import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoTextField;
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
import 'package:sentei/domain/models/elevation_profile.dart' show ProfileSample;
import 'package:sentei/domain/models/track_photo.dart';
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
    // solo la voce riassuntiva con un'icona neutra (non uno swatch del
    // colore corrente: era fuorviante, sembrava un'informazione a sé).
    expect(find.text('Impostazioni avanzate'), findsOneWidget);
    expect(find.text('Colore'), findsNothing);
    expect(find.text('Segui i sentieri'), findsNothing);
    expect(find.byIcon(CupertinoIcons.slider_horizontal_3), findsOneWidget);

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
      'selezionare un punto sostituisce nome/distanza/impostazioni avanzate '
      '(si sta modificando il punto, non il resto della traccia)',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier.startNewDrawing();
    notifier.addPoint(const LatLng(45.0, 7.0));
    notifier.addPoint(const LatLng(45.01, 7.0));
    await tester.pumpAndSettle();

    // Nessun punto selezionato: card "normale".
    expect(find.byType(CupertinoTextField), findsOneWidget); // _NameField
    expect(find.text('Impostazioni avanzate'), findsOneWidget);
    expect(find.byIcon(Icons.straighten), findsOneWidget); // distanza

    container.read(selectedWaypointProvider.notifier).toggle(1);
    await tester.pumpAndSettle();

    // Un punto selezionato: solo i suoi dati, il resto sparisce.
    expect(find.byType(CupertinoTextField), findsNothing);
    expect(find.text('Impostazioni avanzate'), findsNothing);
    expect(find.byIcon(Icons.straighten), findsNothing);
    expect(find.text('Punto 2 di 2'), findsOneWidget);

    // Chiudendo si torna alla card normale.
    await tester.tap(find.byIcon(CupertinoIcons.clear_circled_solid));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoTextField), findsOneWidget);
    expect(find.text('Impostazioni avanzate'), findsOneWidget);
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

  testWidgets(
      'scorrendo il grafico, la thumbnail della foto vicina al cursore si evidenzia',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier
      ..startNewDrawing()
      ..addPoint(const LatLng(45.0, 7.0))
      ..addPoint(const LatLng(45.05, 7.0)); // percorso lungo qualche km
    await notifier.finishDrawing();
    final id = container.read(tracksProvider).tracks.first.id;
    await notifier.addPhotos(id, const [
      TrackPhoto(id: 'near', position: LatLng(45.005, 7), distanceMeters: 500),
      TrackPhoto(id: 'far', position: LatLng(45.04, 7), distanceMeters: 5000),
    ]);
    await tester.pumpAndSettle();

    List<Color> borderColors() => [
          for (final w in tester.widgetList<AnimatedContainer>(
              find.byType(AnimatedContainer)))
            ((w.decoration as BoxDecoration).border as Border).top.color,
        ];

    // Nessun cursore: nessuna thumbnail evidenziata (bordo trasparente).
    expect(borderColors().every((c) => c == Colors.transparent), isTrue);

    // Cursore a 510m: entro tolleranza (25m) dalla foto "near" (500m), non
    // dalla foto "far" (5000m).
    container.read(profileCursorProvider.notifier).set(
        const ProfileSample(
            distanceMeters: 510, elevation: 1000, position: LatLng(45.005, 7)));
    await tester.pumpAndSettle();

    final colors = borderColors();
    expect(colors[0] == Colors.transparent, isFalse); // "near": evidenziata
    expect(colors[1], Colors.transparent); // "far": non evidenziata
  });

  testWidgets(
      'tap su una thumbnail nella striscia apre la stessa PhotoDetailCard '
      'del pin in mappa (selectedPhotoProvider condiviso)', (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier
      ..startNewDrawing()
      ..addPoint(const LatLng(45.0, 7.0))
      ..addPoint(const LatLng(45.01, 7.0));
    await notifier.finishDrawing();
    final id = container.read(tracksProvider).tracks.first.id;
    await notifier.addPhotos(id, const [
      TrackPhoto(id: 'ph1', position: LatLng(45.005, 7), distanceMeters: 500),
    ]);
    await tester.pumpAndSettle();

    expect(container.read(selectedPhotoProvider), isNull);
    // La foto finta non ha bytes di thumbnail: la striscia mostra la stessa
    // icona segnaposto (CupertinoIcons.photo) usata anche dal tasto "Trova
    // foto vicine" nella riga sopra — quest'ultima viene prima nell'albero.
    await tester.tap(find.byIcon(CupertinoIcons.photo).last);
    await tester.pumpAndSettle();

    expect(container.read(selectedPhotoProvider)?.id, 'ph1');
  });

  testWidgets(
      'PhotoDetailCard mostra titolo (o data come default), coordinate, '
      'quota e data/ora', (tester) async {
    final notifier2 = ProviderContainer(overrides: [
      routingServiceProvider.overrideWithValue(_FakeRouting()),
      elevationServiceProvider.overrideWithValue(_FakeElevation()),
      tracksRepositoryProvider.overrideWithValue(_FakeRepo()),
    ]);
    addTearDown(notifier2.dispose);
    notifier2
      ..read(tracksProvider.notifier).startNewDrawing()
      ..read(tracksProvider.notifier).addPoint(const LatLng(45.0, 7.0))
      ..read(tracksProvider.notifier).addPoint(const LatLng(45.01, 7.0));
    await notifier2.read(tracksProvider.notifier).finishDrawing();
    final id = notifier2.read(tracksProvider).tracks.first.id;
    final takenAt = DateTime(2025, 8, 18, 10, 30);
    await notifier2.read(tracksProvider.notifier).addPhotos(id, [
      TrackPhoto(
          id: 'ph1',
          position: const LatLng(45.005, 7),
          distanceMeters: 500,
          takenAt: takenAt),
    ]);
    final photo = notifier2.read(tracksProvider).tracks.first.photos.single;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: notifier2,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PhotoDetailCard(photo: photo, onClose: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nessun titolo impostato: la data/ora di scatto fa da titolo di default.
    expect(find.text(Format.dateTime(takenAt)), findsOneWidget);
    expect(
        find.text(Format.coordinates(45.005, 7)), findsOneWidget);
    expect(find.text('Quota ${Format.meters(_FakeElevation.fixedElevation)}'),
        findsOneWidget);
    expect(find.text('Modifica titolo'), findsOneWidget);
    expect(find.text('Scollega'), findsOneWidget);

    // Modifica titolo: il dialog precompilato salva il nuovo valore.
    await tester.tap(find.text('Modifica titolo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'Bivacco Ravelli');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(find.text('Bivacco Ravelli'), findsOneWidget);
    expect(
        notifier2.read(tracksProvider).tracks.first.photos.single.title,
        'Bivacco Ravelli');
  });

  testWidgets('PhotoDetailCard: Scollega chiede conferma e rimuove la foto',
      (tester) async {
    final container2 = ProviderContainer(overrides: [
      routingServiceProvider.overrideWithValue(_FakeRouting()),
      elevationServiceProvider.overrideWithValue(_FakeElevation()),
      tracksRepositoryProvider.overrideWithValue(_FakeRepo()),
    ]);
    addTearDown(container2.dispose);
    container2.read(tracksProvider.notifier)
      ..startNewDrawing()
      ..addPoint(const LatLng(45.0, 7.0))
      ..addPoint(const LatLng(45.01, 7.0));
    await container2.read(tracksProvider.notifier).finishDrawing();
    final id = container2.read(tracksProvider).tracks.first.id;
    await container2.read(tracksProvider.notifier).addPhotos(id, const [
      TrackPhoto(id: 'ph1', position: LatLng(45.005, 7), distanceMeters: 500),
    ]);
    final photo = container2.read(tracksProvider).tracks.first.photos.single;
    container2.read(selectedPhotoProvider.notifier).set(photo);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container2,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PhotoDetailCard(
              photo: photo,
              onClose: () =>
                  container2.read(selectedPhotoProvider.notifier).clear(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scollega'));
    await tester.pumpAndSettle();
    expect(find.text('Scollegare la foto?'), findsOneWidget);

    await tester.tap(find.text('Scollega').last);
    await tester.pumpAndSettle();

    expect(container2.read(tracksProvider).tracks.first.photos, isEmpty);
    expect(container2.read(selectedPhotoProvider), isNull);
  });
}
