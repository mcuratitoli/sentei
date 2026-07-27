/// Formattazioni per la UI (unità metriche).
abstract final class Format {
  /// Distanza: metri sotto 1 km, altrimenti km con un decimale.
  static String distance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Quota/dislivello in metri arrotondati.
  static String meters(double m) => '${m.round()} m';

  /// Coordinate in gradi decimali con emisfero (N/S, E/O) — stesso formato
  /// ovunque siano mostrate (punto ispezionato in esplorazione, foto).
  static String coordinates(double latitude, double longitude) {
    final ns = latitude >= 0 ? 'N' : 'S';
    final ew = longitude >= 0 ? 'E' : 'O';
    return '${latitude.abs().toStringAsFixed(5)}°$ns  '
        '${longitude.abs().toStringAsFixed(5)}°$ew';
  }

  /// Data e ora locali, es. "18/08/2025 14:32".
  static String dateTime(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}/${l.year} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
