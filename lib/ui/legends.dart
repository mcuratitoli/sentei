import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cai_difficulty.dart';
import 'tokens.dart';

/// Legende di riferimento (Impostazioni → Informazioni): **difficoltà** dei
/// percorsi e **abbreviazioni**. Contenuti tratti dalla «Guida dei Monti
/// d'Italia» (CAI) e dalla guida del Monviso (scala Welzenbach, abbreviazioni).

// Palette di dominio per i gradi non-escursionistici (gli escursionistici
// T/E/EE/EEA usano `caiScaleColor`). Alpinismo = viola; Welzenbach = ardesia.
const Color _alpF = Color(0xFF7E57C2);
const Color _alpPD = Color(0xFF5E35B1);
const Color _welzI = Color(0xFF90A4AE);
const Color _welzII = Color(0xFF607D8B);
const Color _welzIII = Color(0xFF455A64);

/// Voce di difficoltà: sigla, colore, titolo e descrizione.
class _Grade {
  const _Grade(this.sigla, this.color, this.title, this.body);
  final String sigla;
  final Color color;
  final String title;
  final String body;
}

/// Difficoltà **alpinistiche** (oltre l'escursionismo). Fonte: Guida CAI.
const List<_Grade> _alpine = [
  _Grade('F', _alpF, 'Facile',
      'Siamo già nell\'alpinismo: richiede un minimo di dimestichezza con la '
          'roccia, oppure pendii nevosi da superare con piccozza e ramponi.'),
  _Grade('PD', _alpPD, 'Poco difficile',
      'Le difficoltà diventano più continue e rendono consigliabile la '
          'progressione in cordata.'),
];

/// Difficoltà dei singoli passaggi su roccia — **scala Welzenbach**.
const List<_Grade> _welzenbach = [
  _Grade('I', _welzI, 'Primo grado',
      'Brevi passaggi in cui si devono usare le mani per mantenere l\'equilibrio.'),
  _Grade('II', _welzII, 'Secondo grado',
      'Appigli e appoggi assai abbondanti, ma richiedono già una corretta '
          'impostazione dei movimenti.'),
  _Grade('III', _welzIII, 'Terzo grado',
      'Passaggi in genere non obbligati, ma su strutture ripide o addirittura '
          'verticali, con una scelta di appigli e appoggi più limitata.'),
];

/// Abbreviazioni ricorrenti sulle guide e sulle carte dell'arco alpino.
const List<(String, String)> _abbreviations = [
  ('ANA', 'Associazione Nazionale Alpini'),
  ('ASF', 'Alpi Senza Frontiere'),
  ('CAF', 'Club Alpin Français'),
  ('CAI', 'Club Alpino Italiano'),
  ('GTA', 'Grande Traversata delle Alpi · Grande Traversée des Alpes'),
  ('IGM', 'Istituto Geografico Militare (italiano)'),
  ('IGN', 'Institut Géographique National (francese)'),
  ('UGET', 'Unione Giovani Escursionisti Torino'),
];

/// Mostra la legenda dei **gradi di difficoltà** (escursionistici, alpinistici,
/// scala Welzenbach) in un bottom sheet.
Future<void> showDifficultyLegend(BuildContext context) {
  return _showSheet(context, const _DifficultyLegendSheet());
}

/// Mostra la legenda delle **abbreviazioni** in un bottom sheet.
Future<void> showAbbreviationsLegend(BuildContext context) {
  return _showSheet(context, const _AbbreviationsSheet());
}

Future<void> _showSheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.palette.glassFill,
    isScrollControlled: true,
    showDragHandle: true,
    // Cap dell'altezza (~88%): con contenuti lunghi il foglio arrivava a **tutta
    // altezza**, senza più la fascia in alto da toccare per chiudere e col drag
    // handle non afferrabile → restava "incastrato". Lasciando uno scrim sopra,
    // il tap-fuori e il drag-to-dismiss tornano a funzionare (il contenuto
    // scorre dentro il foglio).
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.88,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: (_) => child,
  );
}

class _DifficultyLegendSheet extends StatelessWidget {
  const _DifficultyLegendSheet();

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
            const Text('Difficoltà dei percorsi', style: AppText.sheetTitle),
            const SizedBox(height: 6),
            Text(
              'Sigle convenzionali della «Guida dei Monti d\'Italia» (CAI).',
              style: AppText.body.copyWith(color: palette.secondaryLabel),
            ),
            const SizedBox(height: 16),
            Text(
              'Sulla mappa lo stile della linea del tracciato segue il grado, '
              'come sulle carte escursionistiche: pieno per T, poi trattini, '
              'trattini corti e tratto‑punto.',
              style: AppText.footnote.copyWith(color: palette.secondaryLabel),
            ),
            const SizedBox(height: 14),
            const _SectionLabel('Escursionistiche'),
            for (final s in caiScalesInOrder)
              _GradeRow(
                sigla: s,
                color: caiScaleColor(s),
                title: caiScaleLabel(s),
                body: caiScaleDescription(s),
                lineStyle: true,
              ),
            const SizedBox(height: 8),
            const _SectionLabel('Alpinistiche'),
            for (final g in _alpine)
              _GradeRow(
                  sigla: g.sigla, color: g.color, title: g.title, body: g.body),
            const SizedBox(height: 8),
            const _SectionLabel('Passaggi su roccia · scala Welzenbach'),
            for (final g in _welzenbach)
              _GradeRow(
                  sigla: g.sigla, color: g.color, title: g.title, body: g.body),
            const SizedBox(height: 6),
            Text(
              'Ogni grado può essere suddiviso in inferiore (−) o superiore (+).',
              style: AppText.footnote.copyWith(color: palette.secondaryLabel),
            ),
            const SizedBox(height: 16),
            const _NoteBox(
              'Le valutazioni valgono in condizioni ottimali e con tempo '
              'favorevole. Con maltempo o cattive condizioni del terreno '
              '(roccia bagnata, neve o ghiaccio) le difficoltà possono '
              'aumentare notevolmente.',
            ),
          ],
        ),
      ),
    );
  }
}

class _AbbreviationsSheet extends StatelessWidget {
  const _AbbreviationsSheet();

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
            const Text('Abbreviazioni', style: AppText.sheetTitle),
            const SizedBox(height: 12),
            for (final (sigla, full) in _abbreviations) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        sigla,
                        style: AppText.value.copyWith(color: palette.accent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(full,
                          style: AppText.body
                              .copyWith(color: palette.bodyText, height: 1.3)),
                    ),
                  ],
                ),
              ),
              if (sigla != _abbreviations.last.$1)
                const Divider(height: 1, thickness: 0.5),
            ],
          ],
        ),
      ),
    );
  }
}

/// Intestazione di sezione (es. "Escursionistiche").
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          text.toUpperCase(),
          style: AppText.captionSmall.copyWith(
            color: context.palette.secondaryLabel,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      );
}

/// Riga di un grado: badge colorato con la sigla + titolo + descrizione.
class _GradeRow extends StatelessWidget {
  const _GradeRow({
    required this.sigla,
    required this.color,
    required this.title,
    required this.body,
    this.lineStyle = false,
  });

  final String sigla;
  final Color color;
  final String title;
  final String body;

  /// Se vero mostra un campione della **linea del tracciato** per questo grado
  /// (§P1.B), col tratteggio di [caiScaleDash]. Solo per la scala CAI.
  final bool lineStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, borderRadius: AppRadii.rSm),
            // Le sigle sono corte (T, EE, PD…) tranne le varianti ferrata
            // (`EEA:F`): FittedBox le rimpicciolisce quanto basta senza
            // allargare il badge, così le righe restano allineate.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                sigla,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title,
                          style: AppText.value.copyWith(color: color)),
                    ),
                    if (lineStyle) ...[
                      const SizedBox(width: 10),
                      CustomPaint(
                        size: const Size(52, 12),
                        painter: _LineStylePainter(
                          color: color,
                          dash: caiScaleDash(sigla),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(body,
                    style: AppText.bodyDetail
                        .copyWith(color: context.palette.bodyText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Campione della linea del tracciato: un segmento orizzontale col tratteggio
/// [dash] (unità di larghezza linea, come Mapbox — qui ×2.6 per i px) e cap
/// tondo, così i "punti" di EE si vedono rotondi come in mappa.
class _LineStylePainter extends CustomPainter {
  const _LineStylePainter({required this.color, required this.dash});

  final Color color;
  final List<double>? dash;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      // `butt` come sulla mappa: un cap tondo salderebbe i trattini corti.
      ..strokeCap = StrokeCap.butt;
    final d = dash;
    if (d == null || d.isEmpty) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    const scale = 2.6;
    var x = 0.0;
    var on = true;
    var i = 0;
    while (x < size.width) {
      final len = d[i % d.length] * scale;
      if (on && len > 0) {
        canvas.drawLine(
            Offset(x, y), Offset((x + len).clamp(0, size.width), y), paint);
      }
      x += len;
      on = !on;
      i++;
    }
  }

  @override
  bool shouldRepaint(_LineStylePainter old) =>
      old.color != color || old.dash != dash;
}

/// Riquadro-nota (condizioni). Sfondo tenue, testo secondario.
class _NoteBox extends StatelessWidget {
  const _NoteBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.scaffoldBg,
        borderRadius: AppRadii.rMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cupertino, non Material (era `Icons.info_outline`).
          Icon(CupertinoIcons.info, size: 18, color: palette.secondaryLabel),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.footnote
                  .copyWith(color: palette.secondaryLabel, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mostra fonte dati e attribuzione della mappa (Impostazioni → Mappa) in un
/// bottom sheet. **Non sostituisce** l'icona "i" nativa Mapbox sulla mappa
/// stessa — i termini d'uso Mapbox impongono di mostrarla lì e non è
/// rimovibile (vedi `map_gl_screen.dart` → `_configureOrnaments`): è solo un
/// accesso aggiuntivo, più comodo, alle stesse informazioni.
Future<void> showMapInfo(BuildContext context) {
  return _showSheet(context, const _MapInfoSheet());
}

class _MapInfoSheet extends StatelessWidget {
  const _MapInfoSheet();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Mappa', style: AppText.sheetTitle),
            const SizedBox(height: 6),
            Text(
              'Mapbox Outdoors, con terreno 3D e sentieri CAI · OSM2CAI · '
              'Overpass.',
              style: AppText.body.copyWith(color: palette.secondaryLabel),
            ),
            const SizedBox(height: 16),
            const _SectionLabel('Attribuzione'),
            Text(
              'Mappe © Mapbox, © OpenStreetMap e contributori.',
              style: AppText.body.copyWith(color: palette.bodyText),
            ),
            const SizedBox(height: 10),
            const _MapInfoLink(
              label: 'Mapbox',
              url: 'https://www.mapbox.com/about/maps/',
            ),
            const _MapInfoLink(
              label: 'OpenStreetMap',
              url: 'https://www.openstreetmap.org/copyright',
            ),
          ],
        ),
      ),
    );
  }
}

class _MapInfoLink extends StatelessWidget {
  const _MapInfoLink({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppText.body.copyWith(color: accent)),
            const SizedBox(width: 4),
            Icon(CupertinoIcons.arrow_up_right_square, size: 14, color: accent),
          ],
        ),
      ),
    );
  }
}
