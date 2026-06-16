import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/format.dart';
import '../../ui/elevation_profile_chart.dart';
import 'route_editor_provider.dart';

/// Pannello inferiore di controllo del tracciato.
///
/// Due modalità: **disegno** (aggiungi/annulla punti, snap, Fine) e
/// **selezionato** (modifica, elimina, dislivello). Visibile solo quando si
/// disegna o il percorso è selezionato (vedi `RouteEditorState.showCard`).
class DrawRouteControls extends ConsumerWidget {
  const DrawRouteControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(routeEditorProvider);
    if (!editor.showCard) return const SizedBox.shrink();

    final distance = ref.watch(routeDistanceProvider);
    final metrics = ref.watch(routeMetricsProvider);
    final routing = ref.watch(routedPathProvider).isLoading;
    final showingProfile = metrics.value != null;

    void hideProfile() {
      ref.read(routeMetricsProvider.notifier).reset();
      ref.read(profileCursorProvider.notifier).set(null);
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _NameField(),
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
            if (editor.drawing)
              Row(
                children: [
                  Icon(editor.snapToTrail ? Icons.route : Icons.timeline,
                      size: 18),
                  const SizedBox(width: 6),
                  const Text('Segui sentieri'),
                  const Spacer(),
                  Switch(
                    value: editor.snapToTrail,
                    onChanged: (_) =>
                        ref.read(routeEditorProvider.notifier).toggleSnap(),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (editor.drawing) ...[
                  FilledButton.icon(
                    onPressed: () =>
                        ref.read(routeEditorProvider.notifier).finishDrawing(),
                    icon: const Icon(Icons.check),
                    label: const Text('Fine'),
                  ),
                  IconButton(
                    tooltip: 'Annulla ultimo punto',
                    onPressed: editor.waypoints.isEmpty
                        ? null
                        : () => ref.read(routeEditorProvider.notifier).undo(),
                    icon: const Icon(Icons.undo),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: () =>
                        ref.read(routeEditorProvider.notifier).startDrawing(),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifica'),
                  ),
                  IconButton(
                    tooltip: 'Elimina percorso',
                    onPressed: () {
                      ref.read(routeEditorProvider.notifier).clear();
                      hideProfile();
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: !editor.canCompute || metrics.isLoading
                      ? null
                      : showingProfile
                          ? hideProfile
                          : () =>
                              ref.read(routeMetricsProvider.notifier).compute(),
                  icon: metrics.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(showingProfile ? Icons.expand_more : Icons.terrain),
                  label: Text(showingProfile ? 'Nascondi' : 'Dislivello'),
                ),
              ],
            ),
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

/// Campo per dare un nome al percorso. Sincronizzato col provider (anche su reset).
class _NameField extends ConsumerStatefulWidget {
  const _NameField();

  @override
  ConsumerState<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends ConsumerState<_NameField> {
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(routeEditorProvider).name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Allinea il campo a reset/modifiche esterne dello stato.
    ref.listen(routeEditorProvider.select((s) => s.name), (_, next) {
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
      onChanged: (v) => ref.read(routeEditorProvider.notifier).setName(v),
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
