import 'package:flutter/foundation.dart' show debugPrint;
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
///
/// ⚠️ **Aggiornamento 26 agosto 2026** — quella verifica non è più affidabile
/// al 100%: un segnavia (251C) confermato manualmente presente sul sito non
/// veniva trovato dall'app, e un `curl` diretto nella stessa serata ha
/// restituito **due volte di fila una pagina con `HTTP 200` ma zero righe**
/// (struttura della pagina intatta — stesso "Ordina per", stesso footer "Vai
/// alle pagine >>" — ma l'elenco vuoto in mezzo), a fronte di richieste
/// dell'app riuscite poco prima con centinaia di voci. Il sito sembra quindi
/// **intermittente** (nella stessa categoria di affidabilità di Overpass,
/// non un bug di parsing nostro confermato) — ma non è escluso al 100% un
/// problema di formato/match dal nostro lato. Non ancora approfondito, vedi
/// `docs/ROADMAP.md` (bug aperto). Log diagnostici aggiunti in [findByRef]
/// per la prossima sessione: distinguono "pagina arrivata ma vuota" da
/// "pagina con voci ma nessun match".
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
      if (res.statusCode != 200) {
        debugPrint('[trails] caivarallo "$target": HTTP ${res.statusCode}');
        return null;
      }
      final body = res.body;
      // Log diagnostico permanente (non solo per il bug del 26 ago 2026 sul
      // segnavia 251C, mai trovato nonostante esista sul sito): distingue
      // "la pagina è arrivata ma senza righe" (probabile intermittenza del
      // sito, osservata dal vivo con `curl` diretto la stessa notte — due
      // richieste di fila hanno restituito la lista completamente vuota,
      // pur con `HTTP 200` e la struttura della pagina intatta) da "la
      // pagina aveva righe ma nessuna con questo ref esatto" (più probabile
      // un problema di formato/match nostro). Senza questo, i due casi sono
      // indistinguibili da un `null` secco nei log.
      var count = 0;
      for (final m in _entryPattern.allMatches(body)) {
        count++;
        if (m.group(2)!.trim() != target) continue;
        final id = m.group(1)!;
        final title = _cleanTitle(m.group(3)!);
        debugPrint('[trails] caivarallo "$target": trovato dopo $count voci '
            '(su almeno altrettante nella pagina)');
        return CaiVaralloResult(
          title: title.isEmpty ? 'Segnavia $target' : title,
          url: '$detailBaseUrl?sentiero=$id',
        );
      }
      debugPrint('[trails] caivarallo "$target": non trovato fra $count voci '
          'nella pagina${count == 0 ? " (lista vuota — probabile intermittenza "
              "del sito, non necessariamente un ref inesistente)" : ""}');
      return null;
    } catch (e) {
      debugPrint('[trails] caivarallo "$target" fallito: $e');
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
