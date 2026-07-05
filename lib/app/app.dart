import 'package:flutter/material.dart';

import '../core/constants.dart';
import 'router.dart';
import 'theme.dart';

/// Widget radice dell'app.
class SenteiApp extends StatelessWidget {
  const SenteiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appDisplayName,
      theme: AppTheme.light(),
      // Sentèi è disegnata **solo per il tema chiaro** (mappa, superfici in vetro
      // bianco, palette blu, sfondi grouped chiari). Forziamo il light mode così
      // testo e sfondi restano coerenti anche quando il sistema è in Dark Mode
      // (altrimenti: testo chiaro su sfondi chiari hardcodati = quasi invisibile,
      // e i widget Cupertino renderizzano scuri → incoerenza).
      themeMode: ThemeMode.light,
      // Il `builder` forza la brightness a *light* anche per i widget **Cupertino**
      // (liste inset-grouped, action sheet, ecc.), che seguono `platformBrightness`
      // dalla MediaQuery e non il `themeMode` di Material.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(platformBrightness: Brightness.light),
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
