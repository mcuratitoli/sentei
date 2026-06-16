import 'package:latlong2/latlong.dart';

/// Tratto del percorso percorso su un dato sentiero (ref CAI), espresso in
/// distanza cumulata da..a (metri). Serve a mostrare i numeri sentiero lungo
/// l'asse X del profilo altimetrico.
class TrailSegment {
  const TrailSegment({
    required this.fromMeters,
    required this.toMeters,
    required this.ref,
  });

  final double fromMeters;
  final double toMeters;
  final String ref;
}

/// Un campione del profilo altimetrico: quota e posizione a una certa distanza
/// cumulata lungo il percorso.
class ProfileSample {
  const ProfileSample({
    required this.distanceMeters,
    required this.elevation,
    required this.position,
  });

  /// Distanza dall'inizio del percorso (metri).
  final double distanceMeters;

  /// Quota (metri).
  final double elevation;

  /// Coordinata corrispondente sul percorso (per evidenziare il punto in mappa).
  final LatLng position;
}

/// Profilo altimetrico completo di un percorso, pronto per il rendering e con
/// i valori sintetici già calcolati.
class ElevationProfile {
  const ElevationProfile({
    required this.samples,
    required this.minElevation,
    required this.maxElevation,
    required this.totalDistance,
  });

  final List<ProfileSample> samples;
  final double minElevation;
  final double maxElevation;
  final double totalDistance;

  bool get isEmpty => samples.isEmpty;

  /// Costruisce il profilo da punti (già densificati) e relative quote.
  ///
  /// Allinea quote e punti per indice; i campioni con quota `null` (tile
  /// mancante) vengono saltati. Logica pura e deterministica (§9).
  factory ElevationProfile.fromSamples({
    required List<LatLng> points,
    required List<double?> elevations,
    Distance distance = const Distance(),
  }) {
    assert(points.length == elevations.length,
        'points ed elevations devono avere la stessa lunghezza');

    final samples = <ProfileSample>[];
    var cumulative = 0.0;
    var min = double.infinity;
    var max = double.negativeInfinity;

    for (var i = 0; i < points.length; i++) {
      if (i > 0) cumulative += distance(points[i - 1], points[i]);
      final e = elevations[i];
      if (e == null) continue;
      samples.add(ProfileSample(
          distanceMeters: cumulative, elevation: e, position: points[i]));
      if (e < min) min = e;
      if (e > max) max = e;
    }

    return ElevationProfile(
      samples: samples,
      minElevation: samples.isEmpty ? 0 : min,
      maxElevation: samples.isEmpty ? 0 : max,
      totalDistance: cumulative,
    );
  }
}
