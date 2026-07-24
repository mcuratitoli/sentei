import 'package:flutter/material.dart';

import 'tokens.dart';

/// Novità per versione (Impostazioni → Informazioni → Sentèi), in forma
/// **sintetica** — versione completa e dettagliata in `CHANGELOG.md` alla
/// radice del repo. Tenere le due liste allineate quando si rilascia una
/// nuova versione: aggiungere qui la voce più recente in cima.
///
/// Vedi anche [kUpcomingHighlights] più sotto: stessa idea ma per le
/// prossime priorità, non ancora rilasciate.
class ReleaseNote {
  const ReleaseNote({
    required this.version,
    required this.build,
    required this.date,
    required this.highlights,
  });

  final String version;
  final int build;

  /// Data testuale breve (es. "5 luglio 2026").
  final String date;

  /// Punti salienti, 2-4 voci, una riga ciascuna.
  final List<String> highlights;
}

const List<ReleaseNote> kReleaseNotes = [
  ReleaseNote(
    version: '1.0.0',
    build: 5,
    date: '24 luglio 2026',
    highlights: [
      'Modalità scura: Standard, Notturno e Risparmio energetico',
      'Editing avanzato dei tracciati (punti intermedi, undo, ri-instradamento)',
      'Import GPX migliorato + legenda difficoltà estesa',
      'Novità in-app: questo changelog',
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

/// Prossime priorità di sviluppo, in forma sintetica e in linguaggio semplice
/// (niente nomi di file/provider) — versione completa, con dettagli e ordine
/// di priorità, in `docs/ROADMAP.md` (sezione P1). Va aggiornata a mano
/// quando cambiano le priorità in cima alla roadmap, stessa convenzione di
/// [kReleaseNotes]. 3-6 voci: se la lista si allunga troppo, tenere solo le
/// più rilevanti per chi usa l'app.
const List<String> kUpcomingHighlights = [
  'Tema chiaro/scuro sempre coerente con quello scelto, fin dall\'apertura',
  'Tasto per eliminare una traccia direttamente dalla sua scheda',
  'Traccia selezionata più in evidenza, le altre più trasparenti',
  'Foto lungo il percorso: galleria, titoli e dettagli per ogni scatto',
  'Modifica dei punti di un tracciato più semplice e intuitiva',
];

/// Mostra le novità per versione in un bottom sheet (stesso linguaggio
/// visivo di `showDifficultyLegend`/`showAbbreviationsLegend` in `legends.dart`).
Future<void> showReleaseNotes(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.palette.glassFill,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.88,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: (_) => const _ReleaseNotesSheet(),
  );
}

class _ReleaseNotesSheet extends StatelessWidget {
  const _ReleaseNotesSheet();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Novità', style: AppText.sheetTitle),
            const SizedBox(height: 6),
            Text(
              'Le versioni più recenti di Sentèi.',
              style: AppText.body.copyWith(color: palette.secondaryLabel),
            ),
            const SizedBox(height: 16),
            for (final n in kReleaseNotes) _VersionBlock(note: n),
            if (kUpcomingHighlights.isNotEmpty) const _UpcomingSection(),
          ],
        ),
      ),
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: palette.hairline),
          const SizedBox(height: 16),
          Text('In arrivo',
              style: AppText.sectionValue.copyWith(color: palette.bodyText)),
          const SizedBox(height: 6),
          Text(
            'Le prossime priorità di sviluppo — l\'ordine può cambiare.',
            style: AppText.body.copyWith(color: palette.secondaryLabel),
          ),
          const SizedBox(height: 10),
          for (final h in kUpcomingHighlights)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ',
                      style: AppText.body.copyWith(color: palette.secondaryLabel)),
                  Expanded(
                    child: Text(h,
                        style: AppText.body
                            .copyWith(color: palette.bodyText, height: 1.3)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

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
          for (final h in note.highlights)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ',
                      style: AppText.body.copyWith(color: palette.secondaryLabel)),
                  Expanded(
                    child: Text(h,
                        style: AppText.body
                            .copyWith(color: palette.bodyText, height: 1.3)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
