import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_bottom_sheet.dart';
import 'app_buttons.dart';
import 'release_notes.dart';
import 'tokens.dart';

/// Card "Novità in Sentèi" mostrata **una sola volta** al primo avvio dopo un
/// aggiornamento, con le novità della sola versione appena installata.
///
/// Non è un'altra lista di contenuti da mantenere: pesca da [kReleaseNotes],
/// la stessa fonte della schermata Impostazioni → Informazioni → Sentèi.

const String _kSeenBuildKey = 'whats_new_seen_build';

/// La release da raccontare all'utente adesso, o `null` se non c'è nulla da
/// mostrare. Registra sempre la build corrente come "vista", così la card non
/// ricompare al riavvio successivo.
///
/// Non mostra nulla su una **prima installazione** (nessuna build precedente
/// registrata): non è un aggiornamento, e un elenco di "novità" a chi apre
/// l'app per la prima volta non dice niente. Nemmeno se la build installata
/// non ha una voce in [kReleaseNotes] — meglio niente che una card vuota.
Future<ReleaseNote?> pendingWhatsNew() async {
  final int current;
  try {
    final info = await PackageInfo.fromPlatform();
    final parsed = int.tryParse(info.buildNumber);
    if (parsed == null) return null;
    current = parsed;
  } catch (_) {
    return null;
  }
  final prefs = await SharedPreferences.getInstance();
  final seen = prefs.getInt(_kSeenBuildKey);
  await prefs.setInt(_kSeenBuildKey, current);
  if (seen == null || seen >= current) return null;
  for (final note in kReleaseNotes) {
    if (note.build == current) return note;
  }
  return null;
}

/// Mostra la card delle novità di [note].
///
/// Bottom sheet e non dialog centrato, come **ogni** pannello modale dell'app
/// (`new design/DESIGN_GUIDELINES.md` §7/§10): il mockup di riferimento era
/// una card centrata, ma quella forma non esiste altrove in Sentèi.
Future<void> showWhatsNew(BuildContext context, ReleaseNote note) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (sheetContext) => _WhatsNewBody(note: note),
  );
}

class _WhatsNewBody extends StatelessWidget {
  const _WhatsNewBody({required this.note});

  final ReleaseNote note;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // `spotlight` quando c'è (le stesse voci raccontate più per esteso),
    // altrimenti gli `highlights` della tab "Novità".
    final items =
        note.spotlight.isNotEmpty ? note.spotlight : note.highlights;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(CupertinoIcons.map,
                size: 32, color: Color(0xFFFFFFFF)),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text('Novità in Sentèi',
              style: AppText.sheetTitle.copyWith(fontSize: 22)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Versione ${note.version} (${note.build})',
              style: AppText.captionSmall.copyWith(
                  color: palette.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Scrollabile: una release con molte voci non deve spingere il
        // "Continua" fuori dallo schermo.
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in items) ...[
                  NoteRow(item: item),
                  const SizedBox(height: 18),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        AppButton(
          label: 'Continua',
          variant: AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

