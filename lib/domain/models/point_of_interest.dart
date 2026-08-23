import 'package:latlong2/latlong.dart';

/// Categoria di un punto interessante rilevato lungo il percorso (§export
/// immagine, `docs/ROADMAP.md`). Mappata a un sottoinsieme di tag OSM in
/// `data/poi/overpass_poi_service.dart`.
enum PoiCategory { rifugio, alpe, lago, colle, cima }

extension PoiCategoryLabel on PoiCategory {
  String get label => switch (this) {
        PoiCategory.rifugio => 'Rifugio',
        PoiCategory.alpe => 'Alpeggio',
        PoiCategory.lago => 'Lago',
        PoiCategory.colle => 'Colle',
        PoiCategory.cima => 'Cima',
      };
}

/// Punto interessante grezzo (nodo OSM), prima di sapere se è vicino a un
/// percorso — fonte-agnostico: chi lo produce (oggi Overpass) non deve
/// trapelare nel dominio, stesso principio di `RawPhotoLocation`.
class RawPointOfInterest {
  const RawPointOfInterest({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
  });

  final String id;
  final String name;
  final PoiCategory category;
  final LatLng position;
}

/// Punto interessante risultato vicino a un percorso dopo
/// [NearbyPoisMatcher.match]: come [RawPointOfInterest], con in più la
/// distanza dal percorso e la distanza cumulata lungo il percorso.
class PoiCandidate {
  const PoiCandidate({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
    required this.distanceToPathMeters,
    required this.distanceAlongPathMeters,
  });

  final String id;
  final String name;
  final PoiCategory category;
  final LatLng position;
  final double distanceToPathMeters;
  final double distanceAlongPathMeters;
}
