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

  group('estimateForTrack: salita/discesa su percorso chiuso', () {
    const calc = HikingTimeCalculator();

    test('andata e ritorno (stesso punto): salita e discesa distinte', () {
      // Salita: 3000 m, D+ 300 → oriz 0.75h, vert 300/400=0.75h.
      // max(0.75,0.75) + min/4 = 0.9375h = 56.25min → 56min.
      // Discesa: 3000 m, D- 300 → oriz 0.75h, vert 300/500=0.6h.
      // max(0.75,0.6) + min/4 = 0.9h = 54min.
      // Totale = somma delle due tratte (non l'aggregato sull'intero
      // percorso: lo sconto min/4 si applicherebbe una sola volta invece
      // che una per tratta, disallineandosi dalla card).
      final r = calc.estimateForTrack(
        _rifugioProfile(),
        distanceMeters: 6000,
        gainMeters: 300,
        lossMeters: 300,
      );
      expect(r.isSplit, isTrue);
      expect(r.ascent, const Duration(minutes: 56));
      expect(r.descent, const Duration(minutes: 54));
      expect(r.total, const Duration(minutes: 110));
    });

    test('anello: arrivo vicino alla partenza ma non identico → comunque split',
        () {
      // ~100 m a nord della partenza (0.0009° di latitudine): sotto la
      // soglia di 150 m, quindi trattato come "chiuso" anche se non è un
      // ritorno esatto sullo stesso punto (es. un anello).
      final profile = ElevationProfile(
        samples: [
          const ProfileSample(
              distanceMeters: 0, elevation: 0, position: LatLng(45, 7)),
          const ProfileSample(
              distanceMeters: 1000, elevation: 100, position: _mid),
          const ProfileSample(
              distanceMeters: 2000, elevation: 200, position: _mid),
          const ProfileSample(
              distanceMeters: 3000, elevation: 300, position: _mid),
          const ProfileSample(
              distanceMeters: 4000, elevation: 200, position: _mid),
          const ProfileSample(
              distanceMeters: 5000, elevation: 100, position: _mid),
          const ProfileSample(
              distanceMeters: 6000, elevation: 0, position: LatLng(45.0009, 7)),
        ],
        minElevation: 0,
        maxElevation: 300,
        totalDistance: 6000,
      );
      final r = calc.estimateForTrack(
        profile,
        distanceMeters: 6000,
        gainMeters: 300,
        lossMeters: 300,
      );
      expect(r.isSplit, isTrue);
    });

    test('percorso punto-a-punto: nessuno split, solo il totale', () {
      final profile = ElevationProfile(
        samples: [
          const ProfileSample(
              distanceMeters: 0, elevation: 0, position: LatLng(45, 7)),
          const ProfileSample(
              distanceMeters: 1000, elevation: 100, position: _mid),
          const ProfileSample(
              distanceMeters: 2000, elevation: 200, position: _mid),
          const ProfileSample(
              distanceMeters: 3000, elevation: 300, position: LatLng(45.2, 7.2)),
        ],
        minElevation: 0,
        maxElevation: 300,
        totalDistance: 3000,
      );
      final r = calc.estimateForTrack(
        profile,
        distanceMeters: 3000,
        gainMeters: 300,
        lossMeters: 0,
      );
      expect(r.isSplit, isFalse);
      expect(r.ascent, isNull);
      expect(r.descent, isNull);
      expect(
        r.total,
        calc.estimate(distanceMeters: 3000, gainMeters: 300, lossMeters: 0),
      );
    });

    test('picco troppo vicino a un capo: niente split (sale per tutto)', () {
      // Percorso chiuso ma con la quota massima proprio all'ultimo campione
      // prima del rientro immediato: non è un vero punto di svolta.
      final profile = ElevationProfile(
        samples: [
          const ProfileSample(
              distanceMeters: 0, elevation: 0, position: LatLng(45, 7)),
          const ProfileSample(
              distanceMeters: 1000, elevation: 100, position: _mid),
          const ProfileSample(
              distanceMeters: 2000, elevation: 200, position: _mid),
          const ProfileSample(
              distanceMeters: 2950, elevation: 300, position: _mid),
          const ProfileSample(
              distanceMeters: 3000, elevation: 295, position: LatLng(45, 7)),
        ],
        minElevation: 0,
        maxElevation: 300,
        totalDistance: 3000,
      );
      final r = calc.estimateForTrack(
        profile,
        distanceMeters: 3000,
        gainMeters: 300,
        lossMeters: 5,
      );
      expect(r.isSplit, isFalse);
    });
  });
}
