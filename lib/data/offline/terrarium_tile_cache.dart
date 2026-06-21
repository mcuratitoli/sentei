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
/// e condivise tra le aree scaricate.
class TerrariumTileCache {
  Directory? _dir;

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/terrarium_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
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
  }

  /// Dimensione totale della cache in byte.
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
