import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Tooltip;

import 'tokens.dart';

/// Sistema **unico** di bottoni dell'app (`new design/DESIGN_GUIDELINES.md`
/// §4): quattro varianti, stessa altezza/raggio (pill), nessun'altra
/// combinazione ammessa (niente bottoni pieni rossi/verdi, niente bordi
/// grigi neutri). Sostituisce le vecchie `_PillAction` "a tinta leggera"
/// (bg tinta 14%, non bordata) sparse nelle card.
enum AppButtonVariant {
  /// Sfondo pieno [AppColors.primary] (o [AppButton.color] per un accento di
  /// tema diverso, es. `darkNight`), testo bianco 700. Azione principale.
  primary,

  /// Sfondo trasparente, bordo 1.5px colore, testo colore 600. Azione
  /// alternativa positiva (es. "Modifica titolo").
  secondary,

  /// Nessuno sfondo/bordo, testo [AppPalette.secondaryLabel] 600. Azione a
  /// bassa enfasi (es. "Annulla").
  tertiary,

  /// Bordo 1.5px [AppColors.destructive], testo rosso 600, nessun
  /// riempimento. Cancellazioni/scollegamenti.
  destructive,
}

/// Bottone pillola alto 48px, stesso stile in tutta l'app. Icona opzionale a
/// sinistra del testo (stesso colore del testo).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.variant,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final AppButtonVariant variant;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Tinta di riferimento per `primary`/`secondary` (default
  /// [AppPalette.accent]); `destructive` usa sempre [AppColors.destructive],
  /// non configurabile — non ha senso un bottone "distruttivo" di un altro colore.
  final Color? color;

  static const double _height = 48;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null;
    final tint = variant == AppButtonVariant.destructive
        ? AppColors.destructive
        : (color ?? palette.accent);

    final Color bg;
    final Color fg;
    final Border? border;
    switch (variant) {
      case AppButtonVariant.primary:
        bg = tint.withValues(alpha: enabled ? 1 : 0.4);
        fg = const Color(0xFFFFFFFF);
        border = null;
      case AppButtonVariant.secondary:
        bg = const Color(0x00000000);
        fg = tint.withValues(alpha: enabled ? 1 : 0.4);
        border = Border.all(
            color: tint.withValues(alpha: enabled ? 1 : 0.4), width: 1.5);
      case AppButtonVariant.tertiary:
        bg = const Color(0x00000000);
        fg = palette.secondaryLabel.withValues(alpha: enabled ? 1 : 0.4);
        border = null;
      case AppButtonVariant.destructive:
        bg = const Color(0x00000000);
        fg = tint.withValues(alpha: enabled ? 1 : 0.4);
        border = Border.all(
            color: tint.withValues(alpha: enabled ? 1 : 0.4), width: 1.5);
    }

    Widget button = CupertinoButton(
      padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      minimumSize: const Size(0, _height),
      borderRadius: BorderRadius.circular(_height / 2),
      color: bg,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
          ],
          // `Flexible` (non solo `Text`): quando il bottone è compresso da un
          // `Expanded` esterno (es. due pillole affiancate, `_SelectedWaypointBar`)
          // un'etichetta lunga come "Aggiungi punto prima" va su due righe
          // invece di uscire dai bordi della pillola (overflow).
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.pillLabel
                  .copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    // Il bordo va disegnato attorno alle dimensioni FINALI del bottone (già
    // alto 48px per `minimumSize`), non attorno al solo contenuto interno —
    // altrimenti su `secondary`/`destructive` la pillola apparirebbe senza
    // bordo visibile ai lati corti.
    if (border != null) {
      button = DecoratedBox(
        decoration: BoxDecoration(
            border: border, borderRadius: BorderRadius.circular(_height / 2)),
        child: button,
      );
    }
    return button;
  }
}

/// Icon-button circolare ~44px (`new design/DESIGN_GUIDELINES.md` §5):
/// cerchio con sfondo neutro di default, tinta d'accento quando [active].
///
/// **Quando usarlo vs [AppButton]**: righe dense con **3+ azioni** (es. la
/// barra della card traccia: profilo, colori dislivelli, modifica, salva
/// offline) usano solo [AppIconButton] — con testo per
/// ognuna andrebbe fuori schermo o su due righe. Righe con **1-2 azioni**
/// (barra del punto selezionato, card foto, foglio foto vicine) usano invece
/// [AppButton], più leggibile quando c'è spazio. Non mescolare i due stili
/// nella stessa riga.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null;
    final bg = active
        ? palette.accent.withValues(alpha: 0.14)
        : palette.iconBgNeutral;
    final fg = !enabled
        ? palette.tertiaryIcon
        : active
            ? palette.accent
            : palette.secondaryLabel;
    Widget button = CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size(size, size),
      onPressed: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: fg),
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return button;
  }
}
