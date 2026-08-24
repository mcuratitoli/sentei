# Roadmap — Sentèi

> Piano di lavoro operativo: **solo punti aperti**, in ordine di priorità. Il completato è
> stato spostato nel changelog tecnico — vedi i riferimenti in fondo.

**Aggiornato:** 24 agosto 2026 · **Stato:** beta `1.0.0+9` in preparazione per la
distribuzione ai tester (iOS/Android), con modifiche già su `main` non ancora rilasciate
(vedi `CHANGELOG.md`, sezione "Non ancora rilasciato").

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
  eccetto dove un punto è citato per posizione altrove nel repo (es. `P1.1`/`P1.2` in
  `docs/CHANGELOG-DEV.md`) — in quel caso resta fisso, segnalato nella sezione.

---

## P1 — Priorità massima (12 agosto 2026, integrata 18 agosto 2026)

> I primi tre temi decisi il 12 agosto come **prime cose da fare**: la fluidità delle foto, la
> stima del tempo di percorrenza e la comprensione dei segnavia sulla mappa. I primi due sono
> lavori chiusi e stimabili (validazione su device in P8), il terzo è un'epica da spezzare.
> **Il 18 agosto** si erano aggiunti due fix rapidi promossi da P2 (tasto elimina nella card,
> evidenziazione della traccia selezionata); **il 23 agosto** sono stati completati e tolti da
> qui — voce ora in `CHANGELOG.md`/`docs/CHANGELOG-DEV.md`. **Il 24 agosto** anche il punto 3
> (l'epica) è stato completato: tutti e tre i punti di questa sezione sono ora chiusi, restano
> visibili qui per riferimento fino al prossimo giro di pulizia della roadmap.
>
> *Numerazione 1-3 fissa* (citata per posizione altrove: `P1.1`/`P1.2` in
> `docs/CHANGELOG-DEV.md`/`docs/validazione-device.md`, "P1, punto 3" in P3) — non riordinata
> per SP come il resto del documento, per non rompere quei rimandi.

### 1. [FIX] Immagini: dimensione e fluidità di caricamento/scroll — *SP 8* — ✅ fatto (12 ago 2026)

Causa-radice confermata: il visualizzatore caricava **l'originale a piena risoluzione**
(~48 MB di bitmap per uno scatto da 12 MP) per riempire un riquadro che ne usa ~4 MB.
Dettagli implementativi e misure in `docs/CHANGELOG-DEV.md`.

- [x] **Decodifica alla dimensione dello schermo** — `PhotoLibraryService.preview()`: è la
  libreria di sistema a ridimensionare. L'originale si carica solo **oltre 1,6× di zoom**.
- [x] **Precarico delle pagine adiacenti** — `PhotoPreviewCache` (LRU 5 voci, richieste in
  volo deduplicate, precarico ±1), svuotata all'uscita dal visualizzatore. Il precarico
  **decodifica** in anticipo (`precacheImage`), non si limita a scaricare i byte:
  altrimenti il lavoro si sposta soltanto al momento dello swipe, che è dove lo scatto si
  vede.
- [x] **Indicatore di caricamento** al centro mentre l'anteprima arriva, invece della
  miniatura stirata a schermo intero. Serve soprattutto alle foto ancora **solo in iCloud**,
  dove PhotoKit deve prima scaricarle.
- [x] **Zoom senza blocchi** — l'originale si decodifica a 2,5× la larghezza dello schermo,
  non a piena risoluzione (48 MP = ~195 MB di bitmap).
- [x] **Miniature: qualità giusta per l'uso** — JPEG q80 invece del default q100, e
  `cacheWidth` sui riquadri piccoli. *Il sospetto della "cover sgranata" era infondato: i
  riquadri più grandi sono 64 pt = 192 px a 3×, sotto i 200 px salvati — un secondo taglio
  di miniatura non serve.*
- [x] **Peso dei metadati sincronizzati** — misurato su 8 foto collegate: JSON della traccia
  da **843,6 KB a 255,0 KB** (105,5 → 31,9 KB per foto), 3,3× in meno su ogni sync.

### 2. [FEATURE] Tempo di percorrenza stimato (metodo CAI) — *SP 8* — ✅ fatto (15 ago 2026)

Manca del tutto: una traccia mostra distanza, D+/D- e difficoltà, ma non "quanto ci metto".
È il dato che ogni cartello CAI riporta, quindi va calcolato **con lo stesso metodo dei
cartelli**, non con una media inventata.

- [x] **Formula scelta: CAI / "ora di marcia"** — velocità di riferimento **4 km/h in
  piano**, **300 m/h in salita**, **500 m/h in discesa** (estremo prudente delle forbici
  indicate in analisi, coerente con la segnaletica italiana), combinate con la formula
  svizzera (SAC): `t = max(t_oriz, t_vert) + min(t_oriz, t_vert) / 2`. Scartate Naismith
  (sottostima sui sentieri alpini) e Tobler per-segmento (avrebbe richiesto una taratura sul
  tipo di terreno che oggi non abbiamo).
- [x] **Servizio di dominio puro** — `lib/domain/services/hiking_time.dart`
  (`HikingTimeCalculator.estimate`), input = distanza + D+/D- **già calcolati** da
  `TrackMetricsCalculator` (quindi D+ con deadband, non il grezzo), nessuna dipendenza dalla
  UI. Coperto da test (`test/domain/hiking_time_test.dart`): piano/salita/discesa isolati,
  combinato, verticale dominante, passo lento/veloce, input a zero.
- [x] **Salita/discesa distinte sui percorsi chiusi** (aggiunta 15 ago 2026, su richiesta
  esplicita) — `HikingTimeCalculator.estimateForTrack`: se partenza e arrivo del percorso
  sono a meno di 150 m (andata e ritorno, o anello — tipico "su al rifugio e giù"), il
  profilo altimetrico viene diviso nel punto di **quota massima** e ogni metà ha il proprio
  tempo (D+/D- ricalcolati con deadband sulla sola tratta, non l'aggregato). Un sentiero
  punto-a-punto resta **una previsione sola**. Mostrato in `draw_route_controls.dart`
  (`_HikingTimeRow`, frecce ↗/↘ come D+/D-); la lista tracciati mostra solo il totale
  (compatta), il dettaglio si apre dalla card.
- [x] **Applicato ovunque c'è un percorso** — la stima legge `DrawnTrack.metrics`, quindi
  vale per traccia in disegno/selezionata (`draw_route_controls.dart`), traccia salvata
  nella lista (`tracks_list_screen.dart`) e GPX importato: nessun percorso diverso, stesso
  `TrackMetrics` per tutti e tre.
- [x] **Passo dell'escursionista** — impostazione Lento/Medio/Veloce persistita
  (`features/settings/hiking_pace_provider.dart`, stesso pattern del tema), "Medio" = il
  riferimento CAI (fattore ×1). Riga "Passo" in Impostazioni → Escursionismo. Il tempo
  mostrato **non include le soste** (convenzione CAI), dichiarato in UI ("di cammino").
- [x] **Difficoltà CAI per tratto tenuta fuori dalla formula** — decisione presa per questa
  iterazione: `TrailSegment.caiScale` già esiste ma pesarlo (EE/EEA più lenti) richiede una
  taratura che oggi non abbiamo dati per fare bene; il passo lento/veloce copre già in parte
  lo stesso bisogno lasciandolo alla scelta dell'utente. Da riconsiderare se il feedback dei
  tester segnala stime sistematicamente ottimiste sui tratti EE/EEA.

### 3. [FEATURE] Capire un segnavia dalla mappa: percorso intero + scheda CAI — ✅ Completa (24 agosto 2026)

Caso d'uso: vedo un rifugio, tocco intorno, trovo un sentiero con un numero — voglio sapere
**dove quel segnavia parte e dove arriva**, vederlo tutto sulla mappa e aprire la scheda
ufficiale. Implementata in 4 fette + un'estensione (fetta 3b), con una UX più semplice di
quella pianificata inizialmente: invece di un tap generico sulla mappa con
`queryRenderedFeatures` e un menu di disambiguazione, si parte da una label segnavia **già
visibile** — sulla card del punto ispezionato (se il tap è vicino a un sentiero) o sulla
card di una propria traccia — e un tap sulla label apre direttamente il flusso; niente
disambiguazione perché la label è già associata a un tratto preciso.

- [x] **Identità della relazione** — `TrailRelation` porta `id`/`source`/`name`/`from`/`to`/
  `osmc:symbol` (fetta 2).
- [x] **Fetch della relazione completa** (non ritagliata) — `TrailService.fetchDetail`,
  OSM2CAI `GET /api/v2/hiking-route/{id}` e Overpass `rel(<id>); out geom;` (fetta 2-3).
- [x] **Mostrarlo** — card di dettaglio (nome, capi-percorso, distanza/dislivelli, difficoltà
  CAI) con dialog di conferma prima del fetch, dalla card del punto ispezionato (fetta 3) e
  dalla card di una traccia propria (fetta 3b, via risoluzione `trailsNear` da un `ref` bare);
  traccia temporanea del segnavia disegnata sulla mappa (tratteggiata, magenta, sopra a
  tutto) con fit-bounds automatico, sparisce alla chiusura della card (fetta 4).
- [x] **Link alla scheda ufficiale** — confermato per Overpass (permalink
  `openstreetmap.org/relation/{id}`, sempre valido); **non implementato per OSM2CAI**
  (`officialUrl` resta `null` per quella fonte — nessun permalink pubblico verificato,
  principio "mai inventare un URL" ancora valido). Arricchimento ulteriore per la Valsesia:
  ricerca su `www.caivarallo.com`, tutti i risultati trovati come link (fetta 3b).
- [ ] **Non incluso, estensione naturale per una prossima epica**: "usa questo segnavia come
  traccia" — import diretto del GPX della relazione nell'editor.

*13 story point.*

---

## P2 — Feedback test su device (24 luglio 2026, ridotta 18 agosto 2026)

> Osservazioni raccolte testando la beta `1.0.0+4` direttamente sul telefono. Restano il
> primo lavoro dopo P1. **Il 18 agosto** due punti sono stati promossi a P1 (tasto elimina,
> evidenziazione traccia selezionata) e uno tolto perché già rilasciato in `1.0.0+8`
> (focus mappa dopo l'import — 29 luglio 2026, vedi `docs/CHANGELOG-DEV.md`), risultava
> ancora aperto qui per una svista. Ordine aggiornato per SP crescente.

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

*Totale indicativo: ~14 story point — riferimento per pianificare, non un vincolo rigido.*

---

## P3 — Editing tracce & UX mappa (aperti, ordine per SP crescente)

- [ ] **Linee sentieri visibili sul layer mappa** — *SP 2*. Costo quasi zero: la geometria
  dei sentieri (`sentei-trails`) è già scaricata per posizionare le etichette, manca solo una
  `LineLayer` che la disegni. *Naturale da fare insieme a **P1, punto 3**: serve comunque un
  layer selezionabile su cui fare `queryRenderedFeatures`.*
- [ ] **Separazione strade/sentieri su Mapbox** — *SP 3*. Nascondere i layer strada-sterrata
  dello stile Outdoors mostrando solo i sentieri OSM/CAI; da rivalutare quando la qualità dei
  sentieri in mappa diventa priorità (analisi delle opzioni già fatta).
- [ ] **[TASK] Studiare la grafica della mappa in ottica GaiaGPS** — *SP 3*. Valutare come
  avvicinare stile/leggibilità della mappa (colori, spessori sentieri, etichette, terreno)
  a quello di GaiaGPS, nei limiti dello stile Mapbox Outdoors in uso (§2 CLAUDE.md); capire
  cosa è personalizzabile via stile Mapbox custom vs cosa richiederebbe layer aggiuntivi.
- [ ] **Migrazione layer sentieri a OSM2CAI** — *SP 5*. Stessa idea sopra ma con `ref`/
  `osmc_symbol`/`cai_scale` da OSM2CAI invece di Overpass (più ricco, limite bbox da
  gestire con zoom minimo/fallback). *Anche questo confluisce in **P1, punto 3**, che
  richiede id e tag della relazione.*
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
