import 'package:go_router/go_router.dart';

import '../features/map/map_screen.dart';
import '../features/map_gl/map_gl_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tracks_list/tracks_list_screen.dart';

/// Configurazione di routing dell'app (go_router).
///
/// Le rotte oltre la mappa e la lista tracciati sono placeholder che verranno
/// riempiti seguendo la roadmap (§7).
final appRouter = GoRouter(
  // TEMP(spike Fase 0): home sullo spike GL. Ripristinare a MapScreen.routePath.
  initialLocation: MapGlScreen.routePath,
  routes: <RouteBase>[
    GoRoute(
      path: MapScreen.routePath,
      name: MapScreen.routeName,
      builder: (context, state) => const MapScreen(),
    ),
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
