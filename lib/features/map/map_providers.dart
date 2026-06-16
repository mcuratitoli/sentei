import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/map_sources/map_source.dart';
import '../../data/map_sources/map_sources.dart';

/// Layer base attualmente selezionato.
///
/// TODO(settings): persistere la scelta con shared_preferences (§3).
class SelectedBaseSource extends Notifier<MapSource> {
  @override
  MapSource build() => MapSources.defaultBase;

  void select(MapSource source) => state = source;
}

final selectedBaseSourceProvider =
    NotifierProvider<SelectedBaseSource, MapSource>(SelectedBaseSource.new);

/// Overlay "Sentieri" (Waymarked Trails) attivo o meno.
class TrailsOverlayEnabled extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final trailsOverlayEnabledProvider =
    NotifierProvider<TrailsOverlayEnabled, bool>(TrailsOverlayEnabled.new);
