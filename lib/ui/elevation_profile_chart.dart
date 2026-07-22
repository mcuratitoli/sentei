import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/models/elevation_profile.dart';
import '../domain/services/steepness.dart';
import 'cai_difficulty.dart';
import 'tokens.dart';

/// Grafico del profilo altimetrico: area riempita quota vs distanza, con
/// scrubbing — trascinando il dito/cursore si evidenzia un punto e lo si
/// notifica via [onCursor] (per evidenziarlo in mappa). Sotto l'asse X mostra
/// i **numeri dei sentieri** (ref CAI) attraversati in ciascun tratto.
///
/// Widget di presentazione: nessuna dipendenza da Riverpod.
class ElevationProfileChart extends StatefulWidget {
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
  State<ElevationProfileChart> createState() => _ElevationProfileChartState();
}

class _ElevationProfileChartState extends State<ElevationProfileChart> {
  OverlayEntry? _tip;
  Timer? _tipTimer;

  @override
  void dispose() {
    _removeTip();
    super.dispose();
  }

  void _removeTip() {
    _tipTimer?.cancel();
    _tipTimer = null;
    _tip?.remove();
    _tip = null;
  }

  /// Grado CAI del tratto sotto [local] se il tap cade nella **banda difficoltà**
  /// (striscia inferiore del grafico); altrimenti `null` (→ scrubbing normale).
  String? _difficultyAt(Offset local, double width, double totalHeight) {
    final total = widget.profile.totalDistance;
    if (total <= 0) return null;
    if (local.dy < totalHeight - _ProfilePainter.scaleBandHeight) return null;
    for (final s in widget.trailSegments) {
      final scale = s.caiScale;
      if (scale == null) continue;
      final x0 = s.fromMeters / total * width;
      final x1 = s.toMeters / total * width;
      if (local.dx >= x0 && local.dx <= x1) return scale;
    }
    return null;
  }

  /// Mostra un tooltip che spiega il grado CAI (es. "EE — Escursionisti
  /// Esperti"), ancorato al punto toccato; si chiude al tap o dopo 3s.
  void _showTip(Offset globalPos, String scale) {
    _removeTip();
    final overlay = Overlay.of(context);
    final text = '$scale — ${caiScaleLabel(scale)}';
    _tip = OverlayEntry(
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeTip,
              ),
            ),
            Positioned(
              left: (globalPos.dx - 110).clamp(8.0, size.width - 228),
              top: (globalPos.dy - 54).clamp(8.0, size.height - 60),
              child: _DifficultyTip(text: text),
            ),
          ],
        );
      },
    );
    overlay.insert(_tip!);
    _tipTimer = Timer(const Duration(seconds: 3), _removeTip);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.profile.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('Profilo non disponibile')),
      );
    }

    // La banda del grado CAI si aggiunge in altezza (non comprime il grafico):
    // l'area "profilo + banda segnavia" resta `height`, la scale sta sotto.
    final hasScale = widget.trailSegments.any((s) => s.caiScale != null);
    final totalHeight =
        widget.height + (hasScale ? _ProfilePainter.scaleBandHeight : 0);

    return SizedBox(
      height: totalHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          void report(double dx) {
            if (widget.onCursor == null || widget.profile.totalDistance <= 0) {
              return;
            }
            final frac = (dx / width).clamp(0.0, 1.0);
            final target = frac * widget.profile.totalDistance;
            widget.onCursor!(_nearestByDistance(widget.profile.samples, target));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final scale =
                  _difficultyAt(d.localPosition, width, totalHeight);
              if (scale != null) {
                _showTip(d.globalPosition, scale);
                return; // tap sulla banda difficoltà → tooltip, non scrubbing
              }
              report(d.localPosition.dx);
            },
            onHorizontalDragStart: (d) => report(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => report(d.localPosition.dx),
            onHorizontalDragEnd: (_) => widget.onCursor?.call(null),
            onTapUp: (_) => widget.onCursor?.call(null),
            child: CustomPaint(
              painter: _ProfilePainter(
                profile: widget.profile,
                trailSegments: widget.trailSegments,
                color: scheme.primary,
                cursorColor: scheme.error,
                bandColor: scheme.secondaryContainer,
                bandTextColor: scheme.onSecondaryContainer,
                cursor: widget.cursor,
                steepness: widget.steepness,
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

/// Bolla-tooltip scura (stile iOS) con la spiegazione del grado di difficoltà.
class _DifficultyTip extends StatelessWidget {
  const _DifficultyTip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.overlayDark,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0x40000000),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: AppText.captionEmphasis.copyWith(color: const Color(0xFFFFFFFF)),
        ),
      ),
    );
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
  static const double scaleBandHeight = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final samples = profile.samples;
    if (samples.length < 2 || profile.totalDistance <= 0) return;

    final hasBands = trailSegments.isNotEmpty;
    final hasScale = trailSegments.any((s) => s.caiScale != null);
    final bandsH =
        (hasBands ? _bandHeight : 0) + (hasScale ? scaleBandHeight : 0);
    final chartH = size.height - bandsH;

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

    // Banda dei numeri sentiero (ref CAI) sotto l'asse X.
    if (hasBands) {
      final top = chartH + 1;
      final bottom = chartH + _bandHeight;
      for (final seg in trailSegments) {
        final x0 = dxFor(seg.fromMeters);
        final x1 = dxFor(seg.toMeters);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(x0 + 1, top, x1 - 1, bottom),
          const Radius.circular(4),
        );
        canvas.drawRRect(rect, Paint()..color = bandColor);
        _bandLabel(canvas, seg.ref, bandTextColor, x0, x1, top, _bandHeight);
      }
    }

    // Banda del grado di difficoltà CAI (T/E/EE/EEA), colorata per difficoltà,
    // allineata ai tratti dei numeri sentiero. Solo i tratti con scale nota.
    if (hasScale) {
      final top = chartH + _bandHeight + 1;
      for (final seg in trailSegments) {
        final scale = seg.caiScale;
        if (scale == null) continue;
        final x0 = dxFor(seg.fromMeters);
        final x1 = dxFor(seg.toMeters);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(x0 + 1, top, x1 - 1, size.height),
          const Radius.circular(4),
        );
        canvas.drawRRect(rect, Paint()..color = caiScaleColor(scale));
        _bandLabel(
            canvas, scale, const Color(0xFFFFFFFF), x0, x1, top, scaleBandHeight);
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

  /// Disegna [text] centrato nel tratto [x0]..[x1] della banda, se c'è spazio.
  void _bandLabel(Canvas canvas, String text, Color color, double x0,
      double x1, double top, double bandH) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: AppText.chartLabel.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (tp.width <= (x1 - x0) - 4) {
      tp.paint(
        canvas,
        Offset((x0 + x1) / 2 - tp.width / 2, top + (bandH - tp.height) / 2),
      );
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
