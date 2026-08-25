import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/util/format.dart';
import '../data/trails/trail_service.dart';
import '../features/draw_route/route_editor_provider.dart'
    show trackCardExpandedProvider;
import '../features/map_gl/inspected_point_provider.dart';
import '../features/map_gl/trail_detail_provider.dart';
import 'app_bottom_sheet.dart';
import 'ios_menu.dart';
import 'tokens.dart';

/// Punto d'ingresso da una label segnavia **già risolta** (card del punto
/// ispezionato, che ha già la `TrailRelation` completa con id/fonte):
/// conferma prima di aprire (evita aperture accidentali con un fetch di
/// rete dietro), poi la card di dettaglio — che si aggiorna da sola mentre
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
      // Focus sul segnavia: la card sotto (punto ispezionato o traccia) non
      // deve restare in sovrimpressione mentre si guarda il percorso intero.
      ref.read(inspectedPointProvider.notifier).clear();
      ref.read(trackCardExpandedProvider.notifier).collapse();
      startFetch();
      if (context.mounted) {
        showAppBottomSheet<void>(
          context: context,
          builder: (_) => const _TrailDetailSheet(),
        ).whenComplete(() => ref.read(trailDetailProvider.notifier).clear());
      }
    },
  );
}

class _TrailDetailSheet extends ConsumerWidget {
  const _TrailDetailSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trailDetailProvider);
    final palette = context.palette;
    if (state == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSheetHeader(
          title: 'Segnavia ${state.relation.ref}',
          onClose: () => Navigator.of(context).pop(),
        ),
        switch (state.stage) {
          TrailDetailStage.loading => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CupertinoActivityIndicator()),
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
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(d.officialUrl!),
                mode: LaunchMode.externalApplication),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Scheda ufficiale',
                    style: AppText.body.copyWith(color: palette.accent)),
                const SizedBox(width: 4),
                Icon(CupertinoIcons.arrow_up_right_square,
                    size: 14, color: palette.accent),
              ],
            ),
          ),
        ],
        // Risultati CAI Varallo (solo per i segnavia in Valsesia e dintorni,
        // §"Un segnavia per intero" — richiesta esplicita dell'utente, 24
        // ago 2026): 0 o più, ognuno un link a sé, non un unico "scopri di
        // più" — il sito non ha una pagina segnavia dedicata univoca, la
        // ricerca può restituire più contenuti pertinenti (eventi, rifugi,
        // itinerari) e l'utente sceglie quale aprire.
        if (d.caiVaralloResults.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Trovato anche su CAI Varallo',
              style: AppText.captionSmall.copyWith(color: palette.secondaryLabel)),
          const SizedBox(height: 6),
          for (final r in d.caiVaralloResults)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () =>
                    launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body.copyWith(color: palette.accent)),
                    ),
                    const SizedBox(width: 4),
                    Icon(CupertinoIcons.arrow_up_right_square,
                        size: 14, color: palette.accent),
                  ],
                ),
              ),
            ),
        ],
      ],
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
