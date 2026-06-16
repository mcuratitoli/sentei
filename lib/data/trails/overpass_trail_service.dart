import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Recupera i **numeri dei sentieri** (tag `ref` delle relazioni
/// `route=hiking` OSM, es. CAI "203") attraversati da un percorso, via
/// **Overpass API**. Best-effort: in caso di errore/timeout ritorna lista vuota
/// (i tag sono un di più, non devono bloccare nulla).
class OverpassTrailService {
  OverpassTrailService({
    http.Client? client,
    this.endpoint = 'https://overpass-api.de/api/interpreter',
    this.timeout = const Duration(seconds: 25),
    this.maxPoints = 30,
    this.aroundMeters = 40,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String endpoint;
  final Duration timeout;

  /// Punti massimi campionati dal percorso (per non gonfiare la query).
  final int maxPoints;

  /// Raggio (m) entro cui cercare i sentieri attorno ai punti campionati.
  final int aroundMeters;

  Future<List<String>> trailRefsAlong(List<LatLng> path) async {
    if (path.length < 2) return const [];

    final sample = _sample(path, maxPoints);
    final coords =
        sample.map((p) => '${p.latitude},${p.longitude}').join(',');
    final query = '[out:json][timeout:25];'
        'way(around:$aroundMeters,$coords)["highway"];'
        'rel(bw)["route"="hiking"];'
        'out tags;';

    try {
      final res = await _client
          .post(
            Uri.parse(endpoint),
            headers: const {'User-Agent': 'sentei/0.1 (hiking app)'},
            body: {'data': query},
          )
          .timeout(timeout);
      if (res.statusCode != 200) return const [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final elements = (data['elements'] as List?) ?? const [];
      final refs = <String>{};
      for (final e in elements) {
        final tags = (e as Map)['tags'] as Map?;
        final ref = tags?['ref'];
        if (ref is String && ref.trim().isNotEmpty) refs.add(ref.trim());
      }
      final list = refs.toList()..sort();
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// Campiona al massimo [max] punti dal percorso, estremi inclusi.
  List<LatLng> _sample(List<LatLng> path, int max) {
    if (path.length <= max) return path;
    final step = (path.length / max).ceil();
    final out = <LatLng>[];
    for (var i = 0; i < path.length; i += step) {
      out.add(path[i]);
    }
    if (out.last != path.last) out.add(path.last);
    return out;
  }
}
