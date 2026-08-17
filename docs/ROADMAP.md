# Roadmap — Sentèi

> Piano di lavoro operativo: **solo punti aperti**, in ordine di priorità. Il completato è
> stato spostato nel changelog tecnico — vedi i riferimenti in fondo.

**Aggiornato:** 17 agosto 2026 · **Stato:** beta `1.0.0+8` distribuita ai tester, con
modifiche già su `main` non ancora rilasciate (vedi `CHANGELOG.md`, sezione "Non ancora
rilasciato").

## Come leggere questo documento

- Le sezioni sono numerate **P1 → P8** in ordine di priorità (P1 = da affrontare per primo).
- Ogni punto è etichettato **[FIX]** (comportamento rotto/incoerente di una feature già
  rilasciata), **[FEATURE]** (funzionalità nuova) o **[TASK]** (lavoro tecnico, non visibile
  all'utente).
- **SP** = story point, peso di complessità in scala Fibonacci 1-2-3-5-8-13: 1-2 banale
  (minuti), 3 qualche ora, 5 mezza giornata, 8 giornata piena su più file, 13 epica da
  spezzare in sotto-task prima di iniziare.
- `[ ]` = da fare, `[~]` = iniziato/parziale.

---

## P1 — Priorità massima (12 agosto 2026)

> Tre temi decisi come **prime cose da fare**, prima di riprendere il feedback di test in P2:
> la fluidità delle foto, la stima del tempo di percorrenza e la comprensione dei segnavia
> sulla mappa. I primi due sono lavori chiusi e stimabili, il terzo è un'epica da spezzare.

### 1. [FIX] Immagini: dimensione e fluidità di caricamento/scroll — ✅ fatto (12 ago 2026)

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

### 2. [FEATURE] Tempo di percorrenza stimato (metodo CAI) — ✅ fatto (15 ago 2026)

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

### 3. [FEATURE] Capire un segnavia dalla mappa: percorso intero + scheda CAI — *SP 13 (epica)*

Caso d'uso: vedo un rifugio, tocco intorno, trovo un sentiero con un numero — voglio sapere
**dove quel segnavia parte e dove arriva**, vederlo tutto sulla mappa e aprire la scheda
ufficiale. Oggi non è possibile: il tap sulla mappa (`map_gl_screen.dart:674`) produce solo
l'*info punto* (quota/coordinate/località) e non interroga il layer sentieri; e soprattutto
i modelli in `data/trails/` conservano **solo `ref` + geometria ritagliata al bounding box**
(`TrailRelation`, `TrailRefLine`) — niente id di relazione, niente `name`/`from`/`to`, e la
geometria finisce dove finisce lo schermo. Va spezzata così:

- [ ] **Portarsi dietro l'identità della relazione** — id OSM/OSM2CAI e tag `name`, `from`,
  `to`, `network`, `osmc:symbol` in `TrailRelation`/`TrailRefLine` e nel source GeoJSON
  `sentei-trails`. È il prerequisito di tutto il resto.
- [ ] **Tap → quale segnavia** — `queryRenderedFeatures` sul layer sentieri con una
  tolleranza in pixel; se sotto il dito ci sono più segnavia sovrapposti, farli scegliere.
- [ ] **Fetch della relazione completa** (non ritagliata): OSM2CAI espone
  `GET /api/v2/hiking-route/{id}` in GeoJSON e `GET /api/v2/hiking-routes/{id}.gpx`
  (vedi `docs/osm2cai-investigation.md`); fuori Italia, Overpass con `rel(<id>); out geom;`.
- [ ] **Mostrarlo** — l'intera relazione evidenziata sulla mappa + fit-bounds, e una card
  con numero, nome, partenza → arrivo, lunghezza, D+/D-, difficoltà CAI e **tempo stimato**
  (riusa il punto 2 di questa sezione).
- [ ] **Link alla scheda ufficiale** — *da verificare prima di implementare*: dell'endpoint
  API OSM2CAI sappiamo la forma, della **pagina web** pubblica corrispondente no. Verificare
  se esiste un permalink per id su `osm2cai.cai.it` (e cosa fare fuori Italia: fallback alla
  relazione su `openstreetmap.org`); non inventare un URL.
- [ ] **Da tenere separato** (non in questa epica, ma è l'estensione naturale): "usa questo
  segnavia come traccia" — import diretto del GPX della relazione nell'editor.

*Totale indicativo: ~23 story point, di cui 10 già fatti (punti 1 e 2) — il punto 3 va
rivisto una volta spezzato.*

---

## P2 — Feedback test su device (24 luglio 2026)

> Osservazioni raccolte testando la beta `1.0.0+4` direttamente sul telefono. Restano il
> primo lavoro dopo P1.

1. [ ] **[FIX] Interazione poco intuitiva per annullare la ricerca luogo** — *SP 2*. Nel
   pannello di ricerca l'unico modo per uscire è il chevron verso sinistra, poco leggibile
   come "annulla ricerca". Valutare una X esplicita o un gesto più standard (tap fuori dal
   pannello).
2. [ ] **[FEATURE] Focus mappa sull'area importata** — *SP 2*. Dopo l'import di un GPX la
   mappa deve inquadrare automaticamente (camera fit-bounds) l'area del tracciato
   importato, invece di restare sull'inquadratura precedente.
3. [ ] **[FEATURE] Tasto elimina nella card traccia selezionata** — *SP 2*. Oggi
   l'eliminazione è raggiungibile solo dalla lista tracciati (menu azioni riga); aggiungere
   un tasto elimina (con conferma, coerente con `showIosConfirm`) direttamente nella card
   che appare selezionando una traccia sulla mappa.
4. [ ] **[FEATURE] Evidenziazione della traccia selezionata** — *SP 3*. Quando una traccia
   è selezionata la sua linea deve risaltare (più spessa/satura), mentre le altre tracce
   visibili in mappa passano a un'opacità ridotta — leggibilità in aree con più tracce
   sovrapposte.
5. [ ] **[FEATURE] Epica "Foto lungo il percorso" — completare l'esperienza immagini** —
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
6. [ ] **[TASK] Passata di pulizia del codice** — *SP 1*. A fine implementazione dei punti
    sopra, eseguire una verifica di pulizia/coerenza (skill `simplify`) sulle modifiche.

*Totale indicativo: ~20 story point — riferimento per pianificare, non un vincolo rigido.*

---

## P3 — Editing tracce & UX mappa (aperti)

- [~] **Sync foto lungo il percorso** — analisi e decisione architetturale fatte
  (`docs/eval-photo-sync.md`), implementazione UI in corso su branch dedicato: vedi i
  requisiti dettagliati in **P2, punto 5**.
- [ ] **Versione Web** (browser desktop) — PoC necessario: `mapbox_maps_flutter` non gira
  su Flutter Web (richiede Mapbox GL JS o `flutter_map`/MapLibre dietro l'astrazione mappa
  già engine-agnostica); da verificare anche `drift` (WASM), `path_provider` (non
  disponibile su web), sync cloud lato browser. Prima decisione da prendere: MVP
  sola-visualizzazione vs editing completo.
- [ ] **Linee sentieri visibili sul layer mappa** — costo quasi zero: la geometria dei
  sentieri (`sentei-trails`) è già scaricata per posizionare le etichette, manca solo una
  `LineLayer` che la disegni. *Naturale da fare insieme a **P1, punto 3**: serve comunque un
  layer selezionabile su cui fare `queryRenderedFeatures`.*
- [ ] **Migrazione layer sentieri a OSM2CAI** — stessa idea sopra ma con `ref`/
  `osmc_symbol`/`cai_scale` da OSM2CAI invece di Overpass (più ricco, limite bbox da
  gestire con zoom minimo/fallback). *Anche questo confluisce in **P1, punto 3**, che
  richiede id e tag della relazione.*
- [ ] **Separazione strade/sentieri su Mapbox** — nascondere i layer strada-sterrata dello
  stile Outdoors mostrando solo i sentieri OSM/CAI; da rivalutare quando la qualità dei
  sentieri in mappa diventa priorità (analisi delle opzioni già fatta).
- [ ] **[TASK] Studiare la grafica della mappa in ottica GaiaGPS** — valutare come
  avvicinare stile/leggibilità della mappa (colori, spessori sentieri, etichette, terreno)
  a quello di GaiaGPS, nei limiti dello stile Mapbox Outdoors in uso (§2 CLAUDE.md); capire
  cosa è personalizzabile via stile Mapbox custom vs cosa richiederebbe layer aggiuntivi.

## P4 — Build & toolchain

- [ ] **Dimensione dell'APK: `--split-per-abi`** → ~40-50 MB per architettura invece di un
  unico APK universale. Misure reali su 1.0.0+8 (29 lug 2026): **APK 124 MB**, contro
  **42 MB dell'IPA** della stessa versione — il grosso è il codice nativo compilato per
  tutte le ABI insieme (arm64-v8a, armeabi-v7a, x86_64), che l'IPA non porta. In crescita:
  erano ~122 MB alla misura precedente.
  - È solo un flag di build, nessuna modifica al codice:
    `flutter build apk --release --split-per-abi` produce un file per architettura
    (agli amici si dà quello **arm64-v8a**, che copre tutti i telefoni recenti).
  - Priorità legata al canale di distribuzione: **irrilevante su Play Store** (lo store
    serve già solo l'ABI del dispositivo, e con `--release` si userebbe comunque un
    App Bundle), **rilevante subito** se si continua a passare l'APK a mano — vedi la
    strategia in P6.
- [ ] **Aggiornamento Flutter** (`flutter upgrade` + `pub upgrade --major-versions`) —
  sessione dedicata dopo la beta, rischio regressioni mapbox/drift/riverpod.
- [ ] **CI base** (GitHub Actions: `flutter analyze` + `flutter test`) — non ancora
  configurata.

## P5 — Rimandati

- [ ] Bundling font offline (ora scaricati a runtime via `google_fonts`... nota: su iOS si
  usa già il font di sistema, verificare se il bundling serve ancora su Android).
- [ ] Registrazione traccia live (background location, Fase 2 del CLAUDE.md).

## P6 — Distribuzione & accesso

**Decisione presa (22 luglio 2026):** iOS **Unlisted App Distribution** + Android **Play
closed testing** con Google Group — niente codice di sblocco, niente vetrina pubblica.
Motivazione e analisi completa in `docs/CHANGELOG-DEV.md`.

- [ ] iOS: submit review della build corrente + richiesta Unlisted.
- [ ] Android: creare Play Console, generare upload keystore, build `.aab` (non più APK),
  track closed testing + Google Group come lista tester.
- [ ] Documentare i due flussi in `docs/` (es. `docs/distribuzione-unlisted.md`).
- [ ] **Analitiche d'uso** — analisi completa fatta e aggiornata (24 luglio 2026,
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
- [x] **Login autenticato (Google/Apple):** escluso — l'utente ha deciso di restarne fuori
  per non "slegarsi da problematiche" non necessarie; nessuna delle analitiche sopra lo
  richiede. Vedi `docs/eval-usage-analytics.md` §6. Riaprire solo per un motivo diverso
  dalle analitiche (continuità multi-dispositivo, supporto utenti).

## P7 — Backlog tecnico (bassa priorità)

- [ ] **Affidabilità del BRouter pubblico**: durante l'import di una traccia alpina reale
  (29 lug 2026) il server ha rifiutato molti segmenti con `HTTP 400: operation killed by
  thread-priority-watchdog`, su **entrambi** i profili della catena (`hiking-mountain` e
  `trekking`), degradando parecchi tratti a linea retta. Il fallback funziona come
  progettato, ma la resa sulla singola traccia ne risente: se il fenomeno si ripete,
  riconsiderare le alternative con API key già valutate (GraphHopper/Valhalla/ORS, vedi
  `CLAUDE.md` §6.2) o un retry più paziente.
- [ ] Densificazione del path: passo fisso 15 m di default — valutare passo adattivo alla
  pendenza.
- [ ] Precisione D+/D-: campionamento DEM Terrarium a z13 di default — verificare contro
  z14/15 sulle Alpi.
- [ ] Modello di sync cloud: oggi solo file + last-write-wins — valutare un indice o una
  gestione dei conflitti più fine se servisse.
- [ ] Routing offline (BRouter embedded, Fase 2 del CLAUDE.md) — confermare la fattibilità
  reale in Flutter (dimensione dei segment file) prima di impegnarsi.
- [ ] Unità di misura: oggi solo metrico — valutare se serve un'opzione imperiale.
- [ ] **Multilingua (i18n)**: oggi l'app è solo in italiano — aggiungere il supporto per
  l'inglese (`flutter_localizations` + `intl`, estrazione delle stringhe UI in ARB),
  partendo dalle schermate principali (mappa, disegno traccia, lista tracciati,
  impostazioni). Decisione aperta collegata in `CLAUDE.md` §10.

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
