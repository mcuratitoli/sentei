import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../data/map_sources/map_source.dart';
import '../../data/map_sources/map_sources.dart';
import '../tracks_list/tracks_list_screen.dart';
import 'map_providers.dart';

/// Schermata mappa principale (Fase 0).
///
/// Mostra il layer base selezionabile + overlay sentieri opzionale +
/// attribuzione obbligatoria. Il disegno tracciati arriva in Fase 1 (§7).
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  static const String routeName = 'map';
  static const String routePath = '/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(selectedBaseSourceProvider);
    final trailsOn = ref.watch(trailsOverlayEnabledProvider);

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
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: AppConstants.defaultCenter,
          initialZoom: AppConstants.defaultZoom,
          minZoom: AppConstants.minZoom,
          maxZoom: AppConstants.maxZoom,
        ),
        children: [
          base.toTileLayer(),
          if (trailsOn) MapSources.waymarkedTrailsHiking.toTileLayer(),
          _AttributionBox(sources: attributions),
        ],
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
