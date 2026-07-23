import 'package:flutter/cupertino.dart';

import 'tokens.dart';

/// `CupertinoListSection.insetGrouped` theme-aware: la versione stock dipende
/// solo da `Brightness` (colori di sistema iOS fissi), quindi in Notturno lo
/// sfondo pagina, le card e i divisori restano grigio/nero **freddi** anche
/// se testo/icone diventano ambra. Qui sfondo, decorazione e divisori vengono
/// dalla [AppPalette] corrente, coerenti col resto dell'app.
///
/// **Limite noto:** il *subtitle* di `CupertinoListTile` ha il colore
/// (`CupertinoColors.secondaryLabel`) **cablato nel framework Flutter**, senza
/// hook per sovrascriverlo — resta grigio di sistema anche qui.
class AppListSection extends StatelessWidget {
  const AppListSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CupertinoListSection.insetGrouped(
      header: header == null
          ? null
          : Text(header!, style: TextStyle(color: palette.label)),
      footer: footer == null
          ? null
          : Text(footer!, style: TextStyle(color: palette.secondaryLabel)),
      backgroundColor: const Color(0x00000000),
      decoration: BoxDecoration(
        color: palette.glassFill,
        borderRadius: BorderRadius.circular(10),
      ),
      separatorColor: palette.hairline.withValues(alpha: 0.5),
      children: children,
    );
  }
}
