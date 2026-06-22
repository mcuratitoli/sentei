import 'dart:ui' show Color;

import 'package:latlong2/latlong.dart';

import '../models/elevation_profile.dart';

/// Intervallo di pendenza (valore assoluto in %) con colore ed etichetta.
class SteepnessBucket {
  const SteepnessBucket(this.maxPercent, this.color, this.label);

  /// Limite superiore (escluso) dell'intervallo.
  final double maxPercent;
  final Color color;
  final String label;
}

/// Scaglioni di pendenza (verde→rosso), pensati per l'escursionismo.
/// **Da validare/tarare** con tracce reali.
const List<SteepnessBucket> kSteepnessBuckets = <SteepnessBucket>[
  SteepnessBucket(7, Color(0xFF1A9850), '0–7% · pianeggiante'),
  SteepnessBucket(15, Color(0xFFA6D96A), '7–15% · dolce'),
  SteepnessBucket(25, Color(0xFFFEE08B), '15–25% · sostenuto'),
  SteepnessBucket(35, Color(0xFFFDAE61), '25–35% · ripido'),
  SteepnessBucket(45, Color(0xFFF46D43), '35–45% · molto ripido'),
  SteepnessBucket(double.infinity, Color(0xFFD73027), '>45% · estremo'),
];

/// Colore per una pendenza (in %, segno ignorato: salita/discesa pari).
Color steepnessColor(double slopePercent) {
  final s = slopePercent.abs();
  for (final b in kSteepnessBuckets) {
    if (s < b.maxPercent) return b.color;
  }
  return kSteepnessBuckets.last.color;
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Un tratto di traccia con un colore di ripidezza uniforme.
class SteepnessSegment {
  const SteepnessSegment(this.points, this.colorHex);
  final List<LatLng> points;
  final String colorHex; // "#RRGGBB"
}

/// Spezza il profilo in tratti colorati per pendenza, unendo i tratti
/// consecutivi con lo stesso colore (per ridurre il numero di geometrie).
List<SteepnessSegment> steepnessSegments(ElevationProfile profile) {
  final s = profile.samples;
  if (s.length < 2) return const [];

  double slopeAt(int j) {
    final dDist = s[j + 1].distanceMeters - s[j].distanceMeters;
    if (dDist <= 0) return 0;
    final dEle = s[j + 1].elevation - s[j].elevation;
    return dEle / dDist * 100.0;
  }

  final out = <SteepnessSegment>[];
  var run = <LatLng>[s[0].position];
  var runColor = _hex(steepnessColor(slopeAt(0)));
  for (var i = 1; i < s.length; i++) {
    final c = _hex(steepnessColor(slopeAt(i - 1)));
    if (c == runColor) {
      run.add(s[i].position);
    } else {
      out.add(SteepnessSegment(run, runColor));
      run = <LatLng>[s[i - 1].position, s[i].position];
      runColor = c;
    }
  }
  out.add(SteepnessSegment(run, runColor));
  return out;
}
