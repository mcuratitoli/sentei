import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/data/trails/cai_varallo_search_service.dart';
import 'package:sentei/data/trails/trail_service.dart';
import 'package:sentei/domain/models/elevation_profile.dart' show TrailSegment;
import 'package:sentei/features/draw_route/route_editor_provider.dart'
    show trailServiceProvider;
import 'package:sentei/features/map_gl/inspected_point_provider.dart';
import 'package:sentei/ui/trail_detail_sheet.dart';

/// Fake controllabile: [detail] la risposta di fetchDetail (`null` = "non
/// trovato"), [throwOnFetch] per simulare un fallimento di rete.
class _FakeTrailService implements TrailService {
  _FakeTrailService({this.detail, this.throwOnFetch = false});
  final TrailDetail? detail;
  final bool throwOnFetch;

  @override
  Future<List<TrailRelation>> fetchRelations(List<LatLng> path,
          {double? radiusMeters}) async =>
      const [];

  @override
  Future<TrailDetail?> fetchDetail(TrailRelation relation) async {
    if (throwOnFetch) throw Exception('boom');
    return detail;
  }

  @override
  Future<TrailDetail?> fetchByRefOnly(String trailRef, LatLng anchor) async =>
      null;

  @override
  Future<List<TrailSegment>> trailSegmentsAlong(List<LatLng> path) async => const [];

  @override
  Future<List<TrailRelation>> trailsNear(LatLng point,
          {double thresholdMeters = 60}) async =>
      const [];
}

final _relation =
    TrailRelation('203', const [], TrailSource.overpass, id: '123');

// `TrailDetailCard` è ora persistente e non modale (§"Un segnavia per
// intero", 25 ago 2026: niente più `showAppBottomSheet` — l'utente deve
// poter esplorare la mappa sotto), quindi l'host deve includerla nell'albero
// come farebbe `map_gl_screen.dart`, non aspettarsela da una route pushata.
Widget _host(TrailService service) => ProviderScope(
      overrides: [trailServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Stack(
              children: [
                Center(
                  child: CupertinoButton(
                    onPressed: () => showTrailDetail(context, ref, _relation),
                    child: const Text('open'),
                  ),
                ),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: TrailDetailCard(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('conferma richiesta prima di aprire il dettaglio', (tester) async {
    await tester.pumpWidget(_host(_FakeTrailService(
      detail: const TrailDetail(ref: '203', points: []),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Vuoi vedere il percorso completo di questo segnavia?'),
        findsOneWidget);
    // Il dettaglio non è ancora stato richiesto: niente spinner/card.
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets(
      'annullando la conferma il dettaglio non si apre affatto', (tester) async {
    await tester.pumpWidget(_host(_FakeTrailService(
      detail: const TrailDetail(ref: '203', points: []),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(find.text('Segnavia 203'), findsNothing);
  });

  testWidgets(
      'confermando: la card mostra nome/capi-percorso/link OpenStreetMap',
      (tester) async {
    await tester.pumpWidget(_host(_FakeTrailService(
      detail: const TrailDetail(
        ref: '203',
        points: [],
        name: 'Alta Via del Rifugio',
        from: 'Alagna',
        to: 'Rifugio Pastore',
        distanceMeters: 5000,
        officialUrl: 'https://www.openstreetmap.org/relation/123',
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approfondisci'));
    await tester.pumpAndSettle();

    expect(find.text('Alta Via del Rifugio'), findsOneWidget);
    // Partenza e arrivo su due righe separate (25 ago 2026), non più
    // "Alagna → Rifugio Pastore" su una sola riga.
    expect(find.text('Alagna'), findsOneWidget);
    expect(find.text('Rifugio Pastore'), findsOneWidget);
    expect(find.text('OpenStreetMap'), findsOneWidget);
  });

  testWidgets(
      'match CAI Varallo: un link verso l\'elenco ufficiale',
      (tester) async {
    await tester.pumpWidget(_host(_FakeTrailService(
      detail: const TrailDetail(
        ref: '203',
        points: [],
        caiVarallo: CaiVaralloResult(
          title: 'Rassa - Alpe Toso - Colle del Loo',
          url:
              'https://www.caivarallo.it/valsesia/sentieri-valsesia/sentieri-valsesia-dettaglio.php?sentiero=417',
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approfondisci'));
    await tester.pumpAndSettle();

    expect(find.text('CAI Varallo'), findsOneWidget);
  });

  testWidgets(
      'nessun match CAI Varallo: il link non compare',
      (tester) async {
    await tester.pumpWidget(_host(_FakeTrailService(
      detail: const TrailDetail(ref: '203', points: []),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approfondisci'));
    await tester.pumpAndSettle();

    expect(find.text('CAI Varallo'), findsNothing);
  });

  testWidgets(
      'geometria non completa: mostra comunque nome/link e un avviso, '
      'nessun crash (feedback utente 25 ago 2026)', (tester) async {
    await tester.pumpWidget(_host(_FakeTrailService(
      detail: const TrailDetail(
        ref: '203',
        points: [LatLng(45.93, 7.87)],
        name: 'Alta Via del Rifugio',
        officialUrl: 'https://www.openstreetmap.org/relation/123',
        geometryComplete: false,
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approfondisci'));
    await tester.pumpAndSettle();

    expect(find.text('Alta Via del Rifugio'), findsOneWidget);
    expect(find.text('OpenStreetMap'), findsOneWidget);
    expect(find.textContaining('Percorso completo non trovato'), findsOneWidget);
  });

  testWidgets(
      'confermando: chiude la card del punto ispezionato sotto, non solo la riduce',
      (tester) async {
    final container = ProviderContainer(overrides: [
      trailServiceProvider.overrideWithValue(
          _FakeTrailService(detail: const TrailDetail(ref: '203', points: []))),
    ]);
    addTearDown(container.dispose);
    // Un punto ispezionato "acceso" a mano (bypassa `inspect()`, che
    // lancerebbe elevazione/geocoding/segnavia reali): basta che lo stato
    // sia non-null perché il test verifichi la chiusura.
    container.read(inspectedPointProvider.notifier).state =
        const InspectedPoint(point: LatLng(45.93, 7.87));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Stack(
              children: [
                Center(
                  child: CupertinoButton(
                    onPressed: () => showTrailDetail(context, ref, _relation),
                    child: const Text('open'),
                  ),
                ),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: TrailDetailCard(),
                ),
              ],
            ),
          ),
        ),
      ),
    ));

    expect(container.read(inspectedPointProvider), isNotNull);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approfondisci'));
    await tester.pumpAndSettle();

    expect(container.read(inspectedPointProvider), isNull);
  });

  testWidgets('segnavia non trovato: messaggio di errore, niente crash',
      (tester) async {
    await tester.pumpWidget(_host(_FakeTrailService(detail: null)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approfondisci'));
    await tester.pumpAndSettle();

    expect(find.textContaining('non trovato'), findsOneWidget);
  });

  testWidgets('fallimento di rete: stesso stato di errore, nessuna eccezione propagata',
      (tester) async {
    await tester.pumpWidget(_host(_FakeTrailService(throwOnFetch: true)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approfondisci'));
    await tester.pumpAndSettle();

    expect(find.textContaining('non trovato'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chiudendo con la × la card sparisce', (tester) async {
    await tester.pumpWidget(_host(_FakeTrailService(
      detail: const TrailDetail(ref: '203', points: []),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approfondisci'));
    await tester.pumpAndSettle();
    expect(find.text('Segnavia 203'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.xmark).first);
    await tester.pumpAndSettle();

    expect(find.text('Segnavia 203'), findsNothing);
  });
}
