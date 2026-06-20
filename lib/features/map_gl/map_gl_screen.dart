import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../core/constants.dart';
import '../../data/location/location_service.dart';
import '../draw_route/route_editor_provider.dart';
import '../map/map_providers.dart';

/// SPIKE (Fase 0 della migrazione a Mapbox GL — vedi
/// `docs/plan-mapbox-gl-migration.md`). De-risca la **Fase 4** (disegno con
/// snap-to-trail + waypoint trascinabili) e il **3D** (terreno + gesto a due
/// dita). Riusa il routing esistente (`routeAlong` / BRouter).
class MapGlScreen extends ConsumerStatefulWidget {
  const MapGlScreen({super.key});

  static const String routeName = 'map-gl';
  static const String routePath = '/gl';

  @override
  ConsumerState<MapGlScreen> createState() => _MapGlScreenState();
}

class _MapGlScreenState extends ConsumerState<MapGlScreen> {
  MapboxMap? _map;
  CircleAnnotationManager? _circles;
  PolylineAnnotationManager? _line;

  /// Manager separati per le tracce SALVATE (read-only, da tracksProvider).
  PolylineAnnotationManager? _savedLines;
  CircleAnnotationManager? _savedEnds;

  /// Centratura una-tantum sulle tracce caricate (le tracce arrivano async).
  bool _centeredOnSaved = false;

  /// Cache dell'area sentieri già scaricata (sud,ovest,nord,est in gradi).
  double? _tS, _tW, _tN, _tE;

  // onStyleLoaded può scattare prima di onMapCreated: il setup parte solo
  // quando entrambi sono pronti (in qualsiasi ordine), una volta sola.
  bool _styleLoaded = false;
  bool _didSetup = false;

  Future<void> _trySetup() async {
    if (_didSetup || _map == null || !_styleLoaded) return;
    _didSetup = true;
    await _styleSetup(_map!);
  }

  static const String _trailSourceId = 'sentei-trails';
  static const String _trailLayerId = 'sentei-trails-line';
  static const double _trailMinZoom = 13;

  /// Waypoint nell'ordine di inserimento + mappa id-cerchio→indice.
  final List<ll.LatLng> _waypoints = <ll.LatLng>[];
  final Map<String, int> _indexById = <String, int>{};

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
    // Posizione utente nativa (puck + heading) + bussola nativa (default).
    await map.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      puckBearingEnabled: true,
    ));
    await _trySetup();
  }

  /// Disegna (read-only) le tracce SALVATE dallo stato: linea col colore della
  /// traccia + casing bianco, e marker partenza (verde) / arrivo (rosso).
  Future<void> _renderSaved() async {
    final lines = _savedLines;
    final ends = _savedEnds;
    if (lines == null || ends == null) return;
    await lines.deleteAll();
    await ends.deleteAll();
    final tracks = ref.read(tracksProvider).tracks;
    // Centratura una-tantum sulle tracce (caricate async dopo onMapCreated).
    if (!_centeredOnSaved) {
      for (final t in tracks) {
        if (t.waypoints.isNotEmpty) {
          _centeredOnSaved = true;
          await _map?.flyTo(
            CameraOptions(
              center: Point(
                coordinates: Position(
                    t.waypoints.first.longitude, t.waypoints.first.latitude),
              ),
              zoom: 14,
            ),
            MapAnimationOptions(duration: 700),
          );
          break;
        }
      }
    }
    for (final t in tracks) {
      final path = t.routedPath;
      if (path.length < 2) continue;
      await lines.create(PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: [
            for (final p in path) Position(p.longitude, p.latitude),
          ],
        ),
        lineColor: t.color.toARGB32(),
        lineWidth: 4,
        lineBorderColor: 0xFFFFFFFF,
        lineBorderWidth: 1,
      ));
      final wps = t.waypoints;
      if (wps.isEmpty) continue;
      await ends.create(CircleAnnotationOptions(
        geometry:
            Point(coordinates: Position(wps.first.longitude, wps.first.latitude)),
        circleRadius: 6,
        circleColor: 0xFF2E7D32, // partenza (verde)
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2,
      ));
      if (wps.length > 1) {
        await ends.create(CircleAnnotationOptions(
          geometry: Point(
              coordinates: Position(wps.last.longitude, wps.last.latitude)),
          circleRadius: 6,
          circleColor: 0xFFC62828, // arrivo (rosso)
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 2,
        ));
      }
    }
  }

  /// Centra sulla posizione GPS dell'utente (permessi via geolocator).
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

  /// Allo stile caricato: terreno 3D, rete sentieri (sotto), poi i manager
  /// delle annotation (sopra), così le tracce stanno sopra i sentieri.
  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    _styleLoaded = true;
    await _trySetup();
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
      'exaggeration': 1.4,
    }));
    // Numeri sentiero CAI: sorgente GeoJSON di punti + symbol layer con le
    // etichette `ref`. Mapbox declustera automaticamente le etichette
    // sovrapposte (collision), così restano leggibili. Le linee dei sentieri
    // le disegna già lo stile Outdoors.
    await map.style.addSource(GeoJsonSource(
      id: _trailSourceId,
      data: '{"type":"FeatureCollection","features":[]}',
    ));
    await map.style.addLayer(SymbolLayer(
      id: _trailLayerId,
      sourceId: _trailSourceId,
      // Etichette ripetute LUNGO il sentiero, così i numeri sono sempre in vista.
      symbolPlacement: SymbolPlacement.LINE,
      symbolSpacing: 220,
      textFieldExpression: <Object>['get', 'ref'],
      textSize: 13,
      textColor: 0xFF1B5E20, // verde scuro
      textHaloColor: 0xFFFFFFFF,
      textHaloWidth: 1.5,
    ));
    // Manager annotation (sopra il layer sentieri): tracce salvate, poi disegno.
    _savedLines = await map.annotations.createPolylineAnnotationManager();
    _savedEnds = await map.annotations.createCircleAnnotationManager();
    _circles = await map.annotations.createCircleAnnotationManager();
    _line = await map.annotations.createPolylineAnnotationManager();
    _circles!.dragEvents(onEnd: _onDragEnd);
    await _renderSaved();
    await _maybeFetchTrails();
  }

  /// Scarica e mostra i numeri sentiero (ref CAI) per la vista corrente (su map
  /// idle). Gating zoom + cache sull'area già scaricata (come nel 2D).
  Future<void> _maybeFetchTrails() async {
    final map = _map;
    if (map == null) return;
    try {
      await _maybeFetchTrailsInner(map);
    } catch (_) {
      // best-effort: i numeri sono un di più, non bloccano nulla.
    }
  }

  Future<void> _maybeFetchTrailsInner(MapboxMap map) async {
    final cam = await map.getCameraState();
    if (cam.zoom < _trailMinZoom) {
      _tS = null;
      await map.style.setStyleSourceProperty(
          _trailSourceId, 'data', '{"type":"FeatureCollection","features":[]}');
      return;
    }
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
    // Già coperto dall'ultima area scaricata? niente nuova richiesta.
    if (_tS != null && s >= _tS! && n <= _tN! && w >= _tW! && e <= _tE!) {
      return;
    }
    // Espandi del 15% per coprire piccoli pan.
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

  Future<void> _onTap(MapContentGestureContext context) async {
    final circles = _circles;
    if (circles == null) return;
    final pos = context.point.coordinates;
    _waypoints.add(ll.LatLng(pos.lat.toDouble(), pos.lng.toDouble()));
    final annotation = await circles.create(CircleAnnotationOptions(
      geometry: Point(coordinates: pos),
      circleRadius: 7,
      circleColor: 0xFF1565C0,
      circleStrokeColor: 0xFFFFFFFF,
      circleStrokeWidth: 2,
      isDraggable: true,
    ));
    _indexById[annotation.id] = _waypoints.length - 1;
    await _reroute();
  }

  Future<void> _onDragEnd(CircleAnnotation annotation) async {
    final i = _indexById[annotation.id];
    if (i == null) return;
    final pos = annotation.geometry.coordinates;
    _waypoints[i] = ll.LatLng(pos.lat.toDouble(), pos.lng.toDouble());
    await _reroute();
  }

  /// Ricalcola il percorso seguendo i sentieri (BRouter) e ridisegna la linea.
  Future<void> _reroute() async {
    final line = _line;
    if (line == null) return;
    await line.deleteAll();
    if (_waypoints.length < 2) return;
    final routed = await routeAlong(
      ref.read(routingServiceProvider),
      _waypoints,
      true, // snap-to-trail
    );
    if (routed.length < 2) return;
    await line.create(PolylineAnnotationOptions(
      geometry: LineString(
        coordinates: [
          for (final p in routed) Position(p.longitude, p.latitude),
        ],
      ),
      lineColor: 0xFF1565C0,
      lineWidth: 4,
      lineBorderColor: 0xFFFFFFFF,
      lineBorderWidth: 1,
    ));
  }

  Future<void> _clear() async {
    _waypoints.clear();
    _indexById.clear();
    await _circles?.deleteAll();
    await _line?.deleteAll();
  }

  Future<void> _setPitch(double pitch) async {
    await _map?.flyTo(
      CameraOptions(pitch: pitch),
      MapAnimationOptions(duration: 600),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ridisegna le tracce salvate quando lo stato cambia (caricamento, salvataggio…).
    ref.listen(tracksProvider, (_, __) => _renderSaved());
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            styleUri: MapboxStyles.OUTDOORS,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            onMapIdleListener: (_) => _maybeFetchTrails(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SPIKE GL · tocca = punto (snap sentieri) · trascina i '
                    'pallini · "3D" = inclina',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'gl-locate',
                      onPressed: _locate,
                      child: const Icon(Icons.my_location),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton.extended(
                      heroTag: 'gl-clear',
                      onPressed: _clear,
                      icon: const Icon(Icons.clear),
                      label: const Text('Pulisci'),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton.extended(
                      heroTag: 'gl-tilt',
                      onPressed: () => _setPitch(65),
                      icon: const Icon(Icons.terrain),
                      label: const Text('3D'),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton.extended(
                      heroTag: 'gl-flat',
                      onPressed: () => _setPitch(0),
                      icon: const Icon(Icons.crop_landscape),
                      label: const Text('2D'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
