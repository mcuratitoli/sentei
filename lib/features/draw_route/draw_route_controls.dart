import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/format.dart';
import '../../ui/elevation_profile_chart.dart';
import 'route_editor_provider.dart';

/// Pannello inferiore di controllo della traccia attiva.
///
/// Due modalità: **disegno/modifica** (nome, colore, snap, aggiungi/annulla
/// punti, Fine) e **selezionata** (nome in sola lettura, modifica/elimina/
/// dislivello). Visibile solo quando una traccia è in card (`showCard`).
class DrawRouteControls extends ConsumerWidget {
  const DrawRouteControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(tracksProvider);
    if (!st.showCard) return const SizedBox.shrink();

    final track = st.active;
    final drawing = st.drawing;
    final distance = ref.watch(routeDistanceProvider);
    final metrics = ref.watch(routeMetricsProvider);
    final routing = track != null &&
        ref.watch(routedPathProvider(track.id)).isLoading;
    final canCompute = track?.canCompute ?? false;
    final profileVisible = ref.watch(profileVisibleProvider);
    final showingChart = profileVisible && metrics.value != null;

    void toggleProfile() {
      if (metrics.value == null && !metrics.isLoading) {
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
            // Nome: editabile solo in modifica/creazione.
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
                _GainLoss(metrics: metrics),
                const Spacer(),
                if (routing)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (drawing) ...[
              Row(
                children: [
                  Icon(track?.snapToTrail ?? true
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
                  onPressed: !canCompute ? null : toggleProfile,
                  icon: metrics.isLoading
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
                    onPressed: () {
                      ref.read(tracksProvider.notifier).remove();
                      ref.read(profileCursorProvider.notifier).set(null);
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.read(tracksProvider.notifier).editSelected(),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifica'),
                  ),
                ],
              ],
            ),
            if (showingChart)
              metrics.maybeWhen(
                data: (m) => m == null || m.profile.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ElevationProfileChart(
                          profile: m.profile,
                          cursor: ref.watch(profileCursorProvider),
                          onCursor: (s) =>
                              ref.read(profileCursorProvider.notifier).set(s),
                        ),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            metrics.maybeWhen(
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Quota non disponibile: $e',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
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

  final AsyncValue<dynamic> metrics;

  @override
  Widget build(BuildContext context) {
    return metrics.maybeWhen(
      data: (m) => m == null
          ? const SizedBox.shrink()
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up, size: 18),
                Text(' ${Format.meters(m.elevation.gain)}'),
                const SizedBox(width: 8),
                const Icon(Icons.trending_down, size: 18),
                Text(' ${Format.meters(m.elevation.loss)}'),
              ],
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
