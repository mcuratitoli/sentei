# Piano di migrazione — mappa unica su Mapbox GL (Opzione A)

> Obiettivo: sostituire `flutter_map` con **`mapbox_maps_flutter`** come **unico
> motore mappa**, per ottenere la **transizione fluida 2D↔3D a due dita
> (nativa)** + stile vettoriale + un solo motore. Vedi `docs/eval-3d-map.md`.
> Stato: **piano** (nessun codice ancora). Da approvare prima di eseguire.

## 1. Principio guida

**Si riscrive solo il layer di presentazione mappa.** Il dominio e lo stato NON
si toccano: `Tracks`/`TracksState`, `routeAlong`, routing (BRouter), elevazione
(Terrarium), Overpass (numeri + rete), GPX, storage (drift), profilo. Sono tutti
basati su `LatLng` e non importano `flutter_map`. Confermato a inventario.

**File da riscrivere:** `features/map/map_screen.dart` (il grosso).
**File da adattare:** `data/map_sources/*` (sorgenti → stile/raster GL),
`features/map/map_providers.dart` (camera/bounds), `data/trails/trail_network_service.dart`
(disaccoppiare il tipo `LatLngBounds`). **Da eliminare a fine migrazione:**
`features/map_3d/` (assorbito), dipendenze `flutter_map` + `flutter_map_dragmarker`.

## 2. Inventario feature → equivalente Mapbox GL

| Feature attuale (flutter_map) | Equivalente Mapbox GL | Note / rischio |
|---|---|---|
| Base **Mapbox Outdoors** | stile nativo (`MapboxStyles.OUTDOORS`) | banale, già usato in 3D |
| Base **OpenTopoMap** + filtro *muted* | raster source + raster layer, `raster-saturation`/`raster-brightness` | il muting diventa **nativo** (niente ColorFilter) |
| Polilinee tracce (dash + casing + attiva + pulse salvataggio) | line layer(s) da GeoJSON source: `line-dasharray`, `line-gap-width` (casing), `line-width` per attiva; pulse via animazione `line-opacity` | resa **migliore**; il pulse richiede un piccolo ticker |
| Rete sentieri CAI (vettoriale, verde, dash fitti) | GeoJSON source aggiornata su `onMapIdle` + line layer (stesso stile) | riusa `TrailNetworkService`; gating zoom uguale |
| Marker partenza/arrivo **P/A** | PointAnnotation (testo) o symbol layer | medio |
| Waypoint **trascinabili** + tap-per-eliminare (`DragMarkers`) | PointAnnotation **draggable** (`onPointAnnotationDrag*`) + tap su annotation | ⚠️ parità UX del drag/commit a rilascio da verificare |
| Posizione utente (marker blu) | **location component nativo** (puntino + heading) | **meglio del custom** |
| Cursore profilo→punto mappa | PointAnnotation aggiornata su `profileCursorProvider` | banale |
| Tap: aggiungi punto (disegno) | `onTapListener` → coordinate native | banale |
| Tap: seleziona traccia per vicinanza (`PathGeometry.distanceToPath`) | `queryRenderedFeatures` sul line layer tracce | ⚠️ cambio di approccio (più idiomatico) |
| Bussola / "nord su" / rotazione | nativo (bearing + compass widget) | meglio |
| **2D↔3D a due dita** | **nativo** (pitch gesture) | **l'obiettivo: gratis** |
| Box attribuzione | attribution nativa + custom per OpenTopoMap/OSM | banale |
| Fullscreen | invariato (UI) | banale |
| `DrawRouteControls`, barra in basso, liste, settings | **invariati** (leggono provider) | nessun lavoro |

## 3. Approccio sui punti delicati

- **Disegno/editing:** stessi metodi `Tracks` (`addPoint`/`movePoint`/`removePoint`).
  Il rendering del percorso live (`livePathProvider`) diventa un update della
  GeoJSON source ad ogni cambio stato.
- **Drag dei waypoint:** PointAnnotation con `isDraggable: true`; commit su
  `onPointAnnotationDragEnd` (come l'attuale `onDragEnd`). Tap su annotation =
  elimina. Da validare la fluidità rispetto a `flutter_map_dragmarker`.
- **Hit-test selezione traccia:** `queryRenderedFeatures` attorno al punto toccato
  filtrando il layer "tracce" → id traccia dalle properties. Sostituisce il
  calcolo `distanceToPath` in metri (più semplice e preciso).
- **Coordinate:** helper `Position(lng,lat) ↔ LatLng(lat,lng)` centralizzato
  (attenzione all'ordine: GeoJSON è lng,lat).
- **Ordine layer:** id stabili e inserimento sopra lo stile base (`addLayer`/
  `addLayerAt`); gestire il re-add quando lo stile cambia (OpenTopoMap↔Outdoors).
- **2D↔3D:** un solo `MapWidget`; pitch 0 = 2D, gesto due dita = tilt. Eventuale
  pulsante "appiattisci" (pitch→0). Soglia rotazione/gesti da tarare per non
  interferire col tap-disegno.

## 4. Piano a fasi (ognuna verificabile e committabile)

| Fase | Contenuto | Dim. | Rischio |
|---|---|---|---|
| **0. Spike** | branch dedicato; `MapWidget` a tutto schermo con Outdoors + barra in basso esistente + gesto 2D↔3D. Niente disegno. | S | basso |
| **1. Basi + camera** | switch base Outdoors/OpenTopoMap (raster + saturation), bussola/nord, attribuzione, location nativa | M | basso |
| **2. Tracce (read-only)** | render di tutte le tracce salvate come line layer (dash/casing/attiva) + marker P/A + cursore profilo | M | medio |
| **3. Rete sentieri** | GeoJSON da `TrailNetworkService` su `onMapIdle` + stile verde tratteggiato | S–M | basso |
| **4. Disegno/editing** | tap-add, waypoint draggable, tap-elimina, preview live re-route, **tap-seleziona** via queryRenderedFeatures | **L** | **alto** |
| **5. Cleanup** | rimozione `flutter_map`(+dragmarker) e `features/map_3d/`; QA finale iOS (+ Android se serve) | M | medio |

> Si lavora su **branch** tenendo la `MapScreen` attuale finché la Fase 4 non è
> a parità. La Fase 4 (editing) è il cuore del rischio: va isolata e testata a
> fondo sul device prima del merge.

## 5. Rischi & mitigazioni

- **Parità UX del disegno (Fase 4):** prototipare drag+tap presto (già in Fase 0
  un mini-test) per confermare la fluidità prima di impegnarsi.
- **Gesti in conflitto** (tap-disegno vs pan/rotate/pitch): tarare soglie; usare
  `onTapListener` discreto.
- **Due motori durante la transizione:** convivono solo sul branch; nessun rischio
  su `main` finché non si fa merge.
- **Billing Mapbox:** 25k MAU/mese gratis — ampi per uso personale; monitorare.
- **Test:** la UI mappa non ha test automatici → verifica **manuale sul device**
  per ogni fase (come finora). Il dominio resta coperto dai 45 test.
- **iOS/Android:** SDK maturo; per ora si valida iOS (simulatore), Android quando
  serve (setup gradle già predisposto).

## 6. Rollback

Tutto su branch `feat/mapbox-gl`. Se a metà non convince: si abbandona il branch,
`main` resta sull'ibrido funzionante (flutter_map 2D + vista 3D Mapbox). Nessun
codice di dominio toccato → rollback pulito.

## 7. Cosa NON cambia per l'utente

Disegno, snap-to-trail, dislivelli/profilo, numeri sentieri, salvataggio,
import/export GPX, liste e impostazioni: **identici**. Cambia il motore mappa e
si **guadagna** il 3D fluido a due dita ovunque.

## 8. Domande aperte

- In 2D si parte sempre a pitch 0; vogliamo un pulsante rapido "torna piatto"?
- OpenTopoMap lo teniamo come alternativa raster, o si va **solo Mapbox**
  (vettoriale) semplificando? (l'utente preferiva OpenTopoMap per le curve di
  livello — ma Outdoors ha già curve di livello).
- Stima a fasi: procediamo una fase alla volta (consigliato) con verifica a
  ciascuna, o blocco unico?
