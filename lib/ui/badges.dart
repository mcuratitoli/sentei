import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Tooltip;

import 'cai_difficulty.dart';
import 'tokens.dart';

/// Badge/tag della traccia (`design/DESIGN_GUIDELINES.md` §6): due forme
/// **sempre distinte**, mai per colore casuale — badge di difficoltà
/// (rettangolo arrotondato) vs tag numero sentiero (pill).

/// Badge del grado di difficoltà CAI complessivo: rettangolo arrotondato
/// (radius 9, non pill), sfondo pieno del colore del livello, testo bianco.
class AppDifficultyBadge extends StatelessWidget {
  const AppDifficultyBadge({super.key, required this.scale});

  final String scale;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Difficoltà CAI: ${caiScaleLabel(scale)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: caiScaleColor(scale),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(scale, style: AppText.badge.copyWith(color: const Color(0xFFFFFFFF))),
      ),
    );
  }
}

/// Tag di un numero sentiero (203, GTA, U09…): pill completamente arrotondata,
/// sfondo bianco/superficie, bordo sottile — sempre distinto per **forma**
/// (non colore) dal badge di difficoltà.
///
/// [onTap] opzionale: quando presente (§"Un segnavia per intero",
/// `docs/ROADMAP.md` P1.3 — dalla card del punto ispezionato o della
/// traccia) la pillola apre l'approfondimento del segnavia; il contenitore
/// è già visivamente "una cosa a sé" (bordo+sfondo), quindi basta un
/// `CupertinoButton` che ne riprende la forma, niente stile aggiuntivo per
/// segnalare che è cliccabile.
class AppTrailTag extends StatelessWidget {
  const AppTrailTag({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: palette.glassFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.borderDivider, width: 1),
      ),
      child: Text(
        label,
        style: AppText.badge
            .copyWith(color: palette.label, fontWeight: FontWeight.w600),
      ),
    );
    if (onTap == null) return pill;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: pill,
    );
  }
}
