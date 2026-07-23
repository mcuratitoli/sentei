import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Modalità di tema selezionabile dall'utente in Impostazioni.
enum AppThemeMode { auto, light, dark }

extension AppThemeModeX on AppThemeMode {
  String get label => switch (this) {
        AppThemeMode.auto => 'Automatico',
        AppThemeMode.light => 'Chiaro',
        AppThemeMode.dark => 'Scuro',
      };

  ThemeMode get flutterMode => switch (this) {
        AppThemeMode.auto => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };
}

/// Modalità di tema (Automatico/Chiaro/Scuro), **persistita** in
/// `shared_preferences`. Default: **Automatico** (segue il sistema).
class AppThemeModeController extends Notifier<AppThemeMode> {
  static const _key = 'app_theme_mode';

  @override
  AppThemeMode build() {
    _restore();
    return AppThemeMode.auto;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == null) return;
      for (final m in AppThemeMode.values) {
        if (m.name == saved) {
          if (m != state) state = m;
          return;
        }
      }
    } catch (_) {
      // shared_preferences non disponibile (es. in test): resta il default.
    }
  }

  Future<void> set(AppThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {
      // best-effort
    }
  }
}

final appThemeModeProvider =
    NotifierProvider<AppThemeModeController, AppThemeMode>(
        AppThemeModeController.new);

/// Variante del tema scuro (Standard/Notturno/Risparmio energetico),
/// **persistita**. Rilevante solo quando il tema effettivo è scuro. Default:
/// **Standard**.
class AppDarkVariantController extends Notifier<AppDarkVariant> {
  static const _key = 'app_dark_variant';

  @override
  AppDarkVariant build() {
    _restore();
    return AppDarkVariant.standard;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == null) return;
      for (final v in AppDarkVariant.values) {
        if (v.name == saved) {
          if (v != state) state = v;
          return;
        }
      }
    } catch (_) {
      // shared_preferences non disponibile (es. in test): resta il default.
    }
  }

  Future<void> set(AppDarkVariant variant) async {
    state = variant;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, variant.name);
    } catch (_) {
      // best-effort
    }
  }
}

final appDarkVariantProvider =
    NotifierProvider<AppDarkVariantController, AppDarkVariant>(
        AppDarkVariantController.new);
