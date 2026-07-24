# CLAUDE.md — Sentèi

> **Nome visualizzato:** `Sentèi` (sentieri in dialetto piemontese).
> **Nome tecnico** (repository, package, bundle id, codice): `sentei` — senza accento.

> Documento di riferimento per lo sviluppo con Claude Code.
> **Sentèi** — app per l'escursionismo che replica le funzionalità di base di **GaiaGPS**,
> focalizzato sulle **Alpi del Nord Italia** e le zone di confine con **Francia** e **Svizzera**.
>
> ⚠️ **Questo repository è pubblico.** Non aggiungere qui (né altrove nel repo) token, chiavi
> API, ID dispositivo, credenziali o altri dati personali/sensibili — vedi §9.

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
| Rendering mappa | **`mapbox_maps_flutter`** (Mapbox GL) | Stile vettoriale **Outdoors** (+ varianti Dark/Satellite) con **terreno 3D** nativo (gesto a due dita), un solo motore. Migrato da `flutter_map` (multi-sorgente raster), rimosso. Token pubblico via `--dart-define=MAPBOX_TOKEN` — mai nel repo, vedi §8/§9. |
| Dati sentieri/segnavia | **OSM2CAI/INFOMONT** (catasto ufficiale CAI, Italia) primario + **Overpass API** (OSM `route=hiking`) fallback per le zone di confine FR/CH | Il layer sentieri della mappa lo disegna già Mapbox Outdoors; queste fonti servono per i **numeri segnavia** e il **grado di difficoltà CAI**, non per il layer visivo. |
| Elevazione | **Terrarium** (terrain-RGB, DEM SRTM/Copernicus) | Cacheabile offline, decodifica pixel→quota locale, nessuna dipendenza da un servizio a pagamento. |
| Offline | **Essenziale dalla v1** | Mappa + elevazione scaricabili per area (Mapbox OfflineManager + cache Terrarium); routing offline rimane Fase 2. |
| Cloud | **File GPX/JSON su iCloud Drive + Google Drive** | Nessun backend da mantenere, privacy massima, costi zero. |
| Storage locale | **SQLite (`drift`)** per metadati + file GPX su filesystem | Lista tracciati veloce, file standard esportabili. |
| State management | **Riverpod** (`Notifier`/`NotifierProvider`) + **go_router** | Vedi §7 per lo storico della scelta. |

> ⚠️ Queste scelte sono fissate. Se emergono motivi per cambiarle, **discuterne prima** di rifattorizzare.

---

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

# Foto lungo il percorso (in corso, vedi docs/ROADMAP.md)
photo_manager:         # accesso alla libreria foto per il matching spaziale con la traccia

# UI/stato
flutter_riverpod:      # state management, API Notifier
go_router:             # routing
package_info_plus:     # versione app (mostrata in Impostazioni)
```

> Verificare sempre l'ultima versione stabile su pub.dev e la compatibilità con la
> versione corrente di Flutter prima di aggiungere un pacchetto.

---

## 4. Dati mappa, sentieri ed elevazione (fonti + licenze)

**Rispettare SEMPRE le fair-use policy e l'attribuzione.** Niente download massivo aggressivo
delle tile; il download offline deve essere limitato per area e con rate limiting.

| Sorgente | Ruolo | Licenza / note |
|---|---|---|
| **Mapbox** (Outdoors / Dark / Satellite) | Base mappa (unico motore, §2) | Servizio a pagamento oltre il free tier — token pubblico via `--dart-define`, mai nel repo. |
| **OSM2CAI / INFOMONT** — `https://osm2cai.cai.it/api/geojson/hiking_routes/bounding_box` | Numeri segnavia + difficoltà CAI, **solo Italia** | Catasto ufficiale REI (CAI + Wikimedia Italia), licenza **ODbL**. Indagine endpoint: `docs/osm2cai-investigation.md`. |
| **Overpass API** (relazioni OSM `route=hiking`) | Numeri segnavia + difficoltà, fallback per l'intero arco alpino incl. confini FR/CH | Dati OpenStreetMap (ODbL); rispettare i limiti di frequenza delle istanze pubbliche. |
| **Terrain RGB / Terrarium** — `https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png` | Elevazione (D+/D-, profilo altimetrico), cacheabile offline | DEM SRTM/Copernicus codificato Terrarium, riuso libero. |
| **BRouter** (servizio pubblico) — `https://brouter.de/brouter` | Snap-to-trail (routing lungo i sentieri OSM) | Nessuna API key; vedi §5 per la catena di profili usata. |
| **Nominatim** (OSM) | Geocoding di fallback (ricerca luoghi, reverse geocoding) | Rispettare la usage policy (rate limit, User-Agent). |

> **Sorgenti storiche, non più in uso** dopo la migrazione a Mapbox GL: OpenTopoMap, SwissTopo,
> IGN, OSM raster standard, overlay raster Waymarked Trails (erano i layer base dell'epoca
> `flutter_map` multi-sorgente). Dettagli in `docs/CHANGELOG-DEV.md`.

---

## 5. Struttura del progetto

```
lib/
  main.dart
  app/                  # bootstrap, routing (go_router), tema (chiaro/scuro, 3 varianti dark)
  core/                 # costanti, formattazione, util geo (tile math)
  data/
    routing/            # BRouter (snap-to-trail)
    trails/             # numeri segnavia + difficoltà CAI: OSM2CAI, Overpass, strategia combinata
    offline/             # Mapbox OfflineManager + cache/decoder Terrarium (elevazione)
    storage/             # drift (SQLite) + repository tracciati + codec di serializzazione
    cloud/               # CloudSyncService: iCloud + Google Drive, motore last-write-wins
    gpx/                 # import/export GPX
    search/              # geocoding (Mapbox + Nominatim)
    location/            # posizione GPS
    photos/              # libreria foto + matching spaziale con la traccia (in corso)
    map_sources/         # costanti residue (template Terrarium)
  domain/
    models/              # Track, ElevationProfile, TrackPhoto, ...
    services/             # calcolo distanza/dislivello, semplificazione path, matching foto
  features/
    map_gl/               # schermata mappa principale (Mapbox GL) + info punto ispezionato
    draw_route/           # disegno/editing tracciato, azioni foto vicine
    tracks_list/          # libreria tracciati salvati (ordinamento, ricerca)
    offline_maps/         # gestione mappe/elevazione scaricate
    settings/             # tema, sorgente cloud, legende, changelog/roadmap in-app
  ui/                     # widget condivisi (vetro iOS, toast/menu, profilo altimetrico, token di design)
test/
```

> Struttura indicativa: riflette l'organizzazione attuale del codice, non un vincolo rigido.
> Quando una cartella cambia scopo in modo duraturo, aggiornarla qui.

---

## 6. Sfide tecniche e approccio scelto

### 6.1 Offline (priorità alta)
- **Tile mappa offline:** Mapbox OfflineManager + TileStore, download per bounding box (area
  visualizzata) a un range di zoom definito, con progress.
- **Elevazione offline:** cache su disco delle tile **Terrarium** per l'area scaricata.
  Decodifica: `elevation = (R * 256 + G + B / 256) - 32768` (metri). Da questo si calcolano
  D+/D- e il profilo altimetrico **senza rete**.
- **Routing offline:** rinviato a Fase 2 (vedi §7) — servirebbe BRouter embedded (segment
  files); fattibilità da confermare.

### 6.2 Disegno tracciati + snap-to-trail
- L'utente tocca la mappa per aggiungere waypoint; il percorso effettivo segue i sentieri OSM
  via **BRouter** (servizio pubblico, profilo `hiking-mountain`, formato GeoJSON, senza API
  key), instradato **per segmento** (un punto non instradabile degrada solo quel tratto a
  linea retta, con retry).
  - *Catena profili:* `hiking-mountain` → `trekking`. Alcuni segmenti alpini fanno esplodere
    la ricerca dei profili `hiking-*` (il server pubblico li uccide dopo un timeout); il
    profilo `trekking` li calcola comunque seguendo i sentieri. Linea retta solo se entrambi
    falliscono.
  - *Alternative valutate:* GraphHopper/Valhalla/OpenRouteService (richiedono API key) —
    tenute di riserva se la reliability del servizio pubblico BRouter non bastasse.
- **Numeri sentiero (ref CAI) e difficoltà:** non disponibili da BRouter → interfaccia comune
  `TrailService` (`data/trails/`, template method: segmentazione punto→sentiero condivisa).
  Strategia combinata (`CombinedTrailService`): **OSM2CAI** primario (Italia, `ref` CAI/REI
  validati anche dove il tag OSM grezzo manca, es. Valle d'Aosta) → **Overpass** fallback
  (copre anche le zone di confine FR/CH). Risultato: chip + banda per-tratto (`TrailSegment`,
  incluso `cai_scale` T/E/EE/EEA).

### 6.3 Calcolo distanza/dislivello
- Distanza: haversine cumulativo su punti densificati (interpolazione ogni ~10-25 m).
- Dislivello: campionamento dell'elevazione lungo il path con filtro a soglia (**deadband**,
  default 8 m) per evitare D+ gonfiato dal rumore del DEM. Da validare con tracce reali
  (vedi `docs/ROADMAP.md`).

### 6.4 GPX
- Export: percorso instradato e densificato con quota (non i soli waypoint del disegno).
- Import: parsing GPX di terzi + **riallineamento ibrido** ai sentieri rilevati (vedi
  `docs/CHANGELOG-DEV.md` per il flusso a 2 fasi caricamento→revisione).

### 6.5 Cloud (iCloud + Google Drive)
- Interfaccia comune `CloudSyncService` con due implementazioni (iCloud, Google Drive).
- Modello sync semplice: i tracciati sono file (`.gpx` + sidecar `.json` di metadati);
  conflitti risolti con "last write wins" + timestamp. Niente merge complesso in v1.
- **iCloud richiede capability/entitlement** nel progetto Xcode + Apple Developer Program.

### 6.6 Foto lungo il percorso (in corso)
- Nessun asse temporale affidabile sulla traccia (il parsing GPX scarta `<time>`) → matching
  **spaziale**: EXIF GPS della foto proiettato sul percorso instradato (distanza cumulata).
- Nessun upload dell'originale: solo metadati (GPS + timestamp + distanza-lungo-percorso +
  thumbnail) viaggiano nel JSON della traccia già sincronizzato; ogni device rifà un
  re-match locale nella propria libreria foto. Analisi completa: `docs/eval-photo-sync.md`.

---

## 7. Roadmap a fasi (storico + stato)

| Fase | Contenuto | Stato |
|---|---|---|
| **Fase 0** | Setup progetto, struttura cartelle, mappa base + attribuzioni | ✅ Completa |
| **Fase 1 (MVP)** | GPS, disegno + snap-to-trail, distanza/dislivello, salvataggio locale, GPX, aree offline | ✅ Completa |
| **Fase 2** | Sync cloud (iCloud + Drive) ✅, snap-to-trail online ✅ · routing offline embedded ⏳ · registrazione traccia live ⏳ | In corso |
| **Fase 3** | Rifiniture: ricerca località ✅, waypoint/foto ⏳, statistiche ⏳ | In corso |

> Costruire **end-to-end** ogni fase prima di ottimizzare. Ogni feature: modello → repository →
> servizio → UI, con test sulla logica geo (distanza/dislivello/GPX) — è il cuore dell'app e
> deve restare deterministica e separata dalla UI.
>
> Stato dettagliato, priorità e story point dei prossimi passi: **`docs/ROADMAP.md`**.
> Cronologia completa di cosa è già stato fatto: **`docs/CHANGELOG-DEV.md`**.

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

### Ambiente di sviluppo
- **Flutter 3.44.2** (stabile). ⚠️ Il `dart` sul PATH può differire da quello di Flutter
  (es. se installato anche via Homebrew): per i tool usare **`flutter pub run ...`**, NON
  `dart run ...` (altrimenti "Flutter SDK not available").
- **Dispositivi:** l'UDID del simulatore iOS **cambia a ogni ricreazione** — se "No supported
  devices", rilanciare `flutter devices` (o `xcrun simctl list devices available`) e usare
  l'UDID corrente. Per un iPhone fisico via cavo serve un Apple ID configurato in Xcode
  (Settings → Accounts) e la firma del team di sviluppo già impostata nel progetto.
- Bundle id: `com.mattiacuratitoli.sentei` (già in uso su App Store Connect; su Android è lo
  stesso `applicationId` — vedere `ios/Runner.xcodeproj` e `android/app/build.gradle` come
  fonte di verità).

```bash
xcrun simctl boot <UDID>     # avvia il simulatore (se spento)
open -a Simulator
flutter run -d <UDID>        # build + install + run
# Su un iPhone fisico via cavo: flutter run -d <device id da `flutter devices`>
```
> **Hot reload:** in una sessione interattiva si usa `r`. In esecuzioni NON interattive (output
> reindirizzato) il segnale di reload **termina** il processo: dopo una modifica Dart
> **rilanciare `flutter run`** (build in cache, ~10–20s). Le modifiche a **plugin nativi**
> (es. geolocator, drift, file_selector) richiedono un rebuild completo (pod install).

### Codegen e asset
```bash
flutter pub run build_runner build           # rigenera drift (lib/data/storage/app_database.g.dart)
flutter pub run flutter_launcher_icons       # rigenera icone app (sorgente: branding/appstore.png)
flutter pub run flutter_native_splash:create # rigenera splash (sorgente: branding/splash.png)
```

---

## 9. Convenzioni di codice, segreti e sicurezza

- **Dart/Flutter style** ufficiale; `flutter analyze` deve passare pulito prima di un commit.
- Logica di dominio (geo, GPX, calcoli) **separata dalla UI** e **coperta da test** — è il cuore
  dell'app e deve essere deterministica.
- Ogni nuova sorgente dati va aggiunta in `data/` con la sua **attribuzione** (§4).
- Commit piccoli e tematici. Messaggi in italiano o inglese, ma coerenti.
- **Questo repository è pubblico: niente segreti nel repo, mai.** In pratica:
  - token/chiavi API (Mapbox, Google) solo via `--dart-define` a build time, mai hardcoded;
  - credenziali locali (secret download token Mapbox, ecc.) solo in file **fuori dal repo**
    (`~/.netrc`, `~/.gradle/gradle.properties`) — vedi le guide in `docs/`;
  - i client OAuth (Google) vivono in `configs/`, **gitignorato**;
  - non incollare qui (né in altri file versionati) UDID di dispositivi reali, indirizzi email,
    percorsi assoluti della macchina di sviluppo o altri identificatori personali — sono privi
    di valore per chi legge il repo e non dovrebbero finire in un documento pubblico.
- Team ID Apple e bundle id sono già pubblici di fatto (compaiono nel binario distribuito e
  nei file di progetto `ios/`/`android/`), ma evitare comunque di ripeterli qui senza motivo.

---

## 10. Questioni aperte (decisioni architetturali, non operative)

- [ ] **IGN SCAN 25 / fonti mappa storiche:** obsoleto dopo la migrazione a Mapbox GL (§2) —
  da riconsiderare solo se si tornasse a un'architettura multi-sorgente.
- [ ] **Routing offline (BRouter embedded):** confermare la fattibilità reale in Flutter
  (dimensione dei segment file) prima di impegnarsi — Fase 2.
- [ ] **Login autenticato (Google/Apple) + analitiche d'uso:** introdurrebbe un'identità
  server-side che oggi l'app non ha (privacy-first, zero backend) — decisione da prendere
  prima di progettare l'implementazione. Dettagli in `docs/ROADMAP.md`.
- [ ] **Unità di misura / localizzazione:** oggi solo metrico e italiano — valutare se serve
  i18n.

> Le questioni **operative** (cosa implementare, in che ordine, con che priorità) vivono in
> `docs/ROADMAP.md`, non qui: questa sezione è solo per decisioni architetturali di fondo
> ancora da prendere.

---

## 11. Note legali / licenze (importante)

- **Attribuzione obbligatoria** per Mapbox, OpenStreetMap/OSM2CAI: mostrarla in-app (§4).
- **Niente download massivo** delle tile: rispettare le usage policy di ogni servizio,
  specialmente quelli gratuiti (Overpass, Nominatim).
- **Sentèi** è un progetto personale ispirato a GaiaGPS, **non** ne riusa codice o dati proprietari.
- Sentèi è **gratuita e senza fini di lucro**: se in futuro cambiasse modello, rivedere tutte
  le licenze dei servizi di terze parti in uso (in particolare Mapbox, oltre il free tier).

---

## 12. Stato del progetto

Sentèi è in **beta privata** (TestFlight + APK Android, distribuita ad amici). Per lo stato
aggiornato, non duplicarlo qui — è mantenuto in tre punti, ciascuno con uno scopo preciso:

- **`docs/ROADMAP.md`** — cosa resta da fare, in ordine di priorità, con peso di complessità.
- **`docs/CHANGELOG-DEV.md`** — cronologia tecnica dettagliata di ciò che è stato implementato
  (con cause-radice dei bug, decisioni, file coinvolti).
- **`CHANGELOG.md`** (radice del repo) — novità per versione in linguaggio semplice, la stessa
  lista mostrata in-app (Impostazioni → Informazioni → Sentèi, insieme a un'anteprima sintetica
  delle prossime priorità).

Architettura e stack restano quelli descritti in questo documento (§2-§6); quando cambiano in
modo duraturo, questo file va aggiornato — lo stato di avanzamento **contingente**, invece, no.
