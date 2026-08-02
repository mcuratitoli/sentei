# Roadmap — Sentèi

> Piano di lavoro operativo: **solo punti aperti**, in ordine di priorità. Il completato è
> stato spostato nel changelog tecnico — vedi i riferimenti in fondo.

**Aggiornato:** 2 agosto 2026 · **Stato:** beta `1.0.0+8` (29 luglio 2026) in rilascio ai
tester.

## Come leggere questo documento

- Le sezioni sono numerate **P1 → P7** in ordine di priorità (P1 = da affrontare per primo).
- Ogni punto è etichettato **[FIX]** (comportamento rotto/incoerente di una feature già
  rilasciata), **[FEATURE]** (funzionalità nuova) o **[TASK]** (lavoro tecnico, non visibile
  all'utente).
- **SP** = story point, peso di complessità in scala Fibonacci 1-2-3-5-8-13: 1-2 banale
  (minuti), 3 qualche ora, 5 mezza giornata, 8 giornata piena su più file, 13 epica da
  spezzare in sotto-task prima di iniziare.
- `[ ]` = da fare, `[~]` = iniziato/parziale.

---

## P1 — Feedback test su device (24 luglio 2026) — priorità massima

> Osservazioni raccolte testando la beta `1.0.0+4` direttamente sul telefono. Precedono
> tutto il resto della roadmap.

1. [ ] **[FIX] Interazione poco intuitiva per annullare la ricerca luogo** — *SP 2*. Nel
   pannello di ricerca l'unico modo per uscire è il chevron verso sinistra, poco leggibile
   come "annulla ricerca". Valutare una X esplicita o un gesto più standard (tap fuori dal
   pannello).
2. [x] **[FEATURE] Focus mappa sull'area importata** — *SP 2*. Dopo l'import di un GPX la
   mappa inquadra automaticamente l'area del tracciato importato. **Fatto** (29 luglio 2026,
   confluito in `1.0.0+8`, vedi `docs/CHANGELOG-DEV.md`): due bug sovrapposti (id sempre
   `null` in fase 1, `flyTo` perso durante la transizione della schermata lista→mappa).
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
      e azioni bulk (es. eliminazione massiva);
    - toccando un'anteprima (dalla griglia o dal punto in mappa) ci si aspetta anche lo
      **zoom/focus della mappa** sul punto di scatto (oggi si apre solo la card di dettaglio,
      la mappa non si sposta);
    - fix minore: il testo "Trovate X immagini" (import foto) risulta ancora sottolineato
      in giallo (probabile residuo di sottolineatura di debug, stesso bug già risolto
      altrove con `DefaultTextStyle(decoration:none)`).
6. [ ] **[TASK] Passata di pulizia del codice** — *SP 1*. A fine implementazione dei punti
    sopra, eseguire una verifica di pulizia/coerenza (skill `simplify`) sulle modifiche.

*Totale indicativo: ~20 story point — riferimento per pianificare, non un vincolo rigido.*

---

## P2 — Editing tracce & UX mappa (aperti)

- [~] **Sync foto lungo il percorso** — analisi e decisione architetturale fatte
  (`docs/eval-photo-sync.md`), implementazione UI in corso su branch dedicato: vedi i
  requisiti dettagliati in **P1, punto 6**.
- [ ] **Versione Web** (browser desktop) — PoC necessario: `mapbox_maps_flutter` non gira
  su Flutter Web (richiede Mapbox GL JS o `flutter_map`/MapLibre dietro l'astrazione mappa
  già engine-agnostica); da verificare anche `drift` (WASM), `path_provider` (non
  disponibile su web), sync cloud lato browser. Prima decisione da prendere: MVP
  sola-visualizzazione vs editing completo.
- [ ] **Linee sentieri visibili sul layer mappa** — costo quasi zero: la geometria dei
  sentieri (`sentei-trails`) è già scaricata per posizionare le etichette, manca solo una
  `LineLayer` che la disegni.
- [ ] **Migrazione layer sentieri a OSM2CAI** — stessa idea sopra ma con `ref`/
  `osmc_symbol`/`cai_scale` da OSM2CAI invece di Overpass (più ricco, limite bbox da
  gestire con zoom minimo/fallback).
- [ ] **Separazione strade/sentieri su Mapbox** — nascondere i layer strada-sterrata dello
  stile Outdoors mostrando solo i sentieri OSM/CAI; da rivalutare quando la qualità dei
  sentieri in mappa diventa priorità (analisi delle opzioni già fatta).
- [ ] **[TASK] Studiare un'opzione per esplorare i segnavia** — valutare come permettere
  all'utente di esplorare/consultare i segnavia (numeri sentiero CAI) direttamente in app,
  eventualmente appoggiandosi ai siti CAI (es. schede sentiero, sezioni locali) oltre ai
  dati già usati per numeri/difficoltà (`data/trails/`, OSM2CAI/Overpass, §4 CLAUDE.md).
  Da chiarire: solo link esterno alla scheda CAI del sentiero selezionato, o integrazione
  più profonda (es. ricerca per numero segnavia)?
- [ ] **[TASK] Analizzare la grafica della mappa in ottica GaiaGPS** — studiare come
  avvicinare stile/leggibilità della mappa (colori, spessori sentieri, etichette, terreno)
  a quello di GaiaGPS, nei limiti dello stile Mapbox Outdoors in uso (§2 CLAUDE.md);
  capire cosa è personalizzabile via stile Mapbox custom vs cosa richiederebbe layer
  aggiuntivi.

## P3 — Validazione pendente su device

Implementato in codice e coperto da test automatici, ma non ancora confermato a schermo
su un telefono fisico:

- [ ] **"Trova foto vicine" su una libreria reale e grande** — è il bug che ha originato
  tutto il lavoro sulle foto (1.0.0+7): `photoLocations()` scandiva solo le 3000 foto più
  recenti dell'intera libreria, quindi con più di 3000 scatti *dopo* l'escursione quelle
  del percorso restavano fuori dalla finestra e non ne trovava mai nessuna. Ora scandisce
  tutta la libreria a blocchi di 500. **Non verificabile sul simulatore** (serve una
  libreria vera, con GPS negli EXIF): provare al rilascio sul dispositivo reale, con un
  rullino da più di 3000 foto e una traccia vecchia.
- [ ] Import GPX riallineato (flusso a 2 fasi: caricamento annullabile → editing →
  Salva) — comportamento atteso descritto in `docs/CHANGELOG-DEV.md`. *(Selettore file su
  iOS, focus mappa e nome della traccia corretti e provati sul simulatore in 1.0.0+8;
  resta da validare il **riallineamento** vero su tracce reali — vedi anche la nota sui
  fallimenti BRouter in P7.)*
- [ ] Card **Novità** al primo avvio dopo un aggiornamento — provata sul simulatore
  forzando la build precedente nelle preferenze; da vedere in un aggiornamento vero
  (TestFlight/Play), dove il salto di versione arriva dallo store e non da un `flutter run`.
- [ ] Dark mode, le 3 varianti (Standard/Notturno/Risparmio energetico) su schermate
  reali — leggibilità testo/vetro/hairline; **Automatico** deve seguire il cambio di Dark
  Mode di sistema mentre l'app è aperta.
- [ ] Mappa scura automatica — coerenza col tema, leggibilità label sentieri CAI e
  attribuzione "i" su un'area con sentieri/rilievo reali (non solo zona urbana).
- [ ] Legende aggiornate (difficoltà T/E/EE/EEA + F/PD + Welzenbach, Abbreviazioni).
- [ ] Download mappe + elevazione offline in modalità aereo.
- [ ] Smoothing dislivello (deadband) su tracce reali — validare la soglia di default.
- [ ] Difficoltà CAI su tracce reali.
- [ ] Smoke test OSM2CAI on-device — `osm2cai.cai.it` è bloccato dalla network policy
  dell'ambiente di sviluppo, va provato su rete reale.

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

---

## Riferimenti

- **[`docs/CHANGELOG-DEV.md`](./CHANGELOG-DEV.md)** — changelog tecnico esteso: tutto ciò
  che è stato completato, con dettagli implementativi, bug e decisioni.
- **[`CHANGELOG.md`](../CHANGELOG.md)** — changelog sintetico per chi usa l'app (anche
  in-app, Impostazioni → Informazioni → Sentèi).
- **[`CLAUDE.md`](../CLAUDE.md)** — visione di prodotto, decisioni architetturali fisse,
  stack tecnico, comandi.
