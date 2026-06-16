import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

import '../../core/util/tile_math.dart';
import '../../domain/services/elevation_service.dart';
import 'terrarium.dart';

/// Recupera i byte (PNG) di una tile Terrarium per indice z/x/y, oppure `null`
/// se non disponibile (rete assente / fuori copertura).
///
/// Iniettabile: in test si passa un fetcher finto; in Fase 1.F qui si aggancia
/// la cache offline FMTC.
typedef TerrariumTileFetcher = Future<Uint8List?> Function(int z, int x, int y);

/// Implementazione di [ElevationService] basata sul DEM Terrarium (§6.1).
///
/// Campiona la quota leggendo il pixel corrispondente alla coordinata nella
/// tile decodificata. Mantiene una cache LRU in memoria delle tile decodificate
/// per non riscaricarle quando più punti vicini cadono nella stessa tile.
class TerrariumElevationService implements ElevationService {
  TerrariumElevationService({
    required TerrariumTileFetcher fetchTile,
    this.zoom = 13,
    int maxCachedTiles = 16,
  })  : _fetchTile = fetchTile,
        _maxCachedTiles = maxCachedTiles;

  final TerrariumTileFetcher _fetchTile;

  /// Livello di zoom usato per il campionamento. z13 ≈ 13–19 m/pixel alle
  /// latitudini alpine: buon compromesso copertura/precisione per il D+.
  final int zoom;

  final int _maxCachedTiles;
  final Map<String, img.Image?> _cache = <String, img.Image?>{};

  @override
  Future<double?> elevationAt(LatLng point) async {
    final loc = TileMath.locate(point, zoom);
    final tile = await _tile(loc.tileX, loc.tileY);
    if (tile == null) return null;
    return _sample(tile, loc.pixelX, loc.pixelY);
  }

  @override
  Future<List<double?>> elevationsAlong(List<LatLng> points) async {
    final result = <double?>[];
    for (final p in points) {
      result.add(await elevationAt(p));
    }
    return result;
  }

  double? _sample(img.Image tile, int px, int py) {
    final pixel = tile.getPixel(px, py);
    return Terrarium.decodeElevation(
      pixel.r.toInt(),
      pixel.g.toInt(),
      pixel.b.toInt(),
    );
  }

  Future<img.Image?> _tile(int x, int y) async {
    final key = '$zoom/$x/$y';
    if (_cache.containsKey(key)) {
      // tocca la chiave per la politica LRU
      final cached = _cache.remove(key);
      _cache[key] = cached;
      return cached;
    }

    final bytes = await _fetchTile(zoom, x, y);
    final decoded = bytes == null ? null : img.decodePng(bytes);
    _put(key, decoded);
    return decoded;
  }

  void _put(String key, img.Image? value) {
    _cache[key] = value;
    if (_cache.length > _maxCachedTiles) {
      _cache.remove(_cache.keys.first); // rimuove la entry più vecchia
    }
  }
}
