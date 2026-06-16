import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Errore di localizzazione (servizio disattivo o permesso negato).
class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
  @override
  String toString() => 'LocationException: $message';
}

/// Accesso alla posizione GPS (foreground). Background → Fase 2 (§7).
class LocationService {
  const LocationService();

  /// Verifica servizio attivo + permessi, richiedendoli se necessario.
  /// Lancia [LocationException] se non utilizzabile.
  Future<void> ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Localizzazione disattivata sul dispositivo');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationException('Permesso di localizzazione negato');
    }
  }

  /// Stream delle posizioni (aggiornamento ogni ~10 m).
  Stream<LatLng> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map((p) => LatLng(p.latitude, p.longitude));
  }
}
