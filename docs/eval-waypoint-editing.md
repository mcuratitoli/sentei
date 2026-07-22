# Editing dei punti intermedi della traccia — analisi e piano

> Roadmap P2, primo item. Analisi 22 lug 2026, decisioni utente 23 lug 2026.
> Stato: **in implementazione step-by-step**.

## Stato attuale (prima di questa feature)

In modalità disegno/modifica (`editingId != null`, `route_editor_provider.dart`):

- **Aggiungi**: tap sulla mappa → `addPoint(p)` → sempre **in coda**.
- **Sposta**: drag di un pallino → `movePoint(i)` (funziona su qualsiasi waypoint).
- **Elimina**: **tap** su un pallino → `removePoint(i)` → immediato, senza conferma.
- **Undo**: `undo()` rimuove solo l'**ultimo** punto (LIFO).
- Ri-editare una traccia salvata: `editSelected()`.
- Anteprima: `livePathProvider` **re-instrada TUTTI i segmenti** a ogni modifica
  (`routeAlong` in loop su BRouter).

Pallini renderizzati in `map_gl_screen.dart` (`_waypointDots`, `circleRadius: 7`,
`isDraggable: true`); `dragEvents→_onWaypointDragEnd`, `tapEvents→_onWaypointTap`.

## Problemi

1. **Inserimento intermedio assente**: non puoi mettere un punto di controllo tra
   due esistenti per rimodellare un tratto (`addPoint` solo in coda).
2. **Ri-instradamento non incrementale**: ogni edit ricalcola l'intero percorso →
   lento su tracce lunghe (N segmenti × chiamate BRouter).
3. **Delete rischioso**: tap = elimina istantaneo → cancellazioni accidentali.
4. **Undo limitato**: solo last-added.
5. **Drag difficile** (segnalato dall'utente): il pallino da 7px è un target
   troppo piccolo → spesso si sposta la mappa invece del punto.

## Decisioni (utente, 23 lug 2026)

1. Inserimento → **maniglie di metà-segmento** (pallini fantasma al centro di ogni
   tratto; trascinandone uno nasce un waypoint e il segmento si splitta).
2. Delete → **selezione + conferma** (niente più tap-delete istantaneo).
3. Re-instradamento → **incrementale** (solo i segmenti toccati).
4. Undo → **a stack** (snapshot delle operazioni).
5. Procedere **step by step**.
6. Rendere i punti **molto più facili da afferrare**.

## Piano step-by-step

- **Step 1 — Grab facile.** Ingrandire il target touch dei waypoint (raggio ~10–11
  + stroke) così il drag prende il punto e non la mappa. Rif. `_renderAll`/waypoint
  render in `map_gl_screen.dart`.
- **Step 2 — Undo a stack.** Nel notifier `Tracks`, stack di snapshot dei waypoint
  (push prima di ogni mutazione: add/move/remove/insert); `undo()` fa pop. Lo stack
  si azzera all'inizio/fine editing. Test di logica.
- **Step 3 — Selezione + elimina con conferma.** Tap su pallino = **seleziona**
  (evidenzia con anello), non elimina. Elimina da pulsante nella card (o long-press)
  con `showIosConfirm`. Nuovo stato "waypoint selezionato".
- **Step 4 — Inserimento con maniglie di metà-segmento.** `insertPoint(index, p)`
  nel notifier; nuovo `CircleAnnotationManager` per le maniglie (stile distinto,
  più piccole/traslucide) al centro di ogni segmento; drag maniglia → insert + split.
- **Step 5 — Ri-instradamento incrementale.** Passare da "route whole" a un modello
  **per-segmento** con cache Riverpod: provider family `segmentRouteProvider((a,b,
  snap))`; percorso = concatenazione dei segmenti. Riverpod cacha per chiave →
  ricalcola solo i segmenti la cui coppia di estremi è cambiata (insert = due nuove
  chiavi A→W, W→B; move di wp[i] = segmenti i-1 e i; remove = fusione dei due
  adiacenti). I tratti non toccati restano cache-hit.

## Note

- Segnavia/difficoltà CAI: restano ricalcolati al "Fine" (nessun impatto durante l'editing).
- Distinzione gesti sui pallini: `tap=seleziona / drag=sposta / drag-maniglia=inserisci`.
