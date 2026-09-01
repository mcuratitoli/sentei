# Sentèi — Panoramica del progetto

> Documento di sintesi autoconsistente, pensato per essere condiviso con un
> assistente esterno (es. una sessione Claude di chat) che valuti possibili
> migliorie **in parallelo** allo sviluppo. Non sostituisce i documenti operativi
> del repo (`CLAUDE.md`, `docs/ROADMAP.md`, `docs/CHANGELOG-DEV.md`,
> `CHANGELOG.md`): li riassume allo stato del **28 agosto 2026**.

---

## 1. Cos'è

**Sentèi** (nome tecnico: `sentei`, senza accento) è un'app mobile **iOS + Android**
per l'**escursionismo**, focalizzata sulle **Alpi del Nord Italia** e le zone di
confine con **Francia** e **Svizzera**. Replica le funzionalità di base di
**GaiaGPS**, senza riusarne codice o dati: è un progetto personale, **gratuito e
senza fini di lucro**, in **beta privata** distribuita ad amici.

Repository **pubblico**. Nessun segreto nel repo: i token (Mapbox, Google) passano
via `--dart-define` a build time.

## 2. Finalità del prodotto

Funzioni cardine (tutte già implementate salvo dove indicato):

1. **Mappe topografiche** con sentieri affidabili (rete CAI / FFRandonnée / SAC).
2. **Disegno di tracciati** lungo i sentieri (snap-to-trail), con **distanza** e
   **dislivello** (D+/D-) e **tempo di percorrenza** stimato col metodo CAI/SAC.
3. **Salvataggio** locale dei tracciati.
4. **Export / import GPX**.
5. **Sync cloud personale**: iCloud Drive (iOS) + Google Drive (Android), a file,
   senza backend.
6. **Uso offline** (priorità alta: in montagna spesso non c'è segnale) — mappa +
   elevazione scaricabili per area. Il **routing offline** è ancora da fare.

Funzioni accessorie già presenti: ricerca di località e rifugi, **numeri segnavia
CAI + grado di difficoltà** per tratto, **profilo altimetrico** interattivo,
**foto lungo il percorso** (matching spaziale con la traccia), **export di
un'immagine** del percorso pronta da condividere, tema chiaro + 3 varianti scure.

### Non-obiettivi (scope escluso di proposito)

Social / condivisione, navigazione turn-by-turn vocale, meteo, fitness tracking
avanzato, **login autenticato / identità server-side**, backend di qualunque tipo.
Suggerimenti che richiedano uno di questi sono fuori perimetro salvo esplicita
riapertura della decisione.

## 3. Stato di implementazione

Versione corrente: **`1.0.0` build 11** (`1.0.0+11`). Beta privata: **TestFlight**
(iOS) + **APK** (Android), distribuita ad amici.

Costruzione **a fasi**, ognuna end-to-end (modello → repository → servizio → UI):

| Fase | Contenuto | Stato |
|---|---|---|
| **0** — Setup | Struttura progetto, mappa base + attribuzioni | ✅ Completa |
| **1** — MVP | GPS, disegno + snap-to-trail, distanza/dislivello, salvataggio locale, GPX, aree offline | ✅ Completa |
| **2** | Sync cloud (iCloud + Drive) ✅ · snap-to-trail online ✅ · **routing offline embedded** ⏳ · **registrazione traccia live** ⏳ | In corso |
| **3** | Ricerca località ✅ · waypoint/foto ⏳ (parziale) · statistiche ⏳ | In corso |

### Cosa funziona oggi (verificato, in parte su device fisico)

- Mappa **Mapbox GL** vettoriale (stile Outdoors + Dark + Satellite) con **terreno
  3D** nativo.
- **Disegno / editing tracciati** con snap-to-trail via **BRouter** pubblico,
  per-segmento; tratti "liberi" (linea retta) mescolabili nella stessa traccia.
- **Distanza** (haversine cumulativo su punti densificati ~10-25 m) e **D+/D-**
  (campionamento DEM con filtro deadband, default 8 m).
- **Tempo di percorrenza** CAI/SAC (4 km/h piano, 400 m/h salita, 500 m/h discesa,
  formula svizzera con correttivo `min/4`); split automatico salita/discesa sui
  percorsi ad anello.
- **Numeri segnavia + grado CAI** (T/E/EE/EEA) per tratto: OSM2CAI (Italia) +
  Overpass (confini FR/CH); scheda del segnavia col percorso intero sulla mappa e
  link a OpenStreetMap / CAI Varallo (Valsesia).
- **GPX** import (con riallineamento ai sentieri) / export.
- **Aree offline**: tile mappa (Mapbox OfflineManager) + cache tile elevazione
  (Terrarium).
- **Sync cloud** iCloud + Google Drive, a file (`.gpx` + sidecar `.json`),
  last-write-wins, auto-sync su salva/elimina — testato su device.
- **Foto lungo il percorso**: matching spaziale via EXIF GPS proiettato sul
  percorso, anteprime in cache LRU, niente upload dell'originale.
- **Ricerca località** (Mapbox + Nominatim), **export immagine** del percorso con
  POI etichettati.

### In lavorazione / pianificato — priorità (roadmap P1 → P8)

- **P1 (massima priorità, 28 ago 2026)** — tre nuovi lavori:
  - **A** — *indicatore di quota e coordinate correnti* sempre visibile sulla
    mappa (card in alto a sinistra, espandibile: accuratezza + coordinate + copia;
    quota GPS solo se accurata ≤ 25 m). **In sviluppo in questa sessione.**
  - **B** — *difficoltà CAI resa sullo stile della linea* del tracciato (piena=T,
    tratteggio largo=E, stretto=EE, punteggiato=EEA; convenzione ispirata a
    SAC/Tabacco). Vincolo: su Mapbox GL `line-dasharray` non è data-driven.
  - **C** — *tempi di percorrenza per un intervallo scelto* (start→punto,
    punto→punto, punto→fine); rimozione dello split automatico anello.
- **P2** — feedback dai test su device: uscita più intuitiva dalla ricerca luogo,
  completamento "epica foto" (vista a griglia, import dalla card), zoom/angolazione
  personalizzabili per l'export immagine, affidabilità ricerca segnavia (CAI
  Varallo + Overpass) da riconfermare.
- **P3** — editing tracce & UX mappa: linee sentieri come layer selezionabile,
  separazione strade/sentieri, studio grafico in ottica GaiaGPS, migrazione layer
  sentieri a OSM2CAI, UI sync foto, PoC **versione Web**.
- **P4** — build & toolchain: tetto alla cache tile Mapbox, CI (GitHub Actions),
  upgrade Flutter.
- **P5** — rimandati: bundling font offline, **registrazione traccia live** (epica,
  background location).
- **P6** — distribuzione: iOS Unlisted, Play Console + `.aab`, **analitiche d'uso**
  (epica, analisi fatta).
- **P7** — backlog tecnico: densificazione path, precisione D+/D-, **unità
  imperiali**, affidabilità BRouter, modello di sync cloud, **multilingua (i18n)**,
  **routing offline** (BRouter embedded, epica).
- **P8** — validazione su device: fix/feature già implementati ma non ancora
  confermati a schermo su un telefono fisico.

## 4. Decisioni architetturali (fisse)

| Ambito | Scelta | Note |
|---|---|---|
| Framework | **Flutter 3.44.2** (Dart) | Un codebase iOS + Android. |
| Rendering mappa | **`mapbox_maps_flutter`** (Mapbox GL) | Stile vettoriale Outdoors/Dark/Satellite, terreno 3D nativo. Migrato da `flutter_map` (raster multi-sorgente), ora rimosso. Token pubblico via `--dart-define`. |
| Sentieri / segnavia | **OSM2CAI / INFOMONT** (catasto ufficiale CAI, Italia) + **Overpass API** fallback (confini FR/CH) | Servono per **numeri segnavia** e **grado CAI**, non per il layer visivo (lo disegna Mapbox Outdoors). |
| Elevazione | **Terrarium** (terrain-RGB, DEM SRTM/Copernicus) | Cacheabile offline, decodifica pixel→quota locale, nessun servizio a pagamento. |
| Routing (snap-to-trail) | **BRouter** pubblico (no API key) | Per-segmento, catena profili `hiking-mountain` → `trekking`, linea retta se entrambi falliscono. Offline → Fase 2. |
| Offline | Essenziale dalla v1 | Mapbox OfflineManager + cache Terrarium. Routing offline rinviato. |
| Cloud | File GPX/JSON su **iCloud Drive + Google Drive** | Nessun backend, privacy massima, costi zero. Conflitti "last write wins". |
| Storage locale | **SQLite (`drift`)** per metadati + file GPX su filesystem | |
| State management | **Riverpod** (`Notifier`/`NotifierProvider`) + **go_router** | |
| Foto | `photo_manager` + matching **spaziale** (EXIF GPS sul percorso) | Mai l'originale a piena risoluzione; miniature 200 px q80 nei metadati sincronizzati. |

## 5. Struttura del codice

```
lib/
  app/        bootstrap, routing (go_router), tema (chiaro + 3 dark)
  core/       costanti, formattazione, util geo (tile math)
  data/
    routing/  BRouter (snap-to-trail)
    trails/   numeri segnavia + difficoltà CAI: OSM2CAI, Overpass, strategia combinata
    poi/      punti interessanti lungo il percorso (Overpass) per l'export immagine
    offline/  Mapbox OfflineManager + cache/decoder Terrarium
    storage/  drift (SQLite) + repository tracciati + codec di serializzazione
    cloud/    CloudSyncService: iCloud + Google Drive, last-write-wins
    gpx/      import/export GPX
    search/   geocoding (Mapbox + Nominatim)
    location/ posizione GPS
    photos/   libreria foto (matching spaziale) + cache anteprime
  domain/
    models/   Track, ElevationProfile, TrackPhoto, ...
    services/ distanza/dislivello, semplificazione path, tempo CAI, matching foto
  features/
    map_gl/       schermata mappa principale (Mapbox GL)
    draw_route/   disegno/editing tracciato, azioni foto, export (GPX/immagine)
    tracks_list/  libreria tracciati salvati
    offline_maps/ gestione mappe/elevazione scaricate
    settings/     tema, sorgente cloud, legende, changelog/roadmap in-app
  ui/         chrome "vetro" iOS + card opache, toast/menu, profilo altimetrico, token di design
test/         logica di dominio (geo, GPX, tempo) — deterministica, separata dalla UI
```

## 6. Vincoli e sfide note (utili a chi valuta migliorie)

- **Zero backend, privacy-first.** Nessuna identità server-side, nessun account. Il
  cloud è lo storage personale dell'utente (Drive/iCloud). Proposte che richiedano
  un server o un login autenticato sono fuori perimetro (decisione aperta ma non
  presa — `CLAUDE.md` §10).
- **Gratuita e non-profit.** Rispettare le fair-use policy dei servizi gratuiti
  (Overpass, Nominatim, Terrarium): niente download massivo, rate limiting, User-
  Agent corretto. Mapbox è a pagamento oltre il free tier.
- **Fonti dati intermittenti.** OSM2CAI (endpoint spesso rotto in produzione),
  Overpass (istanze pubbliche sature) e lo scraping di CAI Varallo sono
  inaffidabili a intermittenza. È stata fatta parecchia resilienza di rete
  (interruttori, staffetta fra istanze, degradazione parziale) ma non è considerata
  chiusa.
- **Mapbox GL — limiti noti:** `line-dasharray` non è data-driven (impatta P1.B);
  gli ornamenti nativi (scale bar, logo, "i") hanno solo 4 posizioni d'angolo e il
  logo non è ridimensionabile; `mapbox_maps_flutter` 2.25 non espone `setDiskQuota`
  per la cache tile (servirebbe codice nativo — P4).
- **UI solo in italiano.** i18n è deciso e in roadmap (P7), non fatto.
- **Solo unità metriche.** Opzione imperiale in backlog (P7).
- **iOS Simulator** non fornisce un'accuratezza verticale GPS realistica: alcune
  feature basate sulla qualità del fix vanno verificate su device fisico (P8).
- **Repo pubblico:** nessun segreto committato; token via `--dart-define`.

## 7. Come si lavora sul progetto

- Logica di dominio (geo, GPX, calcoli) **separata dalla UI** e **coperta da test**
  (attualmente ~249 test verdi). `flutter analyze` deve passare pulito.
- Commit piccoli e tematici, messaggi in italiano o inglese.
- Disciplina documentale: a ogni bump di versione si allineano nella stessa
  sessione `docs/CHANGELOG-DEV.md`, `docs/ROADMAP.md`, `CHANGELOG.md`,
  `README.md` e la roadmap/changelog **in-app** (`lib/ui/release_notes.dart`).

## 8. Documenti di riferimento nel repo

- **`CLAUDE.md`** — visione di prodotto, decisioni architetturali fisse, stack,
  comandi, convenzioni.
- **`docs/ROADMAP.md`** — piano operativo, solo punti aperti, in ordine di
  priorità (P1 → P8) con story point.
- **`docs/CHANGELOG-DEV.md`** — cronologia tecnica dettagliata (cosa, perché, con
  quali file, quali bug risolti).
- **`CHANGELOG.md`** — novità per versione in linguaggio utente (anche in-app).
- **`docs/validazione-device.md`** — checklist di validazione su telefono fisico.
- **`design/DESIGN_GUIDELINES.md`** — linee guida grafiche (bottoni, bottom sheet,
  badge, palette).
