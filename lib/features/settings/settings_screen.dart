import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoButton,
        CupertinoIcons,
        CupertinoListTile,
        CupertinoListTileChevron,
        CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/theme.dart';
import '../../app/theme_provider.dart';
import '../../domain/services/hiking_time.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/app_list_section.dart';
import '../../ui/ios_toast.dart';
import '../../ui/legends.dart';
import '../../ui/release_notes.dart';
import '../../ui/tokens.dart';
import '../offline_maps/offline_maps_screen.dart';
import 'cloud_sync_controller.dart';
import 'hiking_pace_provider.dart';

/// Contenitore icona uniforme per le righe di Impostazioni (`new
/// design/DESIGN_GUIDELINES.md` §5): quadrato arrotondato 30×30, sfondo
/// tinta d'accento (rossa solo per un'azione distruttiva come "Disconnetti").
class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon, {this.destructive = false});

  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? AppColors.destructive : context.palette.accent;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 17, color: tint),
    );
  }
}

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
          AppListSection(
            header: 'Mappa',
            children: [
              CupertinoListTile(
                leading: const _SettingsIcon(CupertinoIcons.map),
                title: const Text('Mappa'),
                subtitle:
                    const Text('Mapbox Outdoors · Sentiero CAI'),
              ),
              CupertinoListTile(
                leading: const _SettingsIcon(CupertinoIcons.cloud_download),
                title: const Text('Mappe offline'),
                subtitle:
                    const Text('Scarica aree per l\'uso senza connessione'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => context.push(OfflineMapsScreen.routePath),
              ),
            ],
          ),
          const _HikingSection(),
          const _AppearanceSection(),
          const _CloudSection(),
          AppListSection(
            header: 'Informazioni',
            children: [
              CupertinoListTile(
                leading: const _SettingsIcon(CupertinoIcons.book),
                title: const Text('Legenda difficoltà'),
                subtitle:
                    const Text('T · E · EE · EEA, alpinistiche e scala Welzenbach'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => showDifficultyLegend(context),
              ),
              CupertinoListTile(
                leading: const _SettingsIcon(CupertinoIcons.textformat_abc),
                title: const Text('Abbreviazioni'),
                subtitle: const Text('ANA, ASF, CAF, CAI, GTA, IGM, IGN, UGET'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => showAbbreviationsLegend(context),
              ),
              CupertinoListTile(
                leading: const _SettingsIcon(CupertinoIcons.info),
                title: const Text('Sentèi'),
                subtitle: const Text('App per l\'escursionismo · novità'),
                additionalInfo:
                    Text(ref.watch(appVersionProvider).value ?? '…'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => showReleaseNotes(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sezione **Escursionismo**: passo dell'escursionista, moltiplicatore sulla
/// stima del tempo di percorrenza mostrata su ogni traccia (§ROADMAP P1.2).
class _HikingSection extends ConsumerWidget {
  const _HikingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pace = ref.watch(hikingPaceProvider);
    return AppListSection(
      header: 'Escursionismo',
      children: [
        CupertinoListTile(
          leading: const _SettingsIcon(CupertinoIcons.speedometer),
          title: const Text('Passo'),
          subtitle:
              const Text('Il tempo stimato non include le soste'),
          additionalInfo: Text(pace.label),
          trailing: const CupertinoListTileChevron(),
          onTap: () => _showPaceSheet(context, ref, pace),
        ),
      ],
    );
  }

  Future<void> _showPaceSheet(
      BuildContext context, WidgetRef ref, HikingPace current) {
    final notifier = ref.read(hikingPaceProvider.notifier);
    return showAppBottomSheet<void>(
      context: context,
      builder: (_) => _SelectionSheet<HikingPace>(
        title: 'Passo',
        values: HikingPace.values,
        current: current,
        labelOf: (p) => p.label,
        onSelected: notifier.set,
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

    return AppListSection(
      header: 'Aspetto',
      children: [
        CupertinoListTile(
          leading: const _SettingsIcon(CupertinoIcons.moon_fill),
          title: const Text('Tema'),
          // subtitle (non additionalInfo): "Risparmio energetico" è troppo
          // lungo per stare a destra senza troncare il titolo della riga.
          subtitle: Text(mode.label),
          trailing: const CupertinoListTileChevron(),
          onTap: () => _showThemeSheet(context, ref, mode),
        ),
        if (isEffectivelyDark)
          CupertinoListTile(
            leading: const _SettingsIcon(CupertinoIcons.sparkles),
            title: const Text('Variante scura'),
            subtitle: Text(variant.label),
            trailing: const CupertinoListTileChevron(),
            onTap: () => _showVariantSheet(context, ref, variant),
          ),
      ],
    );
  }

  Future<void> _showThemeSheet(
      BuildContext context, WidgetRef ref, AppThemeMode current) {
    final notifier = ref.read(appThemeModeProvider.notifier);
    return showAppBottomSheet<void>(
      context: context,
      builder: (_) => _SelectionSheet<AppThemeMode>(
        title: 'Tema',
        values: AppThemeMode.values,
        current: current,
        labelOf: (m) => m.label,
        onSelected: notifier.set,
      ),
    );
  }

  Future<void> _showVariantSheet(
      BuildContext context, WidgetRef ref, AppDarkVariant current) {
    final notifier = ref.read(appDarkVariantProvider.notifier);
    return showAppBottomSheet<void>(
      context: context,
      builder: (_) => _SelectionSheet<AppDarkVariant>(
        title: 'Variante scura',
        values: AppDarkVariant.values,
        current: current,
        labelOf: (v) => v.label,
        onSelected: notifier.set,
      ),
    );
  }
}

/// Bottom sheet di selezione da una lista breve (tema, variante scura):
/// titolo + × in header, righe testo con spunta sul valore corrente — stessa
/// struttura di "Selezione tema" in `new design/DESIGN_GUIDELINES.md` §7.
class _SelectionSheet<T> extends StatelessWidget {
  const _SelectionSheet({
    required this.title,
    required this.values,
    required this.current,
    required this.labelOf,
    required this.onSelected,
  });

  final String title;
  final List<T> values;
  final T current;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSheetHeader(
          title: title,
          onClose: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 6),
        for (final v in values) ...[
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            minimumSize: const Size(0, 0),
            onPressed: () {
              Navigator.of(context).pop();
              onSelected(v);
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(labelOf(v),
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: palette.label,
                              )),
                ),
                if (v == current)
                  Icon(CupertinoIcons.checkmark,
                      size: 18, color: palette.accent),
              ],
            ),
          ),
          if (v != values.last) Divider(color: palette.borderDivider, height: 1),
        ],
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
    final provider = ref.watch(cloudProviderProvider);
    // iCloud: la nuvola è già l'icona reale del servizio. Google Drive: icona
    // distinta (triangolo "aggiungi a Drive") così le due righe non si
    // confondono più a colpo d'occhio.
    final providerIcon = switch (provider) {
      CloudProvider.iCloud =>
        cloud.signedIn ? CupertinoIcons.cloud_fill : CupertinoIcons.cloud,
      CloudProvider.googleDrive => Icons.add_to_drive,
    };

    ref.listen(cloudSyncProvider.select((s) => s.message), (_, msg) {
      if (msg != null && msg.isNotEmpty) {
        showIosToast(context, msg);
      }
    });

    const spinner = CupertinoActivityIndicator(radius: 11);

    return AppListSection(
      header: 'Sincronizzazione cloud',
      children: [
        // iCloud è iOS-only: il selettore ha senso solo lì.
        if (Platform.isIOS) const _CloudProviderSelector(),
        if (!cloud.signedIn)
          CupertinoListTile(
            leading: _SettingsIcon(providerIcon),
            title: Text(providerName),
            subtitle: const Text('Accedi per sincronizzare le tracce'),
            trailing: cloud.busy
                ? spinner
                : const Icon(CupertinoIcons.arrow_right_circle),
            onTap: cloud.busy ? null : notifier.signIn,
          )
        else ...[
          CupertinoListTile(
            leading: _SettingsIcon(providerIcon),
            title: Text(providerName),
            subtitle: Text(cloud.account ?? 'Connesso'),
          ),
          CupertinoListTile(
            leading: const _SettingsIcon(CupertinoIcons.arrow_2_circlepath),
            title: const Text('Sincronizza ora'),
            subtitle:
                const Text('Carica e scarica le tracce (last-write-wins)'),
            trailing:
                cloud.busy ? spinner : const CupertinoListTileChevron(),
            onTap: cloud.busy ? null : notifier.syncNow,
          ),
          CupertinoListTile(
            leading: const _SettingsIcon(CupertinoIcons.square_arrow_right,
                destructive: true),
            title: const Text('Disconnetti',
                style: TextStyle(color: AppColors.destructive)),
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

