import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'router.dart';
import 'theme.dart';
import 'theme_provider.dart';

/// Widget radice dell'app.
class SenteiApp extends ConsumerWidget {
  const SenteiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appThemeModeProvider);
    final variant = ref.watch(appDarkVariantProvider);
    return MaterialApp.router(
      title: AppConstants.appDisplayName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(variant),
      themeMode: mode.flutterMode,
      // I widget **Cupertino** (liste inset-grouped, action sheet, ecc.)
      // seguono `platformBrightness` dalla MediaQuery, non il `themeMode`
      // Material. Se l'utente ha scelto esplicitamente Chiaro/Scuro, forziamo
      // la stessa brightness anche lì; in **Automatico** lasciamo passare quella
      // reale del sistema (i Cupertino seguono il sistema come il resto dell'app).
      builder: (context, child) {
        final systemBrightness = MediaQuery.platformBrightnessOf(context);
        final effectiveBrightness = switch (mode) {
          AppThemeMode.auto => systemBrightness,
          AppThemeMode.light => Brightness.light,
          AppThemeMode.dark => Brightness.dark,
        };
        final resolvedTheme = effectiveBrightness == Brightness.dark
            ? AppTheme.dark(variant)
            : AppTheme.light();
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(platformBrightness: effectiveBrightness),
          // Cambio tema/variante **animato**, non a scatto: `AnimatedTheme`
          // interpola `ColorScheme`/`TextTheme` e — poiché `AppPalette`
          // implementa `ThemeExtension.lerp` — anche i colori custom (vetro,
          // sfondi, testo) via `context.palette`. Non copre i widget Cupertino
          // nativi (es. righe di `CupertinoListSection`), che leggono
          // `platformBrightness` (booleana, non interpolabile): per quelli il
          // cambio resta immediato.
          child: AnimatedTheme(
            data: resolvedTheme,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
