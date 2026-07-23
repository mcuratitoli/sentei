import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/domain/models/photo_candidate.dart';
import 'package:sentei/domain/services/nearby_photos_matcher.dart';

void main() {
  const matcher = NearbyPhotosMatcher();

  final path = [
    const LatLng(45.0, 7.0),
    const LatLng(45.0, 7.01),
    const LatLng(45.0, 7.02),
  ];

  test('percorso vuoto o con un solo punto → nessun match', () {
    final photo = RawPhotoLocation(id: 'a', position: const LatLng(45.0, 7.0));
    expect(matcher.match(routedPath: const [], photos: [photo]), isEmpty);
    expect(
      matcher.match(routedPath: const [LatLng(45.0, 7.0)], photos: [photo]),
      isEmpty,
    );
  });

  test('nessuna foto → nessun match', () {
    expect(matcher.match(routedPath: path, photos: const []), isEmpty);
  });

  test('foto entro soglia viene inclusa con la distanza-lungo-percorso', () {
    // Praticamente sul secondo vertice del percorso.
    final photo = RawPhotoLocation(
      id: 'near',
      position: const LatLng(45.0001, 7.01),
      takenAt: DateTime(2026, 7, 20),
    );
    final result = matcher.match(routedPath: path, photos: [photo]);
    expect(result, hasLength(1));
    expect(result.single.id, 'near');
    expect(result.single.takenAt, DateTime(2026, 7, 20));
    expect(result.single.distanceToPathMeters, lessThan(80));
    const distance = Distance();
    final expectedAlong = distance(path[0], path[1]);
    expect(result.single.distanceAlongPathMeters,
        closeTo(expectedAlong, 5));
  });

  test('foto oltre la soglia viene scartata', () {
    final photo = RawPhotoLocation(
      id: 'far',
      // ~1.5 km dal percorso.
      position: const LatLng(45.015, 7.01),
    );
    expect(matcher.match(routedPath: path, photos: [photo]), isEmpty);
  });

  test('soglia personalizzata', () {
    final photo = RawPhotoLocation(id: 'mid', position: const LatLng(45.0007, 7.01));
    expect(
      matcher.match(routedPath: path, photos: [photo], thresholdMeters: 50),
      isEmpty,
    );
    expect(
      matcher.match(routedPath: path, photos: [photo], thresholdMeters: 100),
      hasLength(1),
    );
  });

  test('risultati ordinati per distanza crescente', () {
    final near = RawPhotoLocation(id: 'near', position: const LatLng(45.0002, 7.0));
    final far = RawPhotoLocation(id: 'far', position: const LatLng(45.0006, 7.01));
    final result = matcher.match(routedPath: path, photos: [far, near]);
    expect(result.map((c) => c.id).toList(), ['near', 'far']);
  });
}
