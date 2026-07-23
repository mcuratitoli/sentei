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
import '../../domain/models/track_photo.dart';
import '../../domain/services/elevation_service.dart';
import '../../domain/services/path_geometry.dart';
import '../../domain/services/polyline_simplify.dart';
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
    this.trailsResolved = false,
    this.createdAt,
    this.photos = const [],
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

  /// Se i segnavia/difficoltà CAI sono **già stati cercati** per questa traccia
  /// (a prescindere dall'esito: `trailRefs` può essere vuoto perché la zona non
  /// ne ha). Distingue "cercati e non trovati" da "mai cercati" (tracce vecchie
  /// salvate prima della funzionalità): solo queste ultime vengono risolte in
  /// modo lazy alla selezione. Si azzera quando la geometria cambia.
  final bool trailsResolved;

  /// Foto collegate alla traccia (§"Sync album fotografico"). Indipendenti
  /// dalla geometria calcolata: **non** azzerate da [clearedComputed].
  final List<TrackPhoto> photos;

  bool get canCompute => waypoints.length >= 2;

  DrawnTrack copyWith({
    List<LatLng>? waypoints,
    String? name,
    Color? color,
    bool? snapToTrail,
    List<LatLng>? routedPath,
    TrackMetrics? metrics,
    List<String>? trailRefs,
    bool? trailsResolved,
    DateTime? createdAt,
    List<TrackPhoto>? photos,
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
        trailsResolved: trailsResolved ?? this.trailsResolved,
        createdAt: createdAt ?? this.createdAt,
        photos: photos ?? this.photos,
      );

  /// Azzera i dati calcolati (quando i waypoint cambiano in modifica). Le
  /// [photos] **sopravvivono**: modificare il tracciato non deve scollegare
  /// le foto già associate (la loro `distanceMeters` potrà risultare un po'
  /// stale finché non si ricalcola, non è un dato critico).
  DrawnTrack clearedComputed() => DrawnTrack(
        id: id,
        waypoints: waypoints,
        name: name,
        color: color,
        snapToTrail: snapToTrail,
        createdAt: createdAt,
        photos: photos,
      );
}

/// Stato dell'editor multi-traccia.
class TracksState {
  const TracksState({
    this.tracks = const [],
    this.editingId,
    this.selectedId,
    this.savingId,
    this.resolvingTrailsId,
    this.geometryNonce = 0,
    this.undoDepth = 0,
  });

  final List<DrawnTrack> tracks;
  final String? editingId;
  final String? selectedId;

  /// Profondità dello stack di undo della sessione di editing corrente (0 fuori
  /// editing). Serve alla UI per abilitare il tasto "Annulla".
  final int undoDepth;

  /// Se c'è almeno un'operazione annullabile.
  bool get canUndo => undoDepth > 0;

  /// Id della traccia per cui è in corso calcolo+salvataggio dopo il "Fine".
  final String? savingId;

  /// Id della traccia per cui è in corso la ricerca lazy di segnavia/difficoltà
  /// (backfill di una traccia vecchia alla selezione). Mostra lo spinner nella
  /// card senza toccare la geometria.
  final String? resolvingTrailsId;

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

/// Chiave di un segmento (coppia di waypoint + snap) per la cache di routing.
class _SegKey {
  const _SegKey(this.a, this.b, this.snap);
  final LatLng a;
  final LatLng b;
  final bool snap;

  @override
  bool operator ==(Object other) =>
      other is _SegKey &&
      other.snap == snap &&
      other.a.latitude == a.latitude &&
      other.a.longitude == a.longitude &&
      other.b.latitude == b.latitude &&
      other.b.longitude == b.longitude;

  @override
  int get hashCode =>
      Object.hash(a.latitude, a.longitude, b.latitude, b.longitude, snap);
}

/// Instrada un **singolo segmento** (un tratto non instradabile degrada solo
/// quel segmento a linea retta; snap OFF → retta diretta). La cache per-chiave
/// di Riverpod fa sì che, a una modifica, si ricalcolino **solo** i segmenti la
/// cui coppia di estremi è cambiata (ri-instradamento incrementale); gli altri
/// restano cache-hit.
final segmentRouteProvider =
    FutureProvider.family<List<LatLng>, _SegKey>((ref, key) async {
  if (!key.snap) return [key.a, key.b];
  try {
    final seg = await ref.read(routingServiceProvider).route([key.a, key.b]);
    return seg.geometry.length >= 2 ? seg.geometry : [key.a, key.b];
  } on RoutingException catch (e) {
    debugPrint('[routing] segmento → retta: ${e.message}');
    return [key.a, key.b];
  }
});

/// Concatena i segmenti instradati in un percorso unico. [get] sceglie la
/// modalità: `ref.watch(...future)` (anteprima reattiva) o `ref.read(...future)`
/// (uso una-tantum al salvataggio, che riusa la cache dell'anteprima).
Future<List<LatLng>> _concatSegments(
  List<LatLng> wp,
  bool snap,
  Future<List<LatLng>> Function(_SegKey) get,
) async {
  if (wp.length < 2) return wp;
  final segs = await Future.wait([
    for (var i = 0; i < wp.length - 1; i++) get(_SegKey(wp[i], wp[i + 1], snap)),
  ]);
  final path = <LatLng>[wp.first];
  for (final s in segs) {
    path.addAll(s.skip(1));
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

  /// Stack di undo della sessione di editing: ogni voce è uno snapshot dei
  /// waypoint **prima** di una mutazione (add/move/remove/insert). `undo()` fa
  /// pop. Si azzera all'inizio/fine di ogni sessione di editing.
  final List<List<LatLng>> _undoStack = [];

  /// Registra lo stato dei waypoint prima di una mutazione (per l'undo).
  void _pushUndo() {
    final t = state.editing;
    if (t == null) return;
    _undoStack.add(List<LatLng>.of(t.waypoints));
  }

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
    // l'utente sta già disegnando/salvando/**importando**: preserva l'eventuale
    // traccia in corso non ancora su disco, altrimenti la sovrascriveremmo con i
    // dati del disco (su install pulita = lista vuota → traccia azzerata).
    final inProgressId =
        state.editingId ?? state.savingId ?? ref.read(importLoadingProvider);
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
    _undoStack.clear();
    state = TracksState(tracks: [...tracks, track], editingId: track.id, geometryNonce: state.geometryNonce + 1);
  }

  void editSelected() {
    if (state.selectedId == null) return;
    _editSnapshot = state.byId(state.selectedId); // per ripristino su Annulla
    _undoStack.clear();
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
    _undoStack.clear();
    ref.read(importPreviewProvider.notifier).clear(); // via il riferimento grezzo
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
    _undoStack.clear();
    ref.read(importPreviewProvider.notifier).clear(); // via il riferimento grezzo

    if (track.waypoints.length < 2) {
      state = TracksState(
        tracks: state.tracks.where((t) => t.id != id).toList(),
        geometryNonce: state.geometryNonce + 1,
      );
      return;
    }

    // Import **non modificato** (o traccia già instradata): il percorso è già
    // valido → non ri-instradare (preserva il risultato ibrido dell'import),
    // seleziona e persisti così com'è.
    if (track.routedPath.length >= 2 && track.metrics != null) {
      state = TracksState(
        tracks: state.tracks,
        selectedId: id,
        geometryNonce: state.geometryNonce + 1,
      );
      final saved = state.byId(id);
      if (saved != null) {
        final now = DateTime.now();
        try {
          await ref.read(tracksRepositoryProvider).save(saved, updatedAt: now);
        } catch (_) {/* best-effort */}
        unawaited(ref.read(cloudSyncProvider.notifier).autoPush(saved, now));
      }
      return;
    }

    // Chiude la modalità disegno ma **mantiene la traccia selezionata**: la card
    // resta aperta e mostra un indicatore di caricamento mentre il calcolo
    // prosegue in background (savingId = id → spinner + animazione traccia). I
    // dati (percorso/metriche/segnavia) vengono riempiti quando pronti.
    state = TracksState(
      tracks: state.tracks,
      selectedId: id,
      savingId: id,
      geometryNonce: state.geometryNonce,
    );

    // Riusa la cache dei segmenti già instradati dall'anteprima (read → hit).
    final path = await _concatSegments(track.waypoints, track.snapToTrail,
        (k) => ref.read(segmentRouteProvider(k).future));

    TrackMetrics? metrics;
    try {
      metrics = await const TrackMetricsCalculator()
          .compute(path, ref.read(elevationServiceProvider));
    } catch (_) {
      metrics = null;
    }

    // Numeri sentiero per tratto (per il grafico) + elenco unico (per i chip).
    // `trailsResolved` = true solo se la ricerca è **andata a buon fine** (anche
    // con esito vuoto): su errore resta false così la selezione futura ritenta.
    List<TrailSegment> segments = const [];
    var trailsResolved = false;
    try {
      segments = await ref.read(trailServiceProvider).trailSegmentsAlong(path);
      trailsResolved = true;
    } catch (_) {
      segments = const [];
      trailsResolved = false;
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
            t.copyWith(
                routedPath: path,
                metrics: metrics,
                trailRefs: refs,
                trailsResolved: trailsResolved)
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

  void select(String id) {
    state = TracksState(
        tracks: state.tracks,
        selectedId: id,
        geometryNonce: state.geometryNonce);
    // Backfill lazy: se la traccia non ha mai cercato segnavia/difficoltà, li
    // cerca ora (una volta sola). Best-effort, non blocca la selezione.
    unawaited(_resolveTrailsIfNeeded(id));
  }

  /// Cerca segnavia + grado di difficoltà per una traccia **selezionata** che
  /// non li ha mai cercati (`trailsResolved == false`: tipicamente tracce vecchie
  /// salvate prima della funzionalità). Se erano già stati cercati — anche con
  /// esito vuoto — non fa nulla (niente ricalcolo a ogni riselezione).
  Future<void> _resolveTrailsIfNeeded(String id) async {
    final track = state.byId(id);
    if (track == null) return;
    if (track.trailsResolved) return; // già cercati (anche se vuoti)
    if (track.routedPath.length < 2) return; // niente geometria su cui cercare
    if (state.resolvingTrailsId != null) return; // una ricerca alla volta

    // Spinner nella card (geometria invariata → geometryNonce fermo).
    state = TracksState(
      tracks: state.tracks,
      editingId: state.editingId,
      selectedId: state.selectedId,
      savingId: state.savingId,
      resolvingTrailsId: id,
      geometryNonce: state.geometryNonce,
    );

    List<TrailSegment> segments = const [];
    var resolved = false;
    try {
      segments = await ref
          .read(trailServiceProvider)
          .trailSegmentsAlong(track.routedPath);
      resolved = true;
    } catch (_) {
      resolved = false;
    }
    final refs = <String>{for (final s in segments) s.ref}.toList()..sort();

    // Applica i risultati (se la traccia esiste ancora) e togli lo spinner.
    final stillThere = state.byId(id) != null;
    state = TracksState(
      tracks: [
        for (final t in state.tracks)
          if (t.id == id && resolved)
            t.copyWith(
              trailRefs: refs,
              metrics: t.metrics?.copyWith(trailSegments: segments),
              trailsResolved: true,
            )
          else
            t,
      ],
      editingId: state.editingId,
      selectedId: state.selectedId,
      savingId: state.savingId,
      // resolvingTrailsId azzerato.
      geometryNonce: state.geometryNonce,
    );

    // Persiste il backfill (best-effort) + auto-sync cloud.
    if (resolved && stillThere) {
      final saved = state.byId(id);
      if (saved != null) {
        final now = DateTime.now();
        try {
          await ref.read(tracksRepositoryProvider).save(saved, updatedAt: now);
        } catch (_) {/* best-effort */}
        unawaited(ref.read(cloudSyncProvider.notifier).autoPush(saved, now));
      }
    }
  }

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

  /// Generazione dell'import corrente: `cancelImport()` la incrementa per
  /// invalidare (annullare) un `_runImport` in volo.
  int _importGen = 0;

  /// Importa una traccia da GPX con **riallineamento ibrido**, in due fasi:
  /// 1) **caricamento** (annullabile) che semplifica la grezza e la instrada lungo
  ///    i sentieri (snap dove coincide, grezza fuori sentiero);
  /// 2) **revisione/editing**: si entra in modifica sulla traccia ricalcolata, con
  ///    la grezza ancora **tratteggiata** come riferimento; si persiste **solo al
  ///    Salva**. Ritorna `null` se l'import è **avviato**, o un messaggio d'errore.
  Future<String?> importGpx(String xml) async {
    final ({String name, List<LatLng> path}) parsed;
    try {
      parsed = const GpxService().parseTrack(xml);
    } on FormatException catch (e) {
      return e.message;
    } catch (_) {
      return 'GPX non valido';
    }

    final id = _newId();
    final idxs = const PolylineSimplifier()
        .simplifyIndices(parsed.path, tolerance: 30, maxPoints: 40);
    final waypoints = [for (final i in idxs) parsed.path[i]];
    final track = DrawnTrack(
      id: id,
      name: parsed.name.isNotEmpty ? parsed.name : 'Importato',
      snapToTrail: true,
      waypoints: waypoints,
      createdAt: DateTime.now(),
    );
    // Fase 1 — caricamento: la traccia esiste (per il focus mappa) ma **non** è
    // selezionata/in editing né persistita; la grezza è tratteggiata e la card
    // di caricamento (annullabile) è attiva via importLoadingProvider.
    final gen = ++_importGen;
    state = TracksState(
        tracks: [...state.tracks, track],
        geometryNonce: state.geometryNonce + 1);
    ref.read(importPreviewProvider.notifier).set(id, parsed.path);
    ref.read(importLoadingProvider.notifier).set(id);
    unawaited(_runImport(gen, id, parsed.path, idxs));
    return null;
  }

  /// Instradamento ibrido + metriche + segnavia (fase 1), poi passaggio in
  /// **editing** sulla traccia ricalcolata (fase 2). Annullabile: `cancelImport`
  /// incrementa `_importGen` (o rimuove la traccia) → qui si esce senza effetti.
  Future<void> _runImport(
      int gen, String id, List<LatLng> raw, List<int> idxs) async {
    bool cancelled() => gen != _importGen || state.byId(id) == null;

    final routed = await _hybridRoute(raw, idxs, cancelled);
    if (cancelled()) return;

    TrackMetrics? metrics;
    try {
      metrics = await const TrackMetricsCalculator()
          .compute(routed, ref.read(elevationServiceProvider));
    } catch (_) {
      metrics = null;
    }
    if (cancelled()) return;

    List<TrailSegment> segments = const [];
    var resolved = false;
    try {
      segments = await ref.read(trailServiceProvider).trailSegmentsAlong(routed);
      resolved = true;
    } catch (_) {
      resolved = false;
    }
    if (cancelled()) return;
    final refs = <String>{for (final s in segments) s.ref}.toList()..sort();
    if (metrics != null && segments.isNotEmpty) {
      metrics = metrics.copyWith(trailSegments: segments);
    }

    // Fase 2 — editing/revisione: routedPath = ibrido; la grezza resta come
    // riferimento (importPreview). Traccia "nuova" → l'annulla la scarta; si
    // persiste solo al Salva (finishDrawing).
    _editSnapshot = null;
    _undoStack.clear();
    ref.read(importLoadingProvider.notifier).set(null);
    state = TracksState(
      tracks: [
        for (final t in state.tracks)
          if (t.id == id)
            t.copyWith(
                routedPath: routed,
                metrics: metrics,
                trailRefs: refs,
                trailsResolved: resolved)
          else
            t,
      ],
      editingId: id,
      geometryNonce: state.geometryNonce + 1,
    );
  }

  /// Annulla l'import in corso (dalla card di caricamento): scarta la traccia e
  /// i riferimenti; il `_runImport` in volo si autoinvalida (`_importGen`).
  void cancelImport() {
    _importGen++;
    final id = ref.read(importLoadingProvider);
    ref.read(importLoadingProvider.notifier).set(null);
    ref.read(importPreviewProvider.notifier).clear();
    if (id != null) {
      state = TracksState(
        tracks: state.tracks.where((t) => t.id != id).toList(),
        geometryNonce: state.geometryNonce + 1,
      );
    }
  }

  /// Instrada i segmenti (snap) e, per ciascuno, sceglie snap **oppure** il
  /// tratto grezzo se lo snap devia troppo (fuori sentiero / detour).
  Future<List<LatLng>> _hybridRoute(
      List<LatLng> raw, List<int> idxs, bool Function() cancelled) async {
    const geo = PathGeometry();
    final keys = [
      for (var k = 0; k < idxs.length - 1; k++)
        _SegKey(raw[idxs[k]], raw[idxs[k + 1]], true),
    ];
    final snaps = await _snapBounded(keys, cancelled);
    final path = <LatLng>[raw[idxs.first]];
    for (var k = 0; k < idxs.length - 1; k++) {
      final rawSub = raw.sublist(idxs[k], idxs[k + 1] + 1);
      final snapped = snaps[k].length >= 2 ? snaps[k] : [raw[idxs[k]], raw[idxs[k + 1]]];
      final rawLen = geo.totalDistance(rawSub);
      final snapLen = geo.totalDistance(snapped);
      var maxDev = 0.0;
      for (final p in snapped) {
        final d = geo.distanceToPath(p, rawSub);
        if (d > maxDev) maxDev = d;
      }
      // Snap accettato solo se resta **vicino** alla grezza e non troppo più
      // lungo; altrimenti si tiene il sotto-tratto grezzo.
      final diverges = (rawLen > 1 && snapLen > 1.6 * rawLen) || maxDev > 60;
      path.addAll((diverges ? rawSub : snapped).skip(1));
    }
    return path;
  }

  /// Instrada [keys] con concorrenza limitata (gentile col server BRouter
  /// pubblico) riusando la cache di `segmentRouteProvider`. Si ferma se [cancelled].
  Future<List<List<LatLng>>> _snapBounded(
      List<_SegKey> keys, bool Function() cancelled,
      {int concurrency = 6}) async {
    final out = List<List<LatLng>>.filled(keys.length, const []);
    var next = 0;
    Future<void> worker() async {
      while (true) {
        if (cancelled()) break;
        final i = next++;
        if (i >= keys.length) break;
        out[i] = await ref.read(segmentRouteProvider(keys[i]).future);
      }
    }

    await Future.wait(
        [for (var w = 0; w < concurrency && w < keys.length; w++) worker()]);
    return out;
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
      undoDepth: _undoStack.length,
    );
  }

  void setName(String name) => _updateEditing((t) => t.copyWith(name: name), affectsGeometry: false);
  void setColor(Color c) => _updateEditing((t) => t.copyWith(color: c));

  /// Attiva/disattiva lo snap-to-trail della traccia in modifica. Con OFF il
  /// percorso è la linea retta tra i waypoint (utile fuori sentiero: ghiacciai,
  /// creste senza tracce OSM, dove BRouter devierebbe su way non pertinenti).
  /// Cambia la geometria → azzera i dati calcolati e aggiorna l'anteprima.
  void setSnap(bool snap) =>
      _updateEditing((t) => t.clearedComputed().copyWith(snapToTrail: snap));

  void addPoint(LatLng p) {
    if (state.editing == null) return;
    _pushUndo();
    _updateEditing(
        (t) => t.clearedComputed().copyWith(waypoints: [...t.waypoints, p]));
  }

  /// Annulla l'ultima operazione sui waypoint (stack di undo della sessione).
  void undo() {
    if (_undoStack.isEmpty) return;
    final prev = _undoStack.removeLast();
    _updateEditing((t) => t.clearedComputed().copyWith(waypoints: prev));
  }

  void movePoint(int index, LatLng p) {
    final t = state.editing;
    if (t == null || index < 0 || index >= t.waypoints.length) return;
    _pushUndo();
    _updateEditing((tt) =>
        tt.clearedComputed().copyWith(waypoints: [...tt.waypoints]..[index] = p));
  }

  void removePoint(int index) {
    final t = state.editing;
    if (t == null || index < 0 || index >= t.waypoints.length) return;
    _pushUndo();
    _updateEditing((tt) =>
        tt.clearedComputed().copyWith(waypoints: [...tt.waypoints]..removeAt(index)));
  }

  /// Inserisce un waypoint a [index] (split di un segmento con le maniglie di
  /// metà-segmento). [index] in `[0, lunghezza]`.
  void insertPoint(int index, LatLng p) {
    final t = state.editing;
    if (t == null || index < 0 || index > t.waypoints.length) return;
    _pushUndo();
    _updateEditing((tt) =>
        tt.clearedComputed().copyWith(waypoints: [...tt.waypoints]..insert(index, p)));
  }
}

final tracksProvider = NotifierProvider<Tracks, TracksState>(Tracks.new);

/// Indice del **waypoint selezionato** durante l'editing (per evidenziarlo in
/// mappa ed eliminarlo con conferma). `null` = nessuna selezione. Si azzera al
/// cambio di traccia/sessione; la mappa lo azzera anche a ogni cambio di
/// geometria (aggiungi/sposta/rimuovi/inserisci → gli indici cambiano).
class SelectedWaypoint extends Notifier<int?> {
  @override
  int? build() {
    ref.watch(activeTrackIdProvider);
    return null;
  }

  /// Tap sullo stesso punto = deseleziona; su un altro = seleziona.
  void toggle(int i) => state = state == i ? null : i;
  void clear() => state = null;
}

final selectedWaypointProvider =
    NotifierProvider<SelectedWaypoint, int?>(SelectedWaypoint.new);

/// Traccia **grezza** importata, da mostrare **tratteggiata** sulla mappa mentre
/// l'import la instrada (riferimento). `(id, raw)` durante l'import; `null` a
/// import concluso (poi si tiene solo la versione instradata).
class ImportPreview extends Notifier<(String, List<LatLng>)?> {
  @override
  (String, List<LatLng>)? build() => null;
  void set(String id, List<LatLng> raw) => state = (id, raw);
  void clear() => state = null;
}

final importPreviewProvider =
    NotifierProvider<ImportPreview, (String, List<LatLng>)?>(ImportPreview.new);

/// Id della traccia il cui import è in **fase di caricamento** (instradamento in
/// corso, annullabile). `null` quando non c'è un import in caricamento.
class ImportLoading extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final importLoadingProvider =
    NotifierProvider<ImportLoading, String?>(ImportLoading.new);

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
  // Percorso = concatenazione dei segmenti (cache per-segmento → incrementale:
  // spostando/inserendo un punto si ricalcolano solo i 1-2 segmenti toccati).
  return _concatSegments(
      waypoints, snap, (k) => ref.watch(segmentRouteProvider(k).future));
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

/// Visibilità del grafico del profilo (toggle dal tasto "Percorso").
class ProfileVisible extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(activeTrackIdProvider); // reset (chiuso) al cambio traccia
    // Il grafico è **chiuso di default**: si apre esplicitamente col tasto
    // "Percorso". Coerente sia sulle tracce appena salvate sia su quelle
    // esistenti riselezionate.
    return false;
  }

  void toggle() => state = !state;
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
