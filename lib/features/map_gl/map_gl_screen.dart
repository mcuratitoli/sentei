import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../core/constants.dart';

/// SPIKE (Fase 0 della migrazione a Mapbox GL — vedi
/// `docs/plan-mapbox-gl-migration.md`). Scopo: de-riscare la **Fase 4**
/// (disegno: tap-aggiungi + waypoint trascinabili) e verificare il **gesto
/// 2D↔3D nativo a due dita**. Non è ancora la mappa definitiva.
class MapGlScreen extends StatefulWidget {
  const MapGlScreen({super.key});

  static const String routeName = 'map-gl';
  static const String routePath = '/gl';

  @override
  State<MapGlScreen> createState() => _MapGlScreenState();
}

class _MapGlScreenState extends State<MapGlScreen> {
  MapboxMap? _map;
  CircleAnnotationManager? _circles;
  PolylineAnnotationManager? _line;

  /// Punti del percorso (ordine di inserimento) + mappa id-annotation→indice.
  final List<Position> _points = <Position>[];
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
      zoom: 13,
      pitch: 0, // si parte piatti (2D); due dita per inclinare.
    ));
    _circles = await map.annotations.createCircleAnnotationManager();
    _line = await map.annotations.createPolylineAnnotationManager();
    _circles!.dragEvents(
      onChanged: _onDrag,
      onEnd: _onDrag,
    );
    // Tap sulla mappa = aggiungi punto (nuova API interaction, non deprecata).
    map.addInteraction(TapInteraction.onMap(_onTap));
  }

  void _onDrag(CircleAnnotation annotation) {
    final i = _indexById[annotation.id];
    if (i == null) return;
    _points[i] = annotation.geometry.coordinates;
    _redrawLine();
  }

  Future<void> _onTap(MapContentGestureContext context) async {
    final circles = _circles;
    if (circles == null) return;
    final pos = context.point.coordinates;
    _points.add(pos);
    final annotation = await circles.create(CircleAnnotationOptions(
      geometry: Point(coordinates: pos),
      circleRadius: 7,
      circleColor: 0xFF1565C0,
      circleStrokeColor: 0xFFFFFFFF,
      circleStrokeWidth: 2,
      isDraggable: true,
    ));
    _indexById[annotation.id] = _points.length - 1;
    await _redrawLine();
  }

  Future<void> _redrawLine() async {
    final line = _line;
    if (line == null) return;
    await line.deleteAll();
    if (_points.length >= 2) {
      await line.create(PolylineAnnotationOptions(
        geometry: LineString(coordinates: List<Position>.from(_points)),
        lineColor: 0xFF1565C0,
        lineWidth: 4,
        lineBorderColor: 0xFFFFFFFF,
        lineBorderWidth: 1,
      ));
    }
  }

  Future<void> _clear() async {
    _points.clear();
    _indexById.clear();
    await _circles?.deleteAll();
    await _line?.deleteAll();
  }

  Future<void> _flatten() async {
    await _map?.flyTo(
      CameraOptions(pitch: 0),
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
                    'SPIKE GL · tocca = punto · trascina i pallini · '
                    'due dita = inclina (3D)',
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
                    FloatingActionButton.extended(
                      heroTag: 'gl-clear',
                      onPressed: _clear,
                      icon: const Icon(Icons.clear),
                      label: const Text('Pulisci'),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton.extended(
                      heroTag: 'gl-flat',
                      onPressed: _flatten,
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
