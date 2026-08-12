import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Novità per versione (Impostazioni → Informazioni → Sentèi, tab "Novità"),
/// in forma **sintetica** — versione completa e dettagliata in `CHANGELOG.md`
/// alla radice del repo. **Tenere le due liste allineate**: quando si
/// aggiorna `CHANGELOG.md` per una nuova versione, aggiungere qui la voce
/// corrispondente nella stessa sessione di lavoro (vedi anche `CLAUDE.md` §9).
///
/// Vedi anche [kUpcomingHighlights] più sotto: stessa idea ma per la tab
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

  /// Punti salienti, 2-4 voci, una riga ciascuna.
  final List<String> highlights;

  /// Versione "raccontata" degli [highlights] — icona, titolo e una frase di
  /// spiegazione — per la card **Novità** che compare al primo avvio dopo un
  /// aggiornamento (`whats_new.dart`). Serve solo alla release più recente:
  /// sulle vecchie si può lasciare vuota, e la card ripiega sugli
  /// [highlights] come sole righe di titolo.
  final List<WhatsNewItem> spotlight;
}

/// Una voce della card Novità: icona + titolo + (opzionale) spiegazione.
class WhatsNewItem {
  const WhatsNewItem({required this.title, this.body, this.icon});

  final String title;
  final String? body;
  final IconData? icon;
}

const List<ReleaseNote> kReleaseNotes = [
  ReleaseNote(
    version: '1.0.0',
    build: 8,
    date: '29 luglio 2026',
    highlights: [
      'Card con le novità al primo avvio dopo un aggiornamento',
      'Importando un GPX la mappa si sposta sulla traccia importata',
      'Una traccia importata prende il nome del file GPX',
    ],
    // La build 7 non è mai stata distribuita: chi aggiorna arriva dalla 6, e
    // per lui "l'ultimo aggiornamento" è tutto il salto 6 → 8. Questa lista
    // copre quindi anche le novità della 7 — è l'unica `spotlight` in
    // circolazione, così non ci sono due elenchi che raccontano la stessa cosa.
    spotlight: [
      WhatsNewItem(
        icon: CupertinoIcons.photo_on_rectangle,
        title: 'Foto raggruppate per escursione',
        body: 'Le foto di una traccia sono divise per uscita, con '
            'visualizzatore a schermo intero e profilo altimetrico.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.search,
        title: '"Trova foto" cerca in tutta la libreria',
        body: 'Prima si fermava agli scatti più recenti: su una libreria '
            'grande non trovava nulla.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.arrow_down_doc,
        title: 'Import GPX più affidabile',
        body: 'Il file .gpx è selezionabile nella schermata File, la mappa si '
            'sposta sulla traccia e il nome è quello del file.',
      ),
      WhatsNewItem(
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
      '"Trova foto vicine" cerca in tutta la libreria: prima si fermava alle 3000 più recenti',
      'Foto raggruppate per escursione, con visualizzatore a schermo intero e profilo altimetrico',
      'Card di traccia e foto: si chiudono trascinandole verso il basso, conferme tutte uguali',
      'Corretto l\'import GPX su iPhone: il file non era selezionabile',
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 6,
    date: '28 luglio 2026',
    highlights: [
      'Redesign grafico: card e pannelli con sfondo pieno, bottoni e badge coerenti',
      'Tutti i pannelli a comparsa ora incollati al bordo inferiore, come la selezione tema',
      'Foto lungo il percorso: card di dettaglio unificata, thumbnail evidenziate sul grafico',
      'Tema chiaro/scuro coerente fin dall\'apertura dell\'app',
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 5,
    date: '24 luglio 2026',
    highlights: [
      'Modalità scura: Standard, Notturno e Risparmio energetico',
      'Editing avanzato dei tracciati (punti intermedi, undo, ri-instradamento)',
      'Import GPX migliorato + legenda difficoltà estesa',
      'Novità in-app: questo changelog, ora con anche la roadmap',
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 4,
    date: '5 luglio 2026',
    highlights: [
      'Menu e conferme in stile iOS (conferma prima di eliminare una traccia)',
      'Ordinamento tracciati salvato: alfabetico, data, dislivello, quota',
      'Cloud per piattaforma: iCloud su iOS, Google Drive su Android',
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 3,
    date: '2 luglio 2026',
    highlights: [
      'Legenda difficoltà CAI + tooltip nel grafico del profilo',
      'Info punto: quota, coordinate e località al tocco sulla mappa',
      'Vista satellite e ricerca in stile vetro',
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 2,
    date: '25 giugno 2026',
    highlights: [
      'Ricerca di località e rifugi alpini',
      'Segnavia CAI ufficiali (OSM2CAI) e grado di difficoltà in card',
      'Interfaccia in stile "vetro smerigliato" iOS',
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    build: 1,
    date: '16 giugno 2026',
    highlights: [
      'Prima beta: mappa 3D, disegno tracciati con snap-to-trail',
      'Distanza, dislivello e profilo altimetrico',
      'Salvataggio locale, export/import GPX, mappe offline',
      'Sync su Google Drive e iCloud Drive',
    ],
  ),
];

/// Prossime priorità di sviluppo (tab "Roadmap"), in forma sintetica e in
/// linguaggio semplice (niente nomi di file/provider) — versione completa,
/// con dettagli e ordine di priorità, in `docs/ROADMAP.md` (sezione P1).
/// **Tenere allineata**: quando cambiano le priorità in cima alla roadmap,
/// riportare qui a mano le 3-6 voci più rilevanti per chi usa l'app, nella
/// stessa sessione di lavoro in cui si tocca `docs/ROADMAP.md` (stessa
/// convenzione di [kReleaseNotes], vedi anche `CLAUDE.md` §9).
const List<String> kUpcomingHighlights = [
  'Foto più leggere: si aprono subito e si scorrono senza scatti',
  'Tempo di percorrenza stimato, calcolato con il metodo del CAI',
  'Tocca un segnavia per vederlo intero: da dove parte, dove arriva, la scheda ufficiale',
  'Tasto per eliminare una traccia direttamente dalla sua scheda',
  'Foto lungo il percorso: vista a griglia, importazione dalla card, zoom sul punto di scatto',
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
                  : 'Le prossime priorità di sviluppo — l\'ordine può cambiare.',
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
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: isChangelog
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final n in kReleaseNotes) _VersionBlock(note: n),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _bulletRows(kUpcomingHighlights, palette),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Righe puntate condivise da changelog e roadmap (stesso stile).
List<Widget> _bulletRows(List<String> items, AppPalette palette) => [
      for (final h in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: AppText.body.copyWith(color: palette.secondaryLabel)),
              Expanded(
                child: Text(h,
                    style: AppText.body.copyWith(color: palette.bodyText, height: 1.3)),
              ),
            ],
          ),
        ),
    ];

class _VersionBlock extends StatelessWidget {
  const _VersionBlock({required this.note});
  final ReleaseNote note;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${note.version} (${note.build})',
                  style: AppText.value.copyWith(color: palette.accent)),
              const SizedBox(width: 8),
              Text(note.date,
                  style: AppText.footnote.copyWith(color: palette.secondaryLabel)),
            ],
          ),
          const SizedBox(height: 6),
          ..._bulletRows(note.highlights, palette),
        ],
      ),
    );
  }
}
