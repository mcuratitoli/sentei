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
import '../../ui/action_sheet.dart';
import '../../ui/ios_toast.dart';
import '../draw_route/route_editor_provider.dart';
import '../map/map_providers.dart';
import '../offline_maps/track_offline_download.dart';

enum _SortMode { date, alpha }

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
  _SortMode _sort = _SortMode.date;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(tracksProvider).tracks;

    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? [...all]
        : all.where((t) => t.name.toLowerCase().contains(q)).toList();
    filtered.sort((a, b) {
      switch (_sort) {
        case _SortMode.alpha:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _SortMode.date:
          final da = a.createdAt ?? DateTime(0);
          final db = b.createdAt ?? DateTime(0);
          return db.compareTo(da); // più recenti prima
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
        if (t.trailRefs.isNotEmpty) 'sent. ${t.trailRefs.join(", ")}',
      ].join(' · ')),
      trailing: IconButton(
        visualDensity: VisualDensity.compact,
        icon: const Icon(CupertinoIcons.ellipsis_circle,
            color: CupertinoColors.systemGrey),
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
    await showSenteiActionSheet(
      context: context,
      title: 'Ordina i tracciati',
      actions: [
        SheetAction(
          label: 'Per data (recenti prima)',
          isDefault: _sort == _SortMode.date,
          onPressed: () => setState(() => _sort = _SortMode.date),
        ),
        SheetAction(
          label: 'Alfabetico',
          isDefault: _sort == _SortMode.alpha,
          onPressed: () => setState(() => _sort = _SortMode.alpha),
        ),
      ],
    );
  }

  Future<void> _showTrackActions(DrawnTrack t) async {
    await showSenteiActionSheet(
      context: context,
      title: t.name.isNotEmpty ? t.name : 'Senza nome',
      actions: [
        SheetAction(label: 'Esporta GPX', onPressed: () => _exportGpx(t)),
        SheetAction(
          label: 'Salva offline',
          onPressed: () => downloadTrackOffline(context, ref, t),
        ),
        SheetAction(
          label: 'Elimina',
          isDestructive: true,
          onPressed: () => ref.read(tracksProvider.notifier).remove(t.id),
        ),
      ],
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
