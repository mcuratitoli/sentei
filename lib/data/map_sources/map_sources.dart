import 'map_source.dart';

/// Catalogo delle sorgenti cartografiche (§4 del CLAUDE.md).
///
/// Le URL e le licenze sono fissate nel documento di progetto. Rispettare
/// SEMPRE le fair-use policy: niente download massivo, attribuzione obbligatoria.
abstract final class MapSources {
  /// Access token Mapbox, iniettato a build time:
  /// `flutter run --dart-define=MAPBOX_TOKEN=pk.xxxx`. Mai committato (§9).
  static const String _mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

  /// Vero se è stato fornito un token Mapbox (abilita la sua sorgente).
  static bool get hasMapboxToken => _mapboxToken.isNotEmpty;

  /// Layer base disponibili, in ordine di presentazione nel selettore.
  /// Mapbox compare solo se è presente il token.
  static List<MapSource> get bases => <MapSource>[
        if (hasMapboxToken) mapboxOutdoors,
        openTopoMap,
      ];

  /// Overlay opzionali sovrapponibili al layer base.
  static const List<MapSource> overlays = <MapSource>[
    waymarkedTrailsHiking,
  ];

  /// Sorgente di default all'avvio.
  static const MapSource defaultBase = openTopoMap;

  // ---- Layer base ---------------------------------------------------------

  /// Mapbox Outdoors (stile topografico per escursionismo, look "alla Suunto":
  /// curve di livello, hillshading, sentieri). Tile **raster 512** servite via
  /// Styles API → `tileSize 512` + `zoomOffset -1`. Già curata: niente filtro
  /// muted. Richiede un access token Mapbox (free tier; per produzione
  /// commerciale verificare i ToS, §11).
  static const MapSource mapboxOutdoors = MapSource(
    id: 'mapbox_outdoors',
    name: 'Mapbox Outdoors',
    urlTemplate:
        'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/{z}/{x}/{y}@2x'
        '?access_token=$_mapboxToken',
    attribution: '© Mapbox · © OpenStreetMap',
    attributionUrl: 'https://www.mapbox.com/about/maps/',
    maxNativeZoom: 18,
    tileSize: 512,
    zoomOffset: -1,
    muteByDefault: false,
    note: 'Mapbox free tier. Token via --dart-define. ToS per uso commerciale.',
  );

  static const MapSource openTopoMap = MapSource(
    id: 'opentopomap',
    name: 'OpenTopoMap',
    urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    subdomains: <String>['a', 'b', 'c'],
    attribution: '© OpenTopoMap (CC-BY-SA) · © OpenStreetMap contributors',
    attributionUrl: 'https://opentopomap.org/about',
    maxNativeZoom: 17,
    note: 'CC-BY-SA. Attribuzione obbligatoria, fair use. Niente bulk download.',
  );

  /// Non è un layer selezionabile: tenuto solo per l'**attribuzione OSM** della
  /// rete sentieri vettoriale (dati Overpass/OSM).
  static const MapSource osmAttribution = MapSource(
    id: 'osm_attribution',
    name: 'OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap contributors',
    attributionUrl: 'https://www.openstreetmap.org/copyright',
  );

  // ---- Overlay ------------------------------------------------------------

  static const MapSource waymarkedTrailsHiking = MapSource(
    id: 'waymarkedtrails_hiking',
    name: 'Sentieri (Waymarked Trails)',
    urlTemplate: 'https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png',
    kind: MapSourceKind.overlay,
    attribution: '© Waymarked Trails (CC-BY-SA)',
    attributionUrl: 'https://hiking.waymarkedtrails.org/',
    maxNativeZoom: 18,
    note: 'Overlay percorsi escursionistici segnati.',
  );

  // ---- Elevazione (non è un layer visibile) -------------------------------

  /// Template Terrarium (terrain-RGB) per l'elevazione offline (§6.1).
  /// NON va aggiunto come layer visibile: serve a campionare la quota.
  /// Decodifica: elevation = (R * 256 + G + B / 256) - 32768  [metri].
  static const String terrariumTemplate =
      'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png';
}
