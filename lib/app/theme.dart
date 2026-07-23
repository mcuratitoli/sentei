import 'package:flutter/material.dart';

import '../ui/tokens.dart';

/// Variante del tema **scuro**, scelta dall'utente in Impostazioni quando il
/// tema effettivo è scuro (manuale "Scuro" o "Automatico" con sistema in dark).
enum AppDarkVariant {
  /// Dark elegante in stile iOS (default).
  standard,

  /// Toni caldi/smorzati per l'uso in montagna: basso abbagliamento, preserva
  /// la visione notturna.
  night,

  /// Nero puro (OLED) ovunque possibile, per il minor consumo di batteria.
  oled,
}

extension AppDarkVariantX on AppDarkVariant {
  String get label => switch (this) {
        AppDarkVariant.standard => 'Standard',
        AppDarkVariant.night => 'Notturno',
        AppDarkVariant.oled => 'Risparmio energetico',
      };

  AppPalette get palette => switch (this) {
        AppDarkVariant.standard => AppPalette.darkStandard,
        AppDarkVariant.night => AppPalette.darkNight,
        AppDarkVariant.oled => AppPalette.darkOled,
      };
}

/// Temi dell'app. Palette blu/azzurro; **chiaro** + **3 varianti scure**
/// (vedi [AppDarkVariant]), scelte dall'utente in Impostazioni (`app.dart`).
///
/// **Tipografia:** font **di sistema** della piattaforma (San Francisco su iOS,
/// Roboto su Android) — niente più Lato via `google_fonts`. Su iOS questo dà il
/// look nativo "SF Pro" coerente con i widget Cupertino usati nell'app; Flutter
/// seleziona la `Typography` Cupertino in automatico quando gira su iOS.
///
/// **Design token:** i colori strutturali (sfondi/testo/grigi/vetro) vivono in
/// `AppPalette` (`lib/ui/tokens.dart`) e sono theme-aware via `context.palette`;
/// i colori **brand/semantici** (`AppColors.primary`/`destructive`) restano
/// costanti in ogni variante (salvo `accent`, che nella variante Notturno
/// diventa ambra caldo — vedi [AppPalette.accent]) — `colorScheme.primary` è
/// **forzato** all'accento esatto (`ColorScheme.fromSeed` altrimenti lo
/// rimappa sulla palette tonale M3).
abstract final class AppTheme {
  static ThemeData light() {
    const palette = AppPalette.light;
    final scheme = ColorScheme.fromSeed(seedColor: palette.accent).copyWith(
      primary: palette.accent,
      error: AppColors.destructive,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: _textTheme(palette),
      extensions: const [palette],
    );
  }

  static ThemeData dark(AppDarkVariant variant) {
    final palette = variant.palette;
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: palette.accent,
      error: AppColors.destructive,
      surface: palette.scaffoldBg,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.scaffoldBg,
      textTheme: _textTheme(palette),
      extensions: [palette],
    );
  }

  /// Type scale coerente con gli stili app-specifici in [AppText]. Serve da
  /// fondamenta per il codice che legge `Theme.of(context).textTheme`.
  static TextTheme _textTheme(AppPalette palette) => TextTheme(
        headlineSmall: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        bodyMedium: const TextStyle(fontSize: 14),
        bodySmall: TextStyle(fontSize: 13, color: palette.secondaryLabel),
        labelSmall: TextStyle(fontSize: 12, color: palette.secondaryLabel),
      );
}
