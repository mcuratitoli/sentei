import 'dart:ui';

import 'package:flutter/cupertino.dart';

/// Menu contestuale / conferma in stile **iOS** (à la Apple Photos): un unico
/// riquadro in vetro con righe *icona + testo* separate da divisori sottili, con
/// l'azione distruttiva in rosso. Sostituisce action sheet / alert dialog.

const double _kMenuWidth = 250;
const double _kConfirmMaxWidth = 270;
const double _kRadius = 14;
const Color _kFill = Color(0xF5FFFFFF); // chiaro, quasi opaco (app solo light)
const Color _kSeparator = Color(0x243C3C43); // separatore iOS chiaro
const Color _kLabel = Color(0xFF1C1C1E);
const Color _kSecondary = Color(0x99000000);
const Color _kDestructive = Color(0xFFFF3B30); // systemRed

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

/// Mostra un **menu contestuale** ancorato al widget [anchorContext] (di solito
/// il `context` del bottone che lo apre). Le voci sono righe icona+testo.
Future<void> showIosMenu({
  required BuildContext context,
  required BuildContext anchorContext,
  required List<IosMenuItem> items,
}) {
  return _show(context: context, anchorContext: anchorContext, items: items);
}

/// Mostra una **conferma** centrata (testo esplicativo + azione, di norma rossa),
/// stile Apple Photos. Tap fuori = annulla.
Future<void> showIosConfirm({
  required BuildContext context,
  String? title,
  required String message,
  required String confirmLabel,
  required VoidCallback onConfirm,
  bool destructive = true,
  String cancelLabel = 'Annulla',
}) {
  final header = _ConfirmHeader(title: title, message: message);
  return _show(
    context: context,
    anchorContext: null,
    header: header,
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
  required BuildContext? anchorContext,
  Widget? header,
  required List<IosMenuItem> items,
}) {
  Rect? anchor;
  final overlay =
      Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
  final box = anchorContext?.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize && overlay != null) {
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    anchor = topLeft & box.size;
  }
  final centered = anchor == null;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'menu',
    barrierColor: const Color(0x14000000),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (_, __, ___) =>
        _MenuLayer(anchor: anchor, header: header, items: items),
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: centered ? 0.96 : 0.9, end: 1)
              .animate(curved),
          alignment: centered ? Alignment.center : Alignment.topRight,
          child: child,
        ),
      );
    },
  );
}

class _MenuLayer extends StatelessWidget {
  const _MenuLayer({
    required this.anchor,
    required this.header,
    required this.items,
  });

  final Rect? anchor;
  final Widget? header;
  final List<IosMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final centered = anchor == null;
    final card = _MenuCard(header: header, items: items, centered: centered);
    if (centered) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kConfirmMaxWidth),
          child: card,
        ),
      );
    }
    final size = MediaQuery.of(context).size;
    final a = anchor!;
    final left =
        (a.right - _kMenuWidth).clamp(8.0, size.width - 8 - _kMenuWidth);
    final openBelow = (size.height - a.bottom) > 320;
    return Stack(
      children: [
        Positioned(
          left: left,
          width: _kMenuWidth,
          top: openBelow ? a.bottom + 6 : null,
          bottom: openBelow ? null : (size.height - a.top + 6),
          child: card,
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.header,
    required this.items,
    required this.centered,
  });

  final Widget? header;
  final List<IosMenuItem> items;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_kRadius);
    final children = <Widget>[];
    if (header != null) {
      children.add(header!);
      children.add(const _Sep());
    }
    for (var i = 0; i < items.length; i++) {
      children.add(_MenuRow(item: items[i], centered: centered));
      if (i != items.length - 1) children.add(const _Sep());
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: DecoratedBox(
            decoration: BoxDecoration(color: _kFill, borderRadius: radius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 0.5, child: ColoredBox(color: _kSeparator));
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.centered});

  final IosMenuItem item;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final color = item.isDestructive ? _kDestructive : _kLabel;
    final label = Text(
      item.label,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        fontSize: 17,
        color: color,
        fontWeight: (centered && item.isDestructive)
            ? FontWeight.w600
            : FontWeight.w400,
      ),
    );
    final Widget content;
    if (centered) {
      content = Center(child: label);
    } else {
      content = Row(
        children: [
          if (item.icon != null) ...[
            Icon(item.icon, size: 20, color: color),
            const SizedBox(width: 12),
          ],
          Expanded(child: label),
          if (item.selected)
            const Icon(CupertinoIcons.check_mark,
                size: 18, color: Color(0xFF1565C0)),
        ],
      );
    }
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      minimumSize: const Size.fromHeight(50),
      borderRadius: BorderRadius.zero,
      onPressed: () {
        Navigator.of(context).pop();
        item.onPressed?.call();
      },
      child: content,
    );
  }
}

class _ConfirmHeader extends StatelessWidget {
  const _ConfirmHeader({this.title, required this.message});

  final String? title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null && title!.isNotEmpty) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kLabel,
              ),
            ),
            const SizedBox(height: 5),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: _kSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
