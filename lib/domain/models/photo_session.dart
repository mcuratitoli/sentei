import 'track_photo.dart';

/// Un gruppo di foto della traccia raggruppate per "escursione" da
/// [PhotoSessionGrouper] (§"Sync album fotografico", `docs/eval-photo-sync.md`,
/// domanda aperta #1).
class PhotoSession {
  const PhotoSession({required this.photos, this.date});

  /// Foto del gruppo, in ordine di scatto (o di collegamento se senza data).
  final List<TrackPhoto> photos;

  /// Data rappresentativa del gruppo (lo scatto più vecchio con `takenAt`
  /// noto). `null` se nessuna foto del gruppo ha una data nota.
  final DateTime? date;
}
