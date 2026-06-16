import 'package:flutter/material.dart';

import '../domain/models/elevation_profile.dart';

/// Grafico del profilo altimetrico: area riempita quota vs distanza.
///
/// Widget di presentazione puro: riceve un [ElevationProfile] già calcolato
/// (vedi `ElevationProfile.fromSamples`).
class ElevationProfileChart extends StatelessWidget {
  const ElevationProfileChart({
    super.key,
    required this.profile,
    this.height = 140,
  });

  final ElevationProfile profile;
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
      child: CustomPaint(
        painter: _ProfilePainter(profile: profile, color: scheme.primary),
        size: Size.infinite,
      ),
    );
  }
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter({required this.profile, required this.color});

  final ElevationProfile profile;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final samples = profile.samples;
    if (samples.length < 2 || profile.totalDistance <= 0) return;

    final eleRange = (profile.maxElevation - profile.minElevation).abs();
    final span = eleRange < 1 ? 1.0 : eleRange; // evita divisione per ~0

    Offset toOffset(ProfileSample s) {
      final dx = s.distanceMeters / profile.totalDistance * size.width;
      final norm = (s.elevation - profile.minElevation) / span;
      final dy = size.height - norm * size.height;
      return Offset(dx, dy);
    }

    final line = Path()..moveTo(toOffset(samples.first).dx, toOffset(samples.first).dy);
    for (final s in samples.skip(1)) {
      final o = toOffset(s);
      line.lineTo(o.dx, o.dy);
    }

    // Area riempita sotto la linea.
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
  }

  @override
  bool shouldRepaint(_ProfilePainter oldDelegate) =>
      oldDelegate.profile != profile || oldDelegate.color != color;
}
