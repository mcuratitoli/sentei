import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoButton,
        CupertinoIcons,
        CupertinoListSection,
        CupertinoListTile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/offline/terrarium_tile_cache.dart';
import '../../ui/ios_toast.dart';
import '../../ui/tokens.dart';
import '../draw_route/route_editor_provider.dart';
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
  String _phase = '';

  Future<void> _download(MapAreaBounds b) async {
    final service = ref.read(offlineMapsServiceProvider);
    final now = DateTime.now();
    final name = 'Area ${now.day}/${now.month} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _downloading = true;
      _progress = 0;
      _phase = 'Mappa';
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
      // Elevazione: cache delle tile Terrarium per D+/profilo offline.
      if (mounted) {
        setState(() {
          _phase = 'Elevazione';
          _progress = 0;
        });
      }
      await downloadTerrariumArea(
        cache: ref.read(terrariumCacheProvider),
        south: b.south,
        west: b.west,
        north: b.north,
        east: b.east,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      ref.invalidate(downloadedRegionsProvider);
      if (mounted) {
        showIosToast(context, 'Area "$name" scaricata');
      }
    } catch (e) {
      if (mounted) {
        showIosToast(context, 'Download fallito: $e');
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
      backgroundColor: context.palette.scaffoldBg,
      appBar: AppBar(
        title: const Text('Mappe offline'),
        centerTitle: true,
        backgroundColor: context.palette.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.4,
      ),
      body: ListView(
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('Scarica'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_downloading) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CupertinoActivityIndicator(radius: 9),
                          const SizedBox(width: 12),
                          Text('$_phase… ${(_progress * 100).round()}%'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress == 0 ? null : _progress,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFE3E3EA),
                          color: AppColors.primary,
                        ),
                      ),
                    ] else
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          borderRadius: BorderRadius.circular(12),
                          onPressed:
                              bounds == null ? null : () => _download(bounds),
                          child: Text(
                            bounds == null
                                ? 'Apri prima la mappa sull\'area'
                                : 'Scarica l\'area visualizzata',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      'Scarica mappa + elevazione dell\'area inquadrata, per '
                      'usarla senza connessione (mappa fino allo zoom 15; '
                      'D+/profilo offline).',
                      style: TextStyle(
                          fontSize: 12.5, color: context.palette.secondaryLabel),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          regions.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('Errore: $e')),
            ),
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('Nessuna area scaricata',
                          style: TextStyle(
                              color: context.palette.secondaryLabel)),
                    ),
                  )
                : CupertinoListSection.insetGrouped(
                    header: const Text('Aree scaricate'),
                    children: [
                      for (final r in list)
                        CupertinoListTile(
                          leading: const Icon(CupertinoIcons.map, color: AppColors.primary),
                          title: Text(r.name),
                          subtitle: Text(_fmtSize(r.sizeBytes)),
                          trailing: CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 36),
                            onPressed: () => _delete(r.id),
                            child: const Icon(CupertinoIcons.delete,
                                size: 22, color: AppColors.destructive),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
