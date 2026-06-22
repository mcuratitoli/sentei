import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/domain/models/elevation_profile.dart';
import 'package:sentei/domain/services/steepness.dart';

ElevationProfile _profile(List<(double dist, double ele)> pts) => ElevationProfile(
      samples: [
        for (final p in pts)
          ProfileSample(
            distanceMeters: p.$1,
            elevation: p.$2,
            position: const LatLng(45, 8),
          ),
      ],
      totalDistance: pts.last.$1,
      minElevation: pts.map((e) => e.$2).reduce((a, b) => a < b ? a : b),
      maxElevation: pts.map((e) => e.$2).reduce((a, b) => a > b ? a : b),
    );

void main() {
  group('steepnessColor', () {
    test('pianura e ripido danno colori diversi', () {
      final flat = steepnessColor(0);
      final steep = steepnessColor(kSteepnessMaxPercent);
      expect(flat, isNot(steep));
    });

    test('il segno della pendenza non conta (salita == discesa)', () {
      expect(steepnessColor(20), steepnessColor(-20));
    });
  });

  group('steepnessGradientStops', () {
    test('profilo vuoto o con un punto → nessuno stop', () {
      expect(steepnessGradientStops(_profile([(0, 100)])), isEmpty);
    });

    test('frazioni: prima 0, ultima 1, strettamente crescenti', () {
      final stops = steepnessGradientStops(_profile([
        (0, 100),
        (50, 110),
        (100, 105),
        (200, 200),
      ]));
      expect(stops.length, 4);
      expect(stops.first.t, 0.0);
      expect(stops.last.t, 1.0);
      for (var i = 1; i < stops.length; i++) {
        expect(stops[i].t, greaterThan(stops[i - 1].t));
      }
    });

    test('colori in formato #RRGGBB', () {
      final stops = steepnessGradientStops(_profile([(0, 0), (100, 50)]));
      for (final s in stops) {
        expect(s.colorHex, matches(RegExp(r'^#[0-9a-fA-F]{6}$')));
      }
    });

    test('distanze duplicate non rompono la monotonia', () {
      final stops = steepnessGradientStops(_profile([
        (0, 100),
        (50, 110),
        (50, 120),
        (100, 130),
      ]));
      for (var i = 1; i < stops.length; i++) {
        expect(stops[i].t, greaterThan(stops[i - 1].t));
      }
    });
  });
}
