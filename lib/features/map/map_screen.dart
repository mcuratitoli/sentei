import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../data/map_sources/map_source.dart';
import '../../data/map_sources/map_sources.dart';
import '../draw_route/direction_arrows.dart';
import '../draw_route/draw_route_controls.dart';
import '../draw_route/route_editor_provider.dart';
import '../tracks_list/tracks_list_screen.dart';
import 'map_providers.dart';

/// Schermata mappa principale: visualizzazione + disegno tracciato con
/// snap-to-trail (1.B + §6.2).
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

  @override
  Widget build(BuildContext context) {
    final base = ref.watch(selectedBaseSourceProvider);
    final trailsOn = ref.watch(trailsOverlayEnabledProvider);
    final editor = ref.watch(routeEditorProvider);
    final routedPath = ref.watch(routedPathProvider);
    final cursor = ref.watch(profileCursorProvider);

    final attributions = <MapSource>[
      base,
      if (trailsOn) MapSources.waymarkedTrailsHiking,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appDisplayName),
        actions: [
          IconButton(
            tooltip: editor.snapToTrail
                ? 'Snap ai sentieri: ON'
                : 'Snap ai sentieri: OFF',
            icon: Icon(editor.snapToTrail ? Icons.route : Icons.timeline),
            color: editor.snapToTrail
                ? Theme.of(context).colorScheme.primary
                : null,
            onPressed: () => ref.read(routeEditorProvider.notifier).toggleSnap(),
          ),
          IconButton(
            tooltip: 'Sentieri',
            icon: Icon(trailsOn ? Icons.hiking : Icons.hiking_outlined),
            onPressed: () =>
                ref.read(trailsOverlayEnabledProvider.notifier).toggle(),
          ),
          IconButton(
            tooltip: 'Tracciati salvati',
            icon: const Icon(Icons.list_alt),
            onPressed: () =>
                Navigator.of(context).pushNamed(TracksListScreen.routePath),
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
          Positioned(
            top: 12,
            left: 12,
            child: _NorthButton(controller: _mapController),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: const SafeArea(child: DrawRouteControls()),
          ),
        ],
      ),
      // Il FAB compare solo nello stato iniziale; durante il disegno (o con
      // waypoint presenti) il toggle Disegna/Fine vive nel pannello controlli,
      // così non copre il pulsante "Dislivello".
      floatingActionButton: (editor.drawing || editor.waypoints.isNotEmpty)
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  ref.read(routeEditorProvider.notifier).toggleDrawing(),
              icon: const Icon(Icons.edit_location_alt),
              label: const Text('Disegna'),
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

/// Bottone bussola: appare quando la mappa è ruotata e riporta il nord in alto.
class _NorthButton extends StatefulWidget {
  const _NorthButton({required this.controller});

  final MapController controller;

  @override
  State<_NorthButton> createState() => _NorthButtonState();
}

class _NorthButtonState extends State<_NorthButton> {
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
    if (_rotation.abs() < 0.5) return const SizedBox.shrink();
    return SafeArea(
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: const CircleBorder(),
        elevation: 3,
        child: IconButton(
          tooltip: 'Nord in alto',
          onPressed: () => widget.controller.rotate(0),
          icon: Transform.rotate(
            angle: -_rotation * math.pi / 180.0,
            child: const Icon(Icons.navigation, color: Colors.red),
          ),
        ),
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
