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
  });

  /// Velocità di riferimento in piano (km/h). Default CAI: 4 km/h.
  final double flatSpeedKmh;

  /// Velocità di riferimento in salita (m/h). Default CAI: 300 m/h.
  final double ascentMetersPerHour;

  /// Velocità di riferimento in discesa (m/h). Default CAI: 500 m/h.
  final double descentMetersPerHour;

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
}
