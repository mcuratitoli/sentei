import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/app/theme.dart';
import 'package:sentei/core/util/format.dart';
import 'package:sentei/data/cloud/cloud_sync_service.dart';
import 'package:sentei/data/storage/tracks_repository.dart';
import 'package:sentei/data/trails/overpass_trail_service.dart';
import 'package:sentei/domain/services/elevation_service.dart';
import 'package:sentei/domain/services/routing_service.dart';
import 'package:sentei/features/draw_route/draw_route_controls.dart';
import 'package:sentei/features/draw_route/route_editor_provider.dart';
import 'package:sentei/features/settings/cloud_sync_controller.dart';

/// Routing finto: ritorna la spezzata tra i waypoint (nessuna rete), come in
/// `route_editor_test.dart`.
class _FakeRouting implements RoutingService {
  @override
  Future<RouteResult> route(List<LatLng> waypoints, {String? profile}) async =>
      RouteResult(geometry: waypoints);
}

/// Elevazione finta con un valore fisso (verificabile nei test), invece del
/// `null` sempre restituito in `route_editor_test.dart` — qui serve mostrare
/// la quota nella barra del punto selezionato.
class _FakeElevation implements ElevationService {
  static const fixedElevation = 1842.0;
  @override
  Future<double?> elevationAt(LatLng point) async => fixedElevation;
  @override
  Future<List<double?>> elevationsAlong(List<LatLng> points) async =>
      List.filled(points.length, fixedElevation);
}

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

/// Pompa la card di disegno dentro un `ProviderScope` con dipendenze finte
/// (nessuna rete/plugin nativo) e ritorna il container per pilotare
/// `tracksProvider` come farebbe l'utente (startNewDrawing/addPoint...).
Future<ProviderContainer> pumpCard(WidgetTester tester) async {
  late final ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        routingServiceProvider.overrideWithValue(_FakeRouting()),
        elevationServiceProvider.overrideWithValue(_FakeElevation()),
        trailServiceProvider.overrideWithValue(
          OverpassTrailService(
            client:
                MockClient((_) async => http.Response('{"elements":[]}', 200)),
          ),
        ),
        tracksRepositoryProvider.overrideWithValue(_FakeRepo()),
        cloudServiceProvider.overrideWithValue(_FakeCloud()),
      ],
      child: Builder(builder: (context) {
        container = ProviderScope.containerOf(context);
        return MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DrawRouteControls()),
        );
      }),
    ),
  );
  return container;
}

void main() {
  testWidgets(
      '"Impostazioni avanzate" collassa colore e segui i sentieri in un foglio',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    container.read(tracksProvider.notifier).startNewDrawing();
    await tester.pump();

    // Collassato: nella card non ci sono né "Colore" né "Segui i sentieri",
    // solo la voce riassuntiva.
    expect(find.text('Impostazioni avanzate'), findsOneWidget);
    expect(find.text('Colore'), findsNothing);
    expect(find.text('Segui i sentieri'), findsNothing);

    await tester.tap(find.byKey(const Key('advancedSettingsRow')));
    await tester.pumpAndSettle();

    // Il foglio mostra entrambe le impostazioni.
    expect(find.text('Colore'), findsOneWidget);
    expect(find.text('Segui i sentieri'), findsOneWidget);
  });

  testWidgets(
      'nessuna icona ridondante accanto a "Segui i sentieri" nel foglio',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    container.read(tracksProvider.notifier).startNewDrawing();
    await tester.pump();

    await tester.tap(find.byKey(const Key('advancedSettingsRow')));
    await tester.pumpAndSettle();

    expect(find.byIcon(CupertinoIcons.arrow_turn_up_right), findsNothing);
    expect(find.byIcon(CupertinoIcons.minus), findsNothing);
  });

  testWidgets(
      'distanza live durante il disegno (≥2 waypoint), senza attendere il Salva',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier.startNewDrawing();
    await tester.pump();

    // Con un solo waypoint non c'è ancora un percorso: nessuna distanza.
    notifier.addPoint(const LatLng(45.0, 7.0));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.straighten), findsNothing);

    // Il secondo waypoint chiude il percorso (≥2 punti): la traccia non è
    // ancora salvata (niente `metrics`) ma la distanza compare comunque,
    // calcolata sul percorso live (`routeDistanceProvider`).
    notifier.addPoint(const LatLng(45.01, 7.0));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.straighten), findsOneWidget);
    final distance = container.read(routeDistanceProvider);
    expect(distance, greaterThan(0));
    expect(find.text(Format.distance(distance)), findsOneWidget);
    // Nessun D+/D- live: richiederebbe il calcolo completo delle quote.
    expect(find.byIcon(Icons.trending_up), findsNothing);
  });

  testWidgets(
      'punto selezionato: quota, suggerimento e "Aggiungi punto prima" (assente sul primo punto)',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier.startNewDrawing();
    notifier.addPoint(const LatLng(45.0, 7.0));
    notifier.addPoint(const LatLng(45.01, 7.0));
    notifier.addPoint(const LatLng(45.02, 7.0));
    await tester.pumpAndSettle();

    // Seleziona il punto di mezzo (indice 1, "Punto 2 di 3"): ha un
    // precedente, quindi "Aggiungi punto prima" è disponibile.
    container.read(selectedWaypointProvider.notifier).toggle(1);
    await tester.pumpAndSettle();

    expect(find.text('Punto 2 di 3'), findsOneWidget);
    expect(find.text('Tieni premuto per spostare'), findsOneWidget);
    expect(
        find.text(Format.meters(_FakeElevation.fixedElevation)), findsOneWidget);
    expect(find.text('Aggiungi punto prima'), findsOneWidget);

    // Il primo punto non ha un precedente: l'azione sparisce.
    container.read(selectedWaypointProvider.notifier).toggle(1); // deseleziona
    container.read(selectedWaypointProvider.notifier).toggle(0);
    await tester.pumpAndSettle();

    expect(find.text('Punto 1 di 3'), findsOneWidget);
    expect(find.text('Aggiungi punto prima'), findsNothing);
  });

  testWidgets(
      '"Aggiungi punto prima" inserisce il punto e la selezione segue quello originale',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier.startNewDrawing();
    notifier.addPoint(const LatLng(45.0, 7.0)); // indice 0
    notifier.addPoint(const LatLng(45.02, 7.0)); // indice 1
    await tester.pumpAndSettle();

    container.read(selectedWaypointProvider.notifier).toggle(1);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aggiungi punto prima'));
    await tester.pumpAndSettle();

    expect(container.read(tracksProvider).editing!.waypoints.length, 3);
    // Il punto originale (indice 1) è slittato a 2: la selezione lo segue,
    // non il nuovo punto appena inserito.
    expect(container.read(selectedWaypointProvider), 2);
    expect(find.text('Punto 3 di 3'), findsOneWidget);
  });

  testWidgets('eliminare un punto chiede conferma prima di rimuoverlo',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier.startNewDrawing();
    notifier.addPoint(const LatLng(45.0, 7.0));
    notifier.addPoint(const LatLng(45.01, 7.0));
    await tester.pumpAndSettle();

    container.read(selectedWaypointProvider.notifier).toggle(1);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    // Il dialog di conferma è apparso: il punto non è ancora stato rimosso.
    expect(find.text('Eliminare il punto?'), findsOneWidget);
    expect(container.read(tracksProvider).editing!.waypoints.length, 2);

    // Conferma (l'azione distruttiva nel dialog, l'ultima "Elimina" nell'albero).
    await tester.tap(find.text('Elimina').last);
    await tester.pumpAndSettle();

    expect(container.read(tracksProvider).editing!.waypoints.length, 1);
  });
}
