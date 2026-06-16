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

🟡 **Fase 1.C — logica geo (parzialmente fatto):**
- `PathGeometry` (`domain/services/path_geometry.dart`): distanza haversine cumulativa + densificazione a passo.
- `ElevationCalculator` (`domain/services/elevation_calculator.dart`): D+/D- con filtro a soglia (deadband) anti-rumore DEM.
- `Terrarium.decodeElevation` (`data/offline/terrarium.dart`): decoder pixel→quota.
- `ElevationService` (`domain/services/elevation_service.dart`): **interfaccia** per il campionamento quota (impl. tile rinviata a 1.F).
- 17 test verdi (`test/domain/`).
- **Manca**: implementazione concreta `ElevationService` (download/decode tile, in 1.F) e widget profilo altimetrico (`ui/`).

📦 **Stack risolto:** `flutter_map ^8.3.0`, `flutter_riverpod ^3.3.2`, `go_router ^17.3.0`, `latlong2 ^0.9.1`, `url_launcher ^6.3.x`.

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

### 1.A — Posizione GPS
- Pacchetto `geolocator` (foreground). Permessi iOS (`Info.plist`) + Android (`AndroidManifest`).
- Marker posizione + bottone "centra su di me".

### 1.B — Disegno tracciato manuale
- Tap-to-add waypoint, **undo**, drag dei punti, eliminazione.
- Provider Riverpod per lo stato del tracciato in editing.
- Polilinea su `flutter_map` (`PolylineLayer` + `MarkerLayer`).

### 1.C — Calcolo distanza + dislivello + profilo (cuore dell'app, §6.3)
- **Distanza**: haversine cumulativo su punti densificati (interpolazione ~10–25 m). `latlong2`.
- **Elevazione**: decoder Terrarium custom → `elevation = (R*256 + G + B/256) - 32768`.
- **Dislivello D+/D-**: campionamento lungo il path + **smoothing** (soglia ~5–10 m) per non gonfiare il D+ col rumore DEM.
- **Widget profilo altimetrico** in `ui/`.
- 🔴 **Tutto deterministico e coperto da test** (`test/domain/`).

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
- [ ] **Algoritmo smoothing dislivello**: soglia fissa vs filtro (es. media mobile / Douglas-Peucker su quota) — validare con tracce GPX reali.
- [ ] **Densificazione path**: passo fisso (10/25 m) vs adattivo alla pendenza.
- [ ] **Modello sync cloud**: solo file vs indice; gestione conflitti oltre "last write wins"?
- [ ] **IGN SCAN 25** topografico utilizzabile o ripiegare su Plan IGN.
- [ ] **Routing offline BRouter**: confermare fattibilità prima di impegnarsi (F2).
- [ ] **Distribuzione iOS**: Apple Developer Program necessario per iCloud + TestFlight.
- [ ] **Unità di misura / localizzazione**: solo metrico? UI in italiano + i18n?

---

## Principio guida (dal CLAUDE.md §7)

> Costruire **end-to-end la Fase 1** prima di ottimizzare. La logica geo (distanza, dislivello, GPX)
> è il cuore dell'app: **separata dalla UI** e **coperta da test deterministici**.
