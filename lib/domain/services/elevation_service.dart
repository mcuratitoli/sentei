import 'package:latlong2/latlong.dart';

/// Servizio che fornisce la quota (metri) per una coordinata, campionando il
/// DEM Terrarium (§6.1). L'implementazione concreta — download/caching tile
/// (FMTC) + decodifica pixel (vedi `data/offline/terrarium.dart`) — arriva in
/// Fase 1.F. Qui definiamo solo il contratto, così la logica di dominio
/// (distanza/dislivello) resta indipendente dalla sorgente dati e testabile.
abstract interface class ElevationService {
  /// Quota in metri per [point], oppure `null` se non disponibile (tile mancante
  /// offline o fuori copertura).
  Future<double?> elevationAt(LatLng point);

  /// Quote per una serie di punti (es. path densificato). Le posizioni senza
  /// dato restituiscono `null` nello slot corrispondente.
  Future<List<double?>> elevationsAlong(List<LatLng> points);
}
