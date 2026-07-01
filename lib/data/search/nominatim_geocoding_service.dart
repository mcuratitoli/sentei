import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'geocoding_service.dart';

/// Geocoding via **Nominatim** (OpenStreetMap): copertura eccellente per POI
/// alpini — rifugi (`tourism=alpine_hut`), vette (`natural=peak`), passi
/// (`natural=saddle`), laghi, ecc. — che Mapbox Geocoding spesso non indicizza.
///
/// Policy Nominatim: max 1 req/s; User-Agent obbligatorio. Il debounce UI
/// (350 ms) garantisce già il rispetto del rate limit.
class NominatimGeocodingService {
  NominatimGeocodingService({
    http.Client? client,
    this.endpoint = 'https://nominatim.openstreetmap.org/search',
    this.reverseEndpoint = 'https://nominatim.openstreetmap.org/reverse',
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String endpoint;
  final String reverseEndpoint;
  final Duration timeout;

  // Paesi dell'arco alpino (IT, CH, FR, AT + SI per completezza).
  static const _countryCodes = 'it,ch,fr,at,si';

  // User-Agent obbligatorio per la Nominatim Usage Policy.
  static const _userAgent = 'sentei/1.0 (app escursionismo Alpi)';

  /// Reverse geocoding: dal punto [point] ricava località, provincia e nazione
  /// (via Nominatim `/reverse`). `null` su errore di rete.
  Future<ReversePlace?> reverse(LatLng point) async {
    final uri = Uri.parse(reverseEndpoint).replace(queryParameters: {
      'lat': point.latitude.toString(),
      'lon': point.longitude.toString(),
      'format': 'jsonv2',
      'addressdetails': '1',
      'zoom': '14', // livello "villaggio/quartiere": nome località sensato
    });
    try {
      final res = await _client
          .get(uri, headers: {
            'User-Agent': _userAgent,
            'Accept-Language': 'it,en',
          })
          .timeout(timeout);
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = json['address'] as Map<String, dynamic>? ?? const {};
      final locality = (addr['city'] ??
              addr['town'] ??
              addr['village'] ??
              addr['municipality'] ??
              addr['hamlet'] ??
              addr['locality'])
          ?.toString();
      // In Italia `county` è la provincia; altrove ripiega su `state`.
      final province =
          (addr['county'] ?? addr['state_district'] ?? addr['state'])
              ?.toString();
      final country = addr['country']?.toString();
      return ReversePlace(
        locality: locality,
        province: province,
        country: country,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<GeocodeResult>> search(String query, {LatLng? proximity}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final params = <String, String>{
      'q': q,
      'format': 'jsonv2',
      'limit': '8',
      'countrycodes': _countryCodes,
      'addressdetails': '1',
      'namedetails': '1',
      'dedupe': '1',
    };

    // Viewbox ±2.5° centrato sulla mappa: favorisce i risultati nell'area
    // correntemente visualizzata, senza escludere il resto dell'arco alpino.
    if (proximity != null) {
      const d = 2.5;
      params['viewbox'] =
          '${proximity.longitude - d},${proximity.latitude + d},'
          '${proximity.longitude + d},${proximity.latitude - d}';
      params['bounded'] = '0';
    }

    final uri = Uri.parse(endpoint).replace(queryParameters: params);
    try {
      final res = await _client
          .get(uri, headers: {
            'User-Agent': _userAgent,
            'Accept-Language': 'it,en',
          })
          .timeout(timeout);
      if (res.statusCode != 200) return const [];
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.map(_toResult).whereType<GeocodeResult>().toList();
    } catch (_) {
      return const [];
    }
  }

  static GeocodeResult? _toResult(dynamic item) {
    final el = item as Map<String, dynamic>;
    final lat = double.tryParse(el['lat']?.toString() ?? '');
    final lon = double.tryParse(el['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;

    // Preferisce la variante italiana del nome se disponibile.
    final nd = el['namedetails'] as Map<String, dynamic>? ?? {};
    final rawName =
        (nd['name:it'] ?? nd['name'] ?? el['name'] ?? '').toString().trim();
    if (rawName.isEmpty) return null;

    // Contesto: comune + regione (+ paese se non IT, per CH/FR/AT).
    final addr = el['address'] as Map<String, dynamic>? ?? {};
    final locality = addr['municipality']?.toString() ??
        addr['city']?.toString() ??
        addr['town']?.toString() ??
        addr['village']?.toString() ??
        '';
    final region =
        addr['state']?.toString() ?? addr['county']?.toString() ?? '';
    final countryCode = addr['country_code']?.toString() ?? 'it';
    final country =
        countryCode != 'it' ? (addr['country']?.toString() ?? '') : '';
    final context = [locality, region, country]
        .where((s) => s.isNotEmpty)
        .join(', ');

    return GeocodeResult(
      name: rawName,
      context: context,
      center: LatLng(lat, lon),
    );
  }
}
