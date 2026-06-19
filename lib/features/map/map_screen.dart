import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../data/location/location_service.dart';
import '../../data/map_sources/map_source.dart';
import '../../data/map_sources/map_sources.dart';
import '../../domain/services/path_geometry.dart';
import '../draw_route/draw_route_controls.dart';
import '../draw_route/route_editor_provider.dart';
import '../settings/settings_screen.dart';
import '../tracks_list/tracks_list_screen.dart';
import 'map_providers.dart';

/// Schermata mappa principale: visualizzazione + disegno multi-traccia con
/// snap-to-trail (1.B + §6.2) + posizione GPS (1.A).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  static const String routeName = 'map';
  static const String routePath = '/';

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Tap fuori dal disegno: seleziona la traccia più vicina (entro soglia),
  /// altrimenti deseleziona.
  void _handleMapTap(LatLng point) {
    final notifier = ref.read(tracksProvider.notifier);
    final tracks = ref.read(tracksProvider).tracks;
    final zoom = _mapController.camera.zoom;
    final metersPerPixel = 156543.03392 *
        math.cos(point.latitude * math.pi / 180.0) /
        math.pow(2, zoom);
    final threshold = 22 * metersPerPixel; // ~22 px di tolleranza

    String? nearestId;
    var best = double.infinity;
    for (final t in tracks) {
      final path = t.routedPath.length >= 2
          ? t.routedPath
          : (ref.read(livePathProvider(t.id)).value ?? const <LatLng>[]);
      if (path.length < 2) continue;
      final d = const PathGeometry().distanceToPath(point, path);
      if (d < best) {
        best = d;
        nearestId = t.id;
      }
    }
    if (nearestId != null && best <= threshold) {
      notifier.select(nearestId);
    } else {
      notifier.deselect();
    }
  }

  Future<void> _locate() async {
    try {
      final pos = await ref.read(userLocationProvider.notifier).locate();
      _mapController.move(pos, 15);
    } on LocationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.watch(selectedBaseSourceProvider);
    final trailsOn = ref.watch(trailsOverlayEnabledProvider);
    final tracks = ref.watch(tracksProvider);
    final cursor = ref.watch(profileCursorProvider);
    final userPos = ref.watch(userLocationProvider);

    final attributions = <MapSource>[
      base,
      if (trailsOn) MapSources.waymarkedTrailsHiking,
    ];

    // Lavoro in corso: calcolo percorso (a ogni nodo) o salvataggio post-Fine.
    final editingId = tracks.editingId;
    final busy = tracks.saving ||
        (editingId != null &&
            ref.watch(livePathProvider(editingId)).isLoading);

    return Scaffold(
      // Niente AppBar: i controlli sono pulsanti flottanti, identici in
      // fullscreen e non.
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: AppConstants.defaultCenter,
              initialZoom: AppConstants.defaultZoom,
              minZoom: AppConstants.minZoom,
              maxZoom: AppConstants.maxZoom,
              // Lo zoom non deve ruotare la mappa (gesture race + soglia alta).
              interactionOptions: const InteractionOptions(
                enableMultiFingerGestureRace: true,
                rotationThreshold: 30,
              ),
              onTap: (_, point) {
                if (tracks.drawing) {
                  ref.read(tracksProvider.notifier).addPoint(point);
                } else {
                  _handleMapTap(point);
                }
              },
            ),
            children: [
              // IGN copre in dettaglio solo la Francia (404 sul versante
              // italiano ad alto zoom): sotto mettiamo OpenTopoMap come
              // fallback, così l'area italiana resta leggibile invece di
              // mostrare buchi vuoti.
              if (base.id == MapSources.ignPlan.id)
                MapSources.openTopoMap.toTileLayer(muted: true),
              base.toTileLayer(muted: base.muteByDefault),
              // Overlay sentieri attenuato: presente ma non "urlante", così la
              // mappa resta pulita (stile GaiaGPS) senza perdere i tracciati.
              if (trailsOn)
                Opacity(
                  opacity: 0.55,
                  child: MapSources.waymarkedTrailsHiking.toTileLayer(),
                ),
              const _TracksLayer(),
              const _EndpointMarkers(),
              if (tracks.drawing) const _WaypointMarkers(),
              if (userPos != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userPos,
                      width: 22,
                      height: 22,
                      child: const _UserLocationDot(),
                    ),
                  ],
                ),
              if (cursor != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: cursor.position,
                      width: 22,
                      height: 22,
                      child: _CursorDot(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ),
              _AttributionBox(sources: attributions),
            ],
          ),
          if (busy)
            const SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(),
              ),
            ),
          // Card del tracciato (sopra) + barra flottante in basso.
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DrawRouteControls(),
                  _BottomBar(
                    onOrientNorth: () => _mapController.rotate(0),
                    onLocate: _locate,
                    onNewTrack:
                        ref.read(tracksProvider.notifier).startNewDrawing,
                    onTracks: () => context.push(TracksListScreen.routePath),
                    onSettings: () => context.push(SettingsScreen.routePath),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Polilinee di tutte le tracce (ognuna nel suo colore; la attiva più spessa).
/// La traccia in fase di salvataggio (`savingId`) pulsa come effetto di loading.
class _TracksLayer extends ConsumerStatefulWidget {
  const _TracksLayer();

  @override
  ConsumerState<_TracksLayer> createState() => _TracksLayerState();
}

class _TracksLayerState extends ConsumerState<_TracksLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: 1,
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(tracksProvider);

    // Anima solo quando una traccia sta salvando.
    if (st.savingId != null) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1;
    }

    // Percorsi (memorizzati per le tracce finalizzate, live in modifica).
    final entries = <(DrawnTrack, List<LatLng>)>[];
    for (final t in st.tracks) {
      final path = t.routedPath.length >= 2
          ? t.routedPath
          : (ref.watch(livePathProvider(t.id)).value ?? const <LatLng>[]);
      if (path.length >= 2) entries.add((t, path));
    }

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final pulse = 0.3 + 0.7 * _pulse.value;
        final activeId = st.activeId;
        // Ordine di disegno: prima le tracce non attive, poi quella attiva in
        // cima, così il tratto selezionato non resta coperto.
        final ordered = [...entries]
          ..sort((a, b) => (a.$1.id == activeId ? 1 : 0)
              .compareTo(b.$1.id == activeId ? 1 : 0));
        return PolylineLayer(
          polylines: [
            for (final (t, path) in ordered)
              Polyline(
                points: path,
                // Tratto pulito stile GaiaGPS: linea piena con sottile casing
                // bianco e estremità/giunzioni arrotondate (meno "spigoloso").
                strokeWidth: t.id == activeId ? 5 : 4,
                color: t.id == st.savingId
                    ? t.color.withValues(alpha: pulse)
                    : t.color,
                borderStrokeWidth: t.id == activeId ? 3 : 2,
                borderColor: Colors.white.withValues(alpha: 0.85),
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
          ],
        );
      },
    );
  }
}

/// Marker statici di partenza/arrivo per le tracce non in modifica.
class _EndpointMarkers extends ConsumerWidget {
  const _EndpointMarkers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(tracksProvider);
    final markers = <Marker>[];
    for (final t in st.tracks) {
      if (t.id == st.editingId || t.waypoints.isEmpty) continue;
      markers.add(_dot(t.waypoints.first, const Color(0xFF2E7D32),
          Icons.play_arrow));
      if (t.waypoints.length > 1) {
        markers.add(_dot(t.waypoints.last, const Color(0xFFC62828), Icons.flag));
      }
    }
    return MarkerLayer(markers: markers);
  }

  Marker _dot(LatLng p, Color color, IconData icon) => Marker(
        point: p,
        width: 28,
        height: 28,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)],
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      );
}

/// Marker trascinabili per i waypoint della traccia in modifica.
/// Drag (commit a rilascio) per spostare, tap per eliminare.
class _WaypointMarkers extends ConsumerWidget {
  const _WaypointMarkers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editing = ref.watch(tracksProvider).editing;
    if (editing == null) return const SizedBox.shrink();
    final waypoints = editing.waypoints;
    final scheme = Theme.of(context).colorScheme;
    const start = Color(0xFF2E7D32);
    const end = Color(0xFFC62828);
    final last = waypoints.length - 1;

    return DragMarkers(
      markers: [
        for (var i = 0; i < waypoints.length; i++)
          DragMarker(
            key: ValueKey('waypoint-${editing.id}-$i'),
            point: waypoints[i],
            size: const Size(30, 30),
            onDragEnd: (_, latLng) =>
                ref.read(tracksProvider.notifier).movePoint(i, latLng),
            onTap: (_) => ref.read(tracksProvider.notifier).removePoint(i),
            builder: (context, point, isDragging) {
              final isStart = i == 0;
              final isEnd = i == last && last > 0;
              final fill = isStart
                  ? start
                  : isEnd
                      ? end
                      : scheme.surface;
              final icon = isStart
                  ? Icons.play_arrow
                  : isEnd
                      ? Icons.flag
                      : null;
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: Border.all(
                      color: isStart || isEnd ? Colors.white : scheme.primary,
                      width: 2),
                  boxShadow: isDragging
                      ? [const BoxShadow(blurRadius: 6, color: Colors.black38)]
                      : const [BoxShadow(blurRadius: 2, color: Colors.black26)],
                ),
                child: icon == null
                    ? null
                    : Icon(icon, size: 16, color: Colors.white),
              );
            },
          ),
      ],
    );
  }
}


/// Barra flottante in basso (stile dock iOS): nord · posizione · + · tracce · impostazioni.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onOrientNorth,
    required this.onLocate,
    required this.onNewTrack,
    required this.onTracks,
    required this.onSettings,
  });

  final VoidCallback onOrientNorth;
  final VoidCallback onLocate;
  final VoidCallback onNewTrack;
  final VoidCallback onTracks;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        elevation: 6,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Orienta a nord',
                icon: const Icon(Icons.explore_outlined),
                onPressed: onOrientNorth,
              ),
              IconButton(
                tooltip: 'La mia posizione',
                icon: const Icon(Icons.my_location),
                onPressed: onLocate,
              ),
              // + centrale (colore primario, in evidenza).
              _PlusButton(onTap: onNewTrack),
              IconButton(
                tooltip: 'Tracciati salvati',
                icon: const Icon(Icons.list_alt),
                onPressed: onTracks,
              ),
              IconButton(
                tooltip: 'Impostazioni',
                icon: const Icon(Icons.settings_outlined),
                onPressed: onSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottone "+" centrale della barra, in evidenza col colore primario.
class _PlusButton extends StatelessWidget {
  const _PlusButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: scheme.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Tooltip(
              message: 'Nuova traccia',
              child: Icon(Icons.add, color: scheme.onPrimary, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pallino blu della posizione utente.
class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1E88E5),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black45)],
      ),
    );
  }
}

/// Pallino di evidenziazione del punto scrubbed sul profilo altimetrico.
class _CursorDot extends StatelessWidget {
  const _CursorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black45)],
      ),
    );
  }
}

/// Box di attribuzione: obbligatorio per OSM/OpenTopoMap/SwissTopo/IGN (§11).
class _AttributionBox extends StatelessWidget {
  const _AttributionBox({required this.sources});

  final List<MapSource> sources;

  @override
  Widget build(BuildContext context) {
    return RichAttributionWidget(
      alignment: AttributionAlignment.bottomRight,
      attributions: [
        for (final s in sources)
          TextSourceAttribution(
            s.attribution,
            onTap: s.attributionUrl == null
                ? null
                : () => launchUrl(Uri.parse(s.attributionUrl!)),
          ),
      ],
    );
  }
}
