import 'map_source.dart';

/// Catalogo delle sorgenti cartografiche (§4 del CLAUDE.md).
///
/// Le URL e le licenze sono fissate nel documento di progetto. Rispettare
/// SEMPRE le fair-use policy: niente download massivo, attribuzione obbligatoria.
abstract final class MapSources {
  /// API key Stadia Maps, iniettata a build time:
  /// `flutter run --dart-define=STADIA_API_KEY=xxxx`. Mai committata (§9).
  static const String _stadiaKey = String.fromEnvironment('STADIA_API_KEY');

  /// Vero se è stata fornita una API key Stadia (abilita le sue sorgenti).
  static bool get hasStadiaKey => _stadiaKey.isNotEmpty;

  /// Layer base disponibili, in ordine di presentazione nel selettore.
  /// La sorgente Stadia compare solo se è presente la API key.
  static List<MapSource> get bases => <MapSource>[
        if (hasStadiaKey) stamenTerrain,
        openTopoMap,
        swissTopo,
        ignPlan,
        osmStandard,
      ];

  /// Overlay opzionali sovrapponibili al layer base.
  static const List<MapSource> overlays = <MapSource>[
    waymarkedTrailsHiking,
  ];

  /// Sorgente di default all'avvio.
  static const MapSource defaultBase = openTopoMap;

  // ---- Layer base ---------------------------------------------------------

  /// Stamen Terrain (servito da Stadia Maps) — base tenue e morbida, look
  /// ispirato a GaiaGPS. Già poco satura: niente filtro muted ([muteByDefault]
  /// false). Richiede la API key Stadia (free tier per uso non commerciale).
  static const MapSource stamenTerrain = MapSource(
    id: 'stadia_stamen_terrain',
    name: 'Terrain (Gaia-like)',
    urlTemplate:
        'https://tiles.stadiamaps.com/tiles/stamen_terrain/{z}/{x}/{y}.png'
        '?api_key=$_stadiaKey',
    attribution:
        '© Stadia Maps · © Stamen Design · © OpenMapTiles · © OpenStreetMap',
    attributionUrl: 'https://stadiamaps.com/attribution/',
    maxNativeZoom: 18,
    muteByDefault: false,
    note: 'Stadia free tier (non commerciale). API key via --dart-define.',
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

  static const MapSource swissTopo = MapSource(
    id: 'swisstopo_pixelkarte',
    name: 'SwissTopo (CH)',
    urlTemplate:
        'https://wmts.geo.admin.ch/1.0.0/ch.swisstopo.pixelkarte-farbe/default/current/3857/{z}/{x}/{y}.jpeg',
    attribution: '© swisstopo',
    attributionUrl: 'https://www.geo.admin.ch/terms-of-use',
    maxNativeZoom: 18,
    note: 'Gratuito per uso non commerciale, vincoli geo.admin.ch.',
  );

  static const MapSource ignPlan = MapSource(
    id: 'ign_planv2',
    name: 'IGN Plan (FR)',
    urlTemplate:
        'https://data.geopf.fr/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0'
        '&LAYER=GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2&STYLE=normal&TILEMATRIXSET=PM'
        '&FORMAT=image/png&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}',
    attribution: '© IGN/Géoplateforme',
    attributionUrl: 'https://geoservices.ign.fr/',
    maxNativeZoom: 18,
    note: 'Géoplateforme open. SCAN 25 ha condizioni più restrittive — vedi §10.',
  );

  static const MapSource osmStandard = MapSource(
    id: 'osm_standard',
    name: 'OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap contributors',
    attributionUrl: 'https://www.openstreetmap.org/copyright',
    maxNativeZoom: 19,
    note: 'Usage policy restrittiva: SOLO base/fallback, mai download di massa.',
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
