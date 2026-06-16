import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../domain/services/routing_service.dart';

/// Instradamento escursionistico tramite il servizio web pubblico **BRouter**
/// (https://brouter.de), basato su OSM e senza API key (§6.2).
///
/// Restituisce la geometria che segue i sentieri più distanza, dislivello
/// filtrato e quota per punto, tutto in un'unica chiamata. È lo stesso motore
/// previsto per l'offline in Fase 2.
class BRouterRoutingService implements RoutingService {
  BRouterRoutingService({
    http.Client? client,
    this.baseUrl = 'https://brouter.de/brouter',
    this.defaultProfile = 'hiking-mountain',
    this.timeout = const Duration(seconds: 20),
    this.maxAttempts = 3,
    this.retryDelay = const Duration(milliseconds: 500),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final String defaultProfile;
  final Duration timeout;

  /// Tentativi totali per richiesta. Il server pubblico BRouter a volte uccide
  /// il calcolo ("operation killed by thread-priority-watchdog") sotto carico:
  /// un nuovo tentativo spesso riesce.
  final int maxAttempts;
  final Duration retryDelay;

  @override
  Future<RouteResult> route(List<LatLng> waypoints, {String? profile}) async {
    if (waypoints.length < 2) {
      throw const RoutingException('Servono almeno 2 punti');
    }

    final lonlats =
        waypoints.map((p) => '${p.longitude},${p.latitude}').join('|');
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'lonlats': lonlats,
      'profile': profile ?? defaultProfile,
      'alternativeidx': '0',
      'format': 'geojson',
    });

    RoutingException last = const RoutingException('routing non riuscito');
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final res = await _client.get(uri).timeout(timeout);
        if (res.statusCode == 200) return parseGeoJson(res.body);
        last = RoutingException('BRouter HTTP ${res.statusCode}: '
            '${res.body.trim()}');
      } catch (e) {
        last = RoutingException('Rete/timeout: $e');
      }
      if (attempt < maxAttempts) {
        debugPrint('[routing] tentativo $attempt fallito (${last.message}), '
            'ritento…');
        await Future<void>.delayed(retryDelay);
      }
    }
    throw last;
  }

  /// Parsa la risposta GeoJSON di BRouter. Esposto per i test.
  static RouteResult parseGeoJson(String body) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw RoutingException('Risposta non valida: ${body.trim()}');
    }

    final features = json['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      throw const RoutingException('Nessun percorso trovato');
    }
    final feature = features.first as Map<String, dynamic>;
    final coords =
        (feature['geometry'] as Map<String, dynamic>)['coordinates'] as List;

    final geometry = <LatLng>[];
    final elevations = <double?>[];
    for (final c in coords) {
      final coord = c as List;
      final lon = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      geometry.add(LatLng(lat, lon));
      elevations.add(coord.length > 2 ? (coord[2] as num).toDouble() : null);
    }

    final props = (feature['properties'] as Map<String, dynamic>?) ?? const {};
    return RouteResult(
      geometry: geometry,
      elevations: elevations,
      lengthMeters: _numProp(props['track-length']),
      ascentMeters: _numProp(props['filtered ascend']),
    );
  }

  static double? _numProp(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString());
  }
}
