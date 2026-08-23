/// Ricalcolo degli indici dei **segmenti liberi** (tratti disegnati a mano,
/// non agganciati ai sentieri — §"Traccia mista", `docs/ROADMAP.md` P3) dopo
/// un inserimento/rimozione di waypoint. Un segmento `i` collega il waypoint
/// `i` al waypoint `i+1`: inserire o rimuovere un punto sposta gli indici di
/// tutti i segmenti a valle, quindi l'insieme va rimappato esplicitamente
/// invece di lasciarlo scivolare fuori sincrono con i waypoint.
///
/// Logica pura, senza dipendenze da Riverpod/dominio — testabile in isolamento.
library;

/// Dopo l'inserimento di un nuovo waypoint in posizione [index] (0 ≤ [index]
/// ≤ [oldWaypointCount]) in una traccia che aveva [oldWaypointCount]
/// waypoint: il segmento che veniva diviso (quello tra il vecchio waypoint
/// `index-1` e `index`, se [index] cade **dentro** un segmento esistente)
/// eredita la propria libertà su **entrambe** le metà — inserire un punto in
/// un tratto libero non lo riaggancia al sentiero, e viceversa. Un
/// inserimento ai due estremi (prima del primo punto o dopo l'ultimo) crea
/// invece un segmento di bordo del tutto nuovo, non libero di default (come
/// ogni nuovo tratto disegnato senza aver attivato "Libero").
Set<int> freeSegmentsAfterInsert(
    Set<int> free, int index, int oldWaypointCount) {
  final segCount = oldWaypointCount - 1;
  final prefix = [for (var j = 0; j < index - 1; j++) free.contains(j)];
  final List<bool> splitOrNew;
  if (index >= 1 && index - 1 < segCount) {
    final wasFree = free.contains(index - 1);
    splitOrNew = [wasFree, wasFree];
  } else {
    splitOrNew = [false];
  }
  final suffix = [for (var j = index; j < segCount; j++) free.contains(j)];
  final out = [...prefix, ...splitOrNew, ...suffix];
  return {for (var i = 0; i < out.length; i++) if (out[i]) i};
}

/// Dopo la rimozione del waypoint in posizione [index] (0 ≤ [index] <
/// [oldWaypointCount]): i due segmenti adiacenti (quello che arriva e quello
/// che parte dal punto rimosso, se entrambi esistono) si fondono in uno
/// solo, libero se **almeno uno dei due** lo era — rimuovere un punto non
/// deve "riagganciare" per sorpresa un tratto reso libero apposta. Se il
/// punto rimosso è un estremo (primo o ultimo waypoint), l'unico segmento
/// adiacente semplicemente scompare, senza fondersi con nulla.
Set<int> freeSegmentsAfterRemove(
    Set<int> free, int index, int oldWaypointCount) {
  final segCount = oldWaypointCount - 1;
  final hasPredecessor = index - 1 >= 0 && index - 1 < segCount;
  final hasSuccessor = index >= 0 && index < segCount;
  final prefix = [for (var j = 0; j < index - 1; j++) free.contains(j)];
  final mergedSlot = <bool>[
    if (hasPredecessor && hasSuccessor)
      free.contains(index - 1) || free.contains(index),
  ];
  final suffix = [for (var j = index + 1; j < segCount; j++) free.contains(j)];
  final out = [...prefix, ...mergedSlot, ...suffix];
  return {for (var i = 0; i < out.length; i++) if (out[i]) i};
}
