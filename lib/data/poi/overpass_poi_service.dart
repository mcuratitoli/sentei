import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../domain/models/point_of_interest.dart';

/// Recupera i **punti interessanti** (rifugi, alpeggi, laghi, colli/passi,
/// cime) attraversati da un percorso, via **Overpass API** — stessa fonte e
/// stesso spirito "best-effort" di `OverpassTrailService`: qui però mai
/// un'eccezione verso il chiamante, solo lista vuota in caso di errore (i
/// POI sono un arricchimento dell'export immagine, non devono bloccarlo).
///
/// Tag OSM per categoria (attribuzione ODbL, §4 CLAUDE.md):
/// - **rifugio**: `tourism=alpine_hut|wilderness_hut|hut`, `amenity=shelter`
///   (include i bivacchi non presidiati).
/// - **alpe**: `place=locality|isolated_dwelling` **con nome che contiene
///   "alp"** — l'alpeggio non ha un tag OSM dedicato univoco, è
///   un'euristica sul nome (funziona bene nell'arco alpino italiano: "Alpe
///   X", "Alpi X"), quindi filtrata **lato client** dopo lo scarico.
/// - **lago**: `natural=water` con nome.
/// - **colle**: `mountain_pass=yes` o `natural=saddle` con nome.
/// - **cima**: `natural=peak` con nome.
class OverpassPoiService {
  OverpassPoiService({
    http.Client? client,
    this.endpoint = 'https://overpass-api.de/api/interpreter',
    this.timeout = const Duration(seconds: 25),
    this.maxPoints = 30,
    this.aroundMeters = 600,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String endpoint;
  final Duration timeout;

  /// Punti massimi campionati dal percorso (per non gonfiare la query).
  final int maxPoints;

  /// Raggio (m) di ricerca attorno ai punti campionati del percorso — più
  /// largo della soglia di match (`NearbyPoisMatcher`, 500 m) per non perdere
  /// POI vicini a un punto non campionato.
  final int aroundMeters;

  static final RegExp _alpNamePattern = RegExp(r'\balp\w*', caseSensitive: false);

  /// Scarica i nodi OSM rilevanti nel raggio del percorso. Nessuna eccezione:
  /// qualunque errore (rete, timeout, parsing) ritorna lista vuota.
  Future<List<RawPointOfInterest>> fetch(List<LatLng> path) async {
    if (path.length < 2) return const [];
    try {
      return await _fetchOrThrow(path);
    } catch (_) {
      return const [];
    }
  }

  Future<List<RawPointOfInterest>> _fetchOrThrow(List<LatLng> path) async {
    final sample = _sample(path, maxPoints);
    final coords = sample.map((p) => '${p.latitude},${p.longitude}').join(',');
    final r = aroundMeters;
    final query = '[out:json][timeout:25];'
        '('
        'node["tourism"~"^(alpine_hut|wilderness_hut|hut)\$"](around:$r,$coords);'
        'node["amenity"="shelter"](around:$r,$coords);'
        'node["place"~"^(locality|isolated_dwelling)\$"]["name"](around:$r,$coords);'
        'node["natural"="water"]["name"](around:$r,$coords);'
        'node["mountain_pass"="yes"](around:$r,$coords);'
        'node["natural"="saddle"]["name"](around:$r,$coords);'
        'node["natural"="peak"]["name"](around:$r,$coords);'
        ');'
        'out body;';

    final res = await _client
        .post(Uri.parse(endpoint),
            headers: const {'User-Agent': 'sentei/0.1 (hiking app)'},
            body: {'data': query})
        .timeout(timeout);
    if (res.statusCode != 200) {
      throw Exception('overpass HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final elements = (data['elements'] as List?) ?? const [];

    final out = <RawPointOfInterest>[];
    for (final e in elements) {
      final el = e as Map<String, dynamic>;
      if (el['type'] != 'node') continue;
      final lat = (el['lat'] as num?)?.toDouble();
      final lon = (el['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      final tags = (el['tags'] as Map<String, dynamic>?) ?? const {};
      final name = (tags['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;

      final category = _categoryOf(tags, name);
      if (category == null) continue;

      out.add(RawPointOfInterest(
        id: 'osm-${el['id']}',
        name: name,
        category: category,
        position: LatLng(lat, lon),
      ));
    }
    return out;
  }

  /// Classifica un nodo nella categoria giusta in base ai tag (e, per
  /// l'alpeggio, al nome). `null` = nodo scartato (non rientra in nessuna
  /// delle 5 categorie, es. un `place=locality` generico non "Alpe X").
  PoiCategory? _categoryOf(Map<String, dynamic> tags, String name) {
    final tourism = tags['tourism'] as String?;
    if (tourism == 'alpine_hut' || tourism == 'wilderness_hut' ||
        tourism == 'hut' || tags['amenity'] == 'shelter') {
      return PoiCategory.rifugio;
    }
    if (tags['natural'] == 'peak') return PoiCategory.cima;
    if (tags['mountain_pass'] == 'yes' || tags['natural'] == 'saddle') {
      return PoiCategory.colle;
    }
    if (tags['natural'] == 'water') return PoiCategory.lago;
    final place = tags['place'] as String?;
    if ((place == 'locality' || place == 'isolated_dwelling') &&
        _alpNamePattern.hasMatch(name)) {
      return PoiCategory.alpe;
    }
    return null;
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
