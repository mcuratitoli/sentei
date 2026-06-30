import 'package:latlong2/latlong.dart';

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
  })  : _osm2cai = osm2cai ?? Osm2CaiTrailService(),
        _overpass = overpass ?? OverpassTrailService();

  final Osm2CaiTrailService _osm2cai;
  final OverpassTrailService _overpass;

  @override
  Future<List<TrailRelation>> fetchRelations(List<LatLng> path) async {
    final primary = await _osm2cai.fetchRelations(path);
    if (primary.isNotEmpty) return primary;
    return _overpass.fetchRelations(path);
  }
}
