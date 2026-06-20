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
    _circles = await map.annotations.createCircleAnnotationManager();
    _line = await map.annotations.createPolylineAnnotationManager();
    _circles!.dragEvents(onEnd: _onDragEnd);
    map.addInteraction(TapInteraction.onMap(_onTap));
    // Posizione utente nativa (puck + heading) + bussola nativa (default).
    await map.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      puckBearingEnabled: true,
    ));
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

  /// Attiva il terreno 3D (DEM Mapbox) appena lo stile è caricato.
  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null) return;
    await map.style.addSource(RasterDemSource(
      id: 'mapbox-dem',
      url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
      tileSize: 514,
    ));
    await map.style.setStyleTerrain(jsonEncode(<String, Object>{
      'source': 'mapbox-dem',
      'exaggeration': 1.4,
    }));
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
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            styleUri: MapboxStyles.OUTDOORS,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
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
                    'pallini · "3D"/due dita = inclina',
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
