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

class _FakeElevation implements ElevationService {
  @override
  Future<double?> elevationAt(LatLng point) async => null;
  @override
  Future<List<double?>> elevationsAlong(List<LatLng> points) async =>
      List.filled(points.length, null);
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
      'colore collassato di default: un solo swatch, espande al tocco',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    container.read(tracksProvider.notifier).startNewDrawing();
    await tester.pump();

    // Collassato: la label "Colore" è visibile, la palette no.
    expect(find.text('Colore'), findsOneWidget);
    expect(find.byKey(const Key('colorPickerSelectedSwatch')), findsOneWidget);

    await tester.tap(find.byKey(const Key('colorPickerSelectedSwatch')));
    await tester.pump();

    // Espanso: la label collassata sparisce, compare la palette da scegliere.
    expect(find.text('Colore'), findsNothing);
  });

  testWidgets(
      'nessuna icona accanto a "Segui i sentieri" (switch e testo bastano)',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    container.read(tracksProvider.notifier).startNewDrawing();
    await tester.pump();

    expect(find.text('Segui i sentieri'), findsOneWidget);
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
}
