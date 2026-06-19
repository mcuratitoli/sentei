import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Una traccia da disegnare nella vista 3D: punti + colore.
class Track3D {
  const Track3D({required this.points, required this.color});
  final List<ll.LatLng> points;
  final Color color;
}

/// Vista 3D del terreno (stile Suunto): Mapbox Outdoors + terreno 3D (DEM
/// Mapbox) con pitch. Sola visualizzazione — l'editing resta nella mappa 2D
/// (flutter_map). Mostra anche le tracce disegnate, se passate.
///
/// Richiede il token Mapbox (inizializzato in `main.dart`). Senza token la
/// `MapWidget` mostra una vista vuota: il pulsante "3D" è nascosto in quel caso.
class Map3DScreen extends StatefulWidget {
  const Map3DScreen({
    super.key,
    required this.center,
    required this.zoom,
    this.tracks = const <Track3D>[],
  });

  /// Centro iniziale (dal camera 2D corrente).
  final ll.LatLng center;

  /// Zoom iniziale (dal camera 2D corrente).
  final double zoom;

  /// Tracce disegnate da mostrare in 3D.
  final List<Track3D> tracks;

  @override
  State<Map3DScreen> createState() => _Map3DScreenState();
}

class _Map3DScreenState extends State<Map3DScreen> {
  MapboxMap? _map;

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null) return;

    // Terreno 3D: DEM Mapbox + esagerazione del rilievo.
    await map.style.addSource(RasterDemSource(
      id: 'mapbox-dem',
      url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
      tileSize: 514,
    ));
    await map.style.setStyleTerrain(jsonEncode(<String, Object>{
      'source': 'mapbox-dem',
      'exaggeration': 1.4,
    }));

    // Tracce disegnate: linee pulite con casing bianco.
    final tracks = widget.tracks.where((t) => t.points.length >= 2).toList();
    if (tracks.isNotEmpty) {
      final manager = await map.annotations.createPolylineAnnotationManager();
      for (final t in tracks) {
        await manager.create(PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: [
              for (final p in t.points) Position(p.longitude, p.latitude),
            ],
          ),
          lineColor: t.color.toARGB32(),
          lineWidth: 4.0,
          lineBorderColor: 0xFFFFFFFF,
          lineBorderWidth: 1.0,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            styleUri: MapboxStyles.OUTDOORS,
            onMapCreated: (map) {
              _map = map;
              // Zoom minimo per valorizzare il rilievo: da una vista regionale
              // il 3D risulterebbe quasi piatto.
              final zoom = widget.zoom < 13 ? 13.0 : widget.zoom;
              map.setCamera(CameraOptions(
                center: Point(
                  coordinates:
                      Position(widget.center.longitude, widget.center.latitude),
                ),
                zoom: zoom,
                pitch: 70,
              ));
            },
            onStyleLoadedListener: _onStyleLoaded,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Indietro',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
