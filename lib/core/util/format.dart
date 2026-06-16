/// Formattazioni per la UI (unità metriche).
abstract final class Format {
  /// Distanza: metri sotto 1 km, altrimenti km con un decimale.
  static String distance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Quota/dislivello in metri arrotondati.
  static String meters(double m) => '${m.round()} m';
}
