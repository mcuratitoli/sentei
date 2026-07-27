import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Tooltip;

import 'cai_difficulty.dart';
import 'tokens.dart';

/// Badge/tag della traccia (`new design/DESIGN_GUIDELINES.md` §6): due forme
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
class AppTrailTag extends StatelessWidget {
  const AppTrailTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
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
  }
}
