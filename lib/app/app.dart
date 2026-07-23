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
        if (mode == AppThemeMode.auto) {
          return child ?? const SizedBox.shrink();
        }
        final forced =
            mode == AppThemeMode.light ? Brightness.light : Brightness.dark;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(platformBrightness: forced),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
