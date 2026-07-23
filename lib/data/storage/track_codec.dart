import 'dart:convert' show base64Decode, base64Encode;
import 'dart:ui' show Color;

import 'package:latlong2/latlong.dart';

import '../../domain/models/elevation_profile.dart';
import '../../domain/models/track_photo.dart';
import '../../domain/services/elevation_calculator.dart';
import '../../domain/services/track_metrics.dart';
import '../../features/draw_route/route_editor_provider.dart';

/// Serializzazione JSON di [DrawnTrack] e delle sue parti, **condivisa** tra la
/// persistenza locale (drift) e la sincronizzazione cloud: una sola fonte di
/// verità per il formato dei dati. Logica pura, senza I/O.
abstract final class TrackCodec {
  // ---- punti --------------------------------------------------------------

  static List<List<double>> pointsToJson(List<LatLng> pts) =>
      [for (final p in pts) [p.latitude, p.longitude]];

  static List<LatLng> pointsFromJson(List<dynamic> json) => [
        for (final p in json)
          LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ];

  // ---- metriche -----------------------------------------------------------

  static Map<String, dynamic>? metricsToJson(TrackMetrics? m) {
    if (m == null) return null;
    return {
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
      'seg': [
        for (final t in m.trailSegments)
          {
            'f': t.fromMeters,
            't': t.toMeters,
            'r': t.ref,
            if (t.caiScale != null) 'sc': t.caiScale,
          }
      ],
    };
  }

  static TrackMetrics? metricsFromJson(Map<String, dynamic>? m) {
    if (m == null) return null;
    final samples = [
      for (final s in (m['s'] as List? ?? const []))
        ProfileSample(
          distanceMeters: (s['d'] as num).toDouble(),
          elevation: (s['e'] as num).toDouble(),
          position:
              LatLng((s['la'] as num).toDouble(), (s['ln'] as num).toDouble()),
        ),
    ];
    final segments = [
      for (final s in (m['seg'] as List? ?? const []))
        TrailSegment(
          fromMeters: (s['f'] as num).toDouble(),
          toMeters: (s['t'] as num).toDouble(),
          ref: s['r'] as String,
          caiScale: s['sc'] as String?,
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
      trailSegments: segments,
    );
  }

  // ---- foto collegate -------------------------------------------------------

  static Map<String, dynamic> photoToJson(TrackPhoto p) => {
        'id': p.id,
        'la': p.position.latitude,
        'ln': p.position.longitude,
        'd': p.distanceMeters,
        if (p.takenAt != null) 'at': p.takenAt!.toIso8601String(),
        if (p.thumbnail != null) 'thumb': base64Encode(p.thumbnail!),
      };

  static TrackPhoto photoFromJson(Map<String, dynamic> j) => TrackPhoto(
        id: j['id'] as String,
        position:
            LatLng((j['la'] as num).toDouble(), (j['ln'] as num).toDouble()),
        distanceMeters: (j['d'] as num).toDouble(),
        takenAt: parseDate(j['at']),
        thumbnail:
            j['thumb'] == null ? null : base64Decode(j['thumb'] as String),
      );

  static List<Map<String, dynamic>> photosToJson(List<TrackPhoto> photos) =>
      [for (final p in photos) photoToJson(p)];

  static List<TrackPhoto> photosFromJson(List<dynamic>? json) => [
        for (final p in (json ?? const []))
          photoFromJson(p as Map<String, dynamic>),
      ];

  // ---- traccia completa (file cloud autosufficiente) ----------------------

  /// Mappa JSON completa di una traccia, incluso [updatedAt] per la
  /// risoluzione dei conflitti (last-write-wins) in sincronizzazione.
  static Map<String, dynamic> toJson(DrawnTrack t,
          {required DateTime updatedAt}) =>
      {
        'id': t.id,
        'name': t.name,
        'color': t.color.toARGB32(),
        'snapToTrail': t.snapToTrail,
        'waypoints': pointsToJson(t.waypoints),
        'routedPath': pointsToJson(t.routedPath),
        'trailRefs': t.trailRefs,
        'trailsResolved': t.trailsResolved,
        'metrics': metricsToJson(t.metrics),
        'createdAt': t.createdAt?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'photos': photosToJson(t.photos),
      };

  static DrawnTrack fromJson(Map<String, dynamic> j) => DrawnTrack(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        color: Color((j['color'] as num?)?.toInt() ?? 0xFF1565C0),
        snapToTrail: (j['snapToTrail'] as bool?) ?? true,
        waypoints: pointsFromJson((j['waypoints'] as List?) ?? const []),
        routedPath: pointsFromJson((j['routedPath'] as List?) ?? const []),
        trailRefs: ((j['trailRefs'] as List?) ?? const []).cast<String>(),
        trailsResolved: (j['trailsResolved'] as bool?) ?? false,
        metrics: metricsFromJson(j['metrics'] as Map<String, dynamic>?),
        createdAt: parseDate(j['createdAt']),
        photos: photosFromJson(j['photos'] as List?),
      );

  /// Estrae il timestamp di ultima modifica dal JSON (per il merge cloud).
  static DateTime? updatedAtOf(Map<String, dynamic> j) => parseDate(j['updatedAt']);

  static DateTime? parseDate(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;
}
