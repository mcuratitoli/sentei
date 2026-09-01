import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentei/domain/models/elevation_profile.dart';
import 'package:sentei/ui/cai_difficulty.dart';

TrailSegment _seg(double from, double to, String? scale) =>
    TrailSegment(fromMeters: from, toMeters: to, ref: 'X', caiScale: scale);

void main() {
  group('presentCaiScales', () {
    test('un badge per grado distinto, dal più facile al più difficile', () {
      final segs = [
        _seg(0, 100, 'EEA'),
        _seg(100, 200, 'T'),
        _seg(200, 300, 'EE'),
        _seg(300, 400, 'ee'), // duplicato, normalizzato
        _seg(400, 500, null), // senza grado → ignorato
      ];
      expect(presentCaiScales(segs), ['T', 'EE', 'EEA']);
    });

    test('nessun tratto con grado noto → lista vuota', () {
      expect(
          presentCaiScales([_seg(0, 100, null), _seg(100, 200, '')]), isEmpty);
    });

    test('EEA:F si ordina dopo EEA', () {
      final segs = [
        _seg(0, 100, 'EEA:F'),
        _seg(100, 200, 'EEA'),
        _seg(200, 300, 'E')
      ];
      expect(presentCaiScales(segs), ['E', 'EEA', 'EEA:F']);
    });
  });

  group('caiScaleRank', () {
    test('ordine T < E < EE < EEA < EEA:F', () {
      expect(
        [
          caiScaleRank('T'),
          caiScaleRank('E'),
          caiScaleRank('EE'),
          caiScaleRank('EEA'),
          caiScaleRank('EEA:F'),
        ],
        [1, 2, 3, 4, 5],
      );
    });

    test('variante EEA:<x> non nota ricade sul grado base', () {
      expect(caiScaleRank('EEA:PD'), caiScaleRank('EEA'));
    });

    test('grado sconosciuto o assente → 0', () {
      expect(caiScaleRank('boh'), 0);
      expect(caiScaleRank(null), 0);
    });
  });

  group('EEA:F gestito come grado a sé', () {
    test('colore = rosso EEA (non il grigio dei valori ignoti)', () {
      expect(caiScaleColor('EEA:F'), caiScaleColor('EEA'));
      expect(caiScaleColor('EEA:F'), isNot(const Color(0xFF616161)));
    });

    test('rank appena sopra EEA (via ferrata)', () {
      expect(caiScaleRank('EEA:F'), greaterThan(caiScaleRank('EEA')));
    });

    test('etichetta e descrizione dedicate (menzionano la ferrata)', () {
      expect(caiScaleLabel('EEA:F'), contains('ferrata'));
      expect(caiScaleDescription('EEA:F'), contains('ferrata'));
    });

    test('è incluso in caiScalesInOrder per la legenda', () {
      expect(caiScalesInOrder, contains('EEA:F'));
    });
  });
}
