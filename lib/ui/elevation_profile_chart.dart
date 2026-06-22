import 'package:flutter/material.dart';

import '../domain/models/elevation_profile.dart';
import '../domain/services/steepness.dart';

/// Grafico del profilo altimetrico: area riempita quota vs distanza, con
/// scrubbing — trascinando il dito/cursore si evidenzia un punto e lo si
/// notifica via [onCursor] (per evidenziarlo in mappa). Sotto l'asse X mostra
/// i **numeri dei sentieri** (ref CAI) attraversati in ciascun tratto.
///
/// Widget di presentazione: nessuna dipendenza da Riverpod.
class ElevationProfileChart extends StatelessWidget {
  const ElevationProfileChart({
    super.key,
    required this.profile,
    this.trailSegments = const [],
    this.cursor,
    this.onCursor,
    this.height = 150,
    this.steepness = false,
  });

  final ElevationProfile profile;

  /// Se vero, la linea del profilo è colorata per **pendenza** (gradiente).
  final bool steepness;

  /// Tratti percorsi sui vari sentieri (per le etichette sull'asse X).
  final List<TrailSegment> trailSegments;

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
                trailSegments: trailSegments,
                color: scheme.primary,
                cursorColor: scheme.error,
                bandColor: scheme.secondaryContainer,
                bandTextColor: scheme.onSecondaryContainer,
                cursor: cursor,
                steepness: steepness,
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
    required this.trailSegments,
    required this.color,
    required this.cursorColor,
    required this.bandColor,
    required this.bandTextColor,
    this.cursor,
    this.steepness = false,
  });

  final ElevationProfile profile;
  final List<TrailSegment> trailSegments;
  final Color color;
  final Color cursorColor;
  final Color bandColor;
  final Color bandTextColor;
  final ProfileSample? cursor;
  final bool steepness;

  static const double _bandHeight = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final samples = profile.samples;
    if (samples.length < 2 || profile.totalDistance <= 0) return;

    final hasBands = trailSegments.isNotEmpty;
    final chartH = size.height - (hasBands ? _bandHeight : 0);

    final eleRange = (profile.maxElevation - profile.minElevation).abs();
    final span = eleRange < 1 ? 1.0 : eleRange;

    double dxFor(double distance) =>
        distance / profile.totalDistance * size.width;
    double dyFor(double elevation) =>
        chartH - (elevation - profile.minElevation) / span * chartH;

    final line = Path()
      ..moveTo(dxFor(samples.first.distanceMeters),
          dyFor(samples.first.elevation));
    for (final s in samples.skip(1)) {
      line.lineTo(dxFor(s.distanceMeters), dyFor(s.elevation));
    }

    final area = Path.from(line)
      ..lineTo(size.width, chartH)
      ..lineTo(0, chartH)
      ..close();

    final stops =
        steepness ? steepnessGradientStops(profile) : const <SteepnessStop>[];
    if (stops.length >= 2) {
      // Stesso gradiente continuo della mappa: shader orizzontale lungo la
      // distanza. Riempimento sotto la curva (semitrasparente) + linea piena.
      final rect = Rect.fromLTWH(0, 0, size.width, chartH);
      final positions = [for (final s in stops) s.t];
      final colors = [for (final s in stops) s.color];
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            colors: [for (final c in colors) c.withValues(alpha: 0.38)],
            stops: positions,
          ).createShader(rect),
      );
      canvas.drawPath(
        line,
        Paint()
          ..shader = LinearGradient(colors: colors, stops: positions)
              .createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    } else {
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Banda dei numeri sentiero sotto l'asse X.
    if (hasBands) {
      final top = chartH + 1;
      for (final seg in trailSegments) {
        final x0 = dxFor(seg.fromMeters);
        final x1 = dxFor(seg.toMeters);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(x0 + 1, top, x1 - 1, size.height),
          const Radius.circular(4),
        );
        canvas.drawRRect(rect, Paint()..color = bandColor);
        // Etichetta ref se c'è spazio.
        final tp = TextPainter(
          text: TextSpan(
            text: seg.ref,
            style: TextStyle(
                color: bandTextColor,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        if (tp.width <= (x1 - x0) - 4) {
          tp.paint(
            canvas,
            Offset((x0 + x1) / 2 - tp.width / 2,
                top + (_bandHeight - tp.height) / 2),
          );
        }
      }
    }

    final c = cursor;
    if (c != null) {
      final x = dxFor(c.distanceMeters);
      final y = dyFor(c.elevation);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, chartH),
        Paint()
          ..color = cursorColor.withValues(alpha: 0.6)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = cursorColor);
    }
  }

  @override
  bool shouldRepaint(_ProfilePainter old) =>
      old.profile != profile ||
      old.color != color ||
      old.cursor != cursor ||
      old.steepness != steepness ||
      old.trailSegments != trailSegments;
}
