import 'package:http/http.dart' as http;

/// Un risultato di ricerca sul sito di CAI Varallo (§"Un segnavia per
/// intero" — arricchimento locale per i segnavia in Valsesia e dintorni,
/// dove il sito della sottosezione ha spesso più dettagli/foto del
/// permalink OSM generico).
class CaiVaralloResult {
  const CaiVaralloResult({required this.title, required this.url});
  final String title;
  final String url;
}

/// Cerca sul sito pubblico di **CAI Varallo** (WordPress, tema Divi) usando
/// la ricerca nativa `?s=`. **Verificato dal vivo** (a differenza dell'id
/// OSM2CAI, questo dominio non è bloccato dalla network policy del sandbox
/// di sviluppo — controllato con richieste reali il 24 ago 2026): ogni
/// risultato è un titolo con link dentro un tag di intestazione H2 con
/// classe `entry-title`, sulla pagina di ricerca vera (classe `search-results`
/// sul body); una ricerca senza esito ha invece `search-no-results` nella
/// classe del body. Il tema mostra anche un widget "Notizie" fuori dai
/// risultati con la stessa classe `entry-title` ma su un tag H5, non H2 —
/// filtrare esattamente per H2 evita di raccoglierlo per sbaglio.
class CaiVaralloSearchService {
  CaiVaralloSearchService({
    http.Client? client,
    this.baseUrl = 'https://www.caivarallo.com/',
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  static final RegExp _resultPattern =
      RegExp(r'<h2 class="entry-title"><a href="([^"]+)">([^<]*)</a></h2>');

  /// Cerca [query] (tipicamente il nome o il numero del segnavia). Best-effort
  /// come il resto di `data/trails/`: mai un'eccezione verso il chiamante,
  /// lista vuota su qualunque errore — è un arricchimento, non deve mai
  /// bloccare la card di dettaglio.
  Future<List<CaiVaralloResult>> search(String query, {int maxResults = 5}) async {
    if (query.trim().isEmpty) return const [];
    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: {'s': query});
      final res = await _client
          .get(uri, headers: const {'User-Agent': 'sentei/1.0 (app escursionismo Alpi)'})
          .timeout(timeout);
      if (res.statusCode != 200) return const [];
      final body = res.body;
      if (body.contains('search-no-results')) return const [];

      final out = <CaiVaralloResult>[];
      for (final m in _resultPattern.allMatches(body)) {
        if (out.length >= maxResults) break;
        final url = m.group(1)!;
        final title = _decodeHtmlEntities(m.group(2)!.trim());
        if (title.isEmpty) continue;
        out.add(CaiVaralloResult(title: title, url: url));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Le poche entità HTML che compaiono davvero nei titoli di questo sito
  /// (visto nelle risposte reali: `&#8211;` per il trattino lungo). Non un
  /// decoder HTML generico — non serve, i titoli sono testo semplice.
  static String _decodeHtmlEntities(String s) => s
      .replaceAll('&#8211;', '–')
      .replaceAll('&#8217;', '’')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'");
}
