import 'dart:convert';
import 'dart:ui' show Color;

import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/elevation_profile.dart';
import '../../domain/services/elevation_calculator.dart';
import '../../domain/services/track_metrics.dart';
import '../../features/draw_route/route_editor_provider.dart';
import 'app_database.dart';

/// Persiste le tracce su SQLite (drift) convertendo tra [DrawnTrack] di dominio
/// e righe del database (dati strutturati serializzati in JSON).
class TracksRepository {
  TracksRepository(this._db);

  final AppDatabase _db;

  Future<List<DrawnTrack>> loadAll() async {
    final rows = await _db.allTracks();
    return rows.map(_fromRow).toList();
  }

  Future<void> save(DrawnTrack track) async {
    final now = DateTime.now();
    await _db.upsertTrack(TrackRowsCompanion(
      id: Value(track.id),
      name: Value(track.name),
      color: Value(track.color.toARGB32()),
      snapToTrail: Value(track.snapToTrail),
      waypoints: Value(_encodePoints(track.waypoints)),
      routedPath: Value(_encodePoints(track.routedPath)),
      trailRefs: Value(jsonEncode(track.trailRefs)),
      metrics: Value(_encodeMetrics(track.metrics)),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  Future<void> delete(String id) => _db.deleteTrack(id);

  // ---- serializzazione ----------------------------------------------------

  static String _encodePoints(List<LatLng> pts) =>
      jsonEncode([for (final p in pts) [p.latitude, p.longitude]]);

  static List<LatLng> _decodePoints(String json) => [
        for (final p in (jsonDecode(json) as List))
          LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ];

  static String? _encodeMetrics(TrackMetrics? m) {
    if (m == null) return null;
    return jsonEncode({
      'd': m.distanceMeters,
      'g': m.elevation.gain,
      'l': m.elevation.loss,
      'min': m.profile.minElevation,
      'max': m.profile.maxElevation,
      'tot': m.profile.totalDistance,
      's': [
        for (final s in m.profile.samples)
          {
            'd': s.distanceMeters,
            'e': s.elevation,
            'la': s.position.latitude,
            'ln': s.position.longitude,
          }
      ],
    });
  }

  static TrackMetrics? _decodeMetrics(String? json) {
    if (json == null) return null;
    final m = jsonDecode(json) as Map<String, dynamic>;
    final samples = [
      for (final s in (m['s'] as List))
        ProfileSample(
          distanceMeters: (s['d'] as num).toDouble(),
          elevation: (s['e'] as num).toDouble(),
          position: LatLng((s['la'] as num).toDouble(), (s['ln'] as num).toDouble()),
        ),
    ];
    return TrackMetrics(
      distanceMeters: (m['d'] as num).toDouble(),
      elevation: ElevationGainLoss(
        gain: (m['g'] as num).toDouble(),
        loss: (m['l'] as num).toDouble(),
      ),
      profile: ElevationProfile(
        samples: samples,
        minElevation: (m['min'] as num).toDouble(),
        maxElevation: (m['max'] as num).toDouble(),
        totalDistance: (m['tot'] as num).toDouble(),
      ),
    );
  }

  static DrawnTrack _fromRow(TrackRow r) => DrawnTrack(
        id: r.id,
        name: r.name,
        color: Color(r.color),
        snapToTrail: r.snapToTrail,
        waypoints: _decodePoints(r.waypoints),
        routedPath: _decodePoints(r.routedPath),
        trailRefs: (jsonDecode(r.trailRefs) as List).cast<String>(),
        metrics: _decodeMetrics(r.metrics),
      );
}
