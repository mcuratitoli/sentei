import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_maps_providers.dart';

/// Gestione **mappe offline**: scarica l'area visualizzata (mappa Mapbox) e
/// gestisce le aree già scaricate (lista, dimensione, elimina).
class OfflineMapsScreen extends ConsumerStatefulWidget {
  const OfflineMapsScreen({super.key});

  static const String routeName = 'offline-maps';
  static const String routePath = '/offline-maps';

  @override
  ConsumerState<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends ConsumerState<OfflineMapsScreen> {
  bool _downloading = false;
  double _progress = 0;

  Future<void> _download(MapAreaBounds b) async {
    final service = ref.read(offlineMapsServiceProvider);
    final now = DateTime.now();
    final name = 'Area ${now.day}/${now.month} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    try {
      await service.downloadArea(
        id: 'region-${now.millisecondsSinceEpoch}',
        name: name,
        south: b.south,
        west: b.west,
        north: b.north,
        east: b.east,
        maxZoom: 15,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      ref.invalidate(downloadedRegionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Area "$name" scaricata')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download fallito: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _delete(String id) async {
    await ref.read(offlineMapsServiceProvider).delete(id);
    ref.invalidate(downloadedRegionsProvider);
  }

  String _fmtSize(int bytes) {
    if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
    if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final bounds = ref.watch(lastMapBoundsProvider);
    final regions = ref.watch(downloadedRegionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mappe offline')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_downloading) ...[
                  LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                  const SizedBox(height: 8),
                  Text('Scaricamento… ${(_progress * 100).round()}%',
                      textAlign: TextAlign.center),
                ] else
                  FilledButton.icon(
                    icon: const Icon(Icons.download_for_offline),
                    label: Text(bounds == null
                        ? 'Apri prima la mappa sull\'area'
                        : 'Scarica l\'area visualizzata'),
                    onPressed: bounds == null ? null : () => _download(bounds),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Scarica la mappa dell\'area che hai inquadrato, per usarla '
                  'senza connessione (fino allo zoom 15).',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: regions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Errore: $e')),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('Nessuna area scaricata'))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = list[i];
                        return ListTile(
                          leading: const Icon(Icons.map_outlined),
                          title: Text(r.name),
                          subtitle: Text(_fmtSize(r.sizeBytes)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Elimina',
                            onPressed: () => _delete(r.id),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
