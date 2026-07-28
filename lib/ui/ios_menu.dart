import 'package:flutter/cupertino.dart';

import 'app_bottom_sheet.dart';
import 'app_buttons.dart';
import 'tokens.dart';

/// Menu contestuale e conferme **incollati al bordo inferiore** dello
/// schermo, come ogni altro pannello modale dell'app (`new
/// design/DESIGN_GUIDELINES.md` §7 — coerenza esplicitamente richiesta
/// dall'utente con la sheet "Selezione tema"). Sostituisce action sheet /
/// alert dialog centrati o ancorati al punto di tocco.
///
/// Due forme distinte, da non confondere:
/// - [showIosMenu] — righe *icona + testo* omogenee, una per scelta;
/// - [showIosConfirm] — testo + **riga di bottoni** annulla/conferma, stesso
///   impaginato della sheet "Modifica titolo".

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

/// Mostra una **conferma**: stessa struttura della sheet "Modifica titolo"
/// (§7) — header con titolo + ×, testo esplicativo, e in fondo **una riga**
/// di due bottoni del sistema unico (§4): [cancelLabel] terziario a sinistra,
/// azione di conferma **piena** a destra, espansa fino al bordo. Non due
/// righe impilate in stile menu: quelle restano per [showIosMenu], dove le
/// voci sono *scelte* omogenee e non una coppia conferma/annulla.
///
/// La conferma distruttiva è piena **rossa** (non bordata): la coerenza di
/// impaginato con "Modifica titolo" — dove l'azione confermante è il pieno
/// blu "Salva" — è stata scelta esplicitamente dall'utente sopra la regola
/// "niente bottoni pieni rossi" di §4, che resta valida altrove.
///
/// Tap sul backdrop o sulla × = annulla. [onConfirm] è eseguita **dopo** la
/// chiusura della sheet.
Future<void> showIosConfirm({
  required BuildContext context,
  String? title,
  required String message,
  required String confirmLabel,
  required VoidCallback onConfirm,
  bool destructive = true,
  String cancelLabel = 'Annulla',
}) async {
  final confirmed = await showAppBottomSheet<bool>(
    context: context,
    builder: (sheetContext) {
      final palette = sheetContext.palette;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSheetHeader(
            title: title ?? '',
            onClose: () => Navigator.of(sheetContext).pop(false),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppText.footnote
                .copyWith(height: 1.35, color: palette.secondaryLabel),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // `Flexible` e non larghezza intrinseca secca: alcune conferme
              // hanno etichette lunghe ("Continua a modificare") che
              // schiaccerebbero l'azione principale.
              Flexible(
                child: AppButton(
                  label: cancelLabel,
                  variant: AppButtonVariant.tertiary,
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: confirmLabel,
                  variant: AppButtonVariant.primary,
                  color: destructive ? _kDestructive : null,
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  if (confirmed == true) onConfirm();
}

Future<void> _show({
  required BuildContext context,
  String? title,
  required List<IosMenuItem> items,
}) {
  return showAppBottomSheet<void>(
    context: context,
    padding: EdgeInsets.zero,
    builder: (_) => _MenuBody(title: title, items: items),
  );
}

class _MenuBody extends StatelessWidget {
  const _MenuBody({this.title, required this.items});

  final String? title;
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
        for (final item in items) _MenuRow(item: item),
      ],
    );
  }
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
