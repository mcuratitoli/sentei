import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Un'area mappa scaricata per l'uso offline.
class DownloadedRegion {
  const DownloadedRegion({
    required this.id,
    required this.name,
    required this.sizeBytes,
  });

  final String id;
  final String name;
  final int sizeBytes;
}

/// Gestione delle **mappe offline** via Mapbox OfflineManager + TileStore:
/// scarica lo *style pack* (Outdoors) e le **tile vettoriali** di un'area
/// (bbox + range di zoom), elenca e rimuove le aree scaricate.
class OfflineMapsService {
  OfflineManager? _offline;
  TileStore? _tileStore;

  Future<void> _ensure() async {
    _offline ??= await OfflineManager.create();
    _tileStore ??= await TileStore.createDefault();
  }

  /// Scarica mappa (stile + tile) per il bounding box, con progresso 0..1.
  Future<void> downloadArea({
    required String id,
    required String name,
    required double south,
    required double west,
    required double north,
    required double east,
    int minZoom = 8,
    int maxZoom = 15,
    void Function(double progress)? onProgress,
  }) async {
    await _ensure();
    // 1) Style pack: font, sprite, JSON dello stile Outdoors (una volta).
    await _offline!.loadStylePack(
      MapboxStyles.OUTDOORS,
      StylePackLoadOptions(acceptExpired: true, metadata: {'name': name}),
      null,
    );
    // 2) Tile region: tile vettoriali per l'area (Polygon GeoJSON, lng,lat).
    final geometry = <String, Object>{
      'type': 'Polygon',
      'coordinates': [
        [
          [west, south],
          [east, south],
          [east, north],
          [west, north],
          [west, south],
        ],
      ],
    };
    await _tileStore!.loadTileRegion(
      id,
      TileRegionLoadOptions(
        geometry: geometry,
        descriptorsOptions: [
          TilesetDescriptorOptions(
            styleURI: MapboxStyles.OUTDOORS,
            minZoom: minZoom,
            maxZoom: maxZoom,
          ),
        ],
        metadata: {'name': name},
        acceptExpired: true,
        networkRestriction: NetworkRestriction.NONE,
      ),
      (p) {
        if (onProgress != null && p.requiredResourceCount > 0) {
          onProgress(p.completedResourceCount / p.requiredResourceCount);
        }
      },
    );
  }

  /// Elenco delle aree scaricate (con nome dai metadati e dimensione in byte).
  Future<List<DownloadedRegion>> list() async {
    await _ensure();
    final regions = await _tileStore!.allTileRegions();
    final out = <DownloadedRegion>[];
    for (final r in regions) {
      var name = r.id;
      try {
        final md = await _tileStore!.tileRegionMetadata(r.id);
        final n = md['name'];
        if (n is String && n.isNotEmpty) name = n;
      } catch (_) {}
      out.add(DownloadedRegion(
        id: r.id,
        name: name,
        sizeBytes: r.completedResourceSize,
      ));
    }
    return out;
  }

  /// Rimuove un'area scaricata (lo style pack resta, è condiviso).
  Future<void> delete(String id) async {
    await _ensure();
    await _tileStore!.removeRegion(id);
  }
}
