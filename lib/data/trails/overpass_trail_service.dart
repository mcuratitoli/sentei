import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../domain/models/elevation_profile.dart';

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

  /// Attribuisce a ciascun tratto del percorso il **numero del sentiero**
  /// (ref CAI), restituendo segmenti per distanza cumulata. Scarica una volta
  /// le geometrie delle relazioni `route=hiking` vicine e fa il matching locale
  /// (al punto del percorso si assegna il sentiero più vicino entro soglia;
  /// a parità si preferisce quello più "locale", con meno punti). Best-effort.
  Future<List<TrailSegment>> trailSegmentsAlong(List<LatLng> path) async {
    if (path.length < 2) return const [];

    final relations = await _fetchRelations(path);
    if (relations.isEmpty) return const [];

    const distance = Distance();
    // Distanze cumulate lungo il percorso.
    final cum = <double>[0];
    for (var i = 1; i < path.length; i++) {
      cum.add(cum[i - 1] + distance(path[i - 1], path[i]));
    }

    // Campiona ogni ~50 m e assegna il ref.
    const sampleStep = 50.0;
    const threshold = 25.0; // m
    final segments = <TrailSegment>[];
    String? runRef;
    double runStart = 0;
    double lastSampleDist = -sampleStep;

    for (var i = 0; i < path.length; i++) {
      if (i != 0 &&
          i != path.length - 1 &&
          cum[i] - lastSampleDist < sampleStep) {
        continue;
      }
      lastSampleDist = cum[i];
      final ref = _nearestRef(path[i], relations, threshold);

      if (ref != runRef) {
        if (runRef != null) {
          segments.add(TrailSegment(
              fromMeters: runStart, toMeters: cum[i], ref: runRef));
        }
        runRef = ref;
        runStart = cum[i];
      }
    }
    if (runRef != null) {
      segments.add(TrailSegment(
          fromMeters: runStart, toMeters: cum.last, ref: runRef));
    }
    return segments;
  }

  /// Scarica le relazioni `route=hiking` vicine al percorso con la geometria,
  /// filtrando i punti al bounding box del percorso (+ margine).
  Future<List<_Relation>> _fetchRelations(List<LatLng> path) async {
    final sample = _sample(path, maxPoints);
    final coords = sample.map((p) => '${p.latitude},${p.longitude}').join(',');
    // Cerca direttamente le relazioni route=hiking nel raggio, senza passare per
    // le way con highway. Questo copre anche sentieri su ghiacciaio e tracciati
    // alpini che non hanno il tag highway (frequente in Valle d'Aosta e alta quota).
    final query = '[out:json][timeout:25];'
        'rel["route"="hiking"](around:$aroundMeters,$coords);'
        'out geom;';

    final List<dynamic> elements;
    try {
      final res = await _client
          .post(Uri.parse(endpoint),
              headers: const {'User-Agent': 'sentei/0.1 (hiking app)'},
              body: {'data': query})
          .timeout(timeout);
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      elements = (data['elements'] as List?) ?? const [];
    } catch (_) {
      return const [];
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

    final relations = <_Relation>[];
    for (final e in elements) {
      final el = e as Map<String, dynamic>;
      final ref = (el['tags']?['ref'] as String?)?.trim();
      if (ref == null || ref.isEmpty) continue;
      final pts = <LatLng>[];
      for (final mbr in (el['members'] as List? ?? const [])) {
        if (mbr['type'] != 'way') continue;
        for (final g in (mbr['geometry'] as List? ?? const [])) {
          final lat = (g['lat'] as num).toDouble();
          final lon = (g['lon'] as num).toDouble();
          if (inBox(lat, lon)) pts.add(LatLng(lat, lon));
        }
      }
      if (pts.isNotEmpty) relations.add(_Relation(ref, pts));
    }
    return relations;
  }

  /// Ref del sentiero più vicino a [p] entro [threshold] metri; a parità di
  /// vicinanza preferisce la relazione con meno punti (più locale/specifica).
  String? _nearestRef(LatLng p, List<_Relation> relations, double threshold) {
    const distance = Distance();
    String? best;
    var bestDist = threshold;
    var bestCount = 1 << 30;
    for (final r in relations) {
      var d = double.infinity;
      for (final q in r.points) {
        final dd = distance(p, q);
        if (dd < d) d = dd;
        if (d == 0) break;
      }
      if (d <= threshold &&
          (d < bestDist - 1 ||
              (d <= bestDist + 1 && r.points.length < bestCount))) {
        best = r.ref;
        bestDist = d;
        bestCount = r.points.length;
      }
    }
    return best;
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

/// Relazione sentiero scaricata da Overpass: ref + punti (geometria filtrata).
class _Relation {
  const _Relation(this.ref, this.points);
  final String ref;
  final List<LatLng> points;
}
