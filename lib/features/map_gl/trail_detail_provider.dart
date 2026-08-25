import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/trails/trail_service.dart';
import '../draw_route/route_editor_provider.dart' show trailServiceProvider;

/// Fase del fetch della relazione completa (§"Un segnavia per intero").
enum TrailDetailStage { loading, ready, error }

/// Stato della card di dettaglio segnavia aperta (tap su una label + conferma
/// dialog). `null` = nessuna card aperta.
class TrailDetailState {
  const TrailDetailState({
    required this.relation,
    required this.stage,
    this.detail,
    this.errorMessage,
  });

  /// La relazione di partenza (ref/id/fonte) da cui è iniziato il fetch —
  /// serve anche a scartare una risposta arrivata in ritardo dopo che
  /// l'utente ha già chiuso o aperto un altro segnavia.
  final TrailRelation relation;
  final TrailDetailStage stage;
  final TrailDetail? detail;
  final String? errorMessage;
}

/// Notifier della card di dettaglio segnavia: [open] avvia il fetch (via
/// [trailServiceProvider], che smista OSM2CAI/Overpass in base a
/// [TrailRelation.source]) e aggiorna lo stato quando pronto; [clear] chiude
/// la card. Nessuna cache: riaprire lo stesso segnavia rifà il fetch — è
/// un'azione rara (tap deliberato + conferma), non vale la complessità di
/// una cache che potrebbe anche invecchiare.
class TrailDetailNotifier extends Notifier<TrailDetailState?> {
  @override
  TrailDetailState? build() => null;

  /// Come [open], ma partendo solo da un [ref] (numero segnavia) e un punto
  /// vicino — caso della card **traccia** (`_TrailInfo`,
  /// `draw_route_controls.dart`): le sue `trailRefs` sono solo stringhe,
  /// nessun `id`/fonte associato, quindi va prima **risolta** la relazione
  /// completa via [TrailService.trailsNear] sul punto vicino, poi si
  /// prosegue come [open]. Un passo in più sotto lo stesso spinner — non
  /// visibile per l'utente, solo un fetch di rete in più prima del secondo.
  Future<void> openByRef(String trailRef, LatLng anchorPoint) async {
    debugPrint('[trails] openByRef "$trailRef" da anchor '
        '(${anchorPoint.latitude}, ${anchorPoint.longitude})');
    // Placeholder solo per il titolo dello stato di caricamento: non ha
    // ancora un id/fonte, si scarta appena la risoluzione trova quello vero.
    final placeholder = TrailRelation(trailRef, const [], TrailSource.overpass);
    state = TrailDetailState(relation: placeholder, stage: TrailDetailStage.loading);
    List<TrailRelation> nearby;
    try {
      nearby = await ref
          .read(trailServiceProvider)
          .trailsNear(anchorPoint, thresholdMeters: 150);
    } catch (e) {
      debugPrint('[trails] openByRef "$trailRef": trailsNear ha lanciato: $e');
      nearby = const [];
    }
    debugPrint('[trails] openByRef "$trailRef": trailsNear ha trovato '
        '${nearby.length} relazioni vicine: '
        '${nearby.map((r) => "${r.ref}(${r.source.name},id=${r.id})").join(", ")}');
    if (!identical(state?.relation, placeholder)) {
      debugPrint('[trails] openByRef "$trailRef": stato cambiato nel frattempo, scarto');
      return;
    }
    TrailRelation? match;
    for (final r in nearby) {
      if (r.ref == trailRef) {
        match = r;
        break;
      }
    }
    if (match == null) {
      debugPrint('[trails] openByRef "$trailRef": nessuna relazione vicina ha '
          'questo ref esatto, provo comunque CAI Varallo prima di arrendermi');
      TrailDetail? fallback;
      try {
        fallback = await ref
            .read(trailServiceProvider)
            .fetchByRefOnly(trailRef, anchorPoint);
      } catch (e) {
        debugPrint('[trails] openByRef "$trailRef": fetchByRefOnly ha lanciato: $e');
        fallback = null;
      }
      if (!identical(state?.relation, placeholder)) return;
      if (fallback != null) {
        debugPrint('[trails] openByRef "$trailRef": trovato su CAI Varallo, '
            'mostro comunque (senza percorso completo)');
        state = TrailDetailState(
            relation: placeholder,
            stage: TrailDetailStage.ready,
            detail: fallback);
        return;
      }
      debugPrint('[trails] openByRef "$trailRef": non trovato nemmeno lì → non trovato');
      state = TrailDetailState(
        relation: placeholder,
        stage: TrailDetailStage.error,
        errorMessage: 'Segnavia non trovato — riprova più tardi.',
      );
      return;
    }
    debugPrint('[trails] openByRef "$trailRef": match trovato '
        '(${match.source.name}, id=${match.id})');
    await open(match);
  }

  Future<void> open(TrailRelation relation) async {
    debugPrint('[trails] open "${relation.ref}" (${relation.source.name}, '
        'id=${relation.id})');
    state = TrailDetailState(relation: relation, stage: TrailDetailStage.loading);
    TrailDetail? detail;
    try {
      detail = await ref.read(trailServiceProvider).fetchDetail(relation);
    } catch (e) {
      debugPrint('[trails] open "${relation.ref}": fetchDetail ha lanciato: $e');
      detail = null;
    }
    debugPrint('[trails] open "${relation.ref}": fetchDetail → '
        '${detail == null ? "null (non trovato)" : "${detail.points.length} punti"}');
    // Nel frattempo l'utente potrebbe aver chiuso la card o averne aperta
    // un'altra: una risposta in ritardo non deve sovrascriverla.
    if (!identical(state?.relation, relation)) {
      debugPrint('[trails] open "${relation.ref}": stato cambiato nel frattempo, scarto');
      return;
    }
    state = detail == null
        ? TrailDetailState(
            relation: relation,
            stage: TrailDetailStage.error,
            errorMessage: 'Segnavia non trovato — riprova più tardi.',
          )
        : TrailDetailState(
            relation: relation, stage: TrailDetailStage.ready, detail: detail);
  }

  void clear() => state = null;
}

final trailDetailProvider =
    NotifierProvider<TrailDetailNotifier, TrailDetailState?>(
        TrailDetailNotifier.new);
