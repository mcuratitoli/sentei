import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/search/geocoding_service.dart';
import '../draw_route/route_editor_provider.dart' show elevationServiceProvider;
import '../map/map_providers.dart' show geocodingServiceProvider;

/// Punto della mappa ispezionato in modalità **esplorazione**: quando l'utente
/// tocca un punto dove non c'è una traccia da selezionare, mostriamo una
/// mini-card con **altitudine** (dal DEM Terrarium, anche offline), **coordinate**
/// e **località/provincia/nazione** (reverse geocoding).
class InspectedPoint {
  const InspectedPoint({
    required this.point,
    this.elevation,
    this.elevationLoading = true,
    this.place,
    this.placeLoading = true,
  });

  final LatLng point;

  /// Quota in metri, oppure `null` se non disponibile (tile mancante / fuori
  /// copertura) — valida solo quando [elevationLoading] è `false`.
  final double? elevation;
  final bool elevationLoading;

  /// Località/provincia/nazione, oppure `null` se non risolvibile — valida solo
  /// quando [placeLoading] è `false`.
  final ReversePlace? place;
  final bool placeLoading;

  InspectedPoint copyWith({
    double? elevation,
    bool? elevationLoading,
    ReversePlace? place,
    bool? placeLoading,
  }) =>
      InspectedPoint(
        point: point,
        elevation: elevation ?? this.elevation,
        elevationLoading: elevationLoading ?? this.elevationLoading,
        place: place ?? this.place,
        placeLoading: placeLoading ?? this.placeLoading,
      );
}

/// Stato del punto ispezionato (`null` = nessuno). Risolve quota e luogo in modo
/// asincrono e indipendente; un nuovo `inspect`/`clear` invalida i precedenti
/// (token), così una risposta in ritardo non sovrascrive lo stato corrente.
class InspectedPointNotifier extends Notifier<InspectedPoint?> {
  int _token = 0;

  @override
  InspectedPoint? build() => null;

  /// Avvia l'ispezione di [point]: mostra subito le coordinate + spinner, poi
  /// aggiorna quota e luogo appena pronti (separatamente).
  void inspect(LatLng point) {
    final t = ++_token;
    state = InspectedPoint(point: point);

    // Quota (DEM Terrarium, con cache → anche offline).
    () async {
      double? elev;
      try {
        elev = await ref.read(elevationServiceProvider).elevationAt(point);
      } catch (_) {
        elev = null;
      }
      final cur = state;
      if (_token != t || cur == null) return;
      state = cur.copyWith(elevation: elev, elevationLoading: false);
    }();

    // Reverse geocoding (località/provincia/nazione).
    () async {
      ReversePlace? place;
      try {
        place = await ref.read(geocodingServiceProvider).reverse(point);
      } catch (_) {
        place = null;
      }
      final cur = state;
      if (_token != t || cur == null) return;
      state = cur.copyWith(place: place, placeLoading: false);
    }();
  }

  /// Azzera il punto ispezionato (chiusura card / selezione traccia / disegno).
  void clear() {
    _token++;
    state = null;
  }
}

final inspectedPointProvider =
    NotifierProvider<InspectedPointNotifier, InspectedPoint?>(
  InspectedPointNotifier.new,
);
