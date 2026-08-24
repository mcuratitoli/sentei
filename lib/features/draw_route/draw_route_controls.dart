import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoButton,
        CupertinoIcons,
        CupertinoSwitch,
        CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/util/format.dart';
import '../../domain/models/photo_session.dart';
import '../../domain/models/track_photo.dart';
import '../../domain/services/hiking_time.dart';
import '../../domain/services/path_geometry.dart';
import '../../domain/services/photo_session_grouper.dart';
import '../../domain/services/track_metrics.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/app_buttons.dart';
import '../../ui/badges.dart';
import '../../ui/cai_difficulty.dart';
import '../../ui/elevation_profile_chart.dart';
import '../../ui/ios_menu.dart';
import '../../ui/tokens.dart';
import '../../ui/trail_detail_sheet.dart';
import '../map/map_providers.dart';
import '../offline_maps/offline_maps_providers.dart';
import '../offline_maps/track_offline_download.dart';
import '../settings/hiking_pace_provider.dart';
import 'export/export_gpx.dart';
import 'export/export_image_screen.dart';
import 'nearby_photos_action.dart';
import 'photo_location_panel.dart';
import 'route_editor_provider.dart';

const _hikingTimeCalculator = HikingTimeCalculator();

/// Seleziona una foto (mostra il pallino sulla mappa, `_renderPhotos` in
/// `map_gl_screen.dart`) e centra la mappa sul suo punto di scatto — stessa
/// coppia di azioni ovunque si tocchi una miniatura, così il pallino non
/// resta mai "silenzioso" fuori dallo schermo.
void _selectPhoto(WidgetRef ref, TrackPhoto photo) {
  ref.read(selectedPhotoProvider.notifier).set(photo);
  ref.read(mapFlyToPointProvider.notifier).flyTo(photo.position);
}

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

    // Superficie **opaca** (`design/DESIGN_GUIDELINES.md` §7), non più
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
      // Chiusura trascinando l'handle, oltre alla × nell'header (traccia
      // selezionata): solo quando la card *mostra* una traccia — durante il
      // disegno chiudere per sbaglio con uno scorrimento farebbe perdere il
      // lavoro, lì si esce dal pulsante "Annulla" con conferma.
      onDismiss:
          drawing ? null : () => ref.read(tracksProvider.notifier).deselect(),
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
    final freeMode = ref.watch(freeDrawingModeProvider);
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
            snap: snap,
            onDelete: () => _confirmDeleteWaypoint(context, ref, selectedWp),
            onInsertBefore: selectedWp == 0
                ? null
                : () async {
                    await ref
                        .read(tracksProvider.notifier)
                        .insertPointBefore(selectedWp);
                    // Il nuovo punto prende il posto di quello selezionato:
                    // segue la selezione sul punto originale (slittato di uno).
                    // Dopo l'await, non prima: l'indice non esiste finché
                    // l'inserimento non è completato.
                    ref
                        .read(selectedWaypointProvider.notifier)
                        .set(selectedWp + 1);
                  },
            onInsertAfter: selectedWp >= wpCount - 1
                ? null
                : () => ref
                    .read(tracksProvider.notifier)
                    .insertPointAfter(selectedWp),
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
              // "Libero" (§"Traccia mista", `docs/ROADMAP.md` P3): finché è
              // acceso, i punti aggiunti da qui in poi si collegano in linea
              // retta invece di seguire i sentieri — per un tratto specifico
              // (es. l'ultima salita a una cima), non l'intera traccia.
              // Disabilitato quando lo snap è già spento per tutta la
              // traccia: sarebbe senza oggetto, è già tutto libero.
              AppIconButton(
                tooltip: !snap
                    ? 'Tratto libero (l\'intera traccia è già senza sentieri)'
                    : freeMode
                        ? 'Disattiva tratto libero'
                        : 'Attiva tratto libero',
                active: freeMode,
                onPressed: !snap
                    ? null
                    : () => ref.read(freeDrawingModeProvider.notifier).toggle(),
                icon: CupertinoIcons.scribble,
              ),
              const SizedBox(width: 6),
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
    final pace = ref.watch(hikingPaceProvider);
    final hikingTime = hasMetrics
        ? _hikingTimeCalculator.estimateForTrack(
            metrics.profile,
            distanceMeters: metrics.distanceMeters,
            gainMeters: metrics.elevation.gain,
            lossMeters: metrics.elevation.loss,
            pace: pace,
          )
        : null;

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
          // × oltre al chevron: si affianca al trascinamento dell'handle
          // (`AppSheetSurface.onDismiss` in `DrawRouteControls`), non lo
          // sostituisce — più comoda quando la card è espansa e l'handle è
          // fuori dalla vista comoda del pollice.
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
            if (hikingTime != null && hikingTime.total > Duration.zero)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _HikingTimeRow(estimate: hikingTime),
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
              _TrailInfo(track: track, scale: difficulty),
          ],
          const SizedBox(height: 8),
          // Icone nude, senza testo/sfondo. Solo le due "vista" (profilo
          // altimetrico, colori dislivelli) restano dirette in riga: le
          // azioni sulla traccia (modifica/esporta/salva offline/elimina)
          // sono confluite nel menu "altro" per non affollare la riga oltre
          // 3 icone (rischio di andare a capo sugli schermi stretti).
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
                tooltip: 'Altro',
                onPressed: saving || track == null
                    ? null
                    : () => _showTrackMenu(context, ref, track),
                icon: CupertinoIcons.ellipsis,
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
            ),
          ],
          // In fondo alla card, **sotto** il profilo altimetrico: le foto
          // sono un approfondimento del percorso già descritto sopra
          // (metriche → segnavia → grafico), non un'informazione di pari
          // livello da anteporre.
          if (!saving && track != null)
            _PhotoSection(track: track, enabled: hasMetrics),
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

/// Menu "altro" della card traccia selezionata: azioni sulla traccia che
/// prima erano icone dirette in riga (§export immagine, `docs/ROADMAP.md`
/// aggiunta non pianificata) — spostate qui per non affollare la riga sopra.
/// "Esporta GPX"/"Esporta immagine" sono voci dirette (non un sotto-foglio):
/// essendo già dentro un menu, un secondo livello di scelta era ridondante.
Future<void> _showTrackMenu(
    BuildContext context, WidgetRef ref, DrawnTrack track) async {
  final regions = ref.read(downloadedRegionsProvider).value;
  final isOffline = regions?.any((r) => r.id == 'track-${track.id}') ?? false;
  await showIosMenu(
    context: context,
    title: track.name.isNotEmpty ? track.name : 'Senza nome',
    items: [
      IosMenuItem(
        label: 'Modifica',
        icon: CupertinoIcons.pencil,
        onPressed: () => ref.read(tracksProvider.notifier).editSelected(),
      ),
      IosMenuItem(
        label: 'Esporta GPX',
        icon: CupertinoIcons.square_arrow_up,
        onPressed: () => exportTrackGpx(context, track),
      ),
      IosMenuItem(
        label: 'Esporta immagine',
        icon: CupertinoIcons.photo,
        onPressed: () => context.pushNamed(ExportImageScreen.routeName,
            pathParameters: {'trackId': track.id}),
      ),
      IosMenuItem(
        // Già scaricata: resta comunque toccabile per riscaricare (es. dopo
        // aver modificato il percorso), ma icona/testo lo segnalano.
        label: isOffline ? 'Salvata offline' : 'Salva offline',
        icon: isOffline
            ? CupertinoIcons.checkmark_seal_fill
            : CupertinoIcons.cloud_download,
        onPressed: () => downloadTrackOffline(context, ref, track),
      ),
      IosMenuItem(
        label: 'Elimina',
        icon: CupertinoIcons.delete,
        isDestructive: true,
        onPressed: () => _confirmDeleteTrack(context, ref, track),
      ),
    ],
  );
}

/// Conferma ed elimina la traccia [track] dalla card di selezione sulla
/// mappa (stessa conferma della lista tracciati, `tracks_list_screen.dart`).
/// `Tracks.remove` deseleziona da sé se l'id rimosso è quello attivo, quindi
/// la card si chiude senza altro intervento.
Future<void> _confirmDeleteTrack(
    BuildContext context, WidgetRef ref, DrawnTrack track) async {
  final name = track.name.isNotEmpty ? track.name : 'Senza nome';
  await showIosConfirm(
    context: context,
    title: 'Eliminare la traccia?',
    message: '«$name» verrà eliminata definitivamente.',
    confirmLabel: 'Elimina',
    onConfirm: () => ref.read(tracksProvider.notifier).remove(track.id),
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
/// ispezionato in esplorazione) e le sue **coordinate** (stesso formato del
/// punto ispezionato, `Format.coordinates`), un suggerimento per lo
/// spostamento, il tasto **"Libero"** (§"Traccia mista" — stesso stato di
/// quello nella barra di disegno principale, qui perché una cima fuori
/// sentiero si nota spesso *dopo* aver già selezionato il punto da cui
/// inserirla, non prima di iniziare a disegnare) e le azioni **Aggiungi
/// prima**/**Aggiungi dopo** (assenti rispettivamente sul primo e
/// sull'ultimo punto, che non hanno un precedente/successivo) ed
/// **Elimina** (con conferma, isolata sotto perché distruttiva) — pillole
/// chiare con icona, stesso linguaggio del resto della card (`_PillAction`),
/// non più testo puro.
class _SelectedWaypointBar extends ConsumerWidget {
  const _SelectedWaypointBar({
    required this.index,
    required this.total,
    required this.point,
    required this.snap,
    required this.onDelete,
    required this.onInsertBefore,
    required this.onInsertAfter,
    required this.onClose,
  });

  final int index;
  final int total;
  final LatLng point;

  /// `DrawnTrack.snapToTrail` dell'intera traccia: se già spento, il tasto
  /// "Libero" qui sotto è senza oggetto (è già tutto libero) e va disattivato.
  final bool snap;
  final VoidCallback onDelete;
  final VoidCallback? onInsertBefore;
  final VoidCallback? onInsertAfter;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final elevation = ref.watch(waypointElevationProvider(point));
    final freeMode = ref.watch(freeDrawingModeProvider);
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
          child: Text(Format.coordinates(point.latitude, point.longitude),
              style: AppText.captionSmall
                  .copyWith(color: palette.secondaryLabel)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('Tieni premuto per spostare',
              style:
                  AppText.captionSmall.copyWith(color: palette.tertiaryIcon)),
        ),
        if (onInsertBefore != null || onInsertAfter != null) ...[
          const SizedBox(height: 10),
          // Riga intera cliccabile (non solo l'icona): stesso linguaggio di
          // `_AdvancedSettingsRow" (contenitore tinto, raggio AppRadii.rMd)
          // ma come **interruttore** — sfondo e spunta cambiano con lo stato,
          // invece del solo chevron di navigazione. Corretto su segnalazione
          // dell'utente: prima solo il pallino icona era cliccabile e non si
          // capiva che l'intera riga fosse un bottone.
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            onPressed: !snap
                ? null
                : () => ref.read(freeDrawingModeProvider.notifier).toggle(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: freeMode
                    ? palette.accent.withValues(alpha: 0.14)
                    : palette.hairline.withValues(alpha: 0.1),
                borderRadius: AppRadii.rMd,
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.scribble,
                      size: 18,
                      color: !snap
                          ? palette.tertiaryIcon
                          : freeMode
                              ? palette.accent
                              : palette.secondaryLabel),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      !snap
                          ? 'Libero (l\'intera traccia è già senza sentieri)'
                          : freeMode
                              ? 'Libero: il nuovo punto non seguirà i sentieri'
                              : 'Segui sentieri: attiva "Libero" per un tratto fuori sentiero',
                      style: AppText.captionSmall.copyWith(
                          color: !snap
                              ? palette.tertiaryIcon
                              : palette.secondaryLabel),
                    ),
                  ),
                  Icon(
                    freeMode
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    size: 18,
                    color: !snap
                        ? palette.tertiaryIcon
                        : freeMode
                            ? palette.accent
                            : palette.tertiaryIcon,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (onInsertBefore != null || onInsertAfter != null) ...[
          Row(
            children: [
              if (onInsertBefore != null)
                Expanded(
                  child: AppButton(
                    label: 'Aggiungi prima',
                    icon: CupertinoIcons.add,
                    variant: AppButtonVariant.secondary,
                    onPressed: onInsertBefore,
                  ),
                ),
              if (onInsertBefore != null && onInsertAfter != null)
                const SizedBox(width: 8),
              if (onInsertAfter != null)
                Expanded(
                  child: AppButton(
                    label: 'Aggiungi dopo',
                    icon: CupertinoIcons.add,
                    variant: AppButtonVariant.secondary,
                    onPressed: onInsertAfter,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: 'Elimina',
            icon: CupertinoIcons.delete,
            variant: AppButtonVariant.destructive,
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}

/// Numeri dei sentieri (ref CAI) attraversati + grado di difficoltà complessivo.
/// Label dei segnavia coinvolti nella traccia + eventuale badge difficoltà.
/// Tap su una label (§"Un segnavia per intero") apre l'approfondimento: qui
/// però `track.trailRefs` è solo `List<String>` (nessun id/fonte associato
/// a ogni ref, a differenza di `InspectedPoint.nearbyTrails`), quindi serve
/// prima **risolvere** la relazione completa vicino a un punto della
/// traccia — [_anchorFor] trova il punto a metà del tratto con quel ref
/// (`TrackMetrics.trailSegments`, stesso schema di `TrailSegment.ref`), non
/// un punto qualsiasi: un ref può comparire più volte lungo un percorso
/// lungo, serve un punto vicino a **questo** tratto specifico.
class _TrailInfo extends ConsumerWidget {
  const _TrailInfo({required this.track, required this.scale});

  final DrawnTrack? track;
  final String? scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = scale; // locale: promuovibile dopo il null-check
    final t = track;
    final refs = t?.trailRefs ?? const [];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final r in refs)
            AppTrailTag(
              label: r,
              onTap: t == null
                  ? null
                  : () => showTrailDetailByRef(context, ref, r, _anchorFor(t, r)),
            ),
          if (s != null) AppDifficultyBadge(scale: s),
        ],
      ),
    );
  }

  LatLng _anchorFor(DrawnTrack t, String trailRef) {
    final segments = t.metrics?.trailSegments ?? const [];
    final path = t.routedPath;
    final total = const PathGeometry().totalDistance(path);
    if (total > 0) {
      for (final seg in segments) {
        if (seg.ref == trailRef) {
          final mid = (seg.fromMeters + seg.toMeters) / 2;
          return const PathGeometry().pointAtFraction(path, mid / total);
        }
      }
    }
    // Nessun tratto trovato (dato mancante/traccia molto vecchia): meglio un
    // punto qualsiasi della traccia che nessun punto — la risoluzione
    // potrebbe comunque trovare il segnavia se passa vicino.
    if (path.isNotEmpty) return path.first;
    return t.waypoints.isNotEmpty ? t.waypoints.first : const LatLng(0, 0);
  }
}

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

/// Sessioni con le foto **ordinate per distanza lungo il percorso**, non per
/// ordine di collegamento: è l'ordine in cui le si incontra camminando, lo
/// stesso con cui si legge il profilo altimetrico. Lo usano sia le righe
/// della sezione FOTO (copertina = foto più "in basso" nel percorso) sia il
/// carosello di [PhotoDetailCard] — prima viveva dentro il foglio-griglia
/// dell'escursione, ora rimosso.
List<PhotoSession> _sessionsByDistance(List<TrackPhoto> photos) => [
      for (final s in const PhotoSessionGrouper().group(photos))
        PhotoSession(
          photos: [...s.photos]
            ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters)),
          date: s.date,
        ),
    ];

class _PhotoSectionState extends ConsumerState<_PhotoSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final photos = widget.track.photos;
    final hasPhotos = photos.isNotEmpty;
    final sessions =
        hasPhotos ? _sessionsByDistance(photos) : const <PhotoSession>[];

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
                // Niente più foglio con la griglia in mezzo: si va dritti
                // alla prima foto dell'escursione in `PhotoDetailCard`, che
                // ha già il carosello di tutto il gruppo sotto — la griglia
                // era un passaggio in più per la stessa informazione.
                onTap: () => _selectPhoto(ref, sessions[i].photos.first),
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
/// verso la prima foto del gruppo in [PhotoDetailCard].
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
                    ? Image.memory(cover,
                        fit: BoxFit.cover,
                        cacheWidth: _decodeWidth(context, 44))
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

/// Pallino colore tracciato (`design/DESIGN_GUIDELINES.md` §6): il
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
        child:
            Icon(CupertinoIcons.pencil, size: 18, color: palette.iconGreyLight),
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
    // `design/DESIGN_GUIDELINES.md` §2 — "il blu è l'unico colore di
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

/// Tempo di percorrenza stimato (§ROADMAP P1.2). Un percorso **chiuso**
/// (andata e ritorno, o anello con partenza/arrivo nello stesso punto — es.
/// la salita a un rifugio) mostra salita e discesa separate, con gli stessi
/// colori/icone di [_GainLoss] così il legame con D+/D- resta leggibile a
/// colpo d'occhio; un sentiero punto-a-punto mostra solo la stima totale.
class _HikingTimeRow extends StatelessWidget {
  const _HikingTimeRow({required this.estimate});

  final HikingTimeEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final style = AppText.captionSmall;
    final icon =
        Icon(CupertinoIcons.clock, size: 14, color: context.palette.secondaryLabel);

    if (!estimate.isSplit) {
      // "Circa": è una stima col metodo CAI, non un cronometro — non
      // include le soste.
      return Row(mainAxisSize: MainAxisSize.min, children: [
        icon,
        const SizedBox(width: 4),
        Text('Circa ${Format.duration(estimate.total)} di cammino',
            style: style),
      ]);
    }

    const up = AppDifficultyColors.t;
    const down = AppDifficultyColors.eea;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.arrow_up_right, size: 14, color: up),
        const SizedBox(width: 3),
        Text('Salita ${Format.duration(estimate.ascent!)}', style: style),
        const SizedBox(width: 10),
        Icon(CupertinoIcons.arrow_down_right, size: 14, color: down),
        const SizedBox(width: 3),
        Text('Discesa ${Format.duration(estimate.descent!)}', style: style),
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
    // Foto della **stessa escursione**: alimentano sia il carosello in fondo
    // alla card sia il visualizzatore a schermo intero, che mostrano lo
    // stesso insieme.
    final session = _sessionsByDistance(photos).firstWhere(
      (s) => s.photos.any((p) => p.id == current.id),
      orElse: () => PhotoSession(photos: [current], date: current.takenAt),
    );
    final elevation = ref.watch(waypointElevationProvider(current.position));
    final hasTitle = current.title != null && current.title!.isNotEmpty;
    final title = hasTitle
        ? current.title!
        : (current.takenAt != null
            ? Format.dateTime(current.takenAt!)
            : 'Foto collegata');

    // Data/ora **aggiuntiva** solo se esiste un titolo personalizzato:
    // altrimenti `title` è già la data formattata (fallback) e ripeterla
    // sarebbe una duplicazione.
    final showExtraDate = hasTitle && current.takenAt != null;
    final selectedIndex = session.photos.indexWhere((p) => p.id == current.id);

    // Niente intestazione con titolo ("Dettaglio foto" non aggiungeva
    // informazione) e niente ×: la card è una riga sola — miniatura, dati, e
    // a destra le due azioni ridotte a icone. Si chiude trascinando l'handle
    // verso il basso, come la card traccia. Lo spazio liberato dalle vecchie
    // pillole a tutta larghezza ospita ora il carosello dell'escursione.
    //
    // `SizedBox` a larghezza infinita: dentro lo `Stack` di
    // `map_gl_screen.dart` (sovrapposta alla card traccia) le costanti sono
    // lasche e senza questo la card si stringerebbe sul contenuto.
    return SizedBox(
      width: double.infinity,
      child: AppSheetSurface(
        floating: false,
        onDismiss: onClose,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _selectPhoto(ref, current);
                        openFullPhoto(context, trackId, session.photos, current);
                      },
                      child: ClipRRect(
                        borderRadius: AppRadii.rMd,
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: current.thumbnail != null
                              ? Image.memory(current.thumbnail!,
                                  fit: BoxFit.cover,
                                  cacheWidth: _decodeWidth(context, 64))
                              : ColoredBox(
                                  color:
                                      palette.hairline.withValues(alpha: 0.08),
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
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.value.copyWith(
                                  color: palette.label,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          // Quota (+ data, se il titolo è personalizzato) e
                          // coordinate su righe distinte: in una sola riga,
                          // con le azioni ora accanto, le coordinate
                          // finivano quasi sempre troncate.
                          Row(
                            children: [
                              elevation.when(
                                data: (m) => m == null
                                    ? const SizedBox.shrink()
                                    : Text(Format.meters(m),
                                        style: AppText.captionSmall.copyWith(
                                            color: palette.secondaryLabel)),
                                loading: () => const SizedBox(
                                    height: 10,
                                    width: 10,
                                    child:
                                        CupertinoActivityIndicator(radius: 5)),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                              if (showExtraDate)
                                Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Text(
                                      Format.dateTime(current.takenAt!),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.captionSmall.copyWith(
                                          color: palette.secondaryLabel),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            Format.coordinates(current.position.latitude,
                                current.position.longitude),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.captionSmall
                                .copyWith(color: palette.secondaryLabel),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppIconButton(
                      icon: CupertinoIcons.pencil,
                      tooltip: 'Modifica titolo',
                      size: 36,
                      onPressed: trackId == null
                          ? null
                          : () => _promptEditPhotoTitle(
                              context, ref, trackId, current),
                    ),
                    const SizedBox(width: 6),
                    AppIconButton(
                      icon: CupertinoIcons.delete,
                      tooltip: 'Scollega',
                      size: 36,
                      tint: AppColors.destructive,
                      onPressed: trackId == null
                          ? null
                          : () => _confirmRemovePhoto(
                              context, ref, trackId, current.id),
                    ),
                  ],
                ),
                if (session.photos.length > 1) ...[
                  const SizedBox(height: 14),
                  // Stesso filmstrip del visualizzatore a schermo intero, in
                  // versione chiara: tocca una miniatura per spostare la card
                  // su quella foto (senza aprire il fullscreen).
                  _PhotoFilmstrip(
                    photos: session.photos,
                    selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                    onSelect: (i) => _selectPhoto(ref, session.photos[i]),
                    selectedColor: palette.accent,
                    placeholderColor: palette.hairline.withValues(alpha: 0.08),
                    placeholderIconColor: palette.tertiaryIcon,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
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
  // `FocusNode` + richiesta di focus a un frame già disegnato, non
  // `autofocus: true`: sullo sheet modale il focus automatico gareggiava con
  // l'animazione di apertura e il campo restava senza fuoco/tastiera — dal
  // dito dell'utente sembrava che il testo da scrivere non ci fosse.
  final focusNode = FocusNode();
  // Bottom sheet, non più dialog centrato (`design/DESIGN_GUIDELINES.md`
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
    // Le anteprime a piena pagina non servono a nessun'altra schermata e
    // pesano parecchi MB l'una: uscendo, la cache si svuota.
    ref.read(photoPreviewCacheProvider).clear();
    super.dispose();
  }

  /// Scalda le pagine **vicine** a [index]: lo swipe le trova già pronte
  /// invece di aspettare la libreria a ogni cambio pagina. Una per lato basta
  /// — con più margine si tengono in memoria bitmap che l'utente potrebbe non
  /// guardare mai.
  ///
  /// Non basta avere i byte: finché nessuno li **decodifica**, il lavoro (e lo
  /// scatto che si vede) si sposta soltanto al momento dello swipe. Da qui
  /// `precacheImage`, che decodifica in anticipo e lascia l'immagine nella
  /// `ImageCache` di Flutter — dove `Image.memory` sugli stessi byte la
  /// ritrova già pronta.
  void _prefetchNeighbours(List<TrackPhoto> photos, int index, Size size) {
    if (size.isEmpty) return;
    final cache = ref.read(photoPreviewCacheProvider);
    for (final i in [index - 1, index + 1]) {
      if (i < 0 || i >= photos.length) continue;
      final id = photos[i].id;
      // Già scaricata e già decodificata al passaggio precedente.
      if (cache.cached(id) != null) continue;
      cache
          .preview(id, width: size.width.round(), height: size.height.round())
          .then((bytes) {
        if (!mounted || bytes == null) return;
        precacheImage(MemoryImage(bytes), context);
      });
    }
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

    // Dimensione dello schermo come tetto per il precarico: la pagina vera è
    // un po' più bassa (barra e filmstrip), quindi l'anteprima precaricata è
    // semmai *più* grande del necessario, mai più piccola. Le richieste già
    // fatte vengono ignorate, quindi ripeterlo ad ogni build non costa nulla.
    _prefetchNeighbours(photos, index,
        MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context));

    final dragProgress = (_dragDy.abs() / 400).clamp(0.0, 1.0);
    final backdropAlpha = 1 - dragProgress * 0.7;

    // `Material` trasparente: la rotta è costruita con `PageRouteBuilder`
    // senza `Scaffold`, quindi i testi senza stile esplicito ereditavano il
    // `DefaultTextStyle.fallback` di Flutter — quello con la **doppia
    // sottolineatura gialla** di debug (si vedeva sulla data in alto e su
    // "Altitudine"). Lo sfondo resta dei `ColoredBox` qui sotto.
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
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
                    // Chiude il visualizzatore, riduce la card traccia (più
                    // mappa visibile) e centra la mappa sul punto di scatto:
                    // `selectedPhotoProvider` resta impostato (non lo tocca
                    // nessuno qui), quindi `PhotoDetailCard` con la thumbnail
                    // riappare già sopra la card ridotta — nessun'altra azione
                    // da coordinare.
                    onShowOnMap: () {
                      ref
                          .read(mapFlyToPointProvider.notifier)
                          .flyTo(current.position);
                      ref.read(trackCardExpandedProvider.notifier).collapse();
                      Navigator.of(context).maybePop();
                    },
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
                      // Costruisce anche la pagina adiacente **prima** che
                      // entri in vista: insieme al precarico qui sopra, allo
                      // swipe non resta nulla di pesante da fare.
                      allowImplicitScrolling: true,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => _FullPhotoPage(photo: photos[i]),
                    ),
                  ),
                  if (photos.length > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: _PhotoFilmstrip(
                        photos: photos,
                        selectedIndex: index,
                        onSelect: (i) => _pageController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: PhotoLocationPanel(photo: current),
                  ),
                ],
              ),
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
    required this.onShowOnMap,
    required this.onEdit,
    required this.onDelete,
  });

  final TrackPhoto photo;
  final VoidCallback onClose;
  final VoidCallback? onShowOnMap;
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
          _FullPhotoIconButton(
              icon: CupertinoIcons.location, onPressed: onShowOnMap),
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
        color: onPressed == null
            ? const Color(0x66FFFFFF)
            : const Color(0xFFFFFFFF),
        size: 22,
      ),
    );
  }
}

/// Una pagina del carosello.
///
/// Mostra un'**anteprima ridimensionata dalla libreria** allo spazio
/// disponibile, non il file originale: uno scatto da 12 MP decodificato a
/// piena risoluzione sono ~48 MB di bitmap per riempire uno schermo che ne
/// userebbe ~3, ed era la causa dell'attesa all'apertura e degli scatti
/// durante lo swipe. L'originale si carica **solo se l'utente zooma**, dove i
/// pixel in più si vedono davvero.
///
/// Ordine di ripiego: anteprima → miniatura salvata nei metadati (asset non
/// più su questo device, es. traccia sincronizzata da un altro telefono) →
/// icona.
class _FullPhotoPage extends ConsumerStatefulWidget {
  const _FullPhotoPage({required this.photo});

  final TrackPhoto photo;

  @override
  ConsumerState<_FullPhotoPage> createState() => _FullPhotoPageState();
}

class _FullPhotoPageState extends ConsumerState<_FullPhotoPage> {
  /// Ingrandimento oltre il quale l'anteprima a dimensione schermo comincia a
  /// perdere dettaglio: da lì si passa all'originale.
  static const double _originalScaleThreshold = 1.6;

  /// Quanti pixel dell'originale decodificare quando si zooma, in multipli
  /// della larghezza dello schermo. Copre lo zoom fino a 2,5× a piena
  /// definizione senza decodificare 48 MP interi: su uno scatto di un iPhone
  /// recente sarebbero ~200 MB di bitmap, e il salto si sentirebbe tutto.
  static const double _zoomDecodeFactor = 2.5;

  final TransformationController _zoom = TransformationController();

  Uint8List? _preview;
  File? _original;
  bool _loadingOriginal = false;
  bool _requested = false;

  /// Nessuna anteprima disponibile per questa foto (asset non più sul
  /// dispositivo): si ripiega sulla miniatura salvata, non sullo spinner —
  /// altrimenti girerebbe per sempre.
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onZoom);
  }

  @override
  void dispose() {
    _zoom.removeListener(_onZoom);
    _zoom.dispose();
    super.dispose();
  }

  void _onZoom() {
    if (_original != null || _loadingOriginal) return;
    if (_zoom.value.getMaxScaleOnAxis() < _originalScaleThreshold) return;
    _loadingOriginal = true;
    ref
        .read(photoLibraryServiceProvider)
        .originalFile(widget.photo.id)
        .then((file) {
      if (mounted && file != null) setState(() => _original = file);
    }).catchError((_) => null);
  }

  /// I byte dell'anteprima: quelli già arrivati a questa pagina, o quelli che
  /// la cache ha pronti perché la pagina è stata **precaricata** come vicina.
  /// Leggerli qui (e non copiarli nello stato con un `setState` differito)
  /// evita il frame di spinner su una foto che è già in memoria.
  Uint8List? _bytes(Size size) {
    if (_preview != null) return _preview;
    final cache = ref.read(photoPreviewCacheProvider);
    final ready = cache.cached(widget.photo.id);
    if (ready != null) return ready;
    if (!_requested && !size.isEmpty) {
      _requested = true;
      cache
          .preview(widget.photo.id,
              width: size.width.round(), height: size.height.round())
          .then((bytes) {
        if (!mounted) return;
        setState(() {
          _preview = bytes;
          _unavailable = bytes == null;
        });
      });
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bytes = _bytes(constraints.biggest * dpr);
        // `SizedBox.expand` + `BoxFit.contain`: la foto riempie tutto lo
        // spazio del carosello mantenendo le proporzioni. Prima era `Center`
        // sull'immagine alla sua dimensione naturale, che su scatti piccoli
        // (o sulla thumbnail di ripiego) la lasciava minuscola in mezzo al
        // nero — è il soggetto della schermata, deve dominarla.
        final image = _original != null
            ? Image.file(
                _original!,
                fit: BoxFit.contain,
                cacheWidth:
                    (constraints.maxWidth * dpr * _zoomDecodeFactor).round(),
              )
            : bytes != null
                ? Image.memory(bytes, fit: BoxFit.contain)
                : null;
        if (image != null) {
          return InteractiveViewer(
            transformationController: _zoom,
            minScale: 1,
            maxScale: 5,
            child: SizedBox.expand(child: image),
          );
        }
        // Asset non più risolvibile su questo device (es. traccia
        // sincronizzata da un altro telefono): la miniatura salvata nei
        // metadati, a piena grandezza e **non** velata — l'opacità la faceva
        // sembrare un errore di caricamento invece di una versione a bassa
        // risoluzione.
        final thumb = widget.photo.thumbnail;
        if (_unavailable) {
          return SizedBox.expand(
            child: thumb != null
                ? Image.memory(thumb, fit: BoxFit.contain)
                : const Center(
                    child: Icon(CupertinoIcons.photo,
                        color: Color(0x66FFFFFF), size: 64),
                  ),
          );
        }
        // In attesa dell'anteprima: un indicatore, non la miniatura da 200 px
        // stirata a schermo intero — quella si legge come "foto sgranata",
        // non come "sto caricando", e cambiando in corsa faceva l'effetto di
        // un salto di qualità a metà swipe.
        return const SizedBox.expand(
          child: Center(
            child: CupertinoActivityIndicator(
                radius: 16, color: Color(0xFFFFFFFF)),
          ),
        );
      },
    );
  }
}

/// Larghezza in **pixel fisici** a cui decodificare una miniatura mostrata in
/// un riquadro di [side] pt.
///
/// La miniatura salvata nei metadati è 200×200: senza questo, Flutter tiene in
/// memoria la bitmap piena (160 KB) per ogni foto anche dentro un riquadro da
/// 44 pt — con una traccia da decine di scatti sono megabyte di differenza
/// nella striscia di anteprime.
int _decodeWidth(BuildContext context, double side) =>
    (side * MediaQuery.devicePixelRatioOf(context)).round();

/// Filmstrip orizzontale (come la galleria Foto di Apple): tocca una
/// miniatura per saltare a quella foto; la miniatura selezionata scorre in
/// vista da sé quando cambia (swipe sull'immagine principale o tap altrove).
///
/// Usato in **due contesti**, da qui i colori parametrizzati: sul fondo nero
/// del visualizzatore a schermo intero (default, bianco su nero) e dentro
/// [PhotoDetailCard], su superficie chiara.
class _PhotoFilmstrip extends StatefulWidget {
  const _PhotoFilmstrip({
    required this.photos,
    required this.selectedIndex,
    required this.onSelect,
    this.selectedColor = const Color(0xFFFFFFFF),
    this.placeholderColor = const Color(0x33FFFFFF),
    this.placeholderIconColor = const Color(0x88FFFFFF),
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  final Color selectedColor;
  final Color placeholderColor;
  final Color placeholderIconColor;

  /// Padding interno della lista: i 12px laterali servono a schermo intero
  /// (bordo vivo), non dentro la card che ha già il suo padding a 20px.
  final EdgeInsetsGeometry padding;

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
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: widget.padding,
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
                  color: selected ? widget.selectedColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: AppRadii.rMd,
                child: photo.thumbnail != null
                    ? Image.memory(photo.thumbnail!,
                        fit: BoxFit.cover,
                        cacheWidth: _decodeWidth(context, 52))
                    : ColoredBox(
                        color: widget.placeholderColor,
                        child: Icon(CupertinoIcons.photo,
                            color: widget.placeholderIconColor),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
