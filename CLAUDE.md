# CLAUDE.md — Sentèi

> **Nome visualizzato:** `Sentèi` (sentieri in dialetto piemontese).
> **Nome tecnico** (repository, package, bundle id, codice): `sentei` — senza accento.

> Documento di riferimento per lo sviluppo con Claude Code.
> **Sentèi** — app per l'escursionismo che replica le funzionalità di base di **GaiaGPS**,
> focalizzata sulle **Alpi del Nord Italia** e le zone di confine con **Francia** e **Svizzera**.
>
> ⚠️ **Questo repository è pubblico.** Non aggiungere qui (né altrove nel repo) token, chiavi
> API, ID dispositivo, credenziali o altri dati personali/sensibili — vedi §9.

## 1. Visione del prodotto

App mobile (iOS + Android) per escursionisti:

1. Mappe topografiche con **sentieri affidabili** (rete CAI / FFRandonnée / SAC).
2. **Disegno tracciati** lungo i sentieri, con **distanza** e **dislivello** (D+/D-).
3. **Salvataggio** dei tracciati.
4. **Export/import GPX**.
5. **Sync cloud** personale (**iCloud Drive** e **Google Drive**).
6. **Offline** (priorità alta: in montagna spesso non c'è segnale).

Non-obiettivi (per ora): social/condivisione, navigazione turn-by-turn vocale, meteo, fitness tracking avanzato.

## 2. Decisioni architetturali (già prese)

| Ambito | Scelta | Motivazione |
|---|---|---|
| Framework | **Flutter** (Dart) | Un solo codebase iOS+Android, ottimo ecosistema mappe. |
| Rendering mappa | **`mapbox_maps_flutter`** (Mapbox GL) | Stile vettoriale **Outdoors** (+ varianti Dark/Satellite) con **terreno 3D** nativo (gesto a due dita), un solo motore. Migrato da `flutter_map` (multi-sorgente raster), rimosso. Token pubblico via `--dart-define=MAPBOX_TOKEN` — mai nel repo, vedi §8/§9. |
| Dati sentieri/segnavia | **OSM2CAI/INFOMONT** (catasto ufficiale CAI, Italia) primario + **Overpass API** (OSM `route=hiking`) fallback per le zone di confine FR/CH | Il layer sentieri della mappa lo disegna già Mapbox Outdoors; queste fonti servono per i **numeri segnavia** e il **grado di difficoltà CAI**, non per il layer visivo. |
| Elevazione | **Terrarium** (terrain-RGB, DEM SRTM/Copernicus) | Cacheabile offline, decodifica pixel→quota locale, nessuna dipendenza da un servizio a pagamento. |
| Offline | **Essenziale dalla v1** | Mappa + elevazione scaricabili per area (Mapbox OfflineManager + cache Terrarium); routing offline rimane Fase 2. |
| Cloud | **File GPX/JSON su iCloud Drive + Google Drive** | Nessun backend da mantenere, privacy massima, costi zero. |
| Storage locale | **SQLite (`drift`)** per metadati + file GPX su filesystem | Lista tracciati veloce, file standard esportabili. |
| State management | **Riverpod** (`Notifier`/`NotifierProvider`) + **go_router** | Vedi §7 per lo storico della scelta. |

> ⚠️ Queste scelte sono fissate. Se emergono motivi per cambiarle, **discuterne prima** di rifattorizzare.

## 3. Stack tecnico e pacchetti chiave

Elenco allineato a `pubspec.yaml` — quello resta la fonte di verità per le versioni esatte.

```yaml
# Mappa & geo
mapbox_maps_flutter:   # rendering mappa (Mapbox GL): vettoriale + 3D terreno
latlong2:              # coordinate/distanze (dominio engine-agnostico)
geolocator:            # posizione GPS (foreground; background = Fase 2)
# Tracciati & elevazione
gpx:                   # parsing/generazione file GPX
image:                 # decodifica PNG tile Terrarium (lettura pixel)
http:                  # fetch tile Terrarium e servizi REST (BRouter, OSM2CAI, Overpass, Nominatim)
# Persistenza
drift + drift_flutter: # DB metadati tracciati (SQLite)
path_provider:         # percorsi filesystem
shared_preferences:    # impostazioni utente (tema, ordinamento, ecc.)
# Cloud
icloud_storage:        # iCloud Drive (iOS)
google_sign_in + googleapis + extension_google_sign_in_as_googleapis_auth: # Google Drive
share_plus / file_selector: # condivisione/import GPX via "File"
# Foto lungo il percorso
photo_manager:         # accesso alla libreria foto per il matching spaziale con la traccia
# UI/stato
flutter_riverpod:      # state management, API Notifier
go_router:             # routing
package_info_plus:     # versione app (mostrata in Impostazioni)
```

> Verificare sempre l'ultima versione stabile su pub.dev e la compatibilità con Flutter prima di aggiungere un pacchetto.

## 4. Dati mappa, sentieri ed elevazione (fonti + licenze)

**Rispettare SEMPRE le fair-use policy e l'attribuzione.** Niente download massivo aggressivo
delle tile; il download offline deve essere limitato per area e con rate limiting.

| Sorgente | Ruolo | Licenza / note |
|---|---|---|
| **Mapbox** (Outdoors / Dark / Satellite) | Base mappa (unico motore, §2) | Servizio a pagamento oltre il free tier — token pubblico via `--dart-define`, mai nel repo. |
| **OSM2CAI / INFOMONT** — `https://osm2cai.cai.it/api/geojson/hiking_routes/bounding_box` | Numeri segnavia + difficoltà CAI, **solo Italia** | Catasto ufficiale REI (CAI + Wikimedia Italia), licenza **ODbL**. Indagine endpoint: `docs/osm2cai-investigation.md`. |
| **Overpass API** (relazioni OSM `route=hiking`; nodi `tourism`/`natural`/`place`/`mountain_pass`) | Numeri segnavia + difficoltà, fallback per l'intero arco alpino incl. confini FR/CH; **punti interessanti lungo il percorso** (rifugi, alpeggi, laghi, colli, cime) per l'export immagine (`data/poi/overpass_poi_service.dart`) | Dati OpenStreetMap (ODbL); rispettare i limiti di frequenza delle istanze pubbliche. |
| **Terrain RGB / Terrarium** — `https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png` | Elevazione (D+/D-, profilo altimetrico), cacheabile offline | DEM SRTM/Copernicus codificato Terrarium, riuso libero. |
| **BRouter** (servizio pubblico) — `https://brouter.de/brouter` | Snap-to-trail (routing lungo i sentieri OSM) | Nessuna API key; vedi §6.2 per la catena di profili usata. |
| **Nominatim** (OSM) | Geocoding di fallback (ricerca luoghi, reverse geocoding) | Rispettare la usage policy (rate limit, User-Agent). |
| **CAI Varallo** — `https://www.caivarallo.it/valsesia/sentieri-valsesia/sentieri-tutti.php` | Link alla scheda del segnavia sul sito della sottosezione, **solo per i sentieri in Valsesia e dintorni** (`data/trails/cai_varallo_search_service.dart`) | Match esatto per numero di catasto sull'elenco ufficiale (non ricerca full-text — un tentativo precedente su `caivarallo.com`, sito diverso, dava risultati non pertinenti). Nessuna API, solo scraping mirato di una pagina pubblica. |

> **Sorgenti storiche, non più in uso** dopo la migrazione a Mapbox GL: OpenTopoMap, SwissTopo,
> IGN, OSM raster standard, overlay raster Waymarked Trails. Dettagli in `docs/CHANGELOG-DEV.md`.

## 5. Struttura del progetto

```
lib/
  main.dart
  app/                  # bootstrap, routing (go_router), tema (chiaro/scuro, 3 varianti dark)
  core/                 # costanti, formattazione, util geo (tile math)
  data/
    routing/            # BRouter (snap-to-trail)
    trails/             # numeri segnavia + difficoltà CAI: OSM2CAI, Overpass, strategia combinata
    poi/                # punti interessanti lungo il percorso (Overpass) per l'export immagine
    offline/            # Mapbox OfflineManager + cache/decoder Terrarium (elevazione)
    storage/            # drift (SQLite) + repository tracciati + codec di serializzazione
    cloud/              # CloudSyncService: iCloud + Google Drive, motore last-write-wins
    gpx/                # import/export GPX
    search/             # geocoding (Mapbox + Nominatim)
    location/           # posizione GPS
    photos/             # libreria foto (matching spaziale) + cache anteprime, con precarico
    map_sources/        # costanti residue (template Terrarium)
  domain/
    models/             # Track, ElevationProfile, TrackPhoto, ...
    services/           # calcolo distanza/dislivello, semplificazione path, matching foto
  features/
    map_gl/             # schermata mappa principale (Mapbox GL) + info punto ispezionato
    draw_route/         # disegno/editing tracciato, azioni foto vicine, export (GPX/immagine)
    tracks_list/        # libreria tracciati salvati (ordinamento, ricerca)
    offline_maps/       # gestione mappe/elevazione scaricate
    settings/           # tema, sorgente cloud, legende, changelog/roadmap in-app
  ui/                    # chrome "vetro" iOS + design opaco per le card (design/), toast/menu,
                         # profilo altimetrico, token di design
test/
```

> Struttura indicativa: riflette l'organizzazione attuale, non un vincolo rigido. Quando una
> cartella cambia scopo in modo duraturo, aggiornarla qui.

## 6. Sfide tecniche e approccio scelto

### 6.1 Offline (priorità alta)
- **Tile mappa:** Mapbox OfflineManager + TileStore, download per bounding box a un range di zoom definito, con progress. **Elevazione:** cache disco delle tile **Terrarium**; decodifica `elevation = (R*256 + G + B/256) - 32768` (metri) → D+/D- e profilo senza rete.
- **Routing offline:** rinviato a Fase 2 (§7) — BRouter embedded (segment files), fattibilità da confermare.

### 6.2 Disegno tracciati + snap-to-trail
- Waypoint instradati sui sentieri OSM via **BRouter** (pubblico, GeoJSON, no API key), per segmento (un punto non instradabile degrada solo quel tratto a linea retta, con retry). Catena profili `hiking-mountain` → `trekking`: i profili `hiking-*` fanno esplodere alcuni segmenti alpini (il server pubblico li uccide per timeout), `trekking` li calcola comunque seguendo i sentieri; linea retta solo se entrambi falliscono. Riserva (serve API key): GraphHopper/Valhalla/OpenRouteService.
- **Numeri sentiero (ref CAI) e difficoltà:** non disponibili da BRouter → `TrailService` (`data/trails/`), strategia combinata: **OSM2CAI** primario (Italia, `ref` CAI/REI anche dove manca il tag OSM, es. Valle d'Aosta) → **Overpass** fallback (confini FR/CH). Risultato: chip + banda per-tratto (`TrailSegment`, incluso `cai_scale` T/E/EE/EEA).

### 6.3 Calcolo distanza/dislivello
- Distanza: haversine cumulativo su punti densificati (~10-25 m). Dislivello: campionamento con filtro a soglia (**deadband**, default 8 m) per evitare D+ gonfiato dal rumore del DEM — da validare con tracce reali (`docs/ROADMAP.md`).

### 6.4 GPX
- Export: percorso instradato e densificato con quota. Import: parsing di terzi + **riallineamento ibrido** ai sentieri rilevati (flusso a 2 fasi caricamento→revisione, vedi `docs/CHANGELOG-DEV.md`).

### 6.5 Cloud (iCloud + Google Drive)
- `CloudSyncService` comune, due implementazioni. Tracciati = file (`.gpx` + sidecar `.json`), conflitti risolti "last write wins" + timestamp, niente merge complesso. iCloud richiede capability/entitlement Xcode + Apple Developer Program.

### 6.6 Foto lungo il percorso
- Nessun asse temporale affidabile (il parsing GPX scarta `<time>`) → matching **spaziale**: EXIF GPS proiettato sul percorso instradato. Nessun upload dell'originale: solo GPS + timestamp + distanza-lungo-percorso + thumbnail nel JSON sincronizzato; ogni device rifà il match locale (`docs/eval-photo-sync.md`).
- Mai l'originale a piena risoluzione (48 MP ≈ 195 MB). Anteprima della misura giusta (`PhotoLibraryService.preview`), cache LRU con precarico/decodifica anticipata (`PhotoPreviewCache`), originale solo sopra 1,6× zoom. Miniature nei metadati: 200 px/q80.

## 7. Roadmap a fasi (storico + stato)

| Fase | Contenuto | Stato |
|---|---|---|
| **Fase 0** | Setup progetto, struttura cartelle, mappa base + attribuzioni | ✅ Completa |
| **Fase 1 (MVP)** | GPS, disegno + snap-to-trail, distanza/dislivello, salvataggio locale, GPX, aree offline | ✅ Completa |
| **Fase 2** | Sync cloud (iCloud + Drive) ✅, snap-to-trail online ✅ · routing offline embedded ⏳ · registrazione traccia live ⏳ | In corso |
| **Fase 3** | Rifiniture: ricerca località ✅, waypoint/foto ⏳, statistiche ⏳ | In corso |

> Costruire **end-to-end** ogni fase: modello → repository → servizio → UI, con test sulla
> logica geo (distanza/dislivello/GPX) — è il cuore dell'app, deterministico e separato dalla UI.
>
> Sentèi è in **beta privata** (TestFlight + APK Android, distribuita ad amici). Stato e
> priorità dettagliati: **`docs/ROADMAP.md`** (P8 → `docs/validazione-device.md`, fix/feature
> non ancora confermati su device fisico). Cronologia tecnica: **`docs/CHANGELOG-DEV.md`**.
> Novità per versione in linguaggio semplice, la stessa lista in-app: **`CHANGELOG.md`**.

## 8. Comandi ed esecuzione

```bash
flutter pub get              # installa dipendenze
flutter run -d <id>          # avvia su device/simulatore (flutter devices per la lista)
flutter test                 # esegue i test
flutter analyze              # linting/analisi statica
flutter build apk            # build Android
flutter build ipa            # build iOS (richiede Xcode + account Apple)
dart format .                # formattazione

flutter pub run build_runner build           # rigenera drift (lib/data/storage/app_database.g.dart)
flutter pub run flutter_launcher_icons       # rigenera icone app (branding/appstore.png)
flutter pub run flutter_native_splash:create # rigenera splash (branding/splash.png)
```

### Ambiente di sviluppo
- **Flutter 3.44.2.** ⚠️ Il `dart` sul PATH può differire da quello di Flutter (es. Homebrew):
  usare **`flutter pub run ...`**, non `dart run ...` (altrimenti "Flutter SDK not available").
- **Dispositivi:** l'UDID del simulatore iOS **cambia a ogni ricreazione** — se "No supported
  devices", rilanciare `flutter devices`. iPhone fisico via cavo: serve un Apple ID
  configurato in Xcode + firma del team già impostata. UDID correnti e Team ID Apple:
  **`CLAUDE.local.md`** (gitignorato, vedi §9), non qui.
- Bundle id: `com.mattiacuratitoli.sentei` (stesso `applicationId` su Android —
  `ios/Runner.xcodeproj`/`android/app/build.gradle` fonte di verità).

> **Hot reload:** interattivo con `r`; in esecuzioni NON interattive il reload **termina** il
> processo — rilanciare `flutter run` dopo una modifica Dart. Plugin nativi (geolocator,
> drift, file_selector) richiedono un rebuild completo (pod install).

## 9. Convenzioni di codice, segreti e sicurezza

- **Dart/Flutter style** ufficiale; `flutter analyze` deve passare pulito prima di un commit.
- Logica di dominio (geo, GPX, calcoli) **separata dalla UI** e **coperta da test** — è il
  cuore dell'app e deve essere deterministica.
- Ogni nuova sorgente dati va aggiunta in `data/` con la sua **attribuzione** (§4).
- Commit piccoli e tematici. Messaggi in italiano o inglese, ma coerenti.
- **Repository pubblico: niente segreti nel repo, mai.** Token/chiavi (Mapbox, Google) solo
  via `--dart-define` a build time; credenziali locali fuori dal repo (`~/.netrc`,
  `~/.gradle/gradle.properties` — guide in `docs/`); client OAuth (Google) in `configs/`
  (gitignorato); niente UDID/email/percorsi assoluti/identificatori personali in file
  versionati — se servono come riferimento, in **`CLAUDE.local.md`** (gitignorato, nessun
  template committato). Team ID Apple e bundle id sono comunque pubblici di fatto (binario
  distribuito, file `ios/`/`android/`), ma evitare di ripeterli qui senza motivo.
- **`kReleaseNotes`/`kRoadmapGroups`** (`lib/ui/release_notes.dart`) vanno **sempre
  allineati** a `CHANGELOG.md`/alle sezioni P1/P2 di `docs/ROADMAP.md`, **nella stessa
  sessione** in cui si aggiorna l'uno o l'altro. `NoteItem` (icona + titolo + riga opzionale)
  reso da `NoteRow` (condiviso con `whats_new.dart`): emoji solo nel testo di `CHANGELOG.md`,
  in-app la categoria la dice l'icona.
- **Modifiche non ancora distribuite:** vanno in `## Non ancora rilasciato` in cima a
  `CHANGELOG.md`, non in `kReleaseNotes` (solo versioni realmente uscite, usato anche dalla
  card "Novità"). Al rilascio prendono il numero di build e passano a `kReleaseNotes` nella
  stessa sessione.
- **Ad ogni bump di versione in `pubspec.yaml`:** allineare, nella stessa sessione, i file
  interni (`docs/CHANGELOG-DEV.md`, `docs/ROADMAP.md`) e quelli utente (`CHANGELOG.md`,
  `README.md`, `kReleaseNotes`) — incrociare con `CHANGELOG.md`, non fidarsi dello stato "da
  fare" già scritto in `docs/ROADMAP.md`. Checklist: **[`docs/release-checklist.md`](docs/release-checklist.md)**.

## 10. Questioni aperte (decisioni architetturali, non operative)

- [ ] **IGN SCAN 25 / fonti mappa storiche:** obsoleto dopo Mapbox GL (§2) — riconsiderare
  solo con un'architettura multi-sorgente.
- [ ] **Routing offline (BRouter embedded):** confermare la fattibilità reale in Flutter
  (dimensione dei segment file) — Fase 2.
- [ ] **Login autenticato (Google/Apple):** identità server-side che oggi l'app non ha
  (privacy-first, zero backend) — indipendente dalle analitiche d'uso (`docs/eval-usage-analytics.md`).
- [ ] **Unità di misura:** oggi solo metrico — valutare un'opzione imperiale.

> Multilingua: decisione presa, in roadmap (`docs/ROADMAP.md` §P7). Le questioni
> **operative** vivono in `docs/ROADMAP.md`, non qui — questa sezione è solo per decisioni
> architetturali di fondo ancora da prendere.

## 11. Note legali / licenze (importante)

- **Attribuzione obbligatoria** per Mapbox, OpenStreetMap/OSM2CAI: mostrarla in-app (§4).
- **Niente download massivo** delle tile: rispettare le usage policy di ogni servizio,
  specialmente quelli gratuiti (Overpass, Nominatim).
- **Sentèi** è un progetto personale ispirato a GaiaGPS, **non** ne riusa codice o dati proprietari.
- Sentèi è **gratuita e senza fini di lucro**: se in futuro cambiasse modello, rivedere tutte
  le licenze dei servizi di terze parti in uso (in particolare Mapbox, oltre il free tier).
