import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/domain/services/elevation_service.dart';
import 'package:sentei/domain/services/track_metrics.dart';

/// Quota deterministica: cresce linearmente con la longitudine.
/// A 7.0 -> 0 m, a 7.02 -> 2000 m (salita monotona).
class _RampElevation implements ElevationService {
  @override
  Future<double?> elevationAt(LatLng p) async => (p.longitude - 7.0) * 100000;

  @override
  Future<List<double?>> elevationsAlong(List<LatLng> points) async =>
      [for (final p in points) await elevationAt(p)];
}

void main() {
  test('compute: distanza, D+ monotono, profilo popolato', () async {
    const calc = TrackMetricsCalculator();
    final points = [const LatLng(45.0, 7.0), const LatLng(45.0, 7.02)];

    final m = await calc.compute(points, _RampElevation());

    expect(m.distanceMeters, greaterThan(0));
    // Salita monotona ~2000 m, nessuna discesa.
    expect(m.elevation.loss, 0);
    expect(m.elevation.gain, greaterThan(1900));
    expect(m.elevation.gain, lessThanOrEqualTo(2001));
    expect(m.profile.isEmpty, isFalse);
    expect(m.profile.maxElevation, greaterThan(m.profile.minElevation));
  });

  test('meno di 2 punti => metriche vuote', () async {
    const calc = TrackMetricsCalculator();
    final m = await calc.compute(const [LatLng(45, 7)], _RampElevation());
    expect(m.distanceMeters, 0);
    expect(m.profile.isEmpty, isTrue);
  });
}
