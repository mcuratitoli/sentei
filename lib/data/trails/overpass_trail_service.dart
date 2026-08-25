import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
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
    List<String>? mirrorEndpoints,
    this.timeout = const Duration(seconds: 25),
    Duration? perAttemptTimeout,
    this.maxPoints = 30,
    this.aroundMeters = 40,
  })  : _client = client ?? http.Client(),
        _mirrors = mirrorEndpoints ?? _defaultMirrors,
        _perAttemptTimeout = perAttemptTimeout ?? const Duration(seconds: 10);

  final http.Client _client;
  final String endpoint;

  /// Timeout **lato server** passato nella query stessa (`[out:json]
  /// [timeout:N]`): quanto Overpass può impiegare a valutarla prima di
  /// rinunciare da solo. Concetto diverso da [_perAttemptTimeout] (il nostro
  /// timeout HTTP client-side per tentativo) — una query complessa può
  /// legittimamente richiedere fino a questo tempo lato server anche quando
  /// risponde in modo sano.
  final Duration timeout;

  /// Punti massimi campionati dal percorso (per non gonfiare la query).
  final int maxPoints;

  /// Raggio (m) entro cui cercare i sentieri attorno ai punti campionati.
  final int aroundMeters;

  /// Istanze pubbliche alternative, provate in ordine se [endpoint] fallisce
  /// o va in timeout: il server principale (`overpass-api.de`) è pubblico e
  /// gratuito, e osservato dal vivo restituire timeout (`HTTP 504`) sotto
  /// carico (25 ago 2026) — un fallimento isolato che un secondo tentativo,
  /// spesso su un'istanza meno affollata, risolve. Nessuna di queste
  /// richiede una chiave API (stesso servizio Overpass, mirror indipendenti).
  final List<String> _mirrors;
  static const _defaultMirrors = [
    'https://lz4.overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  /// Timeout **per singolo tentativo** nel giro fra [endpoint] e i mirror:
  /// deliberatamente più corto di [timeout] (25s). Osservato dal vivo (25
  /// ago 2026): con `timeout` applicato a OGNI tentativo, un giro sfortunato
  /// con tutte e tre le istanze lente arrivava a **75 secondi** di attesa
  /// prima di mostrare "non trovato" — inaccettabile per un tap interattivo.
  /// Un'istanza sana risponde in pochi secondi; una che non risponde entro
  /// questa soglia sta quasi certamente per andare in timeout comunque, tanto
  /// vale passare al prossimo mirror prima.
  final Duration _perAttemptTimeout;

  /// Prova [endpoint] e via via ogni mirror finché uno risponde `200`;
  /// lancia [TrailLookupException] solo se **tutti** falliscono.
  Future<http.Response> _postToAnyEndpoint(String query) async {
    Object? lastError;
    for (final url in [endpoint, ..._mirrors]) {
      try {
        final res = await _client
            .post(Uri.parse(url),
                headers: const {'User-Agent': 'sentei/0.1 (hiking app)'},
                body: {'data': query})
            .timeout(_perAttemptTimeout);
        if (res.statusCode == 200) return res;
        lastError = 'HTTP ${res.statusCode}';
        debugPrint('[trails] overpass $url → HTTP ${res.statusCode}, provo il prossimo');
      } catch (e) {
        lastError = e;
        debugPrint('[trails] overpass $url fallito ($e), provo il prossimo');
      }
    }
    throw TrailLookupException('overpass: tutte le istanze fallite ($lastError)');
  }

  /// Scarica le relazioni `route=hiking` vicine al percorso con la geometria,
  /// filtrando i punti al bounding box del percorso (+ margine).
  ///
  /// [radiusMeters], quando passato (da `trailsNear`), **sostituisce**
  /// [aroundMeters] nella query: senza, un tap a 50-60 m da un segnavia reale
  /// non veniva nemmeno scaricato (raggio fisso di 40 m, più piccolo della
  /// soglia usata poi per accettare il risultato) — bug osservato dal vivo il
  /// 25 ago 2026. Per [trailSegmentsAlong] (percorso disegnato, non passa
  /// [radiusMeters]) il raggio stretto resta intenzionale: tanti punti
  /// campionati, query più mirata.
  @override
  Future<List<TrailRelation>> fetchRelations(List<LatLng> path,
      {double? radiusMeters}) async {
    final sample = _sample(path, maxPoints);
    final coords = sample.map((p) => '${p.latitude},${p.longitude}').join(',');
    final radius = radiusMeters ?? aroundMeters;
    // Cerca direttamente le relazioni route=hiking nel raggio, senza passare per
    // le way con highway. Questo copre anche sentieri su ghiacciaio e tracciati
    // alpini che non hanno il tag highway (frequente in Valle d'Aosta e alta quota).
    final query = '[out:json][timeout:25];'
        'rel["route"="hiking"](around:$radius,$coords);'
        'out geom;';

    // Fallimento (rete/timeout/HTTP non-200 su TUTTE le istanze) → lancia
    // [TrailLookupException]; risposta valida senza relazioni → lista vuota
    // (nessun segnavia qui).
    final res = await _postToAnyEndpoint(query);
    final List<dynamic> elements;
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      elements = (data['elements'] as List?) ?? const [];
    } catch (e) {
      throw TrailLookupException('overpass parse: $e');
    }
    debugPrint('[trails] overpass around:$radius su ${sample.length} punti → '
        '${elements.length} relazioni grezze, ref: '
        '${elements.map((e) => (e as Map)['tags']?['ref']).toList()}');

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
    debugPrint('[trails] overpass → ${relations.length} relazioni con geometria '
        'nel bbox: ${relations.map((r) => "${r.ref}(id=${r.id},${r.points.length}pt)").toList()}');
    return relations;
  }

  /// Recupera la relazione **completa** (geometria dal capo all'altro, non
  /// ritagliata) per l'id di relazione OSM [id] — `rel(<id>); out geom;`.
  /// `null` se non trovata. `distanceMeters` calcolato localmente sulla
  /// geometria (Overpass non lo precalcola come OSM2CAI); `officialUrl` è il
  /// permalink OSM standard, sempre valido.
  Future<TrailDetail?> fetchDetailById(String id) async {
    final query = '[out:json][timeout:$timeoutSeconds];rel($id);out geom;';
    final res = await _postToAnyEndpoint(query);
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

    // Le `member` way di una relazione non sono garantite tutte nello stesso
    // verso: concatenarle senza controllo può saldare fine-con-fine invece di
    // fine-con-inizio, creando un salto a linea retta — vedi doc su
    // `PathGeometry.stitchSegments`, che sceglie l'orientamento giusto per
    // ogni way in base a quella precedente.
    final ways = <List<LatLng>>[];
    for (final mbr in (el['members'] as List? ?? const [])) {
      if (mbr['type'] != 'way') continue;
      final way = <LatLng>[
        for (final g in (mbr['geometry'] as List? ?? const []))
          LatLng((g['lat'] as num).toDouble(), (g['lon'] as num).toDouble()),
      ];
      if (way.isNotEmpty) ways.add(way);
    }
    final pts = const PathGeometry().stitchSegments(ways);
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
