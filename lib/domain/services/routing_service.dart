import 'package:latlong2/latlong.dart';

/// Risultato dell'instradamento lungo i sentieri.
class RouteResult {
  const RouteResult({
    required this.geometry,
    this.elevations = const [],
    this.lengthMeters,
    this.ascentMeters,
  });

  /// Geometria del percorso che segue i sentieri (denso).
  final List<LatLng> geometry;

  /// Quota per ciascun punto di [geometry] (stessa lunghezza), se disponibile.
  final List<double?> elevations;

  /// Lunghezza calcolata dal motore di routing (m), se fornita.
  final double? lengthMeters;

  /// Dislivello positivo filtrato dal motore (m), se fornito.
  final double? ascentMeters;
}

/// Errore di instradamento (rete assente, punti non raggiungibili, ecc.).
class RoutingException implements Exception {
  const RoutingException(this.message);
  final String message;
  @override
  String toString() => 'RoutingException: $message';
}

/// Calcola il percorso escursionistico che collega una sequenza di waypoint
/// seguendo i sentieri (§6.2). Online (GraphHopper/BRouter) o, in Fase 2,
/// offline (BRouter embedded).
abstract interface class RoutingService {
  /// Instrada [waypoints] (>= 2) lungo i sentieri. Lancia [RoutingException]
  /// se non è possibile calcolare il percorso.
  Future<RouteResult> route(List<LatLng> waypoints, {String? profile});
}
