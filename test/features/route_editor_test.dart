import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sentei/data/storage/tracks_repository.dart';
import 'package:sentei/data/trails/overpass_trail_service.dart';
import 'package:sentei/domain/services/elevation_service.dart';
import 'package:sentei/domain/services/routing_service.dart';
import 'package:sentei/features/draw_route/route_editor_provider.dart';

/// Routing finto: ritorna la spezzata tra i waypoint (nessuna rete).
class _FakeRouting implements RoutingService {
  @override
  Future<RouteResult> route(List<LatLng> waypoints, {String? profile}) async =>
      RouteResult(geometry: waypoints);
}

/// Elevazione finta: quota assente.
class _FakeElevation implements ElevationService {
  @override
  Future<double?> elevationAt(LatLng point) async => null;
  @override
  Future<List<double?>> elevationsAlong(List<LatLng> points) async =>
      List.filled(points.length, null);
}

/// Repository finto: nessuna persistenza su disco nei test.
class _FakeRepo implements TracksRepository {
  @override
  Future<List<DrawnTrack>> loadAll() async => const [];
  @override
  Future<void> save(DrawnTrack track) async {}
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

  test('finishDrawing scarta tracce con meno di 2 punti', () async {
    notifier()
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7));
    await notifier().finishDrawing();
    expect(state().tracks, isEmpty);
    expect(state().drawing, isFalse);
  });

  test('finishDrawing mantiene tracce valide, deseleziona e memorizza i dati',
      () async {
    notifier()
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7))
      ..addPoint(const LatLng(45.01, 7));
    await notifier().finishDrawing();

    expect(state().tracks.length, 1);
    expect(state().showCard, isFalse);
    expect(state().saving, isFalse);
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

  test('setName / setColor / toggleSnap', () {
    notifier()
      ..startNewDrawing()
      ..setName('Giro del lago')
      ..setColor(kTrackPalette[2]);
    expect(state().editing!.name, 'Giro del lago');
    expect(state().editing!.color, kTrackPalette[2]);
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
