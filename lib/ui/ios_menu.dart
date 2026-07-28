import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;

import 'app_bottom_sheet.dart';
import 'tokens.dart';

/// Menu contestuale / conferma **incollati al bordo inferiore** dello
/// schermo, come ogni altro pannello modale dell'app (`new
/// design/DESIGN_GUIDELINES.md` §7 — coerenza esplicitamente richiesta
/// dall'utente con la sheet "Selezione tema"): righe *icona + testo*
/// separate da divisori sottili, azione distruttiva in rosso. Sostituisce
/// action sheet / alert dialog centrati o ancorati al punto di tocco.

const Color _kDestructive = AppColors.destructive; // systemRed, non theme-aware

/// Una voce del menu.
class IosMenuItem {
  const IosMenuItem({
    required this.label,
    this.icon,
    this.onPressed,
    this.isDestructive = false,
    this.selected = false,
  });

  final String label;

  /// Icona **leading** (a sinistra del testo), stile menu Apple.
  final IconData? icon;

  /// Eseguita **dopo** la chiusura del menu.
  final VoidCallback? onPressed;

  /// Rossa (es. "Elimina").
  final bool isDestructive;

  /// Mostra un ✓ trailing (menu di selezione, es. ordinamento).
  final bool selected;
}

/// Mostra un **menu contestuale** con le voci passate. [title] opzionale
/// (mostrato in testa, stile [AppSheetHeader] senza ×: si chiude scegliendo
/// una voce o toccando il backdrop).
Future<void> showIosMenu({
  required BuildContext context,
  String? title,
  required List<IosMenuItem> items,
}) {
  return _show(context: context, title: title, items: items);
}

/// Mostra una **conferma** (testo esplicativo + azione, di norma rossa) più
/// la voce [cancelLabel]. Tap sul backdrop = annulla.
Future<void> showIosConfirm({
  required BuildContext context,
  String? title,
  required String message,
  required String confirmLabel,
  required VoidCallback onConfirm,
  bool destructive = true,
  String cancelLabel = 'Annulla',
}) {
  return _show(
    context: context,
    header: _ConfirmHeader(title: title, message: message),
    items: [
      IosMenuItem(
        label: confirmLabel,
        isDestructive: destructive,
        onPressed: onConfirm,
      ),
      IosMenuItem(label: cancelLabel),
    ],
  );
}

Future<void> _show({
  required BuildContext context,
  String? title,
  Widget? header,
  required List<IosMenuItem> items,
}) {
  return showAppBottomSheet<void>(
    context: context,
    padding: EdgeInsets.zero,
    builder: (_) => _MenuBody(title: title, header: header, items: items),
  );
}

class _MenuBody extends StatelessWidget {
  const _MenuBody({this.title, this.header, required this.items});

  final String? title;
  final Widget? header;
  final List<IosMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(title!, style: AppText.sheetTitle),
          ),
        if (header != null) ...[header!, const _Sep()],
        for (final item in items) _MenuRow(item: item),
      ],
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Divider(color: context.palette.borderDivider, height: 1),
      );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});

  final IosMenuItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = item.isDestructive ? _kDestructive : palette.label;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      minimumSize: const Size.fromHeight(0),
      borderRadius: BorderRadius.zero,
      onPressed: () {
        Navigator.of(context).pop();
        item.onPressed?.call();
      },
      child: Row(
        children: [
          if (item.icon != null) ...[
            Icon(item.icon, size: 20, color: color),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(item.label,
                style: AppText.menuItem.copyWith(color: color)),
          ),
          if (item.selected)
            Icon(CupertinoIcons.checkmark, size: 18, color: palette.accent),
        ],
      ),
    );
  }
}

class _ConfirmHeader extends StatelessWidget {
  const _ConfirmHeader({this.title, required this.message});

  final String? title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null && title!.isNotEmpty) ...[
            Text(title!, style: AppText.sheetTitle),
            const SizedBox(height: 6),
          ],
          Text(
            message,
            style: AppText.footnote
                .copyWith(height: 1.35, color: palette.secondaryLabel),
          ),
        ],
      ),
    );
  }
}
