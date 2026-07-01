import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoAlertDialog,
        CupertinoButton,
        CupertinoDialogAction,
        CupertinoIcons,
        CupertinoSwitch,
        CupertinoTextField,
        showCupertinoDialog;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/format.dart';
import '../../domain/services/track_metrics.dart';
import '../../ui/cai_difficulty.dart';
import '../../ui/elevation_profile_chart.dart';
import '../../ui/glass.dart';
import '../offline_maps/track_offline_download.dart';
import 'route_editor_provider.dart';

/// Pannello inferiore di controllo della traccia attiva.
///
/// - **Creazione/modifica**: vista essenziale — nome, colore, annulla/undo/salva
///   (niente distanza né profilo: si calcolano al salvataggio).
/// - **Selezionata**: dati memorizzati (distanza, D+/D-, numeri sentiero, grado
///   di difficoltà CAI), profilo altimetrico e ripidezza on-demand. Subito dopo
///   il "Salva" la card **resta aperta** con un indicatore di caricamento finché
///   percorso/metriche/segnavia non sono pronti.
class DrawRouteControls extends ConsumerWidget {
  const DrawRouteControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCard = ref.watch(tracksProvider.select((s) => s.showCard));
    if (!showCard) return const SizedBox.shrink();
    final drawing = ref.watch(tracksProvider.select((s) => s.drawing));

    return Padding(
      // Vicino alla toolbar in basso (poco margine sotto).
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
      child: GlassSurface(
        // Card contenutistica: quasi opaca (leggibilità di testo/grafico) ma con
        // il linguaggio "vetro" iOS (bordo chiaro, ombra morbida, angoli ampi).
        opacity: 0.92,
        blur: 30,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: drawing ? const _DrawingBody() : const _SelectedBody(),
        ),
      ),
    );
  }
}

/// Vista di **creazione/modifica**: minimale. Nome, colore e le sole azioni
/// annulla · undo · salva.
class _DrawingBody extends ConsumerWidget {
  const _DrawingBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(tracksProvider.select((s) => s.editing));
    final pathLoading =
        track != null && ref.watch(livePathProvider(track.id)).isLoading;
    final canSave = (track?.waypoints.length ?? 0) >= 2;
    final snap = track?.snapToTrail ?? true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _NameField(),
        _ColorPicker(selected: track?.color),
        // Segui sentieri: OFF = linee dritte tra i punti (fuori sentiero,
        // ghiacciai, creste senza tracce OSM dove lo snap devierebbe).
        Row(
          children: [
            Icon(snap ? CupertinoIcons.arrow_turn_up_right : CupertinoIcons.minus,
                size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(snap ? 'Segui i sentieri' : 'Linee dritte',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            CupertinoSwitch(
              value: snap,
              onChanged: (v) => ref.read(tracksProvider.notifier).setSnap(v),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (pathLoading) ...[
              const CupertinoActivityIndicator(radius: 8),
              const SizedBox(width: 8),
              Text('Calcolo percorso…',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            const Spacer(),
            _CardIconButton(
              tooltip: 'Annulla e chiudi',
              onPressed: () => _confirmCancel(context, ref),
              icon: CupertinoIcons.xmark,
            ),
            _CardIconButton(
              tooltip: 'Annulla ultimo punto',
              onPressed: (track?.waypoints.isEmpty ?? true)
                  ? null
                  : () => ref.read(tracksProvider.notifier).undo(),
              icon: CupertinoIcons.arrow_uturn_left,
            ),
            const SizedBox(width: 8),
            _PillAction(
              label: 'Salva',
              icon: CupertinoIcons.check_mark,
              filled: true,
              onPressed: (!canSave || pathLoading)
                  ? null
                  : () => ref.read(tracksProvider.notifier).finishDrawing(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Vista **traccia selezionata**: dati memorizzati + profilo/ripidezza on-demand.
class _SelectedBody extends ConsumerWidget {
  const _SelectedBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(tracksProvider.select((s) => s.active));
    // Calcolo in corso proprio per la traccia mostrata → indicatore di attesa.
    final saving = ref.watch(
        tracksProvider.select((s) => s.saving && s.savingId == s.activeId));
    // Ricerca lazy di segnavia/difficoltà su una traccia vecchia appena aperta.
    final resolvingTrails = ref.watch(
        tracksProvider.select((s) => s.resolvingTrailsId == s.activeId));
    final distance = ref.watch(routeDistanceProvider);
    final metrics = track?.metrics;
    final hasMetrics = metrics != null;

    final profileVisible = ref.watch(profileVisibleProvider);
    final showingChart =
        profileVisible && hasMetrics && !metrics.profile.isEmpty;
    final steepnessOn = ref.watch(steepnessVisibleProvider);
    final cursor = ref.watch(profileCursorProvider);
    final difficulty =
        hasMetrics ? overallCaiScale(metrics.trailSegments) : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                (track?.name.isNotEmpty ?? false) ? track!.name : 'Senza nome',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            _CardIconButton(
              tooltip: 'Modifica',
              onPressed: saving
                  ? null
                  : () => ref.read(tracksProvider.notifier).editSelected(),
              icon: Icons.edit_rounded,
            ),
          ],
        ),
        if (saving)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              CupertinoActivityIndicator(radius: 9),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Calcolo percorso, dislivello e segnavia…',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          )
        else ...[
          const SizedBox(height: 2),
          Row(
            children: [
              _Metric(icon: Icons.straighten, value: Format.distance(distance)),
              if (hasMetrics) ...[
                const SizedBox(width: 14),
                Container(
                  width: 1,
                  height: 18,
                  color: Theme.of(context).dividerColor,
                ),
                const SizedBox(width: 14),
                _GainLoss(metrics: metrics),
              ],
            ],
          ),
          if (resolvingTrails)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Row(children: [
                CupertinoActivityIndicator(radius: 7),
                SizedBox(width: 8),
                Text('Ricerca segnavia CAI…', style: TextStyle(fontSize: 12)),
              ]),
            )
          else if ((track?.trailRefs.isNotEmpty ?? false) || difficulty != null)
            _TrailInfo(
                refs: track?.trailRefs ?? const [], scale: difficulty),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            _PillAction(
              label: 'Percorso',
              icon: showingChart
                  ? CupertinoIcons.chevron_up_chevron_down
                  : CupertinoIcons.chart_bar_alt_fill,
              onPressed: (!hasMetrics || saving)
                  ? null
                  : () => ref.read(profileVisibleProvider.notifier).toggle(),
            ),
            const SizedBox(width: 6),
            _CardIconButton(
              tooltip: 'Colori dislivelli',
              active: steepnessOn,
              onPressed: (!hasMetrics || saving)
                  ? null
                  : () => ref.read(steepnessVisibleProvider.notifier).toggle(),
              icon: CupertinoIcons.chart_bar_square,
            ),
            const Spacer(),
            _CardIconButton(
              tooltip: 'Salva offline',
              onPressed: saving || track == null
                  ? null
                  : () => downloadTrackOffline(context, ref, track),
              icon: CupertinoIcons.cloud_download,
            ),
          ],
        ),
        if (showingChart) ...[
          const SizedBox(height: 4),
          // Slot fisso per la quota al cursore (spazio riservato sempre, così la
          // card non cambia altezza scorrendo il grafico).
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
                    color: cursor == null ? Theme.of(context).hintColor : null,
                  ),
            ),
          ),
          ElevationProfileChart(
            profile: metrics.profile,
            trailSegments: metrics.trailSegments,
            cursor: cursor,
            steepness: steepnessOn,
            height: 120,
            onCursor: (s) => ref.read(profileCursorProvider.notifier).set(s),
          ),
        ],
      ],
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
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Annullare?'),
      content:
          const Text('Le modifiche non salvate al percorso andranno perse.'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Continua a modificare'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
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

/// Numeri dei sentieri (ref CAI) attraversati + grado di difficoltà complessivo.
class _TrailInfo extends StatelessWidget {
  const _TrailInfo({required this.refs, required this.scale});

  final List<String> refs;
  final String? scale;

  @override
  Widget build(BuildContext context) {
    final s = scale; // locale: promuovibile dopo il null-check
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (refs.isNotEmpty) const Icon(Icons.signpost_outlined, size: 16),
          for (final r in refs)
            Chip(
              label: Text(r),
              labelStyle: const TextStyle(fontSize: 12),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          if (s != null) _DifficultyChip(scale: s),
        ],
      ),
    );
  }
}

/// Chip colorato col grado di difficoltà CAI complessivo del percorso.
class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.scale});

  final String scale;

  @override
  Widget build(BuildContext context) {
    final color = caiScaleColor(scale);
    return Tooltip(
      message: 'Difficoltà CAI: ${caiScaleLabel(scale)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          scale,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
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

    final scheme = Theme.of(context).colorScheme;
    return CupertinoTextField(
      controller: _controller,
      textInputAction: TextInputAction.done,
      placeholder: 'Nome percorso',
      prefix: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Icon(CupertinoIcons.pencil,
            size: 18, color: scheme.onSurface.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
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

  final TrackMetrics metrics;

  @override
  Widget build(BuildContext context) {
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
        Text(Format.meters(metrics.elevation.gain), style: style),
        const SizedBox(width: 10),
        const Icon(Icons.trending_down, size: 18, color: down),
        const SizedBox(width: 3),
        Text(Format.meters(metrics.elevation.loss), style: style),
      ],
    );
  }
}

/// Bottone-icona compatto stile iOS per la card (press-dim, niente ripple).
/// `active` = stato acceso (pastiglia tinta), `onPressed` null = disabilitato.
class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final color = !enabled
        ? scheme.onSurface.withValues(alpha: 0.28)
        : active
            ? scheme.primary
            : scheme.onSurface.withValues(alpha: 0.75);
    Widget button = CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(40, 40),
      onPressed: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: active
            ? BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle)
            : null,
        child: Icon(icon, size: 22, color: color),
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return button;
  }
}

/// Pillola d'azione stile iOS. `filled` = tinta primaria piena (azione
/// primaria); altrimenti tinta leggera (azione secondaria).
class _PillAction extends StatelessWidget {
  const _PillAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final bg = filled
        ? scheme.primary.withValues(alpha: enabled ? 1 : 0.4)
        : scheme.primary.withValues(alpha: enabled ? 0.14 : 0.06);
    final fg = filled
        ? const Color(0xFFFFFFFF)
        : scheme.primary.withValues(alpha: enabled ? 1 : 0.4);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: bg,
      borderRadius: BorderRadius.circular(22),
      minimumSize: const Size(0, 0),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
