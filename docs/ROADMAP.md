# Roadmap di implementazione — Sentèi

> Documento operativo che traduce il `CLAUDE.md` (visione/decisioni) in **passi concreti**,
> **informazioni da recuperare** e **quesiti aperti** da sciogliere durante lo sviluppo.
> Aggiornare man mano che le decisioni vengono prese.

---

## Stato attuale

✅ **Fase 0 — scheletro (fatto):**
- Progetto Flutter inizializzato (`org: com.mattiacuratitoli`, `name: sentei`, piattaforme iOS+Android).
- Struttura cartelle `lib/` come da §5 del CLAUDE.md.
- State management deciso: **Riverpod** (API moderna `Notifier`/`NotifierProvider`) + `go_router`. *Reversibile se si preferisce bloc.*
- Catalogo sorgenti mappa (`data/map_sources/`): OpenTopoMap, SwissTopo, IGN Plan, OSM, overlay Waymarked Trails — con attribuzioni.
- Schermata mappa funzionante: layer base selezionabile + toggle overlay sentieri + box attribuzione.
- Modelli di dominio stub (`Track`, `TrackPoint`).
- **Toolchain aggiornata**: Flutter **3.44.2** (giugno 2026). `flutter analyze` pulito.

✅ **Fase 1.C — logica geo (completa, lato dominio):**
- `PathGeometry` (`domain/services/path_geometry.dart`): distanza haversine cumulativa + densificazione a passo.
- `ElevationCalculator` (`domain/services/elevation_calculator.dart`): D+/D- con filtro a soglia (deadband) anti-rumore DEM.
- `Terrarium.decodeElevation` (`data/offline/terrarium.dart`): decoder pixel→quota.
- `TileMath` (`core/util/tile_math.dart`): coordinate↔tile/pixel Web Mercator.
- `ElevationService` (interfaccia) + `TerrariumElevationService` (`data/offline/`): campionamento quota da tile, fetcher iniettabile + cache LRU. Fetcher HTTP di default in `terrarium_http_fetcher.dart`.
- `ElevationProfile` (`domain/models/`): builder distanze cumulate + min/max.
- `ElevationProfileChart` (`ui/`): widget grafico profilo (CustomPainter).
- `TrackMetricsCalculator` (`domain/services/track_metrics.dart`): orchestratore distanza + D+/D- + profilo in una chiamata.
- **28 test verdi** (`test/domain/`).
- **Manca per "chiudere" 1.C nell'app**: agganciare il fetcher alla cache offline FMTC (→ 1.F) e mostrare metriche+grafico in `track_detail` (dipende da 1.B/1.D).

✅ **Fase 1.B — disegno tracciato (fatto):** vedi sezione 1.B sotto. Tap-to-add, undo, drag, eliminazione, distanza live, D+/D- + profilo on-demand.

✅ **Snap-to-trail (anticipato da Fase 2 su richiesta utente):** i tap sono **waypoint**; il percorso effettivo segue i sentieri OSM via **BRouter** (servizio web pubblico, profilo `hiking-mountain`, no API key). Fallback a linea retta se il routing non è disponibile; toggle "Segui sentieri" (default ON). File: `domain/services/routing_service.dart`, `data/routing/brouter_routing_service.dart`, `routedPathProvider`. **Testato sul parser**; da provare sul campo.

> **Feedback utente (priorità):** (a) ✅ migliorare la tracciatura → snap-to-trail; (b) ⏭️ posizione GPS utente sulla mappa; (c) ⏭️ valutare rese grafiche mappe più belle/intuitive (stile GaiaGPS) — OpenTopoMap/OSM efficaci ma esteticamente migliorabili.

✅ **Rifiniture disegno (feedback 2° test su device):** percorso multi-waypoint (continua ad aggiungere punti dopo l'ultimo); marker **partenza (verde ▶) / arrivo (rosso 🏁)** distinti; FAB "Disegna" nascosto durante il disegno (toggle nel pannello, non copre più "Dislivello"); **frecce di direzione** lungo la traccia (`DirectionArrows`, ~ogni 350 m).

✅ **Rifiniture disegno (feedback 3° test):** (1) zoom non ruota più la mappa (`enableMultiFingerGestureRace` + `rotationThreshold`); (2) **tap su un nodo lo elimina**; (3) bottone **bussola "nord in alto"** (appare quando ruotata); (4) frecce direzione più grandi/contrastate; (5) **scrubbing del profilo altimetrico** → evidenzia il punto corrispondente in mappa (`profileCursorProvider`, `ProfileSample.position`).

✅ **Fase 1.A — posizione GPS + rifiniture (feedback 4° test):** `geolocator` + `LocationService`; bottone **"La mia posizione"** (centra + marker blu), permessi iOS/Android. **Bussola** ridisegnata (ago rosso/grigio sempre visibile, tap → nord su). **Frecce** con bordo bianco netto + key anti-fantasma dopo rimozione nodo. **Modalità fullscreen** (`fullscreenProvider`): nasconde app bar e pannelli, FAB disegno sempre disponibile.

📦 **Stack risolto:** `flutter_map ^8.3.0`, `flutter_map_dragmarker ^8.0.3`, `flutter_riverpod ^3.3.2`, `go_router ^17.3.0`, `latlong2 ^0.9.1`, `image ^4.x`, `http ^1.x`, `url_launcher ^6.3.x`.

---

## Fase 0 — completamento setup

| # | Task | Note |
|---|---|---|
| 0.1 | ✅ Sistemare toolchain Flutter | Fatto: upgrade a 3.44.2, `flutter analyze` pulito |
| 0.2 | ✅ Bump Flutter + migrazione pacchetti | Fatto: Riverpod 3, flutter_map 8, go_router 17 |
| 0.3 | Configurare CI base (GitHub Actions: `flutter analyze` + `flutter test`) | §7 Fase 0 |
| 0.4 | `flutter_lints` + regole extra in `analysis_options.yaml` | §9 |
| 0.5 | Impostare bundle id definitivo in iOS/Android | `com.mattiacuratitoli.sentei` (§10) |
| 0.6 | Schermata Impostazioni minima (sorgente mappa, unità) + persistenza `shared_preferences` | |

---

## Fase 1 — MVP usabile

Ordine consigliato (ogni feature: modello → repository → servizio → UI, con **test sulla logica geo**).

### 1.A — Posizione GPS ✅
- ✅ `geolocator` (foreground) + permessi iOS (`Info.plist`) / Android (`AndroidManifest`).
- ✅ `LocationService` + `userLocationProvider` (stream posizione); marker blu + bottone "La mia posizione" (centra).
- ⏭️ Background location → Fase 2.

### 1.B — Disegno tracciato manuale ✅
- ✅ Tap-to-add waypoint, **undo**, drag dei punti (`flutter_map_dragmarker`), long-press per eliminare.
- ✅ Stato in `RouteEditor` (Riverpod) + distanza live (`routeDistanceProvider`).
- ✅ Polilinea su `flutter_map` + marker trascinabili; FAB modalità disegno.
- ✅ Pannello `DrawRouteControls`: distanza, D+/D- on-demand (usa `TrackMetricsCalculator` + DEM online) e profilo altimetrico inline.
- ⏭️ **Residuo**: salvataggio del tracciato disegnato (→ 1.D).

### 1.C — Calcolo distanza + dislivello + profilo (cuore dell'app, §6.3) ✅ (lato logica)
- ✅ **Distanza**: haversine cumulativo su punti densificati. `PathGeometry`.
- ✅ **Elevazione**: decoder Terrarium + campionamento da tile (`TerrariumElevationService`).
- ✅ **Dislivello D+/D-**: filtro a soglia deadband (default 8 m) anti-rumore DEM. `ElevationCalculator`.
- ✅ **Widget profilo altimetrico** (`ui/elevation_profile_chart.dart`) + builder `ElevationProfile`.
- ✅ **Orchestratore** `TrackMetricsCalculator` (un'unica chiamata: distanza + D+/D- + profilo).
- ✅ **Tutto deterministico e coperto da test** (28 test in `test/domain/`).
- ⏭️ **Residuo**: fetcher tile → cache offline FMTC (1.F); validare la soglia smoothing con tracce reali; cablare in `track_detail` (1.B/1.D).

### 1.D — Persistenza locale
- `drift` + `sqlite3` per metadati tracciati; file GPX su filesystem (`path_provider`).
- Repository tracciati (`data/storage/`); alimentare `tracks_list` e `track_detail`.

### 1.E — GPX import/export (§6.4)
- Pacchetto `gpx`. Export `<trk>` + waypoint con quota/nome. Import robusto (tag mancanti, multi-segmento).
- `share_plus` / `file_picker` per condivisione/import via "File".

### 1.F — Download area offline (§6.1)
- **FMTC** (`flutter_map_tile_caching`): selezione bounding box su mappa, range zoom, stima dimensione, progress, **rate limiting**.
- Caching tile Terrarium per l'area (dislivello offline).
- Schermata `offline_maps/` con gestione spazio.

---

## Fase 2 — Cloud & routing intelligente

- **Sync cloud** (§6.5): interfaccia `CloudSyncService` → impl. iCloud (`icloud_storage`) + Google Drive (`google_sign_in` + `googleapis`). Modello file `.gpx` + sidecar `.json`, conflitti "last write wins".
- **Snap-to-trail**: online **GraphHopper** profilo `hike`/`foot`; offline **BRouter** (valutare embedding).
- **Registrazione traccia live** (background location).

## Fase 3 — Rifiniture
- Cartelle/cartografia per zona, ricerca località, waypoint con icone, statistiche.

---

## Informazioni da recuperare (ricerca/verifica)

| Tema | Cosa verificare | Quando |
|---|---|---|
| **IGN** | URL WMTS Géoplateforme esatto + se `PLANIGNV2` o serve `WMTS GetCapabilities`; condizioni SCAN 25 | F0/F1 (testare le tile sul device) |
| **SwissTopo** | Conferma fair-use uso non commerciale + eventuale API key / referer richiesto | F0/F1 |
| **OpenTopoMap** | Limiti fair-use precisi per download offline (rate) | F1.F |
| **Terrarium** | Disponibilità/zoom della copertura sulle Alpi; precisione DEM per il D+ | F1.C |
| **GraphHopper** | Free tier, limiti, chiave API; alternativa Valhalla | F2 |
| **BRouter** | Fattibilità reale embedded in Flutter (segment files, dimensioni) | F2 |
| **iCloud** | Entitlement + container; richiede **Apple Developer Program (99€/anno)** | F2 |
| **Google Drive** | Progetto Google Cloud + OAuth consent screen + scope `appDataFolder` | F2 |
| **Pacchetti** | Ultima versione stabile e compatibilità con la versione Flutter scelta (pub.dev) | ogni `pub add` |

---

## Quesiti aperti (decisioni da prendere)

- [x] **Aggiornare Flutter?** Fatto: bump a 3.44.2 in Fase 0 (Riverpod 2→3, flutter_map 7→8, go_router→17 migrati).
- [x] **State management**: Riverpod ✓ (API `Notifier`/`NotifierProvider`).
- [~] **Algoritmo smoothing dislivello**: implementato filtro a soglia deadband (default 8 m). Da **validare con tracce GPX reali** ed eventualmente affinare (media mobile / soglia adattiva).
- [ ] **Densificazione path**: passo fisso 15 m di default — valutare passo adattivo alla pendenza.
- [ ] **Zoom DEM**: campionamento Terrarium a z13 di default — verificare precisione D+ vs z14/15 sulle Alpi.
- [ ] **Modello sync cloud**: solo file vs indice; gestione conflitti oltre "last write wins"?
- [ ] **IGN SCAN 25** topografico utilizzabile o ripiegare su Plan IGN.
- [ ] **Routing offline BRouter**: confermare fattibilità prima di impegnarsi (F2).
- [ ] **Distribuzione iOS**: Apple Developer Program necessario per iCloud + TestFlight.
- [ ] **Unità di misura / localizzazione**: solo metrico? UI in italiano + i18n?

---

## Principio guida (dal CLAUDE.md §7)

> Costruire **end-to-end la Fase 1** prima di ottimizzare. La logica geo (distanza, dislivello, GPX)
> è il cuore dell'app: **separata dalla UI** e **coperta da test deterministici**.
