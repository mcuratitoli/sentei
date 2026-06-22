import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/data/storage/track_codec.dart';
import 'package:sentei/domain/models/elevation_profile.dart';
import 'package:sentei/domain/services/elevation_calculator.dart';
import 'package:sentei/domain/services/track_metrics.dart';
import 'package:sentei/features/draw_route/route_editor_provider.dart';

void main() {
  final metrics = TrackMetrics(
    distanceMeters: 1234.5,
    elevation: const ElevationGainLoss(gain: 300, loss: 280),
    profile: ElevationProfile(
      samples: const [
        ProfileSample(distanceMeters: 0, elevation: 1000, position: LatLng(45.1, 7.9)),
        ProfileSample(distanceMeters: 100, elevation: 1050, position: LatLng(45.2, 8.0)),
      ],
      minElevation: 1000,
      maxElevation: 1050,
      totalDistance: 1234.5,
    ),
    trailSegments: const [TrailSegment(fromMeters: 0, toMeters: 100, ref: '203')],
  );

  final track = DrawnTrack(
    id: 't7',
    name: 'Colle del Nivolet',
    color: const Color(0xFFE53935),
    snapToTrail: false,
    waypoints: const [LatLng(45.1, 7.9), LatLng(45.2, 8.0)],
    routedPath: const [LatLng(45.1, 7.9), LatLng(45.15, 7.95), LatLng(45.2, 8.0)],
    trailRefs: const ['203', 'GTA'],
    metrics: metrics,
    createdAt: DateTime.utc(2026, 6, 1, 10, 30),
  );

  test('round-trip completo di DrawnTrack via TrackCodec', () {
    final updatedAt = DateTime.utc(2026, 6, 20, 8, 0);
    final json = TrackCodec.toJson(track, updatedAt: updatedAt);
    final back = TrackCodec.fromJson(json);

    expect(back.id, track.id);
    expect(back.name, track.name);
    expect(back.color.toARGB32(), track.color.toARGB32());
    expect(back.snapToTrail, track.snapToTrail);
    expect(back.waypoints, track.waypoints);
    expect(back.routedPath, track.routedPath);
    expect(back.trailRefs, track.trailRefs);
    expect(back.createdAt, track.createdAt);
    expect(TrackCodec.updatedAtOf(json), updatedAt);

    final m = back.metrics!;
    expect(m.distanceMeters, metrics.distanceMeters);
    expect(m.elevation.gain, metrics.elevation.gain);
    expect(m.elevation.loss, metrics.elevation.loss);
    expect(m.profile.samples.length, 2);
    expect(m.profile.samples.last.elevation, 1050);
    expect(m.trailSegments.single.ref, '203');
  });

  test('fromJson tollera campi assenti (valori di default)', () {
    final back = TrackCodec.fromJson({'id': 'x'});
    expect(back.id, 'x');
    expect(back.name, '');
    expect(back.snapToTrail, true);
    expect(back.waypoints, isEmpty);
    expect(back.routedPath, isEmpty);
    expect(back.trailRefs, isEmpty);
    expect(back.metrics, isNull);
    expect(back.createdAt, isNull);
  });
}
