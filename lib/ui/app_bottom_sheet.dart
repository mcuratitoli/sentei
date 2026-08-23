import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

import 'app_buttons.dart';
import 'tokens.dart';

/// Struttura **unica** di pannello modale (`new design/DESIGN_GUIDELINES.md`
/// §7): handle → header (titolo + chiusura ×) → contenuto, angoli superiori
/// arrotondati, sfondo opaco (non più "vetro" — vedi la nota in cima al file
/// dei token). Usata sia per veri bottom sheet modali ([showAppBottomSheet])
/// sia per pannelli persistenti non-modali (card traccia in `draw_route/`),
/// che condividono lo stesso `AppSheetSurface`/`AppSheetHeader` ma restano
/// dentro l'albero della mappa invece che in una route separata.
class AppSheetSurface extends StatefulWidget {
  const AppSheetSurface({
    super.key,
    required this.child,
    this.showHandle = true,
    this.floating = false,
    this.onDismiss,
  });

  final Widget child;
  final bool showHandle;

  /// `true` per le card **non** attaccate al bordo inferiore dello schermo
  /// (card traccia/foto, che restano fluttuanti sopra la mappa con un
  /// margine sotto): arrotonda tutti e 4 gli angoli, non solo quelli sopra.
  /// Le vere bottom sheet modali ([showAppBottomSheet]), a filo del bordo
  /// inferiore, restano con l'angolo sotto squadrato (default `false`).
  final bool floating;

  /// Chiusura **trascinando l'handle verso il basso**, per i pannelli
  /// persistenti (card traccia/foto) che non hanno la × in alto a destra:
  /// non essendo route modali, il dismiss della bottom sheet di sistema non
  /// li tocca e serve gestirlo qui.
  ///
  /// La presa è il **solo handle**, non tutta la superficie: la card traccia
  /// contiene il grafico del profilo (che intercetta il trascinamento per
  /// muovere il cursore) e un carosello di foto, e un drag globale se li
  /// mangerebbe. L'handle è comunque l'affordance standard iOS.
  final VoidCallback? onDismiss;

  @override
  State<AppSheetSurface> createState() => _AppSheetSurfaceState();
}

class _AppSheetSurfaceState extends State<AppSheetSurface> {
  // Offset del trascinamento in corso: la card segue il dito (solo verso il
  // basso) così il gesto ha un riscontro visivo invece di "scattare" alla
  // fine.
  double _dragDy = 0;
  static const double _dismissDistance = 48;
  static const double _dismissVelocity = 400;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = widget.floating
        ? const BorderRadius.all(Radius.circular(AppRadii.sheet))
        : const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet));

    Widget handle = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: palette.borderDivider,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
    final onDismiss = widget.onDismiss;
    if (onDismiss != null) {
      handle = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) =>
            setState(() => _dragDy = (_dragDy + d.delta.dy).clamp(0, 400)),
        onVerticalDragEnd: (d) {
          final fling = (d.primaryVelocity ?? 0) > _dismissVelocity;
          if (_dragDy > _dismissDistance || fling) {
            setState(() => _dragDy = 0);
            onDismiss();
          } else {
            setState(() => _dragDy = 0);
          }
        },
        // A tutta larghezza: la barretta è di 36px ma la presa deve essere
        // comoda su tutta la testata della card.
        child: SizedBox(width: double.infinity, child: handle),
      );
    }

    return Transform.translate(
      offset: Offset(0, _dragDy),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.glassFill,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.14),
              blurRadius: 16,
              // Sheet a filo del bordo inferiore: ombra verso l'alto (l'unico
              // lato visibile). Card fluttuante: ombra centrata, visibile su
              // tutti i lati.
              offset: Offset(0, widget.floating ? 2 : -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showHandle) handle,
            widget.child,
          ],
        ),
      ),
    );
  }
}

/// Header standard di una sheet: titolo a sinistra, chiusura × a destra
/// (cerchio 36px, sfondo neutro), chevron opzionale prima della × (pannello
/// "dettaglio tracciato": espandi/riduci).
class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    super.key,
    required this.title,
    this.onClose,
    this.collapseIcon,
    this.onCollapseToggle,
    this.collapseTooltip,
    this.trailing,
  });

  final String title;
  final VoidCallback? onClose;

  /// Icona del chevron espandi/riduci (es. `CupertinoIcons.chevron_down`),
  /// mostrata solo se sia questa che [onCollapseToggle] sono non-null.
  final IconData? collapseIcon;
  final VoidCallback? onCollapseToggle;
  final String? collapseTooltip;

  /// Widget aggiuntivo dopo il titolo, prima del chevron/×  (es. la quota nel
  /// punto selezionato) — evita di dover reinventare l'header per ogni caso.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) trailing!,
        if (collapseIcon != null && onCollapseToggle != null) ...[
          const SizedBox(width: 8),
          AppIconButton(
            icon: collapseIcon!,
            tooltip: collapseTooltip,
            onPressed: onCollapseToggle,
            size: 36,
          ),
        ],
        if (onClose != null) ...[
          const SizedBox(width: 8),
          AppIconButton(
            icon: CupertinoIcons.xmark,
            tooltip: 'Chiudi',
            onPressed: onClose,
            size: 36,
          ),
        ],
      ],
    );
  }
}

/// Apre una bottom sheet con la struttura standard (§7): sfondo di backdrop
/// nero ~45%, angoli superiori arrotondati, contenuto scrollabile se serve.
/// Sostituisce `showCupertinoModalPopup`/`showGeneralDialog` usati in passato
/// per lo stesso scopo — un solo meccanismo per tutti i pannelli modali.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  // `false` solo per i pochi fogli che l'utente **deve** chiudere con
  // un'azione esplicita (es. "Novità in Sentèi": un tocco fuori o uno swipe
  // verso il basso non devono bastare a farla sparire senza che l'utente
  // l'abbia letta).
  bool enableDrag = true,
  // Righe azione full-bleed (menu/conferme, `ios_menu.dart`) passano
  // `EdgeInsets.zero` e gestiscono da sé il padding orizzontale di titolo/
  // messaggio, per poter disegnare divisori a tutta larghezza.
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 0, 20, 14),
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    barrierColor: const Color(0x73000000), // ~45% nero
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: (sheetContext) => AppSheetSurface(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: builder(sheetContext),
        ),
      ),
    ),
  );
}
