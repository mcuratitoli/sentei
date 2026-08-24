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
import 'package:sentei/domain/models/track_photo.dart';
import 'package:sentei/domain/services/elevation_service.dart';
import 'package:sentei/domain/services/routing_service.dart';
import 'package:sentei/features/draw_route/draw_route_controls.dart';
import 'package:sentei/features/draw_route/route_editor_provider.dart';
import 'package:sentei/ui/app_bottom_sheet.dart' show AppSheetSurface;
import 'package:sentei/ui/app_buttons.dart' show AppIconButton;
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
    // solo la voce riassuntiva su una barra (nessuno swatch del colore
    // corrente: era fuorviante, sembrava un'informazione a sé; niente icona
    // a sinistra — coerente col mockup, solo testo + chevron).
    expect(find.text('Impostazioni avanzate'), findsOneWidget);
    expect(find.text('Colore'), findsNothing);
    expect(find.text('Segui i sentieri'), findsNothing);
    expect(find.byIcon(CupertinoIcons.chevron_right), findsOneWidget);

    await tester.tap(find.byKey(const Key('advancedSettingsRow')));
    await tester.pumpAndSettle();

    // Il foglio mostra entrambe le impostazioni.
    expect(find.text('COLORE'), findsOneWidget);
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
      'punto selezionato: quota, coordinate, suggerimento e "Aggiungi prima"/"Aggiungi dopo" '
      '(assenti rispettivamente sul primo e sull\'ultimo punto)',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier.startNewDrawing();
    notifier.addPoint(const LatLng(45.0, 7.0));
    notifier.addPoint(const LatLng(45.01, 7.0));
    notifier.addPoint(const LatLng(45.02, 7.0));
    await tester.pumpAndSettle();

    // Seleziona il punto di mezzo (indice 1, "Punto 2 di 3"): ha sia un
    // precedente che un successivo, quindi entrambe le azioni compaiono.
    container.read(selectedWaypointProvider.notifier).toggle(1);
    await tester.pumpAndSettle();

    expect(find.text('Punto 2 di 3'), findsOneWidget);
    expect(find.text(Format.coordinates(45.01, 7.0)), findsOneWidget);
    expect(find.text('Tieni premuto per spostare'), findsOneWidget);
    expect(
        find.text(Format.meters(_FakeElevation.fixedElevation)), findsOneWidget);
    expect(find.text('Aggiungi prima'), findsOneWidget);
    expect(find.text('Aggiungi dopo'), findsOneWidget);

    // Il primo punto non ha un precedente: solo "Aggiungi dopo" resta.
    container.read(selectedWaypointProvider.notifier).toggle(1); // deseleziona
    container.read(selectedWaypointProvider.notifier).toggle(0);
    await tester.pumpAndSettle();

    expect(find.text('Punto 1 di 3'), findsOneWidget);
    expect(find.text('Aggiungi prima'), findsNothing);
    expect(find.text('Aggiungi dopo'), findsOneWidget);

    // L'ultimo punto non ha un successivo: solo "Aggiungi prima" resta.
    container.read(selectedWaypointProvider.notifier).toggle(0); // deseleziona
    container.read(selectedWaypointProvider.notifier).toggle(2);
    await tester.pumpAndSettle();

    expect(find.text('Punto 3 di 3'), findsOneWidget);
    expect(find.text('Aggiungi prima'), findsOneWidget);
    expect(find.text('Aggiungi dopo'), findsNothing);
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
    await tester.tap(find.byIcon(CupertinoIcons.xmark));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoTextField), findsOneWidget);
    expect(find.text('Impostazioni avanzate'), findsOneWidget);
  });

  testWidgets(
      '"Aggiungi prima" inserisce il punto e la selezione segue quello originale',
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

    await tester.tap(find.text('Aggiungi prima'));
    await tester.pumpAndSettle();

    expect(container.read(tracksProvider).editing!.waypoints.length, 3);
    // Il punto originale (indice 1) è slittato a 2: la selezione lo segue,
    // non il nuovo punto appena inserito.
    expect(container.read(selectedWaypointProvider), 2);
    expect(find.text('Punto 3 di 3'), findsOneWidget);
  });

  testWidgets(
      '"Aggiungi dopo" inserisce il punto senza spostare la selezione',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier.startNewDrawing();
    notifier.addPoint(const LatLng(45.0, 7.0)); // indice 0
    notifier.addPoint(const LatLng(45.02, 7.0)); // indice 1
    await tester.pumpAndSettle();

    container.read(selectedWaypointProvider.notifier).toggle(0);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aggiungi dopo'));
    await tester.pumpAndSettle();

    expect(container.read(tracksProvider).editing!.waypoints.length, 3);
    // Il punto selezionato resta l'indice 0: il nuovo punto si inserisce
    // dopo, non prima, quindi non c'è nulla da slittare.
    expect(container.read(selectedWaypointProvider), 0);
    expect(find.text('Punto 1 di 3'), findsOneWidget);
  });

  testWidgets(
      '"Libero": acceso, i punti aggiunti dopo diventano segmenti liberi, quelli prima no',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier.startNewDrawing();
    notifier.addPoint(const LatLng(45.0, 7.0)); // indice 0
    notifier.addPoint(const LatLng(45.01, 7.0)); // indice 1 — segmento 0
    await tester.pumpAndSettle();

    // Spento di default: nessun segmento libero finora.
    expect(container.read(tracksProvider).editing!.freeSegments, isEmpty);
    expect(container.read(freeDrawingModeProvider), false);

    await tester.tap(find.byTooltip('Attiva tratto libero'));
    await tester.pumpAndSettle();
    expect(container.read(freeDrawingModeProvider), true);

    notifier.addPoint(const LatLng(45.02, 7.0)); // indice 2 — segmento 1, libero
    await tester.pumpAndSettle();
    expect(container.read(tracksProvider).editing!.freeSegments, {1});

    await tester.tap(find.byTooltip('Disattiva tratto libero'));
    await tester.pumpAndSettle();
    notifier.addPoint(const LatLng(45.03, 7.0)); // indice 3 — segmento 2, non libero
    await tester.pumpAndSettle();
    expect(container.read(tracksProvider).editing!.freeSegments, {1});
  });

  testWidgets(
      '"Libero" disabilitato quando "Segui sentieri" è già spento per l\'intera traccia',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier.startNewDrawing();
    notifier.addPoint(const LatLng(45.0, 7.0));
    notifier.addPoint(const LatLng(45.01, 7.0));
    notifier.setSnap(false);
    await tester.pumpAndSettle();

    final button = tester.widget<AppIconButton>(find.byWidgetPredicate(
        (w) =>
            w is AppIconButton &&
            w.tooltip == 'Tratto libero (l\'intera traccia è già senza sentieri)'));
    expect(button.onPressed, isNull);
  });

  testWidgets(
      '"Libero" nella card del punto selezionato: rende liberi entrambi i tratti di un inserimento interno',
      (tester) async {
    // Caso reale segnalato dall'utente: traccia a-b-c-d-e-f già disegnata,
    // si seleziona c e si vuole inserire un punto (una cima fuori sentiero)
    // tra c e d, libero da entrambi i lati — non solo aggiungendo in coda.
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier.startNewDrawing();
    for (var i = 0; i < 6; i++) {
      notifier.addPoint(LatLng(45.0 + i * 0.01, 7.0));
    }
    await tester.pumpAndSettle();
    expect(container.read(tracksProvider).editing!.freeSegments, isEmpty);

    // Seleziona c (indice 2).
    container.read(selectedWaypointProvider.notifier).toggle(2);
    await tester.pumpAndSettle();
    expect(find.text('Punto 3 di 6'), findsOneWidget);

    // Il tasto "Libero" è raggiungibile anche da qui, non solo dalla barra
    // principale (nascosta mentre un punto è selezionato) — riga intera
    // cliccabile, non un'icona isolata.
    await tester.tap(
        find.text('Segui sentieri: attiva "Libero" per un tratto fuori sentiero'));
    await tester.pumpAndSettle();
    expect(container.read(freeDrawingModeProvider), true);

    await tester.tap(find.text('Aggiungi dopo'));
    await tester.pumpAndSettle();

    // Il nuovo punto (indice 3, tra il vecchio c e d) divide il vecchio
    // segmento 2 in due: entrambi liberi, non solo quello ereditato.
    expect(container.read(tracksProvider).editing!.waypoints.length, 7);
    expect(container.read(tracksProvider).editing!.freeSegments, {2, 3});
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
      'tap su un\'escursione apre la sua prima foto per distanza lungo il '
      'percorso, non nell\'ordine in cui sono state collegate', (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier
      ..startNewDrawing()
      ..addPoint(const LatLng(45.0, 7.0))
      ..addPoint(const LatLng(45.05, 7.0));
    await notifier.finishDrawing();
    final id = container.read(tracksProvider).tracks.first.id;
    // Collegate in ordine "sbagliato" (la più lontana prima); nessuna delle
    // due ha `takenAt` → finiscono nello stesso gruppo "Foto senza data".
    await notifier.addPhotos(id, const [
      TrackPhoto(id: 'far', position: LatLng(45.04, 7), distanceMeters: 5000),
      TrackPhoto(id: 'near', position: LatLng(45.005, 7), distanceMeters: 500),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('FOTO · 2 FOTO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto senza data'));
    await tester.pumpAndSettle();

    // La foto aperta è "near" (500 m), non "far" (5000 m, collegata prima).
    expect(container.read(selectedPhotoProvider)?.id, 'near');
  });

  testWidgets(
      'tap su un\'escursione va dritto alla PhotoDetailCard (nessuna griglia '
      'intermedia), stesso selectedPhotoProvider del pin in mappa',
      (tester) async {
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

    await tester.tap(find.text('FOTO · 1 FOTO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto senza data'));
    await tester.pumpAndSettle();

    expect(container.read(selectedPhotoProvider)?.id, 'ph1');
    expect(find.byType(GridView), findsNothing);
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

    // 3 righe: titolo (nessuno impostato: la data/ora fa da default e basta —
    // ripeterla anche in una riga a sé sarebbe una duplicazione); quota in
    // soli metri (senza l'etichetta "Quota") + coordinate; data/ora.
    expect(find.text(Format.dateTime(takenAt)), findsOneWidget);
    expect(find.text(Format.coordinates(45.005, 7)), findsOneWidget);
    expect(find.text(Format.meters(_FakeElevation.fixedElevation)),
        findsOneWidget);
    expect(find.textContaining('Quota'), findsNothing);
    // Azioni ridotte a sole icone in linea (niente più pillole con etichetta):
    // si trovano dal tooltip, non dal testo.
    expect(find.byTooltip('Modifica titolo'), findsOneWidget);
    expect(find.byTooltip('Scollega'), findsOneWidget);
    expect(find.text('Scollega'), findsNothing);

    // Modifica titolo: il dialog precompilato salva il nuovo valore. Il
    // titolo ora differisce dalla data: la riga data/ora resta comunque
    // visibile (sempre mostrata, non solo come fallback del titolo).
    await tester.tap(find.byTooltip('Modifica titolo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'Bivacco Ravelli');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(find.text('Bivacco Ravelli'), findsOneWidget);
    // Con un titolo custom, la data/ora torna a comparire una sola volta
    // (solo come riga a sé, non più anche come titolo).
    expect(find.text(Format.dateTime(takenAt)), findsOneWidget);
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

    await tester.tap(find.byTooltip('Scollega'));
    await tester.pumpAndSettle();
    expect(find.text('Scollegare la foto?'), findsOneWidget);

    // La conferma ha ora la stessa forma di "Modifica titolo": riga di due
    // bottoni (Annulla terziario + azione distruttiva), non due voci di menu
    // impilate.
    expect(find.text('Annulla'), findsOneWidget);
    await tester.tap(find.text('Scollega'));
    await tester.pumpAndSettle();

    expect(container2.read(tracksProvider).tracks.first.photos, isEmpty);
    expect(container2.read(selectedPhotoProvider), isNull);
  });

  testWidgets(
      'la card traccia selezionata si riduce a solo nome + azioni, per '
      'lasciare più mappa visibile', (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier
      ..startNewDrawing()
      ..addPoint(const LatLng(45.0, 7.0))
      ..addPoint(const LatLng(45.01, 7.0));
    await notifier.finishDrawing();
    await tester.pumpAndSettle();

    // Espansa di default: distanza e azioni (es. "Profilo altimetrico")
    // visibili.
    expect(find.byIcon(Icons.straighten), findsOneWidget);
    expect(find.byTooltip('Profilo altimetrico'), findsOneWidget);

    await tester.tap(find.byTooltip('Riduci'));
    await tester.pumpAndSettle();

    // Ridotta: solo nome + i due tasti in alto, il resto è sparito.
    expect(find.byIcon(Icons.straighten), findsNothing);
    expect(find.byTooltip('Profilo altimetrico'), findsNothing);
    expect(find.text('Senza nome'), findsOneWidget);

    await tester.tap(find.byTooltip('Espandi'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.straighten), findsOneWidget);
    expect(find.byTooltip('Profilo altimetrico'), findsOneWidget);
  });

  testWidgets(
      'coerenza grafica: icona "Modifica" Cupertino (non Material)',
      (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier
      ..startNewDrawing()
      ..addPoint(const LatLng(45.0, 7.0))
      ..addPoint(const LatLng(45.01, 7.0));
    await notifier.finishDrawing();
    await tester.pumpAndSettle();

    // Superficie opaca (`new design/DESIGN_GUIDELINES.md` §7), non più
    // "vetro" semitrasparente — verificato anche per PhotoDetailCard sotto.
    expect(find.byType(AppSheetSurface), findsOneWidget);

    // "Modifica" era `Icons.edit_rounded` (Material): stonava con le altre
    // icone Cupertino dell'app (nome traccia, titolo foto). Ora è una voce
    // del menu "Altro" (le azioni sulla traccia non stanno più in riga).
    await tester.tap(find.byTooltip('Altro'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_rounded), findsNothing);
    expect(find.byIcon(CupertinoIcons.pencil), findsOneWidget);
  });

  testWidgets(
      'menu "Altro": Esporta GPX ed Esporta immagine sono voci dirette '
      '(niente sotto-foglio, già dentro un menu)', (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier
      ..startNewDrawing()
      ..addPoint(const LatLng(45.0, 7.0))
      ..addPoint(const LatLng(45.01, 7.0));
    await notifier.finishDrawing();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Altro'));
    await tester.pumpAndSettle();

    expect(find.text('Esporta GPX'), findsOneWidget);
    expect(find.text('Esporta immagine'), findsOneWidget);
    expect(find.text('Salva offline'), findsOneWidget);
  });

  testWidgets(
      'tasto Elimina nella card traccia selezionata: conferma e rimuove la '
      'traccia (deseleziona da sé, la card sparisce)', (tester) async {
    final container = await pumpCard(tester);
    await tester.pump();
    final notifier = container.read(tracksProvider.notifier);
    notifier
      ..startNewDrawing()
      ..addPoint(const LatLng(45.0, 7.0))
      ..addPoint(const LatLng(45.01, 7.0));
    await notifier.finishDrawing();
    await tester.pumpAndSettle();

    expect(container.read(tracksProvider).tracks, hasLength(1));

    await tester.tap(find.byTooltip('Altro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare la traccia?'), findsOneWidget);

    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(container.read(tracksProvider).tracks, isEmpty);
    expect(container.read(tracksProvider).selectedId, isNull);
  });

  testWidgets(
      'coerenza grafica: PhotoDetailCard usa una superficie opaca come la '
      'card traccia (non più il "vetro" semitrasparente)', (tester) async {
    final container = ProviderContainer(overrides: [
      routingServiceProvider.overrideWithValue(_FakeRouting()),
      elevationServiceProvider.overrideWithValue(_FakeElevation()),
      tracksRepositoryProvider.overrideWithValue(_FakeRepo()),
    ]);
    addTearDown(container.dispose);
    container.read(tracksProvider.notifier)
      ..startNewDrawing()
      ..addPoint(const LatLng(45.0, 7.0))
      ..addPoint(const LatLng(45.01, 7.0));
    await container.read(tracksProvider.notifier).finishDrawing();
    final id = container.read(tracksProvider).tracks.first.id;
    await container.read(tracksProvider.notifier).addPhotos(id, const [
      TrackPhoto(id: 'ph1', position: LatLng(45.005, 7), distanceMeters: 500),
    ]);
    final photo = container.read(tracksProvider).tracks.first.photos.single;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PhotoDetailCard(photo: photo, onClose: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppSheetSurface), findsOneWidget);
  });
}
