import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/util/format.dart';
import '../../domain/services/path_geometry.dart';
import '../draw_route/route_editor_provider.dart';

/// Libreria dei tracciati salvati (1.D): elenco persistito su disco (drift).
class TracksListScreen extends ConsumerWidget {
  const TracksListScreen({super.key});

  static const String routeName = 'tracks';
  static const String routePath = '/tracks';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(tracksProvider).tracks;

    return Scaffold(
      appBar: AppBar(title: const Text('Tracciati')),
      body: tracks.isEmpty
          ? const Center(
              child: Text('Nessun tracciato salvato.\nDisegnane uno dalla mappa.',
                  textAlign: TextAlign.center),
            )
          : ListView.separated(
              itemCount: tracks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = tracks[i];
                final distance = t.metrics?.distanceMeters ??
                    const PathGeometry().totalDistance(t.routedPath);
                final gain = t.metrics?.elevation.gain;
                return ListTile(
                  leading: CircleAvatar(backgroundColor: t.color, radius: 10),
                  title: Text(t.name.isNotEmpty ? t.name : 'Senza nome'),
                  subtitle: Text([
                    Format.distance(distance),
                    if (gain != null) 'D+ ${Format.meters(gain)}',
                    if (t.trailRefs.isNotEmpty)
                      'sent. ${t.trailRefs.join(", ")}',
                  ].join(' · ')),
                  trailing: IconButton(
                    tooltip: 'Elimina',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        ref.read(tracksProvider.notifier).remove(t.id),
                  ),
                  onTap: () {
                    ref.read(tracksProvider.notifier).select(t.id);
                    context.pop(); // torna alla mappa
                  },
                );
              },
            ),
    );
  }
}
