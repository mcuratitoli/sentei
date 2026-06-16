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

/// Libreria dei tracciati salvati (1.D) + export/import GPX (§6.4).
class TracksListScreen extends ConsumerWidget {
  const TracksListScreen({super.key});

  static const String routeName = 'tracks';
  static const String routePath = '/tracks';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(tracksProvider).tracks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracciati'),
        actions: [
          IconButton(
            tooltip: 'Importa GPX',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _importGpx(context, ref),
          ),
        ],
      ),
      body: tracks.isEmpty
          ? const Center(
              child: Text(
                  'Nessun tracciato salvato.\nDisegnane uno dalla mappa o importa un GPX.',
                  textAlign: TextAlign.center),
            )
          : ListView.separated(
              itemCount: tracks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = tracks[i];
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
                        _exportGpx(context, t);
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
                    context.pop(); // torna alla mappa
                  },
                );
              },
            ),
    );
  }

  Future<void> _importGpx(BuildContext context, WidgetRef ref) async {
    const group = XTypeGroup(
      label: 'GPX',
      extensions: ['gpx'],
      uniformTypeIdentifiers: ['public.xml', 'com.topografix.gpx'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    final xml = await file.readAsString();
    final error = await ref.read(tracksProvider.notifier).importGpx(xml);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? 'Tracciato importato'),
      ));
    }
  }

  Future<void> _exportGpx(BuildContext context, DrawnTrack track) async {
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
