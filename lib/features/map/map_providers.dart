import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/location/location_service.dart';
import '../../data/search/combined_geocoding_service.dart';
import '../../data/trails/trail_network_service.dart';

final trailNetworkServiceProvider =
    Provider<TrailNetworkService>((ref) => TrailNetworkService());

/// Nominatim (OSM) come fonte primaria + Mapbox come complemento.
/// Nominatim copre rifugi, vette, passi e altri POI alpini non presenti
/// nel database proprietario Mapbox.
final geocodingServiceProvider =
    Provider<CombinedGeocodingService>((ref) => CombinedGeocodingService());

final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());

/// Richiesta di **centrare la mappa** su una traccia (selezione dalla lista).
/// Il `nonce` rende ogni richiesta distinta anche per la stessa traccia, così
/// la mappa rieffettua il fly anche riselezionando lo stesso tracciato.
class MapFocusTarget {
  const MapFocusTarget(this.trackId, this.nonce);
  final String trackId;
  final int nonce;
}

class MapFocus extends Notifier<MapFocusTarget?> {
  int _n = 0;

  @override
  MapFocusTarget? build() => null;

  void focusTrack(String id) => state = MapFocusTarget(id, _n++);
}

final mapFocusProvider =
    NotifierProvider<MapFocus, MapFocusTarget?>(MapFocus.new);

/// Richiesta di **centrare la mappa su un punto** (es. "Vedi sulla mappa" dal
/// visualizzatore foto a schermo intero, §"Sync album fotografico") — a
/// differenza di [MapFocus] non inquadra i bounds di un'intera traccia, solo
/// un singolo punto a zoom fisso. Stesso schema del `nonce` per rifare il fly
/// anche riselezionando lo stesso punto.
class MapFlyToTarget {
  const MapFlyToTarget(this.point, this.nonce);
  final LatLng point;
  final int nonce;
}

class MapFlyToPoint extends Notifier<MapFlyToTarget?> {
  int _n = 0;

  @override
  MapFlyToTarget? build() => null;

  void flyTo(LatLng point) => state = MapFlyToTarget(point, _n++);
}

final mapFlyToPointProvider =
    NotifierProvider<MapFlyToPoint, MapFlyToTarget?>(MapFlyToPoint.new);

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
