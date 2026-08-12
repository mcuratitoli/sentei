import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show SynchronousFuture;

import 'photo_library_service.dart';

/// Cache in memoria delle anteprime a schermo intero
/// ([PhotoLibraryService.preview]), con **precarico** delle foto adiacenti.
///
/// Serve il visualizzatore a schermo intero: senza, ogni pagina del carosello
/// richiede la sua anteprima da capo quando entra nell'albero — l'attesa si
/// vede a ogni swipe, e tornare indietro di una foto la ricarica come se non
/// fosse mai stata mostrata.
///
/// Volutamente **piccola**: un'anteprima a piena pagina decodificata occupa
/// diversi MB, quindi tenerne molte in memoria sposterebbe solo il problema.
/// [maxEntries] copre la foto corrente più le vicine precaricate.
///
/// La chiave è il **solo id dell'asset**: c'è una sola dimensione di anteprima
/// in circolazione (lo schermo). Se un giorno servissero due tagli diversi, la
/// chiave dovrà includere anche la dimensione.
class PhotoPreviewCache {
  PhotoPreviewCache(this._library, {this.maxEntries = 5});

  final PhotoLibraryService _library;
  final int maxEntries;

  // `Map` letterale = LinkedHashMap: l'ordine di inserimento è l'ordine di
  // sfratto (il più vecchio esce per primo), e un accesso reinserisce in coda.
  final Map<String, Uint8List> _entries = {};

  /// Richieste in volo, per id: due pagine che chiedono la stessa foto (es.
  /// precarico + apertura) devono condividere una sola richiesta alla libreria.
  final Map<String, Future<Uint8List?>> _inFlight = {};

  /// I byte già in cache, o `null` se non ci sono: permette alla UI di
  /// disegnare al primo frame, senza il tremolio di un `FutureBuilder` che
  /// parte sempre da "in caricamento".
  Uint8List? cached(String assetId) => _entries[assetId];

  /// L'anteprima di [assetId] rimpicciolita per stare in [width]×[height] px.
  /// Se è già in cache il future è già completo (nessun frame di attesa).
  Future<Uint8List?> preview(
    String assetId, {
    required int width,
    required int height,
  }) {
    final hit = _entries.remove(assetId);
    if (hit != null) {
      _entries[assetId] = hit; // torna in coda: è la più usata di recente
      return SynchronousFuture<Uint8List?>(hit);
    }
    final pending = _inFlight[assetId];
    if (pending != null) return pending;

    final request = _load(assetId, width: width, height: height);
    _inFlight[assetId] = request;
    return request;
  }

  Future<Uint8List?> _load(
    String assetId, {
    required int width,
    required int height,
  }) async {
    try {
      final bytes = await _library.preview(
        assetId,
        maxWidth: width,
        maxHeight: height,
      );
      if (bytes != null) _put(assetId, bytes);
      return bytes;
    } catch (_) {
      // Asset sparito o illeggibile: la UI ripiega sulla miniatura salvata.
      return null;
    } finally {
      _inFlight.remove(assetId);
    }
  }

  void _put(String assetId, Uint8List bytes) {
    _entries[assetId] = bytes;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Svuota la cache (uscita dal visualizzatore): le anteprime a piena pagina
  /// non servono a nessun'altra schermata e nel frattempo occupano memoria.
  void clear() => _entries.clear();
}
