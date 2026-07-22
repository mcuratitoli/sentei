import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sentei/data/cloud/cloud_sync_service.dart';
import 'package:sentei/data/storage/tracks_repository.dart';
import 'package:sentei/data/trails/overpass_trail_service.dart';
import 'package:sentei/domain/services/elevation_service.dart';
import 'package:sentei/domain/services/routing_service.dart';
import 'package:sentei/features/draw_route/route_editor_provider.dart';
import 'package:sentei/features/settings/cloud_sync_controller.dart';

/// Routing finto: ritorna la spezzata tra i waypoint (nessuna rete).
class _FakeRouting implements RoutingService {
  @override
  Future<RouteResult> route(List<LatLng> waypoints, {String? profile}) async =>
      RouteResult(geometry: waypoints);
}

/// Routing che **conta** le chiamate (per verificare il ricalcolo incrementale).
class _CountingRouting implements RoutingService {
  _CountingRouting(this.calls);
  final List<List<LatLng>> calls;
  @override
  Future<RouteResult> route(List<LatLng> waypoints, {String? profile}) async {
    calls.add(List.of(waypoints));
    return RouteResult(geometry: waypoints);
  }
}

/// Elevazione finta: quota assente.
class _FakeElevation implements ElevationService {
  @override
  Future<double?> elevationAt(LatLng point) async => null;
  @override
  Future<List<double?>> elevationsAlong(List<LatLng> points) async =>
      List.filled(points.length, null);
}

/// Cloud finto non connesso: l'auto-sync è no-op nei test (niente plugin).
class _FakeCloud implements CloudSyncService {
  @override
  String get providerName => 'Fake';
  @override
  Future<bool> isSignedIn() async => false;
  @override
  Future<String?> signIn() async => null;
  @override
  Future<void> signOut() async {}
  @override
  Future<String?> currentAccount() async => null;
  @override
  Future<List<RemoteTrackMeta>> listRemote() async => const [];
  @override
  Future<DrawnTrack?> downloadTrack(RemoteTrackMeta meta) async => null;
  @override
  Future<void> uploadTrack(DrawnTrack track,
      {required DateTime updatedAt}) async {}
  @override
  Future<void> deleteTrack(RemoteTrackMeta meta) async {}
}

/// Repository finto: nessuna persistenza su disco nei test.
class _FakeRepo implements TracksRepository {
  @override
  Future<List<DrawnTrack>> loadAll() async => const [];
  @override
  Future<List<({DrawnTrack track, DateTime updatedAt})>>
      loadAllWithUpdatedAt() async => const [];
  @override
  Future<void> save(DrawnTrack track, {DateTime? updatedAt}) async {}
  @override
  Future<void> delete(String id) async {}
}

void main() {
  late ProviderContainer container;
  Tracks notifier() => container.read(tracksProvider.notifier);
  TracksState state() => container.read(tracksProvider);

  setUp(() {
    container = ProviderContainer(overrides: [
      routingServiceProvider.overrideWithValue(_FakeRouting()),
      elevationServiceProvider.overrideWithValue(_FakeElevation()),
      trailServiceProvider.overrideWithValue(
        OverpassTrailService(
          client: MockClient(
              (_) async => http.Response('{"elements":[]}', 200)),
        ),
      ),
      tracksRepositoryProvider.overrideWithValue(_FakeRepo()),
      cloudServiceProvider.overrideWithValue(_FakeCloud()),
    ]);
  });
  tearDown(() => container.dispose());

  test('startNewDrawing crea una traccia in modifica', () {
    notifier().startNewDrawing();
    expect(state().tracks.length, 1);
    expect(state().drawing, isTrue);
  });

  test('addPoint / undo agiscono sulla traccia in modifica', () {
    notifier()
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7))
      ..addPoint(const LatLng(45.01, 7));
    expect(state().editing!.waypoints.length, 2);
    notifier().undo();
    expect(state().editing!.waypoints.length, 1);
  });

  test('undo a stack: annulla add/move/remove in ordine inverso', () {
    final n = notifier();
    n.startNewDrawing();
    expect(state().canUndo, isFalse); // niente da annullare
    n
      ..addPoint(const LatLng(45, 7)) // wp: [A]
      ..addPoint(const LatLng(45.01, 7)) // wp: [A,B]
      ..addPoint(const LatLng(45.02, 7)); // wp: [A,B,C]
    expect(state().editing!.waypoints.length, 3);
    expect(state().canUndo, isTrue);

    n.movePoint(0, const LatLng(45.5, 7.5)); // sposta A
    expect(state().editing!.waypoints.first, const LatLng(45.5, 7.5));
    n.removePoint(1); // rimuove B → wp: [A', C]
    expect(state().editing!.waypoints.length, 2);

    // Undo remove → riappare B (3 punti)
    n.undo();
    expect(state().editing!.waypoints.length, 3);
    // Undo move → A torna all'originale
    n.undo();
    expect(state().editing!.waypoints.first, const LatLng(45, 7));
    // Undo dei 3 add → si svuota
    n
      ..undo()
      ..undo()
      ..undo();
    expect(state().editing!.waypoints, isEmpty);
    expect(state().canUndo, isFalse);
    n.undo(); // no-op oltre il fondo
    expect(state().editing!.waypoints, isEmpty);
  });

  test('insertPoint inserisce un waypoint intermedio (split) + undo', () {
    final n = notifier();
    n
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7)) // [A]
      ..addPoint(const LatLng(45.02, 7)); // [A, C]
    n.insertPoint(1, const LatLng(45.01, 7.01)); // [A, B, C]
    expect(state().editing!.waypoints.length, 3);
    expect(state().editing!.waypoints[1], const LatLng(45.01, 7.01));
    // Fuori range = no-op.
    n.insertPoint(9, const LatLng(0, 0));
    expect(state().editing!.waypoints.length, 3);
    // Undo dell'inserimento.
    n.undo();
    expect(state().editing!.waypoints.length, 2);
  });

  test('lo stack di undo si azzera a nuova sessione di editing', () {
    final n = notifier();
    n
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7));
    expect(state().canUndo, isTrue);
    n.startNewDrawing(); // scarta l'incompleta + nuova sessione
    expect(state().canUndo, isFalse);
  });

  test('finishDrawing scarta tracce con meno di 2 punti', () async {
    notifier()
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7));
    await notifier().finishDrawing();
    expect(state().tracks, isEmpty);
    expect(state().drawing, isFalse);
  });

  test('finishDrawing mantiene la traccia selezionata (card aperta) e memorizza',
      () async {
    notifier()
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7))
      ..addPoint(const LatLng(45.01, 7));
    await notifier().finishDrawing();

    expect(state().tracks.length, 1);
    // La card resta aperta sulla traccia salvata (selezionata, non più in
    // disegno, calcolo concluso).
    expect(state().showCard, isTrue);
    expect(state().drawing, isFalse);
    expect(state().saving, isFalse);
    expect(state().selectedId, state().tracks.first.id);
    // Dati calcolati e memorizzati sulla traccia.
    expect(state().tracks.first.routedPath.length, greaterThanOrEqualTo(2));
    expect(state().tracks.first.metrics, isNotNull);
  });

  test('riselezione non azzera i dati memorizzati', () async {
    notifier()
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7))
      ..addPoint(const LatLng(45.01, 7));
    await notifier().finishDrawing();
    final id = state().tracks.first.id;

    notifier().select(id);
    expect(state().active!.routedPath.length, greaterThanOrEqualTo(2));
    notifier().deselect();
    notifier().select(id);
    // Ancora presenti, senza ricalcolo.
    expect(state().active!.metrics, isNotNull);
  });

  test('modificare i waypoint azzera i dati calcolati', () async {
    notifier()
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7))
      ..addPoint(const LatLng(45.01, 7));
    await notifier().finishDrawing();
    final id = state().tracks.first.id;

    notifier().select(id);
    notifier().editSelected();
    notifier().addPoint(const LatLng(45.02, 7));
    expect(state().editing!.routedPath, isEmpty);
    expect(state().editing!.metrics, isNull);
  });

  test('setName / setColor / setSnap', () {
    notifier()
      ..startNewDrawing()
      ..setName('Giro del lago')
      ..setColor(kTrackPalette[2]);
    expect(state().editing!.name, 'Giro del lago');
    expect(state().editing!.color, kTrackPalette[2]);
    // snap ON di default; lo si può spegnere (linee dritte fuori sentiero).
    expect(state().editing!.snapToTrail, isTrue);
    notifier().setSnap(false);
    expect(state().editing!.snapToTrail, isFalse);
  });

  test('ri-instradamento incrementale: sposta un punto → ricalcola solo i '
      'segmenti adiacenti', () async {
    final calls = <List<LatLng>>[];
    final c = ProviderContainer(overrides: [
      routingServiceProvider.overrideWithValue(_CountingRouting(calls)),
      elevationServiceProvider.overrideWithValue(_FakeElevation()),
      trailServiceProvider.overrideWithValue(
        OverpassTrailService(
            client: MockClient((_) async => http.Response('{"elements":[]}', 200))),
      ),
      tracksRepositoryProvider.overrideWithValue(_FakeRepo()),
      cloudServiceProvider.overrideWithValue(_FakeCloud()),
    ]);
    addTearDown(c.dispose);

    final n = c.read(tracksProvider.notifier);
    n
      ..startNewDrawing()
      ..addPoint(const LatLng(45.0, 7.0))
      ..addPoint(const LatLng(45.1, 7.0))
      ..addPoint(const LatLng(45.2, 7.0))
      ..addPoint(const LatLng(45.3, 7.0)); // 4 waypoint → 3 segmenti
    final id = c.read(tracksProvider).editingId!;

    // Tiene vivo il provider e forza il calcolo dell'anteprima.
    final sub = c.listen(livePathProvider(id), (_, __) {});
    addTearDown(sub.close);
    await c.read(livePathProvider(id).future);
    expect(calls.length, 3); // un instradamento per segmento

    // Sposta il punto centrale (indice 1): cambiano solo i segmenti 0-1 e 1-2;
    // il segmento 2-3 resta cache-hit.
    n.movePoint(1, const LatLng(45.15, 7.05));
    await c.read(livePathProvider(id).future);
    expect(calls.length, 5); // +2 (non +3): incrementale
  });

  test('remove elimina la traccia attiva', () async {
    notifier()
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7))
      ..addPoint(const LatLng(45.01, 7));
    await notifier().finishDrawing();
    notifier().select(state().tracks.first.id);
    notifier().remove();
    expect(state().tracks, isEmpty);
  });
}
