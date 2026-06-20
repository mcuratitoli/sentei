import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Scarica la **rete di sentieri** (relazioni `route=hiking` OSM) nel bounding
/// box visibile, via **Overpass API**, per disegnarla come linee vettoriali
/// uniformi (stile GaiaGPS) al posto dell'overlay raster Waymarked.
///
/// Best-effort: su errore/timeout ritorna lista vuota (i sentieri sono un di
/// più, non devono mai bloccare la mappa).
class TrailNetworkService {
  TrailNetworkService({
    http.Client? client,
    this.endpoint = 'https://overpass-api.de/api/interpreter',
    this.timeout = const Duration(seconds: 25),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String endpoint;
  final Duration timeout;

  /// Polilinee dei sentieri `route=hiking` nel bounding box (una per way membro
  /// delle relazioni). I duplicati tra reti diverse non sono rimossi: per il
  /// disegno è irrilevante. Coordinate in gradi (disaccoppiato da flutter_map).
  Future<List<List<LatLng>>> hikingTrailsInBounds(
    double south,
    double west,
    double north,
    double east,
  ) async {
    final s = south, w = west, n = north, e = east;
    final query = '[out:json][timeout:25];'
        '(relation["route"="hiking"]($s,$w,$n,$e););'
        'out geom;';

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

      final lines = <List<LatLng>>[];
      for (final el in elements) {
        final e = el as Map<String, dynamic>;
        for (final mbr in (e['members'] as List? ?? const [])) {
          if (mbr['type'] != 'way') continue;
          final geom = mbr['geometry'] as List? ?? const [];
          if (geom.length < 2) continue;
          lines.add(<LatLng>[
            for (final g in geom)
              LatLng(
                (g['lat'] as num).toDouble(),
                (g['lon'] as num).toDouble(),
              ),
          ]);
        }
      }
      return lines;
    } catch (_) {
      return const [];
    }
  }

  /// **Linee con numero sentiero** (`ref` CAI) nel bounding box: per ogni
  /// relazione `route=hiking` con `ref`, una linea per way membro, con il ref.
  /// Servono per disegnare le etichette **ripetute lungo il sentiero**
  /// (`symbolPlacement: line`) sopra una base che già disegna i tracciati
  /// (es. Mapbox Outdoors). Best-effort.
  Future<List<TrailRefLine>> hikingRefLinesInBounds(
    double south,
    double west,
    double north,
    double east,
  ) async {
    final query = '[out:json][timeout:25];'
        '(relation["route"="hiking"]["ref"]($south,$west,$north,$east););'
        'out geom;';
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

      final out = <TrailRefLine>[];
      for (final el in elements) {
        final e = el as Map<String, dynamic>;
        final ref = (e['tags']?['ref'] as String?)?.trim();
        if (ref == null || ref.isEmpty) continue;
        for (final mbr in (e['members'] as List? ?? const [])) {
          if (mbr['type'] != 'way') continue;
          final geom = mbr['geometry'] as List? ?? const [];
          if (geom.length < 2) continue;
          out.add(TrailRefLine(ref, <LatLng>[
            for (final g in geom)
              LatLng((g['lat'] as num).toDouble(), (g['lon'] as num).toDouble()),
          ]));
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}

/// Una linea di sentiero con il suo numero (ref CAI), per le etichette.
class TrailRefLine {
  const TrailRefLine(this.ref, this.pts);
  final String ref;
  final List<LatLng> pts;
}
