import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/location/location_service.dart';
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

/// Modalità fullscreen: nasconde app bar e pannelli per massimizzare la mappa.
class FullscreenMode extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final fullscreenProvider =
    NotifierProvider<FullscreenMode, bool>(FullscreenMode.new);

final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());

/// Posizione GPS dell'utente. `null` finché non si attiva la localizzazione.
/// `locate()` richiede i permessi e avvia lo stream; rilancia in caso di errore.
class UserLocation extends Notifier<LatLng?> {
  StreamSubscription<LatLng>? _sub;

  @override
  LatLng? build() {
    ref.onDispose(() => _sub?.cancel());
    return null;
  }

  /// Attiva la localizzazione e restituisce la prima posizione (per centrare
  /// la mappa). Lancia [LocationException] se non disponibile.
  Future<LatLng> locate() async {
    final service = ref.read(locationServiceProvider);
    await service.ensureReady();
    _sub ??= service.positionStream().listen((p) => state = p);
    if (state != null) return state!;
    final first = await service.positionStream().first;
    state = first;
    return first;
  }
}

final userLocationProvider =
    NotifierProvider<UserLocation, LatLng?>(UserLocation.new);
