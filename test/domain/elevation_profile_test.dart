import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/domain/models/elevation_profile.dart';

void main() {
  const distance = Distance();

  group('ElevationProfile.fromSamples', () {
    test('distanze cumulate, min/max e totale', () {
      final pts = [
        const LatLng(45.0, 7.0),
        const LatLng(45.01, 7.0),
        const LatLng(45.02, 7.0),
      ];
      final profile = ElevationProfile.fromSamples(
        points: pts,
        elevations: const [1000, 1200, 1100],
      );

      expect(profile.samples.length, 3);
      expect(profile.samples.first.distanceMeters, 0);
      expect(profile.minElevation, 1000);
      expect(profile.maxElevation, 1200);

      final expectedTotal =
          distance(pts[0], pts[1]) + distance(pts[1], pts[2]);
      expect(profile.totalDistance, closeTo(expectedTotal, 1e-6));
      expect(profile.samples.last.distanceMeters, closeTo(expectedTotal, 1e-6));
    });

    test('salta le quote null ma avanza comunque la distanza', () {
      final pts = [
        const LatLng(45.0, 7.0),
        const LatLng(45.01, 7.0),
        const LatLng(45.02, 7.0),
      ];
      final profile = ElevationProfile.fromSamples(
        points: pts,
        elevations: const [1000, null, 1100],
      );

      expect(profile.samples.length, 2);
      // Il secondo campione valido è al terzo punto: distanza > 0.
      expect(profile.samples.last.distanceMeters, greaterThan(0));
    });

    test('lista vuota => profilo vuoto', () {
      final profile = ElevationProfile.fromSamples(
        points: const [],
        elevations: const [],
      );
      expect(profile.isEmpty, isTrue);
    });
  });
}
