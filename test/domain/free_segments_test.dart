import 'package:flutter_test/flutter_test.dart';
import 'package:sentei/domain/services/free_segments.dart';

void main() {
  group('freeSegmentsAfterInsert', () {
    test('inserimento dentro un segmento libero: entrambe le metà restano libere', () {
      // 4 waypoint (0..3), segmenti 0,1,2. Solo il segmento 1 (wp1-wp2) è libero.
      final free = {1};
      // Inserisce a index=2 (tra wp1 e wp2): divide il segmento 1.
      final result = freeSegmentsAfterInsert(free, 2, 4);
      expect(result, {1, 2});
    });

    test('inserimento dentro un segmento agganciato: resta agganciato dopo la divisione', () {
      final free = <int>{};
      final result = freeSegmentsAfterInsert(free, 2, 4);
      expect(result, isEmpty);
    });

    test('segmenti prima del punto inserito restano invariati', () {
      final free = {0};
      final result = freeSegmentsAfterInsert(free, 2, 4);
      expect(result, {0});
    });

    test('segmenti dopo il punto inserito slittano di uno', () {
      final free = {2}; // ultimo segmento (wp2-wp3)
      final result = freeSegmentsAfterInsert(free, 1, 4);
      expect(result, {3});
    });

    test('inserimento prima del primo waypoint: nuovo segmento di bordo non libero', () {
      final free = {0, 1};
      final result = freeSegmentsAfterInsert(free, 0, 4);
      // Tutti i vecchi segmenti slittano di uno; il nuovo segmento 0 non è libero.
      expect(result, {1, 2});
    });

    test('inserimento dopo l\'ultimo waypoint: nuovo segmento di bordo non libero', () {
      final free = {0};
      final result = freeSegmentsAfterInsert(free, 4, 4);
      expect(result, {0});
    });
  });

  group('freeSegmentsAfterRemove', () {
    test('rimozione di un punto interno: il tratto fuso resta libero se almeno un lato lo era', () {
      // 5 waypoint (0..4), segmenti 0,1,2,3. Liberi: 0 e 2.
      final free = {0, 2};
      // Rimuove wp2: i segmenti 1 (wp1-wp2) e 2 (wp2-wp3) si fondono nel nuovo
      // segmento 1 (wp1-wp3); segmento 2 era libero → resta libero.
      final result = freeSegmentsAfterRemove(free, 2, 5);
      expect(result, {0, 1});
    });

    test('rimozione di un punto interno: il tratto fuso resta agganciato se entrambi i lati lo erano', () {
      final free = <int>{0};
      final result = freeSegmentsAfterRemove(free, 2, 5);
      expect(result, {0});
    });

    test('rimozione del primo waypoint: il segmento che partiva da lì scompare, non si fonde', () {
      // 4 waypoint, segmenti 0(libero),1,2. Rimuove wp0.
      final free = {0};
      final result = freeSegmentsAfterRemove(free, 0, 4);
      // Il vecchio segmento 0 (libero) sparisce del tutto; i segmenti 1,2
      // slittano a 0,1 (nessuno dei due era libero).
      expect(result, isEmpty);
    });

    test('rimozione dell\'ultimo waypoint: il segmento che arrivava lì scompare, non si fonde', () {
      // 4 waypoint, segmenti 0,1,2(libero). Rimuove wp3 (index 3, ultimo).
      final free = {2};
      final result = freeSegmentsAfterRemove(free, 3, 4);
      expect(result, isEmpty);
    });

    test('segmenti lontani dal punto rimosso restano invariati o slittano coerentemente', () {
      // 6 waypoint, segmenti 0,1,2,3,4. Liberi: 0 e 4. Rimuove wp2 (interno).
      final free = {0, 4};
      final result = freeSegmentsAfterRemove(free, 2, 6);
      // Segmento 0 invariato; segmenti 1+2 si fondono (nessuno libero, resta
      // agganciato); segmento 3 slitta a 2; segmento 4 (libero) slitta a 3.
      expect(result, {0, 3});
    });
  });
}
