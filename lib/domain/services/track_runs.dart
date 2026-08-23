import 'package:latlong2/latlong.dart';

/// Un tratto contiguo di un percorso instradato con lo stesso stato
/// libero/agganciato (§"Traccia mista", `docs/ROADMAP.md` P3).
typedef TrackRun = ({List<LatLng> points, bool free});

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
