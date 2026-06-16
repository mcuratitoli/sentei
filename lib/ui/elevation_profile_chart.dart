import 'package:flutter/material.dart';

import '../domain/models/elevation_profile.dart';

/// Grafico del profilo altimetrico: area riempita quota vs distanza, con
/// scrubbing — trascinando il dito/cursore si evidenzia un punto e lo si
/// notifica via [onCursor] (per evidenziarlo in mappa).
///
/// Widget di presentazione: nessuna dipendenza da Riverpod.
class ElevationProfileChart extends StatelessWidget {
  const ElevationProfileChart({
    super.key,
    required this.profile,
    this.cursor,
    this.onCursor,
    this.height = 140,
  });

  final ElevationProfile profile;

  /// Campione attualmente evidenziato (disegnato con linea + pallino).
  final ProfileSample? cursor;

  /// Notifica il campione sotto il dito durante lo scrubbing (`null` a fine).
  final ValueChanged<ProfileSample?>? onCursor;

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (profile.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('Profilo non disponibile')),
      );
    }

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          void report(double dx) {
            if (onCursor == null || profile.totalDistance <= 0) return;
            final frac = (dx / width).clamp(0.0, 1.0);
            final target = frac * profile.totalDistance;
            onCursor!(_nearestByDistance(profile.samples, target));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => report(d.localPosition.dx),
            onHorizontalDragStart: (d) => report(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => report(d.localPosition.dx),
            onHorizontalDragEnd: (_) => onCursor?.call(null),
            onTapUp: (_) => onCursor?.call(null),
            child: CustomPaint(
              painter: _ProfilePainter(
                profile: profile,
                color: scheme.primary,
                cursor: cursor,
                cursorColor: scheme.error,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }

  static ProfileSample _nearestByDistance(
      List<ProfileSample> samples, double target) {
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
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter({
    required this.profile,
    required this.color,
    required this.cursorColor,
    this.cursor,
  });

  final ElevationProfile profile;
  final Color color;
  final Color cursorColor;
  final ProfileSample? cursor;

  @override
  void paint(Canvas canvas, Size size) {
    final samples = profile.samples;
    if (samples.length < 2 || profile.totalDistance <= 0) return;

    final eleRange = (profile.maxElevation - profile.minElevation).abs();
    final span = eleRange < 1 ? 1.0 : eleRange; // evita divisione per ~0

    double dxFor(double distance) =>
        distance / profile.totalDistance * size.width;
    double dyFor(double elevation) =>
        size.height - (elevation - profile.minElevation) / span * size.height;

    final line = Path()
      ..moveTo(dxFor(samples.first.distanceMeters),
          dyFor(samples.first.elevation));
    for (final s in samples.skip(1)) {
      line.lineTo(dxFor(s.distanceMeters), dyFor(s.elevation));
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final c = cursor;
    if (c != null) {
      final x = dxFor(c.distanceMeters);
      final y = dyFor(c.elevation);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = cursorColor.withValues(alpha: 0.6)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = cursorColor);
    }
  }

  @override
  bool shouldRepaint(_ProfilePainter old) =>
      old.profile != profile || old.color != color || old.cursor != cursor;
}
