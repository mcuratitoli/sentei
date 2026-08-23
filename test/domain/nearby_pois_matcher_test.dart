import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/domain/models/point_of_interest.dart';
import 'package:sentei/domain/services/nearby_pois_matcher.dart';

void main() {
  const matcher = NearbyPoisMatcher();

  final path = [
    const LatLng(45.0, 7.0),
    const LatLng(45.0, 7.01),
    const LatLng(45.0, 7.02),
  ];

  RawPointOfInterest poi(String id, LatLng pos,
          {PoiCategory category = PoiCategory.rifugio, String name = 'Test'}) =>
      RawPointOfInterest(id: id, name: name, category: category, position: pos);

  test('percorso vuoto o con un solo punto → nessun match', () {
    final p = poi('a', const LatLng(45.0, 7.0));
    expect(matcher.match(routedPath: const [], pois: [p]), isEmpty);
    expect(
      matcher.match(routedPath: const [LatLng(45.0, 7.0)], pois: [p]),
      isEmpty,
    );
  });

  test('nessun POI → nessun match', () {
    expect(matcher.match(routedPath: path, pois: const []), isEmpty);
  });

  test('POI entro soglia viene incluso con nome/categoria/distanza-lungo-percorso',
      () {
    final p = poi('near', const LatLng(45.001, 7.01),
        category: PoiCategory.rifugio, name: 'Rifugio Test');
    final result = matcher.match(routedPath: path, pois: [p]);
    expect(result, hasLength(1));
    expect(result.single.id, 'near');
    expect(result.single.name, 'Rifugio Test');
    expect(result.single.category, PoiCategory.rifugio);
    expect(result.single.distanceToPathMeters, lessThan(500));
    const distance = Distance();
    final expectedAlong = distance(path[0], path[1]);
    expect(result.single.distanceAlongPathMeters, closeTo(expectedAlong, 20));
  });

  test('POI oltre la soglia viene scartato', () {
    final p = poi('far', const LatLng(45.02, 7.01)); // ~2 km dal percorso
    expect(matcher.match(routedPath: path, pois: [p]), isEmpty);
  });

  test('soglia personalizzata', () {
    final p = poi('mid', const LatLng(45.003, 7.01)); // ~330 m dal percorso
    expect(
      matcher.match(routedPath: path, pois: [p], thresholdMeters: 200),
      isEmpty,
    );
    expect(
      matcher.match(routedPath: path, pois: [p], thresholdMeters: 400),
      hasLength(1),
    );
  });

  test('risultati ordinati per distanza-lungo-percorso crescente', () {
    final far = poi('far', const LatLng(45.001, 7.02));
    final near = poi('near', const LatLng(45.001, 7.0));
    final result = matcher.match(routedPath: path, pois: [far, near]);
    expect(result.map((c) => c.id).toList(), ['near', 'far']);
  });

  test('oltre maxResults tiene solo i più vicini al percorso', () {
    // Tre POI entro soglia, distanze-al-percorso crescenti (a più vicino).
    final a = poi('a', const LatLng(45.0005, 7.0));
    final b = poi('b', const LatLng(45.001, 7.01));
    final c = poi('c', const LatLng(45.002, 7.02));
    final result = matcher.match(
      routedPath: path,
      pois: [a, b, c],
      maxResults: 2,
    );
    expect(result, hasLength(2));
    expect(result.map((r) => r.id), isNot(contains('c')));
  });

  test('POI vicinissimi tra loro (< minSpacingMeters): tiene solo il primo '
      'incontrato camminando', () {
    final first = poi('first', const LatLng(45.0, 7.005));
    // ~39 m da "first": stesso "posto" ai fini dell'immagine esportata.
    final tooClose = poi('too-close', const LatLng(45.0, 7.0055));
    // Ben oltre 150 m da entrambi: resta un punto a parte.
    final far = poi('far', const LatLng(45.0, 7.015));
    final result = matcher.match(routedPath: path, pois: [tooClose, far, first]);

    expect(result.map((r) => r.id).toList(), ['first', 'far']);
  });

  test('due punti vicini di categorie diverse: vince il rifugio anche se '
      'l\'alpeggio si incontra prima camminando (caso reale: Rifugio Vallè / '
      'Alpe Vallè di Sopra, stesso punto)', () {
    final alpeFirst = poi('alpe-first', const LatLng(45.0, 7.005),
        category: PoiCategory.alpe, name: 'Alpe Vallè di Sopra');
    // ~39 m da "alpeFirst", incontrato leggermente dopo camminando.
    final rifugioAfter = poi('rifugio-after', const LatLng(45.0, 7.0055),
        category: PoiCategory.rifugio, name: 'Rifugio Vallè');
    final result =
        matcher.match(routedPath: path, pois: [alpeFirst, rifugioAfter]);

    expect(result.map((r) => r.id).toList(), ['rifugio-after']);
  });

  test('soglia di deduplicazione personalizzata', () {
    final first = poi('first', const LatLng(45.0, 7.005));
    final close = poi('close', const LatLng(45.0, 7.0055)); // ~39 m
    expect(
      matcher
          .match(routedPath: path, pois: [first, close], minSpacingMeters: 10)
          .map((r) => r.id),
      containsAll(['first', 'close']),
    );
    expect(
      matcher
          .match(routedPath: path, pois: [first, close], minSpacingMeters: 60)
          .map((r) => r.id)
          .toList(),
      ['first'],
    );
  });
}
