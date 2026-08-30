import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/domain/models/elevation_profile.dart';
import 'package:sentei/domain/services/hiking_time.dart';

const _mid = LatLng(45.01, 7.01);

/// Salita 0→300 m in 3000 m, discesa 300→0 m in altri 3000 m (6000 m totali):
/// stesso profilo usato a mano nei commenti dei test sotto.
ElevationProfile _rifugioProfile({LatLng start = const LatLng(45, 7)}) {
  return ElevationProfile(
    samples: [
      ProfileSample(distanceMeters: 0, elevation: 0, position: start),
      const ProfileSample(distanceMeters: 1000, elevation: 100, position: _mid),
      const ProfileSample(distanceMeters: 2000, elevation: 200, position: _mid),
      const ProfileSample(distanceMeters: 3000, elevation: 300, position: _mid),
      const ProfileSample(distanceMeters: 4000, elevation: 200, position: _mid),
      const ProfileSample(distanceMeters: 5000, elevation: 100, position: _mid),
      ProfileSample(distanceMeters: 6000, elevation: 0, position: start),
    ],
    minElevation: 0,
    maxElevation: 300,
    totalDistance: 6000,
  );
}

void main() {
  group('HikingTimeCalculator (passo medio, riferimento CAI)', () {
    const calc = HikingTimeCalculator();

    test('solo piano: 4 km a 4 km/h = 1h', () {
      final d = calc.estimate(
          distanceMeters: 4000, gainMeters: 0, lossMeters: 0);
      expect(d, const Duration(hours: 1));
    });

    test('solo salita: 400 m a 400 m/h = 1h', () {
      final d = calc.estimate(
          distanceMeters: 0, gainMeters: 400, lossMeters: 0);
      expect(d, const Duration(hours: 1));
    });

    test('solo discesa: 500 m a 500 m/h = 1h', () {
      final d = calc.estimate(
          distanceMeters: 0, gainMeters: 0, lossMeters: 500);
      expect(d, const Duration(hours: 1));
    });

    test('combinato: max + min/4', () {
      // Orizzontale: 4 km / 4 km/h = 1h. Verticale: 400/400 + 0/500 = 1h.
      // max(1,1) + min(1,1)/4 = 1.25h = 75 min.
      final d = calc.estimate(
          distanceMeters: 4000, gainMeters: 400, lossMeters: 0);
      expect(d, const Duration(minutes: 75));
    });

    test('verticale dominante: orizzontale trascurabile, salita ripida', () {
      // Orizzontale: 1 km / 4 km/h = 15 min. Verticale: 1200/400 = 3h.
      // max(3, 0.25) + min(3, 0.25)/4 = 3h3.75min ~ 3h04min.
      final d = calc.estimate(
          distanceMeters: 1000, gainMeters: 1200, lossMeters: 0);
      expect(d, const Duration(hours: 3, minutes: 4));
    });

    test('nessuna distanza né dislivello => zero', () {
      final d =
          calc.estimate(distanceMeters: 0, gainMeters: 0, lossMeters: 0);
      expect(d, Duration.zero);
    });
  });

  group('validazione su traccia reale (15 ago 2026)', () {
    const calc = HikingTimeCalculator();

    test('Rassa → Alpe Toso: entro margine ragionevole dal tempo CAI reale', () {
      // Traccia utente: 6,4 km, D+ 800 m (mulattiera/carrozzabile T, D- ~0).
      // Fonti CAI (caivarallo.com, escursionismo.it): D+ 732 m, tempo
      // indicato 2h15-2h20. Prima correzione (velocità di salita 300→400
      // m/h, invariato qui): 3h43 → 2h48, ancora troppo lento secondo
      // l'utente sulla traccia reale (D+ 810, D- 107: 3h15 misurati in
      // app). Seconda correzione (correttivo max+min/2 → max+min/4,
      // ricalibrato sugli esempi numerici del modello svizzero ufficiale —
      // vedi la nota su [HikingTimeCalculator]): scende a 2h24 su questo
      // caso semplificato (D- 0). Regressione: non deve tornare sopra le 3h.
      final d = calc.estimate(
          distanceMeters: 6400, gainMeters: 800, lossMeters: 0);
      expect(d, const Duration(hours: 2, minutes: 24));
      expect(d.inMinutes, lessThan(180)); // meno di 3h, non più 3h43/3h15
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

  group('estimateRange: tempo su una sotto-tratta del profilo', () {
    const calc = HikingTimeCalculator();

    test('default (nessun indice) = tempo start → end dell\'intero percorso', () {
      // _rifugioProfile: 0→300→0 m in 6000 m, gradini da 100 m (tutti sopra
      // il deadband di 8 m) → D+ 300, D- 300 ricalcolati sul profilo.
      final r = calc.estimateRange(_rifugioProfile());
      expect(r.distanceMeters, 6000);
      expect(r.gainMeters, 300);
      expect(r.lossMeters, 300);
      expect(
        r.time,
        calc.estimate(distanceMeters: 6000, gainMeters: 300, lossMeters: 300),
      );
    });

    test('solo la salita (indici 0..3): D- nullo', () {
      final r = calc.estimateRange(_rifugioProfile(),
          startIndex: 0, endIndex: 3);
      expect(r.distanceMeters, 3000);
      expect(r.gainMeters, 300);
      expect(r.lossMeters, 0);
      expect(r.time,
          calc.estimate(distanceMeters: 3000, gainMeters: 300, lossMeters: 0));
    });

    test('solo la discesa (indici 3..6): D+ nullo', () {
      final r = calc.estimateRange(_rifugioProfile(),
          startIndex: 3, endIndex: 6);
      expect(r.distanceMeters, 3000);
      expect(r.gainMeters, 0);
      expect(r.lossMeters, 300);
    });

    test('tratta centrale punto → punto (indici 1..5)', () {
      // Quote [100,200,300,200,100] su 1000→5000 m → D+ 200, D- 200.
      final r = calc.estimateRange(_rifugioProfile(),
          startIndex: 1, endIndex: 5);
      expect(r.distanceMeters, 4000);
      expect(r.gainMeters, 200);
      expect(r.lossMeters, 200);
    });

    test('indici invertiti danno lo stesso risultato', () {
      final a = calc.estimateRange(_rifugioProfile(),
          startIndex: 1, endIndex: 5);
      final b = calc.estimateRange(_rifugioProfile(),
          startIndex: 5, endIndex: 1);
      expect(b.time, a.time);
      expect(b.distanceMeters, a.distanceMeters);
      expect(b.gainMeters, a.gainMeters);
    });

    test('indici coincidenti → intervallo nullo', () {
      final r = calc.estimateRange(_rifugioProfile(),
          startIndex: 2, endIndex: 2);
      expect(r.time, Duration.zero);
      expect(r.distanceMeters, 0);
    });

    test('indici fuori range → clampati agli estremi', () {
      final full = calc.estimateRange(_rifugioProfile());
      final clamped = calc.estimateRange(_rifugioProfile(),
          startIndex: -5, endIndex: 999);
      expect(clamped.time, full.time);
      expect(clamped.distanceMeters, full.distanceMeters);
    });

    test('profilo con meno di due campioni → intervallo nullo', () {
      final profile = ElevationProfile(
        samples: const [
          ProfileSample(distanceMeters: 0, elevation: 100, position: _mid),
        ],
        minElevation: 100,
        maxElevation: 100,
        totalDistance: 0,
      );
      final r = calc.estimateRange(profile);
      expect(r.time, Duration.zero);
    });

    test('passo veloce accorcia anche la stima su intervallo', () {
      final medium = calc.estimateRange(_rifugioProfile());
      final fast = calc.estimateRange(_rifugioProfile(), pace: HikingPace.fast);
      expect(fast.time.inMinutes, lessThan(medium.time.inMinutes));
    });
  });
}
