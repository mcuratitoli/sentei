import 'package:flutter/material.dart';

import '../domain/models/elevation_profile.dart';

/// Difficoltà escursionistica CAI: helper condivisi (ordine, colore, etichetta)
/// usati sia dal grafico del profilo (banda per tratto) sia dalla card della
/// traccia (grado complessivo di sintesi).

/// Ordine di difficoltà CAI: T < E < EE < EEA.
const Map<String, int> _caiRank = {'T': 1, 'E': 2, 'EE': 3, 'EEA': 4};

/// Normalizza un grado CAI (maiuscolo, senza spazi). `null` se vuoto/assente.
String? normalizeCaiScale(String? scale) {
  final k = scale?.toUpperCase().trim();
  return (k == null || k.isEmpty) ? null : k;
}

/// Grado di difficoltà **complessivo** del percorso = il tratto più impegnativo.
/// `null` se nessun tratto ha un grado noto.
String? overallCaiScale(Iterable<TrailSegment> segments) {
  String? best;
  var bestRank = 0;
  for (final s in segments) {
    final k = normalizeCaiScale(s.caiScale);
    if (k == null) continue;
    final r = _caiRank[k] ?? 0;
    if (r > bestRank) {
      best = k;
      bestRank = r;
    }
  }
  return best;
}

/// Colore per il grado di difficoltà CAI: T verde, E blu, EE arancio,
/// EEA rosso; grigio per valori non standard.
Color caiScaleColor(String scale) {
  switch (normalizeCaiScale(scale)) {
    case 'T':
      return const Color(0xFF2E7D32);
    case 'E':
      return const Color(0xFF1565C0);
    case 'EE':
      return const Color(0xFFEF6C00);
    case 'EEA':
      return const Color(0xFFC62828);
    default:
      return const Color(0xFF616161);
  }
}

/// Descrizione estesa del grado CAI (per tooltip/legenda).
String caiScaleLabel(String scale) {
  switch (normalizeCaiScale(scale)) {
    case 'T':
      return 'Turistico';
    case 'E':
      return 'Escursionistico';
    case 'EE':
      return 'Escursionisti Esperti';
    case 'EEA':
      return 'Escursionisti Esperti con Attrezzatura';
    default:
      return scale;
  }
}

/// Spiegazione dettagliata del grado CAI (per la legenda in Impostazioni).
String caiScaleDescription(String scale) {
  switch (normalizeCaiScale(scale)) {
    case 'T':
      return 'Percorsi su stradine, mulattiere o comodi sentieri ben segnalati. '
          'Non richiedono allenamento specifico oltre alla camminata.';
    case 'E':
      return 'Sentieri o tracce su terreno vario (pascoli, detriti, pietraie). '
          'Possono avere brevi tratti ripidi o esposti con protezioni. '
          'Richiedono allenamento e calzature adeguate.';
    case 'EE':
      return 'Percorsi impegnativi su terreno insidioso: tracce infide, pendii '
          'ripidi, tratti esposti, roccette o brevi passaggi con neve. '
          'Richiedono esperienza, passo sicuro e assenza di vertigini.';
    case 'EEA':
      return 'Itinerari attrezzati o vie ferrate che richiedono l\'uso di '
          'dispositivi di autoassicurazione (imbrago, kit da ferrata, casco) '
          'e conoscenza del loro impiego.';
    default:
      return scale;
  }
}

/// Gradi CAI in ordine di difficoltà crescente (per la legenda).
const List<String> caiScalesInOrder = ['T', 'E', 'EE', 'EEA'];
