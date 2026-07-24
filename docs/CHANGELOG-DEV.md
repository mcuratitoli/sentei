# Changelog tecnico — Sentèi

Cronologia dettagliata di sviluppo: cosa è stato implementato, perché, con quali file
coinvolti e quali bug/cause-radice sono stati risolti lungo il percorso. Organizzato per
**data**, ordine cronologico inverso (più recente in cima).

- Per le **novità in linguaggio utente** (cosa cambia per chi usa l'app) vedi
  [`CHANGELOG.md`](../CHANGELOG.md) alla radice del repo — la stessa lista è mostrata
  in-app in Impostazioni → Informazioni → Sentèi.
- Per **cosa resta da fare**, in ordine di priorità, vedi [`ROADMAP.md`](./ROADMAP.md).

---

## 24 luglio 2026 — Icone provider cloud distinte (in lavorazione, non ancora rilasciato)

In Impostazioni → Sincronizzazione cloud, la riga di accesso/account mostrava sempre
`CupertinoIcons.cloud`/`cloud_fill` sia per iCloud sia per Google Drive — a colpo d'occhio
indistinguibili. `_CloudSection` (`lib/features/settings/settings_screen.dart`) ora sceglie
l'icona in base al `cloudProviderProvider` attivo: **iCloud** resta la nuvola (coerente con
l'iconografia reale del servizio Apple), **Google Drive** usa `Icons.add_to_drive` (Material,
triangolo/cartella — nessun asset o dipendenza aggiuntiva, `uses-material-design: true` già
presente). Il selettore segmentato (`_CloudProviderSelector`) resta solo testuale, non
toccato: il problema segnalato era specificamente l'icona della riga account.

---

## 24 luglio 2026 — Roadmap sintetica in-app (in lavorazione, non ancora rilasciato)

Impostazioni → Informazioni → Sentèi mostrava solo il changelog (`kReleaseNotes`,
`lib/ui/release_notes.dart`). Aggiunta una nuova costante `kUpcomingHighlights` (3-6 voci,
linguaggio utente, zero nomi di file/provider) per la roadmap sintetica. Stessa logica di
manutenzione del changelog: quando cambia la sezione P1 di `ROADMAP.md`, le voci più
rilevanti per l'utente vanno riportate a mano in `kUpcomingHighlights`, nella stessa
sessione di lavoro (regola esplicita in `CLAUDE.md` §9). Scartate in fase di analisi:
parsing di `ROADMAP.md` a runtime (documento per sviluppatori, non adatto a un utente
finale) e una pagina web esterna linkata da Impostazioni (hosting dedicato non
giustificato alla scala "beta tra amici").

**UI (revisione):** prima versione con le due liste impilate in un unico scroll (sezione
"In arrivo" sotto le versioni, separata da un hairline) — sostituita su richiesta utente
con **due tab** nello stesso bottom sheet (`CupertinoSlidingSegmentedControl<_NotesTab>`,
stesso pattern del selettore cloud in `settings_screen.dart`): "Novità" (default, aperta
all'apertura del foglio) e "Roadmap". Titolo/sottotitolo del foglio e la sola area
contenuti sotto il selettore scrollano (`Flexible` + `SingleChildScrollView`); il
selettore resta fisso. Righe puntate fattorizzate in `_bulletRows` (riusate da entrambe
le tab, prima duplicate tra `_VersionBlock` e la vecchia `_UpcomingSection`).

---

## 23-24 luglio 2026 — build `1.0.0+5`

### Dark mode (3 varianti) + mappa scura automatica
Tema **Automatico/Chiaro/Scuro** con 3 varianti scure — **Standard** (dark iOS elegante,
default), **Notturno** (uso in montagna: toni caldi/smorzati, niente bianco puro né blu
freddo, basso abbagliamento), **Risparmio energetico** (nero OLED puro) — attivazione
manuale in Impostazioni, persistita (`shared_preferences`).

- **Step 1 (fondamenta):** `AppPalette` (`ThemeExtension`, `lib/ui/tokens.dart`) coi colori
  strutturali (sfondi/testo/grigi/vetro/hairline) risolti da `context.palette`; i colori
  brand/semantici (primary/destructive/difficoltà CAI/palette tracce) restano costanti in
  ogni variante. Migrati tutti gli usi strutturali (settings, tracks_list, offline_maps,
  map_gl incluso i `CustomPainter` che ricevono il colore via costruttore, glass.dart,
  ios_menu.dart, legends.dart). Nessun cambio visivo in light.
- **Step 2 (temi + toggle):** 3 palette dark (`AppPalette.darkStandard/darkNight/darkOled`)
  + `AppTheme.dark(AppDarkVariant)`; `theme_provider.dart` (persistito, stesso pattern di
  `tracks_sort_provider`); `app.dart` → `SenteiApp` diventato `ConsumerWidget`, **rimosso il
  force-light** introdotto il 5 luglio: il `builder` forza `platformBrightness` solo se
  l'utente ha scelto esplicitamente Chiaro/Scuro, in Automatico lascia passare quella
  reale di sistema (anche per i widget Cupertino). Sezione "Aspetto" in Impostazioni.
- **Step 3 (verifica):** confermato a schermo che l'Automatico segue il sistema e che il
  light resta pixel-identico a prima. Widget test: `test/features/settings_appearance_test.dart`,
  `test/app/theme_provider_test.dart`. 89 test verdi.
- **Mappa scura (Opzione A):** `MapboxStyles.DARK` come "Outdoors scuro", coordinato col
  tema app (non un terzo tasto "vista"); Satellite invariata anche a tema scuro. Dettagli
  colore per leggibilità: label sentieri CAI verde chiaro su alone scuro, hillshade/cielo
  attenuati, icona attribuzione "i" chiara. Analisi: `docs/eval-dark-map.md`.

### Editing avanzato dei tracciati — punti intermedi
Waypoint più afferrabili (raggio 7→11); **undo a stack**; tap = seleziona + elimina con
conferma (niente più cancellazioni accidentali); **inserimento di un punto intermedio**
con maniglie di metà-segmento (`insertPoint` + split); **ri-instradamento incrementale**
(`segmentRouteProvider` family con cache per-chiave → sposta/inserisci ricalcola solo i
segmenti adiacenti). Analisi/piano: `docs/eval-waypoint-editing.md`.

> Limite noto in questa prima versione (maniglie al centro della corda, non del sentiero) →
> ripensato e sostituito, vedi `ROADMAP.md` P1.

### Import GPX riallineato ai sentieri (flusso a 2 fasi)
L'import GPX ora: (1) parsa la traccia grezza; (2) la semplifica (Douglas-Peucker adattivo,
≤40 waypoint); (3) **fase di caricamento annullabile** — instrada segmento per segmento con
snap-to-trail e sceglie un **ibrido**: snap dove coincide con la grezza (lunghezza ≤1.6× e
scarto ≤60 m), altrimenti mantiene il tratto grezzo fuori sentiero (card con **Annulla**,
concorrenza 6, cache `segmentRouteProvider`); (4) calcola metriche + segnavia/difficoltà
CAI; (5) **fase di revisione** — non auto-importa: entra in editing sulla traccia
ricalcolata con la grezza tratteggiata (dimmed) come riferimento immutabile; persiste solo
al Salva. Rif. `Tracks.importGpx`/`_runImport`/`_hybridRoute`, `PolylineSimplifier`,
`importPreviewProvider`, `importLoadingProvider`.

> Bug noto emerso dal test su device (la grezza può restare "fantasma" in mappa) →
> tracciato come fix in `ROADMAP.md` P1.

### Sync foto lungo il percorso — analisi e decisione (implementazione UI in corso)
Analisi completa in `docs/eval-photo-sync.md`. Scoperta chiave: non esiste un asse
temporale sulla traccia (il parsing GPX scarta `<time>`; `createdAt` è la data di
creazione in Sentèi, non della escursione) → matching **spaziale** (EXIF GPS della foto sul
`routedPath`, estendendo `PathGeometry` con la distanza cumulata) + data come segnale
secondario. **Decisione "sync" senza server:** i metadati (GPS + timestamp + distanza
lungo il percorso + thumbnail piccolo) viaggiano nel JSON della traccia (già sincronizzato
via iCloud/Google Drive); l'originale resta solo in galleria, mai caricato — ogni device
rifà un re-match locale nella propria libreria. Permesso pieno alla libreria foto + griglia
in-app ("Trovate N foto vicino al percorso") invece del picker di sistema. Nessun
login/backend. Package candidato: `photo_manager`. Lavoro su branch dedicato.

### UI: rifiniture varie
- **Bottoni in alto a destra accorpati**: da due superfici separate (bussola + pillola
  2D/3D · posizione) a un'unica pillola in vetro con tre righe separate da hairline
  (stile Apple Maps). Rif. `_SideControls`/`_PillDivider` in `map_gl_screen.dart`.
- **Splash screen animato**: sfondo topografico procedurale (`CustomPaint`,
  `_TopoSplashPainter`) — isoipse in drift ellittico + zoom "Ken Burns" su gradiente
  azzurrino→bianco, logo in una radura bianca centrale. Nessun asset extra, offline, tema
  blu. Il primo frame Flutter è identico al native splash (continuità nativo→Flutter),
  poi dissolve verso l'animazione. Logo a fondo trasparente generato da `branding/splash.png`.
- **Gap di avvio eliminato**: la mappa resta coperta dallo splash finché la camera iniziale
  non è già sulla posizione GPS (o sul fallback traccia salvata), piazzata istantaneamente
  (`setCamera`, niente `flyTo`); poi lo splash dissolve. Timeout di sicurezza 12 s.
- **Attribuzione Mapbox ("i")** spostata più in alto a sinistra. *Limite noto:* l'SDK non
  espone la dimensione dell'icona (solo posizione/margini/colore), resta della grandezza
  nativa.

### Design system — tokenizzazione
Audit (22 luglio): 66 `Color(0x…)` hardcoded contro 10 usi di `colorScheme`, 25 `fontSize`
hardcoded contro 6 `textTheme`, 7 grigi quasi identici senza ruolo, 4 rossi senza ruolo, 9
raggi diversi, `_kGroupedBg` duplicato in 3 file. Fix: creato `lib/ui/tokens.dart`
(`AppColors`/`AppSpacing`/`AppRadii`/`AppText`), migrati i punti caldi (settings,
tracks_list, offline_maps, controlli mappa, glass.dart), poi estesa `AppText` a una type
scale iOS completa e aggiunti grigi semantici. **Unica variazione visiva intenzionale:**
azione distruttiva unificata a iOS `systemRed` (prima convivevano due rossi diversi).
Risultato: `Color(0x…)` inline 66→45 (residuo = ombre/scrim e colori di dominio
CAI/elevazione/bussola). analyze pulito, 68→89 test verdi nel corso del lavoro.

### Fix — GPS all'apertura (21 luglio)
All'apertura la mappa si posiziona **sempre** sulla posizione GPS corrente. Prima
centrava sulla prima traccia salvata (`_maybeCenter`) e il GPS partiva solo in assenza di
tracce → chi aveva tracce salvate non veniva mai portato sulla propria posizione. Ora
`_locateSilently` è chiamato sempre al primo setup; la traccia salvata resta solo
fallback se il GPS manca/permessi negati.

### Legenda difficoltà ampliata (22 luglio)
Oltre alle escursionistiche T/E/EE/EEA, copre anche le alpinistiche F/PD e la scala
Welzenbach I/II/III (nota −/+ e "condizioni ottimali"), testo allineato alla «Guida dei
Monti d'Italia» (CAI). Aggiunta la legenda Abbreviazioni (ANA/ASF/CAF/CAI/GTA/IGM/IGN/UGET).
Contenuti in `lib/ui/legends.dart`, descrizioni in `lib/ui/cai_difficulty.dart`.

---

## 5 luglio 2026 — build `1.0.0+4`

### Menu e conferme in stile iOS (Apple Photos)
Sostituiti action sheet/alert Material con `lib/ui/ios_menu.dart`: `showIosMenu` (menu
contestuale ancorato al bottone — usato per Ordina e azioni riga in Tracciati) e
`showIosConfirm` (conferma centrata — usata per "Annullare?" e per la **conferma di
eliminazione traccia**, prima immediata senza conferma).

### Ordinamento tracciati persistito
Provider persistito (`tracks_sort_provider.dart`, `shared_preferences`), default
alfabetico, 4 criteri: Alfabetico · Per data · Dislivello (D+) · Quota più alta.

### Google Drive su Android
Provider cloud per piattaforma: Android solo Google Drive (iCloud nascosto), iOS
selettore iCloud (default) · Google Drive. Client OAuth Android (package + SHA-1 debug) e
Web (`GOOGLE_SERVER_CLIENT_ID`) creati in Google Cloud. Toolchain Android reinstallata:
JDK 17 + Android SDK 36 + NDK 28.2 + CMake, via `sdkmanager`. Checklist:
`docs/cloud-google-drive-setup.md` §5.

### Fix — Dark Mode: testi invisibili + sfondi incoerenti
Segnalato da tester via TestFlight su iPhone reale: in Dark Mode i testi risultavano
chiari su sfondi chiari hardcodati (quasi invisibili) e le liste Cupertino
renderizzavano scure in mezzo a sezioni chiare. Causa: l'app dichiarava `theme` +
`darkTheme` ma aveva sfondi chiari hardcodati (`_kGroupedBg`, vetro bianco) mentre il
testo seguiva la brightness di sistema. **Fix (temporaneo, poi superato il 23 luglio):**
forzato il light mode in tutta l'app (`themeMode: ThemeMode.light` + override
`platformBrightness` nel `builder`, così anche i widget Cupertino restavano chiari).

### Distribuzione — build `1.0.0+4` rilasciata ai tester
iOS su TestFlight (gruppo interno "Amici", IPA caricata via Xcode Organizer — la CLI
`flutter build ipa` falliva l'export per mancanza di un Apple ID in *Xcode → Settings →
Accounts*) + APK Android (122 MB, debug-signed, Drive-ready) distribuito ai tester
Android. Privacy policy pubblicata su GitHub Pages, repo reso pubblico. Guide:
`docs/testflight-setup.md`, `docs/testflight-amici.md`.

---

## 2 luglio 2026 — build `1.0.0+3`

- **Vista Mappa ⇄ Satellite**: tasto "vista" in barra alterna direttamente le due viste
  (`satellite-streets-v12`); re-setup completo (terreno 3D, sky, layer sentieri CAI,
  annotation) a ogni cambio stile; terreno ri-applicato al primo idle dopo lo switch (fix
  "3D piatto dopo il cambio vista").
- **Info punto (mini-card esplorazione)**: toccando un punto della mappa senza tracce
  vicine, mini-card in vetro con quota (DEM Terrarium, anche offline sulle aree
  scaricate), coordinate (copia al tap) e località/provincia/nazione (reverse geocoding
  Nominatim). Marker pallino+anello sul punto ispezionato.
  Rif. `features/map_gl/inspected_point_provider.dart`.
- **Pannello di ricerca in vetro**: `GlassSurface` al posto di `Material`/elevation;
  chiusura al tap sulla mappa.
- **Ornamenti Mapbox** riposizionati (logo/attribuzione sollevati sopra la barra
  flottante, non rimovibili per ToS Mapbox).
- **Card traccia selezionata**: tasto X per chiudere/deselezionare, matita di modifica
  nella riga azioni.
- Privacy policy pubblicata (richiesta da App Store/TestFlight).

---

## 25 giugno – 1 luglio 2026 — build `1.0.0+2` e revisione estetica iOS

### Segnavia e difficoltà CAI
- **Numeri sentiero via Overpass** (`OverpassTrailService`): relazioni `route=hiking`
  vicine ai punti del percorso → `ref` (es. "203", "203E"), mostrati come chip nella card.
- **Catasto ufficiale OSM2CAI/INFOMONT** (CAI + Wikimedia Italia, ODbL) aggiunto come fonte
  primaria per l'Italia, con Overpass come fallback per le zone di confine FR/CH.
  Interfaccia comune `TrailService` (template method, segmentazione condivisa) +
  `Osm2CaiTrailService` + `OverpassTrailService` + `CombinedTrailService`. Risolve i
  segnavia mancanti dove il tag OSM grezzo manca ma il sentiero è accatastato CAI (es.
  Valle d'Aosta). Indagine endpoint: `docs/osm2cai-investigation.md`.
- **Grado di difficoltà CAI** (`cai_scale`, T/E/EE/EEA): seconda banda nel grafico
  altimetrico sotto i numeri segnavia, chip di sintesi nella card (tratto più
  impegnativo). Letto da entrambe le fonti (OSM2CAI `properties`, Overpass `tags`),
  persistito in `track_codec.dart` (retro-compatibile).
- **Fix "ricerca fallita ≠ vuota":** i servizi segnavia inghiottivano gli errori di
  rete/timeout e tornavano lista vuota, marcando erroneamente la traccia come "cercata e
  non trovata" senza retry. Ora lanciano `TrailLookupException` su errore e ritornano
  `[]` solo su risposta valida senza sentieri; migrazione schema DB per ri-cercare le
  tracce bloccate dal vecchio comportamento.
- **Backfill lazy**: le tracce salvate prima di questa funzionalità cercano segnavia/
  difficoltà una sola volta alla selezione, non ad ogni riselezione.

### Card traccia ridisegnata
Creazione = vista essenziale (nome, colore, annulla/undo/Salva); al Salva la card resta
aperta con spinner finché percorso/dislivello/segnavia non sono pronti; selezione =
distanza, D+/D-, segnavia, chip difficoltà CAI, profilo on-demand.

### Toggle "Segui i sentieri" (poi rimosso il 5 luglio, snap sempre attivo)
Introdotto perché fuori sentiero (ghiacciai, creste senza tracce OSM) lo snap produceva
percorsi sbagliati: il profilo BRouter `hiking-mountain` falliva per timeout server
(*"operation killed by thread-priority-watchdog"*) e l'unico che "riusciva",
`trekking`, deviava su way non pertinenti. **Fix definitivo:** catena di profili
`hiking-mountain` (con retry) → `trekking`, linea retta solo se entrambi falliscono.

### Revisione estetica iOS — "vetro smerigliato"
Nuovo primitivo condiviso `lib/ui/glass.dart` (`GlassSurface`/`GlassCircleButton`):
superfici translucide con blur, bordo chiaro sottile, press-dim Cupertino. Applicato
progressivamente a: controlli mappa (bussola/posizione/2D-3D come cerchi in vetro),
barra in basso (pillola con ricerca/+/lista/impostazioni), card traccia, Impostazioni e
Tracciati (liste inset-grouped Cupertino), dialoghi (`CupertinoAlertDialog` al posto di
`AlertDialog`), toast iOS condiviso (`lib/ui/ios_toast.dart`, sostituisce tutte le
`SnackBar`), tipografia di sistema (rimosso `google_fonts` Lato → San Francisco su iOS).
*Nota:* il blur non attraversa la platform view Mapbox (compensato con più trasparenza);
resta pieno su menu/liste/impostazioni (pagine Flutter pure).

### Distribuzione — APK Android
`build/app/outputs/flutter-apk/app-release.apk`, debug-signed (ok sideload, non Play
Store). Toolchain Android migrata: Gradle 9.1.0 / AGP 9.0.1 / Kotlin 2.3.20 / Java 17,
`compileSdk=36`. Guida: `docs/android-apk-setup.md`.

---

## 16-25 giugno 2026 — build `1.0.0+1`, prima beta e sviluppo iniziale

### Fase 0 — scheletro
Progetto Flutter inizializzato (`com.mattiacuratitoli.sentei`), struttura cartelle come
da CLAUDE.md §5, catalogo sorgenti mappa iniziale (OpenTopoMap/SwissTopo/IGN/OSM +
Waymarked Trails), Riverpod + go_router.

### Logica geo (dominio, Fase 1.C)
`PathGeometry` (haversine cumulativo + densificazione), `ElevationCalculator` (D+/D- con
deadband anti-rumore DEM), `Terrarium.decodeElevation` (decoder pixel→quota),
`TerrariumElevationService` (fetcher iniettabile + cache LRU), `TrackMetricsCalculator`
(orchestratore). 28 test di dominio.

### Disegno tracciato + snap-to-trail
Tap-to-add waypoint, undo, drag, marker partenza/arrivo, frecce di direzione. Il
percorso segue i sentieri OSM via **BRouter** (servizio pubblico, profilo
`hiking-mountain`, no API key), con fallback a linea retta. Routing reso via
per-segmento con retry per isolare i fallimenti a un singolo tratto invece che
all'intera traccia. Multi-traccia: stato `TracksState`/`Tracks`, ogni traccia con nome,
colore, snap indipendenti.

### Persistenza e GPX
`drift` + SQLite (`AppDatabase`/`TracksRepository`), lista tracciati con import/export
GPX (`gpx`, `file_selector`, `share_plus`).

### Migrazione a Mapbox GL (5 fasi, validata su iPhone)
Da `flutter_map` a `mapbox_maps_flutter`: motore unico, stile Outdoors, terreno 3D
(gesto nativo a due dita), numeri CAI come etichette lungo i sentieri, editing
(tap/drag/seleziona) wired a `Tracks`. `flutter_map` rimosso. Piano:
`docs/plan-mapbox-gl-migration.md`, `docs/eval-3d-map.md`.

### Offline (mappa + elevazione)
Mappa: Mapbox OfflineManager + TileStore (`loadStylePack` + `loadTileRegion` sulla bbox
visualizzata, con progress). Elevazione: `TerrariumTileCache` su disco +
`cachingTerrariumFetcher`, download tile z13 del bbox — D+/profilo funzionano offline
per le aree scaricate.

### Sync cloud
Interfaccia comune `CloudSyncService` + `TrackCodec` (serializzazione condivisa) +
motore last-write-wins (`computeSyncPlan`). Backend Google Drive (`google_sign_in` +
`googleapis`, cartella "Sentèi") e iCloud Drive (`icloud_storage`, capability Xcode).
Auto-sync su salvataggio/import/eliminazione.

### Estetica mappa e ricerca
Stile Mapbox Outdoors con hillshade + cielo atmosferico; ricerca luoghi/rifugi
(Mapbox Geocoding + Nominatim OSM come fallback); focus automatico della mappa
selezionando una traccia dalla lista.

📦 **Stack storico (pre-migrazione Mapbox):** `flutter_map ^8.3.0`,
`flutter_map_dragmarker ^8.0.3`, `flutter_riverpod ^3.3.2`, `go_router ^17.3.0`,
`latlong2 ^0.9.1` — per lo stack attuale vedi `CLAUDE.md` §3.

---

## Decisioni di progetto (non legate a una release)

### Pubblicazione sugli store con sblocco tramite codice alfanumerico (22 luglio 2026)
**Domanda:** pubblicare su App Store/Play Store ma limitare l'uso a chi inserisce un
codice alfanumerico — fattibile?

**Esito: fattibile su entrambi gli store**, purché il codice sia realmente funzionante
durante la review (Apple Guideline 2.1 "App Completeness" + minimum functionality; Play
richiede di dichiarare l'accesso ristretto in Play Console "App access"). Nessuna
guideline vieta il pattern in sé (inviti, licenze, beta chiuse).

**Decisione presa: iOS Unlisted App Distribution + Android Play closed testing con
Google Group — niente codice, niente vetrina pubblica.** Motivazione: il codice
alfanumerico è lato client → non protegge davvero il token Mapbox (estraibile dal
binario) né i costi; la pubblicazione pubblica massimizza l'esposizione che si vuole
evitare. Alla scala "amici" i costi Mapbox restano nel free tier comunque.

- **iOS — Unlisted:** app in review normale, poi resa "unlisted" (non in ricerca,
  accessibile solo via link diretto `apps.apple.com/...`, stabile e permanente).
  Aggiornamenti = flusso App Store normale, stesso link. Revocabile ("Remove from
  Sale", non retroattivo). Modello **link-gated**, non per-utente.
- **Android — Play closed testing con Google Group:** modello speculare, ma
  **identity-gated** — solo gli account Google membri del gruppo installano; si
  gestiscono aggiungendo/rimuovendo membri dal gruppo. Richiede: account Play Console
  (25$ una tantum), upload keystore di release (oggi l'APK è debug-signed), build
  `.aab` invece di APK.

I passi operativi non ancora completati sono in `ROADMAP.md`.

### Login autenticato e analitiche d'uso (22 luglio 2026)
Obiettivo esplorato: login Google/Apple per identificare gli utenti (Google Sign-In già
integrato per Drive; Sign in with Apple necessario su iOS per la guideline 4.8 se si
offre un login social) + analitiche d'uso (map load Mapbox, tracce salvate, feature
usate) per monitorare i costi mappe. **Decisione architetturale non ancora presa:**
introdurrebbe un'identità server-side che oggi l'app non ha (privacy-first, zero
backend) — da discutere prima di implementare. Item ancora aperto, vedi `ROADMAP.md`.
