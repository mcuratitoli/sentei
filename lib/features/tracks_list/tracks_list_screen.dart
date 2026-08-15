import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart'
    show
        CupertinoIcons,
        CupertinoListTile,
        CupertinoSearchTextField;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/util/format.dart';
import '../../data/gpx/gpx_service.dart';
import '../../domain/services/hiking_time.dart';
import '../../domain/services/path_geometry.dart';
import '../../ui/app_buttons.dart';
import '../../ui/app_list_section.dart';
import '../../ui/ios_menu.dart';
import '../../ui/ios_toast.dart';
import '../../ui/tokens.dart';
import '../draw_route/route_editor_provider.dart';
import '../map/map_providers.dart';
import '../offline_maps/track_offline_download.dart';
import '../settings/hiking_pace_provider.dart';
import 'tracks_sort_provider.dart';

const _hikingTimeCalculator = HikingTimeCalculator();

/// Libreria dei tracciati salvati (1.D) + export/import GPX (§6.4), con
/// ordinamento (data/alfabetico) e ricerca sul titolo.
class TracksListScreen extends ConsumerStatefulWidget {
  const TracksListScreen({super.key});

  static const String routeName = 'tracks';
  static const String routePath = '/tracks';

  @override
  ConsumerState<TracksListScreen> createState() => _TracksListScreenState();
}

class _TracksListScreenState extends ConsumerState<TracksListScreen> {
  String _query = '';

  static double _gain(DrawnTrack t) => t.metrics?.elevation.gain ?? 0;
  static double _maxAlt(DrawnTrack t) => t.metrics?.profile.maxElevation ?? 0;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(tracksProvider).tracks;
    final sort = ref.watch(tracksSortProvider);
    final pace = ref.watch(hikingPaceProvider);

    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? [...all]
        : all.where((t) => t.name.toLowerCase().contains(q)).toList();
    filtered.sort((a, b) {
      switch (sort) {
        case TrackSortMode.alpha:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case TrackSortMode.date:
          final da = a.createdAt ?? DateTime(0);
          final db = b.createdAt ?? DateTime(0);
          return db.compareTo(da); // più recenti prima
        case TrackSortMode.elevationGain:
          return _gain(b).compareTo(_gain(a)); // D+ decrescente
        case TrackSortMode.maxAltitude:
          return _maxAlt(b).compareTo(_maxAlt(a)); // quota più alta decrescente
      }
    });

    return Scaffold(
      backgroundColor: context.palette.scaffoldBg,
      appBar: AppBar(
        title: const Text('Tracciati'),
        centerTitle: true,
        backgroundColor: context.palette.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.4,
        actions: [
          IconButton(
            tooltip: 'Ordina',
            icon: const Icon(CupertinoIcons.arrow_up_arrow_down),
            onPressed: _showSortSheet,
          ),
          IconButton(
            tooltip: 'Importa GPX',
            icon: const Icon(CupertinoIcons.tray_arrow_down),
            onPressed: _importGpx,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: CupertinoSearchTextField(
              placeholder: 'Cerca per nome',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  all.isEmpty
                      ? 'Nessun tracciato salvato.\nDisegnane uno dalla mappa o importa un GPX.'
                      : 'Nessun risultato per "$_query".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.palette.secondaryLabel),
                ),
              ),
            )
          : ListView(
              children: [
                AppListSection(
                  children: [
                    for (final t in filtered) _trackTile(t, pace),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _trackTile(DrawnTrack t, HikingPace pace) {
    final distance = t.metrics?.distanceMeters ??
        const PathGeometry().totalDistance(t.routedPath);
    final gain = t.metrics?.elevation.gain;
    final metrics = t.metrics;
    // Solo il totale in lista (compatta): la salita/discesa separate — per
    // un percorso chiuso, es. su e giù da un rifugio — si vedono aprendo la
    // card della traccia (`draw_route_controls.dart`, `_HikingTimeRow`).
    final hikingTime = metrics == null
        ? null
        : _hikingTimeCalculator
            .estimateForTrack(
              metrics.profile,
              distanceMeters: metrics.distanceMeters,
              gainMeters: metrics.elevation.gain,
              lossMeters: metrics.elevation.loss,
              pace: pace,
            )
            .total;
    return CupertinoListTile(
      // Pallino colore tracciato: cerchio pieno 12-13px (`new
      // design/DESIGN_GUIDELINES.md` §6), non più 16px.
      leading: Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(color: t.color, shape: BoxShape.circle),
      ),
      title: Text(t.name.isNotEmpty ? t.name : 'Senza nome'),
      subtitle: Text([
        Format.distance(distance),
        if (gain != null) 'D+ ${Format.meters(gain)}',
        if (hikingTime != null && hikingTime > Duration.zero)
          Format.duration(hikingTime),
        if (t.trailRefs.isNotEmpty) t.trailRefs.join(", "),
      ].join(' · ')),
      trailing: AppIconButton(
        tooltip: 'Altre azioni',
        icon: CupertinoIcons.ellipsis,
        size: 36,
        onPressed: () => _showTrackActions(t),
      ),
      onTap: () {
        ref.read(tracksProvider.notifier).select(t.id);
        // Centra la mappa sulla traccia così non va cercata a mano.
        ref.read(mapFocusProvider.notifier).focusTrack(t.id);
        context.pop();
      },
    );
  }

  Future<void> _showSortSheet() async {
    final sort = ref.read(tracksSortProvider);
    final notifier = ref.read(tracksSortProvider.notifier);
    await showIosMenu(
      context: context,
      title: 'Ordina per',
      items: [
        IosMenuItem(
          label: 'Alfabetico',
          icon: CupertinoIcons.textformat_abc,
          selected: sort == TrackSortMode.alpha,
          onPressed: () => notifier.set(TrackSortMode.alpha),
        ),
        IosMenuItem(
          label: 'Per data',
          icon: CupertinoIcons.calendar,
          selected: sort == TrackSortMode.date,
          onPressed: () => notifier.set(TrackSortMode.date),
        ),
        IosMenuItem(
          label: 'Dislivello (D+)',
          icon: CupertinoIcons.arrow_up,
          selected: sort == TrackSortMode.elevationGain,
          onPressed: () => notifier.set(TrackSortMode.elevationGain),
        ),
        IosMenuItem(
          label: 'Quota più alta',
          icon: CupertinoIcons.triangle,
          selected: sort == TrackSortMode.maxAltitude,
          onPressed: () => notifier.set(TrackSortMode.maxAltitude),
        ),
      ],
    );
  }

  Future<void> _showTrackActions(DrawnTrack t) async {
    await showIosMenu(
      context: context,
      title: t.name.isNotEmpty ? t.name : 'Senza nome',
      items: [
        IosMenuItem(
          label: 'Esporta GPX',
          icon: CupertinoIcons.square_arrow_up,
          onPressed: () => _exportGpx(t),
        ),
        IosMenuItem(
          label: 'Salva offline',
          icon: CupertinoIcons.cloud_download,
          onPressed: () => downloadTrackOffline(context, ref, t),
        ),
        IosMenuItem(
          label: 'Elimina',
          icon: CupertinoIcons.delete,
          isDestructive: true,
          onPressed: () => _confirmDeleteTrack(t),
        ),
      ],
    );
  }

  void _confirmDeleteTrack(DrawnTrack t) {
    final name = t.name.isNotEmpty ? t.name : 'Senza nome';
    showIosConfirm(
      context: context,
      title: 'Eliminare la traccia?',
      message: '«$name» verrà eliminata definitivamente.',
      confirmLabel: 'Elimina',
      onConfirm: () => ref.read(tracksProvider.notifier).remove(t.id),
    );
  }

  Future<void> _importGpx() async {
    // Su iOS il selettore file filtra **solo** per `uniformTypeIdentifiers`
    // (`extensions` vale su desktop): perché un .gpx risulti conforme a questi
    // UTI serve la dichiarazione `UTImportedTypeDeclarations` in
    // `ios/Runner/Info.plist` — senza, il sistema lo classifica `public.data`
    // generico e il file appare in grigio, non selezionabile.
    const group = XTypeGroup(
      label: 'GPX',
      extensions: ['gpx'],
      uniformTypeIdentifiers: ['public.xml', 'com.topografix.gpx'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    final xml = await file.readAsString();
    final error = await ref
        .read(tracksProvider.notifier)
        .importGpx(xml, fileName: file.name);
    if (!mounted) return;
    if (error != null) {
      showIosToast(context, error);
      return;
    }
    // Import avviato: torna alla mappa a vedere la traccia importata (grezza
    // tratteggiata + caricamento, poi il percorso instradato lungo i sentieri).
    //
    // L'id da inquadrare è quello dell'**import in corso**, non `selectedId`:
    // nella fase 1 la traccia esiste già nella lista (apposta, per poterla
    // inquadrare) ma non è ancora né selezionata né in editing — `selectedId`
    // restava null e la mappa non si spostava mai sulla traccia importata.
    final id = ref.read(importLoadingProvider);
    if (context.canPop()) context.pop();
    if (id != null) ref.read(mapFocusProvider.notifier).focusTrack(id);
  }

  Future<void> _exportGpx(DrawnTrack track) async {
    final xml = const GpxService().exportToGpx(track);
    final dir = await getTemporaryDirectory();
    final safe = (track.name.isNotEmpty ? track.name : 'tracciato')
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final path = '${dir.path}/$safe.gpx';
    await File(path).writeAsString(xml);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: track.name),
    );
  }
}
