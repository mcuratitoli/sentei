import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> open(TrailRelation relation) async {
    state = TrailDetailState(relation: relation, stage: TrailDetailStage.loading);
    TrailDetail? detail;
    try {
      detail = await ref.read(trailServiceProvider).fetchDetail(relation);
    } catch (_) {
      detail = null;
    }
    // Nel frattempo l'utente potrebbe aver chiuso la card o averne aperta
    // un'altra: una risposta in ritardo non deve sovrascriverla.
    if (!identical(state?.relation, relation)) return;
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
