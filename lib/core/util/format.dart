/// Formattazioni per la UI (unità metriche).
abstract final class Format {
  /// Distanza: metri sotto 1 km, altrimenti km con un decimale.
  static String distance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Quota/dislivello in metri arrotondati.
  static String meters(double m) => '${m.round()} m';

  /// Durata: "Xh Ymin" oltre l'ora, altrimenti "Y min" (arrotondata al
  /// minuto). Sotto il minuto: "meno di 1 min".
  static String duration(Duration d) {
    final totalMinutes = d.inMinutes;
    if (totalMinutes < 1) return 'meno di 1 min';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}min';
  }

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

  static const _months = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];

  /// Data lunga in italiano, es. "18 agosto 2025" (giorno locale, senza ora).
  static String longDate(DateTime d) {
    final l = d.toLocal();
    return '${l.day} ${_months[l.month - 1]} ${l.year}';
  }
}
