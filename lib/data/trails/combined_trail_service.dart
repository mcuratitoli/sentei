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
    // Primario: se dà risultati li usa. Se **fallisce** (throw) o torna **vuoto**
    // si ripiega su Overpass. L'eventuale fallimento del fallback viene
    // **propagato** (throw): così chi risolve i segnavia distingue "cercato e
    // non trovato" (vuoto genuino) da "ricerca fallita" (da ritentare).
    try {
      final primary = await _osm2cai.fetchRelations(path);
      debugPrint('[trails] combined: OSM2CAI → ${primary.length} relazioni '
          '(${primary.map((r) => r.ref).toList()})');
      if (primary.isNotEmpty) return primary;
    } on TrailLookupException catch (e) {
      // primario ko → tenta il fallback
      debugPrint('[trails] combined: OSM2CAI fallito ($e), provo Overpass');
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
  /// Se la geometria risultante è in **Valsesia e dintorni**, interroga
  /// anche CAI Varallo (richiesta esplicita dell'utente) e allega i
  /// risultati trovati — 0 o più, mai un errore verso il chiamante: è un
  /// arricchimento locale, non deve mai far fallire la card di dettaglio.
  @override
  Future<TrailDetail?> fetchDetail(TrailRelation relation) async {
    final id = relation.id;
    if (id == null) {
      debugPrint('[trails] combined.fetchDetail "${relation.ref}": nessun id '
          '(fonte ${relation.source.name}) → null');
      return null;
    }
    final detail = await switch (relation.source) {
      TrailSource.osm2cai => _osm2cai.fetchDetailById(id),
      TrailSource.overpass => _overpass.fetchDetailById(id),
    };
    debugPrint('[trails] combined.fetchDetail "${relation.ref}" '
        '(${relation.source.name}, id=$id) → '
        '${detail == null ? "null" : "${detail.points.length} punti"}');
    if (detail == null || !_isNearValsesia(detail.points)) return detail;
    final query = (detail.name?.isNotEmpty ?? false) ? detail.name! : detail.ref;
    final results = await _caiVarallo.search(query);
    debugPrint('[trails] combined.fetchDetail "${relation.ref}": in Valsesia, '
        'CAI Varallo → ${results.length} risultati per "$query"');
    return results.isEmpty ? detail : detail.copyWith(caiVaralloResults: results);
  }
}
