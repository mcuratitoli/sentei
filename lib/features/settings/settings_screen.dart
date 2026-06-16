import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/map_sources/map_sources.dart';
import '../map/map_providers.dart';

/// Impostazioni dell'app (placeholder iniziale: sorgente mappa predefinita,
/// info; in arrivo unità, account cloud, ecc.).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String routeName = 'settings';
  static const String routePath = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(selectedBaseSourceProvider);
    final trailsOn = ref.watch(trailsOverlayEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Mappa', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final s in MapSources.bases)
            ListTile(
              title: Text(s.name),
              subtitle: s.note != null
                  ? Text(s.note!, maxLines: 2, overflow: TextOverflow.ellipsis)
                  : null,
              trailing: s.id == base.id
                  ? Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary)
                  : const Icon(Icons.circle_outlined),
              onTap: () =>
                  ref.read(selectedBaseSourceProvider.notifier).select(s),
            ),
          const Divider(),
          const ListTile(
            title:
                Text('Sentieri', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            secondary:
                Icon(trailsOn ? Icons.hiking : Icons.hiking_outlined),
            title: const Text('Mostra sentieri segnati'),
            subtitle: const Text('Overlay Waymarked Trails sulla mappa'),
            value: trailsOn,
            onChanged: (_) =>
                ref.read(trailsOverlayEnabledProvider.notifier).toggle(),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Sentèi'),
            subtitle: Text('App escursionismo'),
          ),
          const ListTile(
            leading: Icon(Icons.cloud_off),
            title: Text('Sincronizzazione cloud'),
            subtitle: Text('In arrivo (Google Drive)'),
            enabled: false,
          ),
        ],
      ),
    );
  }
}
