import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/app_bottom_sheet.dart';
import '../../../ui/tokens.dart';
import '../route_editor_provider.dart';
import 'export_gpx.dart';
import 'export_image_screen.dart';

/// Foglio "Esporta": due scelte omogenee (icona + titolo + sottotitolo +
/// chevron, come le righe di Impostazioni) — GPX (esistente, condivisione
/// diretta) o Immagine (nuova schermata di anteprima, §export immagine).
Future<void> showExportSheet(BuildContext context, DrawnTrack track) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (sheetContext) => _ExportSheet(track: track),
  );
}

class _ExportSheet extends StatelessWidget {
  const _ExportSheet({required this.track});

  final DrawnTrack track;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSheetHeader(
          title: 'Esporta',
          onClose: () => Navigator.of(context).pop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(
            track.name.isNotEmpty ? track.name : 'Senza nome',
            style: AppText.footnote.copyWith(color: palette.secondaryLabel),
          ),
        ),
        const SizedBox(height: 6),
        _ExportOptionRow(
          icon: CupertinoIcons.doc_text,
          title: 'Traccia GPX',
          subtitle: 'File da aprire in altre app',
          onTap: () {
            Navigator.of(context).pop();
            exportTrackGpx(context, track);
          },
        ),
        _ExportOptionRow(
          icon: CupertinoIcons.photo,
          title: 'Immagine',
          subtitle: 'Mappa 3D con dati e punti scelti',
          onTap: () {
            Navigator.of(context).pop();
            context.pushNamed(ExportImageScreen.routeName,
                pathParameters: {'trackId': track.id});
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ExportOptionRow extends StatelessWidget {
  const _ExportOptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      minimumSize: const Size.fromHeight(0),
      borderRadius: BorderRadius.zero,
      onPressed: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 19, color: palette.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.value.copyWith(color: palette.label)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppText.footnote
                        .copyWith(color: palette.secondaryLabel)),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_right,
              size: 16, color: palette.tertiaryIcon),
        ],
      ),
    );
  }
}
