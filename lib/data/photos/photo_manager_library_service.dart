import 'dart:io' show File, Platform;
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

  /// Qualità JPEG della miniatura **salvata** nei metadati della traccia. Il
  /// default di `photo_manager` è 100, che su un 200×200 costa il doppio dei
  /// byte senza differenze visibili a quella dimensione — e quei byte, in
  /// base64 dentro il JSON, finiscono su iCloud/Drive ad ogni sync.
  static const int _thumbnailQuality = 80;

  /// Qualità JPEG dell'anteprima a schermo intero: alta, ma non 100 (gli
  /// ultimi punti di qualità sono quasi tutti byte in più).
  static const int _previewQuality = 90;

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
    return asset?.thumbnailDataWithSize(
      ThumbnailSize.square(size),
      quality: _thumbnailQuality,
    );
  }

  @override
  Future<Uint8List?> preview(
    String assetId, {
    required int maxWidth,
    required int maxHeight,
  }) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    // `thumbnailDataWithOption` e non `thumbnailDataWithSize`: quest'ultima su
    // iOS forza `ResizeContentMode.fill`, che **ritaglia** la foto per
    // riempire il riquadro richiesto — accettabile per una miniatura quadrata
    // mostrata con `BoxFit.cover`, sbagliato per la foto a schermo intero.
    // Con `fit` la libreria rimpicciolisce mantenendo le proporzioni. Su
    // Android non serve l'equivalente: Glide (`submit(w, h)`, nessuna
    // trasformazione) rimpicciolisce già senza ritagliare.
    final size = ThumbnailSize(maxWidth, maxHeight);
    final option = Platform.isIOS || Platform.isMacOS
        ? ThumbnailOption.ios(
            size: size,
            quality: _previewQuality,
            // L'anteprima resta sullo schermo finché l'utente non cambia
            // foto: `opportunistic` (default) consegnerebbe prima una
            // versione degradata, che si vedrebbe come un lampo sfocato a
            // ogni swipe.
            deliveryMode: DeliveryMode.highQualityFormat,
          )
        : ThumbnailOption(size: size, quality: _previewQuality);
    return asset.thumbnailDataWithOption(option);
  }

  @override
  Future<File?> originalFile(String assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    return asset?.file;
  }
}
