import '../models/elevation_profile.dart';
import 'elevation_calculator.dart';

/// Passo dell'escursionista: moltiplicatore sulle velocità di riferimento
/// CAI. "Medio" è il riferimento (nessuna correzione).
enum HikingPace { slow, medium, fast }

extension HikingPaceX on HikingPace {
  String get label => switch (this) {
        HikingPace.slow => 'Lento',
        HikingPace.medium => 'Medio',
        HikingPace.fast => 'Veloce',
      };

  /// Fattore applicato alle velocità di riferimento (>1 = più veloce).
  double get speedFactor => switch (this) {
        HikingPace.slow => 0.8,
        HikingPace.medium => 1.0,
        HikingPace.fast => 1.25,
      };
}

/// Risultato di [HikingTimeCalculator.estimateRange]: tempo di percorrenza di
/// una **sotto-tratta** del percorso, con le metriche (distanza, D+/D-) di
/// quella sola tratta — servono alla UI che mostra "da qui a lì".
class HikingRangeEstimate {
  const HikingRangeEstimate({
    required this.time,
    required this.distanceMeters,
    required this.gainMeters,
    required this.lossMeters,
  });

  static const zero = HikingRangeEstimate(
    time: Duration.zero,
    distanceMeters: 0,
    gainMeters: 0,
    lossMeters: 0,
  );

  final Duration time;
  final double distanceMeters;
  final double gainMeters;
  final double lossMeters;
}

/// Stima il **tempo di percorrenza** con il metodo CAI/SAC (§ROADMAP P1.2, poi
/// P1.C): velocità di riferimento in piano e in verticale, combinate con
/// `t = max(t_oriz, t_vert) + min(t_oriz, t_vert) / 4`.
///
/// La formula svizzera "da manuale" usa `/ 2`, non `/ 4`: **corretto il 15
/// agosto 2026** confrontando due esempi numerici del modello ufficiale
/// (Schweizer Wanderwege, la fonte del metodo CAI) — +100 m/1000 m ≈ 20 min,
/// +300 m/1000 m ≈ 49 min — e una traccia reale (Rassa → Alpe Toso, VC:
/// 6,4 km, D+ 800 m, tempo CAI di riferimento 2h15-2h20). Con `/2` il
/// correttivo esagera quando distanza e dislivello **non sono bilanciati**
/// (il caso più comune: una salita diretta, o una camminata quasi
/// pianeggiante) — è pensato per percorsi misti. Con `/4`: +100 m → 18,6 min
/// (atteso 20), +300 m → 48,6 min (atteso 49), Alpe Toso → ~2h39 (atteso
/// 2h15-2h20), tutti entro un margine ragionevole; con `/2` uscivano
/// rispettivamente 22, 52 e 3h15 — sistematicamente troppo lenti.
///
/// Il tempo **non include le soste** (convenzione CAI): va detto in UI.
///
/// [estimate] prende distanza e dislivelli **già calcolati** da
/// [TrackMetricsCalculator] (`domain/services/track_metrics.dart`) — in
/// particolare il D+/D- con **deadband** già applicato ([ElevationCalculator]),
/// non il dislivello grezzo, altrimenti il tempo si gonfia come si gonfiava il
/// dislivello prima del filtro (§6.3 del CLAUDE.md).
///
/// [estimateRange] copre invece una **sotto-tratta** fra due indici del profilo
/// altimetrico: ricalcola distanza e D+/D- (con lo stesso deadband) sulla sola
/// tratta e applica [estimate]. Coi default → intero percorso. Ha sostituito il
/// vecchio `estimateForTrack`, che divideva automaticamente salita/discesa sui
/// percorsi ad anello: rimosso il 30 agosto 2026 (P1.C) — l'utente sceglie
/// esplicitamente l'intervallo, niente più euristica sul punto di quota massima.
class HikingTimeCalculator {
  const HikingTimeCalculator({
    this.flatSpeedKmh = 4.0,
    this.ascentMetersPerHour = 400,
    this.descentMetersPerHour = 500,
    this.elevationCalculator = const ElevationCalculator(),
  });

  /// Velocità di riferimento in piano (km/h). Default SAC/CAI: 4 km/h.
  final double flatSpeedKmh;

  /// Velocità di riferimento in salita (m/h). Default **SAC: 400 m/h** — non
  /// 300: era la scelta iniziale (l'estremo prudente della forbice 300-350
  /// indicata in roadmap), ma è più lenta del valore standard della formula
  /// svizzera stessa. Vedi la nota sulla classe per il dettaglio della
  /// validazione (Rassa → Alpe Toso) e la correzione del correttivo
  /// `min/4` fatta insieme a questa.
  final double ascentMetersPerHour;

  /// Velocità di riferimento in discesa (m/h). Default CAI: 500 m/h.
  final double descentMetersPerHour;

  /// Filtro a soglia (deadband) per ricalcolare D+/D- sulla sotto-tratta in
  /// [estimateRange] — stessa logica delle metriche di traccia, non il grezzo.
  final ElevationCalculator elevationCalculator;

  /// Stima la durata del percorso. Ritorna [Duration.zero] se non c'è
  /// distanza né dislivello.
  Duration estimate({
    required double distanceMeters,
    required double gainMeters,
    required double lossMeters,
    HikingPace pace = HikingPace.medium,
  }) {
    if (distanceMeters <= 0 && gainMeters <= 0 && lossMeters <= 0) {
      return Duration.zero;
    }
    final factor = pace.speedFactor;

    final horizontalHours = (distanceMeters / 1000) / (flatSpeedKmh * factor);
    final verticalHours = gainMeters / (ascentMetersPerHour * factor) +
        lossMeters / (descentMetersPerHour * factor);

    final hours = horizontalHours >= verticalHours
        ? horizontalHours + verticalHours / 4
        : verticalHours + horizontalHours / 4;

    return Duration(minutes: (hours * 60).round());
  }

  /// Stima il tempo su una **sotto-tratta** del percorso, fra due indici del
  /// profilo altimetrico (inclusi, in qualsiasi ordine). Con i default →
  /// intero percorso (start → end), cioè la stessa stima "totale" di sempre.
  ///
  /// Distanza e D+/D- sono ricalcolati **sulla sola sotto-tratta** con il
  /// deadband di [elevationCalculator] (non l'aggregato dell'intero percorso:
  /// altrimenti un tratto in salita si porterebbe dietro anche il D- del
  /// resto). Ritorna [HikingRangeEstimate.zero] se l'intervallo è degenere
  /// (meno di due campioni, o i due indici coincidono).
  HikingRangeEstimate estimateRange(
    ElevationProfile profile, {
    int startIndex = 0,
    int? endIndex,
    HikingPace pace = HikingPace.medium,
  }) {
    final samples = profile.samples;
    if (samples.length < 2) return HikingRangeEstimate.zero;

    final last = samples.length - 1;
    var lo = startIndex.clamp(0, last);
    var hi = (endIndex ?? last).clamp(0, last);
    if (lo > hi) {
      final t = lo;
      lo = hi;
      hi = t;
    }
    if (lo == hi) return HikingRangeEstimate.zero;

    final sub = samples.sublist(lo, hi + 1);
    final distance =
        sub.last.distanceMeters - sub.first.distanceMeters;
    final gainLoss = elevationCalculator
        .compute([for (final s in sub) s.elevation]);

    return HikingRangeEstimate(
      time: estimate(
        distanceMeters: distance,
        gainMeters: gainLoss.gain,
        lossMeters: gainLoss.loss,
        pace: pace,
      ),
      distanceMeters: distance,
      gainMeters: gainLoss.gain,
      lossMeters: gainLoss.loss,
    );
  }
}
