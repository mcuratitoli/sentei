import '../models/photo_session.dart';
import '../models/track_photo.dart';

/// Raggruppa le foto collegate a una traccia in "escursioni" (§"Sync album
/// fotografico", `docs/eval-photo-sync.md`, domanda aperta #1): la traccia
/// non ha un concetto esplicito di "visita", quindi lo si deduce dai
/// timestamp EXIF delle foto — scatti vicini nel tempo sono probabilmente
/// della stessa uscita, scatti lontani mesi/anni sono uscite diverse sullo
/// stesso percorso.
///
/// Logica pura e deterministica, senza dipendenze da UI (§9 del CLAUDE.md).
class PhotoSessionGrouper {
  const PhotoSessionGrouper({this.maxGap = const Duration(hours: 30)});

  /// Gap massimo tra due scatti consecutivi (ordinati per data) perché siano
  /// considerati la stessa escursione. 30h invece di 24h per non spezzare
  /// in due gruppi un'uscita con pernottamento (bivacco/rifugio) solo perché
  /// attraversa la mezzanotte.
  final Duration maxGap;

  /// Raggruppa [photos] per escursione, più recente prima. Le foto senza
  /// `takenAt` (EXIF senza data) finiscono in un unico gruppo finale con
  /// `date: null`, invece di una per ciascuna — evita rumore quando manca
  /// il dato piuttosto che creare un gruppo "sconosciuto" per ogni foto.
  List<PhotoSession> group(List<TrackPhoto> photos) {
    final dated = photos.where((p) => p.takenAt != null).toList()
      ..sort((a, b) => a.takenAt!.compareTo(b.takenAt!));
    final undated = photos.where((p) => p.takenAt == null).toList();

    final sessions = <PhotoSession>[];
    var current = <TrackPhoto>[];
    for (final photo in dated) {
      if (current.isNotEmpty &&
          photo.takenAt!.difference(current.last.takenAt!) > maxGap) {
        sessions
            .add(PhotoSession(photos: current, date: current.first.takenAt));
        current = [];
      }
      current.add(photo);
    }
    if (current.isNotEmpty) {
      sessions.add(PhotoSession(photos: current, date: current.first.takenAt));
    }

    sessions.sort((a, b) => b.date!.compareTo(a.date!));

    if (undated.isNotEmpty) {
      sessions.add(PhotoSession(photos: undated, date: null));
    }
    return sessions;
  }
}
