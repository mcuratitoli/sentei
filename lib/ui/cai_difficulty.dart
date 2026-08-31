import 'package:flutter/material.dart';

import '../domain/models/elevation_profile.dart';
import 'tokens.dart' show AppDifficultyColors;

/// Difficoltà escursionistica CAI: helper condivisi (ordine, colore, etichetta)
/// usati sia dal grafico del profilo (banda per tratto) sia dalla card della
/// traccia (un badge per ogni grado presente lungo il percorso).

/// Ordine di difficoltà CAI: T < E < EE < EEA < EEA:F (tratto di via ferrata).
/// La variante `EEA:F` (e in generale `EEA:<x>`, dove `<x>` è la difficoltà
/// alpinistica del tratto attrezzato) vale un gradino sopra EEA "liscio".
const Map<String, int> _caiRank = {
  'T': 1,
  'E': 2,
  'EE': 3,
  'EEA': 4,
  'EEA:F': 5,
};

/// Normalizza un grado CAI (maiuscolo, senza spazi). `null` se vuoto/assente.
String? normalizeCaiScale(String? scale) {
  final k = scale?.toUpperCase().trim();
  return (k == null || k.isEmpty) ? null : k;
}

/// Grado "base" prima dei due punti: `EEA:F` → `EEA`. Per i valori standard
/// (T/E/EE/EEA) è il valore stesso. Serve per dare comunque un colore/stile
/// sensato alle varianti `EEA:<x>` diverse dalla `:F` già in `_caiRank`.
String _baseCaiScale(String? scale) {
  final k = normalizeCaiScale(scale);
  if (k == null) return '';
  final i = k.indexOf(':');
  return i < 0 ? k : k.substring(0, i);
}

/// Posizione del grado nell'ordine di difficoltà (0 = sconosciuto). Usa il
/// grado esatto se noto, altrimenti ricade sul [_baseCaiScale] (così una
/// `EEA:PD` non vista prima si ordina comunque come EEA).
int caiScaleRank(String? scale) {
  final k = normalizeCaiScale(scale);
  if (k == null) return 0;
  return _caiRank[k] ?? _caiRank[_baseCaiScale(k)] ?? 0;
}

/// Tutti i gradi CAI **distinti** presenti nei tratti, dal più facile al più
/// difficile. Vuoto se nessun tratto ha un grado noto. La card della traccia
/// ne mostra un badge ciascuno: se il percorso ha un tratto T, uno EE e uno
/// EEA si vedono tutti e tre, non solo il più impegnativo.
List<String> presentCaiScales(Iterable<TrailSegment> segments) {
  final seen = <String>{};
  for (final s in segments) {
    final k = normalizeCaiScale(s.caiScale);
    if (k != null) seen.add(k);
  }
  final list = seen.toList()
    ..sort((a, b) => caiScaleRank(a).compareTo(caiScaleRank(b)));
  return list;
}

/// Colore per il grado di difficoltà CAI: T verde, E teal, EE arancio,
/// EEA (e varianti attrezzate `EEA:<x>`) rosso; grigio per valori non standard.
/// **Il blu è escluso** (riservato al brand/azione, `AppColors.primary` — vedi
/// `design/DESIGN_GUIDELINES.md` §2): prima "E" usava lo stesso blu del brand,
/// ambiguo con lo stato attivo.
Color caiScaleColor(String scale) {
  switch (normalizeCaiScale(scale)) {
    case 'T':
      return AppDifficultyColors.t;
    case 'E':
      return AppDifficultyColors.e;
    case 'EE':
      return AppDifficultyColors.ee;
    case 'EEA':
    case 'EEA:F':
      return AppDifficultyColors.eea;
  }
  // Altre varianti attrezzate (EEA:PD, EEA:D…): stesso rosso di EEA.
  if (_baseCaiScale(scale) == 'EEA') return AppDifficultyColors.eea;
  return const Color(0xFF616161);
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
    case 'EEA:F':
      return 'Escursionisti Esperti con Attrezzatura (via ferrata)';
  }
  if (_baseCaiScale(scale) == 'EEA') {
    return 'Escursionisti Esperti con Attrezzatura (via ferrata)';
  }
  return scale;
}

/// Spiegazione dettagliata del grado CAI (per la legenda in Impostazioni).
/// Testo allineato alla «Guida dei Monti d'Italia» (CAI).
String caiScaleDescription(String scale) {
  switch (normalizeCaiScale(scale)) {
    case 'T':
      return 'I percorsi più facili: stradine o sentieri ben tracciati, '
          'agevoli e con dislivelli piuttosto modesti.';
    case 'E':
      return 'Itinerari su sentiero o con percorso abbastanza evidente, che '
          'richiedono già un po\' di esperienza e allenamento alla fatica. '
          'A volte brevi tratti esposti o elementari passaggi su roccia.';
    case 'EE':
      return 'Percorsi con tratti aerei ed esposti, passaggi su roccia o '
          'problemi di orientamento. Richiedono esperienza, passo sicuro e '
          'assenza di vertigini.';
    case 'EEA':
      return 'Itinerari attrezzati o vie ferrate che richiedono l\'uso di '
          'dispositivi di autoassicurazione (imbrago, kit da ferrata, casco) '
          'e conoscenza del loro impiego.';
    case 'EEA:F':
      return 'Come EEA, ma con un vero tratto di via ferrata. La sigla dopo i '
          'due punti indica la difficoltà alpinistica del tratto attrezzato '
          '(qui «F» = Facile). Obbligatori imbrago, kit da ferrata e casco, e '
          'la conoscenza del loro impiego.';
  }
  if (_baseCaiScale(scale) == 'EEA') {
    return 'Come EEA, ma con un vero tratto di via ferrata. La sigla dopo i '
        'due punti indica la difficoltà alpinistica del tratto attrezzato. '
        'Obbligatori imbrago, kit da ferrata e casco.';
  }
  return scale;
}

/// Gradi CAI in ordine di difficoltà crescente (per la legenda).
const List<String> caiScalesInOrder = ['T', 'E', 'EE', 'EEA', 'EEA:F'];

/// Pattern di **tratteggio** della linea del tracciato per grado CAI, sul
/// modello delle carte escursionistiche ufficiali (Tabacco/CAI): **T** linea
/// piena, **E** trattini lunghi, **EE** punteggiato, **EEA** (e varianti
/// attrezzate `EEA:<x>`) dash‑punto (resa di ripiego delle crocette da via
/// ferrata — un `line-dasharray` non può fare simboli). `null` = linea piena
/// (T o grado sconosciuto).
///
/// Valori in **unità di larghezza linea** (come vuole Mapbox `line-dasharray`):
/// scalano con lo spessore. Fonte unica condivisa da mappa
/// (`map_gl_screen.dart`) e legenda (`legends.dart`).
List<double>? caiScaleDash(String? scale) {
  switch (normalizeCaiScale(scale)) {
    case 'E':
      return const [3, 3];
    case 'EE':
      // `on` quasi nullo + `line-cap: round` = pallini tondi; periodo largo
      // così i pallini restano **ben staccati** (con cap tondo ogni "on"
      // guadagna mezza larghezza per lato, un periodo stretto li salda).
      return const [0.1, 4.5];
    case 'EEA':
    case 'EEA:F':
      return const [3, 2.5, 0.1, 2.5];
  }
  if (_baseCaiScale(scale) == 'EEA') return const [3, 2.5, 0.1, 2.5];
  return null;
}
