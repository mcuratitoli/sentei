import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/theme_provider.dart';
import 'data/logging/app_log_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Presto, prima di ogni altra cosa che potrebbe loggare (routing, export,
  // ecc.): nessuna riga persa. Vedi `app_log_service.dart`.
  await AppLogService.instance.install();
  // Token pubblico Mapbox (lo stesso `pk....` usato per le tile raster),
  // necessario alla vista 3D. Iniettato via --dart-define=MAPBOX_TOKEN.
  const mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');
  if (mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxToken);
  }
  // Tema/variante letti **prima** di `runApp`: senza, il primo frame parte
  // sempre da Automatico (in attesa del restore asincrono da
  // shared_preferences) e — con tema impostato manualmente ma sistema in
  // Dark Mode — mostra per un istante lo Scuro di sistema invece del Chiaro
  // scelto dall'utente.
  final prefs = await SharedPreferences.getInstance();
  final initialThemeMode = AppThemeModeController.readFrom(prefs);
  final initialDarkVariant = AppDarkVariantController.readFrom(prefs);
  runApp(
    ProviderScope(
      overrides: [
        appThemeModeProvider
            .overrideWith(() => AppThemeModeController(initialThemeMode)),
        appDarkVariantProvider
            .overrideWith(() => AppDarkVariantController(initialDarkVariant)),
      ],
      child: const SenteiApp(),
    ),
  );
}
