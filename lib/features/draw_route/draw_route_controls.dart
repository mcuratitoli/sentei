import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/format.dart';
import '../../domain/services/track_metrics.dart';
import '../../ui/elevation_profile_chart.dart';
import '../offline_maps/track_offline_download.dart';
import 'route_editor_provider.dart';

/// Pannello inferiore di controllo della traccia attiva.
///
/// In **modifica/creazione**: nome, colore, aggiungi/annulla punti, Fine,
/// dislivello live on-demand. In **vista selezionata**: dati memorizzati al
/// "Fine" (distanza, D+/D-, profilo, numeri sentieri), modifica/elimina.
class DrawRouteControls extends ConsumerWidget {
  const DrawRouteControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(tracksProvider);
    if (!st.showCard) return const SizedBox.shrink();

    final track = st.active;
    final drawing = st.drawing;
    final saving = st.saving;
    // Durante il disegno: calcolo del percorso in corso a ogni nodo.
    final pathLoading =
        drawing && track != null && ref.watch(livePathProvider(track.id)).isLoading;
    final distance = ref.watch(routeDistanceProvider);
    final liveMetrics = ref.watch(routeMetricsProvider);
    final canCompute = track?.canCompute ?? false;

    // In modifica le metriche sono live (on-demand); in selezione, memorizzate.
    final TrackMetrics? shownMetrics =
        drawing ? liveMetrics.value : track?.metrics;
    final metricsLoading = drawing && liveMetrics.isLoading;

    final profileVisible = ref.watch(profileVisibleProvider);
    final showingChart = profileVisible && shownMetrics != null;
    final steepnessOn = ref.watch(steepnessVisibleProvider);
    final cursor = ref.watch(profileCursorProvider);

    void toggleProfile() {
      if (shownMetrics == null && !metricsLoading) {
        ref.read(routeMetricsProvider.notifier).compute();
        ref.read(profileVisibleProvider.notifier).show();
      } else {
        ref.read(profileVisibleProvider.notifier).toggle();
      }
    }

    return Card(
      // Vicino alla toolbar in basso (poco margine sotto).
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 2),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (drawing)
              const _NameField()
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (track?.name.isNotEmpty ?? false)
                          ? track!.name
                          : 'Senza nome',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Modifica',
                    visualDensity: VisualDensity.compact,
                    onPressed: saving
                        ? null
                        : () =>
                            ref.read(tracksProvider.notifier).editSelected(),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                _Metric(
                  icon: Icons.straighten,
                  value: Format.distance(distance),
                ),
                if (shownMetrics != null) ...[
                  const SizedBox(width: 14),
                  Container(
                    width: 1,
                    height: 18,
                    color: Theme.of(context).dividerColor,
                  ),
                  const SizedBox(width: 14),
                  _GainLoss(metrics: shownMetrics),
                ],
              ],
            ),
            if (pathLoading)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Calcolo percorso…', style: TextStyle(fontSize: 12)),
                ]),
              )
            else if (saving)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Calcolo dislivello e sentieri…',
                      style: TextStyle(fontSize: 12)),
                ]),
              )
            else if (!drawing && (track?.trailRefs.isNotEmpty ?? false))
              _TrailTags(refs: track!.trailRefs),
            if (drawing) _ColorPicker(selected: track?.color),
            const SizedBox(height: 4),
            // Controlli compatti: Percorso (profilo) · Ripidezza (icona) · azioni.
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: !canCompute || saving ? null : toggleProfile,
                  icon: metricsLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(showingChart ? Icons.unfold_less : Icons.terrain),
                  label: const Text('Percorso'),
                ),
                if (!drawing) ...[
                  const SizedBox(width: 4),
                  if (steepnessOn)
                    IconButton.filledTonal(
                      tooltip: 'Ripidezza',
                      onPressed: () =>
                          ref.read(steepnessVisibleProvider.notifier).toggle(),
                      icon: const Icon(Icons.stairs),
                    )
                  else
                    IconButton(
                      tooltip: 'Ripidezza',
                      onPressed: () =>
                          ref.read(steepnessVisibleProvider.notifier).toggle(),
                      icon: const Icon(Icons.stairs),
                    ),
                ],
                const Spacer(),
                if (drawing) ...[
                  IconButton(
                    tooltip: 'Annulla e chiudi',
                    onPressed: () => _confirmCancel(context, ref),
                    icon: const Icon(Icons.close),
                  ),
                  IconButton(
                    tooltip: 'Annulla ultimo punto',
                    onPressed: (track?.waypoints.isEmpty ?? true)
                        ? null
                        : () => ref.read(tracksProvider.notifier).undo(),
                    icon: const Icon(Icons.undo),
                  ),
                  FilledButton.icon(
                    onPressed: pathLoading
                        ? null
                        : () =>
                            ref.read(tracksProvider.notifier).finishDrawing(),
                    icon: const Icon(Icons.check),
                    label: const Text('Fine'),
                  ),
                ] else
                  IconButton(
                    tooltip: 'Salva offline',
                    onPressed: saving || track == null
                        ? null
                        : () => downloadTrackOffline(context, ref, track),
                    icon: const Icon(Icons.download_for_offline_outlined),
                  ),
              ],
            ),
            if (showingChart && !shownMetrics.profile.isEmpty) ...[
              const SizedBox(height: 4),
              // Slot fisso per la quota al cursore (spazio riservato sempre,
              // così la card non cambia altezza scorrendo il grafico).
              SizedBox(
                height: 16,
                child: Text(
                  cursor == null
                      ? 'Tocca il grafico per la quota del punto'
                      : 'Quota ${Format.meters(cursor.elevation)} · '
                          '${Format.distance(cursor.distanceMeters)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight:
                            cursor == null ? FontWeight.normal : FontWeight.bold,
                        color:
                            cursor == null ? Theme.of(context).hintColor : null,
                      ),
                ),
              ),
              ElevationProfileChart(
                profile: shownMetrics.profile,
                trailSegments: shownMetrics.trailSegments,
                cursor: cursor,
                steepness: steepnessOn,
                height: 120,
                onCursor: (s) =>
                    ref.read(profileCursorProvider.notifier).set(s),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chiede conferma e, se accordata, annulla la creazione/modifica in corso
/// chiudendo la card. Se non c'è ancora nulla da perdere (zero punti) chiude
/// direttamente senza dialog.
Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
  final st = ref.read(tracksProvider);
  final hasWork = (st.editing?.waypoints.isNotEmpty ?? false);
  if (!hasWork) {
    ref.read(tracksProvider.notifier).cancelEditing();
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Annullare?'),
      content: const Text(
          'Le modifiche non salvate al percorso andranno perse.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Continua a modificare'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Annulla percorso'),
        ),
      ],
    ),
  );
  if (ok == true) {
    ref.read(tracksProvider.notifier).cancelEditing();
  }
}

/// Chip con i numeri dei sentieri (ref CAI) attraversati dalla traccia.
class _TrailTags extends StatelessWidget {
  const _TrailTags({required this.refs});

  final List<String> refs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.signpost_outlined, size: 16),
          for (final r in refs)
            Chip(
              label: Text(r),
              labelStyle: const TextStyle(fontSize: 12),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

/// Selettore di colore per la traccia in modifica.
class _ColorPicker extends ConsumerWidget {
  const _ColorPicker({required this.selected});

  final Color? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.palette_outlined, size: 18),
          const SizedBox(width: 8),
          for (final c in kTrackPalette)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => ref.read(tracksProvider.notifier).setColor(c),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c == selected ? Colors.black : Colors.white,
                      width: c == selected ? 3 : 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Campo per dare un nome alla traccia in modifica. Sincronizzato col provider.
class _NameField extends ConsumerStatefulWidget {
  const _NameField();

  @override
  ConsumerState<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends ConsumerState<_NameField> {
  late final TextEditingController _controller = TextEditingController(
      text: ref.read(tracksProvider).active?.name ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tracksProvider.select((s) => s.active?.name ?? ''), (_, next) {
      if (next != _controller.text) _controller.text = next;
    });

    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        isDense: true,
        prefixIcon: Icon(Icons.edit_note),
        hintText: 'Nome percorso',
        border: OutlineInputBorder(),
      ),
      onChanged: (v) => ref.read(tracksProvider.notifier).setName(v),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 5),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _GainLoss extends StatelessWidget {
  const _GainLoss({required this.metrics});

  final TrackMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    if (m == null) return const SizedBox.shrink();
    final style = Theme.of(context)
        .textTheme
        .titleSmall
        ?.copyWith(fontWeight: FontWeight.bold);
    const up = Color(0xFF2E7D32);
    const down = Color(0xFFC62828);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.trending_up, size: 18, color: up),
        const SizedBox(width: 3),
        Text(Format.meters(m.elevation.gain), style: style),
        const SizedBox(width: 10),
        const Icon(Icons.trending_down, size: 18, color: down),
        const SizedBox(width: 3),
        Text(Format.meters(m.elevation.loss), style: style),
      ],
    );
  }
}
