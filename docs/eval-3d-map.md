# Valutazione: mappa 3D (stile Suunto) — rewrite del motore mappa

> Documento decisionale. Obiettivo dell'utente: vista **3D del terreno** (alla
> Suunto) mantenendo i colori Mapbox Outdoors già apprezzati.
>
> ✅ **DECISO E IMPLEMENTATO: Opzione B (ibrido).** Vista 3D dedicata con
> `mapbox_maps_flutter` (Outdoors + terreno DEM Mapbox + pitch), pulsante "3D"
> nella barra. flutter_map resta per l'editing 2D. Verificata sul simulatore
> (Monte Rosa, prospettiva 3D con curve di livello). Dettaglio in `features/map_3d/`.

## 1. Il vincolo di fondo

`flutter_map` (motore attuale) è **solo 2D raster**: non può rendere terreno 3D.
Il 3D richiede un motore **GL** (vettoriale, con terreno da DEM). Quindi il 3D
**implica cambiare/affiancare il motore di rendering** — scelta fissata nel
CLAUDE.md §2, da decidere consapevolmente.

## 2. Superficie d'impatto (quanto codice è legato a flutter_map)

Buona notizia: l'accoppiamento è **concentrato**. `flutter_map` è usato solo in:

| File | Cosa usa | Migrabilità |
|---|---|---|
| `features/map/map_screen.dart` | `FlutterMap`, `TileLayer`, `PolylineLayer`, `MarkerLayer`, `DragMarkers`, `MapController`, `MapCamera`, gesture | **Grosso** — è la UI mappa |
| `data/map_sources/map_source.dart` | `TileLayer` (+ muted filter) | Medio |
| `features/map/map_providers.dart` | `LatLngBounds`, camera | Piccolo |
| `data/trails/trail_network_service.dart` | solo il tipo `LatLngBounds` | Banale (disaccoppiabile) |

**Tutto il resto è engine-agnostico** e NON va riscritto: geometria
(`PathGeometry`), elevazione (`Terrarium*`, `ElevationCalculator`), routing
(`BRouter`), GPX, storage (`drift`), Overpass (numeri sentieri + rete), profilo
altimetrico. Il "cuore" dell'app è salvo.

## 3. I due motori 3D possibili

| | **mapbox_maps_flutter** (ufficiale) | **maplibre** (pacchetto moderno, open) |
|---|---|---|
| 3D terreno | ✅ nativo | ✅ (globe, pitch, terrain, hillshade) |
| Stile "Outdoors" che piace all'utente | ✅ **sì, identico** (è Mapbox) | ⚠️ no: i tile/stili Mapbox **non** sono usabili con MapLibre (ToS). Si usa MapTiler Outdoor o OpenTopoMap drappeggiato |
| Costo | **25.000 MAU/mese gratis**, poi $4/1.000 (25k–125k) | **Gratis/open**, ma porti tu i tile (MapTiler free / self-host) |
| Setup | account + token pubblico (runtime) **+ secret download token** (build) | nessun token Mapbox; serve fonte tile+DEM |
| Maturità Flutter | alta, ufficiale | media: v0.3.x, ~2 mesi, API 0.x in evoluzione |
| DEM per il 3D | `mapbox-terrain-dem-v1` | **Terrarium** (che già scarichiamo!) o MapTiler |

**Per la continuità visiva (Outdoors che ti piace) + 3D + maturità → il
candidato naturale è `mapbox_maps_flutter`.** 25k MAU/mese gratis sono ampi per
uso personale / fase iniziale. (MapLibre resta l'alternativa "zero vendor lock-in"
se in futuro il costo o i ToS Mapbox diventassero un problema.)

## 4. Tre architetture possibili

### Opzione A — Migrazione totale a un motore GL
Si butta `flutter_map`, si riscrive `map_screen.dart` con il motore GL: tutto
(2D editing + 3D) in un solo motore.
- ✅ 3D ovunque, stile vettoriale nativo (dash/casing più belli), una sola mappa
- ❌ **rewrite pesante** della UI mappa: disegno, drag dei waypoint, hit-test
  tap→traccia, marker, bussola/rotazione, cursore profilo→mappa
- ⏱️ alto · rischio: medio-alto

### Opzione B — Ibrido: 2D per l'editing + vista 3D dedicata (CONSIGLIATO)
Si **tiene** `flutter_map` per disegno/modifica (tutto già funziona) e si
**aggiunge una schermata 3D** (sola visualizzazione) con `mapbox_maps_flutter`:
terreno 3D + stile Outdoors + la traccia selezionata, con pitch/rotazione.
- ✅ **additivo, basso rischio**: non si tocca nulla di funzionante
- ✅ dà subito l'effetto "wow" 3D alla Suunto (che è comunque una vista a sé)
- ✅ riusa il DEM e le tracce esistenti
- ❌ due motori mappa nel progetto (più dipendenze); 3D non per l'editing
- ⏱️ medio-basso · rischio: basso

### Opzione C — Restare 2D
Niente 3D. Zero costo/rischio. (Scartabile: l'utente vuole il 3D.)

## 5. Mappatura feature → motore GL (per Opzione A, o futura)

| Feature attuale (flutter_map) | Equivalente GL |
|---|---|
| `TileLayer` base + muted filter | raster layer / **stile vettoriale** (colori nativi, niente filtro) |
| Polilinea traccia (dash + casing) | line layer (`line-dasharray` + `line-gap-width`) — più pulito |
| Rete sentieri vettoriale | GeoJSON source + line layer |
| Marker start/end, user, waypoint | symbol / point annotations |
| Drag waypoint (`DragMarkers`) | annotation **draggable** (supportato) |
| Tap→aggiungi/seleziona traccia | `onTap` + proiezione schermo↔latlng / `queryRenderedFeatures` |
| Bussola / "nord su" / rotazione | nativo (bearing + compass) |
| Cursore profilo→punto in mappa | update annotation |
| Attribuzione | nativa |

Nessun blocco tecnico: tutto ha un equivalente. Il costo è **tempo di
riscrittura e ri-test**, non fattibilità.

## 6. Setup `mapbox_maps_flutter` (una tantum)

- Token **pubblico** a runtime (riusiamo `MAPBOX_TOKEN` già in uso).
- **Secret download token** (scope `Downloads:Read`) per scaricare l'SDK nativo
  (gradle.properties / `.netrc`) — passo di configurazione build, da fare una volta.
- `pod install` / gradle sync (rebuild nativo completo).

## 7. Raccomandazione

1. **Partire con l'Opzione B (ibrido).** Aggiungere una **vista 3D** con
   `mapbox_maps_flutter`: pulsante "3D" sulla traccia selezionata → schermata con
   terreno 3D + Outdoors + traccia. Basso rischio, riusa tutto, effetto Suunto
   immediato. Lo stesso token Mapbox basta.
2. **Rivalutare l'Opzione A più avanti**, solo se il 3D diventa centrale anche
   nell'editing: a quel punto la migrazione totale a `mapbox_maps_flutter` (un
   solo motore) ha senso, sapendo che il dominio non va toccato.

## 8. Domande aperte prima di implementare la B

- DEM per il 3D: **terreno Mapbox** (`mapbox-terrain-dem-v1`, semplice, dentro lo
  stesso account) o **Terrarium** nostro (zero dipendenze extra, ma più lavoro)?
- Cosa mostra la vista 3D: solo la traccia selezionata, o anche la rete sentieri?
- Punto d'ingresso UI: pulsante "3D" nella card della traccia? nella barra?
- Esborso: confermato che 25k MAU/mese gratis bastano (uso personale) → sì.
