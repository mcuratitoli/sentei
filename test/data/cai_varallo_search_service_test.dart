import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentei/data/trails/cai_varallo_search_service.dart';

// Estratto reale (semplificato) di una risposta di ricerca caivarallo.com
// del 24 ago 2026 — verificato dal vivo con curl, non un formato inventato.
// Include anche un blocco "Notizie" con entry-title su H5 (non risultati di
// ricerca), per verificare che il parser lo ignori.
const _searchResultsBody = '''
<!DOCTYPE html>
<html lang="it-IT">
<body class="search search-results wp-theme-Divi">
	<article id="post-987509313" class="et_pb_post ...">
		<h2 class="entry-title"><a href="https://www.caivarallo.com/eventi-attivita-cai/festa-della-famiglia-alpe-bors-alagna-valsesia/">FESTA DELLA FAMIGLIA &#8211; ALPE BORS (ALAGNA VALSESIA)</a></h2>
	</article>
	<article id="post-987507594" class="et_pb_post ...">
		<h2 class="entry-title"><a href="https://www.caivarallo.com/rifugi-cai-varallo/capanna-sociale-alagna/">Baita Alagna</a></h2>
	</article>
	<div class="et_pb_text_inner"><h3>Notizie</h3></div>
	<article id="post-987509411" class="et_pb_post clearfix ...">
		<h5 class="entry-title">Voce del widget "Notizie", non un risultato di ricerca</h5>
	</article>
</body>
</html>
''';

const _noResultsBody = '''
<!DOCTYPE html>
<html lang="it-IT">
<body class="search search-no-results wp-theme-Divi">
	<h1 class="not-found-title">No Results Found</h1>
</body>
</html>
''';

http.Client _fixed(String body) => MockClient((_) async => http.Response(body, 200));

void main() {
  group('CaiVaralloSearchService.search', () {
    test('estrae i risultati reali (H2), ignora il widget "Notizie" (H5)', () async {
      final svc = CaiVaralloSearchService(client: _fixed(_searchResultsBody));
      final results = await svc.search('Alagna');
      expect(results, hasLength(2));
      expect(results[0].title, 'FESTA DELLA FAMIGLIA – ALPE BORS (ALAGNA VALSESIA)');
      expect(results[0].url,
          'https://www.caivarallo.com/eventi-attivita-cai/festa-della-famiglia-alpe-bors-alagna-valsesia/');
      expect(results[1].title, 'Baita Alagna');
    });

    test('nessun risultato: body con "search-no-results" → lista vuota', () async {
      final svc = CaiVaralloSearchService(client: _fixed(_noResultsBody));
      expect(await svc.search('xyzqqqnonexistentquery'), isEmpty);
    });

    test('rispetta maxResults', () async {
      final svc = CaiVaralloSearchService(client: _fixed(_searchResultsBody));
      final results = await svc.search('Alagna', maxResults: 1);
      expect(results, hasLength(1));
    });

    test('query vuota: nessuna richiesta, lista vuota', () async {
      var called = false;
      final svc = CaiVaralloSearchService(
          client: MockClient((_) async {
        called = true;
        return http.Response(_searchResultsBody, 200);
      }));
      expect(await svc.search('   '), isEmpty);
      expect(called, isFalse);
    });

    test('errore HTTP o di rete: mai un\'eccezione, lista vuota', () async {
      final httpError = CaiVaralloSearchService(
          client: MockClient((_) async => http.Response('boom', 500)));
      expect(await httpError.search('Alagna'), isEmpty);

      final networkError = CaiVaralloSearchService(
          client: MockClient((_) async => throw Exception('no network')));
      expect(await networkError.search('Alagna'), isEmpty);
    });
  });
}
