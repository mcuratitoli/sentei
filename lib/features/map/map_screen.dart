import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../data/location/location_service.dart';
import '../../data/map_sources/map_source.dart';
import '../../data/map_sources/map_sources.dart';
import '../draw_route/direction_arrows.dart';
import '../draw_route/draw_route_controls.dart';
import '../draw_route/route_editor_provider.dart';
import '../tracks_list/tracks_list_screen.dart';
import 'map_providers.dart';

/// Schermata mappa principale: visualizzazione + disegno tracciato con
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
    final editor = ref.watch(routeEditorProvider);
    final routedPath = ref.watch(routedPathProvider);
    final cursor = ref.watch(profileCursorProvider);
    final userPos = ref.watch(userLocationProvider);
    final fullscreen = ref.watch(fullscreenProvider);

    final attributions = <MapSource>[
      base,
      if (trailsOn) MapSources.waymarkedTrailsHiking,
    ];

    return Scaffold(
      appBar: fullscreen
          ? null
          : AppBar(
              title: const Text(AppConstants.appDisplayName),
              actions: [
                IconButton(
                  tooltip: editor.snapToTrail
                      ? 'Snap ai sentieri: ON'
                      : 'Snap ai sentieri: OFF',
                  icon:
                      Icon(editor.snapToTrail ? Icons.route : Icons.timeline),
                  color: editor.snapToTrail
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  onPressed: () =>
                      ref.read(routeEditorProvider.notifier).toggleSnap(),
                ),
                IconButton(
                  tooltip: 'Sentieri',
                  icon:
                      Icon(trailsOn ? Icons.hiking : Icons.hiking_outlined),
                  onPressed: () =>
                      ref.read(trailsOverlayEnabledProvider.notifier).toggle(),
                ),
                IconButton(
                  tooltip: 'Tracciati salvati',
                  icon: const Icon(Icons.list_alt),
                  onPressed: () => Navigator.of(context)
                      .pushNamed(TracksListScreen.routePath),
                ),
                _SourceMenu(selected: base),
              ],
            ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: AppConstants.defaultCenter,
              initialZoom: AppConstants.defaultZoom,
              minZoom: AppConstants.minZoom,
              maxZoom: AppConstants.maxZoom,
              // Lo zoom non deve ruotare la mappa: con la "gesture race" attiva
              // pinch-zoom e rotazione si escludono a vicenda, e la rotazione
              // richiede un gesto più deciso (soglia più alta).
              interactionOptions: const InteractionOptions(
                enableMultiFingerGestureRace: true,
                rotationThreshold: 30,
              ),
              onTap: editor.drawing
                  ? (_, point) =>
                      ref.read(routeEditorProvider.notifier).addPoint(point)
                  : null,
            ),
            children: [
              base.toTileLayer(),
              if (trailsOn) MapSources.waymarkedTrailsHiking.toTileLayer(),
              if ((routedPath.value?.length ?? 0) >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routedPath.value!,
                      strokeWidth: 4,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              const DirectionArrows(),
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
              if (editor.waypoints.isNotEmpty) const _WaypointMarkers(),
              _AttributionBox(sources: attributions),
            ],
          ),
          if (routedPath.isLoading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(),
            ),
          // Pulsanti flottanti: bussola (sx), localizza + fullscreen (dx).
          SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _Compass(controller: _mapController),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MapButton(
                          icon: fullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          tooltip: fullscreen
                              ? 'Esci da schermo intero'
                              : 'Schermo intero',
                          onPressed: () =>
                              ref.read(fullscreenProvider.notifier).toggle(),
                        ),
                        const SizedBox(height: 8),
                        _MapButton(
                          icon: Icons.my_location,
                          tooltip: 'La mia posizione',
                          highlighted: userPos != null,
                          onPressed: _locate,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!fullscreen)
            Align(
              alignment: Alignment.bottomCenter,
              child: const SafeArea(child: DrawRouteControls()),
            ),
        ],
      ),
      floatingActionButton: _buildFab(editor, fullscreen),
    );
  }

  Widget? _buildFab(RouteEditorState editor, bool fullscreen) {
    // In fullscreen il pannello (col toggle Fine) è nascosto: serve comunque un
    // modo per entrare/uscire dal disegno → FAB sempre presente.
    if (fullscreen) {
      return FloatingActionButton(
        onPressed: () => ref.read(routeEditorProvider.notifier).toggleDrawing(),
        child: Icon(editor.drawing ? Icons.check : Icons.edit_location_alt),
      );
    }
    // Stato iniziale: il FAB avvia il disegno; poi il toggle vive nel pannello.
    if (!editor.drawing && editor.waypoints.isEmpty) {
      return FloatingActionButton.extended(
        onPressed: () => ref.read(routeEditorProvider.notifier).toggleDrawing(),
        icon: const Icon(Icons.edit_location_alt),
        label: const Text('Disegna'),
      );
    }
    return null;
  }
}

/// Bottone tondo piccolo per i controlli mappa.
class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.highlighted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        iconSize: 20,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon,
            color: highlighted ? scheme.primary : scheme.onSurface),
      ),
    );
  }
}

/// Bussola che indica sempre il nord; al tap riporta il nord in alto.
class _Compass extends StatefulWidget {
  const _Compass({required this.controller});

  final MapController controller;

  @override
  State<_Compass> createState() => _CompassState();
}

class _CompassState extends State<_Compass> {
  double _rotation = 0;
  StreamSubscription<MapEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.controller.mapEventStream.listen((e) {
      if (e.camera.rotation != _rotation) {
        setState(() => _rotation = e.camera.rotation);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => widget.controller.rotate(0),
        child: Tooltip(
          message: 'Nord in alto',
          child: SizedBox(
            width: 40,
            height: 40,
            child: CustomPaint(
              painter: _CompassPainter(rotationDeg: _rotation),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({required this.rotationDeg});

  final double rotationDeg;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-rotationDeg * math.pi / 180.0);

    const half = 5.0;
    // Ago nord (rosso).
    final north = Path()
      ..moveTo(0, -r)
      ..lineTo(-half, 0)
      ..lineTo(half, 0)
      ..close();
    canvas.drawPath(north, Paint()..color = const Color(0xFFD32F2F));
    // Ago sud (grigio).
    final south = Path()
      ..moveTo(0, r)
      ..lineTo(-half, 0)
      ..lineTo(half, 0)
      ..close();
    canvas.drawPath(south, Paint()..color = const Color(0xFF9E9E9E));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.rotationDeg != rotationDeg;
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

/// Marker trascinabili per i waypoint. Drag (commit a rilascio) per spostare,
/// tap per eliminare.
class _WaypointMarkers extends ConsumerWidget {
  const _WaypointMarkers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waypoints = ref.watch(routeEditorProvider).waypoints;
    final scheme = Theme.of(context).colorScheme;
    const start = Color(0xFF2E7D32); // verde: partenza
    const end = Color(0xFFC62828); // rosso: arrivo
    final last = waypoints.length - 1;

    return DragMarkers(
      markers: [
        for (var i = 0; i < waypoints.length; i++)
          DragMarker(
            key: ValueKey('waypoint-$i'),
            point: waypoints[i],
            size: const Size(30, 30),
            // Commit solo a fine drag: evita di ri-instradare a ogni frame.
            onDragEnd: (_, latLng) =>
                ref.read(routeEditorProvider.notifier).movePoint(i, latLng),
            // Tap per eliminare un nodo piazzato per errore.
            onTap: (_) => ref.read(routeEditorProvider.notifier).removePoint(i),
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

/// Menu a tendina per scegliere il layer base.
class _SourceMenu extends ConsumerWidget {
  const _SourceMenu({required this.selected});

  final MapSource selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<MapSource>(
      tooltip: 'Sorgente mappa',
      icon: const Icon(Icons.layers),
      initialValue: selected,
      onSelected: (s) =>
          ref.read(selectedBaseSourceProvider.notifier).select(s),
      itemBuilder: (context) => [
        for (final s in MapSources.bases)
          PopupMenuItem<MapSource>(value: s, child: Text(s.name)),
      ],
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
