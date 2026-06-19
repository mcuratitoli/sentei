import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/location/location_service.dart';
import '../../data/map_sources/map_source.dart';
import '../../data/map_sources/map_sources.dart';
import '../../data/trails/trail_network_service.dart';

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

final trailNetworkServiceProvider =
    Provider<TrailNetworkService>((ref) => TrailNetworkService());

/// Rete sentieri **vettoriale** (relazioni `route=hiking` da OSM/Overpass) per
/// il bounding box visibile. Aggiornata in modo *debounced* al muoversi della
/// mappa, con cache sull'area già scaricata e soglia di zoom (sotto la quale
/// resta vuota, per non sovraccaricare Overpass).
class TrailNetwork extends Notifier<List<List<LatLng>>> {
  Timer? _debounce;
  LatLngBounds? _fetched;
  (LatLngBounds, double)? _pending;
  int _gen = 0;

  /// Sotto questo zoom non si scaricano sentieri (troppa area/dati).
  static const double minZoom = 13;

  @override
  List<List<LatLng>> build() {
    ref.onDispose(() => _debounce?.cancel());
    return const [];
  }

  /// Richiede (debounced) la rete per la vista corrente. Sicuro da chiamare in
  /// fase di build: non muta lo stato in modo sincrono (solo via timer).
  void updateView(LatLngBounds visible, double zoom) {
    _pending = (visible, zoom);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _run);
  }

  void _run() {
    final pending = _pending;
    if (pending == null) return;
    final (visible, zoom) = pending;
    if (zoom < minZoom) {
      _fetched = null;
      if (state.isNotEmpty) state = const [];
      return;
    }
    // Già coperto dall'ultima area scaricata: niente nuova richiesta.
    if (_fetched != null && _contains(_fetched!, visible)) return;
    _fetch(visible);
  }

  Future<void> _fetch(LatLngBounds visible) async {
    final expanded = _expand(visible, 0.15);
    final gen = ++_gen;
    final lines =
        await ref.read(trailNetworkServiceProvider).hikingTrailsInBounds(expanded);
    if (gen != _gen) return; // superato da una richiesta più recente
    // Cache l'area comunque (anche se vuota) per non martellare Overpass.
    _fetched = expanded;
    state = lines;
  }

  bool _contains(LatLngBounds outer, LatLngBounds inner) =>
      inner.south >= outer.south &&
      inner.north <= outer.north &&
      inner.west >= outer.west &&
      inner.east <= outer.east;

  LatLngBounds _expand(LatLngBounds b, double frac) {
    final dLat = (b.north - b.south) * frac;
    final dLon = (b.east - b.west) * frac;
    return LatLngBounds(
      LatLng(b.south - dLat, b.west - dLon),
      LatLng(b.north + dLat, b.east + dLon),
    );
  }
}

final trailNetworkProvider =
    NotifierProvider<TrailNetwork, List<List<LatLng>>>(TrailNetwork.new);

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
