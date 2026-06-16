import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../data/map_sources/map_source.dart';
import '../../data/map_sources/map_sources.dart';
import '../draw_route/draw_route_controls.dart';
import '../draw_route/route_editor_provider.dart';
import '../tracks_list/tracks_list_screen.dart';
import 'map_providers.dart';

/// Schermata mappa principale: visualizzazione + disegno tracciato (1.B).
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  static const String routeName = 'map';
  static const String routePath = '/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(selectedBaseSourceProvider);
    final trailsOn = ref.watch(trailsOverlayEnabledProvider);
    final editor = ref.watch(routeEditorProvider);

    final attributions = <MapSource>[
      base,
      if (trailsOn) MapSources.waymarkedTrailsHiking,
    ];

    return Scaffold(
      appBar: AppBar(
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
            onPressed: () =>
                Navigator.of(context).pushNamed(TracksListScreen.routePath),
          ),
          _SourceMenu(selected: base),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: AppConstants.defaultCenter,
              initialZoom: AppConstants.defaultZoom,
              minZoom: AppConstants.minZoom,
              maxZoom: AppConstants.maxZoom,
              onTap: editor.drawing
                  ? (_, point) =>
                      ref.read(routeEditorProvider.notifier).addPoint(point)
                  : null,
            ),
            children: [
              base.toTileLayer(),
              if (trailsOn) MapSources.waymarkedTrailsHiking.toTileLayer(),
              if (editor.points.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: editor.points,
                      strokeWidth: 4,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              if (editor.points.isNotEmpty) const _RoutePointMarkers(),
              _AttributionBox(sources: attributions),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(child: const DrawRouteControls()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ref.read(routeEditorProvider.notifier).toggleDrawing(),
        icon: Icon(editor.drawing ? Icons.check : Icons.edit_location_alt),
        label: Text(editor.drawing ? 'Fine' : 'Disegna'),
      ),
    );
  }
}

/// Marker trascinabili per i punti del tracciato. Drag per spostare, long-press
/// per eliminare un punto.
class _RoutePointMarkers extends ConsumerWidget {
  const _RoutePointMarkers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(routeEditorProvider).points;
    final scheme = Theme.of(context).colorScheme;

    return DragMarkers(
      markers: [
        for (var i = 0; i < points.length; i++)
          DragMarker(
            key: ValueKey('route-point-$i'),
            point: points[i],
            size: const Size(28, 28),
            onDragUpdate: (_, latLng) =>
                ref.read(routeEditorProvider.notifier).movePoint(i, latLng),
            onLongPress: (_) =>
                ref.read(routeEditorProvider.notifier).removePoint(i),
            builder: (context, point, isDragging) {
              final isEndpoint = i == 0 || i == points.length - 1;
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEndpoint ? scheme.primary : scheme.surface,
                  border: Border.all(color: scheme.primary, width: 2),
                  boxShadow: isDragging
                      ? [const BoxShadow(blurRadius: 6, color: Colors.black38)]
                      : null,
                ),
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
