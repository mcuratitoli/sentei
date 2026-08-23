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

    final raw = await OverpassPoiService().fetch(track.routedPath);
    if (!mounted) return;
    final matched = const NearbyPoisMatcher()
        .match(routedPath: track.routedPath, pois: raw);
    setState(() {
      _pois = matched;
      // Tutti selezionati di default: l'utente toglie quelli che non vuole
      // vedere, più semplice che partire da zero e doverli spuntare tutti.
      _selectedPoiIds = matched.map((p) => p.id).toSet();
      _stage = _Stage.capturingMap;
    });
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
        title: const Text('Immagine'),
        centerTitle: true,
        backgroundColor: palette.scaffoldBg,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _buildBody(context),
          // Rig di cattura offscreen: fuori dallo schermo (coordinate
          // negative), rimosso appena `_onSnapshotResult` ha il risultato.
          if (_stage == _Stage.capturingMap && _track != null)
            Positioned(
              left: -6000,
              top: 0,
              child: RouteSnapshotCapture(
                path: _track!.routedPath,
                routeColor: _track!.color,
                pois: _pois,
                size: _kExportSize,
                onResult: _onSnapshotResult,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_stage) {
      case _Stage.loadingPois:
        return const _CenteredProgress(message: 'Rilevo punti di interesse…');
      case _Stage.capturingMap:
        return const _CenteredProgress(message: 'Genero l\'anteprima…');
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
  });

  final DrawnTrack track;
  final HikingTimeEstimate? hikingTime;
  final RouteSnapshotResult snapshot;
  final List<PoiCandidate> pois;
  final Set<String> selectedPoiIds;

  @override
  Widget build(BuildContext context) {
    final metrics = track.metrics;
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
          for (final poi in pois)
            if (selectedPoiIds.contains(poi.id) &&
                snapshot.poiPixels[poi.id] != null)
              _PoiLabel(position: snapshot.poiPixels[poi.id]!, name: poi.name),
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

/// Etichetta di un punto interessante: pallino + lineetta + pillola col
/// nome, come nelle cartine di montagna — dimensioni **fisse** (non in
/// funzione del testo) così l'ancoraggio verticale sopra [position] resta
/// preciso senza dover misurare il layout della pillola.
class _PoiLabel extends StatelessWidget {
  const _PoiLabel({required this.position, required this.name});
  final Offset position;
  final String name;

  static const double _dotSize = 7;
  static const double _lineLength = 12;
  static const double _pillHeight = 20;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy - _dotSize / 2 - _lineLength - _pillHeight,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: _pillHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xE61C1C1E),
                borderRadius: BorderRadius.circular(_pillHeight / 2),
              ),
              alignment: Alignment.center,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(width: 1.5, height: _lineLength, color: Colors.white70),
          ],
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
                  Text('Rilevati lungo la traccia · scegli quali mostrare',
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
        PoiCategory.alpe => CupertinoIcons.house,
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
