import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/offline/terrarium_elevation_service.dart';
import '../../data/offline/terrarium_http_fetcher.dart';
import '../../data/routing/brouter_routing_service.dart';
import '../../domain/models/elevation_profile.dart';
import '../../domain/services/elevation_service.dart';
import '../../domain/services/path_geometry.dart';
import '../../domain/services/routing_service.dart';
import '../../domain/services/track_metrics.dart';

/// Stato dell'editor di tracciato: i waypoint inseriti dall'utente, se la
/// modalità disegno è attiva e se lo snap-to-trail è abilitato.
///
/// I waypoint sono i punti di controllo (tap/drag). Il percorso effettivo che
/// segue i sentieri è calcolato da [routedPathProvider].
class RouteEditorState {
  const RouteEditorState({
    this.waypoints = const [],
    this.drawing = false,
    this.selected = false,
    this.snapToTrail = true,
    this.name = '',
  });

  final List<LatLng> waypoints;

  /// In modalità disegno/modifica (tap aggiunge punti).
  final bool drawing;

  /// Percorso selezionato: mostra la card con azioni (modifica/elimina/dislivello).
  final bool selected;

  final bool snapToTrail;
  final String name;

  bool get hasRoute => waypoints.isNotEmpty;
  bool get canCompute => waypoints.length >= 2;

  /// La card dei controlli è visibile in disegno o quando il percorso è selezionato.
  bool get showCard => drawing || selected;

  RouteEditorState copyWith({
    List<LatLng>? waypoints,
    bool? drawing,
    bool? selected,
    bool? snapToTrail,
    String? name,
  }) =>
      RouteEditorState(
        waypoints: waypoints ?? this.waypoints,
        drawing: drawing ?? this.drawing,
        selected: selected ?? this.selected,
        snapToTrail: snapToTrail ?? this.snapToTrail,
        name: name ?? this.name,
      );
}

/// Editor del tracciato (tap-to-add, undo, drag, eliminazione, selezione) — 1.B.
class RouteEditor extends Notifier<RouteEditorState> {
  @override
  RouteEditorState build() => const RouteEditorState();

  void toggleSnap() => state = state.copyWith(snapToTrail: !state.snapToTrail);

  /// Entra in modalità disegno/modifica (nuovo percorso o continua quello esistente).
  void startDrawing() => state = state.copyWith(drawing: true, selected: false);

  /// Termina il disegno: il percorso resta in mappa ma deselezionato.
  void finishDrawing() => state = state.copyWith(drawing: false, selected: false);

  /// Seleziona il percorso (mostra la card azioni).
  void select() {
    if (state.hasRoute && !state.drawing) {
      state = state.copyWith(selected: true);
    }
  }

  void deselect() => state = state.copyWith(selected: false);

  void setName(String name) => state = state.copyWith(name: name);

  void addPoint(LatLng p) =>
      state = state.copyWith(waypoints: [...state.waypoints, p]);

  /// Annulla l'ultimo waypoint inserito.
  void undo() {
    if (state.waypoints.isEmpty) return;
    state = state.copyWith(
        waypoints: state.waypoints.sublist(0, state.waypoints.length - 1));
  }

  void movePoint(int index, LatLng p) {
    if (index < 0 || index >= state.waypoints.length) return;
    final next = [...state.waypoints]..[index] = p;
    state = state.copyWith(waypoints: next);
  }

  void removePoint(int index) {
    if (index < 0 || index >= state.waypoints.length) return;
    final next = [...state.waypoints]..removeAt(index);
    state = state.copyWith(waypoints: next);
  }

  /// Cancella tutto e torna allo stato iniziale.
  void clear() => state = const RouteEditorState();
}

final routeEditorProvider =
    NotifierProvider<RouteEditor, RouteEditorState>(RouteEditor.new);

/// Motore di routing escursionistico (online; BRouter pubblico).
final routingServiceProvider =
    Provider<RoutingService>((ref) => BRouterRoutingService());

/// Percorso effettivo da disegnare: con snap-to-trail attivo segue i sentieri
/// (BRouter); altrimenti è la spezzata tra i waypoint. In caso di errore di
/// routing ricade sulla spezzata (così l'app resta usabile offline).
///
/// Si ricalcola automaticamente al variare dei waypoint / dello snap.
final routedPathProvider = FutureProvider<List<LatLng>>((ref) async {
  final st = ref.watch(routeEditorProvider);
  if (st.waypoints.length < 2 || !st.snapToTrail) {
    return st.waypoints;
  }
  try {
    final result = await ref.watch(routingServiceProvider).route(st.waypoints);
    return result.geometry;
  } on RoutingException {
    return st.waypoints; // fallback: linea retta
  }
});

/// Distanza del percorso instradato in metri (no rete: calcolata sul geometry).
final routeDistanceProvider = Provider<double>((ref) {
  final path = ref.watch(routedPathProvider).value ?? const <LatLng>[];
  return const PathGeometry().totalDistance(path);
});

/// Servizio elevazione (online di default; in 1.F si aggancia la cache FMTC).
final elevationServiceProvider = Provider<ElevationService>(
  (ref) => TerrariumElevationService(fetchTile: httpTerrariumFetcher()),
);

/// Metriche complete (distanza + D+/D- + profilo) sul percorso instradato,
/// calcolate su richiesta perché richiedono il campionamento del DEM.
class RouteMetrics extends AsyncNotifier<TrackMetrics?> {
  @override
  Future<TrackMetrics?> build() async => null;

  Future<void> compute() async {
    final path = ref.read(routedPathProvider).value ?? const <LatLng>[];
    if (path.length < 2) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(elevationServiceProvider);
      return const TrackMetricsCalculator().compute(path, service);
    });
  }

  void reset() => state = const AsyncData(null);
}

final routeMetricsProvider =
    AsyncNotifierProvider<RouteMetrics, TrackMetrics?>(RouteMetrics.new);

/// Punto del profilo attualmente "scrubbed" dall'utente sul grafico: serve a
/// evidenziarlo in mappa. `null` quando non si sta scorrendo il profilo.
class ProfileCursor extends Notifier<ProfileSample?> {
  @override
  ProfileSample? build() => null;

  void set(ProfileSample? sample) => state = sample;
}

final profileCursorProvider =
    NotifierProvider<ProfileCursor, ProfileSample?>(ProfileCursor.new);
