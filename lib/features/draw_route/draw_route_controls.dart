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
import '../../domain/models/photo_session.dart';
import '../../domain/models/track_photo.dart';
import '../../domain/services/photo_session_grouper.dart';
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

    // Superficie **opaca** (`new design/DESIGN_GUIDELINES.md` §7), non più
    // "vetro": card di contenuto, non chrome di navigazione — leggibilità di
    // testo/grafico prima di tutto. La chrome (menubar/ricerca/punto
    // ispezionato in esplorazione) non è coperta da questo redesign e resta
    // col vecchio linguaggio `GlassSurface`.
    //
    // Ancorata al bordo inferiore, a tutta larghezza (angoli arrotondati solo
    // sopra), come i fogli modali (legenda/changelog/tema): non più
    // "fluttuante" con margine su tutti i lati — `map_gl_screen.dart` toglie
    // il padding di sicurezza inferiore quando questa card è visibile, e
    // `SafeArea(top: false)` qui sotto lo riapplica solo al contenuto.
    return AppSheetSurface(
      floating: false,
      child: SafeArea(
        top: false,
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
    // Foto da evidenziare col pin giallo sul grafico: quella **selezionata**
    // (tap su una thumbnail/pin, `PhotoDetailCard` aperta) ha priorità;
    // altrimenti quella la cui distanza-lungo-percorso è più vicina al
    // cursore corrente durante lo scrubbing.
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
          if (!saving && track != null)
            _PhotoSection(track: track, enabled: hasMetrics),
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

/// Tolleranza (metri lungo il percorso) per evidenziare col pin giallo sul
/// grafico del profilo la foto sotto il dito durante lo scrubbing —
/// generosa apposta: durante lo scrubbing è più importante "agganciare"
/// facilmente la foto vicina che essere millimetrici.
const double _photoHighlightToleranceMeters = 50;

/// Sezione "FOTO" della card traccia (§"Sync album fotografico"): elenco
/// delle foto collegate raggruppate per escursione ([PhotoSessionGrouper]),
/// collassata di default. Il pulsante "+" avvia sempre la ricerca di nuove
/// foto vicine, anche quando la traccia non ne ha ancora nessuna collegata
/// (in quel caso l'intestazione non ha né conteggio né freccia, dato che non
/// c'è nulla da espandere).
class _PhotoSection extends ConsumerStatefulWidget {
  const _PhotoSection({required this.track, required this.enabled});

  final DrawnTrack track;

  /// `false` finché le metriche della traccia non sono pronte: replica la
  /// condizione che prima disabilitava l'icona "Trova foto vicine" nella
  /// riga strumenti (ora spostata qui, vedi decisione UX 28 lug 2026).
  final bool enabled;

  @override
  ConsumerState<_PhotoSection> createState() => _PhotoSectionState();
}

class _PhotoSectionState extends ConsumerState<_PhotoSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final photos = widget.track.photos;
    final hasPhotos = photos.isNotEmpty;
    final sessions = hasPhotos
        ? const PhotoSessionGrouper().group(photos)
        : const <PhotoSession>[];

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: hasPhotos
                      ? () => setState(() => _expanded = !_expanded)
                      : null,
                  child: Text(
                    hasPhotos
                        ? 'FOTO · ${photos.length} FOTO'
                        : 'Nessuna foto collegata',
                    style: AppText.caption.copyWith(
                      color: palette.secondaryLabel,
                      fontWeight: FontWeight.w600,
                      letterSpacing: hasPhotos ? 0.4 : 0,
                    ),
                  ),
                ),
              ),
              // Sempre accesa (non è uno stato "attivo/disattivo" ma
              // l'azione principale della sezione): stesso trattamento
              // visivo del toggle "Profilo altimetrico" attivo.
              AppIconButton(
                tooltip: 'Trova foto vicine',
                icon: CupertinoIcons.add,
                active: true,
                size: 32,
                onPressed: widget.enabled
                    ? () => findNearbyPhotos(context, ref, widget.track)
                    : null,
              ),
              if (hasPhotos) ...[
                const SizedBox(width: 2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      _expanded
                          ? CupertinoIcons.chevron_down
                          : CupertinoIcons.chevron_up,
                      size: 16,
                      color: palette.tertiaryIcon,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (hasPhotos && _expanded) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < sessions.length; i++) ...[
              _PhotoSessionRow(
                session: sessions[i],
                onTap: () => showAppBottomSheet<void>(
                  context: context,
                  builder: (_) => _PhotoSessionSheet(
                    session: sessions[i],
                    onSelect: (p) =>
                        ref.read(selectedPhotoProvider.notifier).set(p),
                  ),
                ),
              ),
              if (i < sessions.length - 1) const SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }
}

/// Riga di un'escursione nella sezione FOTO espansa: copertina (prima foto
/// del gruppo o icona generica), titolo con la data, conteggio, freccia →
/// verso il foglio con la griglia del gruppo ([_PhotoSessionSheet]).
class _PhotoSessionRow extends StatelessWidget {
  const _PhotoSessionRow({required this.session, required this.onTap});

  final PhotoSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cover = session.photos.first.thumbnail;
    final count = session.photos.length;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 0),
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: palette.hairline.withValues(alpha: 0.1),
          borderRadius: AppRadii.rMd,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadii.rMd,
              child: SizedBox(
                width: 44,
                height: 44,
                child: cover != null
                    ? Image.memory(cover, fit: BoxFit.cover)
                    : ColoredBox(
                        color: palette.hairline.withValues(alpha: 0.08),
                        child: Icon(CupertinoIcons.photo,
                            color: palette.tertiaryIcon),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    session.date != null
                        ? 'Escursione del ${Format.longDate(session.date!)}'
                        : 'Foto senza data',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: palette.label,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 1 ? '1 foto' : '$count foto',
                    style: AppText.captionSmall
                        .copyWith(color: palette.secondaryLabel),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                size: 16, color: palette.tertiaryIcon),
          ],
        ),
      ),
    );
  }
}

/// Foglio con la griglia delle foto di un'escursione: tap su una thumbnail
/// chiude il foglio e mostra [PhotoDetailCard] (stessa via di selezione
/// della thumbnail nel grafico del profilo — un solo punto di dettaglio).
class _PhotoSessionSheet extends StatelessWidget {
  const _PhotoSessionSheet({required this.session, required this.onSelect});

  final PhotoSession session;
  final ValueChanged<TrackPhoto> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Per distanza-lungo-percorso crescente, non nell'ordine di
    // collegamento: più intuitivo da sfogliare insieme al grafico del
    // profilo (stesso criterio della vecchia striscia).
    final photos = [...session.photos]
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSheetHeader(
            title: session.date != null
                ? 'Escursione del ${Format.longDate(session.date!)}'
                : 'Foto senza data',
            onClose: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: photos.length,
              itemBuilder: (_, i) {
                final photo = photos[i];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelect(photo);
                  },
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
                );
              },
            ),
          ),
        ],
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
/// toccando una thumbnail nella sezione FOTO/nel grafico del profilo sia un
/// pin foto in mappa (tutti passano da `selectedPhotoProvider`, mostrata sopra
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

    // Ancorata a tutta larghezza sopra `DrawRouteControls` (che gestisce da
    // sé il padding di sicurezza inferiore, essendo lei il foglio più in
    // basso): stesso trattamento "non più fluttuante" della card traccia.
    return AppSheetSurface(
      floating: false,
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
                    onTap: () {
                      // Il carosello a schermo intero mostra tutta la stessa
                      // escursione di `current`, non solo lei sola.
                      final sessions =
                          const PhotoSessionGrouper().group(photos);
                      final session = sessions.firstWhere(
                        (s) => s.photos.any((p) => p.id == current.id),
                        orElse: () => PhotoSession(
                            photos: [current], date: current.takenAt),
                      );
                      openFullPhoto(
                          context, trackId, session.photos, current);
                    },
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
      );
  }
}

/// Dialog per rinominare una foto: campo di testo precompilato col titolo
/// corrente (vuoto se non impostato — l'interfaccia mostra la data/ora come
/// default, non un valore forzato nei dati).
Future<void> _promptEditPhotoTitle(BuildContext context, WidgetRef ref,
    String trackId, TrackPhoto photo) async {
  final controller = TextEditingController(text: photo.title ?? '');
  // `FocusNode` + richiesta di focus a un frame già disegnato, non
  // `autofocus: true`: sullo sheet modale il focus automatico gareggiava con
  // l'animazione di apertura e il campo restava senza fuoco/tastiera — dal
  // dito dell'utente sembrava che il testo da scrivere non ci fosse.
  final focusNode = FocusNode();
  // Bottom sheet, non più dialog centrato (`new design/DESIGN_GUIDELINES.md`
  // §7/§10: "Modifica titolo" era l'esempio esplicito da convertire).
  final result = await showAppBottomSheet<bool>(
    context: context,
    builder: (sheetContext) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (sheetContext.mounted) focusNode.requestFocus();
      });
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
            focusNode: focusNode,
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
  focusNode.dispose();
  if (result == true) {
    await ref
        .read(tracksProvider.notifier)
        .updatePhotoTitle(trackId, photo.id, controller.text.trim());
  }
  controller.dispose();
}

/// Apre la foto **a schermo intero** in stile galleria (§"Sync album
/// fotografico"): titolo + azioni Modifica/Scollega in alto, carosello
/// orizzontale (con filmstrip) tra tutte le foto di [carousel] — la stessa
/// escursione di [initial], non solo lei sola — a partire da [initial].
/// [trackId] `null` disabilita Modifica/Scollega (traccia non risolvibile,
/// caso difensivo). Ogni pagina riapre il proprio asset dalla libreria del
/// dispositivo tramite l'id `photo_manager` di **questo** device: se non
/// risolve (es. traccia sincronizzata da un altro dispositivo) mostra la
/// thumbnail salvata nei metadati invece di un errore muto — degrado onesto.
Future<void> openFullPhoto(
  BuildContext context,
  String? trackId,
  List<TrackPhoto> carousel,
  TrackPhoto initial,
) async {
  final startIndex = carousel.indexWhere((p) => p.id == initial.id);
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: const Color(0xFF000000),
      pageBuilder: (_, __, ___) => _FullPhotoView(
        trackId: trackId,
        photoIds: [for (final p in carousel) p.id],
        initialIndex: startIndex < 0 ? 0 : startIndex,
      ),
    ),
  );
}

class _FullPhotoView extends ConsumerStatefulWidget {
  const _FullPhotoView({
    required this.trackId,
    required this.photoIds,
    required this.initialIndex,
  });

  final String? trackId;
  final List<String> photoIds;
  final int initialIndex;

  @override
  ConsumerState<_FullPhotoView> createState() => _FullPhotoViewState();
}

class _FullPhotoViewState extends ConsumerState<_FullPhotoView> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _page = widget.initialIndex;

  // Swipe verticale per chiudere (come la galleria Foto di Apple): l'offset
  // corrente del trascinamento, usato per far seguire l'immagine al dito e
  // sfumare lo sfondo, e la soglia oltre la quale rilasciare chiude davvero.
  double _dragDy = 0;
  static const double _dismissDistance = 120;
  static const double _dismissVelocity = 800;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allPhotos =
        ref.watch(tracksProvider.select((s) => s.active?.photos)) ??
            const <TrackPhoto>[];
    // Solo le foto ancora collegate, nello stesso ordine con cui il
    // carosello è stato aperto: se una viene scollegata (anche da qui, col
    // cestino) sparisce dalla vista invece di restare "fantasma".
    final photos = [
      for (final id in widget.photoIds)
        for (final p in allPhotos)
          if (p.id == id) p,
    ];
    if (photos.isEmpty) {
      // Tutte scollegate nel frattempo: non c'è più nulla da mostrare qui.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const ColoredBox(color: Color(0xFF000000));
    }
    final index = _page.clamp(0, photos.length - 1);
    final current = photos[index];

    final dragProgress = (_dragDy.abs() / 400).clamp(0.0, 1.0);
    final backdropAlpha = 1 - dragProgress * 0.7;

    return GestureDetector(
      onVerticalDragUpdate: (d) => setState(() => _dragDy += d.delta.dy),
      onVerticalDragEnd: (d) {
        final fling = (d.primaryVelocity ?? 0).abs() > _dismissVelocity;
        if (_dragDy.abs() > _dismissDistance || fling) {
          Navigator.of(context).maybePop();
        } else {
          setState(() => _dragDy = 0);
        }
      },
      child: ColoredBox(
        color: const Color(0xFF000000).withValues(alpha: backdropAlpha),
        child: Transform.translate(
          offset: Offset(0, _dragDy),
          child: SafeArea(
            child: Column(
              children: [
                _FullPhotoTopBar(
                  photo: current,
                  onClose: () => Navigator.of(context).maybePop(),
                  onEdit: widget.trackId == null
                      ? null
                      : () => _promptEditPhotoTitle(
                          context, ref, widget.trackId!, current),
                  onDelete: widget.trackId == null
                      ? null
                      : () => _confirmRemovePhoto(
                          context, ref, widget.trackId!, current.id),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => _FullPhotoPage(photo: photos[i]),
                  ),
                ),
                if (photos.length > 1)
                  _PhotoFilmstrip(
                    photos: photos,
                    selectedIndex: index,
                    onSelect: (i) => _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra superiore del visualizzatore: chiudi, titolo (o data come
/// fallback, stessa logica di [PhotoDetailCard]), Modifica/Scollega.
class _FullPhotoTopBar extends StatelessWidget {
  const _FullPhotoTopBar({
    required this.photo,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
  });

  final TrackPhoto photo;
  final VoidCallback onClose;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hasTitle = photo.title != null && photo.title!.isNotEmpty;
    final title = hasTitle
        ? photo.title!
        : (photo.takenAt != null
            ? Format.dateTime(photo.takenAt!)
            : 'Foto collegata');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          _FullPhotoIconButton(icon: CupertinoIcons.xmark, onPressed: onClose),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          _FullPhotoIconButton(icon: CupertinoIcons.pencil, onPressed: onEdit),
          _FullPhotoIconButton(
              icon: CupertinoIcons.delete, onPressed: onDelete),
        ],
      ),
    );
  }
}

class _FullPhotoIconButton extends StatelessWidget {
  const _FullPhotoIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: Icon(
        icon,
        color:
            onPressed == null ? const Color(0x66FFFFFF) : const Color(0xFFFFFFFF),
        size: 22,
      ),
    );
  }
}

/// Una pagina del carosello: risolve l'asset **a schermo intero** dalla
/// libreria del dispositivo in modo indipendente (non tutte insieme, solo
/// quando la pagina entra nell'albero) mostrando la thumbnail già disponibile
/// nel frattempo o come fallback onesto se l'originale non risolve più.
class _FullPhotoPage extends StatefulWidget {
  const _FullPhotoPage({required this.photo});

  final TrackPhoto photo;

  @override
  State<_FullPhotoPage> createState() => _FullPhotoPageState();
}

class _FullPhotoPageState extends State<_FullPhotoPage> {
  late Future<File?> _fileFuture = _load(widget.photo.id);

  Future<File?> _load(String photoId) async {
    try {
      final asset = await AssetEntity.fromId(photoId);
      return await asset?.file;
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant _FullPhotoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.id != widget.photo.id) {
      _fileFuture = _load(widget.photo.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _fileFuture,
      builder: (_, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(child: Image.file(file)),
          );
        }
        final thumb = widget.photo.thumbnail;
        return Center(
          child: thumb != null
              ? Opacity(
                  opacity: 0.6,
                  child: Image.memory(thumb, fit: BoxFit.contain),
                )
              : const Icon(CupertinoIcons.photo,
                  color: Color(0x66FFFFFF), size: 64),
        );
      },
    );
  }
}

/// Filmstrip in basso (come la galleria Foto di Apple): tocca una miniatura
/// per saltare a quella pagina; la miniatura selezionata scorre in vista da
/// sé quando cambia (swipe sull'immagine principale o tap altrove).
class _PhotoFilmstrip extends StatefulWidget {
  const _PhotoFilmstrip({
    required this.photos,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<TrackPhoto> photos;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  State<_PhotoFilmstrip> createState() => _PhotoFilmstripState();
}

class _PhotoFilmstripState extends State<_PhotoFilmstrip> {
  final Map<String, GlobalKey> _keys = {};

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  @override
  void didUpdateWidget(covariant _PhotoFilmstrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final id = widget.photos[widget.selectedIndex].id;
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          itemCount: widget.photos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final photo = widget.photos[i];
            final selected = i == widget.selectedIndex;
            return GestureDetector(
              key: _keyFor(photo.id),
              onTap: () => widget.onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.rMd,
                  border: Border.all(
                    color:
                        selected ? const Color(0xFFFFFFFF) : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: AppRadii.rMd,
                  child: photo.thumbnail != null
                      ? Image.memory(photo.thumbnail!, fit: BoxFit.cover)
                      : const ColoredBox(
                          color: Color(0x33FFFFFF),
                          child: Icon(CupertinoIcons.photo,
                              color: Color(0x88FFFFFF)),
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
