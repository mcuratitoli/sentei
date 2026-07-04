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
import 'package:package_info_plus/package_info_plus.dart';

import '../../ui/cai_difficulty.dart';
import '../../ui/ios_toast.dart';
import '../offline_maps/offline_maps_screen.dart';
import 'cloud_sync_controller.dart';

/// Sfondo raggruppato stile iOS (systemGroupedBackground chiaro).
const Color _kGroupedBg = Color(0xFFF2F2F7);

/// Versione app (unica per Android e iOS, da `pubspec.yaml`): "1.0.0 (2)".
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

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
                    Text('Mapbox Outdoors · Sentiero CAI'),
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
            header: const Text('Informazioni'),
            children: [
              CupertinoListTile(
                leading: const Icon(CupertinoIcons.book,
                    color: Color(0xFF1565C0)),
                title: const Text('Legenda difficoltà'),
                subtitle: const Text('Cosa significano T, E, EE, EEA'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => showDifficultyLegend(context),
              ),
              CupertinoListTile(
                leading:
                    const Icon(CupertinoIcons.info, color: Color(0xFF1565C0)),
                title: const Text('Sentèi'),
                subtitle: const Text('App per l\'escursionismo'),
                additionalInfo:
                    Text(ref.watch(appVersionProvider).value ?? '…'),
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
        showIosToast(context, msg);
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
          // Ordine su iOS: iCloud (prima, a sinistra) · Google Drive (seconda).
          children: const {
            CloudProvider.iCloud: Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('iCloud'),
            ),
            CloudProvider.googleDrive: Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Google Drive'),
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

/// Mostra la card in overlay con la legenda dei gradi di difficoltà CAI.
Future<void> showDifficultyLegend(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _DifficultyLegendSheet(),
  );
}

/// Contenuto della legenda difficoltà: una riga per grado (chip colorato +
/// etichetta + descrizione), in ordine crescente T → E → EE → EEA.
class _DifficultyLegendSheet extends StatelessWidget {
  const _DifficultyLegendSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Difficoltà dei sentieri',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            const Text(
              'Scala CAI (Club Alpino Italiano), in ordine crescente di impegno.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6E6E73)),
            ),
            const SizedBox(height: 16),
            for (final scale in caiScalesInOrder) ...[
              _LegendRow(scale: scale),
              if (scale != caiScalesInOrder.last)
                const Divider(height: 24, thickness: 0.5),
            ],
          ],
        ),
      ),
    );
  }
}

/// Una riga della legenda: badge colorato con la sigla + testo esteso.
class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.scale});

  final String scale;

  @override
  Widget build(BuildContext context) {
    final color = caiScaleColor(scale);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            scale,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caiScaleLabel(scale),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                caiScaleDescription(scale),
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: Color(0xFF3A3A3C),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
