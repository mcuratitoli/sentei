import 'package:latlong2/latlong.dart';

/// Un singolo punto del tracciato, con quota opzionale (metri).
class TrackPoint {
  const TrackPoint({
    required this.position,
    this.elevation,
  });

  final LatLng position;

  /// Quota in metri (da DEM Terrarium o GPX importato), `null` se ignota.
  final double? elevation;
}

/// Un tracciato disegnato o importato dall'utente.
///
/// Stub di dominio per la Fase 1: la persistenza (drift) e il calcolo di
/// distanza/dislivello (domain/services) verranno collegati in seguito.
class Track {
  const Track({
    required this.id,
    required this.name,
    required this.points,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final List<TrackPoint> points;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Track copyWith({
    String? name,
    List<TrackPoint>? points,
    DateTime? updatedAt,
  }) {
    return Track(
      id: id,
      name: name ?? this.name,
      points: points ?? this.points,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
