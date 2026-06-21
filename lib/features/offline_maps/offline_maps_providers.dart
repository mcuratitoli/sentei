import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/offline/offline_maps_service.dart';

final offlineMapsServiceProvider =
    Provider<OfflineMapsService>((ref) => OfflineMapsService());

/// Bounding box dell'ultima area inquadrata sulla mappa (per "scarica area
/// visualizzata"). Aggiornato dalla mappa quando si ferma (onMapIdle).
class MapAreaBounds {
  const MapAreaBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.zoom,
  });

  final double south, west, north, east, zoom;
}

class LastMapBounds extends Notifier<MapAreaBounds?> {
  @override
  MapAreaBounds? build() => null;

  void set(MapAreaBounds bounds) => state = bounds;
}

final lastMapBoundsProvider =
    NotifierProvider<LastMapBounds, MapAreaBounds?>(LastMapBounds.new);

/// Elenco delle aree mappa scaricate (ricaricabile con `ref.invalidate`).
final downloadedRegionsProvider =
    FutureProvider<List<DownloadedRegion>>((ref) async {
  return ref.read(offlineMapsServiceProvider).list();
});
