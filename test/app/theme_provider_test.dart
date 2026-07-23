import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentei/app/theme.dart';
import 'package:sentei/app/theme_provider.dart';
import 'package:sentei/ui/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('default: Automatico + variante Standard', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(appThemeModeProvider), AppThemeMode.auto);
    expect(container.read(appDarkVariantProvider), AppDarkVariant.standard);
  });

  test('AppThemeMode: label e mappatura a ThemeMode', () {
    expect(AppThemeMode.auto.flutterMode, ThemeMode.system);
    expect(AppThemeMode.light.flutterMode, ThemeMode.light);
    expect(AppThemeMode.dark.flutterMode, ThemeMode.dark);
  });

  test('set persiste e aggiorna subito lo stato (mode + variant)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(appThemeModeProvider.notifier).set(AppThemeMode.dark);
    expect(container.read(appThemeModeProvider), AppThemeMode.dark);

    await container
        .read(appDarkVariantProvider.notifier)
        .set(AppDarkVariant.night);
    expect(container.read(appDarkVariantProvider), AppDarkVariant.night);

    // Una nuova sessione (nuovo container) ripristina dalle preferenze salvate.
    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    // _restore() è asincrono (fire-and-forget da build()): attende che entrambi
    // i provider risolvano dalle preferenze salvate.
    for (var i = 0;
        i < 50 &&
            (container2.read(appThemeModeProvider) == AppThemeMode.auto ||
                container2.read(appDarkVariantProvider) ==
                    AppDarkVariant.standard);
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(container2.read(appThemeModeProvider), AppThemeMode.dark);
    expect(container2.read(appDarkVariantProvider), AppDarkVariant.night);
  });

  test('AppTheme.dark(variant) applica la palette corretta come extension',
      () {
    for (final v in AppDarkVariant.values) {
      final theme = AppTheme.dark(v);
      expect(theme.extension<AppPalette>(), v.palette);
    }
    // Standard, Notturno e Risparmio energetico devono essere visivamente
    // distinguibili (qui: fondo delle superfici in vetro, che differenzia
    // "elevato #1C1C1E" da "nero puro OLED" da "caldo/notturno").
    final glassFills = {
      for (final v in AppDarkVariant.values) v.palette.glassFill,
    };
    expect(glassFills.length, AppDarkVariant.values.length);
  });
}
