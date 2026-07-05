import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart'
    show
        CupertinoColors,
        CupertinoIcons,
        CupertinoListSection,
        CupertinoListTile,
        CupertinoSearchTextField;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/util/format.dart';
import '../../data/gpx/gpx_service.dart';
import '../../domain/services/path_geometry.dart';
import '../../ui/ios_menu.dart';
import '../../ui/ios_toast.dart';
import '../draw_route/route_editor_provider.dart';
import '../map/map_providers.dart';
import '../offline_maps/track_offline_download.dart';
import 'tracks_sort_provider.dart';

/// Sfondo raggruppato stile iOS (systemGroupedBackground chiaro).
const Color _kGroupedBg = Color(0xFFF2F2F7);

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
      backgroundColor: _kGroupedBg,
      appBar: AppBar(
        title: const Text('Tracciati'),
        centerTitle: true,
        backgroundColor: _kGroupedBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.4,
        actions: [
          Builder(
            builder: (btnCtx) => IconButton(
              tooltip: 'Ordina',
              icon: const Icon(CupertinoIcons.arrow_up_arrow_down),
              onPressed: () => _showSortSheet(btnCtx),
            ),
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
                  style: const TextStyle(color: CupertinoColors.systemGrey),
                ),
              ),
            )
          : ListView(
              children: [
                CupertinoListSection.insetGrouped(
                  children: [
                    for (final t in filtered) _trackTile(t),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _trackTile(DrawnTrack t) {
    final distance = t.metrics?.distanceMeters ??
        const PathGeometry().totalDistance(t.routedPath);
    final gain = t.metrics?.elevation.gain;
    return CupertinoListTile(
      leading: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: t.color, shape: BoxShape.circle),
      ),
      title: Text(t.name.isNotEmpty ? t.name : 'Senza nome'),
      subtitle: Text([
        Format.distance(distance),
        if (gain != null) 'D+ ${Format.meters(gain)}',
        if (t.trailRefs.isNotEmpty) t.trailRefs.join(", "),
      ].join(' · ')),
      trailing: Builder(
        builder: (btnCtx) => IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(CupertinoIcons.ellipsis_circle,
              color: CupertinoColors.systemGrey),
          onPressed: () => _showTrackActions(btnCtx, t),
        ),
      ),
      onTap: () {
        ref.read(tracksProvider.notifier).select(t.id);
        // Centra la mappa sulla traccia così non va cercata a mano.
        ref.read(mapFocusProvider.notifier).focusTrack(t.id);
        context.pop();
      },
    );
  }

  Future<void> _showSortSheet(BuildContext anchor) async {
    final sort = ref.read(tracksSortProvider);
    final notifier = ref.read(tracksSortProvider.notifier);
    await showIosMenu(
      context: context,
      anchorContext: anchor,
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

  Future<void> _showTrackActions(BuildContext anchor, DrawnTrack t) async {
    await showIosMenu(
      context: context,
      anchorContext: anchor,
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
    const group = XTypeGroup(
      label: 'GPX',
      extensions: ['gpx'],
      uniformTypeIdentifiers: ['public.xml', 'com.topografix.gpx'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    final xml = await file.readAsString();
    final error = await ref.read(tracksProvider.notifier).importGpx(xml);
    if (mounted) {
      showIosToast(context, error ?? 'Tracciato importato');
    }
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
