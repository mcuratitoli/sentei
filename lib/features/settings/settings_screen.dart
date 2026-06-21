import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../offline_maps/offline_maps_screen.dart';

/// Impostazioni dell'app. La mappa è **Mapbox Outdoors** (con terreno 3D e
/// numeri sentiero CAI); non c'è più un selettore di sorgente.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String routeName = 'settings';
  static const String routePath = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.map_outlined),
            title: Text('Mappa'),
            subtitle: Text('Mapbox Outdoors · terreno 3D · numeri sentiero CAI'),
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined),
            title: const Text('Mappe offline'),
            subtitle: const Text('Scarica aree per l\'uso senza connessione'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(OfflineMapsScreen.routePath),
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
