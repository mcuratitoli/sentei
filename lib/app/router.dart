import 'package:go_router/go_router.dart';

import '../features/map_gl/map_gl_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tracks_list/tracks_list_screen.dart';

/// Configurazione di routing dell'app (go_router). La mappa principale è su
/// Mapbox GL (`MapGlScreen`).
final appRouter = GoRouter(
  initialLocation: MapGlScreen.routePath,
  routes: <RouteBase>[
    GoRoute(
      path: MapGlScreen.routePath,
      name: MapGlScreen.routeName,
      builder: (context, state) => const MapGlScreen(),
    ),
    GoRoute(
      path: TracksListScreen.routePath,
      name: TracksListScreen.routeName,
      builder: (context, state) => const TracksListScreen(),
    ),
    GoRoute(
      path: SettingsScreen.routePath,
      name: SettingsScreen.routeName,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
