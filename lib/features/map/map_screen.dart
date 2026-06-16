import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../data/location/location_service.dart';
import '../../data/map_sources/map_source.dart';
import '../../data/map_sources/map_sources.dart';
import '../../domain/services/path_geometry.dart';
import '../draw_route/draw_route_controls.dart';
import '../draw_route/route_editor_provider.dart';
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
    final fullscreen = ref.watch(fullscreenProvider);

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
      appBar: fullscreen
          ? null
          : AppBar(
              title: const Text(AppConstants.appDisplayName),
              actions: [
                IconButton(
                  tooltip: 'Sentieri',
                  icon: Icon(trailsOn ? Icons.hiking : Icons.hiking_outlined),
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
              base.toTileLayer(),
              if (trailsOn) MapSources.waymarkedTrailsHiking.toTileLayer(),
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
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(),
            ),
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
      floatingActionButton: _buildFab(tracks, fullscreen),
    );
  }

  Widget? _buildFab(TracksState tracks, bool fullscreen) {
    final notifier = ref.read(tracksProvider.notifier);
    if (fullscreen) {
      return FloatingActionButton(
        onPressed: () => tracks.drawing
            ? notifier.finishDrawing()
            : notifier.startNewDrawing(),
        child: Icon(tracks.drawing ? Icons.check : Icons.edit_location_alt),
      );
    }
    // "Disegna" sempre in basso a destra quando nessuna traccia è in card.
    if (!tracks.showCard) {
      return FloatingActionButton.extended(
        onPressed: notifier.startNewDrawing,
        icon: const Icon(Icons.edit_location_alt),
        label: const Text('Disegna'),
      );
    }
    return null; // card visibile → i tasti sono nella card
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
        return PolylineLayer(
          polylines: [
            for (final (t, path) in entries)
              Polyline(
                points: path,
                strokeWidth: t.id == st.activeId ? 6 : 4,
                color: t.id == st.savingId
                    ? t.color.withValues(alpha: pulse)
                    : t.color,
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
            child: CustomPaint(painter: _CompassPainter(rotationDeg: _rotation)),
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
    final north = Path()
      ..moveTo(0, -r)
      ..lineTo(-half, 0)
      ..lineTo(half, 0)
      ..close();
    canvas.drawPath(north, Paint()..color = const Color(0xFFD32F2F));
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
