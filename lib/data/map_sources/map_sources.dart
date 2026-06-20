/// Costanti delle sorgenti dati mappa.
///
/// La mappa visibile è gestita nativamente da Mapbox GL (stile Outdoors), quindi
/// qui resta solo il template per l'**elevazione** (non è un layer visibile).
abstract final class MapSources {
  /// Template Terrarium (terrain-RGB) per l'elevazione offline (§6.1).
  /// Decodifica: elevation = (R * 256 + G + B / 256) - 32768  [metri].
  static const String terrariumTemplate =
      'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png';
}
