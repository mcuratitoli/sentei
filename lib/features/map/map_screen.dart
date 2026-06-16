import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
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
          SafeArea(
            child: Stack(
              children: [
                if (busy)
                  const Align(
                    alignment: Alignment.topCenter,
                    child: LinearProgressIndicator(),
                  ),
                // Sinistra: logo (sfondo blur) + bussola piccola sotto.
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _LogoBadge(),
                        const SizedBox(height: 8),
                        _Compass(controller: _mapController, size: 36),
                      ],
                    ),
                  ),
                ),
                // Destra: tracce / mappe / menu uniti in un controllo arrotondato.
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _MapButtonStack(
                      onLocate: _locate,
                      onTracks: () => context.push(TracksListScreen.routePath),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: const SafeArea(child: DrawRouteControls()),
          ),
        ],
      ),
      floatingActionButton: _buildFab(tracks),
    );
  }

  Widget? _buildFab(TracksState tracks) {
    // FAB tondo "+" per creare una nuova traccia, quando nessuna è in card.
    if (!tracks.showCard) {
      return FloatingActionButton(
        tooltip: 'Nuova traccia',
        onPressed: ref.read(tracksProvider.notifier).startNewDrawing,
        child: const Icon(Icons.add),
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

/// Dimensione uniforme dei pulsanti flottanti.
const double _kMapButtonSize = 44;

/// Nome dell'app in sovrimpressione, con sfondo sfocato semitrasparente per
/// staccarlo dalla mappa sottostante.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          color: Colors.white.withValues(alpha: 0.25),
          child: Text(
            AppConstants.appDisplayName,
            style: AppTheme.appNameStyle(Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

/// Controllo verticale unito (tracce / mappe / menu) con angoli arrotondati.
class _MapButtonStack extends ConsumerWidget {
  const _MapButtonStack({required this.onLocate, required this.onTracks});

  final VoidCallback onLocate;
  final VoidCallback onTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final base = ref.watch(selectedBaseSourceProvider);
    final trailsOn = ref.watch(trailsOverlayEnabledProvider);
    final located = ref.watch(userLocationProvider) != null;

    Widget cell(IconData icon, {VoidCallback? onTap, bool highlighted = false}) {
      final c = SizedBox(
        width: _kMapButtonSize,
        height: _kMapButtonSize,
        child: Icon(icon,
            size: 22,
            color: highlighted ? scheme.primary : scheme.onSurface),
      );
      return onTap == null ? c : InkWell(onTap: onTap, child: c);
    }

    final divider = Divider(
        height: 1, thickness: 1, color: scheme.outlineVariant);

    return Material(
      color: scheme.surface,
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Tracciati salvati',
            child: cell(Icons.list_alt, onTap: onTracks),
          ),
          divider,
          PopupMenuButton<MapSource>(
            tooltip: 'Sorgente mappa',
            initialValue: base,
            onSelected: (s) =>
                ref.read(selectedBaseSourceProvider.notifier).select(s),
            itemBuilder: (_) => [
              for (final s in MapSources.bases)
                PopupMenuItem<MapSource>(value: s, child: Text(s.name)),
            ],
            child: cell(Icons.layers),
          ),
          divider,
          PopupMenuButton<String>(
            tooltip: 'Altro',
            onSelected: (v) {
              if (v == 'locate') onLocate();
              if (v == 'trails') {
                ref.read(trailsOverlayEnabledProvider.notifier).toggle();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'locate',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.my_location),
                  title: Text('La mia posizione'),
                ),
              ),
              PopupMenuItem(
                value: 'trails',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(trailsOn ? Icons.hiking : Icons.hiking_outlined),
                  title: Text(
                      trailsOn ? 'Nascondi sentieri' : 'Mostra sentieri'),
                ),
              ),
            ],
            child: cell(Icons.more_vert, highlighted: located),
          ),
        ],
      ),
    );
  }
}

/// Bussola che indica sempre il nord; al tap riporta il nord in alto.
class _Compass extends StatefulWidget {
  const _Compass({required this.controller, this.size = _kMapButtonSize});

  final MapController controller;
  final double size;

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => widget.controller.rotate(0),
        child: Tooltip(
          message: 'Nord in alto',
          child: SizedBox(
            width: widget.size,
            height: widget.size,
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
