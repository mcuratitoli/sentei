import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoIcons,
        CupertinoListSection,
        CupertinoListTile,
        CupertinoListTileChevron,
        CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../offline_maps/offline_maps_screen.dart';
import 'cloud_sync_controller.dart';

/// Sfondo raggruppato stile iOS (systemGroupedBackground chiaro).
const Color _kGroupedBg = Color(0xFFF2F2F7);

/// Impostazioni dell'app. La mappa è **Mapbox Outdoors** (con terreno 3D e
/// numeri sentiero CAI); non c'è più un selettore di sorgente.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String routeName = 'settings';
  static const String routePath = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _kGroupedBg,
      appBar: AppBar(
        title: const Text('Impostazioni'),
        centerTitle: true,
        backgroundColor: _kGroupedBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.4,
      ),
      body: ListView(
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('Mappa'),
            children: [
              const CupertinoListTile(
                leading: Icon(CupertinoIcons.map, color: Color(0xFF1565C0)),
                title: Text('Mappa'),
                subtitle:
                    Text('Mapbox Outdoors · terreno 3D · numeri sentiero CAI'),
              ),
              CupertinoListTile(
                leading: const Icon(CupertinoIcons.cloud_download,
                    color: Color(0xFF1565C0)),
                title: const Text('Mappe offline'),
                subtitle:
                    const Text('Scarica aree per l\'uso senza connessione'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => context.push(OfflineMapsScreen.routePath),
              ),
            ],
          ),
          const _CloudSection(),
          CupertinoListSection.insetGrouped(
            children: const [
              CupertinoListTile(
                leading: Icon(CupertinoIcons.info, color: Color(0xFF1565C0)),
                title: Text('Sentèi'),
                subtitle: Text('App per l\'escursionismo alpina'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sezione di sincronizzazione cloud: scelta del provider (su iOS), accesso,
/// sincronizza, disconnetti. Gli esiti compaiono come SnackBar.
class _CloudSection extends ConsumerWidget {
  const _CloudSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(cloudSyncProvider);
    final notifier = ref.read(cloudSyncProvider.notifier);
    final providerName = ref.watch(cloudServiceProvider).providerName;

    ref.listen(cloudSyncProvider.select((s) => s.message), (_, msg) {
      if (msg != null && msg.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(msg)));
      }
    });

    const spinner = CupertinoActivityIndicator(radius: 11);
    const tint = Color(0xFF1565C0);

    return CupertinoListSection.insetGrouped(
      header: const Text('Sincronizzazione cloud'),
      children: [
        // iCloud è iOS-only: il selettore ha senso solo lì.
        if (Platform.isIOS) const _CloudProviderSelector(),
        if (!cloud.signedIn)
          CupertinoListTile(
            leading: const Icon(CupertinoIcons.cloud, color: tint),
            title: Text(providerName),
            subtitle: const Text('Accedi per sincronizzare le tracce'),
            trailing: cloud.busy
                ? spinner
                : const Icon(CupertinoIcons.arrow_right_circle),
            onTap: cloud.busy ? null : notifier.signIn,
          )
        else ...[
          CupertinoListTile(
            leading: const Icon(CupertinoIcons.cloud_fill, color: tint),
            title: Text(providerName),
            subtitle: Text(cloud.account ?? 'Connesso'),
          ),
          CupertinoListTile(
            leading: const Icon(CupertinoIcons.arrow_2_circlepath, color: tint),
            title: const Text('Sincronizza ora'),
            subtitle:
                const Text('Carica e scarica le tracce (last-write-wins)'),
            trailing:
                cloud.busy ? spinner : const CupertinoListTileChevron(),
            onTap: cloud.busy ? null : notifier.syncNow,
          ),
          CupertinoListTile(
            leading: const Icon(CupertinoIcons.square_arrow_right,
                color: Color(0xFFC62828)),
            title: const Text('Disconnetti'),
            onTap: cloud.busy ? null : notifier.signOut,
          ),
        ],
      ],
    );
  }
}

/// Selettore del backend cloud (Google Drive / iCloud Drive), mostrato su iOS.
class _CloudProviderSelector extends ConsumerWidget {
  const _CloudProviderSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(cloudProviderProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<CloudProvider>(
          groupValue: selected,
          children: const {
            CloudProvider.googleDrive: Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Google Drive'),
            ),
            CloudProvider.iCloud: Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('iCloud'),
            ),
          },
          onValueChanged: (v) {
            if (v != null) ref.read(cloudProviderProvider.notifier).set(v);
          },
        ),
      ),
    );
  }
}
