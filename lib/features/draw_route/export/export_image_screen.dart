import 'dart:io';
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart' show PhotoManager;
import 'package:share_plus/share_plus.dart';

import '../../../core/util/format.dart';
import '../../../data/photos/photo_library_service.dart' show PhotoLibraryPermission;
import '../../../data/poi/overpass_poi_service.dart';
import '../../../domain/models/point_of_interest.dart';
import '../../../domain/services/elevation_orientation.dart';
import '../../../domain/services/hiking_time.dart';
import '../../../domain/services/nearby_pois_matcher.dart';
import '../../../domain/services/track_metrics.dart' show TrackMetrics;
import '../../../ui/app_buttons.dart';
import '../../../ui/ios_toast.dart';
import '../../../ui/tokens.dart';
import '../../settings/hiking_pace_provider.dart';
import '../nearby_photos_action.dart' show photoLibraryServiceProvider;
import '../route_editor_provider.dart';
import 'route_snapshot.dart';

const _hikingTimeCalculator = HikingTimeCalculator();

/// Dimensione logica (pt) dell'immagine esportata: 4:5, formato versatile per
/// social (Instagram feed) e comunque leggibile come "cartina" verticale.
const _kExportSize = Size(360, 450);

/// Schermata "Immagine" (§export, `docs/ROADMAP.md`): anteprima della mappa
/// 3D col tracciato, scelta dei punti interessanti da mostrare, salvataggio
/// in galleria o condivisione di sistema.
class ExportImageScreen extends ConsumerStatefulWidget {
  const ExportImageScreen({super.key, required this.trackId});

  static const String routeName = 'export-image';
  static const String routePath = '/export-image/:trackId';

  final String trackId;

  @override
  ConsumerState<ExportImageScreen> createState() => _ExportImageScreenState();
}

enum _Stage { loadingPois, capturingMap, ready, error }

class _ExportImageScreenState extends ConsumerState<ExportImageScreen> {
  final _previewKey = GlobalKey();
  _Stage _stage = _Stage.loadingPois;
  String? _errorMessage;
  DrawnTrack? _track;
  List<PoiCandidate> _pois = const [];
  Set<String> _selectedPoiIds = {};
  // Scostamento manuale (drag) di ogni etichetta rispetto alla posizione
  // calcolata automaticamente — solo l'etichetta si sposta, il pallino sul
  // punto resta fisso e corretto (§export immagine).
  final Map<String, Offset> _labelDragOffsets = {};
  RouteSnapshotResult? _snapshot;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  DrawnTrack? _findTrack() {
    for (final t in ref.read(tracksProvider).tracks) {
      if (t.id == widget.trackId) return t;
    }
    return null;
  }

  Future<void> _start() async {
    final track = _findTrack();
    if (track == null || track.routedPath.length < 2) {
      setState(() {
        _stage = _Stage.error;
        _errorMessage = 'Traccia senza percorso';
      });
      return;
    }
    _track = track;

    debugPrint('[export] avvio: ${track.routedPath.length} punti percorso');
    final raw = await OverpassPoiService().fetch(track.routedPath);
    debugPrint('[export] POI grezzi da Overpass: ${raw.length}');
    if (!mounted) return;
    final matched = const NearbyPoisMatcher()
        .match(routedPath: track.routedPath, pois: raw);
    debugPrint('[export] POI abbinati al percorso: ${matched.length}');
    setState(() {
      _pois = matched;
      // Tutti selezionati di default: l'utente toglie quelli che non vuole
      // vedere, più semplice che partire da zero e doverli spuntare tutti.
      _selectedPoiIds = matched.map((p) => p.id).toSet();
      _stage = _Stage.capturingMap;
    });
  }

  /// Orientamento della camera: segue il dislivello (punto più basso in
  /// basso, più alto in alto), non il nord — 0 (nord in alto) se il profilo
  /// non basta a calcolarlo (traccia senza quote, o punto più basso/alto
  /// coincidenti).
  double _bearing() {
    final profile = _track?.metrics?.profile;
    if (profile == null) return 0;
    return elevationOrientationBearing(profile) ?? 0;
  }

  void _onSnapshotResult(RouteSnapshotResult? result) {
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _stage = _Stage.error;
        _errorMessage = 'Impossibile generare l\'anteprima della mappa';
      });
      return;
    }
    setState(() {
      _snapshot = result;
      _stage = _Stage.ready;
    });
  }

  Future<Uint8List?> _renderFinalPng() async {
    final boundary = _previewKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  Future<File> _writeTempPng(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final track = _track!;
    final safe = (track.name.isNotEmpty ? track.name : 'tracciato')
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final path = '${dir.path}/$safe.png';
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _renderFinalPng();
      if (bytes == null) throw Exception('render fallito');
      final file = await _writeTempPng(bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: _track!.name),
      );
    } catch (_) {
      if (mounted) showIosToast(context, 'Esportazione non riuscita');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final permission =
          await ref.read(photoLibraryServiceProvider).requestPermission();
      if (permission == PhotoLibraryPermission.denied) {
        if (mounted) showIosToast(context, 'Permesso libreria foto negato');
        return;
      }
      final bytes = await _renderFinalPng();
      if (bytes == null) throw Exception('render fallito');
      final safe = (_track!.name.isNotEmpty ? _track!.name : 'tracciato')
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      await PhotoManager.editor.saveImage(bytes, filename: '$safe.png');
      if (mounted) showIosToast(context, 'Immagine salvata in galleria');
    } catch (_) {
      if (mounted) showIosToast(context, 'Salvataggio non riuscito');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.scaffoldBg,
      appBar: AppBar(
        title: const Text('Esporta'),
        centerTitle: true,
        backgroundColor: palette.scaffoldBg,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_stage) {
      case _Stage.loadingPois:
        return const _CenteredProgress(message: 'Rilevo punti di interesse…');
      case _Stage.capturingMap:
        // La mappa interattiva mostrata qui non è più quella da cui esce
        // l'immagine finale (quella arriva da uno `Snapshotter` headless,
        // vedi `route_snapshot.dart`): serve solo a calcolare le posizioni
        // pixel di partenza/arrivo/POI. Resta comunque visibile — nessun
        // problema noto a mostrarla, e l'utente vede la mappa 3D assemblarsi
        // dal vivo mentre si genera l'immagine dietro le quinte.
        return _CapturingPreview(
          track: _track!,
          pois: _pois,
          bearing: _bearing(),
          onResult: _onSnapshotResult,
        );
      case _Stage.error:
        return _ErrorBody(message: _errorMessage ?? 'Errore');
      case _Stage.ready:
        final track = _track!;
        final pace = ref.watch(hikingPaceProvider);
        final metrics = track.metrics;
        final hikingTime = metrics == null
            ? null
            : _hikingTimeCalculator.estimateForTrack(
                metrics.profile,
                distanceMeters: metrics.distanceMeters,
                gainMeters: metrics.elevation.gain,
                lossMeters: metrics.elevation.loss,
                pace: pace,
              );
        return _ReadyBody(
          previewKey: _previewKey,
          track: track,
          hikingTime: hikingTime,
          snapshot: _snapshot!,
          pois: _pois,
          selectedPoiIds: _selectedPoiIds,
          dragOffsets: _labelDragOffsets,
          onDragUpdate: (id, delta) => setState(() {
            _labelDragOffsets[id] = (_labelDragOffsets[id] ?? Offset.zero) + delta;
          }),
          busy: _busy,
          onTogglePoi: (id) => setState(() {
            if (!_selectedPoiIds.remove(id)) _selectedPoiIds.add(id);
          }),
          onSave: _saveToGallery,
          onShare: _share,
        );
    }
  }
}

/// Mappa 3D **visibile** mentre viene inquadrata e catturata (vedi il
/// commento in `_buildBody`): stessa cornice/proporzioni della card finale,
/// con un'etichetta di stato sovrapposta in basso.
class _CapturingPreview extends StatelessWidget {
  const _CapturingPreview({
    required this.track,
    required this.pois,
    required this.bearing,
    required this.onResult,
  });

  final DrawnTrack track;
  final List<PoiCandidate> pois;
  final double bearing;
  final ValueChanged<RouteSnapshotResult?> onResult;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: AspectRatio(
            aspectRatio: _kExportSize.width / _kExportSize.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // **Non** un `FittedBox`/scala qui (a differenza
                  // dell'anteprima statica finale, dove va benissimo): una
                  // vista nativa Mapbox (platform view iOS) dentro un
                  // ancestor che applica una trasformazione di scala Flutter
                  // può disallinearsi tra la dimensione logica usata per
                  // `pixelForCoordinate` e quella effettivamente
                  // renderizzata a schermo — verificato: i pallini calcolati
                  // risultavano matematicamente sul percorso (log
                  // `[export]`, differenza di pochi pixel) ma apparivano
                  // altrove nell'immagine. `OverflowBox` mantiene la mappa
                  // alla sua dimensione logica reale (`_kExportSize`, senza
                  // scala), al costo di mostrarla ritagliata invece che
                  // rimpicciolita durante questo stato di caricamento
                  // transitorio — non è l'immagine finale.
                  OverflowBox(
                    minWidth: 0,
                    minHeight: 0,
                    maxWidth: _kExportSize.width,
                    maxHeight: _kExportSize.height,
                    child: SizedBox(
                      width: _kExportSize.width,
                      height: _kExportSize.height,
                      child: RouteSnapshotCapture(
                        path: track.routedPath,
                        routeColor: track.color,
                        pois: pois,
                        size: _kExportSize,
                        bearing: bearing,
                        onResult: onResult,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: const Color(0x99000000),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CupertinoActivityIndicator(
                              radius: 8, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Genero l\'anteprima…',
                              style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
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

class _CenteredProgress extends StatelessWidget {
  const _CenteredProgress({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(radius: 12),
          const SizedBox(height: 12),
          Text(message,
              style: AppText.footnote.copyWith(color: palette.secondaryLabel)),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle,
                size: 32, color: palette.secondaryLabel),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: palette.secondaryLabel)),
          ],
        ),
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({
    required this.previewKey,
    required this.track,
    required this.hikingTime,
    required this.snapshot,
    required this.pois,
    required this.selectedPoiIds,
    required this.dragOffsets,
    required this.onDragUpdate,
    required this.busy,
    required this.onTogglePoi,
    required this.onSave,
    required this.onShare,
  });

  final GlobalKey previewKey;
  final DrawnTrack track;
  final HikingTimeEstimate? hikingTime;
  final RouteSnapshotResult snapshot;
  final List<PoiCandidate> pois;
  final Set<String> selectedPoiIds;
  final Map<String, Offset> dragOffsets;
  final void Function(String poiId, Offset delta) onDragUpdate;
  final bool busy;
  final ValueChanged<String> onTogglePoi;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: AspectRatio(
                aspectRatio: _kExportSize.width / _kExportSize.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _kExportSize.width,
                        height: _kExportSize.height,
                        child: RepaintBoundary(
                          key: previewKey,
                          child: _ExportComposite(
                            track: track,
                            hikingTime: hikingTime,
                            snapshot: snapshot,
                            pois: pois,
                            selectedPoiIds: selectedPoiIds,
                            dragOffsets: dragOffsets,
                            onDragUpdate: onDragUpdate,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: pois.isEmpty
              ? const SizedBox.shrink()
              : _PoiChecklist(
                  pois: pois,
                  selectedPoiIds: selectedPoiIds,
                  onToggle: onTogglePoi,
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                AppIconButton(
                  tooltip: 'Salva in galleria',
                  onPressed: busy ? null : onSave,
                  icon: CupertinoIcons.arrow_down_to_line,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'Condividi',
                    icon: CupertinoIcons.share,
                    variant: AppButtonVariant.primary,
                    onPressed: busy ? null : onShare,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

const TextStyle _poiLabelTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1.15,
);

/// Dove finisce l'etichetta di un POI dopo il posizionamento: il pallino
/// **esatto** sul punto (fisso, mai spostato dall'utente — deve restare
/// corretto) e il rettangolo della pillola, di partenza già scelto per non
/// sovrapporsi ad altre etichette e poi eventualmente **trascinato a mano**
/// dall'utente (§export immagine: posizionamento automatico insufficiente su
/// zone con più punti ravvicinati, l'utente sistema lui il testo).
class _PoiLabelPlacement {
  const _PoiLabelPlacement(
      {required this.id, required this.dot, required this.rect, required this.name});
  final String id;
  final Offset dot;
  final Rect rect;
  final String name;
}

/// Calcola la posizione **di partenza** di ogni etichetta POI visibile: lato
/// destro/sinistro (alternato per indice, forzato verso il centro vicino ai
/// bordi), misura il testo con [TextPainter] per sapere la dimensione reale
/// della pillola (non un valore a occhio), poi risolve le sovrapposizioni
/// spostando in basso — a passi piccoli, **senza** un tetto artificiale
/// durante la ricerca (prima si bloccava contro il bordo inferiore e
/// rinunciava con l'etichetta ancora sovrapposta) — ogni pillola finché non è
/// libera da quelle già piazzate. Poi applica lo scostamento manuale
/// dell'utente per quel POI, se presente in [dragOffsets] (§export
/// immagine, drag delle etichette). Nessuno stato qui: si ricalcola a ogni
/// build, costo trascurabile per al più 10 etichette.
List<_PoiLabelPlacement> _layoutPoiLabels({
  required List<PoiCandidate> pois,
  required Set<String> selectedPoiIds,
  required RouteSnapshotResult snapshot,
  required Map<String, Offset> dragOffsets,
}) {
  const pillPaddingH = 8.0;
  const pillPaddingV = 4.0;
  const lineLength = 14.0;
  const maxPillWidth = 110.0;
  const verticalStep = 6.0;
  const edgeMargin = 8.0;

  final imageWidth = snapshot.logicalSize.width;
  final imageHeight = snapshot.logicalSize.height;

  final placed = <Rect>[];
  final result = <_PoiLabelPlacement>[];

  for (var i = 0; i < pois.length; i++) {
    final poi = pois[i];
    if (!selectedPoiIds.contains(poi.id)) continue;
    final dot = snapshot.poiPixels[poi.id];
    if (dot == null) continue;

    final margin = maxPillWidth + 20;
    final toRight =
        dot.dx < margin ? true : (dot.dx > imageWidth - margin ? false : i.isEven);

    // Nessun `maxLines`/ellissi qui: il nome non va **mai** troncato (era
    // già successo con un tetto di 2 righe — a un certo punto un nome andava
    // a capo su una riga che restava fuori dal riquadro scuro della
    // pillola, quindi illeggibile sul terreno sotto, sembrava "tagliato").
    // La misura qui deve combaciare esattamente con quella del widget reso
    // in `_PoiPill` (stesso stile, stesso vincolo di larghezza, nessun
    // limite di righe), altrimenti l'altezza calcolata qui non basta per il
    // testo vero.
    final painter = TextPainter(
      text: TextSpan(text: poi.name, style: _poiLabelTextStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxPillWidth - pillPaddingH * 2);
    final pillWidth = painter.width + pillPaddingH * 2;
    final pillHeight = painter.height + pillPaddingV * 2;

    final left =
        toRight ? dot.dx + lineLength : dot.dx - lineLength - pillWidth;
    var top = dot.dy - pillHeight / 2;
    var rect = Rect.fromLTWH(left, top, pillWidth, pillHeight);

    var guard = 0;
    while (placed.any((r) => r.overlaps(rect)) && guard < 60) {
      top += verticalStep;
      rect = Rect.fromLTWH(left, top, pillWidth, pillHeight);
      guard++;
    }
    // Clamp finale (raro): solo se lo spostamento anti-sovrapposizione ha
    // portato la pillola fuori dai bordi dell'immagine.
    top = top.clamp(edgeMargin, imageHeight - edgeMargin - pillHeight);
    rect = Rect.fromLTWH(left, top, pillWidth, pillHeight);
    placed.add(rect);

    final drag = dragOffsets[poi.id] ?? Offset.zero;
    final dragged = rect.shift(drag);
    // La pillola trascinata **non può mai uscire dai bordi** dell'immagine
    // (prima poteva: un trascinamento un po' ampio spingeva l'etichetta
    // parzialmente fuori dal riquadro catturato, tagliando il testo — non
    // era un bug di battitura, era proprio la pillola mezza fuori dai
    // bordi). Clampata sull'intera immagine, non solo sulla zona alta
    // riservata al posizionamento automatico: l'utente può comunque
    // trascinarla vicino alla card statistiche se vuole.
    final finalRect = Rect.fromLTWH(
      dragged.left.clamp(0.0, imageWidth - dragged.width),
      dragged.top.clamp(0.0, imageHeight - dragged.height),
      dragged.width,
      dragged.height,
    );
    result.add(_PoiLabelPlacement(
        id: poi.id, dot: dot, rect: finalRect, name: poi.name));
  }
  return result;
}

/// Le lineette di tutte le etichette in un solo `CustomPaint` (più semplice
/// ed economico che un widget per lineetta): ciascuna va dal pallino sul
/// punto al bordo più vicino della sua pillola — calcolato per davvero
/// (proiezione sul rettangolo), non assunto orizzontale, perché
/// l'anti-sovrapposizione può aver spostato la pillola in verticale.
class _LeaderLinesPainter extends CustomPainter {
  const _LeaderLinesPainter(this.placements);
  final List<_PoiLabelPlacement> placements;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final p in placements) {
      final target = Offset(
        p.dot.dx.clamp(p.rect.left, p.rect.right),
        p.dot.dy.clamp(p.rect.top, p.rect.bottom),
      );
      canvas.drawLine(p.dot, target, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LeaderLinesPainter oldDelegate) =>
      !identical(oldDelegate.placements, placements);
}

/// Pallino bianco esatto sul punto interessante — l'ancoraggio reale a cui
/// punta la lineetta (assente prima: le etichette sembravano "volare" senza
/// indicare nulla di preciso sulla mappa).
class _PoiDot extends StatelessWidget {
  const _PoiDot({required this.position});
  final Offset position;
  static const double _size = 6;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - _size / 2,
      top: position.dy - _size / 2,
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.black26, width: 1),
        ),
      ),
    );
  }
}

/// Pillola col nome del POI, già posizionata da [_layoutPoiLabels] — qui solo
/// disegno, nessuna logica di piazzamento. Sfondo **semitrasparente** (si
/// intravede il tracciato/terreno sotto, testo bianco resta leggibile).
/// Trascinabile (§export immagine): il posizionamento automatico non basta
/// da solo su zone con più punti ravvicinati (richiesto esplicitamente
/// dall'utente dopo diversi tentativi di sistemazione automatica) — qui
/// l'utente sposta **solo l'etichetta**, il pallino sul punto resta fisso.
class _PoiPill extends StatelessWidget {
  const _PoiPill(
      {required this.rect, required this.name, required this.onDragUpdate});
  final Rect rect;
  final String name;
  final ValueChanged<Offset> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    // Solo `width` fissata (per il testo a capo dove previsto da
    // `_layoutPoiLabels`), **non** `height`: un'altezza forzata leggermente
    // più bassa di quella richiesta dal testo reale lo faceva "sparire"
    // parzialmente — la seconda riga si spingeva fuori dal riquadro scuro
    // della pillola, illeggibile sul terreno sotto. Qui l'altezza la decide
    // il contenuto vero, sempre.
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDragUpdate(details.delta),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x991C1C1E),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          // Nessun `maxLines`/ellissi: il nome non va mai troncato (vedi
          // commento in `_layoutPoiLabels`).
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: _poiLabelTextStyle,
          ),
        ),
      ),
    );
  }
}

/// Il contenuto **effettivamente esportato**: immagine mappa (già catturata)
/// + etichette POI + card nome/statistiche, tutto disegnato da widget Flutter
/// veri (non "cotto" nel raster della mappa) — così il toggle di un POI nella
/// checklist sottostante si vede subito, senza dover rigenerare la mappa.
class _ExportComposite extends StatelessWidget {
  const _ExportComposite({
    required this.track,
    required this.hikingTime,
    required this.snapshot,
    required this.pois,
    required this.selectedPoiIds,
    required this.dragOffsets,
    required this.onDragUpdate,
  });

  final DrawnTrack track;
  final HikingTimeEstimate? hikingTime;
  final RouteSnapshotResult snapshot;
  final List<PoiCandidate> pois;
  final Set<String> selectedPoiIds;
  final Map<String, Offset> dragOffsets;
  final void Function(String poiId, Offset delta) onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final metrics = track.metrics;
    final placements = _layoutPoiLabels(
      pois: pois,
      selectedPoiIds: selectedPoiIds,
      snapshot: snapshot,
      dragOffsets: dragOffsets,
    );
    return SizedBox(
      width: snapshot.logicalSize.width,
      height: snapshot.logicalSize.height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: Image.memory(snapshot.mapImage, fit: BoxFit.cover),
          ),
          if (snapshot.startPixel != null)
            _EndpointDot(position: snapshot.startPixel!, color: const Color(0xFF2E7D32)),
          if (snapshot.endPixel != null)
            _CheckeredEndpointDot(position: snapshot.endPixel!),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _LeaderLinesPainter(placements)),
            ),
          ),
          for (final p in placements) _PoiDot(position: p.dot),
          for (final p in placements)
            _PoiPill(
              rect: p.rect,
              name: p.name,
              onDragUpdate: (delta) => onDragUpdate(p.id, delta),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StatsOverlay(
              name: track.name.isNotEmpty ? track.name : 'Senza nome',
              metrics: metrics,
              hikingTime: hikingTime,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndpointDot extends StatelessWidget {
  const _EndpointDot({required this.position, required this.color});
  final Offset position;
  final Color color;
  static const double _size = 10;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - _size / 2,
      top: position.dy - _size / 2,
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

/// Bandiera a scacchi per il punto di arrivo — stesso linguaggio visivo del
/// pallino di arrivo sulla mappa principale (`map_gl_screen.dart`), qui
/// disegnato con widget Flutter puri invece di un'icona raster: non serve
/// registrarla in nessuno stile, ed è comunque un cerchietto piccolo.
class _CheckeredEndpointDot extends StatelessWidget {
  const _CheckeredEndpointDot({required this.position});
  final Offset position;
  static const double _size = 10;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - _size / 2,
      top: position.dy - _size / 2,
      child: Container(
        width: _size,
        height: _size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
        ),
        child: ClipOval(
          child: Column(
            children: [
              Expanded(
                child: Row(children: const [
                  Expanded(child: ColoredBox(color: Colors.black)),
                  Expanded(child: ColoredBox(color: Colors.white)),
                ]),
              ),
              Expanded(
                child: Row(children: const [
                  Expanded(child: ColoredBox(color: Colors.white)),
                  Expanded(child: ColoredBox(color: Colors.black)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsOverlay extends StatelessWidget {
  const _StatsOverlay({
    required this.name,
    required this.metrics,
    required this.hikingTime,
  });

  final String name;
  final TrackMetrics? metrics;
  final HikingTimeEstimate? hikingTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xCC000000)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatCell('DISTANZA',
                  metrics != null ? Format.distance(metrics!.distanceMeters) : '—'),
              const SizedBox(width: 24),
              _StatCell('TEMPO',
                  hikingTime != null ? Format.duration(hikingTime!.total) : '—'),
            ],
          ),
          const SizedBox(height: 6),
          _StatCell(
            'DISLIVELLO',
            metrics != null
                ? '↑ ${Format.meters(metrics!.elevation.gain)}   ↓ ${Format.meters(metrics!.elevation.loss)}'
                : '—',
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xB3FFFFFF), fontSize: 9, fontWeight: FontWeight.w600)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _PoiChecklist extends StatelessWidget {
  const _PoiChecklist({
    required this.pois,
    required this.selectedPoiIds,
    required this.onToggle,
  });

  final List<PoiCandidate> pois;
  final Set<String> selectedPoiIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PUNTI SUL PERCORSO',
                      style: AppText.captionSmall.copyWith(
                          color: palette.secondaryLabel,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text('Scegli quali mostrare · trascina un\'etichetta '
                      'sull\'immagine per spostarla',
                      style: AppText.footnote
                          .copyWith(color: palette.secondaryLabel)),
                ],
              ),
            ),
            Text('${selectedPoiIds.length}/${pois.length}',
                style: AppText.value.copyWith(color: palette.accent)),
          ],
        ),
        const SizedBox(height: 8),
        for (final poi in pois)
          _PoiRow(
            poi: poi,
            selected: selectedPoiIds.contains(poi.id),
            onTap: () => onToggle(poi.id),
          ),
      ],
    );
  }
}

class _PoiRow extends StatelessWidget {
  const _PoiRow({required this.poi, required this.selected, required this.onTap});

  final PoiCandidate poi;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (poi.category) {
        PoiCategory.rifugio => CupertinoIcons.house_fill,
        PoiCategory.alpe => CupertinoIcons.tree,
        PoiCategory.lago => CupertinoIcons.drop_fill,
        PoiCategory.colle => CupertinoIcons.arrow_up_right,
        PoiCategory.cima => CupertinoIcons.triangle_fill,
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: CupertinoButton(
        padding: const EdgeInsets.all(10),
        minimumSize: const Size.fromHeight(0),
        borderRadius: BorderRadius.circular(12),
        color: palette.glassFill,
        onPressed: onTap,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(_icon, size: 17, color: palette.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(poi.name,
                      style: AppText.value.copyWith(color: palette.label)),
                  Text(
                    '${poi.category.label} · km ${(poi.distanceAlongPathMeters / 1000).toStringAsFixed(1)}',
                    style: AppText.footnote
                        .copyWith(color: palette.secondaryLabel),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: selected ? palette.accent : palette.tertiaryIcon,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
