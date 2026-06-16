import 'package:flutter_test/flutter_test.dart';
import 'package:sentei/domain/services/elevation_calculator.dart';

void main() {
  group('ElevationCalculator (soglia 8 m)', () {
    const calc = ElevationCalculator(thresholdMeters: 8);

    test('salita oltre soglia viene contata, rumore sotto-soglia no', () {
      // 1000 -> 1005 (delta 5, ignorato) -> 1010 (delta 10 dall'anchor, contato)
      final r = calc.compute(const [1000, 1005, 1010]);
      expect(r.gain, 10);
      expect(r.loss, 0);
    });

    test('salita graduale viene accumulata', () {
      final r = calc.compute(const [0, 10, 20, 30]);
      expect(r.gain, 30);
      expect(r.loss, 0);
    });

    test('discesa contata come loss positivo', () {
      final r = calc.compute(const [100, 80]);
      expect(r.gain, 0);
      expect(r.loss, 20);
    });

    test('rumore puro sotto-soglia non produce dislivello', () {
      final r = calc.compute(const [100, 102, 98, 101, 100]);
      expect(r.gain, 0);
      expect(r.loss, 0);
    });

    test('i campioni null vengono saltati', () {
      final r = calc.compute(const [0, null, 10]);
      expect(r.gain, 10);
    });

    test('meno di 2 quote valide => zero', () {
      expect(calc.compute(const []).gain, 0);
      expect(calc.compute(const [null, 1000]).gain, 0);
    });
  });

  group('soglia 0 (nessuno smoothing)', () {
    const raw = ElevationCalculator(thresholdMeters: 0);
    test('somma ogni variazione', () {
      final r = raw.compute(const [100, 102, 98, 101]);
      expect(r.gain, closeTo(5, 1e-9)); // +2 +3
      expect(r.loss, closeTo(4, 1e-9)); // -4
    });
  });
}
