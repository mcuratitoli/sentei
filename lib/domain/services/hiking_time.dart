import 'package:latlong2/latlong.dart';

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

/// Risultato di [HikingTimeCalculator.estimateForTrack]: [total] c'è sempre;
/// [ascent]/[descent] sono valorizzati solo per un percorso **chiuso**
/// (andata e ritorno, o anello con partenza/arrivo nello stesso punto) —
/// tipico di una salita a un rifugio, dove interessa il tempo di salita
/// separato da quello di discesa, non solo il totale. Per un sentiero
/// punto-a-punto restano `null`: c'è solo una previsione unica.
class HikingTimeEstimate {
  const HikingTimeEstimate({required this.total, this.ascent, this.descent});

  final Duration total;
  final Duration? ascent;
  final Duration? descent;

  bool get isSplit => ascent != null && descent != null;
}

/// Stima il **tempo di percorrenza** con il metodo CAI/SAC (§ROADMAP P1.2):
/// velocità di riferimento in piano e in verticale, combinate con la formula
/// svizzera (SAC) `t = max(t_oriz, t_vert) + min(t_oriz, t_vert) / 2` — è il
/// metodo che produce numeri confrontabili con quelli sulla segnaletica CAI.
///
/// Il tempo **non include le soste** (convenzione CAI): va detto in UI.
///
/// Input: distanza e dislivelli **già calcolati** da [TrackMetricsCalculator]
/// (`domain/services/track_metrics.dart`) — in particolare il D+/D- con
/// **deadband** già applicato (`ElevationCalculator`), non il dislivello
/// grezzo, altrimenti il tempo si gonfia come si gonfiava il dislivello
/// prima del filtro (§6.3 del CLAUDE.md).
class HikingTimeCalculator {
  const HikingTimeCalculator({
    this.flatSpeedKmh = 4.0,
    this.ascentMetersPerHour = 300,
    this.descentMetersPerHour = 500,
    this.elevationCalculator = const ElevationCalculator(),
    this.closedLoopThresholdMeters = 150,
  });

  /// Velocità di riferimento in piano (km/h). Default CAI: 4 km/h.
  final double flatSpeedKmh;

  /// Velocità di riferimento in salita (m/h). Default CAI: 300 m/h.
  final double ascentMetersPerHour;

  /// Velocità di riferimento in discesa (m/h). Default CAI: 500 m/h.
  final double descentMetersPerHour;

  /// Filtro a soglia (deadband) usato per ricalcolare D+/D- delle due metà
  /// salita/discesa in [estimateForTrack] — stessa logica, non il grezzo.
  final ElevationCalculator elevationCalculator;

  /// Distanza massima fra primo e ultimo punto perché un percorso sia
  /// considerato "chiuso" (andata e ritorno, o anello). Sopra questa soglia
  /// è un sentiero punto-a-punto: solo il totale, niente salita/discesa.
  final double closedLoopThresholdMeters;

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
        ? horizontalHours + verticalHours / 2
        : verticalHours + horizontalHours / 2;

    return Duration(minutes: (hours * 60).round());
  }

  /// Come [estimate], ma per un percorso **chiuso** (partenza e arrivo entro
  /// [closedLoopThresholdMeters]) separa anche la salita dalla discesa,
  /// dividendo il profilo nel punto di **quota massima** (il rifugio/la
  /// vetta) — non a metà distanza: sull'anello o sul ramo di ritorno non
  /// coincide col punto medio. Ogni metà ha il proprio D+/D- **con
  /// deadband** ricalcolato sulla sua sola tratta, non l'aggregato
  /// dell'intero percorso (altrimenti la salita si vedrebbe anche il D- del
  /// rientro e viceversa). In quel caso [total] è la **somma** di salita e
  /// discesa (non una terza stima indipendente sull'intero percorso): la
  /// formula SAC applicata all'aggregato dà un numero leggermente più basso
  /// (lo sconto `min/2` si applica una sola volta anziché una per tratta),
  /// e mostrarlo in lista sembrerebbe un'incoerenza con la card, che
  /// riporta proprio salita+discesa.
  HikingTimeEstimate estimateForTrack(
    ElevationProfile profile, {
    required double distanceMeters,
    required double gainMeters,
    required double lossMeters,
    HikingPace pace = HikingPace.medium,
  }) {
    final legs = _splitAtPeak(profile);
    if (legs == null) {
      final total = estimate(
        distanceMeters: distanceMeters,
        gainMeters: gainMeters,
        lossMeters: lossMeters,
        pace: pace,
      );
      return HikingTimeEstimate(total: total);
    }

    final ascent = estimate(
      distanceMeters: legs.outDistance,
      gainMeters: legs.outGain,
      lossMeters: legs.outLoss,
      pace: pace,
    );
    final descent = estimate(
      distanceMeters: legs.backDistance,
      gainMeters: legs.backGain,
      lossMeters: legs.backLoss,
      pace: pace,
    );
    return HikingTimeEstimate(
      total: ascent + descent,
      ascent: ascent,
      descent: descent,
    );
  }

  /// `null` se il percorso non è chiuso, o se il picco è troppo vicino a un
  /// capo per essere un vero punto di svolta (es. sale per tutta la tratta).
  _Legs? _splitAtPeak(ElevationProfile profile) {
    final samples = profile.samples;
    if (samples.length < 4) return null;

    const distance = Distance();
    if (distance(samples.first.position, samples.last.position) >
        closedLoopThresholdMeters) {
      return null;
    }

    var peakIndex = 0;
    var peakElevation = samples.first.elevation;
    for (var i = 1; i < samples.length; i++) {
      if (samples[i].elevation > peakElevation) {
        peakElevation = samples[i].elevation;
        peakIndex = i;
      }
    }

    final totalDistance = samples.last.distanceMeters;
    final outDistance = samples[peakIndex].distanceMeters;
    final backDistance = totalDistance - outDistance;
    const minLegFraction = 0.1;
    if (totalDistance <= 0 ||
        outDistance < totalDistance * minLegFraction ||
        backDistance < totalDistance * minLegFraction) {
      return null;
    }

    final outGainLoss = elevationCalculator.compute(
        samples.sublist(0, peakIndex + 1).map((s) => s.elevation).toList());
    final backGainLoss = elevationCalculator.compute(
        samples.sublist(peakIndex).map((s) => s.elevation).toList());

    return _Legs(
      outDistance: outDistance,
      outGain: outGainLoss.gain,
      outLoss: outGainLoss.loss,
      backDistance: backDistance,
      backGain: backGainLoss.gain,
      backLoss: backGainLoss.loss,
    );
  }
}

class _Legs {
  const _Legs({
    required this.outDistance,
    required this.outGain,
    required this.outLoss,
    required this.backDistance,
    required this.backGain,
    required this.backLoss,
  });

  final double outDistance;
  final double outGain;
  final double outLoss;
  final double backDistance;
  final double backGain;
  final double backLoss;
}
