import 'dart:async';
import 'dart:convert';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx
    show Size;

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

/// Cattura una mappa Mapbox 3D inquadrata sull'intero percorso, col
/// tracciato disegnato sopra — per l'export immagine (§export, `docs/
/// ROADMAP.md`).
///
/// **Due mappe Mapbox coinvolte, con ruoli distinti** (non una sola, come nel
/// primo tentativo): una `MapWidget` interattiva, mostrata a schermo, usata
/// **solo** per calcolare — con `pixelForCoordinate`, che non dipende dai
/// tile caricati — le posizioni in pixel di partenza/arrivo/POI; e uno
/// [Snapshotter] headless nativo, usato per l'immagine raster vera e propria.
/// Il primo tentativo catturava l'immagine con `RepaintBoundary.toImage()`
/// sulla `MapWidget` stessa: funzionava (nessun errore) ma il contenuto
/// restava vuoto — la view nativa Mapbox incorporata come platform view
/// Flutter non renderizza tile in modo affidabile quando non è lei stessa,
/// letteralmente, il contenuto a schermo intero mostrato all'utente (né a
/// opacità zero né fuori dai bordi della finestra: verificato con entrambe,
/// stessi byte identici indipendentemente dal tempo di attesa). Lo
/// [Snapshotter] non ha questo problema: è pensato apposta per generare
/// un'immagine senza passare dalla vista interattiva.
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
    this.bearing = 0,
  });

  final List<ll.LatLng> path;
  final Color routeColor;
  final List<PoiCandidate> pois;
  final Size size;
  final ValueChanged<RouteSnapshotResult?> onResult;

  /// Direzione (gradi, 0–360) verso cui la camera è orientata: **non** il
  /// nord di default, ma quella calcolata da `elevationOrientationBearing`
  /// perché il punto più basso del percorso resti in basso nell'immagine e
  /// quello più alto in alto (richiesta esplicita dell'utente).
  final double bearing;

  @override
  State<RouteSnapshotCapture> createState() => _RouteSnapshotCaptureState();
}

class _RouteSnapshotCaptureState extends State<RouteSnapshotCapture> {
  MapboxMap? _map;
  Snapshotter? _snapshotter;
  bool _mapStyleReady = false;
  bool _snapshotterStyleReady = false;
  bool _done = false;
  Timer? _failSafe;

  @override
  void initState() {
    super.initState();
    // Rete assente o stile mai pronto: non deve restare in caricamento
    // all'infinito, l'export deve comunque poter fallire con un messaggio.
    _failSafe = Timer(const Duration(seconds: 25), () {
      debugPrint('[export] timeout 25s (mapReady=$_mapStyleReady, '
          'snapshotterReady=$_snapshotterStyleReady)');
      _finish(null);
    });
    _createSnapshotter();
  }

  @override
  void dispose() {
    _failSafe?.cancel();
    _snapshotter?.dispose();
    super.dispose();
  }

  /// [widget.size] convertita nel tipo `Size` del plugin Mapbox (omonimo di
  /// `dart:ui`'s `Size`, usato altrove in questo file — da cui l'`hide`
  /// sull'import principale e questo import separato con prefisso).
  mbx.Size get _mbxSize =>
      mbx.Size(width: widget.size.width, height: widget.size.height);

  void _finish(RouteSnapshotResult? result) {
    if (_done) return;
    _done = true;
    _failSafe?.cancel();
    widget.onResult(result);
  }

  Future<void> _createSnapshotter() async {
    try {
      final snapshotter = await Snapshotter.create(
        options: MapSnapshotOptions(size: _mbxSize, pixelRatio: 3),
        onStyleLoadedListener: (_) async {
          debugPrint('[export] snapshotter onStyleLoaded');
          if (_done) return;
          try {
            await _configureStyle(_snapshotter!.style);
            _snapshotterStyleReady = true;
            await _maybeCapture();
          } catch (e, st) {
            debugPrint('[export] snapshotter configureStyle fallito: $e\n$st');
            _finish(null);
          }
        },
      );
      _snapshotter = snapshotter;
      await snapshotter.style.setStyleURI(outdoorsMapStyleUri);
    } catch (e, st) {
      debugPrint('[export] Snapshotter.create fallito: $e\n$st');
      _finish(null);
    }
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    debugPrint('[export] onMapCreated');
    _map = map;
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    debugPrint('[export] onStyleLoaded (map=${_map != null}, done=$_done)');
    final map = _map;
    if (map == null || _done) return;
    try {
      await _configureStyle(map.style);
      _mapStyleReady = true;
      await _maybeCapture();
    } catch (e, st) {
      debugPrint('[export] map configureStyle fallito: $e\n$st');
      _finish(null);
    }
  }

  /// Setup di stile condiviso fra la `MapWidget` interattiva e lo
  /// [Snapshotter] headless: stesso terreno 3D e stesso tracciato, in modo
  /// che l'immagine catturata e le posizioni pixel calcolate sull'altra
  /// mappa restino coerenti fra loro.
  Future<void> _configureStyle(StyleManager style) async {
    await style.addSource(RasterDemSource(
      id: 'sentei-export-dem',
      url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
      tileSize: 514,
    ));
    await style.setStyleTerrain(jsonEncode(<String, Object>{
      'source': 'sentei-export-dem',
      'exaggeration': 1.5,
    }));
    await style.addLayer(SkyLayer(
      id: 'sentei-export-sky',
      skyType: SkyType.ATMOSPHERE,
      skyAtmosphereSunIntensity: 10,
    ));
    await style.addLayer(HillshadeLayer(
      id: 'sentei-export-hillshade',
      sourceId: 'sentei-export-dem',
      hillshadeExaggeration: 0.5,
      hillshadeShadowColor: 0x59413A33,
      hillshadeHighlightColor: 0x33FFFFFF,
    ));

    // Traccia come sorgente/layer di stile (non annotation manager: lo
    // Snapshotter non ha un `.annotations`) — bordo bianco sotto, linea
    // colorata sopra, stesso effetto "alone" delle annotation sulla mappa
    // principale.
    final routeGeoJson = jsonEncode(<String, Object>{
      'type': 'Feature',
      'geometry': <String, Object>{
        'type': 'LineString',
        'coordinates': [
          for (final p in widget.path) [p.longitude, p.latitude],
        ],
      },
    });
    await style.addSource(
        GeoJsonSource(id: 'sentei-export-route', data: routeGeoJson));
    await style.addLayer(LineLayer(
      id: 'sentei-export-route-halo',
      sourceId: 'sentei-export-route',
      lineColor: 0xFFFFFFFF,
      lineWidth: 9,
      lineJoin: LineJoin.ROUND,
      lineCap: LineCap.ROUND,
    ));
    await style.addLayer(LineLayer(
      id: 'sentei-export-route-line',
      sourceId: 'sentei-export-route',
      lineColor: widget.routeColor.toARGB32(),
      lineWidth: 5,
      lineJoin: LineJoin.ROUND,
      lineCap: LineCap.ROUND,
    ));
  }

  /// Quando **entrambe** le mappe hanno lo stile pronto: calcola la camera
  /// sulla mappa interattiva (serve a `pixelForCoordinate`, che non dipende
  /// dai tile caricati — funziona subito dopo `setCamera`), la applica a
  /// entrambe, avvia lo Snapshotter per l'immagine e legge le posizioni
  /// pixel dalla mappa interattiva.
  Future<void> _maybeCapture() async {
    if (_done || !_mapStyleReady || !_snapshotterStyleReady) return;
    final map = _map;
    final snapshotter = _snapshotter;
    if (map == null || snapshotter == null) return;
    try {
      // Include anche i POI nell'inquadratura, non solo il percorso: una
      // cima o un rifugio spesso **non** sono esattamente sul sentiero (fino
      // a 500 m, la soglia di `NearbyPoisMatcher`) — se restano fuori dal
      // riquadro stretto della sola traccia, `pixelForCoordinate` per quel
      // punto torna `(-1,-1)` (fuori dalla vista, verificato coi log
      // `[export]`: "Cima Mutta" appariva con quel pallino) e l'etichetta
      // finisce in un angolo senza senso.
      final points = [
        for (final p in widget.path) Point(coordinates: Position(p.longitude, p.latitude)),
        for (final poi in widget.pois)
          Point(coordinates:
              Position(poi.position.longitude, poi.position.latitude)),
      ];
      // Padding basso generoso: lascia spazio, nell'immagine finale, alla
      // card di nome+statistiche disegnata sopra (§export_image_screen).
      // ignore: deprecated_member_use
      final camera = await map.cameraForCoordinates(
        points,
        MbxEdgeInsets(
          top: widget.size.height * 0.06,
          left: widget.size.width * 0.07,
          right: widget.size.width * 0.07,
          bottom: widget.size.height * 0.36,
        ),
        widget.bearing,
        55,
      );
      await map.setCamera(camera);
      await snapshotter.setSize(_mbxSize);
      await snapshotter.setCamera(camera);

      final bytes = await snapshotter.start();
      if (_done) return;
      if (bytes == null) {
        debugPrint('[export] snapshotter.start() ha ritornato null');
        _finish(null);
        return;
      }
      debugPrint('[export] snapshot catturato: ${bytes.lengthInBytes} byte');

      final poiPixels = <String, Offset>{};
      for (final poi in widget.pois) {
        final px = await map.pixelForCoordinate(Point(
            coordinates:
                Position(poi.position.longitude, poi.position.latitude)));
        // `pixelForCoordinate` torna (-1,-1) per un punto fuori dalla vista
        // (verificato: la camera ora include anche i POI nell'inquadratura,
        // quindi non dovrebbe più succedere — ma se capita comunque, es. per
        // un arrotondamento ai bordi, meglio **non mostrare** quel POI che
        // mostrarlo in un angolo a caso senza senso).
        final inBounds = px.x >= 0 &&
            px.y >= 0 &&
            px.x <= widget.size.width &&
            px.y <= widget.size.height;
        debugPrint('[export] POI "${poi.name}" dot=(${px.x.toStringAsFixed(0)},'
            '${px.y.toStringAsFixed(0)})${inBounds ? '' : ' FUORI INQUADRATURA, escluso'}');
        if (inBounds) poiPixels[poi.id] = Offset(px.x, px.y);
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

      _finish(RouteSnapshotResult(
        mapImage: bytes,
        logicalSize: widget.size,
        poiPixels: poiPixels,
        startPixel: startPixel,
        endPixel: endPixel,
      ));
    } catch (e, st) {
      debugPrint('[export] _maybeCapture fallito: $e\n$st');
      _finish(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size.width,
      height: widget.size.height,
      child: MapWidget(
        styleUri: outdoorsMapStyleUri,
        onMapCreated: _onMapCreated,
        onStyleLoadedListener: _onStyleLoaded,
      ),
    );
  }
}
