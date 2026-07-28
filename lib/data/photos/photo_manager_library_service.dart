import 'dart:typed_data' show Uint8List;

import 'package:latlong2/latlong.dart' as ll;
import 'package:photo_manager/photo_manager.dart';

import '../../domain/models/photo_candidate.dart';
import 'photo_library_service.dart';

/// Implementazione di [PhotoLibraryService] su `photo_manager`
/// (§"Sync album fotografico", `docs/eval-photo-sync.md`).
///
/// Scandisce **l'intera libreria** (nessun tetto sul numero di asset): la
/// ricerca è avviata manualmente dall'utente ("Trova foto" sulla card, non
/// automatica — vedi decisione nel doc), quindi il costo è accettabile anche
/// per librerie grandi. Legge in blocchi di [_batchSize] con le richieste
/// `latlngAsync` di ogni blocco in parallelo, per non caricare tutto in
/// memoria né bloccare l'esecuzione su un singolo asset lento.
class PhotoManagerLibraryService extends PhotoLibraryService {
  const PhotoManagerLibraryService();

  static const int _batchSize = 500;

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
    if (count == 0) return const [];

    final result = <RawPhotoLocation>[];
    for (var start = 0; start < count; start += _batchSize) {
      final end = (start + _batchSize < count) ? start + _batchSize : count;
      final assets = await root.getAssetListRange(start: start, end: end);
      final located = await Future.wait(assets.map(_toLocationOrNull));
      result.addAll(located.whereType<RawPhotoLocation>());
    }
    return result;
  }

  /// `null` se l'asset non ha coordinate GPS valide nell'EXIF (nessuna
  /// posizione, o `(0, 0)` — valore placeholder di molte fotocamere quando il
  /// permesso di localizzazione era disattivato allo scatto).
  Future<RawPhotoLocation?> _toLocationOrNull(AssetEntity asset) async {
    final latLng = await asset.latlngAsync();
    if (latLng == null) return null;
    if (latLng.latitude == 0 && latLng.longitude == 0) return null;
    return RawPhotoLocation(
      id: asset.id,
      position: ll.LatLng(latLng.latitude, latLng.longitude),
      takenAt: asset.createDateTime,
    );
  }

  @override
  Future<Uint8List?> thumbnail(String assetId, {int size = 200}) async {
    final asset = await AssetEntity.fromId(assetId);
    return asset?.thumbnailDataWithSize(ThumbnailSize.square(size));
  }
}
