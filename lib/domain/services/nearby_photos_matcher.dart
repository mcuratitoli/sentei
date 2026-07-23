import 'package:latlong2/latlong.dart';

import '../models/photo_candidate.dart';
import 'path_geometry.dart';

/// Filtra e ordina le foto della libreria per vicinanza a un percorso
/// (§"Sync album fotografico", `docs/eval-photo-sync.md`).
///
/// Logica pura e deterministica, senza dipendenze da `photo_manager` o da UI:
/// riceve le posizioni già lette dalla libreria ([RawPhotoLocation]) e usa
/// [PathGeometry.nearestOnPath] (stessa proiezione locale già impiegata per
/// lo snapping del disegno) per calcolare la distanza dal percorso e la
/// distanza-lungo-percorso di ciascuna foto.
class NearbyPhotosMatcher {
  const NearbyPhotosMatcher({this.geometry = const PathGeometry()});

  final PathGeometry geometry;

  /// Soglia di default (m) oltre la quale una foto non è considerata
  /// "vicina" al percorso (proposta iniziale in `docs/eval-photo-sync.md`,
  /// a metà tra 60 e 100 m).
  static const double defaultThresholdMeters = 80;

  /// Ritorna le foto entro [thresholdMeters] dal percorso, ordinate per
  /// vicinanza crescente. Percorsi vuoti o con un solo punto → nessun match
  /// (non esiste un tratto a cui essere "vicini").
  List<PhotoCandidate> match({
    required List<LatLng> routedPath,
    required List<RawPhotoLocation> photos,
    double thresholdMeters = defaultThresholdMeters,
  }) {
    if (routedPath.length < 2 || photos.isEmpty) return const [];

    final candidates = <PhotoCandidate>[];
    for (final photo in photos) {
      final nearest = geometry.nearestOnPath(photo.position, routedPath);
      if (nearest.distanceToPath <= thresholdMeters) {
        candidates.add(PhotoCandidate(
          id: photo.id,
          position: photo.position,
          takenAt: photo.takenAt,
          distanceToPathMeters: nearest.distanceToPath,
          distanceAlongPathMeters: nearest.distanceAlongPath,
        ));
      }
    }
    candidates.sort(
        (a, b) => a.distanceToPathMeters.compareTo(b.distanceToPathMeters));
    return candidates;
  }
}
