import 'dart:ui' show Color;

import 'package:latlong2/latlong.dart';

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

/// Un tratto di traccia con il colore di ripidezza (gradiente) del suo edge.
class SteepnessSegment {
  const SteepnessSegment(this.points, this.colorHex);
  final List<LatLng> points;
  final String colorHex; // "#RRGGBB"
}

/// Un segmento (2 punti) per ogni edge del profilo, colorato col gradiente.
List<SteepnessSegment> steepnessSegments(ElevationProfile profile) {
  final s = profile.samples;
  if (s.length < 2) return const [];
  final out = <SteepnessSegment>[];
  for (var i = 0; i < s.length - 1; i++) {
    final color = steepnessColor(slopePercentBetween(s[i], s[i + 1]));
    out.add(SteepnessSegment(
      <LatLng>[s[i].position, s[i + 1].position],
      _hex(color),
    ));
  }
  return out;
}
