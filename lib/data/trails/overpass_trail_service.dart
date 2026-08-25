import 'dart:async';
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
    Duration? hedgeDelay,
    this.maxPoints = 30,
    this.aroundMeters = 40,
  })  : _client = client ?? http.Client(),
        _mirrors = mirrorEndpoints ?? _defaultMirrors,
        _perAttemptTimeout = perAttemptTimeout ?? const Duration(seconds: 10),
        _hedgeDelay = hedgeDelay ?? const Duration(seconds: 3);

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

  /// Istanza pubblica alternativa, provata se [endpoint] fallisce o va in
  /// timeout. **Una sola** (non due, come nel primo tentativo del 25 ago
  /// 2026): `lz4.overpass-api.de` è lo **stesso operatore** di
  /// `overpass-api.de` (un'altra istanza dello stesso progetto Overpass
  /// "principale"), non un fallback davvero indipendente — se quell'operatore
  /// rallenta o (sospetto, osservato dal vivo la sera del 25 ago: `Connection
  /// refused` su entrambi contemporaneamente dopo un uso intenso durante i
  /// test) limita le richieste da un IP, tenta comunque **due** volte contro
  /// **lui**, raddoppiando inutilmente il carico proprio sull'operatore che
  /// sta già faticando. `overpass.private.coffee` è un'installazione
  /// indipendente (community `private.coffee`), l'unico vero secondo parere.
  final List<String> _mirrors;
  static const _defaultMirrors = [
    'https://overpass.private.coffee/api/interpreter',
  ];

  /// **Interruttore**: dopo un fallimento totale (tutte le istanze giù),
  /// salta la rete del tutto per questa finestra invece di ritentare ad ogni
  /// tap — introdotto il 25 ago 2026 dopo aver notato che una serie di test
  /// ravvicinati faceva fallire con `Connection refused` **entrambe** le
  /// istanze contemporaneamente: un pattern più coerente con un limite
  /// temporaneo lato server scatenato dal nostro stesso volume di richieste
  /// (ogni ricerca, con la corsa a staffetta, ne genera più di una) che con
  /// un'interruzione di rete generica. Riprova comunque dopo
  /// [_downCooldown], breve rispetto a quello di OSM2CAI (5 min, endpoint
  /// confermato rotto in modo permanente): qui il servizio può tornare
  /// disponibile nel giro di pochi secondi/minuti.
  DateTime? _downUntil;
  static const _downCooldown = Duration(seconds: 30);

  /// Timeout **per singolo tentativo**: deliberatamente più corto di
  /// [timeout] (25s). Un'istanza sana risponde in pochi secondi; una che non
  /// risponde entro questa soglia sta quasi certamente per andare in timeout
  /// comunque.
  final Duration _perAttemptTimeout;

  /// Ritardo fra un tentativo e il successivo nella "corsa a staffetta" di
  /// [_postToAnyEndpoint]: non si aspetta il timeout pieno di un'istanza
  /// prima di provare la successiva. Configurabile (default 3s) solo per i
  /// test, che altrimenti pagherebbero per davvero l'attesa fra i tentativi
  /// anche con un `MockClient` che risponde all'istante.
  final Duration _hedgeDelay;

  /// Prova [endpoint] e il mirror **in corsa a staffetta** ("hedged
  /// request"): parte subito con [endpoint]; se non ha ancora risposto dopo
  /// [_hedgeDelay] (è solo **lento**), lancia ANCHE il mirror in parallelo;
  /// se invece [endpoint] **fallisce** prima che scada [_hedgeDelay], il
  /// mirror parte **subito**, senza aspettare il resto dell'attesa — un
  /// fallimento rapido (`Connection refused`, HTTP non-200) non deve costare
  /// lo stesso ritardo di un tentativo lento ma ancora in corso. Vince il
  /// primo che risponde `200`. Lancia [TrailLookupException] solo se
  /// **entrambi** falliscono — e a quel punto attiva [_downUntil] (vedi
  /// doc lì) prima di rilanciarla.
  Future<http.Response> _postToAnyEndpoint(String query) async {
    final downUntil = _downUntil;
    if (downUntil != null && DateTime.now().isBefore(downUntil)) {
      debugPrint('[trails] overpass: interruttore attivo fino a $downUntil, '
          'nessuna richiesta');
      throw TrailLookupException(
          'overpass: segnalato giù di recente, riprovo tra poco');
    }

    final urls = [endpoint, ..._mirrors];
    final completer = Completer<http.Response>();
    final errors = <Object?>[];
    var pending = urls.length;
    var nextIndex = 1;
    // `Timer`, non `Future.delayed`: deve poter essere **cancellato** appena
    // uno degli endpoint risponde (o si passa al successivo prima del
    // previsto), altrimenti resta agganciato dopo che `_postToAnyEndpoint` è
    // già tornato — innocuo a runtime, ma `flutter_test` (usato dai widget
    // test che disegnano una traccia e quindi risolvono segnavia, es.
    // `draw_route_controls_test.dart`) fa fallire il test con "A Timer is
    // still pending even after the widget tree was disposed" se non lo si
    // ripulisce esplicitamente.
    Timer? hedgeTimer;

    void cancelHedgeTimer() => hedgeTimer?.cancel();

    late void Function(String url) attempt;

    void startNextIfAny() {
      if (nextIndex >= urls.length || completer.isCompleted) return;
      cancelHedgeTimer();
      attempt(urls[nextIndex++]);
    }

    void armHedgeTimer() {
      if (nextIndex >= urls.length) return;
      hedgeTimer = Timer(_hedgeDelay, startNextIfAny);
    }

    void fail(Object error) {
      errors.add(error);
      pending--;
      if (pending == 0 && !completer.isCompleted) {
        _downUntil = DateTime.now().add(_downCooldown);
        completer.completeError(TrailLookupException(
            'overpass: tutte le istanze fallite ($errors) — salto per '
            '${_downCooldown.inSeconds}s'));
      } else {
        // Fallimento rapido: non aspettare il resto di _hedgeDelay per
        // provare il prossimo, se ce n'è uno non ancora partito.
        startNextIfAny();
      }
    }

    attempt = (String url) {
      unawaited(() async {
        try {
          final res = await _client
              .post(Uri.parse(url),
                  headers: const {'User-Agent': 'sentei/0.1 (hiking app)'},
                  body: {'data': query})
              .timeout(_perAttemptTimeout);
          if (completer.isCompleted) return;
          if (res.statusCode == 200) {
            _downUntil = null; // ha risposto: interruttore azzerato
            completer.complete(res);
            cancelHedgeTimer();
          } else {
            debugPrint('[trails] overpass $url → HTTP ${res.statusCode}');
            fail('HTTP ${res.statusCode} da $url');
          }
        } catch (e) {
          if (completer.isCompleted) return;
          debugPrint('[trails] overpass $url fallito ($e)');
          fail(e);
        }
      }());
    };

    attempt(urls[0]);
    armHedgeTimer();
    try {
      return await completer.future;
    } finally {
      cancelHedgeTimer();
    }
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
