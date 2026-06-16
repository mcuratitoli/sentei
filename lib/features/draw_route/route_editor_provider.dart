import 'dart:developer' as developer;
import 'dart:ui' show Color;

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

/// Palette di colori selezionabili per le tracce.
const List<Color> kTrackPalette = [
  Color(0xFF2E6E4E), // verde bosco
  Color(0xFF1E88E5), // blu
  Color(0xFFE53935), // rosso
  Color(0xFFF57C00), // arancio
  Color(0xFF8E24AA), // viola
  Color(0xFF00897B), // teal
];

/// Una traccia disegnata dall'utente (waypoint + nome + colore + snap).
class DrawnTrack {
  const DrawnTrack({
    required this.id,
    this.waypoints = const [],
    this.name = '',
    this.color = const Color(0xFF2E6E4E),
    this.snapToTrail = true,
  });

  final String id;
  final List<LatLng> waypoints;
  final String name;
  final Color color;
  final bool snapToTrail;

  bool get canCompute => waypoints.length >= 2;

  DrawnTrack copyWith({
    List<LatLng>? waypoints,
    String? name,
    Color? color,
    bool? snapToTrail,
  }) =>
      DrawnTrack(
        id: id,
        waypoints: waypoints ?? this.waypoints,
        name: name ?? this.name,
        color: color ?? this.color,
        snapToTrail: snapToTrail ?? this.snapToTrail,
      );
}

/// Stato dell'editor multi-traccia: tutte le tracce + quella in modifica
/// (`editingId`) e quella selezionata (`selectedId`).
class TracksState {
  const TracksState({
    this.tracks = const [],
    this.editingId,
    this.selectedId,
  });

  final List<DrawnTrack> tracks;
  final String? editingId;
  final String? selectedId;

  bool get drawing => editingId != null;

  /// Traccia "attiva" (in modifica o selezionata) a cui si riferisce la card.
  String? get activeId => editingId ?? selectedId;

  bool get showCard => editingId != null || selectedId != null;

  DrawnTrack? byId(String? id) {
    if (id == null) return null;
    for (final t in tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  DrawnTrack? get editing => byId(editingId);
  DrawnTrack? get active => byId(activeId);
}

/// Editor multi-traccia (1.B): crea/modifica più tracce, selezione, snap.
class Tracks extends Notifier<TracksState> {
  int _counter = 0;

  @override
  TracksState build() => const TracksState();

  String _newId() => 't${_counter++}';

  Color _nextColor() => kTrackPalette[state.tracks.length % kTrackPalette.length];

  /// Avvia il disegno di una NUOVA traccia.
  void startNewDrawing() {
    final track = DrawnTrack(id: _newId(), color: _nextColor());
    state = TracksState(
      tracks: [...state.tracks, track],
      editingId: track.id,
      selectedId: null,
    );
  }

  /// Entra in modifica della traccia selezionata.
  void editSelected() {
    if (state.selectedId == null) return;
    state = TracksState(
      tracks: state.tracks,
      editingId: state.selectedId,
      selectedId: null,
    );
  }

  /// Termina il disegno; scarta la traccia se ha meno di 2 punti.
  void finishDrawing() {
    final id = state.editingId;
    if (id == null) return;
    final track = state.byId(id);
    final tracks = (track != null && track.waypoints.length < 2)
        ? state.tracks.where((t) => t.id != id).toList()
        : state.tracks;
    state = TracksState(tracks: tracks, editingId: null, selectedId: null);
  }

  void select(String id) =>
      state = TracksState(tracks: state.tracks, editingId: null, selectedId: id);

  void deselect() =>
      state = TracksState(tracks: state.tracks, editingId: null, selectedId: null);

  /// Elimina una traccia (default: quella attiva).
  void remove([String? id]) {
    final target = id ?? state.activeId;
    if (target == null) return;
    state = TracksState(
      tracks: state.tracks.where((t) => t.id != target).toList(),
      editingId: state.editingId == target ? null : state.editingId,
      selectedId: state.selectedId == target ? null : state.selectedId,
    );
  }

  void _updateEditing(DrawnTrack Function(DrawnTrack) f) {
    final id = state.editingId;
    if (id == null) return;
    state = TracksState(
      tracks: [for (final t in state.tracks) t.id == id ? f(t) : t],
      editingId: id,
      selectedId: state.selectedId,
    );
  }

  void setName(String name) => _updateEditing((t) => t.copyWith(name: name));
  void setColor(Color c) => _updateEditing((t) => t.copyWith(color: c));
  void toggleSnap() =>
      _updateEditing((t) => t.copyWith(snapToTrail: !t.snapToTrail));

  void addPoint(LatLng p) =>
      _updateEditing((t) => t.copyWith(waypoints: [...t.waypoints, p]));

  void undo() => _updateEditing((t) => t.waypoints.isEmpty
      ? t
      : t.copyWith(waypoints: t.waypoints.sublist(0, t.waypoints.length - 1)));

  void movePoint(int index, LatLng p) => _updateEditing((t) {
        if (index < 0 || index >= t.waypoints.length) return t;
        return t.copyWith(waypoints: [...t.waypoints]..[index] = p);
      });

  void removePoint(int index) => _updateEditing((t) {
        if (index < 0 || index >= t.waypoints.length) return t;
        return t.copyWith(waypoints: [...t.waypoints]..removeAt(index));
      });
}

final tracksProvider = NotifierProvider<Tracks, TracksState>(Tracks.new);

/// Id della traccia attiva (in modifica o selezionata).
final activeTrackIdProvider =
    Provider<String?>((ref) => ref.watch(tracksProvider).activeId);

/// Motore di routing escursionistico (online; BRouter pubblico).
final routingServiceProvider =
    Provider<RoutingService>((ref) => BRouterRoutingService());

/// Percorso instradato (lungo i sentieri) di una specifica traccia.
///
/// Instrada **segmento per segmento** (coppie di waypoint consecutivi): se un
/// singolo segmento non è instradabile, ricade su linea retta SOLO per quel
/// tratto, lasciando snappati gli altri (prima un singolo punto problematico
/// rendeva retto l'intero percorso). Snap disattivo → spezzata tra i waypoint.
final routedPathProvider =
    FutureProvider.family<List<LatLng>, String>((ref, id) async {
  final track = ref.watch(tracksProvider).byId(id);
  if (track == null) return const [];
  final wp = track.waypoints;
  if (wp.length < 2 || !track.snapToTrail) return wp;

  final service = ref.watch(routingServiceProvider);
  final path = <LatLng>[wp.first];
  for (var i = 0; i < wp.length - 1; i++) {
    try {
      final seg = await service.route([wp[i], wp[i + 1]]);
      // La geometria parte ~wp[i]: salto il primo punto per non duplicare la
      // giunzione col segmento precedente.
      if (seg.geometry.length >= 2) {
        path.addAll(seg.geometry.skip(1));
      } else {
        path.add(wp[i + 1]);
      }
    } on RoutingException catch (e) {
      developer.log('Segmento $i non instradabile → linea retta: ${e.message}',
          name: 'routing');
      path.add(wp[i + 1]); // fallback retto solo per questo segmento
    }
  }
  return path;
});

/// Distanza (m) del percorso instradato della traccia attiva.
final routeDistanceProvider = Provider<double>((ref) {
  final id = ref.watch(activeTrackIdProvider);
  if (id == null) return 0;
  final path = ref.watch(routedPathProvider(id)).value ?? const <LatLng>[];
  return const PathGeometry().totalDistance(path);
});

/// Servizio elevazione (online di default; in 1.F si aggancia la cache FMTC).
final elevationServiceProvider = Provider<ElevationService>(
  (ref) => TerrariumElevationService(fetchTile: httpTerrariumFetcher()),
);

/// Metriche (distanza + D+/D- + profilo) della traccia attiva.
///
/// Quando una traccia è **selezionata** (non in disegno) il calcolo parte in
/// automatico, così cliccando un percorso si vedono subito distanza e D+/D-.
/// In disegno il calcolo è on-demand ([compute], dal tasto Dislivello).
class RouteMetrics extends AsyncNotifier<TrackMetrics?> {
  @override
  Future<TrackMetrics?> build() async {
    final st = ref.watch(tracksProvider);
    if (st.drawing || st.selectedId == null) return null;
    final path = await ref.watch(routedPathProvider(st.selectedId!).future);
    if (path.length < 2) return null;
    final service = ref.read(elevationServiceProvider);
    return const TrackMetricsCalculator().compute(path, service);
  }

  Future<void> compute() async {
    final id = ref.read(activeTrackIdProvider);
    if (id == null) return;
    final path = ref.read(routedPathProvider(id)).value ?? const <LatLng>[];
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
}

final routeMetricsProvider =
    AsyncNotifierProvider<RouteMetrics, TrackMetrics?>(RouteMetrics.new);

/// Visibilità del grafico del profilo (toggle dal tasto Dislivello).
/// Si azzera quando cambia la traccia attiva.
class ProfileVisible extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(activeTrackIdProvider);
    return false;
  }

  void toggle() => state = !state;
  void show() => state = true;
}

final profileVisibleProvider =
    NotifierProvider<ProfileVisible, bool>(ProfileVisible.new);

/// Punto del profilo "scrubbed" sul grafico, da evidenziare in mappa.
class ProfileCursor extends Notifier<ProfileSample?> {
  @override
  ProfileSample? build() => null;

  void set(ProfileSample? sample) => state = sample;
}

final profileCursorProvider =
    NotifierProvider<ProfileCursor, ProfileSample?>(ProfileCursor.new);
