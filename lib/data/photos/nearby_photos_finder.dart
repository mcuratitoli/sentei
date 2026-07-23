import 'dart:typed_data' show Uint8List;

import 'package:latlong2/latlong.dart';

import '../../domain/models/photo_candidate.dart';
import '../../domain/models/track_photo.dart';
import '../../domain/services/nearby_photos_matcher.dart';
import 'photo_library_service.dart';

/// Esito di [NearbyPhotosFinder.findNearby]: le foto trovate più lo stato del
/// permesso, così la UI distingue "nessuna foto vicina" da "permesso negato".
class NearbyPhotosResult {
  const NearbyPhotosResult({
    required this.permission,
    this.photos = const [],
  });

  final PhotoLibraryPermission permission;
  final List<TrackPhoto> photos;
}

/// Orchestratore della ricerca "foto vicine al percorso" (§"Sync album
/// fotografico", `docs/eval-photo-sync.md`): richiede il permesso, legge le
/// posizioni dalla libreria del dispositivo ([PhotoLibraryService]), le
/// filtra/ordina per vicinanza al percorso ([NearbyPhotosMatcher]) e carica il
/// thumbnail **solo** delle candidate risultanti (non dell'intera libreria).
///
/// Azione manuale, innescata dall'utente ("Trova foto" sulla card traccia,
/// non automatica dopo ogni salvataggio — vedi decisione nel doc).
class NearbyPhotosFinder {
  const NearbyPhotosFinder(
    this._library, {
    this.matcher = const NearbyPhotosMatcher(),
  });

  final PhotoLibraryService _library;
  final NearbyPhotosMatcher matcher;

  Future<NearbyPhotosResult> findNearby({
    required List<LatLng> routedPath,
    DateTime? after,
    DateTime? before,
    double thresholdMeters = NearbyPhotosMatcher.defaultThresholdMeters,
    int thumbnailSize = 200,
  }) async {
    final permission = await _library.requestPermission();
    if (permission == PhotoLibraryPermission.denied) {
      return NearbyPhotosResult(permission: permission);
    }

    final raw = await _library.photoLocations(after: after, before: before);
    final candidates = matcher.match(
      routedPath: routedPath,
      photos: raw,
      thresholdMeters: thresholdMeters,
    );

    final photos = <TrackPhoto>[];
    for (final candidate in candidates) {
      final thumbnail =
          await _library.thumbnail(candidate.id, size: thumbnailSize);
      photos.add(_toTrackPhoto(candidate, thumbnail: thumbnail));
    }
    return NearbyPhotosResult(permission: permission, photos: photos);
  }

  TrackPhoto _toTrackPhoto(PhotoCandidate candidate,
          {required Uint8List? thumbnail}) =>
      TrackPhoto(
        id: candidate.id,
        position: candidate.position,
        distanceMeters: candidate.distanceAlongPathMeters,
        takenAt: candidate.takenAt,
        thumbnail: thumbnail,
      );
}
