import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sentei/data/trails/combined_trail_service.dart';
import 'package:sentei/data/trails/osm2cai_trail_service.dart';
import 'package:sentei/data/trails/overpass_trail_service.dart';
import 'package:sentei/data/trails/trail_service.dart';

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
      "properties": {
        "ref": "5", "ref_osm": "999", "cai_scale": "EE",
        "id": "42", "name": "Alta Via del Rifugio",
        "from": "Alagna", "to": "Rifugio Pastore",
        "osmc_symbol": "red:white:red_bar"
      },
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
      "id": 123456,
      "tags": {
        "ref": "10", "cai_scale": "E",
        "name": "Sentiero delle Guide", "from": "Rima", "to": "Colma",
        "osmc:symbol": "yellow:white:yellow_bar"
      },
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

// Due sentieri paralleli vicini (ref "5" esattamente su un punto, "6" a
// ~31 m verso est): per verificare che `trailsNear` restituisca entrambi,
// ordinati per distanza crescente.
const _osm2caiTwoNearbyBody = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": { "ref": "5" },
      "geometry": {
        "type": "LineString",
        "coordinates": [ [7.8694, 45.9369], [7.8694, 45.9378] ]
      }
    },
    {
      "type": "Feature",
      "properties": { "ref": "6" },
      "geometry": {
        "type": "LineString",
        "coordinates": [ [7.8698, 45.9369], [7.8698, 45.9378] ]
      }
    }
  ]
}
''';

// Risposta OSM2CAI a GET /api/v2/hiking-route/{id}: geometria completa (3
// punti, non ritagliata) + ascent/descent/distance precalcolati.
const _osm2caiDetailFeatureBody = '''
{
  "type": "Feature",
  "properties": {
    "ref": "5", "name": "Alta Via del Rifugio",
    "from": "Alagna", "to": "Rifugio Pastore", "cai_scale": "EE",
    "distance": 1234.5, "ascent": 456, "descent": 12
  },
  "geometry": {
    "type": "LineString",
    "coordinates": [ [7.8694, 45.9369], [7.8695, 45.9373], [7.8694, 45.9378] ]
  }
}
''';

// Stessa relazione ma incapsulata in una FeatureCollection (l'altra forma di
// risposta plausibile, mai verificata dal vivo).
const _osm2caiDetailCollectionBody = '''
{
  "type": "FeatureCollection",
  "features": [ $_osm2caiDetailFeatureBody ]
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

    test('lancia TrailLookupException su errore HTTP (non "vuoto")', () async {
      final svc = Osm2CaiTrailService(
          client: MockClient((_) async => http.Response('boom', 500)));
      expect(svc.trailSegmentsAlong([_a, _b]),
          throwsA(isA<TrailLookupException>()));
    });

    test('lista vuota su risposta valida senza sentieri', () async {
      final svc = Osm2CaiTrailService(
          client: _fixed('{"type":"FeatureCollection","features":[]}'));
      expect(await svc.trailSegmentsAlong([_a, _b]), isEmpty);
    });
  });

  group('fetchRelations: id/name/from/to/osmcSymbol', () {
    test('OSM2CAI espone i metadati oltre a ref/geometria', () async {
      final svc = Osm2CaiTrailService(client: _fixed(_osm2caiBody));
      final relations = await svc.fetchRelations([_a, _b]);
      expect(relations, hasLength(1));
      final r = relations.single;
      expect(r.id, '42');
      expect(r.name, 'Alta Via del Rifugio');
      expect(r.from, 'Alagna');
      expect(r.to, 'Rifugio Pastore');
      expect(r.osmcSymbol, 'red:white:red_bar');
    });

    test('Overpass espone id (sempre presente) e i tag OSM standard',
        () async {
      final svc = OverpassTrailService(client: _fixed(_overpassBody));
      final relations = await svc.fetchRelations([_a, _b]);
      expect(relations, hasLength(1));
      final r = relations.single;
      expect(r.id, '123456');
      expect(r.name, 'Sentiero delle Guide');
      expect(r.from, 'Rima');
      expect(r.to, 'Colma');
      expect(r.osmcSymbol, 'yellow:white:yellow_bar');
    });

    test('campi assenti restano null, non stringhe vuote', () async {
      final svc = Osm2CaiTrailService(client: _fixed(_osm2caiReiBody));
      final relations = await svc.fetchRelations([_a, _b]);
      final r = relations.single;
      expect(r.id, isNull);
      expect(r.name, isNull);
      expect(r.from, isNull);
      expect(r.to, isNull);
    });
  });

  group('fetchDetail', () {
    test('OSM2CAI: parsa una risposta "Feature" diretta', () async {
      final svc = Osm2CaiTrailService(client: _fixed(_osm2caiDetailFeatureBody));
      final detail = await svc.fetchDetailById('42');
      expect(detail, isNotNull);
      expect(detail!.ref, '5');
      expect(detail.name, 'Alta Via del Rifugio');
      expect(detail.from, 'Alagna');
      expect(detail.to, 'Rifugio Pastore');
      expect(detail.distanceMeters, 1234.5);
      expect(detail.ascentMeters, 456);
      expect(detail.descentMeters, 12);
      expect(detail.points, hasLength(3)); // geometria completa, non ritagliata
      expect(detail.officialUrl, isNull); // nessun permalink OSM2CAI confermato
    });

    test('OSM2CAI: parsa anche una risposta "FeatureCollection"', () async {
      final svc =
          Osm2CaiTrailService(client: _fixed(_osm2caiDetailCollectionBody));
      final detail = await svc.fetchDetailById('42');
      expect(detail?.ref, '5');
      expect(detail?.points, hasLength(3));
    });

    test('OSM2CAI: lancia TrailLookupException su errore HTTP', () async {
      final svc = Osm2CaiTrailService(
          client: MockClient((_) async => http.Response('boom', 500)));
      expect(svc.fetchDetailById('42'), throwsA(isA<TrailLookupException>()));
    });

    test('Overpass: geometria completa + permalink OSM standard', () async {
      final svc = OverpassTrailService(client: _fixed(_overpassBody));
      final detail = await svc.fetchDetailById('123456');
      expect(detail, isNotNull);
      expect(detail!.ref, '10');
      expect(detail.name, 'Sentiero delle Guide');
      expect(detail.officialUrl, 'https://www.openstreetmap.org/relation/123456');
      expect(detail.distanceMeters, greaterThan(0)); // calcolato localmente
    });

    test('CombinedTrailService: smista in base alla fonte, niente fallback incrociato',
        () async {
      final svc = CombinedTrailService(
        osm2cai: Osm2CaiTrailService(client: _fixed(_osm2caiDetailFeatureBody)),
        overpass: OverpassTrailService(client: _fixed(_overpassBody)),
      );
      final fromOsm2cai = TrailRelation('5', const [], TrailSource.osm2cai, id: '42');
      final detail1 = await svc.fetchDetail(fromOsm2cai);
      expect(detail1?.name, 'Alta Via del Rifugio');

      final fromOverpass =
          TrailRelation('10', const [], TrailSource.overpass, id: '123456');
      final detail2 = await svc.fetchDetail(fromOverpass);
      expect(detail2?.name, 'Sentiero delle Guide');
    });

    test('CombinedTrailService: null se la relazione non ha id', () async {
      final svc = CombinedTrailService(
        osm2cai: Osm2CaiTrailService(client: _fixed(_osm2caiDetailFeatureBody)),
        overpass: OverpassTrailService(client: _fixed(_overpassBody)),
      );
      final noId = TrailRelation('5', const [], TrailSource.osm2cai);
      expect(await svc.fetchDetail(noId), isNull);
    });
  });

  group('trailsNear', () {
    test('trova il segnavia entro la soglia di default, vuoto se lontano',
        () async {
      final svc = Osm2CaiTrailService(client: _fixed(_osm2caiBody));
      final onTheLine = LatLng(45.93735, 7.8694);
      final found = await svc.trailsNear(onTheLine);
      expect(found.map((r) => r.ref), ['5']);

      final farAway = LatLng(45.93735, 7.90); // ben oltre 60 m
      expect(await svc.trailsNear(farAway), isEmpty);
    });

    test('più segnavia vicini: tutti restituiti, ordinati per distanza crescente',
        () async {
      final svc = Osm2CaiTrailService(client: _fixed(_osm2caiTwoNearbyBody));
      // Esattamente sul ref "5"; il ref "6" è ~31 m più a est, entro soglia.
      final point = LatLng(45.9373, 7.8694);
      final found = await svc.trailsNear(point);
      expect(found.map((r) => r.ref).toList(), ['5', '6']);
    });

    test('nessuna eccezione verso il chiamante su errore HTTP: lista vuota',
        () async {
      final svc = Osm2CaiTrailService(
          client: MockClient((_) async => http.Response('boom', 500)));
      expect(await svc.trailsNear(_a), isEmpty);
    });

    test('soglia personalizzata più stretta esclude un segnavia altrimenti valido',
        () async {
      final svc = Osm2CaiTrailService(client: _fixed(_osm2caiTwoNearbyBody));
      // Esattamente su un vertice del ref "5" (distanza 0); il ref "6" ha il
      // suo vertice più vicino a ~31 m, escluso da una soglia di 10 m.
      final point = LatLng(45.9369, 7.8694);
      final found = await svc.trailsNear(point, thresholdMeters: 10);
      expect(found.map((r) => r.ref).toList(), ['5']);
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

    test('ripiega su Overpass quando OSM2CAI fallisce (HTTP)', () async {
      final svc = CombinedTrailService(
        osm2cai: Osm2CaiTrailService(
            client: MockClient((_) async => http.Response('boom', 500))),
        overpass: OverpassTrailService(client: _fixed(_overpassBody)),
      );
      final segs = await svc.trailSegmentsAlong([_a, _b]);
      expect(segs.map((s) => s.ref).toSet(), {'10'});
    });

    test('propaga il fallimento quando anche il fallback fallisce', () async {
      final svc = CombinedTrailService(
        osm2cai: Osm2CaiTrailService(
            client: MockClient((_) async => http.Response('boom', 500))),
        overpass: OverpassTrailService(
            client: MockClient((_) async => http.Response('boom', 500))),
      );
      expect(svc.trailSegmentsAlong([_a, _b]),
          throwsA(isA<TrailLookupException>()));
    });

    test('vuoto genuino quando entrambi rispondono validi ma vuoti', () async {
      final svc = CombinedTrailService(
        osm2cai: Osm2CaiTrailService(
            client: _fixed('{"type":"FeatureCollection","features":[]}')),
        overpass:
            OverpassTrailService(client: _fixed('{"elements":[]}')),
      );
      expect(await svc.trailSegmentsAlong([_a, _b]), isEmpty);
    });
  });
}
