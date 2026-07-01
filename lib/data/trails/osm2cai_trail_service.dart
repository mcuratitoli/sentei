import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'trail_service.dart';

/// Recupera i **numeri dei sentieri** dal **catasto ufficiale CAI** via
/// **OSM2CAI / INFOMONT** (CAI + Wikimedia Italia, dati open ODbL).
///
/// Rispetto a Overpass (OSM grezzo) il catasto espone il `ref` CAI validato e
/// il codice nazionale REI: trova segnavia anche dove il tag `ref` OSM grezzo
/// manca ma il sentiero è accatastato (es. Valle d'Aosta). Copertura: **solo
/// Italia** → fuori dai confini si usa il fallback Overpass.
///
/// Endpoint (vedi `docs/osm2cai-investigation.md`):
///   POST /api/geojson/hiking_routes/bounding_box
///   body: osm2cai_status, lo0, la0, lo1, la1  → FeatureCollection GeoJSON
///
/// Best-effort: su errore/timeout/bbox troppo grande ritorna lista vuota.
class Osm2CaiTrailService extends TrailService {
  Osm2CaiTrailService({
    http.Client? client,
    this.endpoint = 'https://osm2cai.cai.it/api/geojson/hiking_routes/bounding_box',
    this.timeout = const Duration(seconds: 20),
    // Stati di accatastamento da includere: 1..4 (si esclude solo lo 0 = non
    // lavorato). 4 = validato sul campo; valori bassi = geometria OSM.
    this.osm2caiStatus = '1,2,3,4',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String endpoint;
  final Duration timeout;
  final String osm2caiStatus;

  @override
  Future<List<TrailRelation>> fetchRelations(List<LatLng> path) async {
    // Bounding box del percorso (+ margine ~0.01°). Il server rifiuta bbox
    // troppo grandi (HTTP 500); attorno a un percorso disegnato è sempre piccolo.
    var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
    for (final p in path) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLon = math.min(minLon, p.longitude);
      maxLon = math.max(maxLon, p.longitude);
    }
    const m = 0.01;
    minLat -= m;
    maxLat += m;
    minLon -= m;
    maxLon += m;

    // Distingue **fallimento** (rete/timeout/HTTP non-200 come il 500 "bbox
    // troppo grande") — che lancia [TrailLookupException] — da una risposta
    // valida **vuota** (nessun sentiero accatastato qui) che ritorna [].
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(endpoint),
            headers: const {'User-Agent': 'sentei/1.0 (app escursionismo Alpi)'},
            body: {
              'osm2cai_status': osm2caiStatus,
              'lo0': '$minLon',
              'la0': '$minLat',
              'lo1': '$maxLon',
              'la1': '$maxLat',
            },
          )
          .timeout(timeout);
    } catch (e) {
      throw TrailLookupException('osm2cai: $e');
    }
    if (res.statusCode != 200) {
      throw TrailLookupException('osm2cai HTTP ${res.statusCode}');
    }
    final List<dynamic> features;
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      features = (data['features'] as List?) ?? const [];
    } catch (e) {
      throw TrailLookupException('osm2cai parse: $e');
    }

    bool inBox(double lat, double lon) =>
        lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;

    final relations = <TrailRelation>[];
    for (final f in features) {
      final feat = f as Map<String, dynamic>;
      final props = feat['properties'] as Map<String, dynamic>? ?? const {};
      // Preferenza: ref CAI validato → REI → ref OSM grezzo.
      final ref = _firstNonEmpty([
        props['ref'],
        props['ref_REI'],
        props['ref_REI_comp'],
        props['ref_osm'],
      ]);
      if (ref == null) continue;
      final caiScale = _firstNonEmpty([props['cai_scale'], props['cai_scale_osm']]);

      final pts = <LatLng>[];
      _collectLineCoords(feat['geometry'], pts, inBox);
      if (pts.isNotEmpty) {
        relations.add(TrailRelation(ref, pts, caiScale: caiScale));
      }
    }
    return relations;
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      final s = v?.toString().trim();
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }

  /// Estrae i punti da una geometria GeoJSON (LineString o MultiLineString),
  /// filtrandoli al bounding box. Coordinate GeoJSON: [lon, lat].
  static void _collectLineCoords(
    dynamic geometry,
    List<LatLng> out,
    bool Function(double lat, double lon) inBox,
  ) {
    if (geometry is! Map) return;
    final type = geometry['type'];
    final coords = geometry['coordinates'];
    if (coords is! List) return;

    void addPoint(dynamic pt) {
      if (pt is! List || pt.length < 2) return;
      final lon = (pt[0] as num).toDouble();
      final lat = (pt[1] as num).toDouble();
      if (inBox(lat, lon)) out.add(LatLng(lat, lon));
    }

    if (type == 'LineString') {
      for (final pt in coords) {
        addPoint(pt);
      }
    } else if (type == 'MultiLineString') {
      for (final line in coords) {
        if (line is! List) continue;
        for (final pt in line) {
          addPoint(pt);
        }
      }
    }
  }
}
