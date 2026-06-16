/// Risultato del calcolo di dislivello.
class ElevationGainLoss {
  const ElevationGainLoss({required this.gain, required this.loss});

  /// Dislivello positivo cumulato D+ (metri).
  final double gain;

  /// Dislivello negativo cumulato D- (metri, valore non negativo).
  final double loss;

  @override
  String toString() => 'ElevationGainLoss(D+: $gain m, D-: $loss m)';
}

/// Calcolo di dislivello D+/D- da una serie di quote campionate lungo il path
/// (§6.3 del CLAUDE.md).
///
/// Il DEM (Terrarium) è rumoroso: sommare ogni micro-variazione gonfia il D+.
/// Applichiamo un **filtro a soglia (deadband)**: una variazione viene
/// contabilizzata solo quando si discosta di almeno [thresholdMeters] dall'ultima
/// quota "significativa". Le salite graduali restano contate (a blocchi), mentre
/// il rumore sotto-soglia viene scartato. Algoritmo deterministico e testabile.
class ElevationCalculator {
  const ElevationCalculator({this.thresholdMeters = 8});

  /// Soglia di rumore: variazioni minori vengono ignorate. Tipico 5–10 m (§6.3).
  final double thresholdMeters;

  /// Calcola D+/D- da una lista di quote (metri). Le quote `null` (campioni
  /// mancanti) vengono saltate. Ritorna zero per meno di 2 quote valide.
  ElevationGainLoss compute(List<double?> elevations) {
    assert(thresholdMeters >= 0, 'thresholdMeters non può essere negativo');

    double? anchor;
    var gain = 0.0;
    var loss = 0.0;

    for (final e in elevations) {
      if (e == null) continue;
      if (anchor == null) {
        anchor = e;
        continue;
      }
      final delta = e - anchor;
      if (delta.abs() >= thresholdMeters) {
        if (delta > 0) {
          gain += delta;
        } else {
          loss += -delta;
        }
        anchor = e;
      }
    }
    return ElevationGainLoss(gain: gain, loss: loss);
  }
}
