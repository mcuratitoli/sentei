# Roadmap — Sentèi

> Piano di lavoro operativo: **solo punti aperti**, in ordine di priorità. Il completato è
> stato spostato nel changelog tecnico — vedi i riferimenti in fondo.

**Aggiornato:** 28 agosto 2026 · **Stato:** beta `1.0.0+10` in preparazione per la
distribuzione ai tester (iOS/Android) — vedi `CHANGELOG.md` per le novità della build.

## Come leggere questo documento

- Le sezioni sono numerate **P1 → P8** in ordine di priorità (P1 = da affrontare per primo).
- Ogni punto è etichettato **[FIX]** (comportamento rotto/incoerente di una feature già
  rilasciata), **[FEATURE]** (funzionalità nuova) o **[TASK]** (lavoro tecnico, non visibile
  all'utente).
- **SP** = story point, peso di complessità in scala Fibonacci 1-2-3-5-8-13: 1-2 banale
  (minuti), 3 qualche ora, 5 mezza giornata, 8 giornata piena su più file, 13 epica da
  spezzare in sotto-task prima di iniziare.
- `[ ]` = da fare, `[~]` = iniziato/parziale.
- **Dentro ogni sezione P, i punti sono ordinati per SP crescente** (i più rapidi prima),
  eccetto **P1**, il cui ordine A→B→C è dato dall'utente (segnalato nella sezione), e i
  punti citati per posizione altrove nel repo. Le sigle **storiche** `P1.1`/`P1.2`/`P1.3`
  si riferiscono ai tre lavori chiusi 12–24 ago 2026: mappatura sigla → lavoro nella voce
  del 28 ago 2026 di `docs/CHANGELOG-DEV.md`.

---

## P1 — Priorità massima (28 agosto 2026)

> **Intestazione riassegnata.** I tre lavori storici di P1 — **P1.1** fluidità foto
> (12 ago), **P1.2** tempo di percorrenza CAI (15 ago), **P1.3** epica "capire un segnavia
> dalla mappa" (24 ago) — sono **completati** e documentati per esteso in
> `docs/CHANGELOG-DEV.md` (voci di quelle date) e in `CHANGELOG.md` (build `1.0.0+6` →
> `+10`). Le sigle `P1.1`/`P1.2`/`P1.3` usate lì, in `docs/validazione-device.md` e più
> sotto in P2/P3 continuano a riferirsi a quei lavori — mappatura sigla → lavoro nella voce
> del **28 ago 2026** di `docs/CHANGELOG-DEV.md`.
>
> Dal 28 agosto P1 ospita **tre nuovi lavori** a massima priorità, decisi con l'utente.
> **Ordine A→B→C dato dall'utente, non riordinato per SP** (come già la vecchia P1).
>
> **Stato (31 ago):** A ✅ implementato — in attesa del test su device dell'utente per la
> rifinitura; C ✅ (C1 + C2); B ✅ (v1: tracce salvate; EEA con dash-punto di ripiego). Da
> validare su device fisico: quota reale in A, valori di tratteggio in B (→ P8).
>
> *Totale indicativo: ~16 story point (A 3 · C 5 · B 8).*

### A. [FEATURE] Indicatore di quota e coordinate correnti (HUD posizione) — *SP 3* — [~] in corso (28 ago 2026)

Lettore **sempre visibile** sulla schermata mappa con **quota** e **coordinate** della
posizione GPS dell'utente — il dato che si consulta di continuo in escursione ("a che quota
sono?", "che punto do al soccorso?") e che oggi si ottiene solo toccando un punto a caso
sulla mappa (card "punto ispezionato"). Dettaglio implementativo: voce **28 ago 2026** in
`docs/CHANGELOG-DEV.md`.

- [x] **Widget overlay** (`_PositionHud` in `map_gl_screen.dart`, Stack): collassato =
  icona terreno + quota + chevron; espanso = accuratezza orizzontale + coordinate (gradi
  decimali, una riga) con copia. Stessa `GlassSurface` di menubar/bottoni a destra.
  *Mockup ricevuto dall'utente in sessione, non ancora versionato in `design/`.*
- [x] **Sorgente dati** — `LocationService.fixStream()` → `GpsFix` (lat/lon + accuratezza
  orizzontale + quota + accuratezza verticale); provider `gpsFixProvider` agganciato a
  `userLocationProvider` per non chiedere i permessi due volte.
- [x] **Quota: solo GPS, niente DEM** — mostrata solo se l'accuratezza verticale è nota e
  **≤ 25 m** (soglia decisa con l'utente); altrimenti trattino + riga esplicativa da
  espanso. Scelta: qui interessa la quota **reale dell'utente**, non quella del terreno
  (diverso dalla card "punto ispezionato", che usa il DEM).
- [x] **Stati degeneri** — nessun fix / permesso negato → l'HUD non compare; quota non
  affidabile → trattino.
- [x] **Formato coordinate** — gradi decimali inline; copia negli appunti come
  `lat, lon` (6 decimali) + toast, come la card punto ispezionato.
- [ ] **Nascondere l'HUD** quando una bottom sheet lo copre e durante lo snapshot per
  l'export immagine — da fare.
- [ ] **Validazione su device** (P8): sul simulatore iOS la quota è sempre a trattino
  (nessuna accuratezza verticale realistica) — il valore va verificato su telefono fisico.
- [x] **Ornamenti Mapbox** riposizionati insieme a questa fetta (scale bar in alto a
  sinistra sopra la card; logo + "i" in basso a sinistra). Barra scala *centrata* sotto il
  menu non fattibile col nativo (`OrnamentPosition` = solo 4 angoli) — servirebbe un widget
  custom, da decidere se vale.
- **Logo Mapbox: obbligatorio.** I termini d'uso Mapbox vietano di rimuovere/nascondere sia
  il logo sia l'attribuzione ("i") con un account standard (serve un accordo Enterprise).
  Si può solo **riposizionare** (4 angoli + margini) e tenere l'attribuzione compatta come
  icona "i" — già così. La **dimensione** del logo non è esposta dall'API Flutter.
  Conclusione: resta dov'è, in basso a sinistra il più defilato possibile.
- [ ] **Da testare su device fisico** (utente, 30 ago) — poi rifinitura in base al
  feedback.

### B. [FEATURE] Difficoltà CAI resa sullo stile della linea del tracciato — *SP 8* — ✅ fatto (31 ago 2026)

Sul tracciato, ogni tratto ha uno **stile di linea diverso in base al grado CAI**,
replicando la legenda delle carte escursionistiche (Tabacco/CAI — foto reale, sessione
30 ago). Dettaglio: voce **31 ago 2026** in `docs/CHANGELOG-DEV.md`.

| Grado | Legenda carta | Reso in-app (`caiScaleDash`, unità di larghezza linea) |
|---|---|---|
| **T** / sconosciuto | linea continua | nessun dash |
| **E** | trattini | `[2.5, 2]` |
| **EE** | punteggiato | `[0.4, 2]` + `line-cap: round` (punti rotondi) |
| **EEA** | crocette via ferrata | `[2, 1.2, 0.4, 1.2]` (dash-punto, ripiego) |

- [x] **Fonte unica** — `caiScaleDash(scale)` in `lib/ui/cai_difficulty.dart`, condivisa da
  mappa e legenda.
- [x] **Colore invariato** — cambia solo il tratteggio, la linea resta del colore del
  tracciato; casing bianco invariato.
- [x] **Tratti senza dato CAI = linea piena** (come T).
- [x] **Resa tecnica** — `line-dasharray` non data-driven → un `PolylineAnnotationManager`
  per stile (`_savedLinesE`/`_savedLinesEE`/`_savedLinesEEA`, + `_savedLines` pieno per
  T/sconosciuto, + `_savedFreeLines` per i liberi). Nuovo helper puro `sliceStyledRuns`
  (`domain/services/track_runs.dart`) che spezza i run agganciati per `caiScale` per
  distanza cumulata; test in `test/domain/track_runs_test.dart` (6 casi). 260 test verdi.
- [x] **Tratti "liberi"** — restano un solo run col loro tratteggio (`caiScale: null`),
  lo stile-difficoltà vale solo per gli agganciati.
- [x] **Legenda** — `showDifficultyLegend` (`lib/ui/legends.dart`): campione della linea
  (`_LineStylePainter`) accanto a ogni grado + riga introduttiva.
- **EEA fedele (crocette con sprite/`SymbolLayer`)** — rifinitura rimandata; il dash-punto è
  il ripiego v1.
- **Ambito v1**: tracce **salvate/selezionate** sulla mappa. La linea live durante il
  drag-editing resta piena (i `trailSegments` non sono ancora risolti mentre si trascina);
  lo stile compare appena finito/salvato. Da estendere all'editing se serve.
- **Perf**: 3 manager in più; con molte tracce sulla mappa, tenere d'occhio il conteggio
  annotation.
- [ ] **Da tarare su device** (P8): valori di `caiScaleDash`, leggibilità EE (punti) a
  vari zoom.

### C. [FEATURE] Tempi di percorrenza per un intervallo scelto — *SP 5* — ✅ fatto (30 ago 2026)

> *Spezzato: **C1** dominio + rimozione split automatico — **fatto**;
> **C2** selezione manuale dell'intervallo sul profilo — **fatto**.*

Oggi il tempo stimato è sempre sull'intera traccia e, per i percorsi "chiusi" (anello /
andata-e-ritorno), viene **diviso automaticamente** salita/discesa nel punto di quota
massima. Si **toglie lo split automatico** — default: **una sola stima start → end** — e si
aggiunge una **modalità manuale** per stimare il tempo su un tratto scelto: start → un
punto, tra due punti, o un punto → fine (i tre casi sono lo stesso meccanismo "scegli
indice A e indice B", con A=0 o B=ultimo come casi particolari).

- [x] **C1 — dominio** — `estimateForTrack` sostituito da
  `estimateRange(profile, {startIndex = 0, endIndex, pace})` → `HikingRangeEstimate` (tempo
  + distanza + D+/D- della sotto-tratta, deadband ricalcolato sulla sola tratta). Coi
  default = intera traccia, identico a prima. La formula CAI/SAC (`estimate`, `min/4`)
  invariata. Indici in qualsiasi ordine, clampati; intervallo degenere → `.zero`.
- [x] **C1 — rimozione** — via `_splitAtPeak`, `_Legs`, `HikingTimeEstimate`
  (`ascent`/`descent`/`isSplit`), `closedLoopThresholdMeters` e le frecce ↗/↘ da
  `_HikingTimeRow` (ora prende un `Duration`). Callers (`draw_route_controls`,
  `tracks_list_screen`, `export_image_screen`) passati a `estimate(...)` diretto. Test
  `estimateForTrack` → `estimateRange` (254 verdi). Dettaglio: voce **30 ago 2026** in
  `docs/CHANGELOG-DEV.md`.
- [x] **C2 — UI selezione intervallo** — `ElevationProfileChart` ha ora `selecting` +
  `onPickIndex`: nella card, il tasto testuale "Tempo di un tratto" entra in modalità
  selezione (i tap scelgono gli estremi invece di fare scrubbing), il testo di supporto
  guida ("Tocca l'inizio/la fine del tratto"). Provider `profileRangeProvider`
  (`ProfileRangeSel {a, b}`, transitorio, azzerato al cambio traccia e alla chiusura del
  grafico). Il painter disegna maniglia + linea sui due estremi e scurisce fuori
  dall'intervallo. Funziona anche per un GPX importato (è index-based sul profilo).
- [x] **C2 — risultato** — `_HikingRangeRow`: "Tratto: circa <tempo> · <dist> · ↗X ↘Y m"
  con la × per tornare al totale. Query transitoria, **non** persistita. La riga del tempo
  totale (`_HikingTimeRow`) resta il default quando non c'è selezione.
- [x] **Test** — `estimateRange` puro (default = totale, solo-salita, solo-discesa, tratta
  centrale, indici invertiti/coincidenti/fuori-range, profilo < 2 campioni). 254 verdi.
- Nota: i tap sintetici sul simulatore (`osascript`) cadono sempre al centro del grafico
  (press di accessibilità, non a coordinate) → intervallo di lunghezza 0. La logica di
  `pick` è verificata via log; l'intervallo reale va provato su device.

---

## P2 — Feedback test su device (24 luglio 2026, ridotta 18 agosto 2026)

> Osservazioni raccolte testando la beta `1.0.0+4` direttamente sul telefono. Restano
> prioritarie, subito dopo i tre lavori di P1. **Il 18 agosto** due punti sono stati
> promossi a P1 (tasto elimina, evidenziazione traccia selezionata) e uno tolto perché già
> rilasciato in `1.0.0+8` (focus mappa dopo l'import — 29 luglio 2026, vedi
> `docs/CHANGELOG-DEV.md`), risultava ancora aperto qui per una svista. Ordine aggiornato
> per SP crescente. **Il 26 agosto** si sono aggiunti i punti 5-6 (bug emersi dal test dal
> vivo sull'epica segnavia, storico P1.3), in coda invece che riordinati per SP — nati a
> fine sessione, mantenerne l'ordine di scoperta per ora.

1. [ ] **[TASK] Passata di pulizia del codice** — *SP 1*. A fine implementazione dei punti
    sotto, eseguire una verifica di pulizia/coerenza (skill `simplify`) sulle modifiche.
2. [ ] **[FIX] Interazione poco intuitiva per annullare la ricerca luogo** — *SP 2*. Nel
   pannello di ricerca l'unico modo per uscire è il chevron verso sinistra, poco leggibile
   come "annulla ricerca". Valutare una X esplicita o un gesto più standard (tap fuori dal
   pannello).
3. [ ] **[FEATURE] Epica "Foto lungo il percorso" — completare l'esperienza immagini** —
    *SP 8* (da spezzare in sotto-task in fase di implementazione; l'analisi architetturale
    è già fatta in `docs/eval-photo-sync.md`). **Fatto** (27 luglio 2026, vedi
    `docs/CHANGELOG-DEV.md`): card di dettaglio foto unificata (stessa sia dal pin mappa sia
    dalla striscia nella card traccia) con titolo/coordinate/quota/data-ora e azioni
    "Modifica titolo"/"Scollega"; apertura a schermo intero della foto originale (se ancora
    reperibile sul device); evidenziazione + auto-scroll della thumbnail scorrendo il
    grafico; thumbnail più piccole. **Resta da fare:**
    - il tasto immagini nella card deve permettere di **importare nuove foto**, oltre a
      mostrare/nascondere le anteprime esistenti (oggi "Trova foto vicine" importa, ma non
      c'è un modo per nascondere/mostrare la striscia già collegata);
    - serve una **vista a griglia** con tutte le foto della traccia, con selezione multipla
      e azioni bulk (es. eliminazione massiva) — quando esisterà, anche i suoi tap dovranno
      passare da `_selectPhoto` (vedi voce "un solo pallino" sotto, 16 ago 2026) per centrare
      la mappa come fanno già tutti i punti di tap attuali;
    - fix minore: il testo "Trovate X immagini" (import foto) risulta ancora sottolineato
      in giallo (probabile residuo di sottolineatura di debug, stesso bug già risolto
      altrove con `DefaultTextStyle(decoration:none)`).
4. [ ] **[FEATURE] Export immagine: zoom/angolazione della mappa personalizzabili** —
    *SP 3*. Oggi la camera (zoom, inquadratura, bearing dal dislivello) è calcolata **una
    sola volta**, in automatico (`route_snapshot.dart`), senza possibilità di modifica prima
    di generare. Due strade valutate (23 agosto 2026), nessuna implementata:
    - **A. Mappa interattiva libera come passo intermedio** (pizzica/trascina/ruota
      standard Mapbox, poi "Conferma inquadratura"). Più potente ma richiede riorganizzare
      il flusso (fetch POI → **editing camera** → cattura con quella camera → pronto, invece
      dell'attuale fetch POI → cattura automatica → pronto: i pixel dei POI vanno ricalcolati
      **dopo** la conferma, non prima) e mostrare quella mappa alla sua dimensione naturale,
      non ridimensionata — lezione di questa sessione: le view native Mapbox dentro
      trasformazioni Flutter (`FittedBox`/scale) si disallineano tra la dimensione usata per
      `pixelForCoordinate` e quella effettivamente renderizzata (vedi `docs/
      CHANGELOG-DEV.md`, 23 agosto 2026, il bug del "pallino nel nulla").
    - **B. Slider semplici (zoom +/-, rotazione) sopra l'anteprima già generata** —
      **consigliata**: nessuna mappa interattiva da gestire, solo due controlli numerici che
      al rilascio richiamano di nuovo lo Snapshotter con la nuova camera. Copre la maggior
      parte del bisogno reale (più/meno zoom, ruota un po') con molto meno rischio tecnico
      di A; A vale la pena solo se serve controllo davvero libero (pan per spostare il
      centro, tilt libero).
5. [ ] **[FIX] CAI Varallo: alcuni segnavia esistenti non vengono trovati** — *SP 3*.
   Segnalato dall'utente il 26 agosto 2026: il segnavia 251C, verificato manualmente
   presente sul sito, risultava "non trovato" da `CaiVaralloSearchService.findByRef`.
   Investigazione lampo (non una fix) la stessa notte: un `curl` diretto verso l'elenco ha
   restituito **due volte di fila** `HTTP 200` con la struttura della pagina intatta ma
   **zero righe** nel mezzo, a fronte di richieste dell'app riuscite poco prima con
   centinaia di voci (251, 253, 215, 215C tutte trovate). Il sito sembra quindi
   **intermittente** (stessa categoria di affidabilità di Overpass) più che un bug di
   parsing sicuro dal nostro lato — ma non escluso al 100%. Log diagnostico già aggiunto
   (`cai_varallo_search_service.dart`, 26 ago): distingue "pagina vuota" da "pagina con
   voci ma nessun match esatto" per la prossima sessione. Non approfondito oltre su
   richiesta esplicita dell'utente ("per ora lascia così").
6. [ ] **[FIX] Affidabilità della ricerca Overpass da riconfermare** — *SP 2*. Durante i
   test dal vivo del 25-26 agosto 2026 la ricerca falliva spesso (fino a `Connection
   refused` su tutte le istanze); i fix della stessa serata (interruttore, mirror ridotto a
   uno indipendente, corsa a staffetta con avanzamento rapido su fallimento) hanno
   visibilmente migliorato la situazione nelle ultime prove, ma l'utente non si fida ancora
   al 100% ("anche se ora sembra migliorato"). Da riverificare con un giro di test più
   lungo/rilassato (non concentrato in un'unica sessione di più ore, che può aver
   contribuito essa stessa al problema — vedi `docs/CHANGELOG-DEV.md`, 25 ago).

*Totale indicativo: ~19 story point — riferimento per pianificare, non un vincolo rigido.*

---

## P3 — Editing tracce & UX mappa (aperti, ordine per SP crescente)

- [ ] **Linee sentieri visibili sul layer mappa** — *SP 2*. Costo quasi zero: la geometria
  dei sentieri (`sentei-trails`) è già scaricata per posizionare le etichette, manca solo una
  `LineLayer` che la disegni. *Naturale da fare insieme all'epica segnavia (storico
  **P1.3**, `docs/CHANGELOG-DEV.md`): serve comunque un layer selezionabile su cui fare
  `queryRenderedFeatures`.*
- [ ] **Separazione strade/sentieri su Mapbox** — *SP 3*. Nascondere i layer strada-sterrata
  dello stile Outdoors mostrando solo i sentieri OSM/CAI; da rivalutare quando la qualità dei
  sentieri in mappa diventa priorità (analisi delle opzioni già fatta).
- [ ] **[TASK] Studiare la grafica della mappa in ottica GaiaGPS** — *SP 3*. Valutare come
  avvicinare stile/leggibilità della mappa (colori, spessori sentieri, etichette, terreno)
  a quello di GaiaGPS, nei limiti dello stile Mapbox Outdoors in uso (§2 CLAUDE.md); capire
  cosa è personalizzabile via stile Mapbox custom vs cosa richiederebbe layer aggiuntivi.
- [ ] **Migrazione layer sentieri a OSM2CAI** — *SP 5*. Stessa idea sopra ma con `ref`/
  `osmc_symbol`/`cai_scale` da OSM2CAI invece di Overpass (più ricco, limite bbox da
  gestire con zoom minimo/fallback). *Anche questo confluisce nell'epica segnavia (storico
  **P1.3**), che richiede id e tag della relazione.*
- [~] **Sync foto lungo il percorso** — *SP 8, vedi P2 punto 3*. Analisi e decisione
  architetturale fatte (`docs/eval-photo-sync.md`), implementazione UI in corso su branch
  dedicato: vedi i requisiti dettagliati in **P2, punto 3**.
- [ ] **Versione Web** (browser desktop) — *SP 13 (epica)*. PoC necessario:
  `mapbox_maps_flutter` non gira su Flutter Web (richiede Mapbox GL JS o
  `flutter_map`/MapLibre dietro l'astrazione mappa già engine-agnostica); da verificare
  anche `drift` (WASM), `path_provider` (non disponibile su web), sync cloud lato browser.
  Prima decisione da prendere: MVP sola-visualizzazione vs editing completo.

## P4 — Build & toolchain (ordine per SP crescente)

- [ ] **Tetto sulla cache tile di Mapbox (`TileStore`)** — *SP 5*. Segnalato dall'utente su
  device fisico (23 ago 2026, "l'app pesa centinaia di mega"): risolta la causa più a
  monte, la cache di elevazione senza limiti (vedi `docs/CHANGELOG-DEV.md`), ma resta il
  secondo sospetto verificato e non escluso — la cache tile di Mapbox (condivisa fra aree
  scaricate offline e navigazione online normale) non ha un tetto configurato. Il codice
  sorgente del plugin conferma che è già esclusa dal backup iCloud, ma
  `mapbox_maps_flutter` 2.25 **non espone `setDiskQuota` (o equivalente) nei binding
  Dart** — servirebbe codice nativo (Swift `AppDelegate`/Kotlin) per richiamare l'API
  nativa del `TileStore`. Da riconsiderare se il problema di spazio si ripresenta dopo il
  fix della cache elevazione.
- [ ] **CI base** (GitHub Actions: `flutter analyze` + `flutter test`) — *SP 3*. Non ancora
  configurata.
- [ ] **Aggiornamento Flutter** (`flutter upgrade` + `pub upgrade --major-versions`) —
  *SP 8*. Sessione dedicata dopo la beta, rischio regressioni mapbox/drift/riverpod.

## P5 — Rimandati (ordine per SP crescente)

- [ ] **Bundling font offline** — *SP 2*. Ora scaricati a runtime via `google_fonts`... nota:
  su iOS si usa già il font di sistema, verificare se il bundling serve ancora su Android.
- [ ] **Registrazione traccia live** — *SP 13 (epica)*. Background location, Fase 2 del
  CLAUDE.md.

## P6 — Distribuzione & accesso (ordine per SP crescente)

**Decisione presa (22 luglio 2026):** iOS **Unlisted App Distribution** + Android **Play
closed testing** con Google Group — niente codice di sblocco, niente vetrina pubblica.
Motivazione e analisi completa in `docs/CHANGELOG-DEV.md`.

- [ ] iOS: submit review della build corrente + richiesta Unlisted. — *SP 2*
- [ ] Documentare i due flussi in `docs/` (es. `docs/distribuzione-unlisted.md`). — *SP 2*
- [ ] Android: creare Play Console, generare upload keystore, build `.aab` (non più APK),
  track closed testing + Google Group come lista tester. — *SP 5*
- [ ] **Analitiche d'uso** — *SP 13 (epica)*. Analisi completa fatta e aggiornata (24 luglio 2026,
  `docs/eval-usage-analytics.md`): privacy policy non è un vincolo (2 tester consapevoli),
  login **escluso** (decisione presa dall'utente). Mapbox Dashboard + **alert di soglia**
  Mapbox (zero costo, avvisa prima di sforare il tier gratuito) + App Store Connect
  Analytics coprono già "accessi Mapbox"/"app aperta" senza scrivere nulla. Priorità
  raccomandata: **affidabilità dei servizi terzi** (BRouter/OSM2CAI/Overpass/sync, oggi
  invisibile — causa già di bug reali passati sotto silenzio) più che i conteggi grezzi.
  **Sfruttando la VM DigitalOcean già disponibile** (nessun costo aggiuntivo, massimo
  controllo): stack self-hosted proposto **GlitchTip** (errori, compatibile SDK Sentry) +
  **Umami o endpoint fatto in casa** (adozione feature) + **Grafana** sopra entrambi per
  la dashboard unica. Decisione da prendere: Umami vs fatto-in-casa per il Layer 2/3, e
  specifiche della VM per dimensionare lo stack.
- [x] **Login autenticato (Google/Apple)** — *decisione, non SP-ordinabile*: escluso — l'utente ha deciso di restarne fuori
  per non "slegarsi da problematiche" non necessarie; nessuna delle analitiche sopra lo
  richiede. Vedi `docs/eval-usage-analytics.md` §6. Riaprire solo per un motivo diverso
  dalle analitiche (continuità multi-dispositivo, supporto utenti).

## P7 — Backlog tecnico (bassa priorità, ordine per SP crescente)

- [ ] **Densificazione del path** — *SP 3*. Passo fisso 15 m di default — valutare passo
  adattivo alla pendenza.
- [ ] **Precisione D+/D-** — *SP 3*. Campionamento DEM Terrarium a z13 di default —
  verificare contro z14/15 sulle Alpi.
- [ ] **Unità di misura** — *SP 3*. Oggi solo metrico — valutare se serve un'opzione
  imperiale.
- [ ] **Affidabilità del BRouter pubblico** — *SP 5*. Durante l'import di una traccia alpina
  reale (29 lug 2026) il server ha rifiutato molti segmenti con `HTTP 400: operation killed
  by thread-priority-watchdog`, su **entrambi** i profili della catena (`hiking-mountain` e
  `trekking`), degradando parecchi tratti a linea retta. Il fallback funziona come
  progettato, ma la resa sulla singola traccia ne risente: se il fenomeno si ripete,
  riconsiderare le alternative con API key già valutate (GraphHopper/Valhalla/ORS, vedi
  `CLAUDE.md` §6.2) o un retry più paziente.
- [ ] **Modello di sync cloud** — *SP 8*. Oggi solo file + last-write-wins — valutare un
  indice o una gestione dei conflitti più fine se servisse.
- [ ] **Multilingua (i18n)** — *SP 8*. Oggi l'app è solo in italiano — aggiungere il
  supporto per l'inglese (`flutter_localizations` + `intl`, estrazione delle stringhe UI in
  ARB), partendo dalle schermate principali (mappa, disegno traccia, lista tracciati,
  impostazioni). Decisione aperta collegata in `CLAUDE.md` §10.
- [ ] **Routing offline** (BRouter embedded, Fase 2 del CLAUDE.md) — *SP 13 (epica)*.
  Confermare la fattibilità reale in Flutter (dimensione dei segment file) prima di
  impegnarsi.

## P8 — Validazione su device

> Fix/feature **già implementati e coperti da test automatici o dal simulatore**, ma non
> ancora confermati a schermo su un **telefono fisico** — capitolo a parte apposta (invece
> di infilarli nei punti "da fare" sopra) per tenerne traccia man mano che ciascuno viene
> confermato, senza dimenticarsene tra una sessione e l'altra. Elenco dettagliato, spuntato
> voce per voce con data e note quando validato:
> **[`docs/validazione-device.md`](./validazione-device.md)**.

---

## Riferimenti

- **[`docs/CHANGELOG-DEV.md`](./CHANGELOG-DEV.md)** — changelog tecnico esteso: tutto ciò
  che è stato completato, con dettagli implementativi, bug e decisioni.
- **[`docs/release-checklist.md`](./release-checklist.md)** — checklist da eseguire ad ogni
  bump di versione per tenere allineati roadmap, changelog e file utente.
- **[`CHANGELOG.md`](../CHANGELOG.md)** — changelog sintetico per chi usa l'app (anche
  in-app, Impostazioni → Informazioni → Sentèi).
- **[`CLAUDE.md`](../CLAUDE.md)** — visione di prodotto, decisioni architetturali fisse,
  stack tecnico, comandi.
