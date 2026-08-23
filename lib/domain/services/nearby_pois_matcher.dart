import 'package:latlong2/latlong.dart';

import '../models/point_of_interest.dart';
import 'path_geometry.dart';

/// Filtra, ordina e limita i punti interessanti (rifugi, alpeggi, laghi,
/// colli, cime) per rilevanza rispetto a un percorso — stessa logica di
/// `NearbyPhotosMatcher`, ma per l'export immagine (mappa 3D + tracciato,
/// `docs/ROADMAP.md`).
class NearbyPoisMatcher {
  const NearbyPoisMatcher({this.geometry = const PathGeometry()});

  final PathGeometry geometry;

  /// Soglia (m) oltre la quale un POI non è considerato "sul percorso": più
  /// larga di quella foto (80 m) perché rifugi/alpeggi/laghi spesso stanno a
  /// qualche centinaio di metri dal sentiero tracciato, non esattamente sopra.
  static const double defaultThresholdMeters = 500;

  /// Quanti punti mostrare al massimo nel foglio di scelta: oltre non aiuta
  /// più a "riassumere" il percorso (una traccia lunga può incrociare
  /// decine di località).
  static const int defaultMaxResults = 10;

  /// Ritorna i POI entro [thresholdMeters] dal percorso, ordinati per
  /// distanza-lungo-percorso crescente (l'ordine in cui si incontrano
  /// camminando). Quando ce ne sono più di [maxResults], tiene i più vicini
  /// al percorso (non necessariamente i primi incontrati).
  List<PoiCandidate> match({
    required List<LatLng> routedPath,
    required List<RawPointOfInterest> pois,
    double thresholdMeters = defaultThresholdMeters,
    int maxResults = defaultMaxResults,
  }) {
    if (routedPath.length < 2 || pois.isEmpty) return const [];

    final candidates = <PoiCandidate>[];
    for (final poi in pois) {
      final nearest = geometry.nearestOnPath(poi.position, routedPath);
      if (nearest.distanceToPath <= thresholdMeters) {
        candidates.add(PoiCandidate(
          id: poi.id,
          name: poi.name,
          category: poi.category,
          position: poi.position,
          distanceToPathMeters: nearest.distanceToPath,
          distanceAlongPathMeters: nearest.distanceAlongPath,
        ));
      }
    }
    if (candidates.length > maxResults) {
      candidates.sort(
          (a, b) => a.distanceToPathMeters.compareTo(b.distanceToPathMeters));
      candidates.removeRange(maxResults, candidates.length);
    }
    candidates.sort((a, b) =>
        a.distanceAlongPathMeters.compareTo(b.distanceAlongPathMeters));
    return candidates;
  }
}
