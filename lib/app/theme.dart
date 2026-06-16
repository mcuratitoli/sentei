import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema dell'app. Palette ispirata all'ambiente alpino (verdi/pietra).
/// Font UI: **Lato** (il nome dell'app usa **Yeseva One**, vedi [appNameStyle]).
abstract final class AppTheme {
  static const Color _seed = Color(0xFF2E6E4E); // verde bosco

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    );
    return base.copyWith(textTheme: GoogleFonts.latoTextTheme(base.textTheme));
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      ),
    );
    return base.copyWith(textTheme: GoogleFonts.latoTextTheme(base.textTheme));
  }

  /// Stile del nome dell'app (Yeseva One) in sovrimpressione sulla mappa.
  static TextStyle appNameStyle(Color color) => GoogleFonts.yesevaOne(
        fontSize: 28,
        color: color,
        shadows: const [
          Shadow(blurRadius: 4, color: Colors.white),
          Shadow(blurRadius: 2, color: Colors.white),
        ],
      );
}
