import 'dart:async';
import 'dart:convert';
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../domain/models/point_of_interest.dart';
import '../../map_gl/map_style.dart';

/// Esito della cattura di [RouteSnapshotCapture]: l'immagine raster della
/// mappa 3D col tracciato (nessuna sovrimpressione: nome/quote/etichette POI
/// sono widget Flutter veri, disegnati **sopra** questa immagine in
/// `export_image_screen.dart`, non "cotti" nel raster) più le posizioni in
/// pixel — nello stesso spazio logico di [logicalSize] — di partenza, arrivo
/// e di ciascun POI, calcolate con la stessa camera usata per l'immagine.
class RouteSnapshotResult {
  const RouteSnapshotResult({
    required this.mapImage,
    required this.logicalSize,
    required this.poiPixels,
    this.startPixel,
    this.endPixel,
  });

  final Uint8List mapImage;
  final Size logicalSize;

  /// Posizione in pixel di ogni [PoiCandidate], per `id`.
  final Map<String, Offset> poiPixels;
  final Offset? startPixel;
  final Offset? endPixel;
}

/// Cattura **offscreen** una mappa Mapbox 3D inquadrata sull'intero percorso,
/// col tracciato disegnato sopra — per l'export immagine (§export, `docs/
/// ROADMAP.md`). Non è mai mostrata all'utente: il chiamante la posiziona
/// fuori dallo schermo (`Positioned` con coordinate negative) dentro un
/// proprio `Stack`, la include finché [onResult] non è stato chiamato, poi
/// la rimuove dall'albero.
///
/// Riusa lo stesso terreno 3D (DEM + esagerazione 1.5, cielo atmosferico,
/// hillshade) della mappa principale (`map_gl_screen.dart` →
/// `_styleSetup`), sempre in stile **Outdoors chiaro** (l'immagine esportata
/// non segue il tema scuro dell'app: deve restare leggibile come una
/// cartina, indipendentemente da come l'utente ha impostato Sentèi).
class RouteSnapshotCapture extends StatefulWidget {
  const RouteSnapshotCapture({
    super.key,
    required this.path,
    required this.routeColor,
    required this.pois,
    required this.onResult,
    this.size = const Size(360, 450),
  });

  final List<ll.LatLng> path;
  final Color routeColor;
  final List<PoiCandidate> pois;
  final Size size;
  final ValueChanged<RouteSnapshotResult?> onResult;

  @override
  State<RouteSnapshotCapture> createState() => _RouteSnapshotCaptureState();
}

class _RouteSnapshotCaptureState extends State<RouteSnapshotCapture> {
  final _boundaryKey = GlobalKey();
  MapboxMap? _map;
  bool _cameraSet = false;
  bool _done = false;
  Timer? _failSafe;

  @override
  void initState() {
    super.initState();
    // Rete assente o stile mai pronto: non deve restare in caricamento
    // all'infinito, l'export deve comunque poter fallire con un messaggio.
    _failSafe = Timer(const Duration(seconds: 20), () => _finish(null));
  }

  @override
  void dispose() {
    _failSafe?.cancel();
    super.dispose();
  }

  void _finish(RouteSnapshotResult? result) {
    if (_done) return;
    _done = true;
    _failSafe?.cancel();
    widget.onResult(result);
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null || _done) return;
    try {
      await map.style.addSource(RasterDemSource(
        id: 'sentei-export-dem',
        url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
        tileSize: 514,
      ));
      await map.style.setStyleTerrain(jsonEncode(<String, Object>{
        'source': 'sentei-export-dem',
        'exaggeration': 1.5,
      }));
      await map.style.addLayer(SkyLayer(
        id: 'sentei-export-sky',
        skyType: SkyType.ATMOSPHERE,
        skyAtmosphereSunIntensity: 10,
      ));
      await map.style.addLayer(HillshadeLayer(
        id: 'sentei-export-hillshade',
        sourceId: 'sentei-export-dem',
        hillshadeExaggeration: 0.5,
        hillshadeShadowColor: 0x59413A33,
        hillshadeHighlightColor: 0x33FFFFFF,
      ));

      final lines = await map.annotations.createPolylineAnnotationManager();
      await lines.create(PolylineAnnotationOptions(
        geometry: LineString(coordinates: [
          for (final p in widget.path) Position(p.longitude, p.latitude),
        ]),
        lineColor: widget.routeColor.toARGB32(),
        lineWidth: 5,
        lineBorderColor: 0xFFFFFFFF,
        lineBorderWidth: 2,
      ));

      final points = [
        for (final p in widget.path) Point(coordinates: Position(p.longitude, p.latitude)),
      ];
      // Padding basso generoso: lascia spazio, nell'immagine finale, alla
      // card di nome+statistiche disegnata sopra (§export_image_screen).
      // ignore: deprecated_member_use
      final camera = await map.cameraForCoordinates(
        points,
        MbxEdgeInsets(
          top: widget.size.height * 0.12,
          left: widget.size.width * 0.14,
          right: widget.size.width * 0.14,
          bottom: widget.size.height * 0.42,
        ),
        0,
        55,
      );
      await map.setCamera(camera);
      _cameraSet = true;
    } catch (_) {
      _finish(null);
    }
  }

  Future<void> _onMapIdle(MapIdleEventData _) async {
    if (!_cameraSet || _done) return;
    final map = _map;
    if (map == null) return;
    try {
      final poiPixels = <String, Offset>{};
      for (final poi in widget.pois) {
        final px = await map.pixelForCoordinate(Point(
            coordinates:
                Position(poi.position.longitude, poi.position.latitude)));
        poiPixels[poi.id] = Offset(px.x, px.y);
      }
      Offset? startPixel, endPixel;
      if (widget.path.isNotEmpty) {
        final s = widget.path.first;
        final sp = await map.pixelForCoordinate(
            Point(coordinates: Position(s.longitude, s.latitude)));
        startPixel = Offset(sp.x, sp.y);
        final e = widget.path.last;
        final ep = await map.pixelForCoordinate(
            Point(coordinates: Position(e.longitude, e.latitude)));
        endPixel = Offset(ep.x, ep.y);
      }

      // Un frame in più: `onMapIdle` può scattare appena prima che l'ultimo
      // frame renderizzato sia effettivamente compositato nel layer tree
      // catturabile da `RepaintBoundary`.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _finish(null);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        _finish(null);
        return;
      }
      _finish(RouteSnapshotResult(
        mapImage: bytes.buffer.asUint8List(),
        logicalSize: widget.size,
        poiPixels: poiPixels,
        startPixel: startPixel,
        endPixel: endPixel,
      ));
    } catch (_) {
      _finish(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size.width,
      height: widget.size.height,
      child: RepaintBoundary(
        key: _boundaryKey,
        child: MapWidget(
          styleUri: outdoorsMapStyleUri,
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
          onMapIdleListener: _onMapIdle,
        ),
      ),
    );
  }
}
