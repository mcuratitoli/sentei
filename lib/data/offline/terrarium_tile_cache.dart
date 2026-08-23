import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/util/tile_math.dart';
import '../map_sources/map_sources.dart';
import 'terrarium_elevation_service.dart';

/// Cache **su disco** delle tile Terrarium (terrain-RGB), per il calcolo di
/// dislivello/profilo **offline**. Globale (non per-area): le tile sono piccole
/// e condivise tra le aree scaricate — ma anche fra **ogni** traccia mai
/// vista (disegnata, salvata, importata), non solo le aree scaricate
/// esplicitamente: ogni calcolo di dislivello passa da qui.
///
/// **`Library/Caches`, non `Documents`** (24 ago 2026, bug scoperto su
/// device fisico — "l'app pesa centinaia di mega"): dati rigenerabili come
/// questi non vanno in `Documents` (incluso nel backup iCloud, mai ripulito
/// dal sistema); `getApplicationCacheDirectory()` mappa su `Library/Caches`
/// su iOS, escluso dal backup e purgabile dall'OS sotto pressione di spazio.
/// **Tetto** [maxBytes] con eviction LRU (per data di modifica, non c'è un
/// registro degli accessi): senza, la cache cresce all'infinito con l'uso —
/// era esattamente la causa del bug. 200 MB copre comodamente l'intero arco
/// alpino testato in una sessione di lavoro senza reinventare un vincolo
/// stretto.
class TerrariumTileCache {
  static const int maxBytes = 200 * 1024 * 1024;

  /// Soglia di rientro dopo un'eviction: si scende sotto l'80% del tetto,
  /// non esattamente al 100%, per non dover rifare la scansione della
  /// cartella ad ogni singola scrittura successiva.
  static const int _evictTargetBytes = maxBytes * 4 ~/ 5;

  Directory? _dir;
  int? _approxBytes;
  bool _migrated = false;

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final cacheRoot = await getApplicationCacheDirectory();
    final dir = Directory('${cacheRoot.path}/terrarium_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    if (!_migrated) {
      _migrated = true;
      unawaited(_deleteStaleDocumentsCache());
    }
    return dir;
  }

  /// Pulizia una tantum della vecchia cache in `Documents` (versioni fino a
  /// `1.0.0+8`): senza, resterebbe orfana per sempre sul device di chi ha
  /// già usato l'app, vanificando il fix per chi ne avrebbe più bisogno.
  Future<void> _deleteStaleDocumentsCache() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final stale = Directory('${docs.path}/terrarium_cache');
      if (await stale.exists()) await stale.delete(recursive: true);
    } catch (_) {
      // Best-effort: non deve impedire l'uso della cache nuova.
    }
  }

  Future<File> _file(int z, int x, int y) async {
    final dir = await _ensureDir();
    return File('${dir.path}/${z}_${x}_$y.png');
  }

  Future<Uint8List?> read(int z, int x, int y) async {
    final f = await _file(z, x, y);
    if (await f.exists()) return f.readAsBytes();
    return null;
  }

  Future<void> write(int z, int x, int y, Uint8List bytes) async {
    final f = await _file(z, x, y);
    await f.writeAsBytes(bytes, flush: false);
    _approxBytes = (_approxBytes ?? await sizeBytes()) + bytes.length;
    if (_approxBytes! > maxBytes) {
      unawaited(_evict());
    }
  }

  Future<void> _evict() async {
    final dir = await _ensureDir();
    final files = <File>[];
    await for (final e in dir.list()) {
      if (e is File) files.add(e);
    }
    final withStat = await Future.wait(files.map((f) async {
      final stat = await f.stat();
      return (file: f, modified: stat.modified, size: stat.size);
    }));
    // Più vecchie (per data di modifica) prima: sono le prime candidate a
    // sparire, come un LRU senza dover tenere un registro degli accessi.
    withStat.sort((a, b) => a.modified.compareTo(b.modified));
    var total = withStat.fold<int>(0, (sum, f) => sum + f.size);
    for (final f in withStat) {
      if (total <= _evictTargetBytes) break;
      try {
        await f.file.delete();
        total -= f.size;
      } catch (_) {
        // File già sparito/non cancellabile: salta, la prossima eviction
        // riprova.
      }
    }
    _approxBytes = total;
  }

  /// Dimensione totale della cache in byte (scansione fresca, per la UI).
  Future<int> sizeBytes() async {
    final dir = await _ensureDir();
    var total = 0;
    await for (final e in dir.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  Future<void> clear() async {
    final dir = await _ensureDir();
    if (await dir.exists()) await dir.delete(recursive: true);
    _dir = null;
    _approxBytes = 0;
  }
}

/// Fetcher Terrarium con cache su disco: legge dalla cache, altrimenti scarica
/// via HTTP e salva. Usato dal calcolo elevazione (funziona offline se l'area
/// è stata scaricata).
TerrariumTileFetcher cachingTerrariumFetcher({
  required TerrariumTileCache cache,
  http.Client? client,
}) {
  final c = client ?? http.Client();
  return (int z, int x, int y) async {
    final cached = await cache.read(z, x, y);
    if (cached != null) return cached;
    final url = MapSources.terrariumTemplate
        .replaceFirst('{z}', '$z')
        .replaceFirst('{x}', '$x')
        .replaceFirst('{y}', '$y');
    try {
      final res = await c.get(Uri.parse(url));
      if (res.statusCode != 200) return null;
      final bytes = Uint8List.fromList(res.bodyBytes);
      await cache.write(z, x, y, bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  };
}

/// Scarica nella [cache] tutte le tile Terrarium che coprono il bounding box
/// al livello [zoom] (default z13, come l'elevazione). Progresso 0..1.
Future<void> downloadTerrariumArea({
  required TerrariumTileCache cache,
  required double south,
  required double west,
  required double north,
  required double east,
  int zoom = 13,
  http.Client? client,
  void Function(double progress)? onProgress,
}) async {
  final c = client ?? http.Client();
  final tl = TileMath.locate(LatLng(north, west), zoom);
  final br = TileMath.locate(LatLng(south, east), zoom);
  final x0 = math.min(tl.tileX, br.tileX);
  final x1 = math.max(tl.tileX, br.tileX);
  final y0 = math.min(tl.tileY, br.tileY);
  final y1 = math.max(tl.tileY, br.tileY);
  final total = (x1 - x0 + 1) * (y1 - y0 + 1);
  var done = 0;
  for (var x = x0; x <= x1; x++) {
    for (var y = y0; y <= y1; y++) {
      if (await cache.read(zoom, x, y) == null) {
        final url = MapSources.terrariumTemplate
            .replaceFirst('{z}', '$zoom')
            .replaceFirst('{x}', '$x')
            .replaceFirst('{y}', '$y');
        try {
          final res = await c.get(Uri.parse(url));
          if (res.statusCode == 200) {
            await cache.write(zoom, x, y, Uint8List.fromList(res.bodyBytes));
          }
        } catch (_) {
          // best-effort: salta la tile non scaricata
        }
      }
      done++;
      onProgress?.call(total == 0 ? 1 : done / total);
    }
  }
}
