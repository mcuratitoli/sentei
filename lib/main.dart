import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Token pubblico Mapbox (lo stesso `pk....` usato per le tile raster),
  // necessario alla vista 3D. Iniettato via --dart-define=MAPBOX_TOKEN.
  const mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');
  if (mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxToken);
  }
  runApp(
    const ProviderScope(
      child: SenteiApp(),
    ),
  );
}
