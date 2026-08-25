import 'package:flutter/foundation.dart' show debugPrint;
import 'package:latlong2/latlong.dart';

import 'cai_varallo_search_service.dart';
import 'osm2cai_trail_service.dart';
import 'overpass_trail_service.dart';
import 'trail_service.dart';

/// Servizio segnavia combinato: **OSM2CAI** (catasto ufficiale CAI) come fonte
/// primaria, **Overpass** (OSM grezzo) come fallback.
///
/// OSM2CAI copre l'Italia con i `ref` CAI validati; quando non restituisce nulla
/// — zone di confine (Francia/Svizzera, dove il catasto CAI non arriva) oppure
/// servizio non disponibile — si ricade su Overpass, che copre tutto l'arco
/// alpino. Il fallback avviene a livello di *relazioni*: la segmentazione
/// (matching punto→sentiero) resta unica, ereditata da [TrailService].
class CombinedTrailService extends TrailService {
  CombinedTrailService({
    Osm2CaiTrailService? osm2cai,
    OverpassTrailService? overpass,
    CaiVaralloSearchService? caiVarallo,
  })  : _osm2cai = osm2cai ?? Osm2CaiTrailService(),
        _overpass = overpass ?? OverpassTrailService(),
        _caiVarallo = caiVarallo ?? CaiVaralloSearchService();

  final Osm2CaiTrailService _osm2cai;
  final OverpassTrailService _overpass;
  final CaiVaralloSearchService _caiVarallo;

  /// **Interruttore**: dopo un fallimento OSM2CAI, salta il tentativo
  /// (direttamente su Overpass) fino a questo istante — riprovato poi in
  /// caso il servizio sia tornato su. Introdotto il 25 ago 2026 dopo aver
  /// confermato dal vivo (log `[trails]` + `curl` diretto, vedi
  /// `docs/osm2cai-investigation.md`) che l'endpoint bounding-box risponde
  /// **sempre** `HTTP 405` in produzione: senza questo, ogni singola ricerca
  /// pagava un giro di rete garantito inutile prima di passare a Overpass —
  /// l'utente lo notava come lentezza ("come mai ci mette tanto?").
  DateTime? _osm2caiDownUntil;
  static const _osm2caiCooldown = Duration(minutes: 5);

  /// Valsesia e dintorni immediati (Varallo → Alagna, Val Sermenza, Val
  /// Mastallone, Val Vogna): riquadro **approssimativo**, non un confine
  /// amministrativo — serve solo a decidere se vale la pena interrogare
  /// anche il sito di CAI Varallo (richiesta esplicita dell'utente, 24 ago
  /// 2026), non a classificare con precisione un punto come "in Valsesia".
  static const _valsesiaMinLat = 45.65;
  static const _valsesiaMaxLat = 45.95;
  static const _valsesiaMinLon = 7.85;
  static const _valsesiaMaxLon = 8.35;

  static bool _isNearValsesia(List<LatLng> points) => points.any((p) =>
      p.latitude >= _valsesiaMinLat &&
      p.latitude <= _valsesiaMaxLat &&
      p.longitude >= _valsesiaMinLon &&
      p.longitude <= _valsesiaMaxLon);

  @override
  Future<List<TrailRelation>> fetchRelations(List<LatLng> path,
      {double? radiusMeters}) async {
    final downUntil = _osm2caiDownUntil;
    final skipOsm2cai = downUntil != null && DateTime.now().isBefore(downUntil);
    if (!skipOsm2cai) {
      // Primario: se dà risultati li usa. Se **fallisce** (throw) o torna
      // **vuoto** si ripiega su Overpass. L'eventuale fallimento del
      // fallback viene **propagato** (throw): così chi risolve i segnavia
      // distingue "cercato e non trovato" (vuoto genuino) da "ricerca
      // fallita" (da ritentare).
      try {
        final primary = await _osm2cai.fetchRelations(path);
        _osm2caiDownUntil = null; // ha risposto: interruttore azzerato
        debugPrint('[trails] combined: OSM2CAI → ${primary.length} relazioni '
            '(${primary.map((r) => r.ref).toList()})');
        if (primary.isNotEmpty) return primary;
      } on TrailLookupException catch (e) {
        _osm2caiDownUntil = DateTime.now().add(_osm2caiCooldown);
        debugPrint('[trails] combined: OSM2CAI fallito ($e), provo Overpass '
            '(salto OSM2CAI per i prossimi ${_osm2caiCooldown.inMinutes} min)');
      }
    } else {
      debugPrint('[trails] combined: OSM2CAI saltato (interruttore attivo fino '
          'a $downUntil), vado diretto su Overpass');
    }
    final fallback =
        await _overpass.fetchRelations(path, radiusMeters: radiusMeters);
    debugPrint('[trails] combined: Overpass → ${fallback.length} relazioni '
        '(${fallback.map((r) => r.ref).toList()})');
    return fallback;
  }

  /// Recupera la relazione **completa** di [relation] (§"Un segnavia per
  /// intero"): smista verso OSM2CAI o Overpass in base a [TrailRelation.source]
  /// — a differenza di [fetchRelations], qui **non c'è fallback fra le due
  /// fonti**: si sa già da dove viene la relazione (è il risultato di una
  /// ricerca precedente), non ha senso interrogare l'altra. `null` se
  /// [TrailRelation.id] manca (fonte che non lo espone in modo affidabile,
  /// vedi doc su quel campo) o se il fetch non trova nulla.
  ///
  /// Se la geometria risultante è in **Valsesia e dintorni**, cerca il ref
  /// nell'**elenco ufficiale** di CAI Varallo (match esatto, non ricerca
  /// full-text — vedi doc su [CaiVaralloSearchService]) e allega il
  /// risultato se trovato — mai un errore verso il chiamante: è un
  /// arricchimento locale, non deve mai far fallire la card di dettaglio.
  ///
  /// Se il fetch della geometria completa **fallisce** (rete: Overpass giù,
  /// vedi `docs/CHANGELOG-DEV.md`), non butta via tutto: costruisce un
  /// [TrailDetail] **parziale** (`geometryComplete: false`) con ciò che [relation]
  /// già sa (ref/nome/capi-percorso/grado CAI, dalla ricerca che ha portato
  /// a questo segnavia) e prova comunque CAI Varallo, che non dipende da
  /// quel fetch — feedback esplicito dell'utente (25 ago 2026) dopo un
  /// fallimento totale di Overpass: "non ha senso non mostrare nulla".
  @override
  Future<TrailDetail?> fetchDetail(TrailRelation relation) async {
    final id = relation.id;
    if (id == null) {
      debugPrint('[trails] combined.fetchDetail "${relation.ref}": nessun id '
          '(fonte ${relation.source.name}) → null');
      return null;
    }
    TrailDetail? detail;
    try {
      detail = await switch (relation.source) {
        TrailSource.osm2cai => _osm2cai.fetchDetailById(id),
        TrailSource.overpass => _overpass.fetchDetailById(id),
      };
    } catch (e) {
      debugPrint('[trails] combined.fetchDetail "${relation.ref}": fetch '
          'geometria completa fallito ($e) — mostro comunque i dati già noti');
    }
    debugPrint('[trails] combined.fetchDetail "${relation.ref}" '
        '(${relation.source.name}, id=$id) → '
        '${detail == null ? "fallito/vuoto" : "${detail.points.length} punti"}');
    // `null` da qui in poi significa "il fetch ha risposto ma non ha trovato
    // nulla" (relazione cancellata/id sbagliato): quello sì che resta `null`
    // verso il chiamante, non ha senso mostrare una relazione che la fonte
    // dice non esistere più. Solo l'**eccezione** (sopra) diventa un
    // dettaglio parziale.
    detail ??= relation.points.isEmpty
        ? null
        : TrailDetail(
            ref: relation.ref,
            points: relation.points,
            name: relation.name,
            from: relation.from,
            to: relation.to,
            caiScale: relation.caiScale,
            officialUrl: relation.source == TrailSource.overpass
                ? 'https://www.openstreetmap.org/relation/$id'
                : null,
            geometryComplete: false,
          );
    if (detail == null || !_isNearValsesia(detail.points)) return detail;
    final result = await _caiVarallo.findByRef(detail.ref);
    debugPrint('[trails] combined.fetchDetail "${relation.ref}": in Valsesia, '
        'CAI Varallo → ${result == null ? "nessun match" : result.url}');
    return result == null ? detail : detail.copyWith(caiVarallo: result);
  }

  /// Ultima spiaggia per la card **traccia** (`TrailDetailNotifier.openByRef`)
  /// quando non si riesce nemmeno a risolvere il ref in una relazione vera —
  /// OSM2CAI/Overpass entrambi giù, o senza quel ref nei dintorni. La ricerca
  /// su CAI Varallo non dipende da nessuna delle due fonti (usa solo il ref
  /// e la posizione), quindi può ancora dare un risultato utile — feedback
  /// esplicito dell'utente (25 ago 2026): "sul sito del CAI Varallo lo trovo
  /// subito, non ha senso non mostrarmi nulla". Solo per i segnavia in
  /// Valsesia e dintorni (stesso gate di [fetchDetail]); `null` altrove o se
  /// il ref non è nemmeno nell'elenco ufficiale.
  @override
  Future<TrailDetail?> fetchByRefOnly(String trailRef, LatLng anchor) async {
    if (!_isNearValsesia([anchor])) return null;
    final result = await _caiVarallo.findByRef(trailRef);
    if (result == null) return null;
    return TrailDetail(
      ref: trailRef,
      points: [anchor],
      caiVarallo: result,
      geometryComplete: false,
    );
  }
}
