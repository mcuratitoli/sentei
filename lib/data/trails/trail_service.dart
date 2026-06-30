import 'package:latlong2/latlong.dart';

import '../../domain/models/elevation_profile.dart';

/// Una relazione sentiero generica (numero `ref` + geometria), indipendente
/// dalla fonte (Overpass OSM grezzo o catasto CAI/OSM2CAI). Le sottoclassi di
/// [TrailService] la producono; la logica di matching è condivisa.
class TrailRelation {
  const TrailRelation(this.ref, this.points, {this.caiScale});
  final String ref;
  final List<LatLng> points;

  /// Grado di difficoltà CAI (T/E/EE/EEA), se taggato sulla relazione.
  final String? caiScale;
}

/// Interfaccia comune dei servizi che attribuiscono i **numeri sentiero**
/// (ref CAI) ai tratti di un percorso. La segmentazione (campionamento del
/// percorso + assegnazione del ref più vicino) è identica per ogni fonte ed è
/// implementata qui (template method): le sottoclassi forniscono solo
/// [fetchRelations]. Best-effort: niente deve mai bloccare il disegno.
abstract class TrailService {
  const TrailService();

  /// Soglia (m) entro cui un punto del percorso "appartiene" a un sentiero.
  static const double _matchThreshold = 25.0;

  /// Passo (m) di campionamento del percorso per l'assegnazione del ref.
  static const double _sampleStep = 50.0;

  /// Scarica le relazioni sentiero (ref + geometria) vicine al [path].
  /// Implementata dalle sottoclassi in base alla fonte (Overpass / OSM2CAI).
  Future<List<TrailRelation>> fetchRelations(List<LatLng> path);

  /// Attribuisce a ciascun tratto del percorso il **numero del sentiero**
  /// (ref CAI), restituendo segmenti per distanza cumulata. Scarica una volta
  /// le geometrie vicine ([fetchRelations]) e fa il matching locale: a ogni
  /// punto campionato assegna il sentiero più vicino entro soglia; a parità si
  /// preferisce quello più "locale" (con meno punti). Best-effort.
  Future<List<TrailSegment>> trailSegmentsAlong(List<LatLng> path) async {
    if (path.length < 2) return const [];

    final relations = await fetchRelations(path);
    if (relations.isEmpty) return const [];

    const distance = Distance();
    // Distanze cumulate lungo il percorso.
    final cum = <double>[0];
    for (var i = 1; i < path.length; i++) {
      cum.add(cum[i - 1] + distance(path[i - 1], path[i]));
    }

    // Campiona ogni ~50 m e assegna il sentiero (ref + grado CAI). La
    // segmentazione è per `ref`; il grado di difficoltà segue la relazione
    // abbinata, quindi i confini coincidono con quelli dei numeri sentiero.
    final segments = <TrailSegment>[];
    String? runRef;
    String? runScale;
    double runStart = 0;
    double lastSampleDist = -_sampleStep;

    for (var i = 0; i < path.length; i++) {
      if (i != 0 &&
          i != path.length - 1 &&
          cum[i] - lastSampleDist < _sampleStep) {
        continue;
      }
      lastSampleDist = cum[i];
      final rel = _nearest(path[i], relations, _matchThreshold);
      final ref = rel?.ref;

      if (ref != runRef) {
        if (runRef != null) {
          segments.add(TrailSegment(
              fromMeters: runStart,
              toMeters: cum[i],
              ref: runRef,
              caiScale: runScale));
        }
        runRef = ref;
        runScale = rel?.caiScale;
        runStart = cum[i];
      }
    }
    if (runRef != null) {
      segments.add(TrailSegment(
          fromMeters: runStart,
          toMeters: cum.last,
          ref: runRef,
          caiScale: runScale));
    }
    return segments;
  }

  /// Relazione del sentiero più vicino a [p] entro [threshold] metri; a parità
  /// di vicinanza preferisce quella con meno punti (più locale/specifica).
  /// Ritorna la relazione (ref + grado CAI), non solo il ref.
  TrailRelation? _nearest(
      LatLng p, List<TrailRelation> relations, double threshold) {
    const distance = Distance();
    TrailRelation? best;
    var bestDist = threshold;
    var bestCount = 1 << 30;
    for (final r in relations) {
      var d = double.infinity;
      for (final q in r.points) {
        final dd = distance(p, q);
        if (dd < d) d = dd;
        if (d == 0) break;
      }
      if (d <= threshold &&
          (d < bestDist - 1 ||
              (d <= bestDist + 1 && r.points.length < bestCount))) {
        best = r;
        bestDist = d;
        bestCount = r.points.length;
      }
    }
    return best;
  }
}
