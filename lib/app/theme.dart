import 'package:flutter/material.dart';

import '../ui/tokens.dart';

/// Tema dell'app. Palette blu/azzurro, **solo tema chiaro** (vedi `app.dart`).
///
/// **Tipografia:** font **di sistema** della piattaforma (San Francisco su iOS,
/// Roboto su Android) — niente più Lato via `google_fonts`. Su iOS questo dà il
/// look nativo "SF Pro" coerente con i widget Cupertino usati nell'app; Flutter
/// seleziona la `Typography` Cupertino in automatico quando gira su iOS.
///
/// **Design token:** i colori/spaziature/raggi vivono in `lib/ui/tokens.dart`.
/// Qui il `colorScheme.primary` è **forzato** al blu del brand esatto
/// ([AppColors.primary]) — `ColorScheme.fromSeed` altrimenti lo rimappa sulla
/// palette tonale M3, mentre l'app usa quel blu preciso ovunque.
abstract final class AppTheme {
  static const Color _seed = AppColors.primary; // blu/azzurro (palette app)

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: _seed).copyWith(
      primary: AppColors.primary,
      error: AppColors.destructive,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: _textTheme,
    );
  }

  /// Type scale coerente con gli stili app-specifici in [AppText]. Serve da
  /// fondamenta per il codice che legge `Theme.of(context).textTheme`.
  static const TextTheme _textTheme = TextTheme(
    headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    bodyMedium: TextStyle(fontSize: 14),
    bodySmall: TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
    labelSmall: TextStyle(fontSize: 12, color: AppColors.secondaryLabel),
  );
}
