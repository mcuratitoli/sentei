import 'dart:io' show File;

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
import 'package:photo_manager/photo_manager.dart' show AssetEntity;

import '../../core/util/format.dart';
import '../../domain/models/track_photo.dart';
import '../../domain/services/track_metrics.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/app_buttons.dart';
import '../../ui/badges.dart';
import '../../ui/cai_difficulty.dart';
import '../../ui/elevation_profile_chart.dart';
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
      // Superficie **opaca** (`new design/DESIGN_GUIDELINES.md` §7), non più
      // "vetro": card di contenuto, non chrome di navigazione — leggibilità
      // di testo/grafico prima di tutto. La chrome (menubar/ricerca/punto
      // ispezionato in esplorazione) non è coperta da questo redesign e
      // resta col vecchio linguaggio `GlassSurface`.
      child: AppSheetSurface(
        // Fluttua sopra la mappa con un margine sotto (non è a filo del
        // bordo schermo): arrotondata su tutti i lati, non solo sopra.
        floating: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                    ref
                        .read(tracksProvider.notifier)
                        .insertPointBefore(selectedWp);
                    // Il nuovo punto prende il posto di quello selezionato:
                    // segue la selezione sul punto originale (slittato di uno).
                    ref
                        .read(selectedWaypointProvider.notifier)
                        .set(selectedWp + 1);
                  },
            onClose: () => ref.read(selectedWaypointProvider.notifier).clear(),
          ),
        ],
        // Annulla/Undo/Salva riguardano la traccia nel suo complesso: non
        // hanno senso mentre si sta guardando/spostando un singolo punto (la
        // X in alto in quella vista chiude già, tornando qui).
        if (!selectingPoint) ...[
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
              AppIconButton(
                tooltip: 'Annulla e chiudi',
                onPressed: () => _confirmCancel(context, ref),
                icon: CupertinoIcons.xmark,
              ),
              const SizedBox(width: 6),
              AppIconButton(
                tooltip: 'Annulla',
                onPressed: canUndo
                    ? () => ref.read(tracksProvider.notifier).undo()
                    : null,
                icon: CupertinoIcons.arrow_uturn_left,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Salva',
                  icon: CupertinoIcons.check_mark,
                  variant: AppButtonVariant.primary,
                  onPressed: (!canSave || pathLoading)
                      ? null
                      : () => ref.read(tracksProvider.notifier).finishDrawing(),
                ),
              ),
            ],
          ),
        ],
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
    final resolvingTrails = ref
        .watch(tracksProvider.select((s) => s.resolvingTrailsId == s.activeId));
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
    // Foto da evidenziare (bordo/pin giallo, sia sulla thumbnail nella
    // striscia sia sul pin nel grafico): quella **selezionata** (tap su
    // thumbnail/pin, `PhotoDetailCard` aperta) ha priorità; altrimenti quella
    // la cui distanza-lungo-percorso è più vicina al cursore corrente durante
    // lo scrubbing. Se fuori vista, la striscia scorre per mostrarla.
    final selectedPhoto = ref.watch(selectedPhotoProvider);
    String? highlightedPhotoId;
    if (track != null &&
        selectedPhoto != null &&
        track.photos.any((p) => p.id == selectedPhoto.id)) {
      highlightedPhotoId = selectedPhoto.id;
    } else if (cursor != null && track != null && track.photos.isNotEmpty) {
      TrackPhoto? nearest;
      var best = double.infinity;
      for (final p in track.photos) {
        final d = (p.distanceMeters - cursor.distanceMeters).abs();
        if (d < best) {
          best = d;
          nearest = p;
        }
      }
      if (nearest != null && best <= _photoHighlightToleranceMeters) {
        highlightedPhotoId = nearest.id;
      }
    }

    final expanded = ref.watch(trackCardExpandedProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSheetHeader(
          title: (track?.name.isNotEmpty ?? false) ? track!.name : 'Senza nome',
          // Riduci/espandi: il pannello "dettaglio tracciato" ha il chevron
          // prima della × (§7 delle linee guida).
          collapseIcon: expanded
              ? CupertinoIcons.chevron_down
              : CupertinoIcons.chevron_up,
          collapseTooltip: expanded ? 'Riduci' : 'Espandi',
          onCollapseToggle: () =>
              ref.read(trackCardExpandedProvider.notifier).toggle(),
          onClose: () => ref.read(tracksProvider.notifier).deselect(),
        ),
        if (expanded) ...[
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
                _Metric(
                    icon: Icons.straighten, value: Format.distance(distance)),
                if (hasMetrics) ...[
                  const SizedBox(width: 14),
                  Container(
                    width: 1,
                    height: 18,
                    color: context.palette.borderDivider,
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
            else if ((track?.trailRefs.isNotEmpty ?? false) ||
                difficulty != null)
              _TrailInfo(refs: track?.trailRefs ?? const [], scale: difficulty),
          ],
          const SizedBox(height: 8),
          // Riga con 4-5 azioni: icone nude, senza testo/sfondo (a differenza
          // delle pillole con label usate dove la riga ha solo 1-2 azioni —
          // barra del punto selezionato, card foto, foglio foto vicine —
          // altrimenti qui andrebbe fuori schermo o su due righe). "Percorso"
          // era l'unica pillola con label in questa riga, incoerente con le
          // altre 4: ora è un'icona con stato attivo/disattivo come "Colori
          // dislivelli" accanto.
          Row(
            children: [
              AppIconButton(
                tooltip: 'Profilo altimetrico',
                active: showingChart,
                onPressed: (!hasMetrics || saving)
                    ? null
                    : () => ref.read(profileVisibleProvider.notifier).toggle(),
                // Grafico a linee (non più `waveform_path`, che leggeva
                // troppo come forma d'onda audio).
                icon: CupertinoIcons.graph_square,
              ),
              const SizedBox(width: 6),
              AppIconButton(
                tooltip: 'Colori dislivelli',
                active: steepnessOn,
                onPressed: (!hasMetrics || saving)
                    ? null
                    : () =>
                        ref.read(steepnessVisibleProvider.notifier).toggle(),
                // Fiamma: intensità/difficoltà della pendenza, non un
                // pennello (colore in sé non è il concetto — la ripidità sì).
                icon: CupertinoIcons.flame,
              ),
              const Spacer(),
              AppIconButton(
                tooltip: 'Trova foto vicine',
                onPressed: (!hasMetrics || saving || track == null)
                    ? null
                    : () => findNearbyPhotos(context, ref, track),
                icon: CupertinoIcons.photo,
              ),
              const SizedBox(width: 6),
              AppIconButton(
                tooltip: 'Modifica',
                onPressed: saving
                    ? null
                    : () => ref.read(tracksProvider.notifier).editSelected(),
                icon: CupertinoIcons.pencil,
              ),
              const SizedBox(width: 6),
              AppIconButton(
                tooltip: 'Salva offline',
                onPressed: saving || track == null
                    ? null
                    : () => downloadTrackOffline(context, ref, track),
                icon: CupertinoIcons.cloud_download,
              ),
            ],
          ),
          if (!saving && track != null && track.photos.isNotEmpty)
            _PhotoStrip(track: track, highlightedPhotoId: highlightedPhotoId),
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
                      color:
                          cursor == null ? Theme.of(context).hintColor : null,
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
              onPhotoTap: (p) =>
                  ref.read(selectedPhotoProvider.notifier).set(p),
              highlightedPhotoId: highlightedPhotoId,
            ),
          ],
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
        AppSheetHeader(
          title: 'Punto ${index + 1} di $total',
          onClose: onClose,
          trailing: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: elevation.when(
              data: (m) => Text(
                m != null ? Format.meters(m) : 'quota non disponibile',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: m != null ? palette.accent : palette.tertiaryIcon),
              ),
              loading: () => const CupertinoActivityIndicator(radius: 8),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('Tieni premuto per spostare',
              style:
                  AppText.captionSmall.copyWith(color: palette.tertiaryIcon)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (onInsertBefore != null) ...[
              Expanded(
                child: AppButton(
                  label: 'Aggiungi punto prima',
                  icon: CupertinoIcons.add,
                  variant: AppButtonVariant.secondary,
                  onPressed: onInsertBefore,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: AppButton(
                label: 'Elimina',
                icon: CupertinoIcons.delete,
                variant: AppButtonVariant.destructive,
                onPressed: onDelete,
              ),
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
          for (final r in refs) AppTrailTag(label: r),
          if (s != null) AppDifficultyBadge(scale: s),
        ],
      ),
    );
  }
}

/// Striscia orizzontale delle foto collegate alla traccia (§"Sync album
/// fotografico"): miniatura + rimozione con conferma. Sola lettura/gestione
/// dei collegamenti — l'apertura dell'originale (re-match locale) è un passo
/// successivo, non ancora implementato.
/// Tolleranza (metri lungo il percorso) per evidenziare la thumbnail di una
/// foto mentre si scorre il grafico del profilo con il dito — generosa
/// apposta: durante lo scrubbing è più importante "agganciare" facilmente la
/// foto vicina che essere millimetrici.
const double _photoHighlightToleranceMeters = 50;

/// Dimensione delle thumbnail nella striscia: più piccole di prima (56px),
/// ma non sotto il target di tocco minimo (44pt) dato che restano tappabili.
const double _photoThumbSize = 44;

/// Colore dell'evidenziazione (foto selezionata o sotto il cursore): stesso
/// giallo del pin sul grafico, non l'accento blu del resto dell'app — qui
/// significa "questo è il punto/la foto sotto il dito", non "selezionato"
/// nel senso di editing.
const Color _photoHighlightColor = Color(0xFFFFD600);

class _PhotoStrip extends ConsumerStatefulWidget {
  const _PhotoStrip({required this.track, this.highlightedPhotoId});

  final DrawnTrack track;

  /// Foto il cui pin sul grafico è sotto il dito durante lo scrubbing: la sua
  /// thumbnail si evidenzia e, se fuori vista, la striscia scorre per mostrarla.
  final String? highlightedPhotoId;

  @override
  ConsumerState<_PhotoStrip> createState() => _PhotoStripState();
}

class _PhotoStripState extends ConsumerState<_PhotoStrip> {
  final Map<String, GlobalKey> _keys = {};

  GlobalKey _keyFor(String photoId) =>
      _keys.putIfAbsent(photoId, () => GlobalKey());

  @override
  void didUpdateWidget(covariant _PhotoStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.highlightedPhotoId;
    if (id != null && id != oldWidget.highlightedPhotoId) {
      // Post-frame: la thumbnail deve già essere nell'albero (con la sua
      // GlobalKey) prima di poterla far scorrere in vista.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[id]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: 0.5);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // In ordine lungo il percorso (distanza-lungo-percorso crescente), non
    // nell'ordine di collegamento/importazione — più intuitivo scorrendola
    // insieme al grafico del profilo.
    final photos = [...widget.track.photos]
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: _photoThumbSize,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final photo = photos[i];
            final highlighted = photo.id == widget.highlightedPhotoId;
            return GestureDetector(
              key: _keyFor(photo.id),
              onTap: () => ref.read(selectedPhotoProvider.notifier).set(photo),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _photoThumbSize,
                height: _photoThumbSize,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.rMd,
                  border: Border.all(
                    color:
                        highlighted ? _photoHighlightColor : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: AppRadii.rMd,
                  child: photo.thumbnail != null
                      ? Image.memory(photo.thumbnail!, fit: BoxFit.cover)
                      : ColoredBox(
                          color: palette.hairline.withValues(alpha: 0.08),
                          child: Icon(CupertinoIcons.photo,
                              color: palette.tertiaryIcon),
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
    message:
        'La foto resta nella tua libreria: viene solo scollegata dalla traccia.',
    confirmLabel: 'Scollega',
    onConfirm: () {
      ref.read(tracksProvider.notifier).removePhoto(trackId, photoId);
      // La foto potrebbe essere anche quella aperta in PhotoDetailCard.
      ref.read(selectedPhotoProvider.notifier).clear();
    },
  );
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: palette.hairline.withValues(alpha: 0.1),
          borderRadius: AppRadii.rMd,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text('Impostazioni avanzate',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: palette.label)),
            ),
            Icon(CupertinoIcons.chevron_right,
                size: 16, color: palette.tertiaryIcon),
          ],
        ),
      ),
    );
  }
}

/// Foglio con **colore** della traccia e **segui i sentieri**, spostati fuori
/// dalla card principale (troppo spazio per due impostazioni secondarie).
Future<void> _showAdvancedSettingsSheet(
    BuildContext context, Color? selected, bool snap) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => _AdvancedSettingsSheet(selected: selected, snap: snap),
  );
}

class _AdvancedSettingsSheet extends ConsumerWidget {
  const _AdvancedSettingsSheet({required this.selected, required this.snap});

  final Color? selected;
  final bool snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final selected =
        ref.watch(tracksProvider.select((s) => s.editing?.color)) ??
            this.selected ??
            kTrackPalette.first;
    final snap =
        ref.watch(tracksProvider.select((s) => s.editing?.snapToTrail)) ??
            this.snap;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSheetHeader(
          title: 'Impostazioni avanzate',
          onClose: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 16),
        Text('COLORE',
            style: AppText.caption.copyWith(
                color: palette.secondaryLabel,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4)),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final c in kTrackPalette)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => ref.read(tracksProvider.notifier).setColor(c),
                  child: _ColorSwatch(color: c, selected: c == selected),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(color: palette.borderDivider, height: 25),
        Row(
          children: [
            Expanded(
              child: Text(snap ? 'Segui i sentieri' : 'Linee dritte',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            // Stato ON = blu di brand, non il verde di sistema di default:
            // un solo colore per gli stati "attivo" in tutta l'app (`new
            // design/DESIGN_GUIDELINES.md` §8).
            CupertinoSwitch(
              value: snap,
              activeTrackColor: palette.accent,
              onChanged: (v) => ref.read(tracksProvider.notifier).setSnap(v),
            ),
          ],
        ),
      ],
    );
  }
}

/// Pallino colore tracciato (`new design/DESIGN_GUIDELINES.md` §6): il
/// **selezionato** ha un anello d'accento e una spunta bianca sopra la
/// tinta; gli altri sono cerchi pieni senza contorno — non più "tutti con un
/// anello, quello attivo più spesso", che rendeva ambigua la selezione.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.palette.accent, width: 2),
      ),
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const Icon(CupertinoIcons.checkmark,
            size: 14, color: Color(0xFFFFFFFF)),
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
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(tracksProvider).active?.name ?? '');

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

    final palette = context.palette;
    return CupertinoTextField(
      controller: _controller,
      textInputAction: TextInputAction.done,
      placeholder: 'Nome percorso',
      prefix: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Icon(CupertinoIcons.pencil, size: 18, color: palette.iconGreyLight),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      // Stesso riempimento del campo titolo foto (`_promptEditPhotoTitle`):
      // era `scheme.onSurface.withValues(alpha: 0.06)`, un grigio leggermente
      // diverso da `palette.hairline` usato nell'altro campo di testo.
      decoration: BoxDecoration(
        color: palette.hairline.withValues(alpha: 0.1),
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
    // Icona/testo in grigio scuro neutro, non l'accento blu: nei mockup del
    // redesign il blu è riservato ad azioni/stati attivi, non a dati (vedi
    // `new design/DESIGN_GUIDELINES.md` §2 — "il blu è l'unico colore di
    // brand/azione").
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: context.palette.secondaryLabel),
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
    // Stessi colori della scala di difficoltà CAI (T verde = dislivello
    // positivo, EEA rosso = negativo): un solo significato per tinta in
    // tutta l'app, non un verde/rosso indipendente.
    const up = AppDifficultyColors.t;
    const down = AppDifficultyColors.eea;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(CupertinoIcons.arrow_up_right, size: 18, color: up),
        const SizedBox(width: 3),
        Text(Format.meters(metrics.elevation.gain), style: style),
        const SizedBox(width: 10),
        const Icon(CupertinoIcons.arrow_down_right, size: 18, color: down),
        const SizedBox(width: 3),
        Text(Format.meters(metrics.elevation.loss), style: style),
      ],
    );
  }
}

/// Card **unificata** per i dettagli di una foto collegata: stessa vista sia
/// toccando una thumbnail nella striscia della card traccia sia un pin foto
/// in mappa (entrambi passano da `selectedPhotoProvider`, mostrata sopra
/// `DrawRouteControls` in `map_gl_screen.dart`). Mostra thumbnail (tap → foto
/// a schermo intero se ancora reperibile sul device), titolo (o data/ora come
/// default), coordinate + quota del punto di scatto, data/ora, e le azioni
/// **Modifica titolo**/**Scollega**.
class PhotoDetailCard extends ConsumerWidget {
  const PhotoDetailCard(
      {super.key, required this.photo, required this.onClose});

  final TrackPhoto photo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final trackId = ref.watch(tracksProvider.select((s) => s.active?.id));
    // Rilegge sempre la versione corrente (il titolo può essere stato
    // modificato) invece di fidarsi dello snapshot catturato alla selezione.
    final photos =
        ref.watch(tracksProvider.select((s) => s.active?.photos)) ?? const [];
    var current = photo;
    for (final p in photos) {
      if (p.id == photo.id) {
        current = p;
        break;
      }
    }
    final elevation = ref.watch(waypointElevationProvider(current.position));
    final hasTitle = current.title != null && current.title!.isNotEmpty;
    final title = hasTitle
        ? current.title!
        : (current.takenAt != null
            ? Format.dateTime(current.takenAt!)
            : 'Foto collegata');

    // Riga data/ora **aggiuntiva** solo se esiste un titolo personalizzato:
    // altrimenti `title` è già la data formattata (fallback) e mostrarla di
    // nuovo sotto sarebbe una duplicazione.
    final showExtraDateRow = hasTitle && current.takenAt != null;

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 16),
      child: AppSheetSurface(
        floating: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSheetHeader(title: 'Dettaglio foto', onClose: onClose),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => openFullPhoto(context, current.id),
                    child: ClipRRect(
                      borderRadius: AppRadii.rMd,
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: current.thumbnail != null
                            ? Image.memory(current.thumbnail!,
                                fit: BoxFit.cover)
                            : ColoredBox(
                                color: palette.hairline.withValues(alpha: 0.08),
                                child: Icon(CupertinoIcons.photo,
                                    color: palette.tertiaryIcon),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 3 righe: titolo (o data, se non impostato); quota
                        // (solo i metri) + coordinate; data e ora (solo se il
                        // titolo è personalizzato, altrimenti è già la riga 1).
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.value.copyWith(
                                color: palette.label,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            elevation.when(
                              data: (m) => m == null
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Text(Format.meters(m),
                                          style: AppText.captionSmall.copyWith(
                                              color: palette.secondaryLabel)),
                                    ),
                              loading: () => const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: SizedBox(
                                    height: 10,
                                    width: 10,
                                    child:
                                        CupertinoActivityIndicator(radius: 5)),
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                            Flexible(
                              child: Text(
                                Format.coordinates(current.position.latitude,
                                    current.position.longitude),
                                overflow: TextOverflow.ellipsis,
                                style: AppText.captionSmall
                                    .copyWith(color: palette.secondaryLabel),
                              ),
                            ),
                          ],
                        ),
                        if (showExtraDateRow)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(Format.dateTime(current.takenAt!),
                                style: AppText.captionSmall
                                    .copyWith(color: palette.secondaryLabel)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Modifica titolo',
                      icon: CupertinoIcons.pencil,
                      variant: AppButtonVariant.secondary,
                      onPressed: trackId == null
                          ? null
                          : () => _promptEditPhotoTitle(
                              context, ref, trackId, current),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: 'Scollega',
                      icon: CupertinoIcons.delete,
                      variant: AppButtonVariant.destructive,
                      onPressed: trackId == null
                          ? null
                          : () => _confirmRemovePhoto(
                              context, ref, trackId, current.id),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog per rinominare una foto: campo di testo precompilato col titolo
/// corrente (vuoto se non impostato — l'interfaccia mostra la data/ora come
/// default, non un valore forzato nei dati).
Future<void> _promptEditPhotoTitle(BuildContext context, WidgetRef ref,
    String trackId, TrackPhoto photo) async {
  final controller = TextEditingController(text: photo.title ?? '');
  // Bottom sheet, non più dialog centrato (`new design/DESIGN_GUIDELINES.md`
  // §7/§10: "Modifica titolo" era l'esempio esplicito da convertire).
  final result = await showAppBottomSheet<bool>(
    context: context,
    builder: (sheetContext) {
      final palette = sheetContext.palette;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSheetHeader(
            title: 'Modifica titolo',
            onClose: () => Navigator.of(sheetContext).pop(false),
          ),
          const SizedBox(height: 14),
          CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: 'Titolo della foto',
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => Navigator.of(sheetContext).pop(true),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: palette.hairline.withValues(alpha: 0.1),
              borderRadius: AppRadii.rMd,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              AppButton(
                label: 'Annulla',
                variant: AppButtonVariant.tertiary,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Salva',
                  variant: AppButtonVariant.primary,
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  if (result == true) {
    await ref
        .read(tracksProvider.notifier)
        .updatePhotoTitle(trackId, photo.id, controller.text.trim());
  }
  controller.dispose();
}

/// Apre la foto **a schermo intero** riaprendo l'asset dalla libreria del
/// dispositivo tramite [photoId] (`TrackPhoto.id`, l'id `photo_manager` di
/// **questo** device). Se l'asset non risolve (es. la traccia è stata
/// sincronizzata da un altro dispositivo, dove quell'id non esiste) non fa
/// nulla — nessun errore, nessun re-match per posizione/orario (non richiesto
/// qui): l'originale resta comunque sempre reperibile a mano nella libreria.
Future<void> openFullPhoto(BuildContext context, String photoId) async {
  AssetEntity? asset;
  try {
    asset = await AssetEntity.fromId(photoId);
  } catch (_) {
    asset = null;
  }
  if (asset == null || !context.mounted) return;
  final file = await asset.file;
  if (file == null || !context.mounted) return;
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: const Color(0xFF000000),
      pageBuilder: (_, __, ___) => _FullPhotoView(file: file),
    ),
  );
}

class _FullPhotoView extends StatelessWidget {
  const _FullPhotoView({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF000000),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(child: Image.file(file)),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Color(0x66000000), shape: BoxShape.circle),
                  child: const Icon(CupertinoIcons.xmark,
                      color: Color(0xFFFFFFFF), size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
