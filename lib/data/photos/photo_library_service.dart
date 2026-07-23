import 'dart:typed_data' show Uint8List;

import '../../domain/models/photo_candidate.dart';

/// Stato del permesso alla libreria foto del dispositivo, normalizzato tra le
/// piattaforme (il `PermissionState` di `photo_manager` distingue già così).
enum PhotoLibraryPermission {
  /// Accesso completo alla libreria.
  authorized,

  /// Accesso solo a una selezione di foto (iOS "Selected Photos" / Android 14+
  /// "seleziona foto"): la ricerca funziona solo sulle foto incluse.
  limited,

  /// Nessun accesso.
  denied,
}

/// Accesso in sola lettura alla libreria foto del dispositivo, dietro
/// un'interfaccia che non trapela il pacchetto usato (`photo_manager`) nel
/// resto del codice (§"Sync album fotografico", `docs/eval-photo-sync.md`).
abstract class PhotoLibraryService {
  const PhotoLibraryService();

  /// Richiede il permesso (mostra il dialogo di sistema se non già concesso).
  Future<PhotoLibraryPermission> requestPermission();

  /// Foto con posizione GPS nota, più recenti prima. [after]/[before]
  /// filtrano per data di scatto quando forniti (segnale secondario per
  /// restringere la ricerca — vedi domande aperte in
  /// `docs/eval-photo-sync.md`); `null` = nessun filtro su quel lato.
  /// Foto senza posizione GPS nell'EXIF vengono scartate a monte.
  Future<List<RawPhotoLocation>> photoLocations({
    DateTime? after,
    DateTime? before,
  });

  /// Anteprima JPEG di [assetId] già ridimensionata a [size]×[size] px, o
  /// `null` se l'asset non è più raggiungibile (rimosso dalla libreria).
  Future<Uint8List?> thumbnail(String assetId, {int size = 200});
}
