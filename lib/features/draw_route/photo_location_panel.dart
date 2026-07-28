import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/models/elevation_profile.dart';
import '../../domain/models/track_photo.dart';
import '../../domain/services/track_metrics.dart';
import '../../ui/elevation_profile_chart.dart';
import '../../ui/tokens.dart';
import 'route_editor_provider.dart';

/// Pannello sotto il filmstrip del visualizzatore foto a schermo intero
/// (§"Sync album fotografico"): un tasto — chevron coerente con gli altri
/// espandi/riduci dell'app (`AppSheetHeader`, sezione FOTO della card) —
/// mostra/nasconde il profilo altimetrico della traccia col punto di scatto
/// della foto evidenziato.
class PhotoLocationPanel extends ConsumerStatefulWidget {
  const PhotoLocationPanel({super.key, required this.photo});

  final TrackPhoto photo;

  @override
  ConsumerState<PhotoLocationPanel> createState() =>
      _PhotoLocationPanelState();
}

class _PhotoLocationPanelState extends ConsumerState<PhotoLocationPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final metrics =
        ref.watch(tracksProvider.select((s) => s.active?.metrics));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(CupertinoIcons.graph_square,
                    size: 16, color: Color(0xFFFFFFFF)),
                const SizedBox(width: 6),
                const Text(
                  'Altitudine',
                  style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Stessa convenzione dell'app: chevron_down quando espanso
                // (tocca per ridurre), chevron_up quando ridotto.
                Icon(
                  _expanded
                      ? CupertinoIcons.chevron_down
                      : CupertinoIcons.chevron_up,
                  size: 16,
                  color: const Color(0xFFFFFFFF),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 6),
          _PhotoElevationView(photo: widget.photo, metrics: metrics),
        ],
      ],
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Profilo non disponibile',
            style: TextStyle(color: Color(0xB3FFFFFF)),
          ),
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
