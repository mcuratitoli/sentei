# Roadmap di implementazione — Sentèi

> Documento operativo che traduce il `CLAUDE.md` (visione/decisioni) in **passi concreti**,
> **informazioni da recuperare** e **quesiti aperti** da sciogliere durante lo sviluppo.
> Aggiornare man mano che le decisioni vengono prese.

---

## 🚀 Ripartenza rapida (leggere per primo)

**Dove siamo (giugno 2026):** app funzionante e testata su iPhone fisico + simulatore. Implementato:
mappa multi-sorgente (OpenTopoMap/SwissTopo/IGN/OSM) + overlay sentieri; **GPS**; **disegno multi-traccia**
con **snap-to-trail** (BRouter, catena profili `hiking-mountain → trekking`, routing per-segmento con retry);
**dislivelli + profilo altimetrico interattivo** (scrubbing → punto evidenziato in mappa); **numeri sentieri
CAI** (Overpass) sia come chip sia come **banda sotto il grafico**; **persistenza locale** (drift/SQLite);
lista tracciati ordinabile/ricercabile; **export/import GPX**; UI con palette blu, font **Lato**, **barra
flottante in basso** (bussola-nord / mia posizione / **+** / lista / impostazioni), logo+splash.

> ⏳ **DA TESTARE SUL TELEFONO FISICO (promemoria):** download **mappe offline** (area + per-traccia) con uso in **modalità aereo** (mappa **e** D+/profilo); resa della **card** di dettaglio traccia (in fondo, nasconde la toolbar); gesto **2D↔3D** a due dita. Tutto verificato su simulatore/analyze/test ma non ancora sul device.

**Cosa resta (in ordine di priorità):**
- **Migrazione Mapbox GL — FATTA e VALIDATA su iPhone (branch `feat/mapbox-gl`, 5 fasi). Resta solo il merge in `main`.** L'app è passata da `flutter_map` a **Mapbox GL** (`mapbox_maps_flutter`): un solo motore, stile **Outdoors**, **terreno 3D** (gesto nativo a due dita), numeri CAI come etichette lungo i sentieri, disegno/editing (tap/drag/seleziona) wired a `Tracks`. `flutter_map` rimosso, 45 test verdi, **provata sul telefono fisico: funziona**. Piano/dettagli: `docs/plan-mapbox-gl-migration.md`, `docs/eval-3d-map.md`. Rifiniture post-test: bottone **3D/2D unico** (toggle con etichetta della modalità target); fix **"Calcolo percorso…"** che lampeggiava a ogni carattere del nome (`livePathProvider` ora dipende solo da waypoint+snap). **Prossimo:** `git checkout main && git merge feat/mapbox-gl`.
- **Step 6a — download aree offline (MAPPA) — FATTO (da provare il download reale su device):** via **Mapbox OfflineManager + TileStore** (`data/offline/offline_maps_service.dart`): `loadStylePack(Outdoors)` + `loadTileRegion` (bbox dell'**area visualizzata**, zoom 8–15) con **progress**; lista/elimina/dimensione in `features/offline_maps/` (schermata raggiungibile da Impostazioni → "Mappe offline"). La mappa memorizza l'ultima area inquadrata (`lastMapBoundsProvider`, aggiornato on idle). Init OfflineManager/TileStore verificato sul simulatore; **resta da provare un download reale** (rete) sul device.
- **Step 6b — download aree offline (ELEVAZIONE) — FATTO (da provare il download reale su device):** `TerrariumTileCache` (cache su disco) + `cachingTerrariumFetcher` (legge cache→HTTP→salva, usato da `elevationServiceProvider`) + `downloadTerrariumArea` (tile z13 del bbox). Integrato nel download offline: dopo la mappa, fase "Elevazione" con progress → **D+/profilo funzionano offline** per le aree scaricate. analyze pulito, 45 test verdi. Resta da provare un download reale sul device.
- **Sync cloud — Google Drive FATTO (da testare col setup OAuth dell'utente):** interfaccia comune `CloudSyncService` (`lib/data/cloud/`) + serializzazione condivisa `TrackCodec` + motore last-write-wins (`computeSyncPlan`, testato) + backend **Google Drive** (`google_sign_in` v7 + `googleapis` Drive v3, scope `drive.file`, cartella "Sentèi", `<id>.json` fonte di verità + `<id>.gpx` interop). UI in Impostazioni (accedi/sincronizza/disconnetti). Credenziali via `--dart-define=GOOGLE_CLIENT_ID`. **Setup obbligatorio:** `docs/cloud-google-drive-setup.md`. *Prossimo cloud:* impl **iCloud** (richiede Apple Developer Program a pagamento); limiti v1: delete non propagati, sync manuale.
- **Toggle "Segui sentieri" rimosso:** lo snap-to-trail è sempre attivo per le tracce disegnate (il campo `snapToTrail` resta solo per le tracce importate da GPX, già dettagliate).
- **Export GPX:** già esporta il percorso **instradato e densificato con quota** (`profile.samples`), non i waypoint del disegno → traccia fedele passo-passo (resta da provare l'import in app di terzi).
- **Estetica mappa (Mapbox GL) — FATTA (giu 2026, da iterare a vista):** hillshade extra sotto le etichette + `SkyLayer` atmosferico + esagerazione terreno 1.5 (rilievo alpino); **traccia selezionata** più spessa/bordata; numeri CAI con alone più leggibile. Stile sostituibile con uno Studio custom via `--dart-define=MAP_STYLE_URI=mapbox://styles/...` (`_mapStyleUri` in `map_gl_screen.dart`). Knob: `hillshadeExaggeration`/colori, larghezze linea in `_renderAll`.
- **"Fix IGN" — OBSOLETO:** dopo la migrazione a Mapbox GL non esistono più i layer multi-sorgente (IGN/SwissTopo/OpenTopoMap); la mappa è un singolo stile Mapbox. Gli step 5–5d più sotto sono **storici** (era `flutter_map`).
- **Sync cloud — iCloud: CODICE FATTO (giu 2026), manca solo la capability nativa.** `IcloudSyncService` (`lib/data/cloud/icloud_sync_service.dart`, pacchetto `icloud_storage`) + selettore provider Drive/iCloud (iOS-only) in Impostazioni persistito in `shared_preferences`. Da fare in Xcode con l'Apple Developer Program attivo: capability **iCloud Documents** + container `iCloud.com.mattiacuratitoli.sentei`. Guida: `docs/cloud-icloud-setup.md`.
- **Rimandati:** **bundling font** come asset (ora `google_fonts` scarica a runtime).

**Come eseguire / testare:** vedi `CLAUDE.md` §8 (avvio simulatore, `flutter run`, drift codegen, rigenerazione icone/splash).
In breve: `xcrun simctl boot <UDID iPhone> && open -a Simulator` poi `flutter run -d <UDID>`. L'hot reload via
segnale **non** funziona in sessioni non interattive: dopo una modifica si rilancia `flutter run` (build in cache, ~10-20s).

**Convenzioni di lavoro (preferenze utente):** committare in autonomia a ogni step verificato (`flutter analyze` pulito
+ `flutter test` verde); tenere aggiornati ROADMAP.md e CLAUDE.md a ogni iterazione.

---

## Prossimi step (priorità decisa dall'utente)

1. ✅ **Correzioni grafiche minori — riordino bottoni (FATTO):** rimossa l'AppBar → controlli flottanti identici in fullscreen e non. Bussola top-sx; FAB "Disegna" bottom-dx. Top-dx: riga [scelta mappa][lista tracciati], sotto fullscreen, sotto bottone menu (posizione attuale + mostra/nascondi sentieri). **Lista tracciati**: ordinamento per data/alfabetico + ricerca sul titolo (`createdAt` aggiunto a `DrawnTrack`).
2. ✅ **Font dell'app (FATTO):** **Lato** (UI, via `google_fonts`) + **Yeseva One** per il nome. Inoltre: **rimosso il fullscreen** (l'app è già a tutto schermo), **bottoni uniformati** a 44px (bussola, mappe, lista, menu), **nome "Sentèi"** in sovrimpressione in alto a sinistra (senza sfondo). *Nota: `google_fonts` scarica i font a runtime (cache); valutare il bundling come asset per l'uso offline.*
3. ✅ **Logo + splash screen (FATTO):** icone app generate da `branding/appstore.png` (`flutter_launcher_icons`) e splash da `branding/splash.png` (`flutter_native_splash`, sfondo bianco). Sorgenti in `branding/` (cartella `logo/` rimossa). Palette **blu/azzurro** (seed `#1565C0`).
   - **Layout finale (ridefinito dall'utente):** rimossa la scritta "Sentèi"; **barra flottante in basso** stile dock iOS (rounded), da sx: **bussola** (orienta a nord) · **mia posizione** · **+** centrale (colore primario) · **lista tracce** · **impostazioni** (⚙). **SettingsScreen** con: scelta **sorgente mappa** e sezione **Sentieri** (toggle overlay) — entrambi spostati qui dalla barra.
4. ✅ **Numeri sentieri CAI sul grafico dislivelli (FATTO):** al "Fine" si scaricano via Overpass (`out geom`) le **geometrie** delle relazioni `route=hiking` vicine; matching locale punto→sentiero (più vicino entro 25 m, a parità il più "locale") → `TrailSegment` per tratto (da..a in metri). Mostrati come **banda con etichette** sotto l'asse X del profilo (`ElevationProfileChart`), memorizzati nelle metriche (JSON, niente migrazione DB). Rimosso Yeseva One (font non più usato).
5. 🟡 **Fix IGN (layer 404) — DIAGNOSI + FIX (da verificare in-app):** **non era un bug di URL.** L'endpoint Géoplateforme (`GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2`, KVP/PM/PNG) risponde **200**; IGN Plan copre **in dettaglio solo la Francia** → su Torino/Aosta a z14+ dà **404** (a basso zoom z13 copre anche l'Italia). Fix: (a) `evictErrorTileStrategy.notVisibleRespectMargin` in `MapSource.toTileLayer()` (niente tile rotte/retry-loop); (b) **OpenTopoMap come fallback sotto IGN** in `map_screen` → versante italiano leggibile invece del vuoto. **Da verificare sul simulatore** (toolchain Flutter da reinstallare, vedi sotto). Estetica mappe (stile GaiaGPS) → ora step 5b.
5b. 🟡 **Estetica mappe stile GaiaGPS (in corso, da verificare in-app):** obiettivo dell'utente = lettura più facile, **meno colori e più gradienti dello stesso tono**, **tracce più pulite/semplici**. Fatto senza API key, sulle sorgenti raster esistenti: (a) **filtro "muted"** (`mutedTopoFilter` in `map_source.dart`, saturazione ~60% + leggera schiaritura) applicato alle basi via `tileBuilder` (`toTileLayer(muted: true)`); (b) **tracce ridisegnate**: linea piena con sottile **casing bianco** (`borderColor`/`borderStrokeWidth`) + `StrokeCap.round`/`StrokeJoin.round`, traccia attiva sempre in cima. Verificato sul simulatore (analyze pulito, 45 test verdi, app ok). (c) **Sorgente "Terrain (Gaia-like)"** aggiunta su scelta utente: **Stamen Terrain via Stadia Maps** (`stamenTerrain` in `map_sources.dart`, `muteByDefault:false` perché già tenue). ~~Stadia Terrain~~ **scartata** (l'utente preferisce OpenTopoMap con curve di livello) e **rimossa** dal catalogo.
5c. 🟡 **Rete sentieri vettoriale stile GaiaGPS (in corso, verificata in-app):** l'utente preferisce **OpenTopoMap** (curve di livello) a Stadia Terrain; le linee dei sentieri dell'overlay raster Waymarked erano troppo "confusionarie" (multicolore, spessori vari). **Sostituito l'overlay raster con una rete vettoriale** da OSM: `TrailNetworkService` (`data/trails/trail_network_service.dart`) interroga Overpass per le relazioni `route=hiking` nel **bbox visibile**; provider `trailNetworkProvider`/`TrailNetwork` (`map_providers.dart`) con **debounce 500ms, cache sull'area scaricata, soglia zoom ≥13**; layer `_TrailNetworkLayer` (`map_screen.dart`) disegna **linee uniformi**: colore unico (rosso mattone), spessore 2.5, **tratteggio** + sottile casing bianco. Attribuzione trail → OSM. Verificato su Alagna (rete visibile e pulita). **Nota UX:** i sentieri compaiono da z≥13 (sotto: vuoto, per non sovraccaricare Overpass). Knob facili: colore/dash/width in `_TrailNetworkLayer`, soglia in `TrailNetwork.minZoom`.
5d. 🟡 **Mapbox Outdoors + pulizia layer (da verificare con token):** ispirazione **Suunto** (colori mappa migliori). **Catalogo ridotto a OpenTopoMap + Mapbox Outdoors** (rimossi SwissTopo, IGN, OSM-base, Stadia). `mapboxOutdoors` in `map_sources.dart`: tile raster **512** (Styles API `mapbox/outdoors-v12`, `tileDimension:512`+`zoomOffset:-1`), `muteByDefault:false`. **Token via `--dart-define=MAPBOX_TOKEN=pk...`** (mai nel repo, §9), voce visibile solo con token (`hasMapboxToken`); **default = Mapbox quando il token c'è**, altrimenti OpenTopoMap. `osmStandard`→`osmAttribution` (tenuta solo per credito OSM dei sentieri). **Da provare con il token** dell'utente.
   - **3D (alla Suunto): NON fattibile con flutter_map** (solo 2D raster). Richiede cambio motore (`mapbox_maps_flutter` GL o MapLibre) → **rewrite di tutte le feature mappa** (CLAUDE.md §2 = scelta fissata, da discutere). Rimandato: eventuale piano/valutazione dedicata.
5e. ✅ **Vista 3D (stile Suunto) — FATTO (verificata sul simulatore):** ibrido (Opzione B, vedi `docs/eval-3d-map.md`): flutter_map resta per l'editing 2D, **aggiunta schermata 3D** `features/map_3d/map_3d_screen.dart` con **`mapbox_maps_flutter` 2.25**: stile **Outdoors** + **terreno 3D** (`mapbox-terrain-dem-v1`, esagerazione 1.4, pitch 70°, zoom min 13) + traccia selezionata (polyline annotation). Pulsante **"3D"** nella barra in basso (visibile solo col token). Token pubblico inizializzato in `main.dart` (riusa `MAPBOX_TOKEN`); **secret download token** SDK in `~/.netrc` + `~/.gradle/gradle.properties` (fuori dal repo). iOS target 13→14. **3D solo visualizzazione** (non editing). Migrazione totale a GL (Opzione A) rivalutabile se il 3D diventa centrale.
5f. ✅ **Rifiniture mappa/3D (FATTO):** (a) **tutte** le tracce disegnate ora visibili nella **vista 3D** (`Track3D` in `map_3d_screen.dart`, una polyline annotation per traccia); (b) **sentieri CAI** ristilizzati: più sottili (1.8), **verde semi-trasparente** (sfumature naturali sulle sovrapposizioni), **trattini piccoli e fitti** ([3,3]); (c) **marker partenza/arrivo** ridisegnati: pallini piccoli (18px) con lettera **P**/**A** invece delle icone. (d) **Transizione fluida 2D↔3D a due dita**: analizzata (`docs/eval-3d-map.md` §7-bis) → **non fattibile con l'ibrido** (flutter_map non ha pitch); richiede la **migrazione totale a Mapbox GL (Opzione A)**, dove il gesto è nativo. Da decidere.
6. ⏭️ **Download aree offline** (tile + DEM, FMTC) — §6.1 / Fase 1.F.

> Sync Google Drive: rimandato dall'utente (analisi già pronta in cronologia).

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

✅ **Fase 1.A — posizione GPS + rifiniture (feedback 4° test):** `geolocator` + `LocationService`; bottone **"La mia posizione"** (centra + marker blu), permessi iOS/Android. **Bussola** ridisegnata (ago rosso/grigio sempre visibile, tap → nord su). **Modalità fullscreen** (`fullscreenProvider`).

✅ **Flusso disegno/selezione (feedback 5° test):** (1) frecce singole (rimosso il doppio layer bianco); (2) **stati percorso**: disegno → "Fine" → deselezionato; **tap sulla traccia = seleziona** (card modifica/elimina/dislivello), tap fuori = deseleziona (`PathGeometry.distanceToPath` per l'hit); FAB "Disegna/Modifica" sempre in basso a destra quando nulla è selezionato; (3) **Dislivello come toggle** (apre/chiude il grafico); (4) rimosso il conteggio punti; (5) **nome del percorso** (`RouteEditorState.name` + campo testo).

✅ **(6) Tag numeri sentieri CAI — FATTO:** `OverpassTrailService` interroga **Overpass API** (POST + User-Agent) per le relazioni `route=hiking` vicine ai punti del percorso e ne estrae il `ref` (es. "203", "203E"). `trailRefsProvider.family` (best-effort, lista vuota su errore); chip mostrati nella card in vista selezionata. Catena profili routing ridotta a `hiking-mountain → trekking`.

✅ **Multi-traccia (feedback 6° test):** stato refattorizzato in `TracksState`/`Tracks` (lista `DrawnTrack`), con `editingId`/`selectedId`. Flusso: **Disegna** crea una nuova traccia → punti → **Fine** (deseleziona, si possono crearne altre) → **tap su una traccia** la seleziona (card). Ogni traccia ha **nome** (editabile solo in crea/modifica), **colore** (selettore in crea/modifica) e snap. Routing per-traccia (`routedPathProvider.family`). Dislivello: icona cambia, testo resta "Dislivello".

✅ **Routing robusto + rifiniture card (feedback 7°/8° test):** routing **per-segmento** (BRouter coppia per coppia) → un punto non instradabile degrada **solo quel segmento** a linea retta. **Causa segmenti retti diagnosticata via log**: il server pubblico brouter.de a volte uccide il calcolo (`operation killed by thread-priority-watchdog after 8s`) sotto carico → aggiunto **retry** (3 tentativi + backoff) oltre a timeout. Card: tasto **Dislivello a sinistra**, Fine/Modifica a destra; alla **selezione** di una traccia distanza + D+/D- compaiono in automatico (grafico profilo come toggle separato).

> **Root cause + fix definitivo:** alcuni segmenti in alta quota mandano in crisi i profili `hiking-*` (la ricerca esplode → il server li uccide), mentre il profilo **`trekking`** li calcola in ~1.5 s. Implementata **catena di profili**: `hiking-mountain` (×2 per i fail transitori) → `trekking`. Linea retta solo se anche trekking fallisce. Se in futuro servisse più controllo: istanza BRouter self-hosted o backend con API key.

⏭️ **Frecce di direzione: RIMOSSE temporaneamente** — "impazzivano" (marker fantasma) dopo aggiunta/rimozione nodi + pan mappa. Da **ristudiare** con un approccio diverso (es. layer dipinto su canvas proiettato con `MapCamera`, anziché `MarkerLayer`), così da non avere problemi di reconciliation dei marker.

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
- 🟡 **Cache in-memory dei dati calcolati (FATTO):** al "Fine" si calcola **una volta** percorso instradato + metriche (D+/D-/profilo) + numeri sentieri e si **memorizzano su `DrawnTrack`**; selezionare/deselezionare non ricalcola più (prima "frullava" a ogni riselezione, con esiti incoerenti per i kill del server). `livePathProvider` solo per l'anteprima in modifica.
- ✅ **Persistenza su disco (drift) — FATTO:** `drift` + `drift_flutter` (SQLite). `AppDatabase` con tabella `TrackRows` (dati strutturati in JSON); `TracksRepository` converte ↔ `DrawnTrack`. Le tracce si **caricano all'avvio** e si **salvano al "Fine"** / si eliminano. Schermata **"Tracciati"** popolata (tap → seleziona sulla mappa, elimina).
- ✅ **Export/import GPX (§6.4) — FATTO:** `GpxService` (pacchetto `gpx`) export `<trk>` con quota + import (trk/rte → traccia, snap off, waypoint sottocampionati). UI in "Tracciati": **Importa** (`file_selector`) e **Esporta GPX** (`share_plus` + file temporaneo). *(Nota: usato `file_selector` invece di `file_picker` per conflitto win32 con geolocator+share_plus.)*
- ⏭️ **Sync cloud (Google Drive):** rimandato su decisione utente — login Google account + archiviazione ordinata (vedi analisi in cronologia).

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
| **IGN** | ✅ URL KVP `PLANIGNV2`/PM/PNG confermato (200). Coprenza **solo Francia** in dettaglio (404 su IT a z14+). Resta: condizioni SCAN 25 | risolto giu-2026 |
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
