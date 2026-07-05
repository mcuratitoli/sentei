import 'package:flutter/material.dart';

/// Tema dell'app. Palette blu/azzurro.
///
/// **Tipografia:** font **di sistema** della piattaforma (San Francisco su iOS,
/// Roboto su Android) — niente più Lota via `google_fonts`. Su iOS questo dà il
/// look nativo "SF Pro" coerente con i widget Cupertino usati nell'app; Flutter
/// seleziona la `Typography` Cupertino in automatico quando gira su iOS.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF1565C0); // blu/azzurro (palette app)

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    );
  }
}
