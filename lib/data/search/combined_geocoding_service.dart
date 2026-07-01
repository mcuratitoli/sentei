import 'package:latlong2/latlong.dart';

import 'geocoding_service.dart';
import 'nominatim_geocoding_service.dart';

/// Servizio di geocoding ibrido: interroga **Nominatim** (OSM) e **Mapbox**
/// in parallelo, unendo i risultati con Nominatim in testa.
///
/// Nominatim è la fonte primaria perché ha `tourism=alpine_hut`, `natural=peak`,
/// `natural=saddle` ecc. — POI alpini che Mapbox spesso non indicizza.
/// Mapbox integra risultati per città/indirizzi non presenti in Nominatim.
class CombinedGeocodingService {
  CombinedGeocodingService({
    GeocodingService? mapbox,
    NominatimGeocodingService? nominatim,
  })  : _mapbox = mapbox ?? GeocodingService(),
        _nominatim = nominatim ?? NominatimGeocodingService();

  final GeocodingService _mapbox;
  final NominatimGeocodingService _nominatim;

  /// Cerca [query] interrogando Nominatim e Mapbox in parallelo.
  /// I risultati Nominatim appaiono per primi; i risultati Mapbox vengono
  /// aggiunti solo se non sono duplicati (nessun risultato Nominatim entro
  /// 500 m).
  Future<List<GeocodeResult>> search(String query, {LatLng? proximity}) async {
    final futures = [
      _nominatim.search(query, proximity: proximity),
      if (_mapbox.hasToken) _mapbox.search(query, proximity: proximity),
    ];
    final results = await Future.wait(futures);

    final nominatimResults = results[0];
    final mapboxResults = results.length > 1 ? results[1] : const <GeocodeResult>[];

    return _merge(nominatimResults, mapboxResults);
  }

  /// Reverse geocoding (coordinate → località/provincia/nazione) via Nominatim.
  Future<ReversePlace?> reverse(LatLng point) => _nominatim.reverse(point);

  static List<GeocodeResult> _merge(
    List<GeocodeResult> primary,
    List<GeocodeResult> secondary,
  ) {
    if (secondary.isEmpty) return primary;
    const dist = Distance();
    const dedupeThreshold = 500.0; // metri

    final merged = List<GeocodeResult>.from(primary);
    for (final r in secondary) {
      final isDuplicate = merged.any(
        (existing) => dist(existing.center, r.center) < dedupeThreshold,
      );
      if (!isDuplicate) merged.add(r);
    }
    return merged;
  }
}
