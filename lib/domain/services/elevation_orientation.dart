import 'package:latlong2/latlong.dart';

import '../models/elevation_profile.dart';

/// Bearing (gradi, 0–360) da imprimere alla camera dell'export immagine
/// (§export, `docs/ROADMAP.md`) perché il punto **più basso** del percorso
/// finisca in basso nell'immagine e quello **più alto** in alto — non
/// vincolato al nord (richiesta esplicita: niente "nord in alto" di
/// default, l'orientamento segue il dislivello).
///
/// `null` se il profilo non ha abbastanza informazione (vuoto, oppure punto
/// più basso e più alto coincidenti: nessuna direzione sensata da imprimere,
/// es. un anello che torna esattamente al punto di partenza più alto).
double? elevationOrientationBearing(ElevationProfile profile) {
  if (profile.isEmpty) return null;
  var lowest = profile.samples.first;
  var highest = profile.samples.first;
  for (final s in profile.samples) {
    if (s.elevation < lowest.elevation) lowest = s;
    if (s.elevation > highest.elevation) highest = s;
  }
  if (lowest.position.latitude == highest.position.latitude &&
      lowest.position.longitude == highest.position.longitude) {
    return null;
  }
  // `Distance.bearing` (latlong2) ritorna in [-180, 180]: normalizzato a
  // [0, 360) perché è quanto si aspetta `CameraOptions.bearing` (Mapbox).
  final bearing = const Distance().bearing(lowest.position, highest.position);
  return (bearing + 360) % 360;
}
