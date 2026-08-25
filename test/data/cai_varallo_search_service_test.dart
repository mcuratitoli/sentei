import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentei/data/trails/cai_varallo_search_service.dart';

// Estratto reale (semplificato, 2 voci) dell'elenco
// `sentieri-tutti.php?ord=segnavia` di caivarallo.it del 25 ago 2026 —
// verificato dal vivo con curl, non un formato indovinato. La colonna
// "Segnavia" include la vecchia numerazione fra parentesi (qui "(51)"): il
// match va fatto sulla colonna "Catasto", pulita. Il titolo ha uno spazio
// doppio e i "..." finali che il sito stesso aggiunge (non troncamento: la
// pagina di dettaglio ha lo stesso titolo senza puntini) — verifica che il
// parser li ripulisca.
const _listBody = '''
<a href="sentieri-valsesia-dettaglio.php?sentiero=417" class="nosottolineato">Segnavia <span class="fasciarossa">&nbsp;251 (51)&nbsp;</span></a> | Catasto <span class="fasciaazzurra">&nbsp;251&nbsp;</span></a>  | Dislivello: 1535 m<br /><a href="sentieri-valsesia-dettaglio.php?sentiero=417" class="nosottolineato"><h3><strong>Rassa - Alpe Toso -  Colle del Loo ...</strong></h3></a>&nbsp;<br />Partenza da: Rassa - Arrivo: Colle del Loo<br /><br /><br /><br /><a href="sentieri-valsesia-dettaglio.php?sentiero=427" class="nosottolineato">Segnavia <span class="fasciarossa">&nbsp;253 (53)&nbsp;</span></a> | Catasto <span class="fasciaazzurra">&nbsp;253&nbsp;</span></a>  | Dislivello: 900 m<br /><a href="sentieri-valsesia-dettaglio.php?sentiero=427" class="nosottolineato"><h3><strong>Bocchetta del Croso ...</strong></h3></a>&nbsp;<br />Partenza da: Alpe Toso - Arrivo: Bocchetta del Croso<br /><br /><br /><br />
''';

http.Client _fixed(String body) => MockClient((_) async => http.Response(body, 200));

void main() {
  group('CaiVaralloSearchService.findByRef', () {
    test('trova il segnavia nell\'elenco (match esatto sulla colonna Catasto)',
        () async {
      final svc = CaiVaralloSearchService(client: _fixed(_listBody));
      final result = await svc.findByRef('251');
      expect(result, isNotNull);
      expect(result!.title, 'Rassa - Alpe Toso - Colle del Loo');
      expect(result.url,
          'https://www.caivarallo.it/valsesia/sentieri-valsesia/sentieri-valsesia-dettaglio.php?sentiero=417');
    });

    test('un secondo segnavia nello stesso elenco', () async {
      final svc = CaiVaralloSearchService(client: _fixed(_listBody));
      final result = await svc.findByRef('253');
      expect(result, isNotNull);
      expect(result!.title, 'Bocchetta del Croso');
      expect(result.url, contains('sentiero=427'));
    });

    test('ref non in elenco: null, non un match a caso', () async {
      final svc = CaiVaralloSearchService(client: _fixed(_listBody));
      expect(await svc.findByRef('999'), isNull);
    });

    test('non confonde "251" con "251a" (vecchia numerazione fra parentesi '
        'esclusa dal match)', () async {
      final svc = CaiVaralloSearchService(client: _fixed(_listBody));
      expect(await svc.findByRef('51'), isNull);
    });

    test('ref vuoto: nessuna richiesta, null', () async {
      var called = false;
      final svc = CaiVaralloSearchService(
          client: MockClient((_) async {
        called = true;
        return http.Response(_listBody, 200);
      }));
      expect(await svc.findByRef('   '), isNull);
      expect(called, isFalse);
    });

    test('errore HTTP o di rete: mai un\'eccezione, null', () async {
      final httpError = CaiVaralloSearchService(
          client: MockClient((_) async => http.Response('boom', 500)));
      expect(await httpError.findByRef('251'), isNull);

      final networkError = CaiVaralloSearchService(
          client: MockClient((_) async => throw Exception('no network')));
      expect(await networkError.findByRef('251'), isNull);
    });
  });
}
