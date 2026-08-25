import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/util/format.dart';
import '../data/trails/trail_service.dart';
import '../features/draw_route/route_editor_provider.dart' show tracksProvider;
import '../features/map_gl/inspected_point_provider.dart';
import '../features/map_gl/trail_detail_provider.dart';
import 'app_bottom_sheet.dart';
import 'ios_menu.dart';
import 'tokens.dart';

/// Punto d'ingresso da una label segnavia **già risolta** (card del punto
/// ispezionato, che ha già la `TrailRelation` completa con id/fonte):
/// conferma prima di aprire (evita aperture accidentali con un fetch di
/// rete dietro), poi la card di dettaglio ([TrailDetailCard], persistente
/// nello `Stack` di `map_gl_screen.dart`) — che si aggiorna da sola mentre
/// [TrailDetailNotifier.open] risolve in background.
Future<void> showTrailDetail(
        BuildContext context, WidgetRef ref, TrailRelation relation) =>
    _confirmThenOpen(context, ref, relation.ref,
        () => ref.read(trailDetailProvider.notifier).open(relation));

/// Come [showTrailDetail], ma da una label che ha **solo il numero
/// segnavia** (card traccia, `_TrailInfo` in `draw_route_controls.dart`):
/// [anchorPoint] è un punto vicino usato per risolvere la relazione
/// completa prima del fetch vero e proprio — un passo in più sotto lo
/// stesso spinner, invisibile per l'utente.
Future<void> showTrailDetailByRef(
        BuildContext context, WidgetRef ref, String trailRef, LatLng anchorPoint) =>
    _confirmThenOpen(context, ref, trailRef,
        () => ref.read(trailDetailProvider.notifier).openByRef(trailRef, anchorPoint));

Future<void> _confirmThenOpen(BuildContext context, WidgetRef ref, String trailRef,
    VoidCallback startFetch) async {
  await showIosConfirm(
    context: context,
    title: 'Segnavia $trailRef',
    message: 'Vuoi vedere il percorso completo di questo segnavia?',
    confirmLabel: 'Approfondisci',
    destructive: false,
    onConfirm: () {
      // Da questo momento il focus è solo il segnavia: la card del punto
      // ispezionato o della traccia selezionata non deve restare aperta
      // sotto — chiusura **completa**, non solo ridotta (richiesta esplicita
      // dell'utente dopo aver visto la traccia restare a metà schermo).
      ref.read(inspectedPointProvider.notifier).clear();
      ref.read(tracksProvider.notifier).deselect();
      startFetch();
    },
  );
}

/// Card di dettaglio segnavia: **persistente e non modale**, nello `Stack`
/// di `map_gl_screen.dart` come la card traccia/punto/foto — non più una
/// `showModalBottomSheet` (richiesta esplicita dell'utente, 25 ago 2026: con
/// lo scrim scuro e il tap-fuori che chiude tutto non si poteva esplorare la
/// mappa sottostante col percorso evidenziato). Visibile quando
/// [trailDetailProvider] non è `null`; il rendering del tracciato
/// tratteggiato sulla mappa è gestito a parte in `map_gl_screen.dart`
/// (`_renderTrailDetail`, invariato).
class TrailDetailCard extends ConsumerWidget {
  const TrailDetailCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trailDetailProvider);
    if (state == null) return const SizedBox.shrink();
    final palette = context.palette;

    return SizedBox(
      width: double.infinity,
      child: AppSheetSurface(
        floating: false,
        onDismiss: () => ref.read(trailDetailProvider.notifier).clear(),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSheetHeader(
                  title: 'Segnavia ${state.relation.ref}',
                  onClose: () => ref.read(trailDetailProvider.notifier).clear(),
                ),
                switch (state.stage) {
                  // Testo esplicativo sotto lo spinner (richiesta esplicita
                  // dell'utente, 25 ago 2026, dopo aver visto la ricerca
                  // impiegare fino a una ventina di secondi su un servizio
                  // pubblico sovraccarico): senza, uno spinner muto per
                  // svariati secondi sembra bloccato, non "sta ancora
                  // cercando".
                  TrailDetailStage.loading => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const CupertinoActivityIndicator(),
                          const SizedBox(height: 10),
                          Text(
                            'Cerco il percorso completo…',
                            textAlign: TextAlign.center,
                            style: AppText.footnote
                                .copyWith(color: palette.secondaryLabel),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Può richiedere una decina di secondi se la rete è lenta.',
                            textAlign: TextAlign.center,
                            style: AppText.footnote
                                .copyWith(color: palette.secondaryLabel),
                          ),
                        ],
                      ),
                    ),
                  TrailDetailStage.error => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        state.errorMessage ?? 'Segnavia non trovato.',
                        style: AppText.body.copyWith(color: palette.secondaryLabel),
                      ),
                    ),
                  TrailDetailStage.ready => _TrailDetailBody(detail: state.detail!),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrailDetailBody extends StatelessWidget {
  const _TrailDetailBody({required this.detail});

  final TrailDetail detail;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final d = detail;
    final hasEnds = (d.from?.isNotEmpty ?? false) || (d.to?.isNotEmpty ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (d.name != null) ...[
          Text(d.name!, style: AppText.value.copyWith(color: palette.label)),
          const SizedBox(height: 8),
        ],
        if (hasEnds) ...[
          Row(
            children: [
              Icon(CupertinoIcons.arrow_right, size: 15, color: palette.iconGreyLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${d.from ?? '?'} → ${d.to ?? '?'}',
                  style: AppText.body.copyWith(color: palette.bodyText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            if (d.distanceMeters != null)
              _StatChip(icon: CupertinoIcons.arrow_right_arrow_left,
                  label: Format.distance(d.distanceMeters!)),
            if (d.ascentMeters != null)
              _StatChip(icon: CupertinoIcons.arrow_up_right,
                  label: '+${d.ascentMeters!.round()} m'),
            if (d.descentMeters != null)
              _StatChip(icon: CupertinoIcons.arrow_down_right,
                  label: '-${d.descentMeters!.round()} m'),
            if (d.caiScale != null)
              _StatChip(icon: CupertinoIcons.checkmark_seal, label: d.caiScale!),
          ],
        ),
        if (d.officialUrl != null) ...[
          const SizedBox(height: 14),
          _ExternalLinkRow(
            label: 'OpenStreetMap',
            url: d.officialUrl!,
          ),
        ],
        // Fetch della geometria completa fallito (rete): mostrato comunque
        // tutto il resto (nome/capi-percorso/link), ma con un avviso — non
        // c'è un percorso completo da disegnare sulla mappa questa volta.
        // Introdotto il 25 ago 2026 dopo un fallimento totale di Overpass
        // durante un test dal vivo ("non ha senso non mostrare nulla").
        if (!d.geometryComplete) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.exclamationmark_triangle,
                  size: 14, color: palette.secondaryLabel),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Percorso completo non disponibile ora (rete) — riprova più tardi.',
                  style: AppText.footnote.copyWith(color: palette.secondaryLabel),
                ),
              ),
            ],
          ),
        ],
        // Corrispondenza nell'elenco ufficiale di CAI Varallo (solo per i
        // segnavia in Valsesia e dintorni) — match esatto sul ref, quindi al
        // più uno, non una lista di risultati "forse pertinenti" come nel
        // tentativo precedente (ricerca full-text su un altro sito, scartata
        // il 25 ago 2026 per risultati sbagliati).
        if (d.caiVarallo != null) ...[
          const SizedBox(height: 8),
          _ExternalLinkRow(label: 'CAI Varallo', url: d.caiVarallo!.url),
        ],
      ],
    );
  }
}

class _ExternalLinkRow extends StatelessWidget {
  const _ExternalLinkRow({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.body.copyWith(color: palette.accent)),
          const SizedBox(width: 4),
          Icon(CupertinoIcons.arrow_up_right_square, size: 14, color: palette.accent),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: palette.secondaryLabel),
        const SizedBox(width: 4),
        Text(label, style: AppText.footnote.copyWith(color: palette.secondaryLabel)),
      ],
    );
  }
}
