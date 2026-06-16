import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Libreria dei tracciati salvati (placeholder Fase 1).
///
/// Verrà alimentata dal repository drift (data/storage) con export/import GPX.
class TracksListScreen extends ConsumerWidget {
  const TracksListScreen({super.key});

  static const String routeName = 'tracks';
  static const String routePath = '/tracks';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tracciati')),
      body: const Center(
        child: Text('Nessun tracciato salvato.\n(In arrivo: Fase 1)',
            textAlign: TextAlign.center),
      ),
    );
  }
}
