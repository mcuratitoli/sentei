import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema dell'app. Palette blu/azzurro. Font UI: **Lato**.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF1565C0); // blu/azzurro (palette app)

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
}
