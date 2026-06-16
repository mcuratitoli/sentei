import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Posizione di una coordinata dentro lo schema tile Web Mercator (slippy map):
/// indice tile [tileX]/[tileY] al livello [zoom] + offset del pixel [pixelX]/[pixelY]
/// all'interno della tile.
class TilePixel {
  const TilePixel({
    required this.zoom,
    required this.tileX,
    required this.tileY,
    required this.pixelX,
    required this.pixelY,
  });

  final int zoom;
  final int tileX;
  final int tileY;
  final int pixelX;
  final int pixelY;

  @override
  String toString() =>
      'TilePixel(z:$zoom, tile:$tileX/$tileY, px:$pixelX/$pixelY)';
}

/// Utility di conversione coordinate ↔ tile (EPSG:3857), usate per campionare
/// il DEM Terrarium alla posizione esatta (§6.1).
abstract final class TileMath {
  static const int tileSize = 256;

  /// Converte [point] nella tile/pixel al livello [zoom].
  ///
  /// Valido per latitudini nel range Web Mercator (~±85.05°); oltre, la tile
  /// viene comunque clampata agli estremi validi.
  static TilePixel locate(LatLng point, int zoom, {int tileSize = tileSize}) {
    assert(zoom >= 0, 'zoom non può essere negativo');
    final n = 1 << zoom; // 2^zoom
    final latRad = point.latitude * math.pi / 180.0;

    final xNorm = (point.longitude + 180.0) / 360.0;
    final yNorm = (1 -
            math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
        2;

    final xWorld = xNorm * n;
    final yWorld = yNorm * n;

    final tileX = xWorld.floor().clamp(0, n - 1);
    final tileY = yWorld.floor().clamp(0, n - 1);

    final pixelX =
        ((xWorld - tileX) * tileSize).floor().clamp(0, tileSize - 1);
    final pixelY =
        ((yWorld - tileY) * tileSize).floor().clamp(0, tileSize - 1);

    return TilePixel(
      zoom: zoom,
      tileX: tileX,
      tileY: tileY,
      pixelX: pixelX,
      pixelY: pixelY,
    );
  }
}
