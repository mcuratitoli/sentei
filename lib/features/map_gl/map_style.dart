import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Stile della mappa. Default: Mapbox **Outdoors** (topo stock migliore).
/// Sovrascrivibile con uno stile Mapbox Studio dedicato (simil-GaiaGPS) senza
/// toccare il codice: `--dart-define=MAP_STYLE_URI=mapbox://styles/<user>/<id>`.
const String _envMapStyle = String.fromEnvironment('MAP_STYLE_URI');

/// Stile "mappa" (topografico). L'override d'ambiente vince se presente.
String get outdoorsMapStyleUri =>
    _envMapStyle.isEmpty ? MapboxStyles.OUTDOORS : _envMapStyle;

/// Stile **satellite** con strade/etichette (utile in escursione: si vedono
/// nomi e sentieri sopra l'ortofoto). **Invariato** col tema app (l'ortofoto
/// non ha un "verso scuro" sensato, per decisione utente).
const String satelliteMapStyleUri =
    'mapbox://styles/mapbox/satellite-streets-v12';

/// Stile **scuro** usato al posto di Outdoors quando il tema è scuro
/// (automatico, coordinato col tema — non una scelta separata dell'utente).
/// `dark-v11` è uno stile Mapbox generico ("data visualization"), non tarato
/// per l'escursionismo: buona parte del carattere outdoor di Sentèi resta
/// comunque nei layer nostri sopra (hillshade, terreno 3D, sentieri CAI).
/// Vedi `docs/eval-dark-map.md`.
const String darkMapStyleUri = MapboxStyles.DARK;
