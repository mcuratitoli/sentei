import 'package:latlong2/latlong.dart';

import '../models/elevation_profile.dart' show TrailSegment;

/// Un tratto contiguo di un percorso instradato con lo stesso stato
/// libero/agganciato (§"Traccia mista", `docs/ROADMAP.md` P3).
typedef TrackRun = ({List<LatLng> points, bool free});

/// Come [TrackRun] ma con anche il **grado CAI** del tratto agganciato
/// (`caiScale` null = libero, oppure sentiero senza grado noto → linea piena).
/// §ROADMAP P1.B: resa dello stile-linea per difficoltà.
typedef StyledRun = ({List<LatLng> points, bool free, String? caiScale});

/// Ritaglia [routedPath] (il percorso finale, già concatenato e densificato
/// da BRouter) nei tratti liberi/agganciati originali, usando
/// [segmentPointCounts] (quanti punti ciascun segmento `waypoints[i]`→
/// `waypoints[i+1]` ha contribuito, esclude il primo condiviso) e
/// [freeSegments] (quali di quegli indici sono liberi). Tratti adiacenti con
/// lo stesso stato si fondono in un solo run.
///
/// **Puramente locale**: non richiama mai il routing — è pensata per la resa
/// tratteggiata di una traccia già salvata, che deve restare disponibile
/// offline. Se i dati non tornano (traccia mai passata da questa
/// funzionalità, o waypoint modificati senza rifare "Fine") ritorna un unico
/// tratto pieno invece di rischiare un accesso fuori indice.
List<TrackRun> sliceTrackRuns({
  required List<LatLng> routedPath,
  required List<int> segmentPointCounts,
  required Set<int> freeSegments,
}) {
  final totalCount = segmentPointCounts.fold<int>(0, (a, b) => a + b);
  if (routedPath.length < 2 ||
      segmentPointCounts.isEmpty ||
      totalCount != routedPath.length - 1) {
    return [(points: routedPath, free: false)];
  }
  final runs = <TrackRun>[];
  var cursor = 0;
  for (var i = 0; i < segmentPointCounts.length; i++) {
    final count = segmentPointCounts[i];
    final free = freeSegments.contains(i);
    final segPoints = routedPath.sublist(cursor, cursor + count + 1);
    if (runs.isNotEmpty && runs.last.free == free) {
      runs[runs.length - 1] =
          (points: [...runs.last.points, ...segPoints.skip(1)], free: free);
    } else {
      runs.add((points: segPoints, free: free));
    }
    cursor += count;
  }
  return runs;
}

String? _normScale(String? s) {
  final k = s?.toUpperCase().trim();
  return (k == null || k.isEmpty) ? null : k;
}

/// Come [sliceTrackRuns], ma spezza ulteriormente i tratti **agganciati** per
/// **grado CAI** ([TrailSegment.caiScale], per distanza cumulata lungo il
/// percorso), così la mappa può darne uno stile di linea diverso (§P1.B).
///
/// I tratti liberi restano un solo run con `caiScale: null`. Se [trailSegments]
/// è vuoto il risultato è quello di [sliceTrackRuns] con `caiScale: null` su
/// tutto (retrocompatibile). Puramente locale (haversine sui punti già
/// densificati), niente rete.
List<StyledRun> sliceStyledRuns({
  required List<LatLng> routedPath,
  required List<int> segmentPointCounts,
  required Set<int> freeSegments,
  required List<TrailSegment> trailSegments,
}) {
  final base = sliceTrackRuns(
    routedPath: routedPath,
    segmentPointCounts: segmentPointCounts,
    freeSegments: freeSegments,
  );
  if (trailSegments.isEmpty) {
    return [
      for (final r in base) (points: r.points, free: r.free, caiScale: null),
    ];
  }

  // Distanza cumulata dell'intero percorso, indicizzata come routedPath.
  const distance = Distance();
  final cum = List<double>.filled(routedPath.length, 0);
  for (var i = 1; i < routedPath.length; i++) {
    cum[i] = cum[i - 1] + distance(routedPath[i - 1], routedPath[i]);
  }

  String? scaleAt(double d) {
    for (final s in trailSegments) {
      if (d >= s.fromMeters && d <= s.toMeters) return _normScale(s.caiScale);
    }
    return null;
  }

  final out = <StyledRun>[];
  // I run di base condividono il punto di giunzione: il run k+1 parte dove
  // finisce il run k. `offset` = indice in routedPath del primo punto del run.
  var offset = 0;
  for (final r in base) {
    if (r.free) {
      out.add((points: r.points, free: true, caiScale: null));
    } else {
      final n = r.points.length;
      var start = 0;
      var cur = scaleAt(cum[offset]);
      for (var k = 1; k < n; k++) {
        final sc = scaleAt(cum[offset + k]);
        if (sc != cur) {
          out.add((
            points: r.points.sublist(start, k + 1),
            free: false,
            caiScale: cur,
          ));
          start = k;
          cur = sc;
        }
      }
      out.add((points: r.points.sublist(start), free: false, caiScale: cur));
    }
    offset += r.points.length - 1;
  }
  return out;
}
