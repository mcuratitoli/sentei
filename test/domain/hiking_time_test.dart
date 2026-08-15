import 'package:flutter_test/flutter_test.dart';
import 'package:sentei/domain/services/hiking_time.dart';

void main() {
  group('HikingTimeCalculator (passo medio, riferimento CAI)', () {
    const calc = HikingTimeCalculator();

    test('solo piano: 4 km a 4 km/h = 1h', () {
      final d = calc.estimate(
          distanceMeters: 4000, gainMeters: 0, lossMeters: 0);
      expect(d, const Duration(hours: 1));
    });

    test('solo salita: 300 m a 300 m/h = 1h', () {
      final d = calc.estimate(
          distanceMeters: 0, gainMeters: 300, lossMeters: 0);
      expect(d, const Duration(hours: 1));
    });

    test('solo discesa: 500 m a 500 m/h = 1h', () {
      final d = calc.estimate(
          distanceMeters: 0, gainMeters: 0, lossMeters: 500);
      expect(d, const Duration(hours: 1));
    });

    test('combinato: formula SAC max + min/2', () {
      // Orizzontale: 4 km / 4 km/h = 1h. Verticale: 300/300 + 0/500 = 1h.
      // max(1,1) + min(1,1)/2 = 1.5h = 90 min.
      final d = calc.estimate(
          distanceMeters: 4000, gainMeters: 300, lossMeters: 0);
      expect(d, const Duration(minutes: 90));
    });

    test('verticale dominante: orizzontale trascurabile, salita ripida', () {
      // Orizzontale: 1 km / 4 km/h = 15 min. Verticale: 900/300 = 3h.
      // max(3, 0.25) + min(3, 0.25)/2 = 3h7.5min ~ 3h08min.
      final d = calc.estimate(
          distanceMeters: 1000, gainMeters: 900, lossMeters: 0);
      expect(d, const Duration(hours: 3, minutes: 8));
    });

    test('nessuna distanza né dislivello => zero', () {
      final d =
          calc.estimate(distanceMeters: 0, gainMeters: 0, lossMeters: 0);
      expect(d, Duration.zero);
    });
  });

  group('passo lento/veloce', () {
    const calc = HikingTimeCalculator();

    test('passo lento allunga il tempo (fattore 0.8)', () {
      final medium = calc.estimate(
          distanceMeters: 4000, gainMeters: 0, lossMeters: 0);
      final slow = calc.estimate(
          distanceMeters: 4000,
          gainMeters: 0,
          lossMeters: 0,
          pace: HikingPace.slow);
      expect(slow.inMinutes, greaterThan(medium.inMinutes));
      expect(slow, const Duration(minutes: 75)); // 1h / 0.8
    });

    test('passo veloce accorcia il tempo (fattore 1.25)', () {
      final fast = calc.estimate(
          distanceMeters: 4000,
          gainMeters: 0,
          lossMeters: 0,
          pace: HikingPace.fast);
      expect(fast, const Duration(minutes: 48)); // 1h / 1.25
    });
  });
}
