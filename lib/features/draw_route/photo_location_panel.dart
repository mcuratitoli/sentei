import 'package:flutter/cupertino.dart' show CupertinoButton, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../app/theme.dart';
import '../../domain/models/elevation_profile.dart';
import '../../domain/models/track_photo.dart';
import '../../domain/services/track_metrics.dart';
import '../../ui/elevation_profile_chart.dart';
import '../../ui/tokens.dart';
import '../map_gl/map_style.dart';
import 'route_editor_provider.dart';

enum _LocationTab { elevation, map }

/// Pannello sotto il filmstrip del visualizzatore foto a schermo intero
/// (§"Sync album fotografico"): selettore a due opzioni (stile Komoot) fra
/// il profilo altimetrico col punto di scatto evidenziato e una mini-mappa
/// con lo stesso punto sul percorso.
///
/// La mini-mappa è **pesante** (un'istanza Mapbox live, rete/GL): costruita
/// solo la prima volta che l'utente tocca "Mappa", non subito all'apertura
/// della foto — ma tenuta viva (non ricostruita) ai toggle successivi
/// (`Offstage`, non uno switch condizionale) per non ripagare il costo del
/// caricamento ad ogni tap.
class PhotoLocationPanel extends ConsumerStatefulWidget {
  const PhotoLocationPanel({super.key, required this.photo});

  final TrackPhoto photo;

  @override
  ConsumerState<PhotoLocationPanel> createState() =>
      _PhotoLocationPanelState();
}

class _PhotoLocationPanelState extends ConsumerState<PhotoLocationPanel> {
  _LocationTab _tab = _LocationTab.elevation;
  bool _mapEverOpened = false;

  @override
  Widget build(BuildContext context) {
    if (_tab == _LocationTab.map) _mapEverOpened = true;
    final track = ref.watch(tracksProvider.select((s) => s.active));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TabSelector(
          value: _tab,
          onChanged: (t) => setState(() => _tab = t),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: Stack(
            children: [
              Positioned.fill(
                child: Offstage(
                  offstage: _tab != _LocationTab.elevation,
                  child: _PhotoElevationView(
                    photo: widget.photo,
                    metrics: track?.metrics,
                  ),
                ),
              ),
              if (_mapEverOpened)
                Positioned.fill(
                  child: Offstage(
                    offstage: _tab != _LocationTab.map,
                    child: _PhotoMapPreview(
                      photo: widget.photo,
                      routedPath: track?.routedPath ?? const [],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabSelector extends StatelessWidget {
  const _TabSelector({required this.value, required this.onChanged});

  final _LocationTab value;
  final ValueChanged<_LocationTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TabButton(
          label: 'Altitudine',
          icon: CupertinoIcons.graph_square,
          selected: value == _LocationTab.elevation,
          onTap: () => onChanged(_LocationTab.elevation),
        ),
        const SizedBox(width: 8),
        _TabButton(
          label: 'Mappa',
          icon: CupertinoIcons.map,
          selected: value == _LocationTab.map,
          onTap: () => onChanged(_LocationTab.map),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const selectedFg = Color(0xFF1C1C1E);
    const unselectedFg = Color(0xFFFFFFFF);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFFFFF)
              : const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? selectedFg : unselectedFg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? selectedFg : unselectedFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profilo altimetrico della traccia con un solo punto evidenziato — quello
/// di scatto di [photo] — riusando [ElevationProfileChart.cursor] (niente
/// pin multipli: quelli sono stati tolti dalla card, troppo confusi con
/// molte foto).
class _PhotoElevationView extends StatelessWidget {
  const _PhotoElevationView({required this.photo, required this.metrics});

  final TrackPhoto photo;
  final TrackMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final profile = metrics?.profile;
    if (profile == null || profile.isEmpty) {
      return const Center(
        child: Text(
          'Profilo non disponibile',
          style: TextStyle(color: Color(0xB3FFFFFF)),
        ),
      );
    }
    final sample = _nearestSample(profile.samples, photo.distanceMeters);
    // Sfondo bianco fisso e tema forzato chiaro: il grafico è pensato per
    // stare su una superficie chiara (testi/bande colorate calibrati per
    // quello), non per essere trasparente sul fondo nero della galleria.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: AppRadii.rMd,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
        child: Theme(
          data: AppTheme.light(),
          child: ElevationProfileChart(
            profile: profile,
            trailSegments: metrics!.trailSegments,
            cursor: sample,
            height: 130,
          ),
        ),
      ),
    );
  }
}

ProfileSample _nearestSample(List<ProfileSample> samples, double target) {
  var best = samples.first;
  var bestDiff = (best.distanceMeters - target).abs();
  for (final s in samples) {
    final diff = (s.distanceMeters - target).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      best = s;
    }
  }
  return best;
}

/// Mini-mappa **sola lettura** (nessun gesto: pan/zoom sono disabilitati per
/// non competere con lo swipe orizzontale del carosello sopra) col percorso
/// e un pin evidenziato nel punto di scatto di [photo]. Istanza Mapbox
/// indipendente da quella della schermata principale — vedi nota di
/// [PhotoLocationPanel] sul perché è creata solo on-demand.
class _PhotoMapPreview extends StatefulWidget {
  const _PhotoMapPreview({required this.photo, required this.routedPath});

  final TrackPhoto photo;
  final List<ll.LatLng> routedPath;

  @override
  State<_PhotoMapPreview> createState() => _PhotoMapPreviewState();
}

class _PhotoMapPreviewState extends State<_PhotoMapPreview> {
  CircleAnnotationManager? _markerManager;
  CircleAnnotation? _marker;

  // Il widget resta montato (vedi nota su `Offstage` in [PhotoLocationPanel]):
  // se l'utente scorre il carosello restando sulla scheda "Mappa", questo
  // stato non viene ricreato da zero — va spostato solo il marker esistente,
  // non riavviata tutta la mappa (route/camera restano identiche, è sempre
  // lo stesso percorso).
  @override
  void didUpdateWidget(covariant _PhotoMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.id != widget.photo.id) _moveMarker();
  }

  Future<void> _moveMarker() async {
    final manager = _markerManager;
    final marker = _marker;
    if (manager == null || marker == null) return;
    marker.geometry = Point(
      coordinates: Position(
          widget.photo.position.longitude, widget.photo.position.latitude),
    );
    await manager.update(marker);
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    await map.compass.updateSettings(const CompassSettings(enabled: false));
    await map.scaleBar.updateSettings(const ScaleBarSettings(enabled: false));
    await map.logo.updateSettings(const LogoSettings(enabled: false));
    await map.attribution
        .updateSettings(const AttributionSettings(enabled: false));
    // Sola visualizzazione: qui non serve interagire, e i gesti
    // competerebbero con lo swipe orizzontale del carosello sopra.
    await map.gestures.updateSettings(GesturesSettings(
      rotateEnabled: false,
      pinchToZoomEnabled: false,
      scrollEnabled: false,
      pitchEnabled: false,
      doubleTapToZoomInEnabled: false,
      doubleTouchToZoomOutEnabled: false,
      quickZoomEnabled: false,
    ));

    final path = widget.routedPath;
    if (path.length >= 2) {
      final lineManager =
          await map.annotations.createPolylineAnnotationManager();
      await lineManager.create(PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: [for (final p in path) Position(p.longitude, p.latitude)],
        ),
        lineColor: 0xFF2F6FED,
        lineWidth: 4,
      ));
      final coords = [
        for (final p in path) Point(coordinates: Position(p.longitude, p.latitude)),
      ];
      final camera = await map.cameraForCoordinatesPadding(
        coords,
        CameraOptions(),
        MbxEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
        null,
        null,
      );
      await map.setCamera(camera);
    } else {
      // Nessun percorso utile: centra almeno sulla foto.
      await map.setCamera(CameraOptions(
        center: Point(
          coordinates: Position(
              widget.photo.position.longitude, widget.photo.position.latitude),
        ),
        zoom: 14,
      ));
    }
    if (!mounted) return;

    final markerManager =
        await map.annotations.createCircleAnnotationManager();
    if (!mounted) return;
    // Riletto qui (non prima degli `await` sopra): se nel frattempo il
    // carosello è scorso ad un'altra foto, il marker nasce già nel punto
    // giusto invece che in quello di quando la mappa ha iniziato a caricare.
    final marker = await markerManager.create(CircleAnnotationOptions(
      geometry: Point(
        coordinates: Position(
            widget.photo.position.longitude, widget.photo.position.latitude),
      ),
      circleRadius: 9,
      circleColor: 0xFFFFB300,
      circleStrokeColor: 0xFFFFFFFF,
      circleStrokeWidth: 3,
    ));
    _markerManager = markerManager;
    _marker = marker;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: AppRadii.rMd,
      child: MapWidget(
        styleUri: dark ? darkMapStyleUri : outdoorsMapStyleUri,
        onMapCreated: _onMapCreated,
      ),
    );
  }
}
