import 'package:http/http.dart' as http;

/// Un segnavia trovato nell'elenco ufficiale di CAI Varallo (§"Un segnavia
/// per intero" — arricchimento locale per i segnavia in Valsesia e
/// dintorni, dove il sito della sottosezione ha spesso più dettagli/foto
/// del permalink OSM generico).
class CaiVaralloResult {
  const CaiVaralloResult({required this.title, required this.url});
  final String title;
  final String url;
}

/// Cerca un segnavia nell'**elenco ufficiale** di CAI Varallo
/// (`sentieri-tutti.php?ord=segnavia`, ordinato per numero), non con una
/// ricerca full-text: la ricerca nativa del vecchio sito WordPress
/// (`caivarallo.com`, tentativo precedente) restituiva risultati "trovati"
/// ma **non pertinenti al segnavia** (eventi, notizie, pagine casuali) — un
/// numero di sentiero è un pessimo termine di ricerca full-text. L'elenco
/// invece associa ogni **numero di catasto** (`ref`, colonna "Catasto",
/// affidabile — a differenza della colonna "Segnavia" che include vecchie
/// numerazioni fra parentesi) al suo id pagina (`?sentiero=<id>`): un match
/// esatto sul ref è o giusto o assente, mai "vagamente pertinente".
///
/// **Verificato dal vivo** il 25 agosto 2026: 441 voci su un'unica pagina
/// (nessuna paginazione, nonostante il dubbio iniziale), struttura HTML
/// confermata con richieste `curl` reali (non un formato indovinato).
class CaiVaralloSearchService {
  CaiVaralloSearchService({
    http.Client? client,
    this.listUrl =
        'https://www.caivarallo.it/valsesia/sentieri-valsesia/sentieri-tutti.php?ord=segnavia',
    this.detailBaseUrl =
        'https://www.caivarallo.it/valsesia/sentieri-valsesia/sentieri-valsesia-dettaglio.php',
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String listUrl;
  final String detailBaseUrl;
  final Duration timeout;

  // Cattura, per ogni voce dell'elenco: (1) l'id pagina dal primo link
  // "Segnavia ...", (2) il ref pulito dalla colonna "Catasto" (senza la
  // vecchia numerazione fra parentesi che compare invece nella colonna
  // "Segnavia"), (3) il titolo dal successivo <h3> — non necessariamente
  // sulla stessa riga di testo, da qui `dotAll`. Verificato su un dump reale
  // (25 ago 2026): 441 voci, nessun match saltato alla voce sbagliata
  // nonostante il `.*?` non goloso fra "Catasto" e il titolo.
  static final RegExp _entryPattern = RegExp(
    r'<a href="sentieri-valsesia-dettaglio\.php\?sentiero=(\d+)" class="nosottolineato">'
    r'Segnavia <span class="fasciarossa">[^<]*</span></a> \| '
    r'Catasto <span class="fasciaazzurra">&nbsp;([^&]*?)&nbsp;</span></a>'
    r'.*?<h3><strong>\s*([^<]*?)\s*</strong></h3>',
    dotAll: true,
  );

  /// Cerca [ref] (numero segnavia, es. "251") nell'elenco. Best-effort come
  /// il resto di `data/trails/`: mai un'eccezione verso il chiamante, `null`
  /// su qualunque errore o se il ref non compare in elenco — è un
  /// arricchimento, non deve mai bloccare la card di dettaglio.
  Future<CaiVaralloResult?> findByRef(String ref) async {
    final target = ref.trim();
    if (target.isEmpty) return null;
    try {
      final res = await _client
          .get(Uri.parse(listUrl),
              headers: const {'User-Agent': 'sentei/1.0 (app escursionismo Alpi)'})
          .timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = res.body;
      for (final m in _entryPattern.allMatches(body)) {
        if (m.group(2)!.trim() != target) continue;
        final id = m.group(1)!;
        final title = _cleanTitle(m.group(3)!);
        return CaiVaralloResult(
          title: title.isEmpty ? 'Segnavia $target' : title,
          url: '$detailBaseUrl?sentiero=$id',
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Il sito chiude ogni titolo dell'elenco con " ..." (non una troncatura
  /// reale: la pagina di dettaglio ha lo stesso titolo senza puntini) e usa
  /// spazi doppi in alcuni nomi composti — ripulito qui invece che con un
  /// secondo fetch della pagina di dettaglio solo per il titolo.
  static String _cleanTitle(String raw) => raw
      .replaceAll(RegExp(r'\s*\.\.\.\s*$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
