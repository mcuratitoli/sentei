import 'package:latlong2/latlong.dart';

import 'path_geometry.dart';

/// Semplificazione di polilinee (Douglas-Peucker) per l'import: da migliaia di
/// punti GPS a pochi **waypoint di controllo** posti sulle svolte significative,
/// così la traccia importata diventa modificabile e instradabile.
class PolylineSimplifier {
  const PolylineSimplifier();

  static const _geo = PathGeometry();

  /// Indici dei punti mantenuti da Douglas-Peucker (estremi inclusi), con errore
  /// massimo [toleranceMeters]. Iterativo (stack) per reggere tracce molto lunghe.
  List<int> douglasPeuckerIndices(List<LatLng> pts, double toleranceMeters) {
    final n = pts.length;
    if (n <= 2) return [for (var i = 0; i < n; i++) i];
    final keep = List<bool>.filled(n, false);
    keep[0] = true;
    keep[n - 1] = true;
    final stack = <List<int>>[
      [0, n - 1]
    ];
    while (stack.isNotEmpty) {
      final range = stack.removeLast();
      final lo = range[0];
      final hi = range[1];
      if (hi - lo < 2) continue;
      final seg = [pts[lo], pts[hi]];
      var maxD = 0.0;
      var idx = -1;
      for (var i = lo + 1; i < hi; i++) {
        final d = _geo.distanceToPath(pts[i], seg);
        if (d > maxD) {
          maxD = d;
          idx = i;
        }
      }
      if (maxD > toleranceMeters && idx != -1) {
        keep[idx] = true;
        stack.add([lo, idx]);
        stack.add([idx, hi]);
      }
    }
    return [for (var i = 0; i < n; i++) if (keep[i]) i];
  }

  /// Indici semplificati con **cap adattivo**: parte da [tolerance] e la aumenta
  /// finché il numero di punti mantenuti rientra in [maxPoints].
  List<int> simplifyIndices(
    List<LatLng> pts, {
    double tolerance = 30,
    int maxPoints = 40,
  }) {
    if (pts.length <= maxPoints) {
      return [for (var i = 0; i < pts.length; i++) i];
    }
    var tol = tolerance;
    var idx = douglasPeuckerIndices(pts, tol);
    var guard = 0;
    while (idx.length > maxPoints && guard++ < 24) {
      tol *= 1.6;
      idx = douglasPeuckerIndices(pts, tol);
    }
    return idx;
  }
}
