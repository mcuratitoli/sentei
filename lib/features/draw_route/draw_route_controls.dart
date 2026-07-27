import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoButton,
        CupertinoIcons,
        CupertinoSwitch,
        CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/util/format.dart';
import '../../domain/services/track_metrics.dart';
import '../../ui/cai_difficulty.dart';
import '../../ui/elevation_profile_chart.dart';
import '../../ui/glass.dart';
import '../../ui/ios_menu.dart';
import '../../ui/tokens.dart';
import '../offline_maps/track_offline_download.dart';
import 'nearby_photos_action.dart';
import 'route_editor_provider.dart';

/// Pannello inferiore di controllo della traccia attiva.
///
/// - **Creazione/modifica**: nome, distanza live, impostazioni avanzate
///   (colore/segui sentieri, in un foglio dedicato) e annulla/undo/salva
///   (niente D+/D-: richiederebbero il calcolo completo delle quote ad ogni
///   spostamento di un punto, si calcolano solo al salvataggio).
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
        borderRadius: AppRadii.rCard,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: drawing ? const _DrawingBody() : const _SelectedBody(),
        ),
      ),
    );
  }
}

/// Vista di **creazione/modifica**: nome, distanza live, impostazioni
/// avanzate (colore/segui sentieri) e le azioni annulla · undo · salva.
class _DrawingBody extends ConsumerWidget {
  const _DrawingBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(tracksProvider.select((s) => s.editing));
    final pathLoading =
        track != null && ref.watch(livePathProvider(track.id)).isLoading;
    final canSave = (track?.waypoints.length ?? 0) >= 2;
    final canUndo = ref.watch(tracksProvider.select((s) => s.canUndo));
    final snap = track?.snapToTrail ?? true;
    final selectedWp = ref.watch(selectedWaypointProvider);
    final wpCount = track?.waypoints.length ?? 0;
    // Solo la distanza (haversine sul percorso live, nessuna rete): D+/D-
    // richiedono il calcolo completo delle metriche (quote via Terrarium),
    // troppo costoso da rifare ad ogni spostamento di un punto — restano
    // disponibili solo dopo il Salva, come per le tracce importate.
    final distance = ref.watch(routeDistanceProvider);

    final selectingPoint = selectedWp != null && selectedWp < wpCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Un punto selezionato **sostituisce** nome/distanza/impostazioni: a
        // quel punto si sta modificando il punto, non il resto della traccia
        // (che comunque non cambia sotto — il "Salva" resta in fondo).
        if (!selectingPoint) ...[
          const _NameField(),
          if (wpCount >= 2) ...[
            const SizedBox(height: 6),
            _Metric(icon: Icons.straighten, value: Format.distance(distance)),
          ],
          const SizedBox(height: 4),
          _AdvancedSettingsRow(track: track, snap: snap),
        ] else ...[
          _SelectedWaypointBar(
            index: selectedWp,
            total: wpCount,
            point: track!.waypoints[selectedWp],
            onDelete: () => _confirmDeleteWaypoint(context, ref, selectedWp),
            onInsertBefore: selectedWp == 0
                ? null
                : () {
                    ref.read(tracksProvider.notifier).insertPointBefore(selectedWp);
                    // Il nuovo punto prende il posto di quello selezionato:
                    // segue la selezione sul punto originale (slittato di uno).
                    ref.read(selectedWaypointProvider.notifier).set(selectedWp + 1);
                  },
            onClose: () => ref.read(selectedWaypointProvider.notifier).clear(),
          ),
        ],
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
              tooltip: 'Annulla',
              onPressed: canUndo
                  ? () => ref.read(tracksProvider.notifier).undo()
                  : null,
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
            // Chiudi la card (deseleziona) — stessa X della mini-card punto.
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 40),
              onPressed: () => ref.read(tracksProvider.notifier).deselect(),
              child: Icon(CupertinoIcons.clear_circled_solid,
                  size: 24, color: context.palette.tertiaryIcon),
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
                  style: AppText.caption,
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
                Text('Ricerca segnavia CAI…', style: AppText.captionSmall),
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
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
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
              icon: CupertinoIcons.graph_square,
            ),
            const Spacer(),
            _CardIconButton(
              tooltip: 'Trova foto vicine',
              onPressed: (!hasMetrics || saving || track == null)
                  ? null
                  : () => findNearbyPhotos(context, ref, track),
              icon: CupertinoIcons.photo,
            ),
            _CardIconButton(
              tooltip: 'Modifica',
              onPressed: saving
                  ? null
                  : () => ref.read(tracksProvider.notifier).editSelected(),
              icon: Icons.edit_rounded,
            ),
            _CardIconButton(
              tooltip: 'Salva offline',
              onPressed: saving || track == null
                  ? null
                  : () => downloadTrackOffline(context, ref, track),
              icon: CupertinoIcons.cloud_download,
            ),
          ],
        ),
        if (!saving && track != null && track.photos.isNotEmpty)
          _PhotoStrip(track: track),
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
            photos: track?.photos ?? const [],
            onPhotoTap: (p) => ref.read(selectedPhotoProvider.notifier).set(p),
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
  await showIosConfirm(
    context: context,
    title: 'Annullare?',
    message: 'Le modifiche non salvate al percorso andranno perse.',
    confirmLabel: 'Annulla modifiche',
    cancelLabel: 'Continua a modificare',
    onConfirm: () => ref.read(tracksProvider.notifier).cancelEditing(),
  );
}

/// Conferma l'eliminazione del waypoint [index] (stile Apple: azione rossa).
Future<void> _confirmDeleteWaypoint(
    BuildContext context, WidgetRef ref, int index) async {
  await showIosConfirm(
    context: context,
    title: 'Eliminare il punto?',
    message: 'Il punto ${index + 1} verrà rimosso dal percorso.',
    confirmLabel: 'Elimina',
    onConfirm: () => ref.read(tracksProvider.notifier).removePoint(index),
  );
}

/// Vista **dedicata al punto selezionato**: sostituisce nome/distanza/
/// impostazioni avanzate (si sta modificando il punto, non il resto della
/// traccia). Mostra quale punto, la sua **quota** (stessa fonte del punto
/// ispezionato in esplorazione), un suggerimento per lo spostamento e le
/// azioni **Aggiungi punto prima** (assente sul primo punto, che non ha un
/// precedente) ed **Elimina** (con conferma) — pillole chiare con icona,
/// stesso linguaggio del resto della card (`_PillAction`), non più testo puro.
class _SelectedWaypointBar extends ConsumerWidget {
  const _SelectedWaypointBar({
    required this.index,
    required this.total,
    required this.point,
    required this.onDelete,
    required this.onInsertBefore,
    required this.onClose,
  });

  final int index;
  final int total;
  final LatLng point;
  final VoidCallback onDelete;
  final VoidCallback? onInsertBefore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final elevation = ref.watch(waypointElevationProvider(point));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 40),
              onPressed: onClose,
              child: Icon(CupertinoIcons.clear_circled_solid,
                  size: 24, color: palette.tertiaryIcon),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text('Punto ${index + 1} di $total',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            elevation.when(
              data: (m) => Text(
                m != null ? Format.meters(m) : 'quota non disponibile',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: m != null ? palette.accent : palette.tertiaryIcon),
              ),
              loading: () => const CupertinoActivityIndicator(radius: 8),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 44),
          child: Text('Tieni premuto per spostare', style: AppText.captionSmall.copyWith(color: palette.tertiaryIcon)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (onInsertBefore != null) ...[
              _PillAction(
                label: 'Aggiungi punto prima',
                icon: CupertinoIcons.add,
                onPressed: onInsertBefore,
              ),
              const SizedBox(width: 8),
            ],
            _PillAction(
              label: 'Elimina',
              icon: CupertinoIcons.delete,
              color: AppColors.destructive,
              onPressed: onDelete,
            ),
          ],
        ),
      ],
    );
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
              labelStyle: AppText.captionSmall,
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

/// Striscia orizzontale delle foto collegate alla traccia (§"Sync album
/// fotografico"): miniatura + rimozione con conferma. Sola lettura/gestione
/// dei collegamenti — l'apertura dell'originale (re-match locale) è un passo
/// successivo, non ancora implementato.
class _PhotoStrip extends ConsumerWidget {
  const _PhotoStrip({required this.track});

  final DrawnTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: track.photos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final photo = track.photos[i];
            return GestureDetector(
              onTap: () => _confirmRemovePhoto(context, ref, track.id, photo.id),
              child: ClipRRect(
                borderRadius: AppRadii.rMd,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: photo.thumbnail != null
                      ? Image.memory(photo.thumbnail!, fit: BoxFit.cover)
                      : ColoredBox(
                          color: context.palette.hairline.withValues(alpha: 0.08),
                          child: Icon(CupertinoIcons.photo,
                              color: context.palette.tertiaryIcon),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<void> _confirmRemovePhoto(
    BuildContext context, WidgetRef ref, String trackId, String photoId) async {
  await showIosConfirm(
    context: context,
    title: 'Scollegare la foto?',
    message: 'La foto resta nella tua libreria: viene solo scollegata dalla traccia.',
    confirmLabel: 'Scollega',
    onConfirm: () => ref.read(tracksProvider.notifier).removePhoto(trackId, photoId),
  );
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
          borderRadius: AppRadii.rMd,
        ),
        child: Text(
          scale,
          style: AppText.badge.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

/// Riga collassata: **colore** e **segui i sentieri** vivono in un foglio
/// separato (aperto al tocco) invece di occupare sempre spazio nella card.
class _AdvancedSettingsRow extends StatelessWidget {
  const _AdvancedSettingsRow({required this.track, required this.snap});

  final DrawnTrack? track;
  final bool snap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CupertinoButton(
      key: const Key('advancedSettingsRow'),
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 0),
      onPressed: () => _showAdvancedSettingsSheet(context, track?.color, snap),
      child: Row(
        children: [
          Icon(CupertinoIcons.slider_horizontal_3, size: 18, color: palette.secondaryLabel),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Impostazioni avanzate',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: palette.secondaryLabel)),
          ),
          Icon(CupertinoIcons.chevron_right, size: 16, color: palette.tertiaryIcon),
        ],
      ),
    );
  }
}

/// Foglio con **colore** della traccia e **segui i sentieri**, spostati fuori
/// dalla card principale (troppo spazio per due impostazioni secondarie).
Future<void> _showAdvancedSettingsSheet(
    BuildContext context, Color? selected, bool snap) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.palette.glassFill,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: (_) => _AdvancedSettingsSheet(selected: selected, snap: snap),
  );
}

class _AdvancedSettingsSheet extends ConsumerWidget {
  const _AdvancedSettingsSheet({required this.selected, required this.snap});

  final Color? selected;
  final bool snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final selected = ref.watch(tracksProvider.select((s) => s.editing?.color)) ??
        this.selected ??
        kTrackPalette.first;
    final snap =
        ref.watch(tracksProvider.select((s) => s.editing?.snapToTrail)) ?? this.snap;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Impostazioni avanzate', style: AppText.sheetTitle),
            const SizedBox(height: 16),
            Text('Colore',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: palette.secondaryLabel)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final c in kTrackPalette)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => ref.read(tracksProvider.notifier).setColor(c),
                      child: _ColorSwatch(
                        color: c,
                        ringColor: c == selected ? scheme.onSurface : scheme.outline,
                        ringWidth: c == selected ? 2.5 : 1,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
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
          ],
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch(
      {required this.color, required this.ringColor, this.ringWidth = 1});

  final Color color;
  final Color ringColor;
  final double ringWidth;

  @override
  Widget build(BuildContext context) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: ringColor, width: ringWidth),
        ),
      );
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
        borderRadius: AppRadii.rMd,
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
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  /// Tinta della pillola, `scheme.primary` se non specificata — es.
  /// `AppColors.destructive` per un'azione distruttiva (es. "Elimina") con lo
  /// stesso linguaggio "chiaro + icona" delle altre azioni, non testo puro.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    final enabled = onPressed != null;
    final bg = filled
        ? tint.withValues(alpha: enabled ? 1 : 0.4)
        : tint.withValues(alpha: enabled ? 0.14 : 0.06);
    final fg = filled
        ? const Color(0xFFFFFFFF)
        : tint.withValues(alpha: enabled ? 1 : 0.4);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: bg,
      borderRadius: AppRadii.rPill,
      minimumSize: const Size(0, 0),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 6),
          Text(label, style: AppText.pillLabel.copyWith(color: fg)),
        ],
      ),
    );
  }
}
