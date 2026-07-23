import 'package:latlong2/latlong.dart';

/// Foto della libreria del dispositivo, con posizione GPS nota, prima ancora
/// di sapere se è vicina a un percorso. Fonte-agnostica: chi la produce (oggi
/// `photo_manager`) non deve trapelare nel dominio (§"Sync album fotografico",
/// `docs/eval-photo-sync.md`).
class RawPhotoLocation {
  const RawPhotoLocation({
    required this.id,
    required this.position,
    this.takenAt,
  });

  /// Identificativo locale nella libreria foto del dispositivo (non portabile
  /// tra device — usato solo per recuperare il thumbnail e per deduplicare in
  /// caso di ricerche ripetute, mai per il re-match cross-device).
  final String id;

  final LatLng position;

  /// Data/ora di scatto (EXIF), se disponibile.
  final DateTime? takenAt;
}

/// Foto risultata vicina a un percorso dopo [NearbyPhotosMatcher.match]: come
/// [RawPhotoLocation], con in più la distanza dal percorso e la distanza
/// cumulata lungo il percorso nel punto più vicino (per il pin sul profilo).
class PhotoCandidate {
  const PhotoCandidate({
    required this.id,
    required this.position,
    required this.takenAt,
    required this.distanceToPathMeters,
    required this.distanceAlongPathMeters,
  });

  final String id;
  final LatLng position;
  final DateTime? takenAt;
  final double distanceToPathMeters;
  final double distanceAlongPathMeters;
}
