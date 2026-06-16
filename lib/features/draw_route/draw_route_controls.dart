import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/format.dart';
import '../../ui/elevation_profile_chart.dart';
import 'route_editor_provider.dart';

/// Pannello inferiore di controllo del disegno tracciato (1.B): mostra distanza
/// live e dislivello, con azioni undo/clear/calcola.
class DrawRouteControls extends ConsumerWidget {
  const DrawRouteControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(routeEditorProvider);
    if (!editor.drawing && editor.points.isEmpty) {
      return const SizedBox.shrink();
    }

    final distance = ref.watch(routeDistanceProvider);
    final metrics = ref.watch(routeMetricsProvider);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                Text('${editor.points.length} punti',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton.icon(
                  onPressed: editor.points.isEmpty
                      ? null
                      : () => ref.read(routeEditorProvider.notifier).undo(),
                  icon: const Icon(Icons.undo),
                  label: const Text('Annulla'),
                ),
                TextButton.icon(
                  onPressed: editor.points.isEmpty
                      ? null
                      : () {
                          ref.read(routeEditorProvider.notifier).clear();
                          ref.read(routeMetricsProvider.notifier).reset();
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Pulisci'),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: editor.canCompute && !metrics.isLoading
                      ? () => ref.read(routeMetricsProvider.notifier).compute()
                      : null,
                  icon: metrics.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.terrain),
                  label: const Text('Dislivello'),
                ),
              ],
            ),
            metrics.maybeWhen(
              data: (m) => m == null || m.profile.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ElevationProfileChart(profile: m.profile),
                    ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Quota non disponibile: $e',
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
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
