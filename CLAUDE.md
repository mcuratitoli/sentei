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
| Rendering mappa | **`flutter_map`** | Gestisce nativamente più sorgenti di **tile raster** (OpenTopoMap, SwissTopo, IGN) e overlay; plugin maturo per caching offline. |
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
flutter_map:                 # rendering mappa multi-tile
flutter_map_tile_caching:    # (FMTC) caching e download offline di aree
latlong2:                    # coordinate / distanze
geolocator:                  # posizione GPS (foreground; background in fase 2)
proj4dart:                   # eventuali conversioni di proiezione (WMTS)

# Tracciati
gpx:                         # parsing/generazione file GPX
# (decoder Terrarium custom per l'elevazione — vedi §6)

# Persistenza
drift + sqlite3:             # DB metadati tracciati
path_provider:               # percorsi filesystem
shared_preferences:          # impostazioni utente

# Cloud
icloud_storage:              # iCloud Drive (iOS)
google_sign_in + googleapis: # Google Drive (Android/iOS)
share_plus / file_picker:    # condivisione/import GPX via "File"

# UI/stato
riverpod (o bloc):           # state management (scegliere — vedi §10)
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
- **Fase 2 (snap-to-trail):** instradamento che segue i sentieri OSM:
  - *Online:* **GraphHopper API** profilo `hike`/`foot` (o Valhalla).
  - *Offline:* **BRouter** (motore di routing OSM offline con profili escursionistici) —
    valutare embedding/segment files. Documentare la decisione quando si affronta.

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

## 8. Comandi

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

- [ ] **State management:** `riverpod` (consigliato) vs `bloc`. Decidere in Fase 0.
- [ ] **Bundle id** definitivo (proposta: `com.mattiacuratitoli.sentei`). Nome app: `Sentèi` (display), `sentei` (tecnico) ✓.
- [ ] **IGN SCAN 25:** verificare se la licenza topografica dettagliata è utilizzabile o se usare Plan IGN.
- [ ] **Routing offline:** confermare fattibilità BRouter embedded in Flutter (Fase 2).
- [ ] **Apple Developer Program** (99€/anno) necessario per iCloud + distribuzione iOS reale.
- [ ] **Google Cloud project** + OAuth consent per Google Drive.
- [ ] Strategia di **smoothing del dislivello** (soglia/algoritmo) da validare con tracce reali.

---

## 11. Note legali / licenze (importante)

- **Attribuzione obbligatoria** per OSM, OpenTopoMap (CC-BY-SA), SwissTopo, IGN: mostrarla in mappa.
- **Niente download massivo** delle tile OSM standard (vietato dalla usage policy).
- SwissTopo e IGN sono **gratuite ma per uso non commerciale / con condizioni**: se in futuro
  l'app diventasse a pagamento, **rivedere le licenze**.
- **Sentèi** è un progetto personale ispirato a GaiaGPS, **non** ne riusa codice o dati proprietari.
