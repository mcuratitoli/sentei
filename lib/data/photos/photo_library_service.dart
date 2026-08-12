import 'dart:io' show File;
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
  ///
  /// È la miniatura **salvata nei metadati della traccia** (base64 nel JSON
  /// sincronizzato sul cloud): tenerla piccola: 200 px coprono con margine il
  /// riquadro più grande in cui viene mostrata (64 pt = 192 px a 3×).
  Future<Uint8List?> thumbnail(String assetId, {int size = 200});

  /// Anteprima JPEG di [assetId] rimpicciolita per stare in
  /// [maxWidth]×[maxHeight] **pixel**, proporzioni invariate.
  ///
  /// Per mostrare una foto a schermo intero: chiedere alla libreria di
  /// ridimensionare costa una frazione del caricare l'originale (12 MP →
  /// ~48 MB di bitmap decodificata) per poi rimpicciolirlo a schermo. Non
  /// sostituisce [originalFile], che serve solo quando l'utente zooma.
  Future<Uint8List?> preview(
    String assetId, {
    required int maxWidth,
    required int maxHeight,
  });

  /// Il file della foto originale, a piena risoluzione, o `null` se l'asset
  /// non è più sul dispositivo. **Caro**: usarlo solo su richiesta esplicita
  /// dell'utente (zoom), mai per il primo disegno di una schermata.
  Future<File?> originalFile(String assetId);
}
