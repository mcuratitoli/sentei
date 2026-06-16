import 'package:latlong2/latlong.dart';

import '../models/elevation_profile.dart';
import 'elevation_calculator.dart';
import 'elevation_service.dart';
import 'path_geometry.dart';

/// Metriche complete di un tracciato.
class TrackMetrics {
  const TrackMetrics({
    required this.distanceMeters,
    required this.elevation,
    required this.profile,
  });

  final double distanceMeters;
  final ElevationGainLoss elevation;
  final ElevationProfile profile;

  static const empty = TrackMetrics(
    distanceMeters: 0,
    elevation: ElevationGainLoss(gain: 0, loss: 0),
    profile: ElevationProfile(
      samples: [],
      minElevation: 0,
      maxElevation: 0,
      totalDistance: 0,
    ),
  );
}

/// Orchestra il calcolo delle metriche di un tracciato (§6.3):
/// densifica il path → campiona le quote (DEM) → distanza, D+/D-, profilo.
///
/// La sorgente quote è iniettata via [ElevationService], così la logica resta
/// indipendente da rete/cache e testabile con un servizio finto.
class TrackMetricsCalculator {
  const TrackMetricsCalculator({
    this.geometry = const PathGeometry(),
    this.elevation = const ElevationCalculator(),
    this.stepMeters = 15,
  });

  final PathGeometry geometry;
  final ElevationCalculator elevation;
  final double stepMeters;

  Future<TrackMetrics> compute(
    List<LatLng> points,
    ElevationService elevationService,
  ) async {
    if (points.length < 2) return TrackMetrics.empty;

    final dense = geometry.densify(points, stepMeters: stepMeters);
    final elevations = await elevationService.elevationsAlong(dense);

    return TrackMetrics(
      distanceMeters: geometry.totalDistance(dense),
      elevation: elevation.compute(elevations),
      profile: ElevationProfile.fromSamples(
        points: dense,
        elevations: elevations,
      ),
    );
  }
}
