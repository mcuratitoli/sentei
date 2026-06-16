import 'package:latlong2/latlong.dart';

/// Calcoli di distanza e densificazione di un percorso (§6.3 del CLAUDE.md).
///
/// Logica pura e deterministica: nessuna dipendenza da UI o rete, così da
/// essere coperta da test (§9). Nota: il nome evita il clash con la classe
/// `DistanceCalculator` esportata da latlong2.
class PathGeometry {
  const PathGeometry({this.distance = const Distance()});

  /// Strategia di distanza geodetica (default: haversine di latlong2).
  final Distance distance;

  /// Distanza totale del percorso in metri (somma haversine cumulativa).
  ///
  /// Ritorna 0 per percorsi con meno di 2 punti.
  double totalDistance(List<LatLng> points) {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += distance(points[i], points[i + 1]);
    }
    return total;
  }

  /// Densifica il percorso inserendo punti intermedi a passo ~[stepMeters],
  /// così da campionare l'elevazione in modo uniforme lungo il path (§6.3).
  ///
  /// Interpolazione lineare in lat/lon: l'errore è trascurabile a passi brevi
  /// (10–25 m). I vertici originali sono sempre preservati.
  List<LatLng> densify(List<LatLng> points, {double stepMeters = 15}) {
    assert(stepMeters > 0, 'stepMeters deve essere positivo');
    if (points.length < 2) return List<LatLng>.of(points);

    final result = <LatLng>[points.first];
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final segment = distance(a, b);
      final steps = (segment / stepMeters).floor();
      for (var s = 1; s <= steps; s++) {
        final t = (s * stepMeters) / segment;
        if (t >= 1) break;
        result.add(_lerp(a, b, t));
      }
      result.add(b);
    }
    return result;
  }

  LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
}
