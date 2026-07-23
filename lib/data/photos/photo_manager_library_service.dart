import 'dart:typed_data' show Uint8List;

import 'package:latlong2/latlong.dart' as ll;
import 'package:photo_manager/photo_manager.dart';

import '../../domain/models/photo_candidate.dart';
import 'photo_library_service.dart';

/// Implementazione di [PhotoLibraryService] su `photo_manager`
/// (§"Sync album fotografico", `docs/eval-photo-sync.md`).
///
/// Limite [_maxAssetsScanned]: la ricerca è avviata manualmente dall'utente
/// ("Trova foto" sulla card, non automatica — vedi decisione nel doc) e
/// scandisce solo le foto più recenti per evitare di caricare l'intera
/// libreria di un utente con anni di scatti; con l'ordinamento per data
/// decrescente e l'eventuale filtro [after]/[before] resta comunque coerente
/// con l'uso reale (foto di un'escursione recente).
class PhotoManagerLibraryService extends PhotoLibraryService {
  const PhotoManagerLibraryService();

  static const int _maxAssetsScanned = 3000;

  @override
  Future<PhotoLibraryPermission> requestPermission() async {
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: true,
        ),
      ),
    );
    switch (state) {
      case PermissionState.authorized:
        return PhotoLibraryPermission.authorized;
      case PermissionState.limited:
        return PhotoLibraryPermission.limited;
      case PermissionState.denied:
      case PermissionState.notDetermined:
      case PermissionState.restricted:
        return PhotoLibraryPermission.denied;
    }
  }

  @override
  Future<List<RawPhotoLocation>> photoLocations({
    DateTime? after,
    DateTime? before,
  }) async {
    final filterOption = FilterOptionGroup(
      createTimeCond: DateTimeCond(
        min: after ?? DateTimeCond.zero,
        max: before ?? DateTime.now(),
      ),
      orders: const [OrderOption(type: OrderOptionType.createDate, asc: false)],
    );
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: filterOption,
    );
    if (paths.isEmpty) return const [];

    final root = paths.first;
    final count = await root.assetCountAsync;
    final end = count < _maxAssetsScanned ? count : _maxAssetsScanned;
    if (end == 0) return const [];
    final assets = await root.getAssetListRange(start: 0, end: end);

    final result = <RawPhotoLocation>[];
    for (final asset in assets) {
      final latLng = await asset.latlngAsync();
      if (latLng == null) continue;
      if (latLng.latitude == 0 && latLng.longitude == 0) continue;
      result.add(RawPhotoLocation(
        id: asset.id,
        position: ll.LatLng(latLng.latitude, latLng.longitude),
        takenAt: asset.createDateTime,
      ));
    }
    return result;
  }

  @override
  Future<Uint8List?> thumbnail(String assetId, {int size = 200}) async {
    final asset = await AssetEntity.fromId(assetId);
    return asset?.thumbnailDataWithSize(ThumbnailSize.square(size));
  }
}
