import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/util/format.dart';
import '../../data/gpx/gpx_service.dart';
import '../../domain/services/path_geometry.dart';
import '../draw_route/route_editor_provider.dart';

enum _SortMode { date, alpha }

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
    final filtered =
        q.isEmpty ? [...all] : all.where((t) => t.name.toLowerCase().contains(q)).toList();
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
      appBar: AppBar(
        title: const Text('Tracciati'),
        actions: [
          PopupMenuButton<_SortMode>(
            tooltip: 'Ordina',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (m) => setState(() => _sort = m),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _SortMode.date, child: Text('Per data')),
              PopupMenuItem(value: _SortMode.alpha, child: Text('Alfabetico')),
            ],
          ),
          IconButton(
            tooltip: 'Importa GPX',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _importGpx,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: 'Cerca per nome',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? Center(
              child: Text(
                all.isEmpty
                    ? 'Nessun tracciato salvato.\nDisegnane uno dalla mappa o importa un GPX.'
                    : 'Nessun risultato per "$_query".',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = filtered[i];
                final distance = t.metrics?.distanceMeters ??
                    const PathGeometry().totalDistance(t.routedPath);
                final gain = t.metrics?.elevation.gain;
                return ListTile(
                  leading: CircleAvatar(backgroundColor: t.color, radius: 10),
                  title: Text(t.name.isNotEmpty ? t.name : 'Senza nome'),
                  subtitle: Text([
                    Format.distance(distance),
                    if (gain != null) 'D+ ${Format.meters(gain)}',
                    if (t.trailRefs.isNotEmpty) 'sent. ${t.trailRefs.join(", ")}',
                  ].join(' · ')),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'export') {
                        _exportGpx(t);
                      } else if (v == 'delete') {
                        ref.read(tracksProvider.notifier).remove(t.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'export', child: Text('Esporta GPX')),
                      PopupMenuItem(value: 'delete', child: Text('Elimina')),
                    ],
                  ),
                  onTap: () {
                    ref.read(tracksProvider.notifier).select(t.id);
                    context.pop();
                  },
                );
              },
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Tracciato importato')),
      );
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
