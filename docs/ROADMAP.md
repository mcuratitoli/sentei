# Roadmap — Sentèi

> Piano di lavoro operativo: **solo punti aperti**, in ordine di priorità. Il completato è
> stato spostato nel changelog tecnico — vedi i riferimenti in fondo.

**Aggiornato:** 24 luglio 2026 · **Stato:** beta `1.0.0+5` rilasciata ai tester.

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

1. [ ] **[FIX] Tema chiaro/scuro non rispettato all'apertura** — *SP 3*. Con il tema
   impostato manualmente (es. Chiaro) su un telefono col sistema in Dark Mode, all'avvio
   l'app mostra comunque Scuro: la preferenza salvata (`appThemeModeProvider`) non viene
   applicata prima del primo frame. Verificare l'ordine di caricamento
   `shared_preferences` vs. `MaterialApp`/override `platformBrightness` in `lib/app/app.dart`.
2. [ ] **[FIX] Traccia "fantasma" dopo import GPX** — *SP 5*. Nel flusso di import a 2 fasi
   (grezza tratteggiata → editing → Salva, vedi `docs/CHANGELOG-DEV.md`), la traccia grezza
   originale può restare visibile in mappa senza essere né selezionabile né eliminabile.
   Garantire che, in ogni uscita dal flusso di import (Salva **o** Annulla), la geometria
   grezza temporanea venga sempre rimossa dal rendering.
3. [ ] **[FIX] Testo del pulsante in uscita dall'editing** — *SP 1*. Il messaggio di
   conferma dice "Annulla percorso": va cambiato in **"Annulla modifiche"**, corretto anche
   quando si sta modificando una traccia esistente e non solo disegnandone una nuova.
4. [ ] **[FIX] Interazione poco intuitiva per annullare la ricerca luogo** — *SP 2*. Nel
   pannello di ricerca l'unico modo per uscire è il chevron verso sinistra, poco leggibile
   come "annulla ricerca". Valutare una X esplicita o un gesto più standard (tap fuori dal
   pannello).
5. [ ] **[FEATURE] Focus mappa sull'area importata** — *SP 2*. Dopo l'import di un GPX la
   mappa deve inquadrare automaticamente (camera fit-bounds) l'area del tracciato
   importato, invece di restare sull'inquadratura precedente.
6. [ ] **[FEATURE] Tasto elimina nella card traccia selezionata** — *SP 2*. Oggi
   l'eliminazione è raggiungibile solo dalla lista tracciati (menu azioni riga); aggiungere
   un tasto elimina (con conferma, coerente con `showIosConfirm`) direttamente nella card
   che appare selezionando una traccia sulla mappa.
7. [ ] **[FEATURE] Evidenziazione della traccia selezionata** — *SP 3*. Quando una traccia
   è selezionata la sua linea deve risaltare (più spessa/satura), mentre le altre tracce
   visibili in mappa passano a un'opacità ridotta — leggibilità in aree con più tracce
   sovrapposte.
8. [ ] **[FIX] Editing punti intermedi — ripensare l'interazione** — *SP 8*. Il punto
   draggabile a metà segmento (vedi `docs/CHANGELOG-DEV.md`, 23 luglio) è poco discoverable
   (serve tenere premuto qualche secondo) e posizionato in modo poco sensato (centro della
   corda retta, non del sentiero). **Da implementare al posto dell'attuale:** rimuovere la
   maniglia intermedia sempre visibile; al tap su un punto esistente la card cambia
   contesto — sparisce nome/colore traccia, compaiono i dati del punto (altitudine, ecc.),
   un suggerimento "tieni premuto per spostare", il tasto elimina punto e un nuovo tasto
   **"aggiungi punto prima"** che inserisce un waypoint a metà tra il punto selezionato e
   il precedente. Tocca `route_editor_provider.dart` + rendering/gesture in
   `map_gl_screen.dart` (rivedere anche `docs/eval-waypoint-editing.md`).
9. [ ] **[FEATURE] Selettore colore traccia espandibile** — *SP 3*. Nell'editing traccia la
   scelta colore deve essere collassata di default e espandersi al tocco; ampliare la
   palette con più tonalità, coerenti con la palette blu dell'app (`lib/ui/tokens.dart`).
10. [ ] **[FEATURE] Coerenza tasto ripidità ↔ tasto immagini** — *SP 2*. Nella card di
    editing, il toggle on/off della banda ripidità/pendenza e il toggle on/off delle
    immagini devono avere lo stesso linguaggio visivo (stessa forma, stesso stato
    attivo/disattivo) — oggi incoerenti.
11. [ ] **[FEATURE] Epica "Foto lungo il percorso" — completare l'esperienza immagini** —
    *SP 13* (da spezzare in sotto-task in fase di implementazione; l'analisi architetturale
    è già fatta in `docs/eval-photo-sync.md`, qui vanno rifinite/aggiunte le parti UI).
    Sotto-richieste raccolte dal test:
    - il tasto immagini nella card deve permettere di **importare nuove foto**, oltre a
      mostrare/nascondere le anteprime esistenti;
    - scorrendo il profilo/tracciato, il punto con una foto associata deve **evidenziarsi**
      (es. bordo giallo) quando il dito lo attraversa;
    - toccando un punto giallo (con foto) oggi si mostra l'anteprima; **toccando
      l'anteprima** ci si aspetta la foto a **schermo intero**;
    - le foto devono poter avere un **titolo** impostabile dall'utente (default: data e ora
      dello scatto);
    - un **tasto info** deve mostrare i metadati della foto: coordinate (ed eventualmente
      altitudine) del luogo di scatto, data/ora, titolo;
    - serve una **vista a griglia** con tutte le foto della traccia, con selezione multipla
      e azioni bulk (es. eliminazione massiva);
    - toccando un'anteprima (dalla griglia o dal punto in mappa) ci si aspetta lo
      **zoom/focus della mappa** sul punto di scatto **e** l'apertura delle info foto;
    - fix minore incluso: il testo "Trovate X immagini" (import foto) risulta ancora
      sottolineato in giallo (probabile residuo di sottolineatura di debug, stesso bug già
      risolto altrove con `DefaultTextStyle(decoration:none)`).
12. [ ] **[TASK] Passata di pulizia del codice** — *SP 1*. A fine implementazione dei punti
    sopra, eseguire una verifica di pulizia/coerenza (skill `simplify`) sulle modifiche.

*Totale indicativo: ~45 story point — riferimento per pianificare, non un vincolo rigido.*

---

## P2 — Editing tracce & UX mappa (aperti)

- [~] **Sync foto lungo il percorso** — analisi e decisione architetturale fatte
  (`docs/eval-photo-sync.md`), implementazione UI in corso su branch dedicato: vedi i
  requisiti dettagliati in **P1, punto 11**.
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

## P3 — Validazione pendente su device

Implementato in codice e coperto da test automatici, ma non ancora confermato a schermo
su un telefono fisico:

- [ ] Import GPX riallineato (flusso a 2 fasi: caricamento annullabile → editing →
  Salva) — comportamento atteso descritto in `docs/CHANGELOG-DEV.md`.
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

- [ ] **APK `--split-per-abi`** → ~40-50 MB invece di 122 MB.
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
- [ ] **Login autenticato (Google e/o Apple)** per identificare gli utenti — decisione
  architetturale ancora aperta: introdurrebbe un'identità server-side che oggi l'app non
  ha (privacy-first, zero backend). Da discutere prima di progettare l'implementazione.
- [ ] **Analitiche d'uso** (dopo login e/o decisione backend) — tool da scegliere
  (Firebase vs soluzione self-hosted/privacy-friendly) e revisione della privacy policy
  (oggi dichiara "nessuna raccolta dati su server propri").

## P7 — Backlog tecnico (bassa priorità)

- [ ] Densificazione del path: passo fisso 15 m di default — valutare passo adattivo alla
  pendenza.
- [ ] Precisione D+/D-: campionamento DEM Terrarium a z13 di default — verificare contro
  z14/15 sulle Alpi.
- [ ] Modello di sync cloud: oggi solo file + last-write-wins — valutare un indice o una
  gestione dei conflitti più fine se servisse.
- [ ] Routing offline (BRouter embedded, Fase 2 del CLAUDE.md) — confermare la fattibilità
  reale in Flutter (dimensione dei segment file) prima di impegnarsi.
- [ ] Unità di misura / localizzazione: oggi solo metrico e italiano — valutare se serve
  i18n.

---

## Riferimenti

- **[`docs/CHANGELOG-DEV.md`](./CHANGELOG-DEV.md)** — changelog tecnico esteso: tutto ciò
  che è stato completato, con dettagli implementativi, bug e decisioni.
- **[`CHANGELOG.md`](../CHANGELOG.md)** — changelog sintetico per chi usa l'app (anche
  in-app, Impostazioni → Informazioni → Sentèi).
- **[`CLAUDE.md`](../CLAUDE.md)** — visione di prodotto, decisioni architetturali fisse,
  stack tecnico, comandi.
