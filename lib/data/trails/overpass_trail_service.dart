import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../domain/services/path_geometry.dart';
import 'trail_service.dart';

/// Recupera i **numeri dei sentieri** (tag `ref` delle relazioni
/// `route=hiking` OSM, es. CAI "203") attraversati da un percorso, via
/// **Overpass API**. Best-effort: in caso di errore/timeout ritorna lista vuota
/// (i tag sono un di più, non devono bloccare nulla).
///
/// La segmentazione (matching punto→sentiero) è ereditata da [TrailService];
/// qui si implementa solo lo scarico delle relazioni da Overpass.
class OverpassTrailService extends TrailService {
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

  /// Scarica le relazioni `route=hiking` vicine al percorso con la geometria,
  /// filtrando i punti al bounding box del percorso (+ margine).
  @override
  Future<List<TrailRelation>> fetchRelations(List<LatLng> path) async {
    final sample = _sample(path, maxPoints);
    final coords = sample.map((p) => '${p.latitude},${p.longitude}').join(',');
    // Cerca direttamente le relazioni route=hiking nel raggio, senza passare per
    // le way con highway. Questo copre anche sentieri su ghiacciaio e tracciati
    // alpini che non hanno il tag highway (frequente in Valle d'Aosta e alta quota).
    final query = '[out:json][timeout:25];'
        'rel["route"="hiking"](around:$aroundMeters,$coords);'
        'out geom;';

    // Fallimento (rete/timeout/HTTP non-200) → lancia [TrailLookupException];
    // risposta valida senza relazioni → lista vuota (nessun segnavia qui).
    final http.Response res;
    try {
      res = await _client
          .post(Uri.parse(endpoint),
              headers: const {'User-Agent': 'sentei/0.1 (hiking app)'},
              body: {'data': query})
          .timeout(timeout);
    } catch (e) {
      throw TrailLookupException('overpass: $e');
    }
    if (res.statusCode != 200) {
      throw TrailLookupException('overpass HTTP ${res.statusCode}');
    }
    final List<dynamic> elements;
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      elements = (data['elements'] as List?) ?? const [];
    } catch (e) {
      throw TrailLookupException('overpass parse: $e');
    }

    // Bounding box del percorso (+ margine ~0.01°).
    var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
    for (final p in path) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLon = math.min(minLon, p.longitude);
      maxLon = math.max(maxLon, p.longitude);
    }
    const m = 0.01;
    bool inBox(double lat, double lon) =>
        lat >= minLat - m &&
        lat <= maxLat + m &&
        lon >= minLon - m &&
        lon <= maxLon + m;

    final relations = <TrailRelation>[];
    for (final e in elements) {
      final el = e as Map<String, dynamic>;
      final tags = el['tags'] as Map<String, dynamic>?;
      final ref = (tags?['ref'] as String?)?.trim();
      if (ref == null || ref.isEmpty) continue;
      final caiScale = (tags?['cai_scale'] as String?)?.trim();
      String? tag(String key) {
        final v = (tags?[key] as String?)?.trim();
        return (v == null || v.isEmpty) ? null : v;
      }

      final pts = <LatLng>[];
      for (final mbr in (el['members'] as List? ?? const [])) {
        if (mbr['type'] != 'way') continue;
        for (final g in (mbr['geometry'] as List? ?? const [])) {
          final lat = (g['lat'] as num).toDouble();
          final lon = (g['lon'] as num).toDouble();
          if (inBox(lat, lon)) pts.add(LatLng(lat, lon));
        }
      }
      if (pts.isNotEmpty) {
        relations.add(TrailRelation(
          ref,
          pts,
          TrailSource.overpass,
          caiScale: (caiScale?.isEmpty ?? true) ? null : caiScale,
          // Id della relazione OSM: sempre presente per un elemento `relation`
          // in una risposta Overpass, a differenza di quello (non confermato)
          // di OSM2CAI — vedi doc su TrailRelation.id.
          id: el['id']?.toString(),
          name: tag('name'),
          from: tag('from'),
          to: tag('to'),
          osmcSymbol: tag('osmc:symbol'),
        ));
      }
    }
    return relations;
  }

  /// Recupera la relazione **completa** (geometria dal capo all'altro, non
  /// ritagliata) per l'id di relazione OSM [id] — `rel(<id>); out geom;`.
  /// `null` se non trovata. `distanceMeters` calcolato localmente sulla
  /// geometria (Overpass non lo precalcola come OSM2CAI); `officialUrl` è il
  /// permalink OSM standard, sempre valido.
  Future<TrailDetail?> fetchDetailById(String id) async {
    final query = '[out:json][timeout:$timeoutSeconds];rel($id);out geom;';
    final http.Response res;
    try {
      res = await _client
          .post(Uri.parse(endpoint),
              headers: const {'User-Agent': 'sentei/0.1 (hiking app)'},
              body: {'data': query})
          .timeout(timeout);
    } catch (e) {
      throw TrailLookupException('overpass detail: $e');
    }
    if (res.statusCode != 200) {
      throw TrailLookupException('overpass detail HTTP ${res.statusCode}');
    }
    final List<dynamic> elements;
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      elements = (data['elements'] as List?) ?? const [];
    } catch (e) {
      throw TrailLookupException('overpass detail parse: $e');
    }
    if (elements.isEmpty) return null;
    final el = elements.first as Map<String, dynamic>;
    final tags = el['tags'] as Map<String, dynamic>?;
    final ref = (tags?['ref'] as String?)?.trim();
    if (ref == null || ref.isEmpty) return null;
    String? tag(String key) {
      final v = (tags?[key] as String?)?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    final pts = <LatLng>[];
    for (final mbr in (el['members'] as List? ?? const [])) {
      if (mbr['type'] != 'way') continue;
      for (final g in (mbr['geometry'] as List? ?? const [])) {
        pts.add(LatLng((g['lat'] as num).toDouble(), (g['lon'] as num).toDouble()));
      }
    }
    if (pts.isEmpty) return null;
    return TrailDetail(
      ref: ref,
      points: pts,
      name: tag('name'),
      from: tag('from'),
      to: tag('to'),
      caiScale: tag('cai_scale'),
      distanceMeters: const PathGeometry().totalDistance(pts),
      officialUrl: 'https://www.openstreetmap.org/relation/$id',
    );
  }

  int get timeoutSeconds => timeout.inSeconds;

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
