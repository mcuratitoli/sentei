import 'dart:math' as math;

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

  /// Distanza minima in metri tra [p] e la spezzata [path] (punto→segmento).
  /// Serve a capire se un tap sulla mappa "colpisce" il tracciato. Ritorna
  /// `double.infinity` per percorsi vuoti.
  ///
  /// Proiezione equirettangolare locale attorno a [p]: precisa alle distanze
  /// in gioco (poche decine di metri).
  double distanceToPath(LatLng p, List<LatLng> path) {
    if (path.isEmpty) return double.infinity;
    if (path.length == 1) return distance(p, path.first);

    const mPerDegLat = 111320.0;
    final mPerDegLon = mPerDegLat * math.cos(p.latitude * math.pi / 180.0);
    double x(LatLng q) => (q.longitude - p.longitude) * mPerDegLon;
    double y(LatLng q) => (q.latitude - p.latitude) * mPerDegLat;

    var best = double.infinity;
    for (var i = 0; i < path.length - 1; i++) {
      final ax = x(path[i]), ay = y(path[i]);
      final bx = x(path[i + 1]), by = y(path[i + 1]);
      final dx = bx - ax, dy = by - ay;
      final lenSq = dx * dx + dy * dy;
      final t = lenSq == 0 ? 0.0 : ((-ax) * dx + (-ay) * dy) / lenSq;
      final tc = t.clamp(0.0, 1.0);
      final px = ax + dx * tc, py = ay + dy * tc;
      final d = math.sqrt(px * px + py * py);
      if (d < best) best = d;
    }
    return best;
  }

  /// Come [distanceToPath], ma ritorna **anche** la distanza cumulata lungo
  /// [path] (in metri, dall'inizio) nel punto più vicino a [p]. Serve al
  /// piazzamento di un elemento esterno (es. una foto geolocalizzata) sul
  /// grafico del profilo altimetrico, il cui asse X è la distanza-lungo-
  /// percorso — non serve alcun dato temporale sulla traccia.
  ///
  /// Ritorna `distanceToPath: infinity, distanceAlongPath: 0` per percorsi vuoti.
  ({double distanceToPath, double distanceAlongPath}) nearestOnPath(
      LatLng p, List<LatLng> path) {
    if (path.isEmpty) {
      return (distanceToPath: double.infinity, distanceAlongPath: 0);
    }
    if (path.length == 1) {
      return (distanceToPath: distance(p, path.first), distanceAlongPath: 0);
    }

    const mPerDegLat = 111320.0;
    final mPerDegLon = mPerDegLat * math.cos(p.latitude * math.pi / 180.0);
    double x(LatLng q) => (q.longitude - p.longitude) * mPerDegLon;
    double y(LatLng q) => (q.latitude - p.latitude) * mPerDegLat;

    var best = double.infinity;
    var bestAlong = 0.0;
    var cumulative = 0.0;
    for (var i = 0; i < path.length - 1; i++) {
      final segLen = distance(path[i], path[i + 1]);
      final ax = x(path[i]), ay = y(path[i]);
      final bx = x(path[i + 1]), by = y(path[i + 1]);
      final dx = bx - ax, dy = by - ay;
      final lenSq = dx * dx + dy * dy;
      final t = lenSq == 0 ? 0.0 : ((-ax) * dx + (-ay) * dy) / lenSq;
      final tc = t.clamp(0.0, 1.0);
      final px = ax + dx * tc, py = ay + dy * tc;
      final d = math.sqrt(px * px + py * py);
      if (d < best) {
        best = d;
        bestAlong = cumulative + segLen * tc;
      }
      cumulative += segLen;
    }
    return (distanceToPath: best, distanceAlongPath: bestAlong);
  }
}
