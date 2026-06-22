import 'dart:ui' show Color;

import '../models/elevation_profile.dart';

const Color _green = Color(0xFF1A9850);
const Color _yellow = Color(0xFFFFD54F);
const Color _red = Color(0xFFD73027);

/// Pendenza (%) oltre la quale il colore è rosso pieno. Sotto, gradiente
/// continuo verde→giallo→rosso. Segno ignorato (salita/discesa pari).
const double kSteepnessMaxPercent = 45;

/// Colore **continuo** (gradiente) per una pendenza in %.
Color steepnessColor(double slopePercent) {
  final t = (slopePercent.abs() / kSteepnessMaxPercent).clamp(0.0, 1.0);
  if (t < 0.5) return Color.lerp(_green, _yellow, t / 0.5)!;
  return Color.lerp(_yellow, _red, (t - 0.5) / 0.5)!;
}

/// Pendenza (%) tra due campioni del profilo (Δquota / Δdistanza·100).
double slopePercentBetween(ProfileSample a, ProfileSample b) {
  final dDist = b.distanceMeters - a.distanceMeters;
  if (dDist <= 0) return 0;
  return (b.elevation - a.elevation) / dDist * 100.0;
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Uno **stop** di colore lungo la traccia per un gradiente continuo: frazione
/// `t` (0..1 della distanza cumulata) → colore della pendenza in quel punto.
class SteepnessStop {
  const SteepnessStop(this.t, this.color);
  final double t; // 0..1
  final Color color;

  /// "#RRGGBB" — per le espressioni Mapbox (`line-gradient`).
  String get colorHex => _hex(color);
}

/// Stop per un **gradiente continuo** di ripidezza lungo la traccia, pensati per
/// `line-gradient` di Mapbox (interpolazione su `line-progress`). Il colore di
/// ogni vertice è la pendenza **media degli edge adiacenti** (sui due estremi,
/// l'unico edge presente): così le transizioni sono morbide invece che a
/// gradini. Le frazioni sono strettamente crescenti (richiesto da `interpolate`)
/// e fissate a 0 sul primo punto e 1 sull'ultimo.
List<SteepnessStop> steepnessGradientStops(ElevationProfile profile) {
  final s = profile.samples;
  if (s.length < 2 || profile.totalDistance <= 0) return const [];
  final total = profile.totalDistance;
  final slopes = <double>[
    for (var i = 0; i < s.length - 1; i++) slopePercentBetween(s[i], s[i + 1]),
  ];

  final stops = <SteepnessStop>[];
  var lastT = -1.0;
  for (var i = 0; i < s.length; i++) {
    final double slope;
    if (i == 0) {
      slope = slopes.first;
    } else if (i == s.length - 1) {
      slope = slopes.last;
    } else {
      slope = (slopes[i - 1] + slopes[i]) / 2.0;
    }

    double t;
    if (i == 0) {
      t = 0.0;
    } else if (i == s.length - 1) {
      t = 1.0;
    } else {
      t = (s[i].distanceMeters / total).clamp(0.0, 1.0);
      if (t <= lastT) t = lastT + 1e-6; // strettamente crescente
      if (t >= 1.0) t = 1.0 - 1e-6;
    }
    lastT = t;
    stops.add(SteepnessStop(t, steepnessColor(slope)));
  }
  return stops;
}
