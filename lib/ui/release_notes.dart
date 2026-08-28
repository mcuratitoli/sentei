import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Una voce di **Novità** o **Roadmap**: icona + titolo + (opzionale) una riga
/// di spiegazione.
///
/// Stesso tipo per le tre superfici che raccontano cosa cambia — tab "Novità",
/// tab "Roadmap" e card di primo avvio (`whats_new.dart`) — così sono anche
/// rese dallo stesso widget ([NoteRow]) e non possono divergere nell'aspetto.
///
/// Il [title] è una riga sola e sta in grassetto: tenerlo corto (4-7 parole).
/// Il [body] spiega *perché* interessa a chi cammina, non come è fatto: va
/// omesso quando il titolo si spiega da sé, altrimenti la lista diventa un
/// muro di testo.
class NoteItem {
  const NoteItem({required this.title, this.body, this.icon});

  final String title;
  final String? body;

  /// Icona **lineare** (`CupertinoIcons`), come ogni icona dell'app
  /// (`design/DESIGN_GUIDELINES.md` §1) — niente emoji qui: in
  /// `CHANGELOG.md` l'emoji fa da marcatore di categoria nel testo, qui la
  /// stessa categoria è resa dall'icona nel quadratino d'accento.
  /// Default: [CupertinoIcons.sparkles].
  final IconData? icon;
}

/// Novità per versione (Impostazioni → Informazioni → Sentèi, tab "Novità"),
/// in forma **sintetica** — versione completa e dettagliata in `CHANGELOG.md`
/// alla radice del repo. **Tenere le due liste allineate**: quando si
/// aggiorna `CHANGELOG.md` per una nuova versione, aggiungere qui la voce
/// corrispondente nella stessa sessione di lavoro (vedi anche `CLAUDE.md` §9).
///
/// Vedi anche [kRoadmapGroups] più sotto: stessa idea ma per la tab
/// "Roadmap" (prossime priorità, non ancora rilasciate).
class ReleaseNote {
  const ReleaseNote({
    required this.version,
    required this.build,
    required this.date,
    required this.highlights,
    this.spotlight = const [],
  });

  final String version;
  final int build;

  /// Data testuale breve (es. "5 luglio 2026").
  final String date;

  /// Punti salienti, tipicamente 3-6 voci (di più solo per una release
  /// grande che ne accumula molte). Se ci sono fix minori non elencati uno
  /// per uno, chiudere con una voce generica "Bugfix e rifiniture" invece di
  /// lasciarli fuori — l'elenco completo resta comunque in `CHANGELOG.md`.
  final List<NoteItem> highlights;

  /// Versione "raccontata" degli [highlights] — le stesse voci con una
  /// spiegazione più distesa — per la card **Novità** che compare al primo
  /// avvio dopo un aggiornamento (`whats_new.dart`). Serve solo alla release
  /// più recente: sulle vecchie si può lasciare vuota, e la card ripiega
  /// sugli [highlights].
  final List<NoteItem> spotlight;
}

const List<ReleaseNote> kReleaseNotes = [
  ReleaseNote(
    version: '1.0.0',
    build: 10,
    date: '26 agosto 2026',
    highlights: [
      NoteItem(
        icon: CupertinoIcons.signature,
        title: 'Un segnavia per intero',
        body: 'Tocca il numero di un sentiero per vedere dove parte, dove '
            'arriva e il percorso completo sulla mappa, con link a '
            'OpenStreetMap e — in Valsesia — a CAI Varallo.',
      ),
      NoteItem(
        icon: CupertinoIcons.scribble,
        title: 'Traccia "mista": tratti liberi fuori sentiero',
        body: 'Il tasto "Libero" fa collegare in linea retta invece di '
            'seguire i sentieri, per un tratto specifico.',
      ),
      NoteItem(
        icon: CupertinoIcons.map_pin_ellipse,
        title: 'Punto selezionato più completo',
        body: 'Mostra anche le coordinate e permette di aggiungere un '
            'punto anche dopo, non solo prima.',
      ),
      NoteItem(
        icon: CupertinoIcons.ellipsis_circle,
        title: 'Menu a tre pallini più coerenti',
        body: 'Stesse voci sulla card traccia e nella lista tracciati.',
      ),
      NoteItem(
        icon: CupertinoIcons.wrench,
        title: 'Bugfix e rifiniture',
        body: 'Punto inserito su un tratto sul sentiero, log più leggibili, '
            'piccole correzioni grafiche non tutte elencate qui.',
      ),
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 9,
    date: '23 agosto 2026',
    highlights: [
      NoteItem(
        icon: CupertinoIcons.photo,
        title: 'Esporta un\'immagine del percorso',
        body: 'Mappa 3D con nome, dati e punti di interesse, pronta da '
            'condividere.',
      ),
      NoteItem(
        icon: CupertinoIcons.delete,
        title: 'Elimina la traccia dalla sua card sulla mappa',
      ),
      NoteItem(
        icon: CupertinoIcons.checkmark_seal,
        title: 'Indicatore "salvata offline" su ogni traccia',
      ),
      NoteItem(
        icon: CupertinoIcons.clock,
        title: 'Tempo di percorrenza stimato (metodo CAI)',
      ),
      NoteItem(
        icon: CupertinoIcons.photo_on_rectangle,
        title: 'Foto più veloci e leggere',
        body: 'Si aprono e scorrono più in fretta, pesano meno nel cloud.',
      ),
      NoteItem(
        icon: CupertinoIcons.trash_circle,
        title: 'Corretta una cache che cresceva senza limiti',
        body: 'I dati di elevazione ora hanno un tetto e liberano lo '
            'spazio già occupato prima d\'ora.',
      ),
      NoteItem(
        icon: CupertinoIcons.wrench,
        title: 'Bugfix e rifiniture',
        body: 'Piccole correzioni grafiche sparse, non tutte elencate qui.',
      ),
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 8,
    date: '29 luglio 2026',
    highlights: [
      NoteItem(
        icon: CupertinoIcons.sparkles,
        title: 'Card con le novità dopo un aggiornamento',
      ),
      NoteItem(
        icon: CupertinoIcons.map,
        title: 'La mappa si sposta sul GPX importato',
      ),
      NoteItem(
        icon: CupertinoIcons.doc_text,
        title: 'Una traccia importata prende il nome del file',
      ),
    ],
    // La build 7 non è mai stata distribuita: chi aggiorna arriva dalla 6, e
    // per lui "l'ultimo aggiornamento" è tutto il salto 6 → 8. Questa lista
    // copre quindi anche le novità della 7 — è l'unica `spotlight` in
    // circolazione, così non ci sono due elenchi che raccontano la stessa cosa.
    spotlight: [
      NoteItem(
        icon: CupertinoIcons.photo_on_rectangle,
        title: 'Foto raggruppate per escursione',
        body: 'Le foto di una traccia sono divise per uscita, con '
            'visualizzatore a schermo intero e profilo altimetrico.',
      ),
      NoteItem(
        icon: CupertinoIcons.search,
        title: '"Trova foto" cerca in tutta la libreria',
        body: 'Prima si fermava agli scatti più recenti: su una libreria '
            'grande non trovava nulla.',
      ),
      NoteItem(
        icon: CupertinoIcons.arrow_down_doc,
        title: 'Import GPX più affidabile',
        body: 'Il file .gpx è selezionabile nella schermata File, la mappa si '
            'sposta sulla traccia e il nome è quello del file.',
      ),
      NoteItem(
        icon: CupertinoIcons.wand_stars,
        title: 'Interfaccia più coerente',
        body: 'Le card si chiudono trascinandole verso il basso e tutte le '
            'conferme hanno la stessa forma.',
      ),
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 7,
    date: '29 luglio 2026',
    highlights: [
      NoteItem(
        icon: CupertinoIcons.search,
        title: '"Trova foto vicine" cerca in tutta la libreria',
        body: 'Prima si fermava alle 3000 più recenti.',
      ),
      NoteItem(
        icon: CupertinoIcons.photo_on_rectangle,
        title: 'Foto raggruppate per escursione',
        body: 'Con visualizzatore a schermo intero e profilo altimetrico.',
      ),
      NoteItem(
        icon: CupertinoIcons.hand_draw,
        title: 'Card che si chiudono trascinandole in basso',
      ),
      NoteItem(
        icon: CupertinoIcons.arrow_down_doc,
        title: 'Corretto l\'import GPX su iPhone',
        body: 'Nella schermata File il tracciato non era selezionabile.',
      ),
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 6,
    date: '28 luglio 2026',
    highlights: [
      NoteItem(
        icon: CupertinoIcons.paintbrush,
        title: 'Redesign grafico di card e pannelli',
        body: 'Sfondo pieno, bottoni e badge coerenti in tutta l\'app.',
      ),
      NoteItem(
        icon: CupertinoIcons.rectangle_stack,
        title: 'Pannelli tutti ancorati al bordo inferiore',
      ),
      NoteItem(
        icon: CupertinoIcons.photo_on_rectangle,
        title: 'Foto: card di dettaglio unificata',
        body: 'Thumbnail evidenziate anche sul profilo altimetrico.',
      ),
      NoteItem(
        icon: CupertinoIcons.moon_stars,
        title: 'Tema chiaro/scuro coerente fin dall\'apertura',
      ),
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 5,
    date: '24 luglio 2026',
    highlights: [
      NoteItem(
        icon: CupertinoIcons.moon_stars,
        title: 'Modalità scura in 3 varianti',
        body: 'Standard, Notturno e Risparmio energetico.',
      ),
      NoteItem(
        icon: CupertinoIcons.pencil,
        title: 'Editing avanzato dei tracciati',
        body: 'Punti intermedi, undo, ri-instradamento.',
      ),
      NoteItem(
        icon: CupertinoIcons.arrow_down_doc,
        title: 'Import GPX migliorato e legenda estesa',
      ),
      NoteItem(
        icon: CupertinoIcons.list_bullet,
        title: 'Novità in-app: questo changelog',
      ),
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 4,
    date: '5 luglio 2026',
    highlights: [
      NoteItem(
        icon: CupertinoIcons.checkmark_seal,
        title: 'Menu e conferme in stile iOS',
        body: 'Conferma prima di eliminare una traccia.',
      ),
      NoteItem(
        icon: CupertinoIcons.sort_down,
        title: 'Ordinamento tracciati salvato',
        body: 'Alfabetico, data, dislivello, quota.',
      ),
      NoteItem(
        icon: CupertinoIcons.cloud,
        title: 'Cloud per piattaforma',
        body: 'iCloud su iOS, Google Drive su Android.',
      ),
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 3,
    date: '2 luglio 2026',
    highlights: [
      NoteItem(
        icon: CupertinoIcons.book,
        title: 'Legenda difficoltà CAI e tooltip sul grafico',
      ),
      NoteItem(
        icon: CupertinoIcons.map_pin_ellipse,
        title: 'Info punto: quota, coordinate e località',
      ),
      NoteItem(
        icon: CupertinoIcons.layers_alt,
        title: 'Vista satellite e ricerca in stile vetro',
      ),
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 2,
    date: '25 giugno 2026',
    highlights: [
      NoteItem(
        icon: CupertinoIcons.search,
        title: 'Ricerca di località e rifugi alpini',
      ),
      NoteItem(
        icon: CupertinoIcons.signature,
        title: 'Segnavia CAI ufficiali e grado di difficoltà',
      ),
      NoteItem(
        icon: CupertinoIcons.wand_stars,
        title: 'Interfaccia in stile "vetro smerigliato"',
      ),
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 1,
    date: '16 giugno 2026',
    highlights: [
      NoteItem(
        icon: CupertinoIcons.map,
        title: 'Prima beta: mappa 3D e disegno tracciati',
        body: 'Con snap-to-trail sui sentieri reali.',
      ),
      NoteItem(
        icon: CupertinoIcons.graph_square,
        title: 'Distanza, dislivello e profilo altimetrico',
      ),
      NoteItem(
        icon: CupertinoIcons.arrow_down_doc,
        title: 'Salvataggio locale, GPX e mappe offline',
      ),
      NoteItem(
        icon: CupertinoIcons.cloud,
        title: 'Sync su Google Drive e iCloud Drive',
      ),
    ],
  ),
];

/// Un gruppo della tab "Roadmap": un'etichetta di stato e le voci che ci
/// stanno dentro. L'ordine dei gruppi **è** l'ordine di priorità.
class RoadmapGroup {
  const RoadmapGroup({required this.label, required this.items});

  /// Etichetta breve mostrata in maiuscoletto (es. "In lavorazione").
  final String label;

  final List<NoteItem> items;
}

/// Prossime priorità di sviluppo (tab "Roadmap"), in linguaggio semplice
/// (niente nomi di file/provider) — versione completa, con dettagli e ordine
/// di priorità, in `docs/ROADMAP.md` (sezioni P1 e P2).
///
/// **Tenere allineata**: quando cambiano le priorità in cima alla roadmap,
/// riportare qui a mano le voci più rilevanti per chi usa l'app, nella stessa
/// sessione di lavoro in cui si tocca `docs/ROADMAP.md` (stessa convenzione di
/// [kReleaseNotes], vedi anche `CLAUDE.md` §9). "Prossime" = le 2-3 priorità in
/// cima (P1); "Più avanti" = fino a 8 voci. È un'anteprima, non il documento
/// completo.
const List<RoadmapGroup> kRoadmapGroups = [
  RoadmapGroup(
    label: 'Prossime',
    items: [
      NoteItem(
        icon: CupertinoIcons.location,
        title: 'Quota e coordinate sempre in vista',
        body: 'La quota e il punto in cui ti trovi, letti di continuo dal '
            'GPS senza dover toccare la mappa.',
      ),
      NoteItem(
        icon: CupertinoIcons.scribble,
        title: 'Difficoltà del sentiero visibile sulla linea',
        body: 'Tratto pieno o tratteggiato secondo il grado CAI (T, E, EE, '
            'EEA), come su una cartina di montagna.',
      ),
      NoteItem(
        icon: CupertinoIcons.clock,
        title: 'Tempo di percorrenza anche per un tratto',
        body: 'Non solo l\'intera traccia: la stima da qui a un punto, tra '
            'due punti, o da un punto alla fine.',
      ),
    ],
  ),
  RoadmapGroup(
    label: 'Più avanti',
    items: [
      NoteItem(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'Segnavia: ricerca più affidabile',
        body: 'A volte non trova un percorso o una scheda CAI Varallo che '
            'esiste davvero — al lavoro per renderlo più costante.',
      ),
      NoteItem(
        icon: CupertinoIcons.zoom_in,
        title: 'Immagine del percorso: zoom e angolazione',
        body: 'Poterli scegliere prima di generare l\'immagine da '
            'condividere.',
      ),
      NoteItem(
        icon: CupertinoIcons.photo_on_rectangle,
        title: 'Foto: vista a griglia e importazione dalla card traccia',
        body: 'Selezione multipla e possibilità di scegliere quali foto '
            'mostrare, non solo aggiungerle tutte.',
      ),
      NoteItem(
        icon: CupertinoIcons.xmark_circle,
        title: 'Uscire dalla ricerca più facilmente',
        body: 'Un tocco fuori dal pannello, non solo la freccia a sinistra.',
      ),
      NoteItem(
        icon: CupertinoIcons.map,
        title: 'Sentieri disegnati in modo più chiaro sulla mappa',
        body: 'Linee più leggibili, più vicine allo stile di una cartina '
            'CAI stampata.',
      ),
      NoteItem(
        icon: CupertinoIcons.location_fill,
        title: 'Registrazione della traccia dal vivo',
        body: 'Seguire il percorso col GPS mentre si cammina, non solo '
            'disegnarlo prima o importarlo da un GPX.',
      ),
      NoteItem(
        icon: CupertinoIcons.speedometer,
        title: 'Unità di misura imperiali',
        body: 'Oggi solo metri e chilometri.',
      ),
      NoteItem(
        icon: CupertinoIcons.globe,
        title: 'Sentèi anche in inglese',
      ),
    ],
  ),
];

enum _NotesTab { changelog, roadmap }

/// Mostra Novità e Roadmap in un bottom sheet a due tab (stesso linguaggio
/// visivo di `showDifficultyLegend`/`showAbbreviationsLegend` in `legends.dart`).
Future<void> showReleaseNotes(BuildContext context) {
  // Altezza fissa (min == max) invece di un semplice tetto massimo: senza
  // questo il bottom sheet si restringe al contenuto e lo switch tra tab
  // "Novità" (lunga) e "Roadmap" (corta) faceva cambiare vistosamente
  // l'altezza della card ad ogni tocco del segmented control.
  final sheetHeight = MediaQuery.of(context).size.height * 0.88;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.palette.glassFill,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      minHeight: sheetHeight,
      maxHeight: sheetHeight,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: (_) => const _ReleaseNotesSheet(),
  );
}

class _ReleaseNotesSheet extends StatefulWidget {
  const _ReleaseNotesSheet();

  @override
  State<_ReleaseNotesSheet> createState() => _ReleaseNotesSheetState();
}

class _ReleaseNotesSheetState extends State<_ReleaseNotesSheet> {
  _NotesTab _tab = _NotesTab.changelog;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isChangelog = _tab == _NotesTab.changelog;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sentèi', style: AppText.sheetTitle),
            const SizedBox(height: 6),
            Text(
              isChangelog
                  ? 'Le versioni più recenti.'
                  : 'Le prossime priorità di sviluppo.',
              style: AppText.body.copyWith(color: palette.secondaryLabel),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<_NotesTab>(
                groupValue: _tab,
                children: const {
                  _NotesTab.changelog: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('Novità'),
                  ),
                  _NotesTab.roadmap: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('Roadmap'),
                  ),
                },
                onValueChanged: (v) {
                  if (v != null) setState(() => _tab = v);
                },
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: isChangelog
                      ? [
                          for (var i = 0; i < kReleaseNotes.length; i++)
                            _VersionBlock(
                              note: kReleaseNotes[i],
                              // La prima versione apre la lista: senza linea
                              // sopra, altrimenti sembra staccata dal titolo.
                              showDivider: i > 0,
                            ),
                        ]
                      : [
                          for (final g in kRoadmapGroups) _RoadmapBlock(group: g),
                        ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Riga di una voce di Novità/Roadmap: icona lineare in un quadratino tinto
/// d'accento, titolo in grassetto e — se c'è — una riga di spiegazione.
///
/// Condivisa da entrambe le tab e dalla card di primo avvio
/// (`whats_new.dart`), così le tre superfici non divergono nell'aspetto.
class NoteRow extends StatelessWidget {
  const NoteRow({super.key, required this.item});

  final NoteItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.14),
            borderRadius: AppRadii.rMd,
          ),
          child: Icon(item.icon ?? CupertinoIcons.sparkles,
              size: 18, color: palette.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 2px di padding in alto: allinea la prima riga di testo al
              // centro ottico del quadratino, che è più alto della riga.
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  item.title,
                  style: AppText.body.copyWith(
                    color: palette.label,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
              if (item.body != null) ...[
                const SizedBox(height: 3),
                Text(
                  item.body!,
                  style: AppText.bodyDetail.copyWith(color: palette.secondaryLabel),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Intestazione di gruppo in maiuscoletto (`DESIGN_GUIDELINES.md` §3,
/// "Caption/etichetta sezione"): 13/600 uppercase, spaziatura ampia.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppText.caption.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: context.palette.secondaryLabel,
      ),
    );
  }
}

class _VersionBlock extends StatelessWidget {
  const _VersionBlock({required this.note, required this.showDivider});

  final ReleaseNote note;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDivider) ...[
          Divider(
            height: 32,
            thickness: 0.5,
            color: palette.hairline.withValues(alpha: 0.25),
          ),
        ],
        Row(
          children: [
            // Pillola con la versione: il numero è l'ancora della lista, va
            // trovato a colpo d'occhio scorrendo.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.14),
                borderRadius: AppRadii.rPill,
              ),
              child: Text(
                '${note.version} (${note.build})',
                style: AppText.captionSmall.copyWith(
                    color: palette.accent, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(note.date,
                style:
                    AppText.footnote.copyWith(color: palette.secondaryLabel)),
          ],
        ),
        const SizedBox(height: 14),
        for (final item in note.highlights) ...[
          NoteRow(item: item),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _RoadmapBlock extends StatelessWidget {
  const _RoadmapBlock({required this.group});

  final RoadmapGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupHeader(group.label),
          const SizedBox(height: 12),
          for (final item in group.items) ...[
            NoteRow(item: item),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
