import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/offline/terrarium_elevation_service.dart';
import '../../data/offline/terrarium_http_fetcher.dart';
import '../../domain/services/elevation_service.dart';
import '../../domain/services/path_geometry.dart';
import '../../domain/services/track_metrics.dart';

/// Stato dell'editor di tracciato: i punti disegnati e se la modalità disegno
/// è attiva.
class RouteEditorState {
  const RouteEditorState({this.points = const [], this.drawing = false});

  final List<LatLng> points;
  final bool drawing;

  bool get canCompute => points.length >= 2;

  RouteEditorState copyWith({List<LatLng>? points, bool? drawing}) =>
      RouteEditorState(
        points: points ?? this.points,
        drawing: drawing ?? this.drawing,
      );
}

/// Editor del tracciato in disegno (tap-to-add, undo, drag, eliminazione) — 1.B.
class RouteEditor extends Notifier<RouteEditorState> {
  @override
  RouteEditorState build() => const RouteEditorState();

  void toggleDrawing() => state = state.copyWith(drawing: !state.drawing);

  void addPoint(LatLng p) =>
      state = state.copyWith(points: [...state.points, p]);

  /// Annulla l'ultimo punto inserito.
  void undo() {
    if (state.points.isEmpty) return;
    state = state.copyWith(points: state.points.sublist(0, state.points.length - 1));
  }

  void movePoint(int index, LatLng p) {
    if (index < 0 || index >= state.points.length) return;
    final next = [...state.points]..[index] = p;
    state = state.copyWith(points: next);
  }

  void removePoint(int index) {
    if (index < 0 || index >= state.points.length) return;
    final next = [...state.points]..removeAt(index);
    state = state.copyWith(points: next);
  }

  void clear() => state = state.copyWith(points: const []);
}

final routeEditorProvider =
    NotifierProvider<RouteEditor, RouteEditorState>(RouteEditor.new);

/// Distanza del tracciato in metri, calcolata in tempo reale (no rete).
final routeDistanceProvider = Provider<double>((ref) {
  final points = ref.watch(routeEditorProvider).points;
  return const PathGeometry().totalDistance(points);
});

/// Servizio elevazione (online di default; in 1.F si aggancia la cache FMTC).
final elevationServiceProvider = Provider<ElevationService>(
  (ref) => TerrariumElevationService(fetchTile: httpTerrariumFetcher()),
);

/// Metriche complete (distanza + D+/D- + profilo), calcolate su richiesta
/// perché richiedono il campionamento del DEM (rete/cache).
class RouteMetrics extends AsyncNotifier<TrackMetrics?> {
  @override
  Future<TrackMetrics?> build() async => null;

  Future<void> compute() async {
    final points = ref.read(routeEditorProvider).points;
    if (points.length < 2) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(elevationServiceProvider);
      return const TrackMetricsCalculator().compute(points, service);
    });
  }

  void reset() => state = const AsyncData(null);
}

final routeMetricsProvider =
    AsyncNotifierProvider<RouteMetrics, TrackMetrics?>(RouteMetrics.new);
