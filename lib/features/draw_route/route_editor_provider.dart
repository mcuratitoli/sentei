import 'dart:async' show unawaited;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../settings/cloud_sync_controller.dart';

import '../../data/gpx/gpx_service.dart';
import '../../data/offline/terrarium_elevation_service.dart';
import '../../data/offline/terrarium_tile_cache.dart';
import '../../data/routing/brouter_routing_service.dart';
import '../../data/storage/app_database.dart';
import '../../data/storage/tracks_repository.dart';
import '../../data/trails/combined_trail_service.dart';
import '../../data/trails/trail_service.dart';
import '../../domain/models/elevation_profile.dart';
import '../../domain/services/elevation_service.dart';
import '../../domain/services/path_geometry.dart';
import '../../domain/services/routing_service.dart';
import '../../domain/services/track_metrics.dart';

/// Palette di colori selezionabili per le tracce (blu di default + varianti).
const List<Color> kTrackPalette = [
  Color(0xFF1565C0), // blu
  Color(0xFF00897B), // teal
  Color(0xFFE53935), // rosso
  Color(0xFFF57C00), // arancio
  Color(0xFF8E24AA), // viola
  Color(0xFF2E6E4E), // verde bosco
];

/// Una traccia disegnata: i waypoint di controllo + i dati **calcolati e
/// memorizzati** al termine del disegno (percorso instradato, metriche, sentieri),
/// così non vanno ricalcolati a ogni selezione.
class DrawnTrack {
  const DrawnTrack({
    required this.id,
    this.waypoints = const [],
    this.name = '',
    this.color = const Color(0xFF1565C0),
    this.snapToTrail = true,
    this.routedPath = const [],
    this.metrics,
    this.trailRefs = const [],
    this.createdAt,
  });

  final String id;
  final List<LatLng> waypoints;
  final String name;
  final Color color;
  final bool snapToTrail;

  /// Data di creazione (per ordinamento). Impostata alla creazione/import.
  final DateTime? createdAt;

  /// Geometria che segue i sentieri, calcolata al "Fine".
  final List<LatLng> routedPath;

  /// Distanza + D+/D- + profilo, calcolati al "Fine" (null se non disponibili).
  final TrackMetrics? metrics;

  /// Numeri dei sentieri (ref CAI) attraversati, calcolati al "Fine".
  final List<String> trailRefs;

  bool get canCompute => waypoints.length >= 2;

  DrawnTrack copyWith({
    List<LatLng>? waypoints,
    String? name,
    Color? color,
    bool? snapToTrail,
    List<LatLng>? routedPath,
    TrackMetrics? metrics,
    List<String>? trailRefs,
    DateTime? createdAt,
  }) =>
      DrawnTrack(
        id: id,
        waypoints: waypoints ?? this.waypoints,
        name: name ?? this.name,
        color: color ?? this.color,
        snapToTrail: snapToTrail ?? this.snapToTrail,
        routedPath: routedPath ?? this.routedPath,
        metrics: metrics ?? this.metrics,
        trailRefs: trailRefs ?? this.trailRefs,
        createdAt: createdAt ?? this.createdAt,
      );

  /// Azzera i dati calcolati (quando i waypoint cambiano in modifica).
  DrawnTrack clearedComputed() => DrawnTrack(
        id: id,
        waypoints: waypoints,
        name: name,
        color: color,
        snapToTrail: snapToTrail,
        createdAt: createdAt,
      );
}

/// Stato dell'editor multi-traccia.
class TracksState {
  const TracksState({
    this.tracks = const [],
    this.editingId,
    this.selectedId,
    this.savingId,
    this.geometryNonce = 0,
  });

  final List<DrawnTrack> tracks;
  final String? editingId;
  final String? selectedId;

  /// Id della traccia per cui è in corso calcolo+salvataggio dopo il "Fine".
  final String? savingId;

  /// Incrementato ad ogni cambio di geometria (waypoint/percorso/colore/lista).
  /// Non cambia su modifiche di soli metadati (nome): usato dal listener mappa
  /// per saltare ri-render inutili e prevenire il flickering al typing del nome.
  final int geometryNonce;

  /// Calcolo+salvataggio in corso.
  bool get saving => savingId != null;

  bool get drawing => editingId != null;
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

/// Instrada [wp] **segmento per segmento** (un tratto non instradabile degrada
/// solo quel segmento a linea retta). Snap disattivo → spezzata tra i waypoint.
Future<List<LatLng>> routeAlong(
    RoutingService service, List<LatLng> wp, bool snap) async {
  if (wp.length < 2 || !snap) return wp;
  final path = <LatLng>[wp.first];
  for (var i = 0; i < wp.length - 1; i++) {
    final to = wp[i + 1];
    try {
      final seg = await service.route([wp[i], to]);
      if (seg.geometry.length >= 2) {
        path.addAll(seg.geometry.skip(1));
      } else {
        path.add(to);
      }
    } on RoutingException catch (e) {
      debugPrint('[routing] seg $i → retta: ${e.message}');
      path.add(to);
    }
  }
  return path;
}

/// Editor multi-traccia (1.B): crea/modifica più tracce, selezione, snap, e al
/// "Fine" calcola+memorizza percorso/metriche/sentieri (1.D, in-memory).
class Tracks extends Notifier<TracksState> {
  int _counter = 0;

  /// Snapshot della traccia all'inizio di una **modifica** di traccia esistente
  /// (per ripristinarla su "Annulla"). `null` quando si sta creando una traccia
  /// nuova: in quel caso l'annullamento la scarta del tutto.
  DrawnTrack? _editSnapshot;

  @override
  TracksState build() {
    _load();
    return const TracksState();
  }

  /// Ricarica le tracce dal disco (es. dopo una sincronizzazione cloud).
  Future<void> reloadFromDisk() => _load();

  /// Carica le tracce salvate all'avvio.
  Future<void> _load() async {
    final loaded = await ref.read(tracksRepositoryProvider).loadAll();
    var maxN = -1;
    for (final t in loaded) {
      final n = int.tryParse(t.id.replaceFirst('t', ''));
      if (n != null && n > maxN) maxN = n;
    }
    if (maxN >= 0) _counter = maxN + 1;

    // _load() è async (fire-and-forget da build()) e può risolversi mentre
    // l'utente sta già disegnando/salvando: preserva l'eventuale traccia in
    // corso non ancora su disco, altrimenti la sovrascriveremmo con i dati del
    // disco (su install pulita = lista vuota → traccia azzerata).
    final inProgressId = state.editingId ?? state.savingId;
    final preserved = inProgressId != null &&
            loaded.every((t) => t.id != inProgressId)
        ? state.byId(inProgressId)
        : null;

    state = TracksState(
      tracks: [...loaded, if (preserved != null) preserved],
      editingId: state.editingId,
      selectedId: state.selectedId,
      savingId: state.savingId,
      geometryNonce: loaded.isEmpty ? state.geometryNonce : state.geometryNonce + 1,
    );
  }

  String _newId() => 't${_counter++}';

  Color _nextColor() => kTrackPalette[state.tracks.length % kTrackPalette.length];

  void startNewDrawing() {
    // Scarta un'eventuale traccia in modifica ancora incompleta (<2 punti).
    final existing = state.editing;
    var tracks = state.tracks;
    if (existing != null && existing.waypoints.length < 2) {
      tracks = tracks.where((t) => t.id != existing.id).toList();
    }
    final track =
        DrawnTrack(id: _newId(), color: _nextColor(), createdAt: DateTime.now());
    _editSnapshot = null; // traccia nuova
    state = TracksState(tracks: [...tracks, track], editingId: track.id, geometryNonce: state.geometryNonce + 1);
  }

  void editSelected() {
    if (state.selectedId == null) return;
    _editSnapshot = state.byId(state.selectedId); // per ripristino su Annulla
    state = TracksState(tracks: state.tracks, editingId: state.selectedId, geometryNonce: state.geometryNonce);
  }

  /// Annulla la creazione/modifica in corso e chiude la card.
  ///
  /// - Traccia **nuova** (nessuno snapshot): viene scartata del tutto.
  /// - Modifica di una traccia **esistente**: ripristina lo snapshot iniziale e
  ///   la riseleziona (i dati su disco non sono stati toccati durante l'editing).
  void cancelEditing() {
    final id = state.editingId;
    if (id == null) return;
    final snapshot = _editSnapshot;
    _editSnapshot = null;
    if (snapshot == null) {
      state = TracksState(
        tracks: state.tracks.where((t) => t.id != id).toList(),
        geometryNonce: state.geometryNonce + 1,
      );
    } else {
      state = TracksState(
        tracks: [for (final t in state.tracks) t.id == id ? snapshot : t],
        selectedId: id,
        geometryNonce: state.geometryNonce + 1,
      );
    }
  }

  /// Termina il disegno: scarta tracce < 2 punti; altrimenti calcola e
  /// memorizza percorso instradato + metriche + numeri sentieri.
  Future<void> finishDrawing() async {
    final id = state.editingId;
    if (id == null) return;
    final track = state.byId(id);
    if (track == null) return;
    _editSnapshot = null;

    if (track.waypoints.length < 2) {
      state = TracksState(
        tracks: state.tracks.where((t) => t.id != id).toList(),
        geometryNonce: state.geometryNonce + 1,
      );
      return;
    }

    // Deseleziona (si possono disegnare altre tracce); il calcolo prosegue in
    // background (savingId = id, per animare la traccia) e i dati restano
    // memorizzati per quando la traccia verrà selezionata.
    state = TracksState(tracks: state.tracks, savingId: id, geometryNonce: state.geometryNonce);

    final path =
        await routeAlong(ref.read(routingServiceProvider), track.waypoints,
            track.snapToTrail);

    TrackMetrics? metrics;
    try {
      metrics = await const TrackMetricsCalculator()
          .compute(path, ref.read(elevationServiceProvider));
    } catch (_) {
      metrics = null;
    }

    // Numeri sentiero per tratto (per il grafico) + elenco unico (per i chip).
    List<TrailSegment> segments = const [];
    try {
      segments = await ref.read(trailServiceProvider).trailSegmentsAlong(path);
    } catch (_) {
      segments = const [];
    }
    final refs = <String>{for (final s in segments) s.ref}.toList()..sort();
    if (metrics != null && segments.isNotEmpty) {
      metrics = metrics.copyWith(trailSegments: segments);
    }

    // La traccia potrebbe essere stata eliminata nel frattempo.
    if (state.byId(id) == null) {
      state = TracksState(
          tracks: state.tracks,
          editingId: state.editingId,
          selectedId: state.selectedId,
          geometryNonce: state.geometryNonce);
      return;
    }
    state = TracksState(
      tracks: [
        for (final t in state.tracks)
          if (t.id == id)
            t.copyWith(routedPath: path, metrics: metrics, trailRefs: refs)
          else
            t,
      ],
      editingId: state.editingId,
      selectedId: state.selectedId,
      // savingId azzerato → fine animazione.
      geometryNonce: state.geometryNonce + 1,
    );

    // Persiste su disco e propaga al cloud (auto-sync, best-effort).
    final saved = state.byId(id);
    if (saved != null) {
      final now = DateTime.now();
      try {
        await ref.read(tracksRepositoryProvider).save(saved, updatedAt: now);
      } catch (_) {/* best-effort */}
      unawaited(ref.read(cloudSyncProvider.notifier).autoPush(saved, now));
    }
  }

  void select(String id) =>
      state = TracksState(tracks: state.tracks, selectedId: id, geometryNonce: state.geometryNonce);

  void deselect() => state = TracksState(tracks: state.tracks, geometryNonce: state.geometryNonce);

  void remove([String? id]) {
    final target = id ?? state.activeId;
    if (target == null) return;
    state = TracksState(
      tracks: state.tracks.where((t) => t.id != target).toList(),
      editingId: state.editingId == target ? null : state.editingId,
      selectedId: state.selectedId == target ? null : state.selectedId,
      geometryNonce: state.geometryNonce + 1,
    );
    ref.read(tracksRepositoryProvider).delete(target); // best-effort
    // Auto-sync: propaga l'eliminazione al cloud (best-effort, no-op se offline).
    unawaited(ref.read(cloudSyncProvider.notifier).autoDelete(target));
  }

  /// Importa una traccia da GPX. Ritorna `null` se ok, o un messaggio d'errore.
  Future<String?> importGpx(String xml) async {
    try {
      final track = const GpxService()
          .importFromGpx(xml, id: _newId())
          .copyWith(createdAt: DateTime.now());
      state = TracksState(
        tracks: [...state.tracks, track],
        editingId: state.editingId,
        selectedId: state.selectedId,
        geometryNonce: state.geometryNonce + 1,
      );
      final now = DateTime.now();
      try {
        await ref.read(tracksRepositoryProvider).save(track, updatedAt: now);
      } catch (_) {/* best-effort */}
      unawaited(ref.read(cloudSyncProvider.notifier).autoPush(track, now));
      return null;
    } on FormatException catch (e) {
      return e.message;
    } catch (e) {
      return 'GPX non valido';
    }
  }

  /// Modifica la traccia in editing; ogni cambio ai waypoint azzera i dati
  /// calcolati (verranno rifatti al prossimo "Fine").
  void _updateEditing(DrawnTrack Function(DrawnTrack) f, {bool affectsGeometry = true}) {
    final id = state.editingId;
    if (id == null) return;
    state = TracksState(
      tracks: [for (final t in state.tracks) t.id == id ? f(t) : t],
      editingId: id,
      selectedId: state.selectedId,
      geometryNonce: affectsGeometry ? state.geometryNonce + 1 : state.geometryNonce,
    );
  }

  void setName(String name) => _updateEditing((t) => t.copyWith(name: name), affectsGeometry: false);
  void setColor(Color c) => _updateEditing((t) => t.copyWith(color: c));

  void addPoint(LatLng p) => _updateEditing(
      (t) => t.clearedComputed().copyWith(waypoints: [...t.waypoints, p]));

  void undo() => _updateEditing((t) => t.waypoints.isEmpty
      ? t
      : t
          .clearedComputed()
          .copyWith(waypoints: t.waypoints.sublist(0, t.waypoints.length - 1)));

  void movePoint(int index, LatLng p) => _updateEditing((t) {
        if (index < 0 || index >= t.waypoints.length) return t;
        return t
            .clearedComputed()
            .copyWith(waypoints: [...t.waypoints]..[index] = p);
      });

  void removePoint(int index) => _updateEditing((t) {
        if (index < 0 || index >= t.waypoints.length) return t;
        return t
            .clearedComputed()
            .copyWith(waypoints: [...t.waypoints]..removeAt(index));
      });
}

final tracksProvider = NotifierProvider<Tracks, TracksState>(Tracks.new);

/// Database locale (drift) e repository delle tracce (persistenza su disco).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final tracksRepositoryProvider = Provider<TracksRepository>(
    (ref) => TracksRepository(ref.watch(databaseProvider)));

final activeTrackIdProvider =
    Provider<String?>((ref) => ref.watch(tracksProvider).activeId);

/// Motore di routing escursionistico (online; BRouter pubblico).
final routingServiceProvider =
    Provider<RoutingService>((ref) => BRouterRoutingService());

/// Servizio per i numeri dei sentieri (ref CAI): OSM2CAI (catasto ufficiale)
/// primario + Overpass (OSM grezzo) fallback per le zone di confine.
final trailServiceProvider =
    Provider<TrailService>((ref) => CombinedTrailService());

/// Cache su disco delle tile Terrarium (condivisa: elevazione online + offline).
final terrariumCacheProvider =
    Provider<TerrariumTileCache>((ref) => TerrariumTileCache());

final elevationServiceProvider = Provider<ElevationService>(
  (ref) => TerrariumElevationService(
    fetchTile: cachingTerrariumFetcher(cache: ref.read(terrariumCacheProvider)),
  ),
);

/// Percorso instradato **in tempo reale** della traccia in modifica (anteprima
/// durante il disegno). Le tracce finalizzate usano `DrawnTrack.routedPath`.
final livePathProvider = FutureProvider.family<List<LatLng>, String>((ref, id) async {
  // Dipende SOLO da waypoint + snap: così cambi di nome/colore della traccia
  // NON fanno ri-instradare (niente "Calcolo percorso…" a ogni carattere).
  final waypoints =
      ref.watch(tracksProvider.select((s) => s.byId(id)?.waypoints));
  if (waypoints == null) return const [];
  final snap =
      ref.watch(tracksProvider.select((s) => s.byId(id)?.snapToTrail ?? true));
  return routeAlong(ref.read(routingServiceProvider), waypoints, snap);
});

/// Distanza (m) della traccia attiva: usa i dati memorizzati se presenti,
/// altrimenti l'anteprima live (durante il disegno).
final routeDistanceProvider = Provider<double>((ref) {
  final track = ref.watch(tracksProvider).active;
  if (track == null) return 0;
  if (track.metrics != null) return track.metrics!.distanceMeters;
  if (track.routedPath.length >= 2) {
    return const PathGeometry().totalDistance(track.routedPath);
  }
  final live = ref.watch(livePathProvider(track.id)).value ?? const <LatLng>[];
  return const PathGeometry().totalDistance(live);
});

/// Metriche calcolate **on-demand durante il disegno** (tasto Dislivello).
/// In vista selezionata si usano invece quelle memorizzate sulla traccia.
class RouteMetrics extends AsyncNotifier<TrackMetrics?> {
  @override
  Future<TrackMetrics?> build() async {
    ref.watch(activeTrackIdProvider); // reset al cambio traccia
    return null;
  }

  Future<void> compute() async {
    final track = ref.read(tracksProvider).active;
    if (track == null) return;
    final path = ref.read(livePathProvider(track.id)).value ??
        (track.routedPath.length >= 2 ? track.routedPath : const <LatLng>[]);
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

/// Visibilità del grafico del profilo (toggle dal tasto Dislivello).
class ProfileVisible extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(activeTrackIdProvider); // reset al cambio traccia
    final st = ref.read(tracksProvider);
    // Aperto di default quando si **seleziona** una traccia con profilo già
    // calcolato; in disegno resta chiuso (il profilo è on-demand, tasto
    // "Percorso"). Il toggle manuale persiste finché non si cambia traccia.
    return !st.drawing && (st.active?.metrics?.profile.isEmpty == false);
  }

  void toggle() => state = !state;
  void show() => state = true;
}

final profileVisibleProvider =
    NotifierProvider<ProfileVisible, bool>(ProfileVisible.new);

/// Visibilità della colorazione per **ripidezza** (pendenza) della traccia
/// selezionata. Si azzera al cambio di traccia.
class SteepnessVisible extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(activeTrackIdProvider);
    return false;
  }

  void toggle() => state = !state;
}

final steepnessVisibleProvider =
    NotifierProvider<SteepnessVisible, bool>(SteepnessVisible.new);

/// Punto del profilo "scrubbed" sul grafico, da evidenziare in mappa.
class ProfileCursor extends Notifier<ProfileSample?> {
  @override
  ProfileSample? build() => null;

  void set(ProfileSample? sample) => state = sample;
}

final profileCursorProvider =
    NotifierProvider<ProfileCursor, ProfileSample?>(ProfileCursor.new);

/// Nasconde dalla mappa le tracce **salvate** (la traccia in modifica resta
/// sempre visibile). Stato in-memory: alla riapertura le tracce tornano visibili.
class TracksHidden extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final tracksHiddenProvider =
    NotifierProvider<TracksHidden, bool>(TracksHidden.new);
