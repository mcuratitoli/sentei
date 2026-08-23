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

  /// Distanza minima (m) tra due POI **tra loro** (non dal percorso): sotto
  /// questa soglia sono lo stesso "posto" ai fini dell'immagine esportata
  /// (es. più alpeggi a poche decine di metri) — le etichette a pillola si
  /// accavallerebbero illeggibili. Ne resta uno solo per gruppo.
  static const double defaultMinSpacingMeters = 150;

  /// Ordine di priorità **tra categorie diverse** quando due POI risultano
  /// troppo vicini: un rifugio nasce spesso proprio su un alpeggio (stesso
  /// punto sulla mappa, nomi diversi) — senza priorità la deduplicazione
  /// teneva "quello incontrato prima camminando", scartando a caso il
  /// rifugio (il punto più interessante dei due) invece dell'alpeggio.
  static const List<PoiCategory> _categoryPriority = [
    PoiCategory.rifugio,
    PoiCategory.cima,
    PoiCategory.colle,
    PoiCategory.lago,
    PoiCategory.alpe,
  ];

  /// Ritorna i POI entro [thresholdMeters] dal percorso, deduplicati fra loro
  /// (min [minSpacingMeters] uno dall'altro — a parità tra due punti vicini,
  /// vince la categoria più in alto in [_categoryPriority]) e ordinati per
  /// distanza-lungo-percorso crescente (l'ordine in cui si incontrano
  /// camminando). Quando restano più di [maxResults], tiene i più vicini al
  /// percorso (non necessariamente i primi incontrati).
  List<PoiCandidate> match({
    required List<LatLng> routedPath,
    required List<RawPointOfInterest> pois,
    double thresholdMeters = defaultThresholdMeters,
    int maxResults = defaultMaxResults,
    double minSpacingMeters = defaultMinSpacingMeters,
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

    // Deduplica in ordine di priorità di categoria (non di percorso): un
    // rifugio processato prima "vince" il suo spazio anche se un alpeggio
    // omonimo/coincidente verrebbe incontrato prima camminando.
    final byPriority = [...candidates]..sort((a, b) {
        final pa = _categoryPriority.indexOf(a.category);
        final pb = _categoryPriority.indexOf(b.category);
        if (pa != pb) return pa.compareTo(pb);
        return a.distanceAlongPathMeters.compareTo(b.distanceAlongPathMeters);
      });
    final deduped = <PoiCandidate>[];
    for (final c in byPriority) {
      final tooClose = deduped.any((kept) =>
          geometry.distance(kept.position, c.position) < minSpacingMeters);
      if (!tooClose) deduped.add(c);
    }
    deduped.sort((a, b) =>
        a.distanceAlongPathMeters.compareTo(b.distanceAlongPathMeters));

    if (deduped.length > maxResults) {
      deduped.sort(
          (a, b) => a.distanceToPathMeters.compareTo(b.distanceToPathMeters));
      deduped.removeRange(maxResults, deduped.length);
      deduped.sort((a, b) =>
          a.distanceAlongPathMeters.compareTo(b.distanceAlongPathMeters));
    }
    return deduped;
  }
}
