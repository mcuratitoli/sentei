import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoButton, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../core/constants.dart';
import '../../core/util/format.dart';
import '../../data/location/location_service.dart';
import '../../data/search/geocoding_service.dart';
import '../../domain/services/path_geometry.dart';
import '../../domain/services/steepness.dart';
import '../../ui/glass.dart';
import '../../ui/ios_toast.dart';
import '../draw_route/draw_route_controls.dart';
import '../draw_route/route_editor_provider.dart';
import '../map/map_providers.dart';
import '../offline_maps/offline_maps_providers.dart';
import '../settings/settings_screen.dart';
import 'inspected_point_provider.dart';
import '../tracks_list/tracks_list_screen.dart';

/// Stile della mappa. Default: Mapbox **Outdoors** (topo stock migliore).
/// Sovrascrivibile con uno stile Mapbox Studio dedicato (simil-GaiaGPS) senza
/// toccare il codice: `--dart-define=MAP_STYLE_URI=mapbox://styles/<user>/<id>`.
const String _envMapStyle = String.fromEnvironment('MAP_STYLE_URI');

/// Stile "mappa" (topografico). L'override d'ambiente vince se presente.
String get _outdoorsStyleUri =>
    _envMapStyle.isEmpty ? MapboxStyles.OUTDOORS : _envMapStyle;

/// Stile **satellite** con strade/etichette (utile in escursione: si vedono
/// nomi e sentieri sopra l'ortofoto).
const String _satelliteStyleUri =
    'mapbox://styles/mapbox/satellite-streets-v12';

/// Vista mappa selezionabile dal tasto "livelli" nella barra.
enum MapStyleChoice { outdoors, satellite }

/// Mappa principale su **Mapbox GL** (migrazione, Fase 4): base Outdoors +
/// terreno 3D, numeri CAI, posizione utente, e **disegno multi-traccia**
/// collegato a `Tracks` (Riverpod) — tap=aggiungi, drag=sposta, tap-nodo=
/// elimina, snap-to-trail live; tap fuori = seleziona/deseleziona.
class MapGlScreen extends ConsumerStatefulWidget {
  const MapGlScreen({super.key});

  static const String routeName = 'map';
  static const String routePath = '/';

  @override
  ConsumerState<MapGlScreen> createState() => _MapGlScreenState();
}

class _MapGlScreenState extends ConsumerState<MapGlScreen> {
  MapboxMap? _map;

  // Manager annotation: tracce salvate (linee+estremi), waypoint in modifica,
  // percorso live in modifica.
  PolylineAnnotationManager? _savedLines;
  CircleAnnotationManager? _savedEnds;
  CircleAnnotationManager? _waypointDots;
  CircleAnnotationManager? _cursorDot;
  CircleAnnotationManager? _inspectedDot;
  PolylineAnnotationManager? _liveLine;

  /// id-cerchio→indice waypoint della traccia in modifica.
  final Map<String, int> _wpIndexById = <String, int>{};

  bool _initialCameraDone = false;
  // Splash "esteso": copre la mappa finché la camera iniziale non è posizionata
  // (GPS o fallback), così l'utente non vede il salto default→traccia→posizione.
  bool _splashVisible = true;
  bool _rendering = false;
  bool _renderAgain = false;
  bool _is3D = false;
  bool _ornamentsConfigured = false;
  // Vista mappa corrente. Lo stile iniziale del MapWidget è fisso (Outdoors);
  // il cambio vista avviene in modo imperativo con `map.loadStyleURI`, così il
  // prop del widget non cambia e non innesca ricariche doppie.
  MapStyleChoice _styleChoice = MapStyleChoice.outdoors;
  // La parte "one-shot" del setup (centratura iniziale) va fatta solo alla
  // prima apertura, non a ogni cambio stile.
  bool _postSetupOnce = false;
  // Dopo un cambio stile, ri-applica il terreno 3D al primo idle: subito dopo
  // il load il mesh del DEM può non essere pronto e la prima inclinazione
  // resterebbe "piatta".
  bool _needTerrainReassert = false;
  // Orientamento corrente della camera (per la bussola custom e il toggle 2D/3D).
  double _bearing = 0;
  double _pitch = 0;

  // Ricerca luoghi (apribile dalla lente nella barra in basso).
  bool _searchOpen = false;
  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  List<GeocodeResult> _searchResults = const [];

  // Cache area numeri sentiero già scaricata (gradi).
  double? _tS, _tW, _tN, _tE;

  // onStyleLoaded può scattare prima di onMapCreated: il setup gira quando
  // entrambi sono pronti. Va rifatto a **ogni** caricamento stile (un cambio
  // vista azzera source/layer/annotation), quindi `_settingUp` evita solo la
  // riesecuzione concorrente per lo stesso load (non è un latch permanente).
  bool _styleLoaded = false;
  bool _settingUp = false;
  // Source/layer/manager TUTTI creati: solo allora si può renderizzare.
  bool _ready = false;

  static const String _trailSourceId = 'sentei-trails';
  static const String _trailLayerId = 'sentei-trails-labels';
  static const double _trailMinZoom = 13;
  static const String _steepSourceId = 'sentei-steepness';
  static const String _steepLayerId = 'sentei-steepness-line';

  // Rete di sicurezza: se il setup o il GPS si incantano, lo splash non deve
  // restare all'infinito → dopo questo timeout si chiude comunque.
  Timer? _splashTimeout;

  // ---- Setup -------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _splashTimeout = Timer(const Duration(seconds: 12), _hideSplash);
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.setCamera(CameraOptions(
      center: Point(
        coordinates: Position(
          AppConstants.defaultCenter.longitude,
          AppConstants.defaultCenter.latitude,
        ),
      ),
      zoom: 14,
      pitch: 0,
    ));
    map.addInteraction(TapInteraction.onMap(_onTap));
    await map.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      puckBearingEnabled: true,
    ));
    await _configureOrnaments(map);
    await _runSetup();
  }

  /// Disabilita la **bussola nativa** Mapbox: si sovrapponeva ai bottoni custom
  /// in alto a destra (posizione / 3D). La **scale bar** (km in base allo zoom)
  /// resta ai default Mapbox, in alto a sinistra.
  Future<void> _configureOrnaments(MapboxMap map) async {
    if (_ornamentsConfigured) return;
    _ornamentsConfigured = true;
    await map.compass.updateSettings(CompassSettings(enabled: false));
    // Logo Mapbox e attribuzione (icona "i") NON possono essere rimossi (lo
    // vietano i termini d'uso Mapbox), ma si possono **riposizionare**. Li
    // impiliamo in alto a sinistra, appena sotto la scale bar: il logo sopra e
    // l'icona "i" **subito sotto, tutta a sinistra** — più defilata, non "in
    // mezzo" com'era prima (marginLeft 118, verso il centro).
    await map.logo.updateSettings(LogoSettings(
      position: OrnamentPosition.TOP_LEFT,
      marginLeft: 6,
      marginTop: 30,
    ));
    // NB: la **dimensione** dell'icona "i" è fissata dall'SDK nativo Mapbox
    // (AttributionSettings non espone size) → non riducibile via API; qui la
    // spostiamo solo un filo più in alto e a sinistra, mantenendo la spaziatura
    // sotto il logo.
    await map.attribution.updateSettings(AttributionSettings(
      position: OrnamentPosition.TOP_LEFT,
      marginLeft: 6,
      marginTop: 56,
      iconColor: 0xFF3A3A3C, // antracite, coerente con la barra
    ));
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    _styleLoaded = true;
    await _runSetup();
  }

  /// Esegue il setup dello stile (terreno, hillshade, layer sentieri, manager
  /// annotation). Chiamato a ogni `onStyleLoaded` (anche dopo un cambio vista) e
  /// da `onMapCreated`; `_settingUp` previene la doppia esecuzione concorrente.
  Future<void> _runSetup() async {
    if (_map == null || !_styleLoaded || _settingUp) return;
    _settingUp = true;
    try {
      await _styleSetup(_map!);
    } finally {
      _settingUp = false;
    }
  }

  Future<void> _styleSetup(MapboxMap map) async {
    _ready = false; // durante il re-setup i manager sono ricreati
    // La source dei numeri sentiero viene ricreata vuota: azzera la cache
    // dell'area già scaricata così le etichette si ripopolano dopo un cambio
    // stile (senza dover fare pan).
    _tS = _tW = _tN = _tE = null;
    // Terreno 3D (DEM Mapbox).
    await map.style.addSource(RasterDemSource(
      id: 'mapbox-dem',
      url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
      tileSize: 514,
    ));
    await map.style.setStyleTerrain(jsonEncode(<String, Object>{
      'source': 'mapbox-dem',
      'exaggeration': 1.5,
    }));
    // Cielo atmosferico: dà profondità all'orizzonte in vista 3D.
    await map.style.addLayer(SkyLayer(
      id: 'sentei-sky',
      skyType: SkyType.ATMOSPHERE,
      skyAtmosphereSunIntensity: 10,
    ));
    // Hillshade extra per un rilievo più marcato (Outdoors ne ha uno tenue).
    // Inserito SOTTO la prima etichetta così non copre testo/sentieri/strade.
    // Riusa la stessa DEM del terreno 3D. SALTATO in vista satellite: l'ortofoto
    // ha già il rilievo reale, un hillshade sopra la scurirebbe.
    String? firstSymbolId;
    for (final l in await map.style.getStyleLayers()) {
      if (l?.type == 'symbol') {
        firstSymbolId = l!.id;
        break;
      }
    }
    if (_styleChoice == MapStyleChoice.outdoors) {
      final hillshade = HillshadeLayer(
        id: 'sentei-hillshade',
        sourceId: 'mapbox-dem',
        hillshadeExaggeration: 0.5,
        hillshadeShadowColor: 0x59413A33,
        hillshadeHighlightColor: 0x33FFFFFF,
      );
      if (firstSymbolId != null) {
        await map.style
            .addLayerAt(hillshade, LayerPosition(below: firstSymbolId));
      } else {
        await map.style.addLayer(hillshade);
      }
    }
    // Numeri sentiero CAI: etichette ripetute lungo i sentieri (Outdoors
    // disegna già le linee). Decluttering automatico di Mapbox.
    await map.style.addSource(GeoJsonSource(
      id: _trailSourceId,
      data: '{"type":"FeatureCollection","features":[]}',
    ));
    await map.style.addLayer(SymbolLayer(
      id: _trailLayerId,
      sourceId: _trailSourceId,
      symbolPlacement: SymbolPlacement.LINE,
      symbolSpacing: 220,
      textFieldExpression: <Object>['get', 'ref'],
      textSize: 13,
      textColor: 0xFF1B5E20,
      textHaloColor: 0xFFFFFFFF,
      textHaloWidth: 2,
      textHaloBlur: 0.5,
    ));
    // Manager (ordine = z-order): tracce salvate, percorso live, waypoint sopra.
    _savedLines = await map.annotations.createPolylineAnnotationManager();
    // Colorazione ripidezza: una sola polilinea con gradiente continuo
    // (`line-gradient` su `line-progress`) → niente gradini di colore. Richiede
    // `lineMetrics: true` sul source. Il gradiente è impostato in _renderSteepness.
    await map.style.addSource(GeoJsonSource(
      id: _steepSourceId,
      data: '{"type":"FeatureCollection","features":[]}',
      lineMetrics: true,
    ));
    await map.style.addLayer(LineLayer(
      id: _steepLayerId,
      sourceId: _steepSourceId,
      lineWidth: 6,
      lineJoin: LineJoin.ROUND,
      lineCap: LineCap.ROUND,
    ));
    _savedEnds = await map.annotations.createCircleAnnotationManager();
    _liveLine = await map.annotations.createPolylineAnnotationManager();
    _waypointDots = await map.annotations.createCircleAnnotationManager();
    _waypointDots!.dragEvents(onEnd: _onWaypointDragEnd);
    _waypointDots!.tapEvents(onTap: _onWaypointTap);
    // Cursore profilo (sopra a tutto): punto evidenziato scorrendo il grafico.
    _cursorDot = await map.annotations.createCircleAnnotationManager();
    // Marker del punto ispezionato in esplorazione (info point).
    _inspectedDot = await map.annotations.createCircleAnnotationManager();
    _ready = true; // tutto creato: ora si può renderizzare
    await _renderAll();
    await _renderSteepness();
    await _renderInspectedPoint();
    await _maybeFetchTrails();
    // Centratura iniziale (GPS) solo alla prima apertura, non a ogni cambio
    // stile: al re-setup dopo uno switch la camera va lasciata dov'è.
    if (!_postSetupOnce) {
      _postSetupOnce = true;
      // All'apertura si punta SEMPRE alla posizione GPS dell'utente; la traccia
      // salvata resta solo come fallback se il GPS non è disponibile.
      unawaited(_locateSilently());
    }
  }

  /// Evidenzia sulla mappa il punto selezionato sul grafico (profileCursor).
  Future<void> _renderCursor() async {
    final mgr = _cursorDot;
    if (mgr == null) return;
    await mgr.deleteAll();
    final c = ref.read(profileCursorProvider);
    if (c == null) return;
    await mgr.create(CircleAnnotationOptions(
      geometry:
          Point(coordinates: Position(c.position.longitude, c.position.latitude)),
      circleRadius: 8,
      circleColor: 0xFFE53935,
      circleStrokeColor: 0xFFFFFFFF,
      circleStrokeWidth: 3,
    ));
  }

  /// Marker del punto ispezionato in esplorazione: pallino colorato circondato
  /// da un anello antracite, in corrispondenza del punto toccato.
  Future<void> _renderInspectedPoint() async {
    final mgr = _inspectedDot;
    if (mgr == null) return;
    await mgr.deleteAll();
    final ip = ref.read(inspectedPointProvider);
    if (ip == null) return;
    await mgr.create(CircleAnnotationOptions(
      geometry: Point(
          coordinates: Position(ip.point.longitude, ip.point.latitude)),
      circleRadius: 6,
      circleColor: 0xFF1565C0, // pallino tinta primaria
      circleStrokeColor: 0xFF1C1C1E, // anello antracite
      circleStrokeWidth: 3,
    ));
  }

  /// Disegna la colorazione per ripidezza della traccia selezionata, se il
  /// toggle è attivo; altrimenti svuota il layer.
  Future<void> _renderSteepness() async {
    final map = _map;
    if (map == null || !_ready) return; // source/layer non ancora pronti
    final state = ref.read(tracksProvider);
    final on = ref.read(steepnessVisibleProvider);
    DrawnTrack? sel;
    for (final t in state.tracks) {
      if (t.id == state.selectedId) {
        sel = t;
        break;
      }
    }
    final profile = sel?.metrics?.profile;
    final stops =
        (on && profile != null) ? steepnessGradientStops(profile) : const [];

    if (stops.isEmpty) {
      await map.style.setStyleSourceProperty(
        _steepSourceId,
        'data',
        '{"type":"FeatureCollection","features":[]}',
      );
      return;
    }

    // Una sola LineString = tutta la traccia; il colore varia col gradiente.
    final coords = [
      for (final s in profile!.samples) [s.position.longitude, s.position.latitude],
    ];
    await map.style.setStyleSourceProperty(
      _steepSourceId,
      'data',
      jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {'type': 'LineString', 'coordinates': coords},
            'properties': <String, Object>{},
          },
        ],
      }),
    );

    // line-gradient: interpolazione continua dei colori lungo line-progress.
    final gradient = <Object>[
      'interpolate',
      <Object>['linear'],
      <Object>['line-progress'],
      for (final st in stops) ...[st.t, st.colorHex],
    ];
    await map.style.setStyleLayerProperty(
      _steepLayerId,
      'line-gradient',
      jsonEncode(gradient),
    );
  }

  // ---- Rendering tracce ---------------------------------------------------

  /// Ridisegna tutto dallo stato: tracce finalizzate (linea+estremi) + traccia
  /// in modifica (percorso live + waypoint trascinabili).
  Future<void> _renderAll() async {
    // Finché il setup non è completo non renderizzare (un listener può scattare
    // durante l'inizializzazione → null-check su manager non ancora creati).
    if (!_ready) return;
    if (_rendering) {
      _renderAgain = true;
      return;
    }
    _rendering = true;
    try {
      final state = ref.read(tracksProvider);
      final hidden = ref.read(tracksHiddenProvider);
      await _savedLines!.deleteAll();
      await _savedEnds!.deleteAll();
      await _liveLine!.deleteAll();
      await _waypointDots!.deleteAll();
      _wpIndexById.clear();

      for (final t in state.tracks) {
        final editing = t.id == state.editingId;
        final path = t.routedPath.length >= 2
            ? t.routedPath
            : (ref.read(livePathProvider(t.id)).value ?? const <ll.LatLng>[]);

        if (!editing) {
          if (hidden) continue; // tracce salvate nascoste
          if (path.length < 2) continue;
          // La traccia selezionata è più spessa e con bordo più marcato.
          final isSelected = t.id == state.selectedId;
          await _savedLines!.create(PolylineAnnotationOptions(
            geometry: _lineOf(path),
            lineColor: t.color.toARGB32(),
            lineWidth: isSelected ? 7 : 4.5,
            lineBorderColor: 0xFFFFFFFF,
            lineBorderWidth: isSelected ? 2.5 : 1.5,
          ));
          await _drawEndpoints(t.waypoints);
        } else {
          // Traccia in modifica: percorso live + waypoint trascinabili.
          if (path.length >= 2) {
            await _liveLine!.create(PolylineAnnotationOptions(
              geometry: _lineOf(path),
              lineColor: t.color.toARGB32(),
              lineWidth: 4,
              lineBorderColor: 0xFFFFFFFF,
              lineBorderWidth: 1,
            ));
          }
          await _drawWaypoints(t.waypoints);
        }
      }
    } finally {
      _rendering = false;
      if (_renderAgain) {
        _renderAgain = false;
        await _renderAll();
      }
    }
  }

  LineString _lineOf(List<ll.LatLng> path) => LineString(
        coordinates: [for (final p in path) Position(p.longitude, p.latitude)],
      );

  Future<void> _drawEndpoints(List<ll.LatLng> wps) async {
    if (wps.isEmpty) return;
    await _savedEnds!.create(CircleAnnotationOptions(
      geometry: Point(
          coordinates: Position(wps.first.longitude, wps.first.latitude)),
      circleRadius: 6,
      circleColor: 0xFF2E7D32,
      circleStrokeColor: 0xFFFFFFFF,
      circleStrokeWidth: 2,
    ));
    if (wps.length > 1) {
      await _savedEnds!.create(CircleAnnotationOptions(
        geometry:
            Point(coordinates: Position(wps.last.longitude, wps.last.latitude)),
        circleRadius: 6,
        circleColor: 0xFFC62828,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2,
      ));
    }
  }

  Future<void> _drawWaypoints(List<ll.LatLng> wps) async {
    for (var i = 0; i < wps.length; i++) {
      final isStart = i == 0;
      final isEnd = i == wps.length - 1 && wps.length > 1;
      final color = isStart
          ? 0xFF2E7D32
          : isEnd
              ? 0xFFC62828
              : 0xFF1565C0;
      final a = await _waypointDots!.create(CircleAnnotationOptions(
        geometry: Point(coordinates: Position(wps[i].longitude, wps[i].latitude)),
        circleRadius: 7,
        circleColor: color,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2,
        isDraggable: true,
      ));
      _wpIndexById[a.id] = i;
    }
  }

  /// Fallback di centratura quando il GPS non è disponibile all'apertura:
  /// inquadra la prima traccia salvata (se presente), altrimenti resta sul
  /// centro default. No-op se la camera iniziale è già stata posizionata.
  void _fallbackCenterOnSavedTrack() {
    if (_initialCameraDone) return;
    final tracks = ref.read(tracksProvider).tracks;
    for (final t in tracks) {
      if (t.waypoints.isNotEmpty) {
        _initialCameraDone = true;
        // Istantaneo: siamo ancora dietro lo splash (nessuna animazione visibile).
        _map?.setCamera(
          CameraOptions(
            center: Point(
              coordinates: Position(
                  t.waypoints.first.longitude, t.waypoints.first.latitude),
            ),
            zoom: 14,
          ),
        );
        return;
      }
    }
  }

  // ---- Interazioni disegno ------------------------------------------------

  Future<void> _onTap(MapContentGestureContext context) async {
    final pos = context.point.coordinates;
    final p = ll.LatLng(pos.lat.toDouble(), pos.lng.toDouble());
    // Un tap sulla mappa chiude sempre la ricerca aperta (che sia per
    // selezionare una traccia o ispezionare un punto).
    if (_searchOpen) _closeSearch();
    final state = ref.read(tracksProvider);
    if (state.drawing) {
      ref.read(inspectedPointProvider.notifier).clear();
      ref.read(tracksProvider.notifier).addPoint(p);
    } else {
      final cam = await _map?.getCameraState();
      _selectNearest(p, cam?.zoom ?? 14);
    }
  }

  void _selectNearest(ll.LatLng point, double zoom) {
    final notifier = ref.read(tracksProvider.notifier);
    final tracks = ref.read(tracksProvider).tracks;
    final mpp = 156543.03392 *
        math.cos(point.latitude * math.pi / 180.0) /
        math.pow(2, zoom);
    final threshold = 22 * mpp; // ~22 px
    String? nearest;
    var best = double.infinity;
    for (final t in tracks) {
      final path = t.routedPath.length >= 2
          ? t.routedPath
          : (ref.read(livePathProvider(t.id)).value ?? const <ll.LatLng>[]);
      if (path.length < 2) continue;
      final d = const PathGeometry().distanceToPath(point, path);
      if (d < best) {
        best = d;
        nearest = t.id;
      }
    }
    if (nearest != null && best <= threshold) {
      ref.read(inspectedPointProvider.notifier).clear();
      notifier.select(nearest);
    } else {
      // Nessuna traccia vicina: in esplorazione mostriamo le info del punto.
      notifier.deselect();
      ref.read(inspectedPointProvider.notifier).inspect(point);
    }
  }

  void _onWaypointDragEnd(CircleAnnotation a) {
    final i = _wpIndexById[a.id];
    if (i == null) return;
    final pos = a.geometry.coordinates;
    ref
        .read(tracksProvider.notifier)
        .movePoint(i, ll.LatLng(pos.lat.toDouble(), pos.lng.toDouble()));
  }

  void _onWaypointTap(CircleAnnotation a) {
    final i = _wpIndexById[a.id];
    if (i == null) return;
    ref.read(tracksProvider.notifier).removePoint(i);
  }

  // ---- Numeri sentiero CAI ------------------------------------------------

  /// Al primo idle dopo un cambio stile ri-applica il terreno 3D (il mesh del
  /// DEM può non essere pronto subito dopo il load → prima inclinazione piatta),
  /// poi aggiorna sempre i numeri sentiero.
  Future<void> _onMapIdle() async {
    if (_needTerrainReassert) {
      _needTerrainReassert = false;
      try {
        await _map?.style.setStyleTerrain(jsonEncode(<String, Object>{
          'source': 'mapbox-dem',
          'exaggeration': 1.5,
        }));
      } catch (_) {
        // best-effort
      }
    }
    await _maybeFetchTrails();
  }

  Future<void> _maybeFetchTrails() async {
    final map = _map;
    if (map == null) return;
    try {
      await _maybeFetchTrailsInner(map);
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _maybeFetchTrailsInner(MapboxMap map) async {
    final cam = await map.getCameraState();
    final b = await map.coordinateBoundsForCamera(CameraOptions(
      center: cam.center,
      zoom: cam.zoom,
      bearing: cam.bearing,
      pitch: cam.pitch,
    ));
    final s = b.southwest.coordinates.lat.toDouble();
    final w = b.southwest.coordinates.lng.toDouble();
    final n = b.northeast.coordinates.lat.toDouble();
    final e = b.northeast.coordinates.lng.toDouble();
    // Memorizza l'area inquadrata (per "scarica area visualizzata" offline).
    ref.read(lastMapBoundsProvider.notifier).set(
          MapAreaBounds(south: s, west: w, north: n, east: e, zoom: cam.zoom),
        );
    if (cam.zoom < _trailMinZoom) {
      _tS = null;
      await map.style.setStyleSourceProperty(
          _trailSourceId, 'data', '{"type":"FeatureCollection","features":[]}');
      return;
    }
    if (_tS != null && s >= _tS! && n <= _tN! && w >= _tW! && e <= _tE!) {
      return;
    }
    final dLat = (n - s) * 0.15, dLon = (e - w) * 0.15;
    final es = s - dLat, en = n + dLat, ew = w - dLon, ee = e + dLon;
    final refLines = await ref
        .read(trailNetworkServiceProvider)
        .hikingRefLinesInBounds(es, ew, en, ee);
    _tS = es;
    _tW = ew;
    _tN = en;
    _tE = ee;
    final features = [
      for (final l in refLines)
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final p in l.pts) [p.longitude, p.latitude],
            ],
          },
          'properties': <String, Object>{'ref': l.ref},
        },
    ];
    await map.style.setStyleSourceProperty(
      _trailSourceId,
      'data',
      jsonEncode({'type': 'FeatureCollection', 'features': features}),
    );
  }

  // ---- Camera / controlli -------------------------------------------------

  Future<void> _locate() async {
    try {
      final pos = await ref.read(userLocationProvider.notifier).locate();
      await _map?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 15,
        ),
        MapAnimationOptions(duration: 800),
      );
    } on LocationException catch (e) {
      if (mounted) {
        showIosToast(context, e.message);
      }
    }
  }

  /// Centra sulla posizione GPS silenziosamente (senza SnackBar su errore).
  /// Chiamato all'apertura dell'app: la mappa si posiziona SEMPRE sulla
  /// posizione corrente dell'utente. Se il GPS non è disponibile o i permessi
  /// vengono rifiutati, ripiega sulla prima traccia salvata (o sul centro
  /// default). Il flag `_initialCameraDone` evita centrature concorrenti.
  Future<void> _locateSilently() async {
    try {
      final pos = await ref.read(userLocationProvider.notifier).locate();
      if (mounted && !_initialCameraDone) {
        _initialCameraDone = true;
        // Camera piazzata **istantaneamente** (niente flyTo): il salto avviene
        // dietro lo splash, così alla dissolvenza la mappa è già sulla posizione.
        await _map?.setCamera(
          CameraOptions(
            center: Point(coordinates: Position(pos.longitude, pos.latitude)),
            zoom: 15,
          ),
        );
      }
    } catch (_) {
      // GPS non disponibile o permessi negati → fallback su traccia salvata.
      _fallbackCenterOnSavedTrack();
    } finally {
      // In ogni caso lo splash si chiude: camera pronta o fallback esaurito.
      _hideSplash();
    }
  }

  /// Nasconde lo splash esteso (dissolvenza gestita dall'`AnimatedOpacity`).
  void _hideSplash() {
    _splashTimeout?.cancel();
    if (!mounted || !_splashVisible) return;
    setState(() => _splashVisible = false);
  }

  /// Alterna 2D (pitch 0) e 3D (pitch 65). L'etichetta del bottone mostra la
  /// modalità *impostabile* (quella verso cui si passa al tap).
  Future<void> _toggle3D() async {
    final to3D = !_is3D;
    await _map?.flyTo(
      CameraOptions(pitch: to3D ? 65 : 0),
      MapAnimationOptions(duration: 600),
    );
    if (mounted) setState(() => _is3D = to3D);
  }

  /// Aggiorna l'orientamento (bussola custom + stato 2D/3D) seguendo la camera.
  void _onCameraChange(CameraChangedEventData data) {
    final b = data.cameraState.bearing;
    final p = data.cameraState.pitch;
    final is3D = p > 1;
    if ((b - _bearing).abs() < 0.5 &&
        (p - _pitch).abs() < 0.5 &&
        is3D == _is3D) {
      return;
    }
    if (mounted) {
      setState(() {
        _bearing = b;
        _pitch = p;
        _is3D = is3D;
      });
    }
  }

  /// Riporta il nord in alto (e azzera l'eventuale rotazione) mantenendo il pitch.
  Future<void> _resetNorth() async {
    await _map?.flyTo(
      CameraOptions(bearing: 0),
      MapAnimationOptions(duration: 400),
    );
  }

  /// Centra la mappa su una traccia, differendo l'operazione se la mappa non è
  /// la route attiva (es. lista tracciati è ancora in primo piano durante il pop).
  /// `cameraForCoordinates` necessita che la mappa sia visibile per calcolare
  /// correttamente i bounds; se chiamata in background restituisce valori invalidi.
  void _scheduleFocusTrack(String id) {
    if (ModalRoute.of(context)?.isCurrent ?? true) {
      _focusTrack(id);
    } else {
      // Attendi che l'animazione di pop della lista tracce sia completata (~300ms)
      // prima di spostare la camera; altrimenti cameraForCoordinates fallisce.
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _focusTrack(id);
      });
    }
  }

  /// Centra/inquadra la mappa su una traccia (richiesto dalla lista tracce).
  Future<void> _focusTrack(String id) async {
    final map = _map;
    if (map == null) return;
    final t = ref.read(tracksProvider).byId(id);
    if (t == null) return;
    final path =
        t.routedPath.length >= 2 ? t.routedPath : t.waypoints;
    if (path.isEmpty) return;
    // La card di dettaglio occupa il fondo: più padding sotto.
    final padding =
        MbxEdgeInsets(top: 90, left: 50, bottom: 260, right: 50);
    if (path.length == 1) {
      await map.flyTo(
        CameraOptions(
          center: Point(
              coordinates:
                  Position(path.first.longitude, path.first.latitude)),
          zoom: 14,
        ),
        MapAnimationOptions(duration: 700),
      );
      return;
    }
    final coords = [
      for (final p in path) Point(coordinates: Position(p.longitude, p.latitude)),
    ];
    final cam = await map.cameraForCoordinatesPadding(
        coords, CameraOptions(), padding, null, null);
    await map.flyTo(cam, MapAnimationOptions(duration: 800));
  }

  // ---- Ricerca luoghi -----------------------------------------------------

  void _openSearch() => setState(() => _searchOpen = true);

  /// Bottone "vista" nella barra: solo due viste → tap = alterna direttamente
  /// tra Mappa (Outdoors) e Satellite.
  void _onLayers() {
    _setStyle(_styleChoice == MapStyleChoice.outdoors
        ? MapStyleChoice.satellite
        : MapStyleChoice.outdoors);
  }

  /// Cambia la vista mappa: ricarica lo stile e ri-esegue il setup (terreno,
  /// hillshade, layer sentieri, manager annotation) al `onStyleLoaded`.
  Future<void> _setStyle(MapStyleChoice choice) async {
    final map = _map;
    if (map == null || choice == _styleChoice) return;
    final uri = switch (choice) {
      MapStyleChoice.outdoors => _outdoorsStyleUri,
      MapStyleChoice.satellite => _satelliteStyleUri,
    };
    setState(() => _styleChoice = choice);
    _ready = false; // i manager verranno ricreati dopo il caricamento
    _needTerrainReassert = true; // ri-applica il terreno al primo idle
    // onStyleLoaded → _runSetup ricrea terreno/hillshade/sentieri/annotation.
    await map.loadStyleURI(uri);
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchOpen = false;
      _searching = false;
      _searchResults = const [];
      _searchCtrl.clear();
    });
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        _searchResults = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce =
        Timer(const Duration(milliseconds: 350), () => _runSearch(v));
  }

  Future<void> _runSearch(String q) async {
    ll.LatLng? prox;
    final cam = await _map?.getCameraState();
    if (cam != null) {
      final c = cam.center.coordinates;
      prox = ll.LatLng(c.lat.toDouble(), c.lng.toDouble());
    }
    final results =
        await ref.read(geocodingServiceProvider).search(q, proximity: prox);
    if (!mounted || !_searchOpen) return;
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  Future<void> _goToResult(GeocodeResult r) async {
    await _map?.flyTo(
      CameraOptions(
        center:
            Point(coordinates: Position(r.center.longitude, r.center.latitude)),
        zoom: 14,
      ),
      MapAnimationOptions(duration: 800),
    );
    _closeSearch();
  }

  @override
  void dispose() {
    _splashTimeout?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final editingId = ref.watch(tracksProvider).editingId;
    // Card visibile (traccia selezionata o in modifica): occupa il fondo e
    // sostituisce la toolbar (che viene nascosta).
    final showCard = ref.watch(tracksProvider.select((s) => s.showCard));
    // Info punto in esplorazione (mini-card): solo se non c'è la card traccia.
    final inspected = ref.watch(inspectedPointProvider);
    final showPointCard = inspected != null && !showCard;
    // La card traccia (selezione/disegno) ha priorità: azzera il punto ispezionato.
    ref.listen(tracksProvider.select((s) => s.showCard), (_, show) {
      if (show) ref.read(inspectedPointProvider.notifier).clear();
    });
    // Ridisegna solo su cambi di GEOMETRIA (waypoint/percorso/colore/lista tracce),
    // non su modifiche di puri metadati (nome) → evita il flickering al typing.
    ref.listen(
      tracksProvider.select((s) => (s.geometryNonce, s.editingId, s.selectedId)),
      (_, __) {
        _renderAll();
        _renderSteepness();
      },
    );
    ref.listen(steepnessVisibleProvider, (_, __) => _renderSteepness());
    ref.listen(profileCursorProvider, (_, __) => _renderCursor());
    ref.listen(inspectedPointProvider, (_, __) => _renderInspectedPoint());
    ref.listen(tracksHiddenProvider, (_, __) => _renderAll());
    ref.listen(mapFocusProvider, (_, next) {
      if (next != null) _scheduleFocusTrack(next.trackId);
    });
    if (editingId != null) {
      ref.listen(livePathProvider(editingId), (_, __) => _renderAll());
    }

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            styleUri: _outdoorsStyleUri,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            onMapIdleListener: (_) => _onMapIdle(),
            onCameraChangeListener: _onCameraChange,
          ),
          // Controlli in alto a destra: posizione e 2D/3D. La bussola nativa è
          // disabilitata (vi si sovrapponeva), quindi stanno in cima a destra.
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: _SideControls(
                  is3D: _is3D,
                  bearing: _bearing,
                  onLocate: _locate,
                  onToggle3D: _toggle3D,
                  onResetNorth: _resetNorth,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DrawRouteControls(),
                  // Pannello di ricerca luoghi (dalla lente): sopra la menubar,
                  // con i risultati che crescono verso l'alto.
                  if (_searchOpen)
                    _SearchPanel(
                      controller: _searchCtrl,
                      searching: _searching,
                      results: _searchResults,
                      onChanged: _onSearchChanged,
                      onSubmitted: (_) {
                        if (_searchResults.isNotEmpty) {
                          _goToResult(_searchResults.first);
                        }
                      },
                      onPick: _goToResult,
                      onClose: _closeSearch,
                    ),
                  // Respiro tra la ricerca e la menubar.
                  if (_searchOpen) const SizedBox(height: 12),
                  // Mini-card info punto (esplorazione): sopra la barra, come la
                  // ricerca (stessa posizione + piccolo margine).
                  if (showPointCard) ...[
                    _PointInfoCard(
                      data: inspected,
                      onClose: () =>
                          ref.read(inspectedPointProvider.notifier).clear(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // La toolbar c'è quando NON è mostrata la card traccia (che
                  // occupa il fondo dello schermo); la mini-card punto le sta sopra.
                  if (!showCard)
                    _BottomBar(
                      onSearch: _openSearch,
                      onLayers: _onLayers,
                      // In Mappa mostro il mondo (→ satellite); in Satellite
                      // mostro l'icona a strati (→ torna a Mappa).
                      layersIcon: _styleChoice == MapStyleChoice.outdoors
                          ? CupertinoIcons.globe
                          : CupertinoIcons.map,
                      layersTooltip: _styleChoice == MapStyleChoice.outdoors
                          ? 'Vista satellite'
                          : 'Vista mappa',
                      onNewTrack: () {
                        ref.read(inspectedPointProvider.notifier).clear();
                        ref.read(tracksProvider.notifier).startNewDrawing();
                      },
                      onTracks: () => context.push(TracksListScreen.routePath),
                      onSettings: () => context.push(SettingsScreen.routePath),
                    ),
                ],
              ),
            ),
          ),
          // Splash esteso: copre la mappa finché la camera iniziale non è pronta
          // (GPS o fallback), poi dissolve. Elimina il salto default→posizione.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_splashVisible,
              child: AnimatedOpacity(
                opacity: _splashVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                child: const _SplashOverlay(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay di avvio: sfondo bianco + logo centrato, in continuità con lo splash
/// nativo (`flutter_native_splash`, `branding/splash.png` su fondo bianco).
/// TODO(roadmap): sostituire lo sfondo bianco con una vista mappa animata
/// (pan lento dall'alto) dietro il logo.
class _SplashOverlay extends StatelessWidget {
  const _SplashOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: Center(
        child: Image.asset(
          'branding/splash.png',
          width: 180,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Barra flottante in basso (dock): ricerca · + · tracce · impostazioni.
/// (La bussola/nord e i bottoni posizione/3D stanno in alto a destra.)
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onSearch,
    required this.onLayers,
    required this.layersIcon,
    required this.layersTooltip,
    required this.onNewTrack,
    required this.onTracks,
    required this.onSettings,
  });

  final VoidCallback onSearch;
  final VoidCallback onLayers;
  final IconData layersIcon;
  final String layersTooltip;
  final VoidCallback onNewTrack;
  final VoidCallback onTracks;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BarButton(
                tooltip: 'Cerca un luogo',
                icon: Icons.search_rounded,
                onPressed: onSearch,
              ),
              // Vista mappa/satellite: l'icona cambia in base alla vista attiva.
              _BarButton(
                tooltip: layersTooltip,
                icon: layersIcon,
                onPressed: onLayers,
              ),
              // Azione primaria "nuovo percorso": cerchio pieno tinta primaria.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const ui.Size(46, 46),
                  onPressed: onNewTrack,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.add,
                        color: Color(0xFFFFFFFF), size: 26),
                  ),
                ),
              ),
              // Lista tracciati: usa il glifo "sentiero" (linea curva con pallini).
              _BarButton(
                tooltip: 'Tracciati salvati',
                onPressed: onTracks,
                child: const _TrailGlyph(),
              ),
              _BarButton(
                tooltip: 'Impostazioni',
                icon: CupertinoIcons.gear_alt_fill,
                onPressed: onSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mini-card mostrata in **esplorazione** toccando un punto della mappa senza
/// tracce vicine: quota (DEM Terrarium, anche offline), località/provincia/
/// nazione (reverse geocoding) e coordinate. Sta **sopra la barra** (come la
/// ricerca) e coesiste con la card traccia (che ha priorità).
class _PointInfoCard extends StatelessWidget {
  const _PointInfoCard({required this.data, required this.onClose});

  final InspectedPoint data;
  final VoidCallback onClose;

  static String _fmtCoords(ll.LatLng p) {
    final ns = p.latitude >= 0 ? 'N' : 'S';
    final ew = p.longitude >= 0 ? 'E' : 'O';
    return '${p.latitude.abs().toStringAsFixed(5)}°$ns  '
        '${p.longitude.abs().toStringAsFixed(5)}°$ew';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final place = data.place;
    final hasPlace = place != null && !place.isEmpty;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width - 16,
      ),
      child: GlassSurface(
        // Stessa trasparenza della ricerca/menubar (default).
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.placemark_fill,
                    color: scheme.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text('Quota ',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        if (data.elevationLoading)
                          const CupertinoActivityIndicator(radius: 8)
                        else
                          Text(
                            data.elevation != null
                                ? Format.meters(data.elevation!)
                                : 'non disponibile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: data.elevation != null
                                  ? scheme.primary
                                  : const Color(0xFF8E8E93),
                            ),
                          ),
                      ],
                    ),
                    // Località, provincia, nazione (reverse geocoding).
                    if (data.placeLoading) ...[
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoActivityIndicator(radius: 6),
                          SizedBox(width: 6),
                          Text('Individuazione luogo…',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF9A9AA0))),
                        ],
                      ),
                    ] else if (hasPlace) ...[
                      const SizedBox(height: 3),
                      Text(
                        place.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.25,
                            color: Color(0xFF3A3A3C)),
                      ),
                    ],
                    const SizedBox(height: 3),
                    // Tap sulle coordinate → copia negli appunti.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                          text: '${data.point.latitude.toStringAsFixed(6)}, '
                              '${data.point.longitude.toStringAsFixed(6)}',
                        ));
                        showIosToast(context, 'Coordinate copiate');
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _fmtCoords(data.point),
                              style: const TextStyle(
                                  fontSize: 12.5, color: Color(0xFF6E6E73)),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(CupertinoIcons.doc_on_doc,
                              size: 13, color: Color(0xFF9A9AA0)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const ui.Size(40, 40),
                onPressed: onClose,
                child: const Icon(CupertinoIcons.clear_circled_solid,
                    size: 24, color: Color(0xFFB0B0B5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grigio antracite neutro per le icone della barra (iOS-like).
const Color _kBarIcon = Color(0xFF3A3A3C);

/// Icona tappabile della barra in vetro: press-dim iOS, niente ripple Material.
/// Con [child] si passa un glifo custom al posto dell'icona.
class _BarButton extends StatelessWidget {
  const _BarButton({
    this.icon,
    this.child,
    required this.onPressed,
    this.tooltip,
  }) : assert(icon != null || child != null);

  final IconData? icon;
  final Widget? child;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget button = CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const ui.Size(46, 46),
      onPressed: onPressed,
      child: SizedBox(
        width: 46,
        height: 46,
        child: Center(
          child: child ?? Icon(icon, size: 24, color: _kBarIcon),
        ),
      ),
    );
    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Glifo "sentiero": linea curva con pallini agli estremi (rappresenta un
/// percorso). Usato come icona della lista tracciati nella barra in basso.
class _TrailGlyph extends StatelessWidget {
  const _TrailGlyph();

  @override
  Widget build(BuildContext context) => const CustomPaint(
        size: ui.Size(24, 24),
        painter: _TrailPainter(),
      );
}

class _TrailPainter extends CustomPainter {
  const _TrailPainter();

  @override
  void paint(Canvas canvas, ui.Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = _kBarIcon
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // Curva a S tra i due estremi (basso-sx → alto-dx).
    final path = Path()
      ..moveTo(w * 0.24, h * 0.76)
      ..cubicTo(w * 0.58, h * 0.74, w * 0.30, h * 0.30, w * 0.76, h * 0.24);
    canvas.drawPath(path, stroke);
    final dot = Paint()
      ..color = _kBarIcon
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.24, h * 0.76), 2.7, dot);
    canvas.drawCircle(Offset(w * 0.76, h * 0.24), 2.7, dot);
  }

  @override
  bool shouldRepaint(_TrailPainter old) => false;
}

/// Controlli in alto a destra, dall'alto verso il basso: bussola · 2D/3D ·
/// posizione. Stile e dimensione (~44px) coordinati con la barra in basso.
class _SideControls extends StatelessWidget {
  const _SideControls({
    required this.is3D,
    required this.bearing,
    required this.onLocate,
    required this.onToggle3D,
    required this.onResetNorth,
  });

  final bool is3D;
  final double bearing;
  final VoidCallback onLocate;
  final VoidCallback onToggle3D;
  final VoidCallback onResetNorth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Un UNICO blocco in vetro (stile Apple Maps): bussola · 2D/3D · posizione,
    // tre righe 44×44 separate da hairline. Accorpati per rafforzare il
    // raggruppamento visivo (Gestalt) e ridurre il rumore (una sola superficie).
    return GlassSurface(
      borderRadius: BorderRadius.circular(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bussola: ago a due tinte (rosso nord / grigio sud); tap → nord in alto.
          _PillButton(
            tooltip: 'Nord in alto',
            onPressed: onResetNorth,
            child: Transform.rotate(
              angle: -bearing * math.pi / 180.0,
              child: const _CompassNeedle(),
            ),
          ),
          const _PillDivider(),
          _PillButton(
            tooltip: is3D ? 'Passa a 2D' : 'Passa a 3D',
            onPressed: onToggle3D,
            child: Text(
              is3D ? '2D' : '3D',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          const _PillDivider(),
          _PillButton(
            tooltip: 'La mia posizione',
            onPressed: onLocate,
            child: Icon(CupertinoIcons.location_fill,
                size: 20, color: scheme.primary),
          ),
        ],
      ),
    );
  }
}

/// Separatore hairline tra le voci della pillola controlli (stile iOS).
class _PillDivider extends StatelessWidget {
  const _PillDivider();

  @override
  Widget build(BuildContext context) => Container(
        height: 0.6,
        width: 30,
        color: const Color(0xFF3C3C43).withValues(alpha: 0.2),
      );
}

/// Voce tappabile dentro una pillola in vetro (44×44, press-dim iOS).
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.child,
    required this.onPressed,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget button = CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const ui.Size(44, 44),
      onPressed: onPressed,
      child: SizedBox(width: 44, height: 44, child: Center(child: child)),
    );
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return button;
  }
}

/// Ago di bussola a due tinte (rosso a nord, grigio a sud).
class _CompassNeedle extends StatelessWidget {
  const _CompassNeedle();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const ui.Size(15, 18), painter: _NeedlePainter());
}

class _NeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, ui.Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final north = Path()
      ..moveTo(cx, 0)
      ..lineTo(0, cy)
      ..lineTo(size.width, cy)
      ..close();
    final south = Path()
      ..moveTo(cx, size.height)
      ..lineTo(0, cy)
      ..lineTo(size.width, cy)
      ..close();
    canvas.drawPath(north, Paint()..color = const Color(0xFFE53935));
    canvas.drawPath(south, Paint()..color = const Color(0xFF8E8E93));
  }

  @override
  bool shouldRepaint(_NeedlePainter oldDelegate) => false;
}

/// Pannello di ricerca luoghi, ancorato **in basso** (sopra la menubar): la
/// lista risultati cresce verso l'alto, il campo testo è una pillola arrotondata
/// coordinata con la barra. Scegliendo un risultato (o all'invio) la mappa vola lì.
class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.searching,
    required this.results,
    required this.onChanged,
    required this.onSubmitted,
    required this.onPick,
    required this.onClose,
  });

  final TextEditingController controller;
  final bool searching;
  final List<GeocodeResult> results;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<GeocodeResult> onPick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 16;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Risultati: sopra il campo, crescono verso l'alto. Stesso vetro
          // della menubar per coerenza.
          if (results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: GlassSurface(
                borderRadius: BorderRadius.circular(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: results.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: _kBarIcon.withValues(alpha: 0.12),
                    ),
                    itemBuilder: (context, i) {
                      final r = results[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(CupertinoIcons.placemark,
                            size: 20, color: _kBarIcon),
                        title: Text(r.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: r.context.isEmpty
                            ? null
                            : Text(r.context,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => onPick(r),
                      );
                    },
                  ),
                ),
              ),
            ),
          // Campo di ricerca (pillola in vetro come la menubar).
          GlassSurface(
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Chiudi',
                    icon: const Icon(CupertinoIcons.back, color: _kBarIcon),
                    onPressed: onClose,
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Cerca un luogo',
                        border: InputBorder.none,
                      ),
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                    ),
                  ),
                  if (searching)
                    const Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: CupertinoActivityIndicator(radius: 9),
                    )
                  else if (controller.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Cancella',
                      icon: const Icon(CupertinoIcons.clear_circled_solid,
                          size: 20, color: Color(0xFFB0B0B5)),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
