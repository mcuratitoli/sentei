import 'dart:typed_data' show Uint8List;

import 'package:latlong2/latlong.dart';

/// Foto collegata a una traccia (§"Sync album fotografico", `docs/eval-photo-sync.md`).
///
/// **Niente id di libreria foto** (`PHAsset.localIdentifier`/MediaStore id):
/// non è portabile tra dispositivi. Si salvano invece i **metadati** della
/// foto (posizione GPS, timestamp EXIF, distanza-lungo-percorso già calcolata)
/// più un **thumbnail piccolo** — tutto ciò che serve per mostrare il pin
/// ovunque la traccia sincronizzi. L'originale resta **sempre e solo** nella
/// libreria foto del dispositivo: si ritrova con un **re-match locale**
/// (posizione+orario) al momento di aprirlo, non con un puntatore diretto.
class TrackPhoto {
  const TrackPhoto({
    required this.id,
    required this.position,
    required this.distanceMeters,
    this.takenAt,
    this.thumbnail,
    this.title,
  });

  /// Identificativo della voce (per rimuovere/aggiornare il collegamento).
  /// Coincide oggi con l'id nella libreria foto del dispositivo — non
  /// portabile tra device, ma sufficiente per riaprire l'originale **sullo
  /// stesso** dispositivo che l'ha collegata (vedi `openFullPhoto`); su un
  /// altro device (sincronizzato via cloud) l'id semplicemente non risolve.
  final String id;

  /// Posizione GPS della foto, dall'EXIF.
  final LatLng position;

  /// Distanza cumulata lungo il percorso (metri) nel punto più vicino a
  /// [position] — usata per piazzare il pin sul profilo altimetrico
  /// (`PathGeometry.nearestOnPath`). Non richiede alcun dato temporale sulla
  /// traccia.
  final double distanceMeters;

  /// Data/ora di scatto (EXIF `DateTimeOriginal`), se disponibile. Usata come
  /// filtro secondario in fase di ricerca e per il re-match su altri device.
  final DateTime? takenAt;

  /// Anteprima piccola (poche KB), sincronizzata **insieme ai metadati**: così
  /// resta visibile anche su un dispositivo dove l'originale non si ritrova.
  final Uint8List? thumbnail;

  /// Titolo impostabile dall'utente. `null`/vuoto → l'interfaccia mostra la
  /// data/ora di scatto come titolo di default (nessun valore forzato qui).
  final String? title;

  TrackPhoto copyWith({
    String? id,
    LatLng? position,
    double? distanceMeters,
    DateTime? takenAt,
    Uint8List? thumbnail,
    String? title,
  }) =>
      TrackPhoto(
        id: id ?? this.id,
        position: position ?? this.position,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        takenAt: takenAt ?? this.takenAt,
        thumbnail: thumbnail ?? this.thumbnail,
        title: title ?? this.title,
      );
}
