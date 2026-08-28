import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Errore di localizzazione (servizio disattivo o permesso negato).
class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
  @override
  String toString() => 'LocationException: $message';
}

/// Posizione GPS arricchita con i metadati di **qualità del fix** — accuratezza
/// orizzontale, quota e accuratezza verticale — usata dall'HUD di posizione
/// sulla mappa (§ROADMAP P1.A). Lo stream "semplice" ([LocationService.positionStream])
/// resta per il centraggio mappa, che di questi dati non ha bisogno.
class GpsFix {
  const GpsFix({
    required this.position,
    required this.horizontalAccuracyM,
    required this.altitudeM,
    required this.altitudeAccuracyM,
  });

  factory GpsFix.fromPosition(Position p) => GpsFix(
        position: LatLng(p.latitude, p.longitude),
        // accuracy/altitudeAccuracy valgono 0 (o < 0 su iOS) quando il dato non
        // è disponibile: normalizzati a null così la UI non mostra "± 0 m".
        horizontalAccuracyM: p.accuracy > 0 ? p.accuracy : null,
        altitudeM: p.altitude,
        altitudeAccuracyM: p.altitudeAccuracy > 0 ? p.altitudeAccuracy : null,
      );

  final LatLng position;
  final double? horizontalAccuracyM;
  final double altitudeM;
  final double? altitudeAccuracyM;

  /// Soglia oltre la quale la quota GPS non è considerata affidabile e la UI
  /// mostra un trattino invece del valore (scelta prodotto, 28 ago 2026).
  static const double reliableAltitudeAccuracyM = 25;

  /// La quota GPS è mostrabile: accuratezza verticale nota e sotto soglia.
  bool get hasReliableAltitude =>
      altitudeAccuracyM != null &&
      altitudeAccuracyM! <= reliableAltitudeAccuracyM;
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

  /// Stream della posizione con i metadati di qualità ([GpsFix]) per l'HUD.
  /// `distanceFilter` più stretto (~5 m): l'HUD mostra un valore che deve
  /// sembrare "vivo" mentre si cammina, non aggiornarsi a scatti da 10 m.
  Stream<GpsFix> fixStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).map(GpsFix.fromPosition);
  }
}
