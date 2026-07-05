import 'dart:ui';

import 'package:flutter/cupertino.dart';

/// Un'azione di [showSenteiActionSheet].
class SheetAction {
  const SheetAction({
    required this.label,
    this.onPressed,
    this.isDestructive = false,
    this.isDefault = false,
  });

  final String label;

  /// Eseguita **dopo** la chiusura del sheet (così l'eventuale navigazione o
  /// dialog successivo parte a sheet già chiuso).
  final VoidCallback? onPressed;

  /// Rossa (azione distruttiva, es. "Elimina").
  final bool isDestructive;

  /// In grassetto/accento (azione preferita o voce attualmente selezionata).
  final bool isDefault;
}

/// Action sheet in stile **iOS 26**: titolo/messaggio opzionali in un riquadro
/// in vetro, poi le azioni come **capsule separate** impilate, e la capsula
/// "Annulla" staccata in fondo. Sostituisce `CupertinoActionSheet`/
/// `CupertinoAlertDialog` per un look Apple più recente.
Future<void> showSenteiActionSheet({
  required BuildContext context,
  String? title,
  String? message,
  required List<SheetAction> actions,
  String cancelLabel = 'Annulla',
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => _SenteiActionSheet(
      title: title,
      message: message,
      actions: actions,
      cancelLabel: cancelLabel,
    ),
  );
}

// Riempimento traslucido delle capsule (light mode: la app è solo chiara).
const Color _kCapsuleFill = Color(0xF2FFFFFF); // bianco ~0.95
const Color _kCapsuleFillCancel = Color(0xFFFFFFFF);
const double _kRadius = 22;

class _SenteiActionSheet extends StatelessWidget {
  const _SenteiActionSheet({
    required this.title,
    required this.message,
    required this.actions,
    required this.cancelLabel,
  });

  final String? title;
  final String? message;
  final List<SheetAction> actions;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final hasHeader = (title != null && title!.isNotEmpty) ||
        (message != null && message!.isNotEmpty);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader) ...[
            _Capsule(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null && title!.isNotEmpty)
                      Text(
                        title!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: CupertinoColors.label,
                        ),
                      ),
                    if (message != null && message!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (final a in actions) ...[
            _Capsule(
              child: _ActionButton(action: a),
            ),
            const SizedBox(height: 8),
          ],
          _Capsule(
            fill: _kCapsuleFillCancel,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 16),
              borderRadius: BorderRadius.circular(_kRadius),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                cancelLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Contenitore capsula in vetro smerigliato (blur + fill traslucido + ombra).
class _Capsule extends StatelessWidget {
  const _Capsule({required this.child, this.fill = _kCapsuleFill});

  final Widget child;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_kRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: DecoratedBox(
            decoration: BoxDecoration(color: fill, borderRadius: radius),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final SheetAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.isDestructive
        ? CupertinoColors.systemRed
        : CupertinoColors.label;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 16),
      borderRadius: BorderRadius.circular(_kRadius),
      onPressed: () {
        Navigator.of(context).pop();
        action.onPressed?.call();
      },
      child: Text(
        action.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: action.isDefault ? FontWeight.w700 : FontWeight.w400,
          color: color,
        ),
      ),
    );
  }
}
