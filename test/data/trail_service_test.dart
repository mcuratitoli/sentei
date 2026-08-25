import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sentei/data/trails/cai_varallo_search_service.dart';
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

// Relazione con 3 "member" way, la centrale (indice 1) data **invertita**
// rispetto alle vicine (il suo ultimo punto, non il primo, è quello che
// combacia col precedente) — riproduce dal vivo il bug del segnavia 251 (25
// ago 2026): un "ramo" a linea retta inesistente su OpenStreetMap, causato
// da una concatenazione ingenua che non controllava l'orientamento.
const _overpassMisorientedMembersBody = '''
{
  "elements": [
    {
      "type": "relation",
      "id": 999,
      "tags": { "ref": "251" },
      "members": [
        {
          "type": "way",
          "geometry": [
            { "lat": 45.70, "lon": 8.00 },
            { "lat": 45.71, "lon": 8.00 }
          ]
        },
        {
          "type": "way",
          "geometry": [
            { "lat": 45.72, "lon": 8.00 },
            { "lat": 45.71, "lon": 8.00 }
          ]
        },
        {
          "type": "way",
          "geometry": [
            { "lat": 45.72, "lon": 8.00 },
            { "lat": 45.73, "lon": 8.00 }
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

// Stesso ref "7", ma con geometria lontana dalla Valsesia (longitudine 15,
// zona Dolomiti) — per verificare che il gate geografico escluda CAI Varallo.
const _osm2caiFarFromValsesiaBody = '''
{
  "type": "Feature",
  "properties": { "ref": "7", "name": "Sentiero lontano" },
  "geometry": {
    "type": "LineString",
    "coordinates": [ [15.0, 46.5], [15.01, 46.5] ]
  }
}
''';

// Estratto reale (semplificato) dell'elenco caivarallo.it, stesso fixture di
// cai_varallo_search_service_test.dart — contiene il ref "5" (usato dalle
// fixture OSM2CAI qui sopra) così `findByRef('5')` trova un match esatto.
const _caiVaralloResultsBody = '''
<a href="sentieri-valsesia-dettaglio.php?sentiero=417" class="nosottolineato">Segnavia <span class="fasciarossa">&nbsp;5 (51)&nbsp;</span></a> | Catasto <span class="fasciaazzurra">&nbsp;5&nbsp;</span></a>  | Dislivello: 1535 m<br /><a href="sentieri-valsesia-dettaglio.php?sentiero=417" class="nosottolineato"><h3><strong>Alta Via del Rifugio ...</strong></h3></a>&nbsp;<br />Partenza da: Alagna - Arrivo: Rifugio Pastore<br /><br /><br /><br />
''';

// Stesso elenco ma senza il ref "5": `findByRef('5')` deve dare `null`, non
// un match a caso su un altro ref presente in pagina.
const _caiVaralloNoResultsBody = '''
<a href="sentieri-valsesia-dettaglio.php?sentiero=427" class="nosottolineato">Segnavia <span class="fasciarossa">&nbsp;253 (53)&nbsp;</span></a> | Catasto <span class="fasciaazzurra">&nbsp;253&nbsp;</span></a>  | Dislivello: 900 m<br /><a href="sentieri-valsesia-dettaglio.php?sentiero=427" class="nosottolineato"><h3><strong>Bocchetta del Croso ...</strong></h3></a>&nbsp;<br />Partenza da: Alpe Toso - Arrivo: Bocchetta del Croso<br /><br /><br /><br />
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

    test(
        'Overpass: raddrizza un member way invertito, niente ramo a linea retta '
        '(bug segnavia 251, 25 ago 2026)', () async {
      final svc =
          OverpassTrailService(client: _fixed(_overpassMisorientedMembersBody));
      final detail = await svc.fetchDetailById('999');
      expect(detail, isNotNull);
      // Percorso continuo dal capo all'altro: nessun salto fra punti
      // consecutivi (i due estremi sono ~333 m via haversine; se il member
      // invertito non fosse raddrizzato, un salto isolato supererebbe
      // ampiamente questa soglia).
      const distance = Distance();
      for (var i = 0; i < detail!.points.length - 1; i++) {
        expect(distance(detail.points[i], detail.points[i + 1]), lessThan(2000));
      }
      expect(detail.points.first.latitude, closeTo(45.70, 1e-9));
      expect(detail.points.last.latitude, closeTo(45.73, 1e-9));
    });

    test('CombinedTrailService: smista in base alla fonte, niente fallback incrociato',
        () async {
      final svc = CombinedTrailService(
        osm2cai: Osm2CaiTrailService(client: _fixed(_osm2caiDetailFeatureBody)),
        overpass: OverpassTrailService(client: _fixed(_overpassBody)),
        caiVarallo: CaiVaralloSearchService(client: _fixed(_caiVaralloNoResultsBody)),
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
        caiVarallo: CaiVaralloSearchService(client: _fixed(_caiVaralloNoResultsBody)),
      );
      final noId = TrailRelation('5', const [], TrailSource.osm2cai);
      expect(await svc.fetchDetail(noId), isNull);
    });

    test(
        'CombinedTrailService: fetch della geometria completa fallito → '
        'dettaglio parziale con ciò che si sa già, non null (feedback utente '
        '25 ago 2026: "non ha senso non mostrare nulla")', () async {
      final svc = CombinedTrailService(
        overpass: OverpassTrailService(
          hedgeDelay: Duration.zero,
          client: MockClient((_) async => http.Response('boom', 500)),
        ),
        caiVarallo: CaiVaralloSearchService(client: _fixed(_caiVaralloResultsBody)),
      );
      // Punto in Valsesia (dentro il riquadro): geometria "ritagliata" già
      // nota dalla ricerca precedente, non quella completa.
      final relation = TrailRelation(
        '5',
        const [LatLng(45.93, 7.87)],
        TrailSource.overpass,
        id: '999',
        name: 'Alta Via del Rifugio',
        from: 'Alagna',
        to: 'Rifugio Pastore',
        caiScale: 'EE',
      );
      final detail = await svc.fetchDetail(relation);
      expect(detail, isNotNull);
      expect(detail!.geometryComplete, isFalse);
      expect(detail.name, 'Alta Via del Rifugio');
      expect(detail.from, 'Alagna');
      expect(detail.to, 'Rifugio Pastore');
      expect(detail.caiScale, 'EE');
      expect(detail.points, relation.points);
      expect(detail.officialUrl, 'https://www.openstreetmap.org/relation/999');
      expect(detail.distanceMeters, isNull); // non calcolabile senza la geometria vera
      // CAI Varallo tentato comunque: non dipende dal fetch fallito.
      expect(detail.caiVarallo, isNotNull);
    });

    test(
        'CombinedTrailService: fetch fallito e relazione senza punti noti → '
        'null (niente su cui costruire nemmeno un dettaglio parziale)',
        () async {
      final svc = CombinedTrailService(
        overpass: OverpassTrailService(
          hedgeDelay: Duration.zero,
          client: MockClient((_) async => http.Response('boom', 500)),
        ),
      );
      final relation =
          TrailRelation('5', const [], TrailSource.overpass, id: '999');
      expect(await svc.fetchDetail(relation), isNull);
    });

    test(
        'CombinedTrailService: fetch fallito, fonte OSM2CAI → dettaglio '
        'parziale ma senza officialUrl inventato', () async {
      final svc = CombinedTrailService(
        osm2cai: Osm2CaiTrailService(
            client: MockClient((_) async => http.Response('boom', 500))),
      );
      final relation = TrailRelation(
        '5',
        const [LatLng(46.5, 15.0)], // fuori Valsesia: niente CAI Varallo
        TrailSource.osm2cai,
        id: '999',
      );
      final detail = await svc.fetchDetail(relation);
      expect(detail, isNotNull);
      expect(detail!.geometryComplete, isFalse);
      expect(detail.officialUrl, isNull);
    });

    test(
        'CombinedTrailService: in Valsesia interroga anche CAI Varallo e allega i risultati',
        () async {
      // _osm2caiDetailFeatureBody ha geometria vicino a Punta Gnifetti/Alagna
      // (45.93, 7.87): dentro il riquadro Valsesia.
      final svc = CombinedTrailService(
        osm2cai: Osm2CaiTrailService(client: _fixed(_osm2caiDetailFeatureBody)),
        overpass: OverpassTrailService(client: _fixed(_overpassBody)),
        caiVarallo: CaiVaralloSearchService(client: _fixed(_caiVaralloResultsBody)),
      );
      final relation = TrailRelation('5', const [], TrailSource.osm2cai, id: '42');
      final detail = await svc.fetchDetail(relation);
      expect(detail?.caiVarallo, isNotNull);
      expect(detail?.caiVarallo?.title, contains('Alta Via del Rifugio'));
    });

    test(
        'CombinedTrailService: fuori Valsesia NON interroga CAI Varallo (nessuna richiesta)',
        () async {
      var called = false;
      final svc = CombinedTrailService(
        // Geometria a longitudine 15 (fuori dal riquadro Valsesia, es. Dolomiti).
        osm2cai: Osm2CaiTrailService(client: _fixed(_osm2caiFarFromValsesiaBody)),
        overpass: OverpassTrailService(client: _fixed(_overpassBody)),
        caiVarallo: CaiVaralloSearchService(
            client: MockClient((_) async {
          called = true;
          return http.Response(_caiVaralloResultsBody, 200);
        })),
      );
      final relation = TrailRelation('7', const [], TrailSource.osm2cai, id: '99');
      final detail = await svc.fetchDetail(relation);
      expect(detail?.caiVarallo, isNull);
      expect(called, isFalse);
    });

    test(
        'CombinedTrailService: in Valsesia ma CAI Varallo non trova nulla → caiVaralloResults vuoto',
        () async {
      final svc = CombinedTrailService(
        osm2cai: Osm2CaiTrailService(client: _fixed(_osm2caiDetailFeatureBody)),
        overpass: OverpassTrailService(client: _fixed(_overpassBody)),
        caiVarallo: CaiVaralloSearchService(client: _fixed(_caiVaralloNoResultsBody)),
      );
      final relation = TrailRelation('5', const [], TrailSource.osm2cai, id: '42');
      final detail = await svc.fetchDetail(relation);
      expect(detail?.caiVarallo, isNull);
    });

    test(
        'CombinedTrailService: CAI Varallo parte in parallelo al fetch della '
        'geometria, non dopo (richiesta esplicita utente 25 ago 2026: "non è '
        'un ultima spiaggia")', () async {
      final svc = CombinedTrailService(
        osm2cai: Osm2CaiTrailService(
            client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return http.Response(_osm2caiDetailFeatureBody, 200);
        })),
        caiVarallo: CaiVaralloSearchService(
            client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return http.Response(_caiVaralloResultsBody, 200);
        })),
      );
      // Punto già noto sulla relazione (dentro il riquadro Valsesia): decide
      // "in Valsesia" prima ancora di aspettare il fetch della geometria.
      final relation = TrailRelation(
          '5', const [LatLng(45.93, 7.87)], TrailSource.osm2cai, id: '42');
      final sw = Stopwatch()..start();
      final detail = await svc.fetchDetail(relation);
      sw.stop();
      expect(detail?.caiVarallo, isNotNull);
      // Se fossero in sequenza ci vorrebbero ~160ms; in parallelo, ~80ms.
      expect(sw.elapsedMilliseconds, lessThan(140));
    });
  });

  group('fetchByRefOnly', () {
    test(
        'in Valsesia e trovato su CAI Varallo → dettaglio parziale con quel '
        'link (ultima spiaggia per la card traccia quando Overpass/OSM2CAI '
        'non risolvono nemmeno la relazione)', () async {
      final svc = CombinedTrailService(
        caiVarallo: CaiVaralloSearchService(client: _fixed(_caiVaralloResultsBody)),
      );
      final detail = await svc.fetchByRefOnly('5', const LatLng(45.93, 7.87));
      expect(detail, isNotNull);
      expect(detail!.geometryComplete, isFalse);
      expect(detail.caiVarallo, isNotNull);
    });

    test('fuori Valsesia → null, nessuna richiesta CAI Varallo', () async {
      var called = false;
      final svc = CombinedTrailService(
        caiVarallo: CaiVaralloSearchService(
            client: MockClient((_) async {
          called = true;
          return http.Response(_caiVaralloResultsBody, 200);
        })),
      );
      final detail =
          await svc.fetchByRefOnly('5', const LatLng(46.5, 15.0));
      expect(detail, isNull);
      expect(called, isFalse);
    });

    test('in Valsesia ma non in elenco CAI Varallo → null', () async {
      final svc = CombinedTrailService(
        caiVarallo: CaiVaralloSearchService(client: _fixed(_caiVaralloNoResultsBody)),
      );
      final detail = await svc.fetchByRefOnly('5', const LatLng(45.93, 7.87));
      expect(detail, isNull);
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

    test(
        'Overpass: la soglia richiesta diventa il raggio della query, non il '
        'default fisso dell\'istanza (bug osservato dal vivo, 25 ago 2026: '
        'un segnavia a 50-60 m veniva scartato perché mai scaricato, con un '
        'raggio fisso di 40 m indipendente dalla soglia)', () async {
      String? capturedBody;
      final svc = OverpassTrailService(
        aroundMeters: 40,
        client: MockClient((request) async {
          capturedBody = request.body;
          return http.Response(_overpassBody, 200);
        }),
      );
      await svc.trailsNear(_a, thresholdMeters: 150);
      expect(capturedBody, contains('around%3A150.0%2C'));
      expect(capturedBody, isNot(contains('around%3A40%2C')));
    });

    test('Overpass: senza soglia esplicita (trailSegmentsAlong) usa il default',
        () async {
      String? capturedBody;
      final svc = OverpassTrailService(
        aroundMeters: 40,
        client: MockClient((request) async {
          capturedBody = request.body;
          return http.Response(_overpassBody, 200);
        }),
      );
      await svc.trailSegmentsAlong([_a, _b]);
      expect(capturedBody, contains('around%3A40%2C'));
    });

    test(
        'Overpass: corsa a staffetta — un mirror più veloce vince senza '
        'aspettare il timeout pieno dell\'istanza principale lenta', () async {
      final svc = OverpassTrailService(
        hedgeDelay: const Duration(milliseconds: 5),
        perAttemptTimeout: const Duration(milliseconds: 300),
        client: MockClient((request) async {
          if (request.url.toString() == 'https://overpass-api.de/api/interpreter') {
            // Mai entro perAttemptTimeout: se la staffetta non scattasse, il
            // test impiegherebbe almeno 300ms.
            await Future<void>.delayed(const Duration(milliseconds: 600));
          }
          return http.Response(_overpassBody, 200);
        }),
      );
      final sw = Stopwatch()..start();
      final result = await svc.fetchRelations([_a]);
      sw.stop();
      expect(result, isNotEmpty);
      expect(sw.elapsedMilliseconds, lessThan(150));
    });

    test(
        'Overpass: un fallimento rapido (non un timeout) fa scattare subito '
        'il mirror, senza aspettare tutto il ritardo di staffetta', () async {
      final svc = OverpassTrailService(
        hedgeDelay: const Duration(milliseconds: 500),
        client: MockClient((request) async {
          if (request.url.toString() == 'https://overpass-api.de/api/interpreter') {
            return http.Response('boom', 500); // fallimento immediato, non un timeout
          }
          return http.Response(_overpassBody, 200);
        }),
      );
      final sw = Stopwatch()..start();
      final result = await svc.fetchRelations([_a]);
      sw.stop();
      expect(result, isNotEmpty);
      expect(sw.elapsedMilliseconds, lessThan(200)); // ben sotto i 500ms di stagger
    });

    test(
        'Overpass: interruttore dopo un fallimento totale, la richiesta '
        'successiva salta la rete del tutto', () async {
      var callCount = 0;
      final svc = OverpassTrailService(
        hedgeDelay: Duration.zero,
        client: MockClient((_) async {
          callCount++;
          return http.Response('boom', 500);
        }),
      );
      await expectLater(
          svc.fetchRelations([_a]), throwsA(isA<TrailLookupException>()));
      final callsAfterFirstFailure = callCount;
      expect(callsAfterFirstFailure, greaterThan(0));

      // Subito dopo, senza aspettare: l'interruttore è attivo, nessuna nuova
      // richiesta di rete deve partire.
      await expectLater(
          svc.fetchRelations([_a]), throwsA(isA<TrailLookupException>()));
      expect(callCount, callsAfterFirstFailure);
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
            // hedgeDelay azzerato: altrimenti il test aspetterebbe per
            // davvero la staffetta fra i mirror anche con un mock istantaneo.
            hedgeDelay: Duration.zero,
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
