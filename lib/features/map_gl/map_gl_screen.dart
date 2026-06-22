import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../core/constants.dart';
import '../../data/location/location_service.dart';
import '../../domain/services/path_geometry.dart';
import '../../domain/services/steepness.dart';
import '../draw_route/draw_route_controls.dart';
import '../draw_route/route_editor_provider.dart';
import '../map/map_providers.dart';
import '../offline_maps/offline_maps_providers.dart';
import '../settings/settings_screen.dart';
import '../tracks_list/tracks_list_screen.dart';

/// Stile della mappa. Default: Mapbox **Outdoors** (topo stock migliore).
/// Sovrascrivibile con uno stile Mapbox Studio dedicato (simil-GaiaGPS) senza
/// toccare il codice: `--dart-define=MAP_STYLE_URI=mapbox://styles/<user>/<id>`.
const String _envMapStyle = String.fromEnvironment('MAP_STYLE_URI');
String get _mapStyleUri =>
    _envMapStyle.isEmpty ? MapboxStyles.OUTDOORS : _envMapStyle;

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
  PolylineAnnotationManager? _liveLine;

  /// id-cerchio→indice waypoint della traccia in modifica.
  final Map<String, int> _wpIndexById = <String, int>{};

  bool _centeredOnSaved = false;
  bool _rendering = false;
  bool _renderAgain = false;
  bool _is3D = false;

  // Cache area numeri sentiero già scaricata (gradi).
  double? _tS, _tW, _tN, _tE;

  // onStyleLoaded può scattare prima di onMapCreated: setup quando entrambi
  // sono pronti, una sola volta.
  bool _styleLoaded = false;
  bool _didSetup = false;
  // Source/layer/manager TUTTI creati: solo allora si può renderizzare. Diverso
  // da _didSetup (che segna "setup avviato", per non rifarlo due volte).
  bool _ready = false;

  static const String _trailSourceId = 'sentei-trails';
  static const String _trailLayerId = 'sentei-trails-labels';
  static const double _trailMinZoom = 13;
  static const String _steepSourceId = 'sentei-steepness';
  static const String _steepLayerId = 'sentei-steepness-line';

  // ---- Setup -------------------------------------------------------------

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
    await _trySetup();
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    _styleLoaded = true;
    await _trySetup();
  }

  Future<void> _trySetup() async {
    if (_didSetup || _map == null || !_styleLoaded) return;
    _didSetup = true;
    await _styleSetup(_map!);
  }

  Future<void> _styleSetup(MapboxMap map) async {
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
    // Riusa la stessa DEM del terreno 3D.
    String? firstSymbolId;
    for (final l in await map.style.getStyleLayers()) {
      if (l?.type == 'symbol') {
        firstSymbolId = l!.id;
        break;
      }
    }
    final hillshade = HillshadeLayer(
      id: 'sentei-hillshade',
      sourceId: 'mapbox-dem',
      hillshadeExaggeration: 0.5,
      hillshadeShadowColor: 0x59413A33,
      hillshadeHighlightColor: 0x33FFFFFF,
    );
    if (firstSymbolId != null) {
      await map.style.addLayerAt(hillshade, LayerPosition(below: firstSymbolId));
    } else {
      await map.style.addLayer(hillshade);
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
    _ready = true; // tutto creato: ora si può renderizzare
    await _renderAll();
    await _renderSteepness();
    await _maybeFetchTrails();
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
      await _savedLines!.deleteAll();
      await _savedEnds!.deleteAll();
      await _liveLine!.deleteAll();
      await _waypointDots!.deleteAll();
      _wpIndexById.clear();

      _maybeCenter(state.tracks);

      for (final t in state.tracks) {
        final editing = t.id == state.editingId;
        final path = t.routedPath.length >= 2
            ? t.routedPath
            : (ref.read(livePathProvider(t.id)).value ?? const <ll.LatLng>[]);

        if (!editing) {
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

  void _maybeCenter(List<DrawnTrack> tracks) {
    if (_centeredOnSaved) return;
    for (final t in tracks) {
      if (t.waypoints.isNotEmpty) {
        _centeredOnSaved = true;
        _map?.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(
                  t.waypoints.first.longitude, t.waypoints.first.latitude),
            ),
            zoom: 14,
          ),
          MapAnimationOptions(duration: 700),
        );
        return;
      }
    }
  }

  // ---- Interazioni disegno ------------------------------------------------

  Future<void> _onTap(MapContentGestureContext context) async {
    final pos = context.point.coordinates;
    final p = ll.LatLng(pos.lat.toDouble(), pos.lng.toDouble());
    final state = ref.read(tracksProvider);
    if (state.drawing) {
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
      notifier.select(nearest);
    } else {
      notifier.deselect();
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
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


  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final editingId = ref.watch(tracksProvider).editingId;
    // Card visibile (traccia selezionata o in modifica): occupa il fondo e
    // sostituisce la toolbar (che viene nascosta).
    final showCard = ref.watch(tracksProvider.select((s) => s.showCard));
    // Ridisegna su cambi di stato e sull'aggiornamento del percorso live.
    ref.listen(tracksProvider, (_, __) {
      _renderAll();
      _renderSteepness();
    });
    ref.listen(steepnessVisibleProvider, (_, __) => _renderSteepness());
    ref.listen(profileCursorProvider, (_, __) => _renderCursor());
    if (editingId != null) {
      ref.listen(livePathProvider(editingId), (_, __) => _renderAll());
    }

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            styleUri: _mapStyleUri,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            onMapIdleListener: (_) => _maybeFetchTrails(),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DrawRouteControls(),
                  // La toolbar c'è solo quando NON è mostrata la card: così la
                  // card di dettaglio occupa il fondo dello schermo.
                  if (!showCard)
                    _BottomBar(
                      onLocate: _locate,
                      is3D: _is3D,
                      onToggle3D: _toggle3D,
                      onNewTrack:
                          ref.read(tracksProvider.notifier).startNewDrawing,
                      onTracks: () => context.push(TracksListScreen.routePath),
                      onSettings: () => context.push(SettingsScreen.routePath),
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

/// Barra flottante in basso (dock): posizione · 3D/2D · + · tracce · impostazioni.
/// (La bussola/nord è fornita nativamente da Mapbox.)
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onLocate,
    required this.is3D,
    required this.onToggle3D,
    required this.onNewTrack,
    required this.onTracks,
    required this.onSettings,
  });

  final VoidCallback onLocate;
  final bool is3D;
  final VoidCallback onToggle3D;
  final VoidCallback onNewTrack;
  final VoidCallback onTracks;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        elevation: 6,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'La mia posizione',
                icon: const Icon(Icons.my_location),
                onPressed: onLocate,
              ),
              IconButton(
                tooltip: is3D ? 'Passa a 2D' : 'Passa a 3D',
                onPressed: onToggle3D,
                icon: Text(
                  is3D ? '2D' : '3D',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              FloatingActionButton.small(
                heroTag: 'gl-new',
                onPressed: onNewTrack,
                child: const Icon(Icons.add),
              ),
              IconButton(
                tooltip: 'Tracciati salvati',
                icon: const Icon(Icons.list_alt),
                onPressed: onTracks,
              ),
              IconButton(
                tooltip: 'Impostazioni',
                icon: const Icon(Icons.settings_outlined),
                onPressed: onSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
