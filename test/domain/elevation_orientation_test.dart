import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/domain/models/elevation_profile.dart';
import 'package:sentei/domain/services/elevation_orientation.dart';

ProfileSample _sample(double lat, double lon, double elevation, double d) =>
    ProfileSample(distanceMeters: d, elevation: elevation, position: LatLng(lat, lon));

void main() {
  test('profilo vuoto => null', () {
    const profile = ElevationProfile(
        samples: [], minElevation: 0, maxElevation: 0, totalDistance: 0);
    expect(elevationOrientationBearing(profile), isNull);
  });

  test('punto più basso e più alto coincidenti => null (nessuna direzione)', () {
    final profile = ElevationProfile(
      samples: [_sample(45.0, 7.0, 1000, 0), _sample(45.0, 7.0, 1000, 10)],
      minElevation: 1000,
      maxElevation: 1000,
      totalDistance: 10,
    );
    expect(elevationOrientationBearing(profile), isNull);
  });

  test('punto più alto esattamente a nord del più basso => bearing ~0', () {
    final profile = ElevationProfile(
      samples: [
        _sample(45.0, 7.0, 1000, 0), // più basso
        _sample(45.01, 7.0, 1500, 100), // più alto, a nord
      ],
      minElevation: 1000,
      maxElevation: 1500,
      totalDistance: 100,
    );
    expect(elevationOrientationBearing(profile), closeTo(0, 0.5));
  });

  test('punto più alto esattamente a est del più basso => bearing ~90', () {
    final profile = ElevationProfile(
      samples: [
        _sample(45.0, 7.0, 1000, 0), // più basso
        _sample(45.0, 7.02, 1500, 100), // più alto, a est
      ],
      minElevation: 1000,
      maxElevation: 1500,
      totalDistance: 100,
    );
    expect(elevationOrientationBearing(profile), closeTo(90, 1));
  });

  test('il punto più basso/alto è cercato su tutto il profilo, non solo agli estremi', () {
    final profile = ElevationProfile(
      samples: [
        _sample(45.0, 7.0, 1200, 0),
        _sample(45.0, 7.01, 900, 50), // più basso, in mezzo
        _sample(45.01, 7.01, 1800, 100), // più alto, in mezzo
        _sample(45.0, 7.02, 1300, 150),
      ],
      minElevation: 900,
      maxElevation: 1800,
      totalDistance: 150,
    );
    // Dal punto (45.0, 7.01) al punto (45.01, 7.01): stessa longitudine,
    // latitudine maggiore => a nord => bearing ~0.
    expect(elevationOrientationBearing(profile), closeTo(0, 0.5));
  });
}
