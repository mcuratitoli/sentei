import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../offline_maps/offline_maps_screen.dart';
import 'cloud_sync_controller.dart';

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
          const _CloudSection(),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Sentèi'),
            subtitle: Text('App escursionismo'),
          ),
        ],
      ),
    );
  }
}

/// Sezione di sincronizzazione cloud (Google Drive): accesso, sincronizza,
/// disconnetti. Gli esiti compaiono come SnackBar.
class _CloudSection extends ConsumerWidget {
  const _CloudSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(cloudSyncProvider);
    final notifier = ref.read(cloudSyncProvider.notifier);

    ref.listen(cloudSyncProvider.select((s) => s.message), (_, msg) {
      if (msg != null && msg.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(msg)));
      }
    });

    final spinner = const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    );

    if (!cloud.signedIn) {
      return ListTile(
        leading: const Icon(Icons.cloud_outlined),
        title: const Text('Google Drive'),
        subtitle: const Text('Accedi per sincronizzare le tracce'),
        trailing: cloud.busy ? spinner : const Icon(Icons.login),
        enabled: !cloud.busy,
        onTap: cloud.busy ? null : notifier.signIn,
      );
    }

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_done_outlined),
          title: const Text('Google Drive'),
          subtitle: Text(cloud.account ?? 'Connesso'),
        ),
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Sincronizza ora'),
          subtitle: const Text('Carica e scarica le tracce (last-write-wins)'),
          trailing: cloud.busy ? spinner : const Icon(Icons.chevron_right),
          enabled: !cloud.busy,
          onTap: cloud.busy ? null : notifier.syncNow,
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Disconnetti'),
          enabled: !cloud.busy,
          onTap: cloud.busy ? null : notifier.signOut,
        ),
      ],
    );
  }
}
