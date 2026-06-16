/// Decodifica delle tile Terrarium (terrain-RGB) per l'elevazione (§6.1).
///
/// Formato Mapzen/AWS: ogni pixel codifica la quota in metri secondo
/// `elevation = (R * 256 + G + B / 256) - 32768`.
abstract final class Terrarium {
  /// Decodifica un pixel RGB (canali 0–255) in quota in metri.
  static double decodeElevation(int r, int g, int b) {
    assert(r >= 0 && r <= 255, 'R fuori range');
    assert(g >= 0 && g <= 255, 'G fuori range');
    assert(b >= 0 && b <= 255, 'B fuori range');
    return (r * 256 + g + b / 256) - 32768;
  }
}
