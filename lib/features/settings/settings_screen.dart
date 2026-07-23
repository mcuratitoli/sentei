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

import '../../app/theme.dart';
import '../../app/theme_provider.dart';
import '../../ui/ios_menu.dart';
import '../../ui/ios_toast.dart';
import '../../ui/legends.dart';
import '../../ui/tokens.dart';
import '../offline_maps/offline_maps_screen.dart';
import 'cloud_sync_controller.dart';

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
      backgroundColor: context.palette.scaffoldBg,
      appBar: AppBar(
        title: const Text('Impostazioni'),
        centerTitle: true,
        backgroundColor: context.palette.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.4,
      ),
      body: ListView(
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('Mappa'),
            children: [
              const CupertinoListTile(
                leading: Icon(CupertinoIcons.map, color: AppColors.primary),
                title: Text('Mappa'),
                subtitle:
                    Text('Mapbox Outdoors · Sentiero CAI'),
              ),
              CupertinoListTile(
                leading: const Icon(CupertinoIcons.cloud_download,
                    color: AppColors.primary),
                title: const Text('Mappe offline'),
                subtitle:
                    const Text('Scarica aree per l\'uso senza connessione'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => context.push(OfflineMapsScreen.routePath),
              ),
            ],
          ),
          const _AppearanceSection(),
          const _CloudSection(),
          CupertinoListSection.insetGrouped(
            header: const Text('Informazioni'),
            children: [
              CupertinoListTile(
                leading: const Icon(CupertinoIcons.book,
                    color: AppColors.primary),
                title: const Text('Legenda difficoltà'),
                subtitle:
                    const Text('T · E · EE · EEA, alpinistiche e scala Welzenbach'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => showDifficultyLegend(context),
              ),
              CupertinoListTile(
                leading: const Icon(CupertinoIcons.textformat_abc,
                    color: AppColors.primary),
                title: const Text('Abbreviazioni'),
                subtitle: const Text('ANA, ASF, CAF, CAI, GTA, IGM, IGN, UGET'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => showAbbreviationsLegend(context),
              ),
              CupertinoListTile(
                leading:
                    const Icon(CupertinoIcons.info, color: AppColors.primary),
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

/// Sezione **Aspetto**: modalità di tema (Automatico/Chiaro/Scuro) e, quando il
/// tema effettivo è scuro, la variante (Standard/Notturno/Risparmio energetico).
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appThemeModeProvider);
    final variant = ref.watch(appDarkVariantProvider);
    // "Automatico" segue il sistema: la variante scura ha senso mostrarla solo
    // quando il tema **effettivo** è scuro (manuale, o auto + sistema in dark).
    final systemIsDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isEffectivelyDark =
        mode == AppThemeMode.dark || (mode == AppThemeMode.auto && systemIsDark);

    return CupertinoListSection.insetGrouped(
      header: const Text('Aspetto'),
      children: [
        Builder(
          builder: (tileCtx) => CupertinoListTile(
            leading: const Icon(CupertinoIcons.moon_fill,
                color: AppColors.primary),
            title: const Text('Tema'),
            additionalInfo: Text(mode.label),
            trailing: const CupertinoListTileChevron(),
            onTap: () => _showThemeMenu(tileCtx, ref, mode),
          ),
        ),
        if (isEffectivelyDark)
          Builder(
            builder: (tileCtx) => CupertinoListTile(
              leading: const Icon(CupertinoIcons.sparkles,
                  color: AppColors.primary),
              title: const Text('Variante scura'),
              additionalInfo: Text(variant.label),
              trailing: const CupertinoListTileChevron(),
              onTap: () => _showVariantMenu(tileCtx, ref, variant),
            ),
          ),
      ],
    );
  }

  Future<void> _showThemeMenu(
      BuildContext context, WidgetRef ref, AppThemeMode current) {
    final notifier = ref.read(appThemeModeProvider.notifier);
    return showIosMenu(
      context: context,
      anchorContext: context,
      items: [
        for (final m in AppThemeMode.values)
          IosMenuItem(
            label: m.label,
            selected: m == current,
            onPressed: () => notifier.set(m),
          ),
      ],
    );
  }

  Future<void> _showVariantMenu(
      BuildContext context, WidgetRef ref, AppDarkVariant current) {
    final notifier = ref.read(appDarkVariantProvider.notifier);
    return showIosMenu(
      context: context,
      anchorContext: context,
      items: [
        for (final v in AppDarkVariant.values)
          IosMenuItem(
            label: v.label,
            selected: v == current,
            onPressed: () => notifier.set(v),
          ),
      ],
    );
  }
}

/// Sezione di sincronizzazione cloud: scelta del provider (su iOS), accesso,
/// sincronizza, disconnetti. Gli esiti compaiono come toast iOS.
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
    const tint = AppColors.primary;

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
                color: AppColors.destructive),
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

