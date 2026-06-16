import 'package:flutter/material.dart';

/// Tema dell'app. Palette ispirata all'ambiente alpino (verdi/pietra).
abstract final class AppTheme {
  static const Color _seed = Color(0xFF2E6E4E); // verde bosco

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      );
}
