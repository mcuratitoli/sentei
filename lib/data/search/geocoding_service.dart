import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Un risultato di ricerca luogo (geocoding).
class GeocodeResult {
  const GeocodeResult({
    required this.name,
    required this.context,
    required this.center,
  });

  /// Nome principale del luogo (es. "Alagna Valsesia").
  final String name;

  /// Contesto/indirizzo esteso (es. "Vercelli, Piemonte, Italia").
  final String context;

  /// Coordinate del luogo.
  final LatLng center;
}

/// Ricerca di località tramite **Mapbox Geocoding v6** (forward geocoding).
/// Riusa lo stesso token pubblico `pk` delle mappe (via `--dart-define`).
class GeocodingService {
  GeocodingService({String? token, http.Client? client})
      : _token = token ?? const String.fromEnvironment('MAPBOX_TOKEN'),
        _client = client ?? http.Client();

  final String _token;
  final http.Client _client;

  bool get hasToken => _token.isNotEmpty;

  /// Cerca [query]; [proximity] (centro mappa) ordina i risultati per vicinanza.
  Future<List<GeocodeResult>> search(String query, {LatLng? proximity}) async {
    final q = query.trim();
    if (q.isEmpty || _token.isEmpty) return const [];
    final params = <String, String>{
      'q': q,
      'access_token': _token,
      'limit': '6',
      'language': 'it',
      if (proximity != null)
        'proximity': '${proximity.longitude},${proximity.latitude}',
    };
    final uri = Uri.https('api.mapbox.com', '/search/geocode/v6/forward', params);
    try {
      final res = await _client.get(uri);
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final features = (json['features'] as List?) ?? const [];
      final out = <GeocodeResult>[];
      for (final f in features) {
        final feature = f as Map<String, dynamic>;
        final props = feature['properties'] as Map<String, dynamic>?;
        final geom = feature['geometry'] as Map<String, dynamic>?;
        final coords = geom?['coordinates'] as List?;
        if (coords == null || coords.length < 2) continue;
        final name = (props?['name'] ?? '').toString();
        final full =
            (props?['full_address'] ?? props?['place_formatted'] ?? '').toString();
        out.add(GeocodeResult(
          name: name.isNotEmpty ? name : full,
          context: full == name ? '' : full,
          center: LatLng(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          ),
        ));
      }
      return out;
    } catch (_) {
      return const []; // best-effort: nessun risultato su errore di rete
    }
  }
}
