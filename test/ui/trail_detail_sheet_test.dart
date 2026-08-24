import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/data/trails/trail_service.dart';
import 'package:sentei/domain/models/elevation_profile.dart' show TrailSegment;
import 'package:sentei/features/draw_route/route_editor_provider.dart'
    show trailServiceProvider;
import 'package:sentei/ui/trail_detail_sheet.dart';

/// Fake controllabile: [detail] la risposta di fetchDetail (`null` = "non
/// trovato"), [throwOnFetch] per simulare un fallimento di rete.
class _FakeTrailService implements TrailService {
  _FakeTrailService({this.detail, this.throwOnFetch = false});
  final TrailDetail? detail;
  final bool throwOnFetch;

  @override
  Future<List<TrailRelation>> fetchRelations(List<LatLng> path) async => const [];

  @override
  Future<TrailDetail?> fetchDetail(TrailRelation relation) async {
    if (throwOnFetch) throw Exception('boom');
    return detail;
  }

  @override
  Future<List<TrailSegment>> trailSegmentsAlong(List<LatLng> path) async => const [];

  @override
  Future<List<TrailRelation>> trailsNear(LatLng point,
          {double thresholdMeters = 60}) async =>
      const [];
}

final _relation =
    TrailRelation('203', const [], TrailSource.overpass, id: '123');

Widget _host(TrailService service) => ProviderScope(
      overrides: [trailServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: CupertinoButton(
                onPressed: () => showTrailDetail(context, ref, _relation),
                child: const Text('open'),
              ),
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
      'confermando: la card mostra nome/capi-percorso/link ufficiale',
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
    expect(find.text('Alagna → Rifugio Pastore'), findsOneWidget);
    expect(find.text('Scheda ufficiale'), findsOneWidget);
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
}
