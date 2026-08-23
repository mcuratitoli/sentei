# Validazione pendente su device — Sentèi

> Elenco a parte (separato da `docs/ROADMAP.md`) per fix/feature **già implementati e
> coperti da test automatici o dal simulatore**, ma non ancora confermati a schermo su un
> **telefono fisico**. Il simulatore iOS non dice nulla su tempi reali, memoria, libreria
> foto vera, rete reale o aggiornamento da store — da qui la necessità di una lista
> separata invece di annegarla nei punti "da fare" della roadmap. Vedi `CLAUDE.md` §7/§12.
>
> Quando un punto è confermato su device, spuntarlo `[x]` con data e note (non cancellarlo:
> qui la storia della validazione è parte del valore della lista).

- [ ] **Export immagine del percorso** (23 ago 2026, `docs/CHANGELOG-DEV.md`) — verificato
  **dal vivo sul simulatore** su più tracce reali (Alpe Toso, Rima/Lanciole/Lavazei, Cima
  Mutta, Pontechianale Giacoletti) in oltre dieci giri di feedback: cattura via
  `Snapshotter`, puntatori POI, etichette trascinabili senza sovrapposizioni, orientamento
  camera sul dislivello. **Resta da verificare su device fisico**: salvataggio in galleria
  (permesso foto reale, non simulato), condivisione di sistema, tempo di risposta di
  `Snapshotter`/Overpass su rete reale (non wifi dev), col percorso più lungo della libreria
  (Giro di Viso, 37 km — tanti POI, elenco scelta lungo).
- [ ] **Migrazione cache elevazione** (23 ago 2026, `docs/CHANGELOG-DEV.md`) — il fix del
  bug "l'app pesa centinaia di mega" (cache Terrarium senza limiti) cancella al primo
  avvio la vecchia cartella in `Documents/terrarium_cache`. Da confermare **proprio sul
  telefono che ha segnalato il problema**: è l'unico con una cache vecchia abbastanza da
  migrare — verificare che lo spazio venga effettivamente liberato (Impostazioni iOS →
  Generali → Spazio [nome] iPhone → Sentèi) e che il nuovo tetto (200 MB, sezione "Cache
  elevazione" in Impostazioni → Mappe offline) regga con l'uso normale.
- [ ] **Log di debug in-app** (23 ago 2026) — `AppLogService`/`DebugLogsScreen`, sblocco 7
  tap sul footer versione: cattura e visualizzazione verificate sul simulatore, ma la
  **rotazione** (oltre 512 KB, oltre 4 file, purge a 7 giorni) non è mai stata esercitata
  per davvero — serve una sessione d'uso abbastanza lunga o log artificialmente gonfiati.
  Da controllare anche la condivisione del file su device fisico (share sheet con
  destinatari reali, non solo il simulatore).
- [ ] **Foto più veloci ad aprirsi e scorrere** (P1.1, 12 ago 2026) — provato sul
  simulatore con 14 foto generate ad hoc, di cui **6 da 48 MP** (8064×6048): la foto è a
  schermo entro ~250 ms anche saltando da una miniatura all'altra. Restano da vedere su un
  telefono vero: **HEIC** veri (decodifica diversa dal JPEG), foto ancora **solo in iCloud**
  (è lì che l'indicatore di caricamento deve comparire, ed è il caso più lento), una traccia
  con decine di foto (memoria scorrendo veloce la striscia) e lo **zoom oltre 1,6×**, non
  provabile sul simulatore perché i click sintetici non fanno pinch.
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
  fallimenti BRouter in `docs/ROADMAP.md` P7, backlog tecnico.)*
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
- [x] **Tempo di percorrenza stimato — validato su una traccia reale, due correzioni**
  (P1.2, 15 ago 2026): l'utente segnala 3h43 stimati contro i 2h15-2h20 di due fonti CAI
  (D+ quasi identico) per Rassa → Alpe Toso (VC). **Prima correzione:** velocità di salita
  300→400 m/h (era l'estremo prudente scelto inizialmente, più lento del valore standard
  della formula svizzera) → 3h43 diventa 2h48 sul caso semplificato, ma sulla traccia reale
  (D+810/D-107) restava 3h15 — ancora troppo. **Seconda correzione**, dopo aver verificato
  due esempi numerici del modello ufficiale (Schweizer Wanderwege): il correttivo
  `+ min(t_oriz,t_vert)/2` esagera quando le due componenti non sono bilanciate (il caso
  più comune — salita diretta o cammino quasi pianeggiante); cambiato in `/4`. Risultato:
  ~2h39 sulla traccia reale dell'utente, entro un margine ragionevole. Dettagli e numeri
  completi in `docs/CHANGELOG-DEV.md`. Non ancora verificato: passo Lento/Medio/Veloce con
  numeri reali, e la velocità di discesa (500 m/h, invariata) su un percorso a discesa
  dominante.
- [ ] Smoke test OSM2CAI on-device — `osm2cai.cai.it` è bloccato dalla network policy
  dell'ambiente di sviluppo, va provato su rete reale.

---

Vedi anche: [`ROADMAP.md`](./ROADMAP.md) (punti "da fare" non ancora implementati),
[`CHANGELOG-DEV.md`](./CHANGELOG-DEV.md) (dettagli tecnici di ciò che è già implementato).
