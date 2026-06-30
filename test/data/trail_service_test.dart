import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sentei/data/trails/combined_trail_service.dart';
import 'package:sentei/data/trails/osm2cai_trail_service.dart';
import 'package:sentei/data/trails/overpass_trail_service.dart';

// Due punti ~100 m a nord uno dell'altro (vicino a Punta Gnifetti).
final _a = LatLng(45.9369, 7.8694);
final _b = LatLng(45.9378, 7.8694);

// FeatureCollection OSM2CAI con un sentiero che ricalca esattamente [_a, _b].
// Coordinate GeoJSON: [lon, lat]. ref="5" (CAI) + ref_osm diverso, per
// verificare che si preferisca il ref CAI.
const _osm2caiBody = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": { "ref": "5", "ref_osm": "999", "cai_scale": "EE" },
      "geometry": {
        "type": "LineString",
        "coordinates": [ [7.8694, 45.9369], [7.8694, 45.9378] ]
      }
    }
  ]
}
''';

// Come sopra ma senza ref CAI: solo ref_REI → deve usare quello.
const _osm2caiReiBody = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": { "ref": "", "ref_REI": "117" },
      "geometry": {
        "type": "MultiLineString",
        "coordinates": [ [ [7.8694, 45.9369], [7.8694, 45.9378] ] ]
      }
    }
  ]
}
''';

// Risposta Overpass (out geom) con relazione ref="10" lungo [_a, _b].
const _overpassBody = '''
{
  "elements": [
    {
      "type": "relation",
      "tags": { "ref": "10", "cai_scale": "E" },
      "members": [
        {
          "type": "way",
          "geometry": [
            { "lat": 45.9369, "lon": 7.8694 },
            { "lat": 45.9378, "lon": 7.8694 }
          ]
        }
      ]
    }
  ]
}
''';

http.Client _fixed(String body) =>
    MockClient((_) async => http.Response(body, 200));

void main() {
  group('Osm2CaiTrailService', () {
    test('estrae il ref CAI e lo assegna al tratto (preferisce ref a ref_osm)',
        () async {
      final svc = Osm2CaiTrailService(client: _fixed(_osm2caiBody));
      final segs = await svc.trailSegmentsAlong([_a, _b]);
      expect(segs, isNotEmpty);
      expect(segs.map((s) => s.ref).toSet(), {'5'});
      expect(segs.first.caiScale, 'EE');
    });

    test('ripiega su ref_REI quando ref è vuoto (e parsa MultiLineString)',
        () async {
      final svc = Osm2CaiTrailService(client: _fixed(_osm2caiReiBody));
      final segs = await svc.trailSegmentsAlong([_a, _b]);
      expect(segs.map((s) => s.ref).toSet(), {'117'});
    });

    test('lista vuota su errore HTTP', () async {
      final svc = Osm2CaiTrailService(
          client: MockClient((_) async => http.Response('boom', 500)));
      expect(await svc.trailSegmentsAlong([_a, _b]), isEmpty);
    });
  });

  group('CombinedTrailService', () {
    test('usa OSM2CAI quando ha risultati', () async {
      final svc = CombinedTrailService(
        osm2cai: Osm2CaiTrailService(client: _fixed(_osm2caiBody)),
        overpass: OverpassTrailService(client: _fixed(_overpassBody)),
      );
      final segs = await svc.trailSegmentsAlong([_a, _b]);
      expect(segs.map((s) => s.ref).toSet(), {'5'});
    });

    test('ripiega su Overpass quando OSM2CAI è vuoto', () async {
      final svc = CombinedTrailService(
        osm2cai: Osm2CaiTrailService(
            client: _fixed('{"type":"FeatureCollection","features":[]}')),
        overpass: OverpassTrailService(client: _fixed(_overpassBody)),
      );
      final segs = await svc.trailSegmentsAlong([_a, _b]);
      expect(segs.map((s) => s.ref).toSet(), {'10'});
      expect(segs.first.caiScale, 'E');
    });
  });
}
