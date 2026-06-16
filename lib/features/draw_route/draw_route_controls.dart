import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/format.dart';
import '../../domain/services/track_metrics.dart';
import '../../ui/elevation_profile_chart.dart';
import 'route_editor_provider.dart';

/// Pannello inferiore di controllo della traccia attiva.
///
/// In **modifica/creazione**: nome, colore, snap, aggiungi/annulla punti, Fine,
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
    final distance = ref.watch(routeDistanceProvider);
    final liveMetrics = ref.watch(routeMetricsProvider);
    final canCompute = track?.canCompute ?? false;

    // In modifica le metriche sono live (on-demand); in selezione, memorizzate.
    final TrackMetrics? shownMetrics =
        drawing ? liveMetrics.value : track?.metrics;
    final metricsLoading = drawing && liveMetrics.isLoading;

    final profileVisible = ref.watch(profileVisibleProvider);
    final showingChart = profileVisible && shownMetrics != null;

    void toggleProfile() {
      if (shownMetrics == null && !metricsLoading) {
        ref.read(routeMetricsProvider.notifier).compute();
        ref.read(profileVisibleProvider.notifier).show();
      } else {
        ref.read(profileVisibleProvider.notifier).toggle();
      }
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (drawing)
              const _NameField()
            else
              Text(
                (track?.name.isNotEmpty ?? false) ? track!.name : 'Senza nome',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                _Metric(
                  icon: Icons.straighten,
                  label: 'Distanza',
                  value: Format.distance(distance),
                ),
                const SizedBox(width: 16),
                _GainLoss(metrics: shownMetrics),
              ],
            ),
            if (saving)
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
            if (drawing) ...[
              Row(
                children: [
                  Icon(
                      (track?.snapToTrail ?? true)
                          ? Icons.route
                          : Icons.timeline,
                      size: 18),
                  const SizedBox(width: 6),
                  const Text('Segui sentieri'),
                  const Spacer(),
                  Switch(
                    value: track?.snapToTrail ?? true,
                    onChanged: (_) =>
                        ref.read(tracksProvider.notifier).toggleSnap(),
                  ),
                ],
              ),
              _ColorPicker(selected: track?.color),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                // Dislivello a sinistra.
                FilledButton.tonalIcon(
                  onPressed: !canCompute || saving ? null : toggleProfile,
                  icon: metricsLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(showingChart ? Icons.unfold_less : Icons.terrain),
                  label: const Text('Dislivello'),
                ),
                const Spacer(),
                // Azioni primarie a destra.
                if (drawing) ...[
                  IconButton(
                    tooltip: 'Annulla ultimo punto',
                    onPressed: (track?.waypoints.isEmpty ?? true)
                        ? null
                        : () => ref.read(tracksProvider.notifier).undo(),
                    icon: const Icon(Icons.undo),
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.read(tracksProvider.notifier).finishDrawing(),
                    icon: const Icon(Icons.check),
                    label: const Text('Fine'),
                  ),
                ] else ...[
                  IconButton(
                    tooltip: 'Elimina percorso',
                    onPressed: saving
                        ? null
                        : () {
                            ref.read(tracksProvider.notifier).remove();
                            ref.read(profileCursorProvider.notifier).set(null);
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                  FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () =>
                            ref.read(tracksProvider.notifier).editSelected(),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifica'),
                  ),
                ],
              ],
            ),
            if (showingChart && !shownMetrics.profile.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevationProfileChart(
                  profile: shownMetrics.profile,
                  cursor: ref.watch(profileCursorProvider),
                  onCursor: (s) =>
                      ref.read(profileCursorProvider.notifier).set(s),
                ),
              ),
          ],
        ),
      ),
    );
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
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 4),
        Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.trending_up, size: 18),
        Text(' ${Format.meters(m.elevation.gain)}'),
        const SizedBox(width: 8),
        const Icon(Icons.trending_down, size: 18),
        Text(' ${Format.meters(m.elevation.loss)}'),
      ],
    );
  }
}
