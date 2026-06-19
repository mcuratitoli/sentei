import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Vista 3D del terreno (stile Suunto): Mapbox Outdoors + terreno 3D (DEM
/// Mapbox) con pitch. Sola visualizzazione — l'editing resta nella mappa 2D
/// (flutter_map). Mostra anche la traccia selezionata, se passata.
///
/// Richiede il token Mapbox (inizializzato in `main.dart`). Senza token la
/// `MapWidget` mostra una vista vuota: il pulsante "3D" è nascosto in quel caso.
class Map3DScreen extends StatefulWidget {
  const Map3DScreen({
    super.key,
    required this.center,
    required this.zoom,
    this.trackPoints,
    this.trackColor,
  });

  /// Centro iniziale (dal camera 2D corrente).
  final ll.LatLng center;

  /// Zoom iniziale (dal camera 2D corrente).
  final double zoom;

  /// Punti della traccia selezionata da disegnare in 3D (opzionale).
  final List<ll.LatLng>? trackPoints;

  /// Colore della traccia selezionata.
  final Color? trackColor;

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

    // Traccia selezionata (se presente): linea pulita con casing bianco.
    final pts = widget.trackPoints;
    if (pts != null && pts.length >= 2) {
      final manager = await map.annotations.createPolylineAnnotationManager();
      final color = (widget.trackColor ?? const Color(0xFF1565C0)).toARGB32();
      await manager.create(PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: [
            for (final p in pts) Position(p.longitude, p.latitude),
          ],
        ),
        lineColor: color,
        lineWidth: 4.0,
        lineBorderColor: 0xFFFFFFFF,
        lineBorderWidth: 1.0,
      ));
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
