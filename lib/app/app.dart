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
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
