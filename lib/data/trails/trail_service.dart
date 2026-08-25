import 'package:flutter/foundation.dart' show debugPrint;
import 'package:latlong2/latlong.dart';

import '../../domain/models/elevation_profile.dart';
import 'cai_varallo_search_service.dart';

/// Errore "duro" di una ricerca segnavia (rete/timeout/HTTP non-200): distingue
/// un **fallimento** (da ritentare) da una risposta **valida ma vuota** (la zona
/// non ha segnavia — da NON ritentare). Chi risolve i segnavia usa questa
/// distinzione per decidere se marcare la traccia come "già cercata".
class TrailLookupException implements Exception {
  const TrailLookupException(this.message);
  final String message;
  @override
  String toString() => 'TrailLookupException: $message';
}

/// Fonte che ha prodotto una [TrailRelation] — serve a sapere **come**
/// recuperarne la relazione completa (§"Un segnavia per intero"): endpoint e
/// formato dell'id sono diversi per OSM2CAI (`GET /api/v2/hiking-route/{id}`)
/// e Overpass (`rel(<id>); out geom;`).
enum TrailSource { osm2cai, overpass }

/// Una relazione sentiero generica (numero `ref` + geometria), indipendente
/// dalla fonte (Overpass OSM grezzo o catasto CAI/OSM2CAI). Le sottoclassi di
/// [TrailService] la producono; la logica di matching è condivisa.
///
/// [points] resta la geometria **ritagliata al bounding box** interrogato
/// (percorso disegnato, o punto singolo per [TrailService.trailsNear]) — va
/// bene per etichettare/matchare, ma non per "mostrare il segnavia per
/// intero" (§`docs/ROADMAP.md` P1.3): quello richiede un fetch a parte della
/// relazione completa, per cui serve [id].
class TrailRelation {
  const TrailRelation(this.ref, this.points, this.source,
      {this.caiScale, this.id, this.name, this.from, this.to, this.osmcSymbol});
  final String ref;
  final List<LatLng> points;
  final TrailSource source;

  /// Grado di difficoltà CAI (T/E/EE/EEA), se taggato sulla relazione.
  final String? caiScale;

  /// Identificativo della relazione presso la fonte — serve a recuperarne la
  /// geometria **completa** (non ritagliata) in un secondo fetch. Per
  /// Overpass è l'id della relazione OSM, sempre presente. Per OSM2CAI **non
  /// ancora verificato dal vivo** (endpoint bloccato dalla network policy del
  /// sandbox di sviluppo, vedi `docs/osm2cai-investigation.md`): il nome
  /// campo tentato (`id`) è il più plausibile ma va confermato su device
  /// prima di fare affidamento su questo valore per OSM2CAI.
  final String? id;

  /// Nome del sentiero e capi-percorso (es. "da Alagna a Rifugio Pastore"),
  /// se la fonte li espone.
  final String? name;
  final String? from;
  final String? to;

  /// Simbolo segnavia (es. bianco/rosso CAI), tag OSM `osmc:symbol` — bonus
  /// per una futura resa colorata, non usato ancora da nessuna UI.
  final String? osmcSymbol;
}

/// La relazione **completa** di un segnavia (§"Un segnavia per intero"):
/// geometria non ritagliata a nessun bounding box, più i dati mostrati nella
/// card di dettaglio. Prodotta da un fetch a parte (per id), non dalla
/// ricerca "cosa c'è vicino a questo percorso/punto" di [TrailRelation].
class TrailDetail {
  const TrailDetail({
    required this.ref,
    required this.points,
    this.name,
    this.from,
    this.to,
    this.caiScale,
    this.distanceMeters,
    this.ascentMeters,
    this.descentMeters,
    this.officialUrl,
    this.caiVarallo,
    this.geometryComplete = true,
  });

  final String ref;

  /// Geometria dell'**intero** segnavia, dal capo-percorso all'altro.
  final List<LatLng> points;
  final String? name;
  final String? from;
  final String? to;
  final String? caiScale;

  /// Precalcolati dalla fonte quando disponibili (OSM2CAI); per Overpass
  /// [distanceMeters] è calcolato localmente sulla geometria, [ascentMeters]/
  /// [descentMeters] restano `null` (richiederebbero campionare l'elevazione
  /// lungo l'intero percorso, fuori scopo per questa card).
  final double? distanceMeters;
  final double? ascentMeters;
  final double? descentMeters;

  /// Link alla scheda pubblica, **solo se un formato affidabile esiste** —
  /// per Overpass è il permalink OSM standard (`openstreetmap.org/relation/
  /// {id}`, sempre valido); per OSM2CAI resta `null` finché non si conferma
  /// dal vivo un permalink pubblico su `osm2cai.cai.it` (vedi
  /// `docs/osm2cai-investigation.md`) — meglio nessun link che uno inventato.
  final String? officialUrl;

  /// Corrispondenza esatta nell'**elenco ufficiale** di CAI Varallo, solo
  /// per i segnavia geograficamente in **Valsesia e dintorni** (verificato
  /// con [CombinedTrailService], non qui — questo campo è solo il
  /// contenitore). `null` altrove o se il ref non compare in elenco.
  final CaiVaralloResult? caiVarallo;

  /// `false` quando [points] **non** è la geometria completa del segnavia,
  /// ma solo quella (ritagliata, spesso pochi punti) già nota dalla ricerca
  /// che ha portato a questo segnavia — usata come ripiego quando il fetch
  /// della geometria completa fallisce (rete). Introdotto il 25 ago 2026
  /// dopo un fallimento totale di Overpass durante un test dal vivo: prima,
  /// un fetch fallito buttava via **anche** ref/nome/capi-percorso/link CAI
  /// Varallo, già noti e non dipendenti da quel fetch — "non ha senso non
  /// mostrare nulla" (feedback testuale dell'utente). La UI usa questo flag
  /// per non disegnare/inquadrare sulla mappa un troncone che sembrerebbe
  /// (a torto) l'intero percorso, e per avvisare che i dati sono parziali.
  final bool geometryComplete;

  TrailDetail copyWith({CaiVaralloResult? caiVarallo}) => TrailDetail(
        ref: ref,
        points: points,
        name: name,
        from: from,
        to: to,
        caiScale: caiScale,
        distanceMeters: distanceMeters,
        ascentMeters: ascentMeters,
        descentMeters: descentMeters,
        officialUrl: officialUrl,
        caiVarallo: caiVarallo ?? this.caiVarallo,
        geometryComplete: geometryComplete,
      );
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
  ///
  /// [radiusMeters] è un suggerimento del raggio di ricerca effettivo da
  /// usare nella query di rete (non solo nel filtro finale sui risultati):
  /// serve a [trailsNear], che altrimenti interrogherebbe la fonte con un
  /// raggio fisso più piccolo della soglia richiesta dal chiamante — bug
  /// osservato dal vivo (24 ago 2026): un segnavia a 50-60 m da un tap
  /// veniva scartato perché mai neanche scaricato, non perché fuori soglia.
  /// `null` (il caso di [trailSegmentsAlong], percorso disegnato) lascia
  /// alla sottoclasse il proprio raggio di default.
  Future<List<TrailRelation>> fetchRelations(List<LatLng> path,
      {double? radiusMeters});

  /// Recupera la relazione **completa** di [relation] (§"Un segnavia per
  /// intero", `docs/ROADMAP.md` P1.3). Implementazione di base: sempre
  /// `null` — una singola fonte (Osm2CaiTrailService/OverpassTrailService)
  /// non basta da sola, serve poter smistare in base a
  /// [TrailRelation.source]; solo [CombinedTrailService] lo fa per davvero.
  /// Vive qui (non solo su quella classe) così `trailServiceProvider` può
  /// restare tipizzato sull'astratto [TrailService].
  Future<TrailDetail?> fetchDetail(TrailRelation relation) async => null;

  /// Ultima spiaggia quando non si riesce nemmeno a **risolvere** un ref in
  /// una relazione vera (OSM2CAI/Overpass entrambi giù o senza risultati,
  /// caso della card traccia — `TrailDetailNotifier.openByRef`): prova a
  /// mostrare qualcosa usando **solo** il numero segnavia già noto e un
  /// punto vicino, senza bisogno di alcuna relazione risolta. Implementazione
  /// di base: sempre `null` (solo [CombinedTrailService] sa cercare su CAI
  /// Varallo). Vive qui per lo stesso motivo di [fetchDetail] — mantenere
  /// `trailServiceProvider` tipizzato sull'astratto [TrailService].
  Future<TrailDetail?> fetchByRefOnly(String trailRef, LatLng anchor) async =>
      null;

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

  /// Segnavia che passano **entro [thresholdMeters]** da [point] — non lungo
  /// un percorso disegnato, un singolo punto qualsiasi (usato dalla card del
  /// punto ispezionato quando si tocca la mappa vicino a un sentiero, §"Un
  /// segnavia per intero", `docs/ROADMAP.md` P1.3). Ordinati per distanza
  /// crescente; nessun limite al numero di risultati — un incrocio può avere
  /// più segnavia vicini, mostrati tutti come label separate invece di
  /// sceglierne uno solo. Best-effort come [trailSegmentsAlong]: nessuna
  /// eccezione verso il chiamante, lista vuota su qualunque errore.
  Future<List<TrailRelation>> trailsNear(LatLng point,
      {double thresholdMeters = 60}) async {
    debugPrint('[trails] trailsNear (${point.latitude}, ${point.longitude}), '
        'soglia ${thresholdMeters}m');
    final List<TrailRelation> relations;
    try {
      relations = await fetchRelations([point], radiusMeters: thresholdMeters);
    } catch (e) {
      debugPrint('[trails] trailsNear: fetchRelations ha lanciato: $e');
      return const [];
    }
    debugPrint('[trails] trailsNear: fetchRelations → ${relations.length} '
        'relazioni scaricate (${relations.map((r) => r.ref).toList()})');
    if (relations.isEmpty) return const [];

    const distance = Distance();
    final withDist = <(TrailRelation, double)>[];
    for (final r in relations) {
      var d = double.infinity;
      for (final q in r.points) {
        final dd = distance(point, q);
        if (dd < d) d = dd;
        if (d == 0) break;
      }
      if (d <= thresholdMeters) {
        withDist.add((r, d));
      } else {
        debugPrint('[trails] trailsNear: "${r.ref}" scartato, distanza '
            '${d.round()}m > soglia ${thresholdMeters}m');
      }
    }
    withDist.sort((a, b) => a.$2.compareTo(b.$2));

    // Dedup per ref: OSM2CAI e Overpass non dovrebbero mai contribuire
    // entrambi (`fetchRelations` sceglie l'uno o l'altro), ma per sicurezza
    // non si vuole la stessa label due volte.
    final seen = <String>{};
    final out = <TrailRelation>[];
    for (final (r, _) in withDist) {
      if (seen.add(r.ref)) out.add(r);
    }
    debugPrint('[trails] trailsNear: risultato finale entro soglia → '
        '${out.map((r) => r.ref).toList()}');
    return out;
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
