# CLAUDE.md — Sentèi

> **Nome visualizzato:** `Sentèi` (sentieri in dialetto piemontese).
> **Nome tecnico** (repository, package, bundle id, codice): `sentei` — senza accento.

> Documento di riferimento per lo sviluppo con Claude Code.
> **Sentèi** — app per l'escursionismo che replica le funzionalità di base di **GaiaGPS**,
> focalizzato sulle **Alpi del Nord Italia** e le zone di confine con **Francia** e **Svizzera**.

---

## 1. Visione del prodotto

Un'app mobile (iOS + Android) per escursionisti che permette di:

1. Visualizzare mappe topografiche con **sentieri affidabili** (rete CAI / FFRandonnée / SAC).
2. **Disegnare tracciati** seguendo i sentieri, con calcolo di **distanza** e **dislivello** (D+/D-).
3. **Salvare** i tracciati creati.
4. **Esportare/importare GPX**.
5. **Sincronizzare** i tracciati sul cloud personale dell'utente (**iCloud Drive** e **Google Drive**).
6. Funzionare **offline** (priorità alta: in montagna spesso non c'è segnale).

Non-obiettivi (per ora): social/condivisione tra utenti, navigazione turn-by-turn vocale,
meteo, tracking di attività fitness avanzato.

---

## 2. Decisioni architetturali (già prese)

| Ambito | Scelta | Motivazione |
|---|---|---|
| Framework | **Flutter** (Dart) | Un solo codebase iOS+Android, ottimo ecosistema mappe. |
| Rendering mappa | **`mapbox_maps_flutter`** (Mapbox GL) — *migrato da `flutter_map`* | Serve il **3D del terreno** (alla Suunto) col gesto nativo a due dita + stile vettoriale **Outdoors** + un solo motore. Migrazione completata (5 fasi) e **validata su iPhone**; `flutter_map` rimosso. Logica di dominio invariata (era engine-agnostica). Token: `--dart-define=MAPBOX_TOKEN=pk...` (runtime) + secret download token in `~/.netrc` e `~/.gradle/gradle.properties`. Vedi `docs/plan-mapbox-gl-migration.md`. |
| Sorgenti mappa | **OpenStreetMap / OpenTopoMap** (base) + **SwissTopo** (CH) + **IGN** (FR) | Copertura sentieri alpina eccellente; topografiche ufficiali nelle zone di confine. |
| Overlay sentieri | **Waymarked Trails (hiking)** | Evidenzia i percorsi escursionistici segnati. |
| Offline | **Essenziale dalla v1** | Caching tile per area + elevazione offline + (fase 2) routing offline. |
| Cloud | **File GPX/JSON su iCloud Drive + Google Drive** | Nessun backend da mantenere, privacy massima, costi zero. |
| Storage locale | **SQLite (`drift`)** per metadati + file GPX su filesystem | Lista tracciati veloce, file standard esportabili. |

> ⚠️ Queste scelte sono fissate. Se emergono motivi per cambiarle, **discuterne prima** di rifattorizzare.

---

## 3. Stack tecnico e pacchetti chiave

```yaml
# Mappa & geo
mapbox_maps_flutter:         # rendering mappa (Mapbox GL): vettoriale + 3D terreno
latlong2:                    # coordinate / distanze (dominio engine-agnostico)
geolocator:                  # posizione GPS (foreground; background in fase 2)
# (ex flutter_map / flutter_map_dragmarker: RIMOSSI con la migrazione a Mapbox GL)
# offline aree: usare l'OfflineManager di Mapbox (non più FMTC) — vedi Step 6

# Tracciati & elevazione
gpx:                         # parsing/generazione file GPX
image:                       # decodifica PNG tile Terrarium (lettura pixel)
http:                        # fetch tile Terrarium (online; offline via FMTC in 1.F)
# (decoder Terrarium custom per l'elevazione — vedi §6; implementato)

# Persistenza
drift + sqlite3:             # DB metadati tracciati
path_provider:               # percorsi filesystem
shared_preferences:          # impostazioni utente

# Cloud
icloud_storage:              # iCloud Drive (iOS)
google_sign_in + googleapis: # Google Drive (Android/iOS)
share_plus / file_picker:    # condivisione/import GPX via "File"

# UI/stato
flutter_riverpod:            # state management (scelto — §10), API Notifier
go_router:                   # routing
```

> Verificare sempre l'ultima versione stabile su pub.dev e la compatibilità con la
> versione corrente di Flutter prima di aggiungere un pacchetto.

---

## 4. Sorgenti dati mappa (URL + licenze)

**Rispettare SEMPRE le fair-use policy e l'attribuzione.** Niente download massivo aggressivo
delle tile; il download offline deve essere limitato per area e con rate limiting.

| Sorgente | Tipo | URL template | Licenza / note |
|---|---|---|---|
| OpenTopoMap | raster XYZ | `https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png` | © OpenTopoMap (CC-BY-SA). Attribuzione obbligatoria, fair use. |
| OSM standard | raster XYZ | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | Usage policy restrittiva: NON per download di massa. Solo base/fallback. |
| Waymarked Trails (hiking) | overlay XYZ | `https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png` | Overlay percorsi escursionistici segnati. |
| OSM2CAI / INFOMONT (numeri sentiero) | REST GeoJSON | `https://osm2cai.cai.it/api/geojson/hiking_routes/bounding_box` | Catasto ufficiale REI (CAI + Wikimedia Italia), licenza **ODbL**. Solo Italia. Espone `ref` CAI/REI validati. Vedi `docs/osm2cai-investigation.md`. |
| SwissTopo (pixelkarte) | WMTS | `https://wmts.geo.admin.ch/1.0.0/ch.swisstopo.pixelkarte-farbe/default/current/3857/{z}/{x}/{y}.jpeg` | Gratuito per uso non commerciale, vincoli di licenza geo.admin.ch. |
| IGN (Plan IGN / Géoplateforme) | WMTS | `https://data.geopf.fr/wmts?...&LAYER=GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2&...` | Géoplateforme open. SCAN 25 topografico ha condizioni più restrittive — verificare. |
| Terrain RGB (elevazione) | raster XYZ | `https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png` | DEM SRTM/Copernicus codificato Terrarium — cacheabile offline per il dislivello. |

**Architettura sorgenti:** layer base selezionabile dall'utente (OpenTopoMap / SwissTopo / IGN
in base alla zona) + overlay opzionale Waymarked Trails. SwissTopo e IGN sono in proiezione
Web Mercator (EPSG:3857) → compatibili con flutter_map senza riproiezione complessa.

---

## 5. Struttura del progetto (proposta)

```
lib/
  main.dart
  app/                  # bootstrap, routing, tema
  core/                 # costanti, errori, util geo, licenze/attribuzioni
  data/
    map_sources/        # definizione TileLayer per ogni sorgente (§4)
    offline/            # gestione download aree (FMTC), elevazione offline
    storage/            # drift DB, repository tracciati
    cloud/              # adapter iCloud + Google Drive (interfaccia comune)
    gpx/                # import/export GPX
  domain/
    models/             # Track, Waypoint, Route, MapRegion...
    services/           # calcolo distanza/dislivello, routing, snapping
  features/
    map/                # schermata mappa principale
    draw_route/         # disegno tracciato (tap-to-add, snap-to-trail)
    tracks_list/        # libreria tracciati salvati
    track_detail/       # dettaglio + profilo altimetrico + export
    offline_maps/       # gestione mappe scaricate
    settings/           # account cloud, sorgente mappa, unità
  ui/                   # widget condivisi (profilo altimetrico, ecc.)
test/
```

---

## 6. Sfide tecniche e approccio scelto

### 6.1 Offline (priorità alta)
- **Tile offline:** usare **FMTC** per scaricare per *bounding box / area su mappa* a range di zoom
  definiti. Mostrare dimensione stimata e barra di avanzamento. Rispettare rate limit.
- **Elevazione offline:** scaricare e cachare le tile **Terrarium (terrain-RGB)** per l'area.
  Decodifica: `elevation = (R * 256 + G + B / 256) - 32768` (metri). Da questo si calcolano
  D+/D- e il profilo altimetrico **senza rete**.
- **Routing offline:** è la parte più complessa → **rinviato a Fase 2** (vedi §7). In MVP il
  disegno è manuale (tap-to-add waypoint) con distanza/dislivello dal polilinea.

### 6.2 Disegno tracciati + "snap-to-trail"
- **MVP:** l'utente tocca la mappa per aggiungere waypoint; il tracciato è la polilinea tra i punti.
  Distanza = somma haversine; dislivello = derivato dal profilo Terrarium campionato lungo il path.
- **Snap-to-trail (IMPLEMENTATO, anticipato da Fase 2 su richiesta utente):** i waypoint vengono
  instradati lungo i sentieri OSM.
  - *Online (scelto):* **BRouter** servizio web pubblico (`https://brouter.de/brouter`, profilo
    `hiking-mountain`, formato GeoJSON, **senza API key**). Restituisce geometria + `track-length`
    + `filtered ascend` + quota per punto. Implementazione: `data/routing/brouter_routing_service.dart`
    dietro l'interfaccia `domain/services/routing_service.dart`. **Fallback a linea retta** su errore.
  - *Offline (Fase 2):* stesso motore **BRouter** embedded (segment files) — coerenza con l'online.
  - *Catena profili:* `hiking-mountain → trekking`. Alcuni segmenti alpini fanno esplodere la
    ricerca dei profili `hiking-*` (il server pubblico li uccide col watchdog ~8s); `trekking`
    li calcola comunque seguendo i sentieri. Fallback a linea retta solo se entrambi falliscono.
  - *Alternative valutate:* GraphHopper/Valhalla/OpenRouteService (richiedono API key) — tenute di
    riserva se la reliability del servizio pubblico BRouter non basta.
- **Numeri sentieri (ref CAI):** non disponibili da BRouter → recuperati dietro l'interfaccia comune
  `TrailService` (`data/trails/`, template method: segmentazione punto→sentiero condivisa, le
  sottoclassi forniscono solo `fetchRelations`). Strategia combinata (`CombinedTrailService`):
  - *Primario:* **OSM2CAI / INFOMONT** (`Osm2CaiTrailService`), catasto ufficiale CAI+Wikimedia Italia
    (open ODbL). `POST /api/geojson/hiking_routes/bounding_box` (`osm2cai_status=1,2,3,4`), preferenza
    `ref` CAI → `ref_REI` → `ref_osm`. Espone il ref anche dove il tag OSM grezzo manca (es. Valle d'Aosta).
    **Solo Italia.** Indagine endpoint: `docs/osm2cai-investigation.md`.
  - *Fallback:* **Overpass API** (`OverpassTrailService`, relazioni `route=hiking` vicine → tag `ref`),
    copre l'intero arco alpino incluse le zone di confine FR/CH dove OSM2CAI non arriva.
  Risultato mostrato come chip + banda per-tratto (`TrailSegment`).

### 6.3 Calcolo distanza/dislivello
- Distanza: haversine cumulativo su punti densificati (interpolazione ogni ~10-25 m).
- Dislivello: campionare l'elevazione lungo il path con **filtro/smoothing** (es. soglia di
  risalita minima ~5-10 m) per evitare D+ gonfiato dal rumore del DEM. Documentare l'algoritmo.

### 6.4 GPX
- Export: track (`<trk>`) + eventuali waypoint, con elevazione e nome. Pacchetto `gpx`.
- Import: parsing GPX di terzi (gestire tag mancanti, multi-segmento).

### 6.5 Cloud (iCloud + Google Drive)
- Definire un'interfaccia comune `CloudSyncService` con due implementazioni:
  - **iCloud:** `icloud_storage` (container iCloud dedicato).
  - **Google Drive:** `google_sign_in` + `googleapis` (cartella dedicata o `appDataFolder`).
- Modello sync semplice: i tracciati sono file (`.gpx` + sidecar `.json` di metadati);
  conflitti risolti con "last write wins" + timestamp. Niente merge complesso in v1.
- **iCloud richiede capability/entitlement** nel progetto Xcode + Apple Developer account.

---

## 7. Roadmap a fasi

**Fase 0 — Setup**
- Init progetto Flutter, struttura cartelle, linting, CI base.
- Schermata mappa con OpenTopoMap + selettore sorgente (SwissTopo/IGN) + overlay Waymarked Trails.
- Attribuzioni/licenze visibili in mappa.

**Fase 1 — MVP usabile**
- Posizione GPS utente sulla mappa.
- Disegno tracciato manuale (tap-to-add, undo, drag punti).
- Calcolo distanza + dislivello (elevazione Terrarium) + profilo altimetrico.
- Salvataggio locale (drift) + export/import GPX.
- Download area offline (tile + terrain) con gestione spazio.

**Fase 2 — Cloud & routing intelligente**
- Sync iCloud Drive + Google Drive.
- Snap-to-trail (GraphHopper online → BRouter offline).
- Registrazione traccia live (background location).

**Fase 3 — Rifiniture**
- Gestione cartelle/cartografia per zona, ricerca località, waypoint con icone, statistiche.

> Costruire **end-to-end la Fase 1** prima di ottimizzare. Ogni feature: modello → repository →
> servizio → UI, con test sulla logica geo (distanza/dislivello/GPX).

---

## 8. Comandi ed esecuzione

```bash
flutter pub get              # installa dipendenze
flutter run                  # avvia su device/simulatore connesso
flutter run -d <id>          # device specifico (flutter devices per la lista)
flutter test                 # esegue i test
flutter analyze              # linting/analisi statica
flutter build apk            # build Android
flutter build ipa            # build iOS (richiede Xcode + account Apple)
dart format .                # formattazione
```

### Ambiente (stato attuale macOS)
- **Flutter 3.44.2** (stabile). ⚠️ Il `dart` sul PATH è quello di Homebrew (diverso da quello di Flutter):
  per i tool usare **`flutter pub run ...`**, NON `dart run ...` (altrimenti "Flutter SDK not available").
- Dispositivi noti: **simulatore iPhone 17 Pro** UDID `5315265D-7156-4526-BBD3-6E3691BB49CC`
  (⚠️ l'UDID cambia a ogni ricreazione del simulatore: se "No supported devices", rilanciare
  `flutter devices` / `xcrun simctl list devices available`);
  **iPhone fisico** id `00008150-001C25243C20401C` (via cavo; firma: team Apple ID già configurato in Xcode,
  bundle id `com.mattiacuratitoli.sentei`).

### Avviare il simulatore e l'app
```bash
xcrun simctl boot 5315265D-7156-4526-BBD3-6E3691BB49CC   # avvia il simulatore (se spento)
open -a Simulator
flutter run -d 5315265D-7156-4526-BBD3-6E3691BB49CC      # build + install + run
# Sul telefono fisico: collegare via cavo, poi: flutter run -d 00008150-001C25243C20401C
```
> **Hot reload:** in una sessione interattiva si usa `r`. In esecuzioni NON interattive (output reindirizzato)
> il segnale di reload **termina** il processo: dopo una modifica Dart **rilanciare `flutter run`** (build in cache, ~10–20s).
> Le modifiche a **plugin nativi** (es. geolocator, drift, file_selector) richiedono un rebuild completo (pod install).

### Codegen e asset
```bash
flutter pub run build_runner build           # rigenera drift (lib/data/storage/app_database.g.dart)
flutter pub run flutter_launcher_icons       # rigenera icone app (sorgente: branding/appstore.png)
flutter pub run flutter_native_splash:create # rigenera splash (sorgente: branding/splash.png)
```

---

## 9. Convenzioni di codice

- **Dart/Flutter style** ufficiale; `flutter analyze` deve passare pulito prima di un commit.
- Logica di dominio (geo, GPX, calcoli) **separata dalla UI** e **coperta da test** — è il cuore
  dell'app e deve essere deterministica.
- Niente chiavi API o segreti nel repo: usare `--dart-define` / file non versionati.
- Ogni nuova sorgente mappa va aggiunta in `data/map_sources/` con la sua **attribuzione**.
- Commit piccoli e tematici. Messaggi in italiano o inglese, ma coerenti.

---

## 10. Questioni aperte (da decidere durante lo sviluppo)

- [x] **State management:** **Riverpod** scelto (API `Notifier`/`NotifierProvider`) + `go_router`.
- [x] **Toolchain:** Flutter aggiornato a **3.44.2** in Fase 0 (Riverpod 2→3, flutter_map 7→8, go_router→17).
- [ ] **Bundle id** definitivo (proposta: `com.mattiacuratitoli.sentei`). Nome app: `Sentèi` (display), `sentei` (tecnico) ✓.
- [ ] **IGN SCAN 25:** verificare se la licenza topografica dettagliata è utilizzabile o se usare Plan IGN.
- [~] **Routing:** snap-to-trail **online** fatto con BRouter pubblico. Resta da confermare la fattibilità **BRouter embedded offline** in Flutter (Fase 2) e la reliability del servizio pubblico.
- [ ] **Apple Developer Program** (99€/anno) necessario per iCloud + distribuzione iOS reale.
- [ ] **Google Cloud project** + OAuth consent per Google Drive.
- [~] **Smoothing del dislivello:** implementato filtro a soglia deadband (default 8 m, `ElevationCalculator`). Da **validare con tracce reali**; zoom DEM Terrarium a z13 da verificare.

---

## 11. Note legali / licenze (importante)

- **Attribuzione obbligatoria** per OSM, OpenTopoMap (CC-BY-SA), SwissTopo, IGN: mostrarla in mappa.
- **Niente download massivo** delle tile OSM standard (vietato dalla usage policy).
- SwissTopo e IGN sono **gratuite ma per uso non commerciale / con condizioni**: se in futuro
  l'app diventasse a pagamento, **rivedere le licenze**.
- **Sentèi** è un progetto personale ispirato a GaiaGPS, **non** ne riusa codice o dati proprietari.

---

## 12. Stato di avanzamento (snapshot — giugno 2026)

> Dettaglio e prossimi passi in `docs/ROADMAP.md` (vedi "🚀 Ripartenza rapida" in cima).

**Implementato e testato (iPhone + simulatore):**
- **Mappa** multi-sorgente + overlay sentieri; **GPS** (`geolocator`); bussola, scelta mappa e toggle sentieri in Impostazioni.
- **Disegno multi-traccia** con **snap-to-trail**: BRouter pubblico, **routing per-segmento** con retry e
  **catena profili `hiking-mountain → trekking`** (alcuni segmenti alpini mandano in crisi i profili `hiking-*`);
  fallback a linea retta solo se tutto fallisce.
- **Dislivello D+/D-** (DEM Terrarium, smoothing deadband) + **profilo altimetrico** con scrubbing
  (evidenzia il punto in mappa) e **banda numeri sentiero CAI** sull'asse X.
- **Numeri sentieri** via `TrailService` combinato: **OSM2CAI** (catasto ufficiale CAI/REI) primario +
  **Overpass** (relazioni `route=hiking`) fallback per le zone di confine: elenco (chip) + per-tratto (`TrailSegment`).
  Esposto anche il **grado di difficoltà CAI** (T/E/EE/EEA, `cai_scale`): banda nel grafico + **chip di sintesi**
  nella card (tratto più impegnativo, `lib/ui/cai_difficulty.dart`).
- **Card traccia** (`draw_route_controls.dart`): in **creazione** minimale (nome/colore/annulla-undo-Salva);
  al **Salva** resta aperta con spinner finché i dati non ci sono (`finishDrawing` seleziona la traccia); in
  **selezione** distanza/D+/D-/segnavia/difficoltà + profilo on-demand. **Backfill lazy** dei segnavia/difficoltà
  alla selezione per le tracce vecchie (`DrawnTrack.trailsResolved`, colonna drift, `schemaVersion` 2). I servizi
  segnavia **lanciano `TrailLookupException`** su errore (rete/timeout/non-200) e ritornano vuoto solo su risposta
  valida: così `trailsResolved` distingue "cercato e non trovato" da "ricerca fallita" (retry). Migrazione
  `schemaVersion` 3: sblocca le tracce risolte a vuoto dal vecchio comportamento.
- **Persistenza locale** `drift`/SQLite (`data/storage/`), lista tracciati ordinabile/ricercabile, **export/import GPX** (`gpx`, `file_selector`, `share_plus`).
- **UI:** palette blu (seed `#1565C0`), font **Lato**, **barra flottante in basso**, logo+splash (sorgenti in `branding/`).

**Pacchetti chiave aggiunti rispetto a §3:** `flutter_map_dragmarker`, `image`, `http`, `geolocator`,
`drift`+`drift_flutter`, `gpx`, `file_selector`, `share_plus`, `path_provider`, `google_fonts`,
dev: `drift_dev`, `build_runner`, `flutter_launcher_icons`, `flutter_native_splash`.

**Sync cloud (Google Drive) — FATTO, da testare col setup OAuth dell'utente:** interfaccia comune
`CloudSyncService` + serializzazione condivisa `TrackCodec` + motore last-write-wins `computeSyncPlan`
(testato) + backend `GoogleDriveSyncService` (`google_sign_in` v7 + `googleapis` Drive v3, scope `drive.file`,
cartella "Sentèi", `<id>.json` + `<id>.gpx`). UI in Impostazioni. Credenziali via `--dart-define=GOOGLE_CLIENT_ID`.
Setup: `docs/cloud-google-drive-setup.md`. **Snap-to-trail sempre attivo** (toggle "Segui sentieri" rimosso).

**Servizi/architettura principali:**
`data/routing/brouter_routing_service.dart` (RoutingService) · `data/trails/` (numeri sentiero:
`trail_service.dart` interfaccia + segmentazione condivisa, `osm2cai_trail_service.dart` primario,
`overpass_trail_service.dart` fallback, `combined_trail_service.dart` strategia) ·
`data/offline/terrarium_*` (elevazione) · `data/storage/` (drift + repository + `TrackCodec`) ·
`data/cloud/` (sync: interfaccia + Google Drive) · `data/gpx/gpx_service.dart` (export = percorso instradato
densificato con quota) · `features/draw_route/route_editor_provider.dart` (stato multi-traccia `Tracks`) ·
`features/map_gl/map_gl_screen.dart` (UI mappa Mapbox GL + barra) · `features/settings/` (UI sync cloud).

**Distribuzione (giu 2026):**
- **iOS:** beta **live su TestFlight** (build `1.0.0+2`, tester esterni approvati). Privacy policy su GitHub Pages, repo pubblico. Guide: `docs/testflight-setup.md`, `docs/testflight-amici.md`.
- **Android:** **APK sideload generato** (`app-release.apk`, debug-signed). Toolchain migrata a **Gradle 9.1 / AGP 9.0.1 / Kotlin 2.3.20 / Java 17** + `compileSdk=36` forzato sui moduli. Guida: `docs/android-apk-setup.md`.

**Da fare (priorità):**
1. **Verifiche sul device fisico:** download mappe/elevazione offline in modalità aereo; ricerca luoghi e focus-traccia (UI nuove).
2. **Drive su Android** (manca client OAuth + SHA-1) + APK `--split-per-abi` per file più leggeri.
3. *Rimandati:* **bundling font** offline; **registrazione traccia live** (background, Fase 2).

> **Nota IGN/multi-sorgente:** OBSOLETO dopo la migrazione a Mapbox GL (mappa = singolo stile Mapbox).
