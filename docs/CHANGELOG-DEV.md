# Changelog tecnico — Sentèi

Cronologia dettagliata di sviluppo: cosa è stato implementato, perché, con quali file
coinvolti e quali bug/cause-radice sono stati risolti lungo il percorso. Organizzato per
**data**, ordine cronologico inverso (più recente in cima).

- Per le **novità in linguaggio utente** (cosa cambia per chi usa l'app) vedi
  [`CHANGELOG.md`](../CHANGELOG.md) alla radice del repo — la stessa lista è mostrata
  in-app in Impostazioni → Informazioni → Novità e roadmap.
- Per **cosa resta da fare**, in ordine di priorità, vedi [`ROADMAP.md`](./ROADMAP.md).

---

## 30 agosto 2026 — P1.C1: tempi di percorrenza, rimosso lo split automatico anello

Prima metà di P1.C (§`docs/ROADMAP.md`).

- `HikingTimeCalculator.estimateForTrack` **rimosso**, con `_splitAtPeak`, `_Legs`,
  `HikingTimeEstimate` (campi `ascent`/`descent`/`isSplit`) e la soglia
  `closedLoopThresholdMeters`. Lo split "salita/discesa" per i percorsi chiusi era stato
  aggiunto il 15 ago **su richiesta esplicita**; ora l'utente sceglierà l'intervallo a mano
  (C2), niente più euristica sul punto di quota massima. Non c'entra con la sovrastima
  segnalata in `docs/validazione-device.md` (storico P1.2): quella dipende dai coefficienti.
- La formula CAI/SAC (`estimate`, correttivo `min/4`) è **invariata**.
- Nuovo `estimateRange(profile, {startIndex = 0, endIndex, pace})` → `HikingRangeEstimate`
  (tempo + distanza + D+/D- della sotto-tratta). Coi default = intero percorso, identico a
  prima. D+/D- ricalcolati **sulla sola sotto-tratta** con lo stesso deadband
  (`ElevationCalculator`, 8 m) delle metriche di traccia. Indici in qualsiasi ordine e
  clampati; intervallo degenere → `HikingRangeEstimate.zero`. È la base per C2.
- Callers passati a `estimate(...)` diretto (ritorna `Duration`): `draw_route_controls.dart`
  (`_HikingTimeRow` ora prende un `Duration`, via le frecce ↗/↘ e il ramo split),
  `tracks_list_screen.dart`, `export/export_image_screen.dart` (`hikingTime` ora `Duration?`).
- Test `test/domain/hiking_time_test.dart`: rimosso il gruppo `estimateForTrack`, aggiunto
  `estimateRange` (default = totale, solo-salita, solo-discesa, tratta centrale, indici
  invertiti/coincidenti/fuori-range, profilo < 2 campioni, passo). **254 test verdi**,
  `flutter analyze` pulito.
- **Nota di sessione**: il pulsante "copia coordinate" dell'HUD (P1.A) era stato commentato
  su disco lasciando la card non compilabile (un `)` orfano) — ripristinato alla versione
  approvata, con in più `HitTestBehavior.opaque` sul target da 32 px.

## 28 agosto 2026 — P1.A: indicatore di quota e coordinate correnti (HUD)

Prima fetta di P1 (§`docs/ROADMAP.md`). HUD sempre visibile nell'angolo in alto a sinistra
della mappa; collassato mostra solo la quota, toccandolo si espande.

- **Dato** — `LocationService.fixStream()`: nuovo stream che oltre a lat/lon porta
  accuratezza orizzontale, quota e accuratezza verticale (`GpsFix`). Lo stream "semplice"
  (`positionStream`, solo `LatLng`) resta per il centraggio mappa, che di quei metadati non
  ha bisogno. Provider `gpsFixProvider` (`features/map/map_providers.dart`): **si aggancia a
  `userLocationProvider`** invece di chiedere lui i permessi, così il prompt di sistema esce
  una volta sola (lo attiva già `_locateSilently` all'apertura mappa).
- **Quota** — mostrata solo se `GpsFix.hasReliableAltitude`: accuratezza verticale nota e
  **≤ 25 m** (soglia decisa con l'utente). Altrimenti un trattino, e da espanso una riga lo
  spiega. **Nessun ripiego sul DEM Terrarium**: qui interessa la quota reale dell'utente,
  non quella del terreno sotto di lui — diversa scelta rispetto alla card "punto
  ispezionato", che il DEM lo usa. Sul **simulatore iOS** la quota è sempre a trattino
  (nessuna accuratezza verticale realistica) → da validare su device (P8).
- **UI** — `_PositionHud` in `map_gl_screen.dart`. Collassato: icona terreno + quota +
  chevron. Espanso: accuratezza orizzontale, coordinate in gradi decimali su una riga
  (`FittedBox` scaleDown come rete di sicurezza) con copia negli appunti + toast. Stessa
  `GlassSurface` (opacità/blur di default della palette) di menubar e bottoni a destra —
  niente override, su richiesta dell'utente.
- **Ornamenti Mapbox riposizionati** per liberare l'angolo in alto a sinistra:
  - scale bar nativa → `TOP_LEFT`, sopra la card (che parte a `top: 30` apposta);
  - logo Mapbox → `BOTTOM_LEFT`, `marginBottom: 0` (il più in basso possibile; dimensione
    fissata dall'SDK, non riducibile);
  - icona "i" → `BOTTOM_LEFT`, subito sopra il logo.
  `OrnamentPosition` espone solo i 4 angoli (niente `BOTTOM_CENTER`): una scale bar davvero
  centrata sotto il menu richiederebbe un widget custom — non fatta, in attesa di decisione.
- `flutter analyze` pulito, 249 test verdi (nessun test di widget sull'HUD).

**Resta da fare in P1.A**: nascondere l'HUD quando una bottom sheet lo copre e durante lo
snapshot dell'export immagine; validazione su device.

## 28 agosto 2026 — Roadmap: «P1» riassegnato a tre nuovi lavori; mappatura sigle storiche

`docs/ROADMAP.md` §P1 conteneva tre lavori **tutti completati** (erano rimasti "per
riferimento fino al prossimo giro di pulizia"). Il giro di pulizia è questo: l'intestazione
P1 ora ospita tre nuovi lavori a massima priorità, decisi con l'utente. Le sigle storiche
`P1.1`/`P1.2`/`P1.3` — citate in questo file e in `docs/validazione-device.md` — restano
valide e si riferiscono a:

- **P1.1** — Immagini: dimensione e fluidità di caricamento/scroll. Deciso 12 ago 2026,
  chiuso 12 ago. Dettaglio: voce **12 agosto 2026** più sotto ("Causa-radice della
  lentezza…"). Utente: build `1.0.0+6`/`+9`.
- **P1.2** — Tempo di percorrenza stimato (metodo CAI/SAC). Deciso 12 ago, chiuso 15 ago
  (correttivo `min/4` tarato lo stesso giorno). Dettaglio: voce **15 agosto 2026**. Utente:
  build `1.0.0+9`.
- **P1.3** — Epica "capire un segnavia dalla mappa: percorso intero + scheda CAI".
  Chiusa 24 ago in 4 fette + estensione 3b, con resilienza di rete 25-26 ago. Dettaglio:
  voci **24 agosto 2026** (fette 1→4) e seguenti. Utente: build `1.0.0+10`.

I tre nuovi lavori P1 (solo pianificati al 28 ago, nessun codice ancora):

- **A** — indicatore di quota e coordinate correnti sempre visibile sulla mappa (HUD
  posizione GPS, quota con fallback DEM Terrarium). *SP 3.*
- **B** — difficoltà CAI resa sullo **stile della linea** del tracciato (piena=T,
  tratteggio largo=E, stretto=EE, punteggiato=EEA; colore invariato; convenzione Sentèi
  ispirata a SAC/Tabacco, non uno standard CAI). *SP 8.*
- **C** — tempi di percorrenza per un **intervallo scelto**: si **rimuove** lo split
  automatico salita/discesa sui percorsi chiusi (`HikingTimeCalculator.estimateForTrack` →
  `estimateRange`, campi `ascent`/`descent` e frecce ↗/↘ eliminati), default = una sola
  stima start→end, più una modalità manuale start→punto / punto→punto / punto→fine sul
  profilo altimetrico. La formula CAI/SAC resta invariata. *SP 5.* **Nota:** lo split era
  stato aggiunto il 15 ago su richiesta esplicita — la rimozione è deliberata, non una
  regressione.

## 26 agosto 2026 — Chiusura sessione: fix testo non centrato, bug aperti loggati per dopo

Ultimo giro della maratona di test su "Un segnavia per intero", prima di preparare il
rilascio. Due segnalazioni dell'utente, entrambe **annotate ma non approfondite ora** su
richiesta esplicita ("per ora lascia così e non approfondire") — vedi `docs/ROADMAP.md` per
i due nuovi punti aperti:

1. **Alcuni segnavia verificati manualmente sul sito CAI Varallo non vengono trovati
   dall'app** (esempio concreto: 251C). Investigazione lampo (non una fix) per capire cosa
   scrivere nel bug report: un `curl` diretto verso l'elenco, la stessa notte, ha restituito
   **due volte di fila** una pagina `HTTP 200` con la struttura intatta (stesso "Ordina per",
   stesso footer "Vai alle pagine >>") ma **zero righe** nel mezzo — a fronte di richieste
   dell'app riuscite poco prima con centinaia di voci (251, 253, 215, 215C tutte trovate).
   Il sito sembra quindi **intermittente**, nella stessa categoria di affidabilità di
   Overpass, più che un bug di parsing sicuro dal nostro lato — ma non escluso al 100%.
   Aggiunto log diagnostico permanente in `CaiVaralloSearchService.findByRef`
   (`cai_varallo_search_service.dart`): distingue "pagina arrivata ma vuota" (probabile
   intermittenza) da "pagina con voci ma nessun match esatto" (più probabile un problema di
   formato/match nostro) — nei log di stanotte non si riusciva a distinguere i due casi, solo
   un `null` secco.
2. **La ricerca su OpenStreetMap (Overpass) falliva spesso durante i test di stanotte**,
   poi migliorata dai fix di stasera (mirror ridotto, staffetta con avanzamento rapido,
   interruttore dopo un fallimento totale — vedi le voci precedenti in questo changelog).
   L'utente conferma un miglioramento ma non si fida ancora al 100% ("anche se ora sembra
   migliorato") — lasciato come punto aperto da ricontrollare in una sessione futura con più
   tempo a disposizione, non chiuso definitivamente stanotte.

Fix minore nel frattempo: il testo esplicativo sotto lo spinner di caricamento non appariva
centrato sulla card — la colonna di testo si stringeva sulla riga più lunga e veniva poi
allineata a sinistra dalla colonna esterna della card (`crossAxisAlignment.start`); la riga
più corta risultava centrata solo rispetto a quella, non rispetto alla card intera.
`SizedBox(width: double.infinity)` attorno alla colonna di testo in `trail_detail_sheet.dart`
la fa ora centrare sull'intera card.

Monitoraggio dal vivo (`Monitor` sui log `[trails]`) chiuso a fine sessione — non serve più,
i meccanismi di fallback/interruttore si sono dimostrati sufficientemente affidabili nei
test di stanotte da non richiedere più supervisione continua.

---

## 25 agosto 2026 — CAI Varallo in parallelo (non "ultima spiaggia"); partenza/arrivo su due righe

Settimo e ultimo giro della serata. Due richieste:

1. **Capi-percorso più leggibili**: "Alagna → Rifugio Pastore" su una riga sola con una
   freccetta non distingueva bene i due punti a colpo d'occhio. Ora partenza e arrivo sono su
   due righe separate, ciascuna con un'icona diversa (un pin per la partenza, una bandiera
   per l'arrivo — stessa metafora di qualunque app di mappe) invece della sola freccia
   generica. Nuovo `_EndpointRow` in `trail_detail_sheet.dart`.
2. **CAI Varallo non è più "ultima spiaggia"**: fin dalla fetta di ieri sera, la ricerca su
   CAI Varallo partiva **solo dopo** aver saputo l'esito della fonte OpenStreetMap (o, nel
   caso della card traccia, solo se la risoluzione falliva del tutto). L'utente ha chiarito la
   richiesta: va fatta **sempre**, appena si sa di essere in Valsesia — **in parallelo**, non
   in coda. Due punti toccati:
   - `CombinedTrailService.fetchDetail`: il controllo Valsesia si fa ora sui punti **già noti
     sulla relazione** (quelli della ricerca che ha portato a questo segnavia, sempre
     popolati nell'uso reale), non su quelli — non ancora disponibili — della geometria
     completa. Se il controllo può farsi subito, CAI Varallo parte **nello stesso istante**
     del fetch della geometria, non dopo; il risultato si allega quando entrambi sono pronti.
     Ripiego per compatibilità (usato solo dai test che passano una relazione "nuda", senza
     punti — mai il caso in produzione): se non si può decidere subito, si ricontrolla dopo il
     fetch sui punti della geometria, come prima.
   - `TrailDetailNotifier.openByRef` (card traccia): `fetchByRefOnly` (solo ref + punto di
     ancoraggio, indipendente da OpenStreetMap) parte **subito**, in parallelo alla
     risoluzione `trailsNear` — non più tentato solo come ripiego se quella non trova un
     match esatto. Se la risoluzione OpenStreetMap va comunque a buon fine, questo risultato
     "in parallelo" viene scartato (`open()` fa la sua propria ricerca CAI Varallo, già in
     parallelo al fetch della geometria) — una chiamata in più verso una singola pagina
     statica, non paragonabile al volume di Overpass di cui ci si è preoccupati poco fa.

   Effetto pratico confermato dall'utente come accettabile: un segnavia può finire per
   mostrare **solo** il link CAI Varallo (nessun nome/capi-percorso da OpenStreetMap, nessuna
   traccia sulla mappa) se la fonte OpenStreetMap fallisce del tutto ma CAI Varallo risponde —
   comportamento già coperto dall'avviso "Percorso completo non disponibile ora" introdotto
   nella fetta precedente (testo generalizzato: non parla più solo di "rete", visto che ora
   copre anche il caso "non risolto su OpenStreetMap" senza che sia necessariamente un
   problema di connessione).

Test: nuovo test di tempistica in `trail_service_test.dart` (CAI Varallo e geometria
impiegano ~80ms ciascuno con mock deliberatamente lenti; il tempo totale resta vicino a 80ms,
non alla somma — prova che girano davvero in parallelo, non solo che il risultato finale è
corretto); nuovo test analogo in `trail_detail_provider_test.dart` per `openByRef`
(`fetchByRefOnly` invocato prima che `trailsNear` sia risolto, non dopo un suo fallimento);
`trail_detail_sheet_test.dart` aggiornato per le due righe separate di partenza/arrivo.

---

## 25 agosto 2026 — Riduce il volume di richieste a Overpass (sospetto autolimite dopo troppi test)

Quinto giro della stessa serata. Durante il test del fix precedente, Overpass ha iniziato a
fallire con `Connection refused` su **tutte** le istanze contemporaneamente — un pattern
diverso dal semplice sovraccarico (`HTTP 504`) di prima. Domanda esplicita dell'utente:
"quante richieste stiamo facendo agli stessi server? non è che ci blocca per troppe
richieste?".

Analisi: sì, probabile. Due cause concorrenti, entrambe nostre:
1. **Due dei tre "mirror" erano lo stesso operatore.** `overpass-api.de` (principale) e
   `lz4.overpass-api.de` (primo mirror) sono la **stessa infrastruttura** (istanze diverse
   dello stesso progetto Overpass "madre"), non fonti indipendenti come si era assunto il 25
   mattina — solo `overpass.private.coffee` è davvero un operatore diverso. Ogni ricerca
   quindi mandava **due** richieste allo stesso operatore che, per primo, mostrava segni di
   sovraccarico.
2. **La corsa a staffetta non avanzava più in fretta su un fallimento rapido.** Un
   `Connection refused` (praticamente istantaneo) faceva comunque aspettare l'intero
   `_hedgeDelay` (3s) prima di provare l'istanza successiva — nessun beneficio di velocità,
   e nel frattempo **tutte e tre** le richieste partivano comunque ad ogni singola ricerca,
   raddoppiando/triplicando il traffico verso server che probabilmente stavano già
   applicando un limite temporaneo su questo IP per l'uso intenso della serata.

Interventi:
- **Mirror ridotto a uno solo** (`overpass.private.coffee`, il solo indipendente):
  `_defaultMirrors` passa da 2 a 1 — ogni ricerca genera al più **2** richieste invece di 3,
  e le due che restano sono davvero due pareri diversi, non lo stesso server contato due
  volte.
- **Fallimento rapido → si passa subito al mirror**, senza aspettare `_hedgeDelay`: la
  staffetta ora avanza su **qualunque** fallimento (non solo un timeout lento), cancellando
  il timer di stagger e tentando l'istanza successiva nello stesso istante.
  `_postToAnyEndpoint` riscritto attorno a un `nextIndex` condiviso fra il timer di hedge e
  il percorso di fallimento, invece di pre-schedulare un timer per ogni mirror a priori.
- **Nuovo interruttore anche per Overpass** (non solo per OSM2CAI): dopo un fallimento
  totale (entrambe le istanze giù), salta la rete del tutto per 30s invece di ritentare ad
  ogni tap — un tap ripetuto durante un'interruzione reale non deve continuare a mandare
  altro traffico a un servizio che ha appena detto di no. Cooldown breve (30s, contro i 5 min
  di OSM2CAI): qui il servizio può tornare disponibile in pochi secondi, non è rotto in modo
  permanente.

**Verificato dal vivo mentre si scriveva questo fix**: un fallimento totale sul fetch della
geometria di "GTA" (tutte e tre le istanze — ancora con la build precedente, prima del
redeploy) ha comunque mostrato la card con i dati già noti invece di "non trovato",
confermando che il fix della voce precedente funziona su un caso reale, non solo nei test.

Test: 2 nuovi in `trail_service_test.dart` (fallimento rapido non aspetta `_hedgeDelay`;
l'interruttore salta la rete del tutto alla richiesta successiva, verificato contando le
chiamate al `MockClient`).

---

## 25 agosto 2026 — CAI Varallo come ultima spiaggia quando la relazione non si risolve affatto

Sesto giro. Feedback dell'utente dopo aver visto "non trovato" per un segnavia dalla card
traccia mentre Overpass era giù: "ha provato anche a cercare il link del CAI? non ha senso
non mostrare nulla!" — distinto dal fix precedente (quello copre il caso in cui la relazione
**è già stata trovata** ma il fetch della geometria fallisce; qui invece è la **risoluzione
stessa** del ref in una relazione — `TrailDetailNotifier.openByRef`, via
`TrailService.trailsNear` — a fallire o a non trovare nulla).

In questo caso non c'è nessuna `TrailRelation` da cui recuperare nome/capi-percorso (li
espone solo Overpass/OSM2CAI), ma la ricerca su CAI Varallo **non dipende da nessuna delle
due fonti**: le basta il numero segnavia (già noto, è quello cliccato) e la posizione (il
punto di ancoraggio sulla traccia, già noto). Nuovo `TrailService.fetchByRefOnly(ref,
anchor)` (implementazione reale solo in `CombinedTrailService`, `null` di base come
`fetchDetail`): se il punto è in Valsesia e il ref è nell'elenco ufficiale, ritorna un
`TrailDetail` minimo (solo ref + il link CAI Varallo, `geometryComplete: false`) invece di
`null`. `TrailDetailNotifier.openByRef` lo prova come ultima spiaggia prima di arrendersi con
"non trovato".

Test: 3 nuovi in `trail_service_test.dart` (`group('fetchByRefOnly')`: trovato in Valsesia,
fuori Valsesia niente richiesta, in Valsesia ma non in elenco); 2 nuovi in
`trail_detail_provider_test.dart` (mostrato comunque via CAI Varallo; errore genuino quando
nemmeno lì si trova nulla) — quello vecchio "nessun ref corrispondente" aggiornato per
riflettere il nuovo comportamento.

---

## 25 agosto 2026 — Fix: un fallimento di rete sulla geometria buttava via anche i dati già noti

Quarto giro della stessa serata: durante un test dal vivo, un fallimento totale di Overpass
(vedi sopra: fino a `Connection refused` su tutte e tre le istanze, sospetta ritorsione del
servizio pubblico dopo molte richieste ravvicinate durante i test di stasera — la corsa a
staffetta manda fino a 3 richieste per ricerca) ha fatto uscire "Segnavia non trovato" per il
251, che pure era già stato **trovato e identificato** un attimo prima (`trailsNear` aveva già
risolto la relazione — solo il fetch della geometria *completa* falliva). Feedback
dell'utente: "ha provato anche a cercare il link del CAI? non ha senso non mostrare nulla!".

Causa: `CombinedTrailService.fetchDetail` non distingueva "il fetch è fallito" da "il fetch ha
risposto ma non ha trovato nulla" — un'eccezione di rete sul fetch della geometria buttava via
**anche** ref/nome/capi-percorso/grado CAI, già noti dalla `TrailRelation` risolta un istante
prima, **e** impediva di provare CAI Varallo, che non dipende affatto da quel fetch (usa solo
il `ref`, non la geometria).

Fix: `fetchDetail` ora cattura l'eccezione e costruisce un `TrailDetail` **parziale**
(`geometryComplete: false`) con i campi già disponibili sulla relazione — sempre che questa
abbia almeno un punto noto (altrimenti resta `null`: niente su cui costruire nulla). Prova
comunque CAI Varallo (usa i punti della relazione, non quelli del fetch fallito, per il
gate geografico Valsesia). La UI (`_TrailDetailBody`) mostra tutto il resto normalmente più
un avviso ("Percorso completo non disponibile ora (rete) — riprova più tardi"); la traccia
tratteggiata sulla mappa e il fit-bounds della camera (`map_gl_screen.dart`) restano
disattivati quando `geometryComplete` è `false` — disegnare un troncone ritagliato come fosse
l'intero segnavia sarebbe più ingannevole che non disegnare nulla.

Test: 3 nuovi casi in `trail_service_test.dart` (dettaglio parziale con CAI Varallo tentato
comunque; `null` genuino quando la relazione non ha nemmeno un punto noto; dettaglio parziale
da OSM2CAI senza inventare un `officialUrl`); nuovo widget test in `trail_detail_sheet_test.dart`
per l'avviso in UI.

---

## 25 agosto 2026 — Terzo giro: tempi di ricerca, messaggio di caricamento, chiudere col tap altrove

Terza tornata di feedback sulla stessa serata di test ("molto migliorato... ma perché ci
mette tanto?"). Tre richieste:

1. **Perché è lento, e cosa si può ottimizzare** — analisi + due interventi:
   - **CAI Varallo è già veloce e resta così**: un solo `GET` a una pagina (l'elenco
     ufficiale), nessun retry, timeout 10s — tipicamente sotto il secondo. Confermato,
     nessuna modifica necessaria lì.
   - **OSM2CAI pagava un giro di rete garantito inutile ad ogni ricerca**: confermato ieri
     che l'endpoint risponde **sempre** `HTTP 405` in produzione (vedi entry precedente) —
     eppure `CombinedTrailService` lo tentava comunque prima di ogni fallback a Overpass.
     Nuovo **interruttore**: dopo il primo fallimento, salta OSM2CAI per 5 minuti (poi
     riprova, in caso torni su) invece di pagare quel giro di rete ad ogni singola ricerca.
   - **Overpass, da sequenziale a "corsa a staffetta" (hedged request)**: il retry
     sequenziale di ieri (prova A, aspetta fino a 10s, poi B, poi C: fino a 30s nel caso
     peggiore) è diventato una **corsa a staffetta** — parte subito con l'istanza
     principale; se non risponde entro 3s, parte ANCHE il primo mirror (in parallelo, non
     al posto); altri 3s e parte anche l'ultimo. Vince il primo `200`. Caso peggiore
     ~16s (contro 30s), caso comune (istanza principale sana) invariato — le altre non
     partono nemmeno. `OverpassTrailService._postToAnyEndpoint` riscritto con un
     `Completer` condiviso; i timer di stagger sono `Timer` veri (non `Future.delayed`)
     per poterli **cancellare** appena una richiesta vince — altrimenti un timer ancora in
     sospeso quando il widget test smonta l'albero fa fallire `flutter_test` con "A Timer
     is still pending even after the widget tree was disposed" (scoperto proprio scrivendo
     il test per questo fix).
   - **Scoperta laterale mentre si indagava il timer pendente**: tre test in
     `draw_route_controls_test.dart` (`PhotoDetailCard mostra titolo...`, `PhotoDetailCard:
     Scollega...`, `coerenza grafica: PhotoDetailCard...`) costruivano un `ProviderContainer`
     **senza** l'override di `trailServiceProvider` — a differenza di `pumpCard()` più in
     alto nello stesso file, che ce l'ha. Prima innocuo (un solo fallimento di rete reale era
     abbastanza rapido da passare inosservato), diventato un problema reale con la corsa a
     staffetta: il test restava appeso per **minuti** su chiamate di rete vere verso
     `overpass-api.de`/mirror. Aggiunto l'override mancante a tutti e tre.
2. **Messaggio di caricamento più chiaro** — sotto lo spinner della card di dettaglio, un
   testo esplicativo ("Cerco il percorso completo…" + "Può richiedere una decina di secondi
   se la rete è lenta"): uno spinner muto per svariati secondi sembrava bloccato.
3. **Tap altrove sulla mappa chiude il dettaglio segnavia, come una traccia selezionata** —
   `_selectNearest` (`map_gl_screen.dart`) già deseleziona la traccia e/o passa all'ispezione
   di un nuovo punto ad ogni tap sulla mappa; il dettaglio segnavia restava però "orfano"
   sopra un punto/traccia ormai diversi. `_onTap` ora chiama
   `trailDetailProvider.notifier.clear()` in testa, prima della logica esistente — stesso
   tap, stesso comportamento del resto delle card.

Test: nuovo test di corsa a staffetta in `trail_service_test.dart` (un mirror più veloce
vince senza aspettare il timeout pieno dell'istanza principale, con `hedgeDelay`/
`perAttemptTimeout` ridotti per restare veloce); `hedgeDelay: Duration.zero` aggiunto al test
di fallimento totale (altrimenti pagherebbe per davvero l'attesa di stagger anche con un
mock istantaneo); tre `ProviderContainer` corretti in `draw_route_controls_test.dart`.

---

## 25 agosto 2026 — "Un segnavia per intero": 6 correzioni dal secondo giro di test dal vivo

Secondo giro di test sulla traccia "Rassa Alpe Toso" (segnavia 251/253), dopo il fix del
raggio di ricerca. Sei segnalazioni, tutte affrontate:

1. **Overpass, resiliente a un'istanza pubblica sovraccarica** — il fallimento isolato
   (`HTTP 504`) di ieri non era accettabile per un'azione interattiva. `OverpassTrailService`
   prova ora **in sequenza** l'istanza principale (`overpass-api.de`) e due mirror pubblici
   indipendenti (`lz4.overpass-api.de`, `overpass.private.coffee`), fermandosi al primo `200`;
   lancia `TrailLookupException` solo se **tutte** falliscono. Non elimina la possibilità di
   fallimento (nessuna garanzia è possibile su un servizio di rete gratuito), ma riduce
   drasticamente la probabilità pratica — verificato che il fallback tenta davvero tutti e
   tre gli endpoint prima di arrendersi (`trail_service_test.dart`).
   - **Corretto in giornata, verifica dal vivo alla mano**: un giro di test con tutte e tre le
     istanze effettivamente lente ha mostrato che il timeout usato per **ogni** tentativo era
     lo stesso timeout "lato server" della query (25s, pensato per una query complessa
     eseguita da un'istanza sana) — nel caso peggiore, **75 secondi** di attesa prima di
     "non trovato". Separato in due concetti distinti: `timeout` resta il timeout server-side
     nella query (`[out:json][timeout:N]`); nuovo `_perAttemptTimeout` (10s di default) è il
     timeout **client-side per tentativo** nel giro fra le istanze — un'istanza sana risponde
     in pochi secondi, una che non risponde entro 10s sta comunque per andare in timeout.
2. **"Scheda ufficiale" → "OpenStreetMap"** — l'etichetta non diceva a chi la legge cosa sta
   per aprire; ora nomina la fonte, coerente con la label "CAI Varallo" accanto.
3. **Chiusura completa della card sotto, non riduzione** — `_confirmThenOpen`
   (`trail_detail_sheet.dart`) ora chiama `tracksProvider.notifier.deselect()` invece di
   `trackCardExpandedProvider.notifier.collapse()`: la card traccia sparisce del tutto (non
   resta ridotta a mezzo schermo), coerente con `inspectedPointProvider.notifier.clear()` già
   presente per la card punto. Fix di ieri insufficiente — richiesta ripetuta esplicitamente.
4. **Card di dettaglio non più modale** — cambio più corposo: `TrailDetailCard`
   (`trail_detail_sheet.dart`) è ora un widget **persistente e non modale**, montato nello
   `Stack` di `map_gl_screen.dart` esattamente come la card traccia/punto/foto (`AppSheetSurface`
   con `onDismiss`, non più `showModalBottomSheet`). Prima lo scrim nero al 45% e il
   tap-fuori-chiude-tutto (comportamento di `showAppBottomSheet`) impedivano di esplorare la
   mappa con il segnavia evidenziato sotto — esattamente il punto di questa fetta. La traccia
   tratteggiata sulla mappa (fetta 4, invariata) ora si vede e si può ispezionare mentre la
   card resta aperta. `map_gl_screen.dart`: nuovo `trailDetailOpen` watcher, che nasconde
   toolbar/altre card e toglie il padding di sicurezza duplicato, stesso schema di `showCard`.
5. **CAI Varallo: sostituita la ricerca full-text con un lookup esatto** — il tentativo di
   ieri (ricerca `?s=` sul sito WordPress `caivarallo.com`) restituiva "risultati" **non
   pertinenti al segnavia** (eventi, pagine a caso): un numero di sentiero è un pessimo
   termine di ricerca full-text. Sostituito con un dominio e un meccanismo diversi:
   `www.caivarallo.it/valsesia/sentieri-valsesia/sentieri-tutti.php?ord=segnavia`, l'**elenco
   ufficiale** di tutti i sentieri della sottosezione (441 voci, **una sola pagina, nessuna
   paginazione** nonostante il dubbio iniziale — verificato dal vivo con curl il 25 ago 2026),
   con match **esatto** sulla colonna "Catasto" (il numero di riferimento pulito — la colonna
   "Segnavia" affiancata include invece vecchie numerazioni fra parentesi, es. "251 (51)", da
   scartare per il match). Un ref o è in elenco (un solo risultato, sempre pertinente) o non
   c'è (nessun risultato) — mai una lista di link "forse". `TrailDetail.caiVaralloResults:
   List<CaiVaralloResult>` → `TrailDetail.caiVarallo: CaiVaralloResult?` (un solo campo
   nullable, non più una lista): la UI ora mostra un unico link "CAI Varallo" accanto a
   "OpenStreetMap", stesso stile.
6. **Overpass: raddrizza le `member` way invertite prima di disegnarle** — causa-radice del
   "ramo" a linea retta visto sul segnavia 251 (assente su OpenStreetMap, confermato dallo
   screenshot dell'utente): `OverpassTrailService.fetchDetailById` concatenava le way membro
   di una relazione **nell'ordine e nel verso ricevuti da Overpass**, che non garantisce
   entrambi — una way "al contrario" (il suo ultimo punto, non il primo, combacia con la way
   precedente) produce un salto a linea retta da un capo sbagliato all'altro. Confermato dal
   vivo scaricando la relazione 251 reale (id `15870089`, via `lz4.overpass-api.de` dopo che
   l'istanza principale era sovraccarica): il member "way 211430342" è esattamente in questa
   condizione. Fix: nuovo `PathGeometry.stitchSegments(List<List<LatLng>>)` (dominio, puro,
   testato), che per ogni segmento successivo al primo sceglie l'orientamento (diretto o
   invertito) che minimizza la distanza dal punto d'arrivo corrente, invece di assumerlo
   sempre corretto. Applicato sia a `OverpassTrailService.fetchDetailById` (le `member` way)
   sia — per coerenza, anche se l'endpoint è oggi non funzionante (vedi sotto) —
   `Osm2CaiTrailService.fetchDetailById` (le parti di un eventuale `MultiLineString`, nuovo
   `_collectLineParts` che preserva i confini di parte invece di appiattirli come il
   `_collectLineCoords` esistente, lasciato invariato per l'uso con bbox di `fetchRelations`).

Aggiornamento sulla scoperta di ieri (OSM2CAI sempre `HTTP 405` in produzione): confermata
ancora oggi, invariata — vedi `docs/osm2cai-investigation.md`.

Test: nuovo `group('stitchSegments')` in `path_geometry_test.dart` (6 casi: verso già
corretto, un segmento invertito raddrizzato, catena con inversioni alternate senza salti,
segmenti vuoti ignorati, nessun segmento, un solo segmento); nuovo test in
`trail_service_test.dart` con una relazione a 3 member way (quella centrale invertita) che
verifica l'assenza di salti nella geometria finale; nuovi test per il retry multi-istanza di
Overpass; `cai_varallo_search_service_test.dart` riscritto da zero per `findByRef` (match
esatto, ref assente, non confondere col numero fra parentesi, ref vuoto, errori di rete);
`trail_detail_sheet_test.dart` aggiornato per la card persistente (l'host di test ora monta
anche `TrailDetailCard` nell'albero, non si aspetta più una route pushata) e per la chiusura
completa della card sottostante (verificata con un `ProviderContainer` reale, non un fake).

---

## 25 agosto 2026 — Verifica dal vivo del fix + scoperta: OSM2CAI 405 in produzione

Dopo il fix del raggio (voce successiva in questo changelog), verifica dal vivo sul
simulatore con log `[trails]` estesi (aggiunti apposta, vedi sotto) e chiusura delle card
sottostanti all'apertura del dettaglio segnavia (`showTrailDetail`/`showTrailDetailByRef`
ora chiamano `inspectedPointProvider.clear()` + `trackCardExpandedProvider.collapse()` prima
di avviare il fetch — la card di un punto o di una traccia non deve restare in sovraimpressione
mentre si guarda il segnavia).

**Risultato della verifica**: sulla traccia "Rassa Alpe Toso", i segnavia 251 e 253 si sono
risolti correttamente end-to-end (anchor point sul tratto giusto → `trailsNear` con soglia
150 m → match per ref → `fetchDetail` → card pronta, con arricchimento CAI Varallo per
entrambi). Un fallimento isolato con `overpass HTTP 504` (timeout del servizio pubblico) ha
mostrato correttamente "non trovato" invece di un crash — comportamento accettabile per una
richiesta best-effort a un servizio gratuito, non un bug.

**Scoperta collaterale, seguita fino in fondo**: in ogni singola risoluzione, OSM2CAI ha
fallito con `HTTP 405 Method Not Allowed`. Verificato **fuori dall'app**, con `curl` diretto
verso `osm2cai.cai.it` (raggiungibile da questa sessione, a differenza di sessioni precedenti
di sviluppo): la risposta conferma `allow: GET, HEAD` per
`POST /api/geojson/hiking_routes/bounding_box` — l'esatto endpoint e metodo che
`Osm2CaiTrailService` chiama, e che il sorgente pubblico del progetto (`webmappsrl/osm2cai`,
controllato su `develop`, `main` e `master`) dichiara **esplicitamente come `Route::post`**.
Testate anche due varianti GET (query string classica → `404 {"error":"Model not found"}`;
path-segment in stile `/bb/{bbox}/{sda}`, come gli altri endpoint REST dello stesso progetto
→ `404` pagina Laravel). Conclusione: la **produzione non riflette il sorgente pubblico** per
questa rotta specifica (cache delle rotte Laravel non rigenerata dopo un deploy, o un branch
di produzione privato diverso da quelli pubblici) — un problema lato CAI/SOSEC, non
risolvibile lato client. Dettagli in `docs/osm2cai-investigation.md` (aggiornamento in cima
al file) e `docs/validazione-device.md`. Effetto pratico, oggi: **ogni ricerca segnavia passa
sempre da Overpass**, mai da OSM2CAI, nonostante il codice lo tratti come fonte primaria — il
fallback della fetta 2/3 (`CombinedTrailService`) si è dimostrato indispensabile, non solo
difensivo.

File toccati per i log: `trail_detail_provider.dart` (`openByRef`/`open`),
`draw_route_controls.dart` (`_TrailInfo._anchorFor`), `combined_trail_service.dart`
(dispatch + esito di ogni fonte), `trail_service.dart` (`trailsNear`: query, risultati
grezzi, filtro per soglia), `osm2cai_trail_service.dart`/`overpass_trail_service.dart`
(bbox/raggio usato, conteggio raw, ref estratti) — tutti tag `[trails]`, seguono la pratica
di log della sessione (aggiungerne ai punti di decisione/fallimento, non solo su richiesta).

---

## 25 agosto 2026 — Fix: `trailsNear` scartava segnavia reali per un raggio di query troppo stretto

Feedback dal vivo sulla fetta 3/3b/4 di ieri: (1) toccando la mappa vicino a un sentiero
noto, la card del punto non mostrava alcuna label segnavia; (2) dalla card di una traccia,
toccando la stessa label segnavia più volte, ~2 volte su 3 usciva "non trovato" — non
affidabile.

Causa-radice: `TrailService.trailsNear(point, {thresholdMeters})` accetta una soglia
configurabile (60 m per il tap sulla mappa, `inspected_point_provider.dart`; 150 m per
risolvere un `ref` bare dalla card traccia, `trail_detail_provider.openByRef`) — ma la
usava **solo per filtrare i risultati già scaricati**, non per decidere quanto cercare in
rete. `OverpassTrailService.fetchRelations` (fallback quando OSM2CAI non ha il sentiero
cadastrato o il tag `ref` manca in quella zona) mandava sempre una query Overpass con un
raggio **fisso di 40 m** (`aroundMeters`, pensato per `trailSegmentsAlong` lungo un percorso
disegnato, dove ha senso restare stretti) — indipendente dalla soglia richiesta dal
chiamante. Un segnavia a 50-150 m dal punto non veniva **nemmeno scaricato**, non scartato
dopo: il filtro finale (`d <= thresholdMeters`) non poteva salvarlo perché la lista di
partenza era già vuota. Spiega entrambi i sintomi: (1) un tap "vicino ma non troppo" a un
sentiero senza copertura OSM2CAI cadeva sempre fuori dal raggio Overpass di 40 m; (2) la
risoluzione via `openByRef` è intermittente perché dipende da quale fonte risponde prima
(OSM2CAI cataloga alcuni segnavia e non altri nello stesso bbox) — quando cade sul fallback
Overpass, il punto di ancoraggio (centro del tratto instradato) può stare oltre i 40 m dal
vertice OSM più vicino pur essendo ben dentro i 150 m dichiarati come soglia accettabile.

Fix: `TrailService.fetchRelations` guadagna un parametro opzionale `radiusMeters`,
propagato da `trailsNear` come raggio di query effettivo (non solo di filtro).
`OverpassTrailService.fetchRelations` lo usa al posto di `aroundMeters` quando presente;
`trailSegmentsAlong` (percorso disegnato, non passa `radiusMeters`) resta invariato — query
strette intenzionali lì, dove il match è già vincolato a 25 m ogni ~50 m di campionamento.
`Osm2CaiTrailService` ignora il parametro: il suo margine di bbox fisso (~0,01°, ~1,1 km) è
già più largo di qualunque soglia in uso (max 150 m), non ha lo stesso problema.
`CombinedTrailService.fetchRelations` inoltra il parametro al fallback Overpass.

Test: nuovo `trailsNear Overpass: la soglia richiesta diventa il raggio della query`
(cattura il body della richiesta HTTP e verifica `around:150` invece del default `around:40`
quando `trailsNear` chiama con `thresholdMeters: 150`) + un test di controllo che
`trailSegmentsAlong` continua a usare il default. Tutte le classi che implementano
`TrailService` nei test (`_FakeTrailService` in due file) aggiornate alla nuova firma.

---

## 24 agosto 2026 — "Un segnavia per intero" (P1.3): fetta 3b (card traccia + CAI Varallo) e fetta 4 (traccia temporanea sulla mappa)

Chiude l'epica: le tre richieste dell'utente dopo aver testato la fetta 3 ("applica anche
sulla card di una traccia", arricchimento CAI Varallo per la Valsesia, traccia temporanea
sulla mappa).

**Card traccia (`_TrailInfo`, `draw_route_controls.dart`)** — le label segnavia della
propria traccia disegnata diventano tappabili come quelle della card del punto ispezionato,
ma con un problema in più: `DrawnTrack.trailRefs` è solo `List<String>`, nessun
id/fonte/geometria associati (a differenza di una `TrailRelation` già risolta). Percorso
scelto: `TrailDetailNotifier.openByRef(trailRef, anchorPoint)` — risolve prima una
`TrailRelation` reale via `trailsNear(anchorPoint)` (già esistente, pensato per l'uso
originale della card del punto), POI il fetch normale — due chiamate di rete sotto un solo
stato di loading, invisibili come passo singolo per l'utente. `anchorPoint` è il punto medio
del tratto di quel segnavia lungo `routedPath` (via `PathGeometry.pointAtFraction`, già
introdotto stamattina per l'inserimento nodo su sentiero), non un punto a caso della
traccia — così `trailsNear` cerca vicino a dove il segnavia passa davvero, non a un capo
lontano. `_TrailInfo` passa da `StatelessWidget` a `ConsumerWidget`.

Bug di sviluppo lungo il percorso: un parametro chiamato `ref` (il numero segnavia, stringa)
dentro `TrailDetailNotifier.openByRef` **oscurava** il getter Riverpod `ref` ereditato dal
`Notifier` — `ref.read(...)` falliva perché risolveva al tipo sbagliato (`String`, non
`Ref`). Rinominato in `trailRef`.

**Arricchimento CAI Varallo** (`data/trails/cai_varallo_search_service.dart`, nuovo) — se il
segnavia risolto cade in un bounding box approssimativo attorno alla Valsesia (lat
45.65–45.95, lon 7.85–8.35, non un confine amministrativo reale: è solo un gate "vale la
pena provare"), `CombinedTrailService.fetchDetail` cerca anche su `www.caivarallo.com`
(ricerca nativa WordPress, `?s=<query>`) e allega **tutti** i risultati trovati (non uno
solo: il sito non ha una pagina segnavia dedicata univoca — un segnavia può comparire in più
contenuti pertinenti: eventi, rifugi, itinerari — e ogni risultato diventa un link a sé nella
card, `TrailDetail.caiVaralloResults`). A differenza dell'endpoint OSM2CAI (mai verificato
dal vivo, `officialUrl` resta `null` per quella fonte), `caivarallo.com` **è stato
verificato dal vivo con richieste `curl` reali** il 24 agosto 2026 — sia la struttura di un
risultato (`<h2 class="entry-title"><a href="...">titolo</a></h2>`) sia il body di "nessun
risultato" (classe `search-no-results`), compreso un widget "Notizie" nella stessa pagina
che usa la stessa classe `entry-title` ma su `<h5>`, non `<h2>` — il parser filtra
esplicitamente per `<h2>` per non raccoglierlo per sbaglio. Sempre best-effort: qualunque
errore (HTTP non-200, eccezione di rete, timeout) → lista vuota, mai propagato verso la card.

**Traccia temporanea sulla mappa (fetta 4)** — `map_gl_screen.dart` guadagna un manager
dedicato `_trailDetailLine` (creato per ultimo nell'ordine dei manager: z-order sopra a
tutto il resto, dev'essere sempre leggibile), tratteggiato, colore magenta (`0xFFE91E63`,
assente da `kTrackPalette` apposta — non deve poter essere scambiato per una traccia
propria). Un `ref.listen(trailDetailProvider, ...)` in `map_gl_screen.dart` (stesso punto
degli altri listener camera/overlay, accanto a `mapFocusProvider`/`mapFlyToPointProvider`)
disegna `TrailDetail.points` quando lo stato passa a `TrailDetailStage.ready` e sposta la
camera sull'intero segnavia (`_focusOnPoints`, un `cameraForCoordinatesPadding`/`flyTo` che
duplica volutamente `_focusTrack` invece di generalizzarlo: quello lavora su un id di
`tracksProvider`, questo su una lista di punti arrivata da rete, tenerli separati evita di
forzare un'astrazione comune tra "traccia salvata" e "anteprima di rete" che non
guadagnerebbe granché in chiarezza). La linea sparisce da sola alla chiusura della card
(`TrailDetailNotifier.clear()` → stato `null` → `_renderTrailDetail` cancella il manager).

Test: `trail_service_test.dart` esteso (arricchimento CAI Varallo dentro/fuori Valsesia, con
verifica esplicita che **nessuna** chiamata HTTP parte se fuori zona), nuovo
`cai_varallo_search_service_test.dart` (parsing su markup reale, no-risultati, cap
`maxResults`, query vuota senza richiesta, errori HTTP/rete mai propagati), nuovo
`trail_detail_provider_test.dart` (4 test diretti su `TrailDetailNotifier.openByRef`),
`trail_detail_sheet_test.dart` esteso (risultati CAI Varallo come link multipli, sezione
assente se vuoti).

---

## 24 agosto 2026 — "Un segnavia per intero" (P1.3): fetta 3, dialog conferma + card di dettaglio

Prima parte visibile e testabile end-to-end dell'epica: dalla card del punto ispezionato,
tap su una label segnavia → conferma → card di dettaglio con nome, capi-percorso,
distanza/dislivelli (se disponibili), link alla scheda ufficiale se trovato. **Solo dalla
card del punto** in questa fetta — la card traccia (`_TrailInfo`, `draw_route_controls.dart`)
non ha ancora le label tappabili: le sue `trailRefs` sono solo `List<String>` (nessun
id/fonte associato), servirebbe un passo di risoluzione in più prima del fetch vero e
proprio. Rimandato a una fetta successiva per non allungare troppo questa.

- `TrailRelation` guadagna `source: TrailSource` (osm2cai/overpass, nuovo enum): senza,
  `fetchDetail` non saprebbe quale endpoint richiamare per una relazione già trovata.
  `trailServiceProvider` resta tipizzato sull'astratto `TrailService` (non
  `CombinedTrailService`): il dispatch vive come metodo di base con default `null`,
  override reale solo in `CombinedTrailService` — così i test che fanno
  `overrideWithValue(OverpassTrailService(...))` restano validi senza modifiche.
- `Osm2CaiTrailService.fetchDetailById`/`OverpassTrailService.fetchDetailById` (rinominati
  da `fetchDetail` per evitare la collisione col metodo dell'interfaccia, firma diversa:
  `String` vs `TrailRelation`): fetch della geometria **completa**, non ritagliata.
  `CombinedTrailService.fetchDetail(relation)` smista in base a `relation.source` — **nessun
  fallback incrociato** qui (a differenza di `fetchRelations`): si sa già da dove viene la
  relazione, interrogare l'altra fonte non avrebbe senso.
- `TrailDetailProvider` (`features/map_gl/trail_detail_provider.dart`, nuovo): stato
  loading/ready/error, guardia contro risposte in ritardo dopo che l'utente ha chiuso o
  aperto un altro segnavia (confronto per identità della `TrailRelation`, non un token int
  come `InspectedPointNotifier` — stessa idea, forma diversa).
- `showTrailDetail` (`ui/trail_detail_sheet.dart`, nuovo, condiviso): dialog di conferma
  (`showIosConfirm`) poi `showAppBottomSheet` che osserva il provider e si aggiorna da sé.
- `AppTrailTag` guadagna `onTap` opzionale — il contenitore è già visivamente "una pillola",
  incapsularlo in un `CupertinoButton` basta a segnalare che è cliccabile (a differenza del
  caso "Libero" di stamattina: qui non serve altro trattamento).
- `_PointInfoCard` (`map_gl_screen.dart`) passa da `StatelessWidget` a `ConsumerWidget`
  (serviva `ref` per aprire il dettaglio).

Test: `trail_service_test.dart` (fetchDetail per entrambe le fonti + dispatch
`CombinedTrailService`, con e senza id), `trail_detail_sheet_test.dart` (nuovo — conferma,
annulla, successo con dati completi, non-trovato, fallimento di rete senza eccezione
propagata).

---

## 24 agosto 2026 — "Un segnavia per intero" (P1.3): fetta 2, id/nome/capi-percorso sulla relazione

Nessun cambiamento visibile (nessuna UI consuma ancora questi dati) — prerequisito per la
fetta 3 (fetch della relazione completa, serve un id affidabile per richiamarla).

`TrailRelation` (`trail_service.dart`) guadagna `id`/`name`/`from`/`to`/`osmcSymbol`,
opzionali. Popolati in entrambe le fonti:
- **Overpass**: `id` dall'elemento `relation` (sempre presente, è un id OSM standard),
  `name`/`from`/`to`/`osmc:symbol` dai tag — tutti tag OSM ben documentati, affidabili.
- **OSM2CAI**: `name`/`from`/`to`/`osmc_symbol` confermati dai campi della risposta
  (`docs/osm2cai-investigation.md`). **`id` NON verificato dal vivo** — il dominio
  `osm2cai.cai.it` è bloccato dalla network policy del sandbox di sviluppo, quindi il nome
  campo tentato (`props['id']`) è la scelta più plausibile ma non testata contro una risposta
  reale. Annotato nel doc-comment di `TrailRelation.id` e in `docs/validazione-device.md`:
  se la fetta 3 (fetch di `GET /api/v2/hiking-route/{id}`) fallisce sistematicamente per le
  relazioni con fonte OSM2CAI, è il primo sospetto da controllare.

Test aggiunti in `trail_service_test.dart` per entrambe le fonti (metadati estratti
correttamente, campi assenti restano `null` non stringa vuota).

---

## 24 agosto 2026 — "Un segnavia per intero" (P1.3): fetta 1, segnavia nella card del punto

Avviata l'epica P1.3 (`docs/ROADMAP.md`), discussa con l'utente prima di scrivere codice: la
sua idea è più semplice del piano iniziale — niente `queryRenderedFeatures`/menu di
disambiguazione su un tap diretto sulla mappa; l'ingresso è sempre da una **label già
esistente** (chip segnavia sulla card traccia, o le nuove label qui sotto), la
disambiguazione la fa da sola la lista di label mostrate. Decisioni prese: dialog di conferma
prima di aprire il dettaglio di un segnavia (evita aperture accidentali), link alla scheda
CAI **tentato** nella card di dettaglio (non bloccante, mostrato solo se trovato — non più
rimandato del tutto come deciso in un primo momento).

**Questa fetta**: quando si tocca un punto qualsiasi della mappa (card del punto ispezionato,
non una traccia), se il punto è **lungo o molto vicino a un sentiero** compaiono le sue
label numero-sentiero, stesso stile (`AppTrailTag`) delle label già mostrate sulla card di
una traccia disegnata — un solo linguaggio visivo per lo stesso concetto.

- `TrailService.trailsNear(point, {thresholdMeters=60})` (nuovo metodo su base class,
  condiviso da OSM2CAI/Overpass/`CombinedTrailService` come già `trailSegmentsAlong`):
  segnavia entro soglia da un **punto singolo** (non un percorso) — riusa `fetchRelations`
  passando `[point]`, poi filtra per distanza dal vertice più vicino di ciascuna relazione
  (stesso approccio di `_nearest`, non punto-segmento: coerente con l'esistente, non
  introduce un secondo modello di "vicinanza"). Ordina per distanza crescente, **non limita
  il numero di risultati** (un incrocio può avere più segnavia vicini, mostrati tutti come
  label separate — è la disambiguazione "gratuita" di cui sopra). Mai un'eccezione verso il
  chiamante, a differenza di `trailSegmentsAlong`: qui non serve la distinzione
  fallito/vuoto-genuino (nessun flag `trailsResolved` da aggiornare per un punto esplorato al
  volo), quindi il contratto è più semplice — lista vuota su qualunque errore. Test in
  `trail_service_test.dart` (soglia, più segnavia vicini con ordine, propagazione errori).
- `InspectedPoint`/`InspectedPointNotifier` (`inspected_point_provider.dart`): terza ricerca
  asincrona indipendente accanto a quota e reverse geocoding, stesso pattern (token-guarded,
  `nearbyTrails`/`nearbyTrailsLoading`, aggiornamento separato non appena pronta).
- `_PointInfoCard` (`map_gl_screen.dart`): righe `AppTrailTag` in fondo alla card, silenziose
  se non ce ne sono (stessa convenzione della località: niente "nessun sentiero qui").

**Non ancora fatto** (fette successive, stesso P1.3): dati id/nome/partenza-arrivo sulla
relazione (oggi si ha solo `ref`+geometria ritagliata al bbox); dialog di conferma + card di
dettaglio segnavia con link CAI se trovato; traccia temporanea del segnavia sulla mappa con
focus/fit-bounds. Le label create qui **non sono ancora tappabili** verso quel flusso.

---

## 24 agosto 2026 — Log più leggibili + più eventi; punto inserito sul sentiero, non sulla corda

Tre correzioni indipendenti nella stessa sessione, dopo un giro di test dal vivo dell'utente.

**1. Visualizzatore log** (`debug_logs_screen.dart`, `app_log_service.dart`): l'utente ha
provato l'export e chiesto tre cose. **Timestamp a 3 cifre di millisecondi**: prima
`DateTime.toIso8601String()` scriveva fino a 6 cifre di microsecondi (e li ometteva del
tutto sui secondi esatti, lunghezza incoerente) — ora `_timestamp()` costruisce la stringa a
mano da campi `DateTime`, sempre `yyyy-MM-ddTHH:mm:ss.mmm`. **Leggibilità**: ogni riga
mostrata ora come timestamp + **categoria colorata** (il tag `[qualcosa]` iniziale del
messaggio, es. `[routing]`) su una riga, il messaggio sotto — prima un'unica riga lunga.
`_LogEntry.parse` separa sul primo doppio-spazio (compatibile con le righe già scritte prima
del fix del timestamp, qualunque sia la loro lunghezza) ed estrae il tag con una regex;
mappa `_categoryColors` in `debug_logs_screen.dart` per le categorie già in uso, le altre
prendono un grigio di default — aggiungerne una nuova nel codice non richiede toccare questa
mappa. **Più log**: convertiti in log utili una decina di `catch (_) {}` silenziosi nei punti
a più alto valore diagnostico di `route_editor_provider.dart` (salvataggio traccia, calcolo
metriche, ricerca segnavia, import GPX) e `cloud_sync_controller.dart` (`autoPush`/
`autoDelete`) — categorie nuove `[storage]`, `[metrics]`, `[trails]`, `[gpx]`, `[terrain]`,
`[cloud]`, oltre alle già esistenti `[export]`/`[routing]`/`[log]`. Richiesta esplicita
dell'utente di tenere questa pratica anche per il futuro (annotato in memoria di sessione,
non solo qui): aggiungere log ai punti di fallimento/decisione ad ogni nuova implementazione,
non solo su richiesta specifica.

**2. "Libero" non abbastanza cliccabile** (`_SelectedWaypointBar`,
`draw_route_controls.dart`): segnalato dall'utente dopo aver provato la funzionalità — il
tasto era un `AppIconButton` piccolo più una didascalia di testo separata, non si capiva che
l'intera riga fosse cliccabile. Sostituito con lo stesso linguaggio di
`_AdvancedSettingsRow` (contenitore a piena larghezza, sfondo tinta, `AppRadii.rMd`), ma come
**interruttore**: sfondo e icona di spunta cambiano con lo stato invece del solo chevron di
navigazione, `CupertinoButton` avvolge l'intera riga come target di tocco.

**3. Punto inserito a metà di un tratto agganciato: ora sul sentiero, non sulla corda retta**
— bug segnalato dall'utente: "il nuovo punto in mezzo viene creato a metà della linea retta
tra il punto selezionato e il precedente... non ha senso se i due nodi seguivano il
sentiero". `insertPointBefore`/`insertPointAfter` calcolavano sempre la media aritmetica
lat/lon dei due estremi — su un sentiero tortuoso può cadere lontano dal percorso reale (in
un caso limite anche fuori mappa rispetto al tracciato). Nuovo
`PathGeometry.pointAtFraction(path, t)` (con test): punto alla frazione `t` della
**lunghezza cumulata** di un percorso, non della media dei suoi estremi. `insertPointBefore`/
`insertPointAfter` ora sono `Future<void>`: se il segmento è agganciato, recuperano la
geometria instradata da `segmentRouteProvider` (di norma già in cache dall'anteprima live in
corso — nessuna nuova chiamata di rete percepibile) e la passano a `pointAtFraction(...,
0.5)`; se libero, usano la coppia di estremi com'era già (`pointAtFraction` su un percorso a
2 punti degenera esattamente nel punto medio della corda, stesso risultato di prima). Aggiornato
il chiamante in `draw_route_controls.dart` (`onInsertBefore` ora `async`, `await` prima di
spostare la selezione — altrimenti l'indice slitterebbe su un punto che non esiste ancora).
Test nuovo in `route_editor_test.dart` con un routing finto "a gomito" per verificare che il
punto inserito segua davvero il sentiero deviato, non la retta.

---

## 24 agosto 2026 — Traccia mista: tasto "Libero" anche per un inserimento interno

Seguito diretto della voce sotto, stessa sessione: l'utente ha provato la funzionalità e
segnalato un buco reale — con una traccia a-b-c-d-e-f già disegnata, selezionando c e
usando "Aggiungi dopo" non c'era modo di dire che il nuovo punto (una cima fuori sentiero
tra c e d) dovesse restare libero: `Tracks.insertPoint` non guardava affatto
`freeDrawingModeProvider`, solo `Tracks.addPoint` (aggiunta in coda) lo faceva.

**Fix**: `insertPoint` ora legge anch'esso `freeDrawingModeProvider` — se acceso, **entrambi**
i segmenti nati dalla divisione (non solo quello ereditato da `freeSegmentsAfterInsert`)
nascono liberi. Il tasto "Libero" ora compare **anche** nella card del punto selezionato
(`_SelectedWaypointBar`, stesso `freeDrawingModeProvider` della barra principale — un solo
stato, acceso da entrambe le viste), con una riga di testo che conferma cosa succederà al
prossimo inserimento ("il nuovo punto si collegherà senza seguire i sentieri"): la barra
principale è nascosta mentre un punto è selezionato, quindi senza questa aggiunta l'utente
avrebbe dovuto pianificare in anticipo di accenderlo *prima* di selezionare il punto — non
il flusso naturale descritto ("clicco su c, poi decido").

Test aggiunto (`draw_route_controls_test.dart`) che riproduce esattamente il caso
segnalato: traccia di 6 punti, seleziona il terzo, accende "Libero" dalla card del punto
(non dalla barra principale), tocca "Aggiungi dopo", verifica che **entrambi** i segmenti
risultanti dalla divisione siano liberi.

---

## 24 agosto 2026 — Traccia mista: tasto "Libero" per i tratti fuori sentiero

Richiesto dall'utente con un caso concreto: Campertogno → Colma di Campertogno segue i
sentieri, ma per l'ultima salita alla Cima Voccani vuole poter tracciare dritto invece di
seguire il giro lungo imposto dallo snap-to-trail. Discussa prima l'UX (due opzioni: toggle
live mentre si disegna vs tap su un segmento già tracciato) — scelta l'opzione **A** (toggle
live), con **B** (tap su segmento per correggere un tratto già disegnato) rimandata come
estensione futura, non implementata qui.

**Interruttore globale vs tasto "Libero"**: discusso esplicitamente se il vecchio
`snapToTrail` (per l'intera traccia, "Impostazioni avanzate") avesse ancora senso — sì,
risolve un problema diverso ("l'intera traccia è fuori sentiero", es. ghiacciaio/sci
alpinismo, zero chiamate a BRouter) dal nuovo tasto ("solo questo tratto"). Il tasto
"Libero" si disabilita quando lo snap globale è già spento (sarebbe senza oggetto).

**Modello dati** (`route_editor_provider.dart`, `DrawnTrack`):
- `freeSegments: Set<int>` — indici dei segmenti liberi (`i` collega `waypoints[i]` e
  `waypoints[i+1]`). Dato "d'intenzione" come `snapToTrail`: sopravvive a
  `clearedComputed()`, a differenza dei dati calcolati (routedPath/metrics/...).
- `segmentPointCounts: List<int>` — quanti punti ciascun segmento originale contribuisce a
  `routedPath` (esclude il primo, condiviso). Calcolato una volta a "Fine"
  (`finishDrawing`), serve a **ritagliare `routedPath` senza richiamare BRouter** per la
  resa tratteggiata di una traccia già salvata — altrimenti visualizzare un percorso offline
  avrebbe richiesto rete solo per sapere dove disegnare i trattini, rompendo la garanzia di
  funzionamento offline (§CLAUDE.md).

**Rimappatura degli indici** (`domain/services/free_segments.dart`, nuovo, con test):
inserire/rimuovere un waypoint sposta gli indici dei segmenti a valle — `freeSegments` va
rimappato esplicitamente a ogni `insertPoint`/`removePoint`, altrimenti "libero" finirebbe
per segnare il segmento sbagliato dopo un edit. Regole (verificate con test, non ovvie a
naso):
- **Insert** dentro un segmento esistente: **entrambe** le metà ereditano la libertà
  dell'originale (dividere un tratto libero non lo riaggancia, e viceversa). Insert a un
  estremo: nuovo segmento di bordo, non libero di default.
- **Remove** di un punto interno: i due segmenti adiacenti si fondono, liberi se **almeno
  uno dei due** lo era (rimuovere un punto non deve "riagganciare" a sorpresa un tratto
  reso libero apposta). Remove di un estremo: l'unico segmento adiacente sparisce, non si
  fonde con nulla (nessun successore/predecessore a cui fondersi).
- Anche lo **stack di undo** (`_undoStack`) ora salva `freeSegments` insieme ai waypoint,
  non solo questi ultimi — altrimenti un `undo()` dopo un insert che aveva diviso un
  segmento libero avrebbe lasciato `freeSegments` fuori sincrono con i waypoint ripristinati.

**Routing per-segmento**: `_concatSegments` prendeva un unico `bool snap` per tutta la
traccia — cambiato in `bool Function(int) segSnap`, così ogni segmento sceglie il proprio
snap (`track.snapToTrail && !track.freeSegments.contains(i)`). Il resto del meccanismo di
routing (cache per-segmento via `segmentRouteProvider`, fallback a retta su errore) era già
per-segmento di suo — un segmento libero è concettualmente lo stesso ramo "retta diretta"
già usato per i fallimenti di rete, solo forzato deliberatamente. Aggiornati entrambi i
punti di chiamata (`finishDrawing`, `livePathProvider`).

**Provider `freeDrawingModeProvider`** (stato del tasto, non persistito): **non** usa lo
stesso pattern di `SelectedWaypoint` (`ref.watch(activeTrackIdProvider)` per auto-azzerarsi
al cambio traccia) — creerebbe una **dipendenza circolare**, dato che `Tracks.addPoint`
legge questo provider e `activeTrackIdProvider` dipende da `tracksProvider` stesso
(`CircularDependencyError` a runtime, scoperto dai test). Si azzera invece con una chiamata
esplicita `reset()` in `startNewDrawing`/`editSelected`.

**Resa tratteggiata** (`map_gl_screen.dart`): nuovo manager `_savedFreeLines`
(`PolylineAnnotationManager` con `setLineDasharray`, separato da `_savedLines` perché il
tratteggio si imposta solo a livello di manager, non per singola annotazione in questo
plugin). `sliceTrackRuns` (`domain/services/track_runs.dart`, nuovo, con test) ritaglia
`routedPath` nei tratti liberi/agganciati usando `segmentPointCounts` — validazione
difensiva (somma dei conteggi contro la lunghezza di `routedPath`) prima di tagliare, con
fallback a un'unica linea piena se i dati non tornano (traccia mai passata da questa
funzionalità, o disallineata). **Solo la traccia selezionata/salvata** ha il tratteggio in
questa iterazione: l'anteprima live (`_liveLine`, durante il disegno attivo) resta una linea
piena unica per semplicità — la forma del percorso è comunque corretta (retta vs sentiero),
manca solo lo stile tratteggiato mentre si disegna. Possibile estensione futura se serve.

**Persistenza**: due nuove colonne Drift (`freeSegments`, `segmentPointCounts`, entrambe
JSON testo, default `'[]'`) — `schemaVersion` 4→5, migrazione additiva (`addColumn`,
nessuna perdita per le tracce esistenti). Incluse anche nel JSON di sincronizzazione cloud
(`TrackCodec`), per rendere disponibile la resa tratteggiata su un altro device senza
ricalcolo.

- **Non verificato su device fisico/simulatore** in questa sessione: interazione del tasto
  "Libero" dal vivo, resa tratteggiata a schermo, comportamento reale di BRouter su un
  tratto misto — annotato in `docs/validazione-device.md`.

---

## 23 agosto 2026 — Export immagine: giro di bug-fixing dal vivo; log di debug in-app

Seguito diretto della sessione precedente (voce sotto): la prima implementazione dell'export
immagine (`RepaintBoundary` offscreen) e altri due punti sono stati verificati dal vivo
sul simulatore, con l'utente che riproduceva e segnalava, oltre dieci giri di feedback su
screenshot reali. Metodo usato per ogni bug: `debugPrint('[export] ...')` in ogni stadio della
pipeline + `Monitor` con `tail -f | grep` sul log di `flutter run`, riproduzione live,
lettura delle righe per individuare la causa esatta (coordinate pixel, byte, sentinelle di
errore) invece di ipotizzare.

**Cattura vuota (PNG da 5,7 KB)** — causa a catena: `Positioned(left:-6000)` fuori dalla
finestra impedisce del tutto il rendering della platform view; `Opacity(0)` mette in pausa il
rendering nativo (mai `onMapIdle`); e anche a vista genuina, `RepaintBoundary.toImage()` su un
`MapWidget` (hybrid composition) produce output vuoto/quasi vuoto **indipendentemente dal
timing** — limite strutturale, non un bug di sincronizzazione. **Fix**: passaggio allo
`Snapshotter` nativo headless per il PNG; il `MapWidget` interattivo resta solo per
`pixelForCoordinate` (non richiede rendering tile riuscito, solo stato camera).

**Puntini bianchi su punti sbagliati della traccia** (verificato via log: differenze di 0-7 px
dal punto più vicino, eppure visivamente sbagliati) — causa: il `MapWidget` sorgente di
`pixelForCoordinate` era dentro un `FittedBox` per lo scaling a schermo; le platform view non
allineano in modo affidabile le coordinate riportate con la scala visiva post-trasformazione
di Flutter. **Fix**: `FittedBox(fit:contain)` → `OverflowBox` (ritaglia, non scala) in
`_CapturingPreview`.

**Etichette POI troncate a una parola** — `TextPainter(maxLines:2)` usato per misurare non
corrispondeva al vero widget `Text(maxLines:2, overflow:ellipsis)`: il testo andato a capo
finiva sotto/fuori dallo sfondo della pillola. **Fix**: tolto `maxLines`/`overflow` sia dalla
misura sia dal widget reale, tolta l'altezza fissa da `Positioned` (solo `width:`), così
misura e resa coincidono sempre.

**"Cima Mutta" a pixel `(-1,-1)`** — sentinella Mapbox per coordinata fuori dal viewport
corrente: la camera veniva calcolata solo sul path del percorso, non sui POI (una cima è
spesso fuori traccia). **Fix**: incluse le posizioni di tutti i POI nell'array passato a
`cameraForCoordinates`; aggiunto un controllo bounds difensivo che scarta ogni pixel ancora
non valido dal risultato finale.

**"Rifugio Vallè" mai tra i punti trovati** — la query Overpass cercava solo `node[...]`, ma
il rifugio è mappato come `way` (contorno edificio). Verificato con `curl` diretto a
`overpass-api.de` riproducendo la query di produzione. **Fix**: `node[...]` → `nwr[...]` in
ogni clausola, `out body;` → `out body center;`, parsing di `el['center']['lat'/'lon']` per
way/relation. Ancora assente dopo il fix: la deduplica teneva "il primo incontrato
camminando" — un alpeggio nello stesso punto del rifugio, processato prima, vinceva. **Fix
2**: la deduplica ordina prima per priorità di categoria (`rifugio, cima, colle, lago, alpe`),
così un rifugio vince sempre su un alpeggio nello stesso punto, indipendentemente
dall'ordine lungo il percorso. Test aggiunto (`nearby_pois_matcher_test.dart`) che rispecchia
esattamente il caso reale (Rifugio Vallè / Alpe Vallè di Sopra).

**Etichette sovrapposte, nessun'ancora visibile** — aggiunti pallini reali sui punti
(prima la lineetta puntava a niente di visibile) + layout automatico anti-sovrapposizione
(spinta verticale greedy su `Rect.overlaps`, via `TextPainter`). Continuava a fallire su
tracciati con molti POI ravvicinati: proposte due strade, scelta dall'utente l'opzione **B**
(etichette trascinabili) dopo aver verificato l'opzione A — l'automatico resta come posizione
di partenza, il pallino **non** è trascinabile (la sua correttezza è "conditio sine qua non",
parola dell'utente). Implementazione: `GestureDetector.onPanUpdate` per pillola, offset per
POI in `Map<String,Offset>` nello state dello schermo, clamp finale dentro i bordi
dell'immagine fatto **una sola volta dopo** il loop di ricerca (bug minore risolto in corsa:
il clamp durante la ricerca restava incastrato contro il bordo).

**Icona "alpe" identica a "rifugio"** — entrambe usavano `house_fill`; cambiata l'alpe a
`CupertinoIcons.tree`.

**Orientamento camera sul dislivello** (richiesta esplicita, non nord fisso) —
`domain/services/elevation_orientation.dart`: cerca il punto di quota minima e massima nel
profilo altimetrico (su tutto il profilo, non solo agli estremi del percorso), calcola il
bearing bussola fra i due (`latlong2` `Distance().bearing`), normalizzato [0,360); `null` se
degenere (stesso punto). Il basso dell'immagine è il punto più basso, l'alto il più alto.

**Zoom/angolazione personalizzabili — solo analisi, non implementata** (richiesta esplicita
dell'utente: "analizza, non implementare"): due opzioni valutate, salvate in
`docs/ROADMAP.md` P2 punto 4 (mappa interattiva come passo intermedio vs slider sopra
l'anteprima già generata, quest'ultima consigliata).

**Menu "Altro" della card**: "Esporta" (sotto-foglio) appiattito in "Esporta GPX"/"Esporta
immagine" come voci dirette — essendo già dentro un menu, un secondo livello era ridondante.

**Indicatore "salvata offline"**: `tracks_list_screen.dart`/`draw_route_controls.dart`
leggono `downloadedRegionsProvider` e confrontano l'id `'track-<id>'` (stesso schema di
`downloadTrackOffline`) per mostrare un segno di spunta verde in lista e nel menu azioni,
cambiando anche etichetta/icona della voce "Salva offline" quando già scaricata.

**Log di debug in-app** (richiesta a sé, non pianificata): `AppLogService`
(`data/logging/app_log_service.dart`) sovrascrive la variabile globale riassegnabile
`debugPrint` di Flutter — nessuna modifica ai punti che già chiamano `debugPrint` (inclusa
tutta la diagnostica `[export]` sopra), cattura tutto da qui in poi. Scrive su
`ApplicationSupportDirectory/logs/sentei.log` (non iCloud-synced, a differenza di
`getApplicationDocumentsDirectory()` già usato per la cache tile terreno). Rotazione: 512 KB
per file (leggero da condividere anche in rete scarsa in montagna), max 4 file (~2 MB
totali), purge per età oltre 7 giorni all'avvio — dimensionamento scelto per un log di debug
beta, non serve conservarlo più a lungo (anche meglio per la privacy: niente accumulo
indefinito di coordinate). `features/settings/debug_logs_screen.dart`: lista monospace scura,
auto-scroll all'ultima riga, condivisione (`share_plus`, stesso pattern di GPX/immagine) e
cancella (con conferma). **Punto d'accesso volutamente nascosto**: non un tasto come gli
altri in Impostazioni, ma 7 tap entro 3 secondi sul footer "Sentèi · vX.X" in fondo alla
schermata (`_VersionFooter` in `settings_screen.dart`).

**Card "Novità"**: era già implementata da una sessione precedente (`whats_new.dart`); due
correttivi su richiesta esplicita — tolta l'icona sopra il titolo (il mockup di riferimento
la mostrava, ma l'istruzione verbale dell'utente prevaleva), e resa non richiudibile a tocco
fuori/swipe (`isDismissible: false, enableDrag: false` — nuovo parametro `enableDrag` su
`showAppBottomSheet`, prima solo `isDismissible`).

- **Non verificato su device fisico** in questa sessione (stesso richiamo della voce
  precedente): salvataggio in galleria, condivisione di sistema, orientamento camera e
  posizioni POI su percorsi reali del telefono, rotazione dei file di log oltre 512 KB —
  annotato in `docs/validazione-device.md`.

---

## 23 agosto 2026 — Android: `--split-per-abi` per il build `1.0.0+9`

Segnalato dall'utente confrontando i due build della `1.0.0+9`: "iOS pesa 44 MB, Android
130 — sono 3 volte tanto". Causa verificata ispezionando l'APK universale (`unzip -l`): le
librerie native occupavano **arm64-v8a 41 MB + armeabi-v7a 32 MB + x86_64 44 MB ≈ 117 MB**,
quasi tutte e tre le architetture bundlate nello stesso file — l'IPA non ha questo problema
perché tutti gli iPhone moderni sono un'unica architettura (arm64). Era già in
`docs/ROADMAP.md` P4 come fix noto e a costo zero (solo un flag di build).

Rifatto con `flutter build apk --release --split-per-abi`: **arm64-v8a 49,5 MB** (quello da
dare ai tester, copre tutti i telefoni recenti), armeabi-v7a 40,2 MB, x86_64 52,6 MB
(emulatori). Punto tolto da `docs/ROADMAP.md` P4 (fatto).

---

## 23 agosto 2026 — Deployment target iOS alzato a 15.0

Segnalato da Transporter caricando l'IPA della `1.0.0+9`: warning `MinimumOSVersion too low`
(90068) — da primavera 2027 Apple richiederà `MinimumOSVersion` ≥ 15.0 per il caricamento su
App Store Connect. Non bloccante ora (solo un warning, quell'IPA a 14.0 resta valida), ma
corretto subito perché a costo zero: `IPHONEOS_DEPLOYMENT_TARGET` 14.0 → 15.0 su tutte e tre
le build configuration di `ios/Runner.xcodeproj/project.pbxproj` + `platform :ios` in
`ios/Podfile`, `pod install` rieseguito senza conflitti (2 pod, nessuna incompatibilità).
**Da questa build in poi** (non retroattivo sull'IPA già generata per la `1.0.0+9`).

---

## 23 agosto 2026 — Cache elevazione senza limiti: causa del "l'app pesa centinaia di mega"

Segnalato dall'utente su **iPhone fisico**, prima di questo rilascio: "Sentèi pesa
veramente molto (centinaia di mega)". Indagine (analisi, non riproducibile sul
simulatore — serve una libreria d'uso reale accumulata nel tempo) prima di procedere.

**Causa individuata**, `data/offline/terrarium_tile_cache.dart`: la cache delle tile
Terrarium (terrain-RGB, usate per il calcolo del dislivello) scrive un PNG per tile senza
alcun tetto, eviction o pulsante per svuotarla — e non è legata solo alle aree scaricate
offline: `terrariumCacheProvider` (`route_editor_provider.dart`) è condiviso da **ogni**
calcolo di dislivello, quindi ogni traccia mai disegnata/vista/importata lascia lì delle
tile per sempre. Viveva inoltre in `getApplicationDocumentsDirectory()` — sbagliata per
dati rigenerabili: `Documents` è incluso nel backup iCloud e non viene mai ripulito
dal sistema per pressione di spazio.

Verificato anche il secondo sospetto, la cache tile di Mapbox (`TileStore`, condivisa fra
aree scaricate e navigazione online): il codice sorgente del plugin conferma che **è già
esclusa dal backup iCloud** by design, ma `mapbox_maps_flutter` 2.25 non espone alcun
metodo Dart per limitarne la dimensione (nessun `setDiskQuota` nei binding) — capirla a
fondo richiederebbe codice nativo (Swift/Kotlin), rimandato: il Terrarium cache era la
causa a più alta confidenza (visibile e correggibile lato Dart) e il rischio di toccare
codice nativo prima di un rilascio non valeva la pena per un sospetto non confermato.

**Fix**, tutto in `terrarium_tile_cache.dart`:
- Spostata in `getApplicationCacheDirectory()` (`Library/Caches` su iOS) — escluso dal
  backup, purgabile dall'OS.
- **Tetto 200 MB** con eviction LRU per data di modifica (non c'è un registro degli
  accessi): al superamento, si scende all'80% del tetto invece di rientrare esatti, per
  non dover rifare la scansione della cartella ad ogni scrittura successiva. Running total
  tenuto in memoria (`_approxBytes`), evita di scansionare il disco a ogni tile scritta —
  solo quando lo si supera.
- **Migrazione una tantum**: alla prima apertura della cache, cancella la vecchia cartella
  in `Documents/terrarium_cache` se esiste — senza, il fix non avrebbe liberato lo spazio
  già occupato su chi ha già installato l'app, cioè esattamente chi ha segnalato il
  problema.
- Nuova sezione "Cache elevazione" in Impostazioni → Mappe offline
  (`offline_maps_screen.dart`): dimensione corrente + pulsante per svuotarla a mano, prima
  invisibile e non azionabile dall'utente.
- **Non testato su platform-channel** (path_provider): nessun test automatico aggiunto,
  stessa convenzione già in uso per `offline_maps_service.dart`/`terrarium_http_fetcher.dart`
  (wrapper sottili su plugin nativi, verificati a schermo non con `flutter test`).
- **Non verificato su device fisico** in questa sessione: la migrazione one-shot va
  confermata proprio sul telefono che ha segnalato il problema (è l'unico con una cache
  vecchia da migrare) — annotato in `docs/validazione-device.md`.

---

## 23 agosto 2026 — Export immagine del percorso; card traccia: Elimina, "Altro", tracce attenuate; Impostazioni riorganizzate

Tre pezzi di lavoro nella stessa sessione, in ordine.

**1. Card traccia selezionata (mappa)**: nuovo tasto **Elimina** (con conferma,
`_confirmDeleteTrack` — stesso testo della lista tracciati). Quando una traccia è
selezionata, le altre si attenuano (`lineOpacity: 0.35` in `_renderAll`,
`map_gl_screen.dart`) per leggibilità con più tracce vicine; i pallini inizio/fine
(`_drawEndpoints`) ora compaiono **solo** sulla traccia selezionata (prima su tutte, anche
senza selezione). Il pallino di arrivo è diventato una bandiera a scacchi
(`_buildFinishFlagImageData`, canvas→PNG via `addStyleImage`+`PointAnnotationManager`) al
posto del cerchio rosso pieno — **bug scoperto in corsa**: il primo tentativo passava byte
RGBA grezzi a `MbxImage.data`, che invece si aspetta un'immagine **codificata** (come da
esempio ufficiale del plugin) — l'eccezione non gestita in `_styleSetup` bloccava l'intero
setup della mappa (nessuna traccia visibile). Risolto codificando in PNG.

**2. Impostazioni**: la voce "Sentèi" (nome+versione, apriva Novità/Roadmap) è stata divisa
in due — un footer di schermata (non di sezione) con nome+versione in fondo alla
`ListView`, e un tasto "Novità e roadmap" a parte in "Informazioni" che apre lo stesso
foglio di prima (`showReleaseNotes`, invariato). La riga "Mappa" ora apre un foglio
`showMapInfo` (nuovo, `lib/ui/legends.dart`) con l'attribuzione Mapbox/OSM e due link
esterni (`url_launcher`, già dipendenza inutilizzata prima d'ora). **Vincolo verificato nel
codice esistente**: l'icona "i" nativa sulla mappa non è rimovibile (termini d'uso Mapbox,
commento già presente in `_configureOrnaments`) — il nuovo foglio è un accesso aggiuntivo,
non un sostituto.

**3. Export immagine** (feature non pianificata, richiesta con mockup dall'utente — vedi
`docs/ROADMAP.md`, non ancora aggiunta lì perché già consegnata). Decisioni prese con
l'utente prima di scrivere codice (4 domande, tutte risposte con l'opzione consigliata):
fonte POI = Overpass API (coerente con `data/trails/`, non i tile vettoriali Mapbox);
rendering = `MapWidget` offscreen + `RepaintBoundary` (non lo `Snapshotter` nativo headless
— serviva controllo Flutter-nativo sulle etichette a pillola+lineetta); il tasto "Esporta"
nella card diventa un menu "Altro" che raccoglie anche Modifica/Salva offline/Elimina
(rischio di overflow con una 6ª icona nuda in riga); categorie POI = rifugio, alpe, lago,
colle, cima, max 10 più vicini al percorso.

- `domain/models/point_of_interest.dart`, `domain/services/nearby_pois_matcher.dart` —
  stesso schema di `nearby_photos_matcher.dart` (soglia 500 m, non 80: un rifugio sta
  spesso a centinaia di metri dal tracciato, non esattamente sopra).
- `data/poi/overpass_poi_service.dart` — nodi OSM per tag (`tourism=alpine_hut|
  wilderness_hut|hut`, `amenity=shelter` → rifugio; `natural=peak` → cima;
  `mountain_pass=yes`/`natural=saddle` → colle; `natural=water` → lago;
  `place=locality|isolated_dwelling` **con nome che contiene "alp"** → alpe, euristica sul
  nome perché l'alpeggio non ha un tag OSM dedicato). Mai un'eccezione verso il chiamante:
  qualunque errore rete/parsing → lista vuota, i POI sono un arricchimento non bloccante.
- `features/draw_route/export/route_snapshot.dart` — `RouteSnapshotCapture`: mappa
  Mapbox headless (stesso terreno 3D/hillshade/cielo di `map_gl_screen.dart`, sempre stile
  Outdoors chiaro, non segue il tema scuro dell'app) posizionata fuori schermo
  (`Positioned(left: -6000, ...)`), cattura con `RepaintBoundary.toImage(pixelRatio: 3)`
  dopo `onMapIdleListener`, più le posizioni pixel di partenza/arrivo/POI via
  `pixelForCoordinate` sulla stessa camera (`cameraForCoordinates(..., pitch: 55)`).
  Timeout di sicurezza 20s (rete assente/stile mai pronto → fallisce senza restare in
  caricamento all'infinito).
- `features/draw_route/export/export_image_screen.dart` — l'immagine base (raster,
  catturata una volta) e le etichette/il testo (widget Flutter veri, sopra) sono
  **disaccoppiati**: il toggle di un POI nella checklist ridisegna solo l'overlay, mai la
  mappa. Il PNG finale si ottiene catturando di nuovo lo stesso `RepaintBoundary` (ora con
  mappa+overlay insieme) solo al tap su "Salva"/"Condividi", non ad ogni toggle.
  Salvataggio in galleria via `PhotoManager.editor.saveImage` (già dipendenza per la
  lettura foto vicine, mai usata finora in scrittura — nessun nuovo permesso iOS: l'app
  chiede già l'accesso `readWrite` di default).
- `features/draw_route/export/export_gpx.dart` — l'export GPX esistente
  (`tracks_list_screen.dart`) estratto in una funzione condivisa: ora usata anche dal
  nuovo foglio "Esporta" della card mappa.
- **Non verificato su simulatore/device** in questa sessione (l'utente ha chiesto di
  ridurre i cicli di test manuali, vedi memoria `sentei-limita-test-simulatore`): la
  cattura offscreen della mappa 3D, il salvataggio in galleria e la condivisione vanno
  controllati a schermo — annotato in `docs/validazione-device.md`.

---

## 16 agosto 2026 — Foto: un solo pallino sulla mappa, non tutto il filo

L'utente segnala che i pallini gialli lungo tutta la traccia (uno per ogni foto collegata)
sono fastidiosi — su un'escursione con molti scatti coprivano il percorso. Richiesta
precisa: nessun pallino di default; ne compare **uno solo**, quello della foto attualmente
guardata, toccando una miniatura o l'icona location nel visualizzatore — e in entrambi i
casi la mappa deve anche centrarsi lì.

- **`_renderPhotos()`** in `map_gl_screen.dart` — prima iterava su `track.photos` e
  disegnava un `CircleAnnotation` per ognuna; ora legge solo `selectedPhotoProvider` e
  disegna **al più un pallino** (quello selezionato, sempre nello stile "grande" che prima
  era riservato all'evidenziazione). Nessuna foto selezionata → nessun pallino, `mgr`
  svuotato con `deleteAll()`.
- **`_selectPhoto(WidgetRef, TrackPhoto)`** — nuovo helper in `draw_route_controls.dart`:
  imposta `selectedPhotoProvider` **e** chiama `mapFlyToPointProvider.notifier.flyTo(...)`
  nella stessa chiamata, così le due azioni (mostra il pallino, centra la mappa) restano
  sempre accoppiate. Sostituisce le chiamate dirette a `selectedPhotoProvider.notifier.set()`
  nei due punti dove si tocca una miniatura: la riga sessione nella sezione FOTO (prima
  foto del gruppo) e il filmstrip dentro `PhotoDetailCard` (foto specifica). L'icona
  location nel visualizzatore a schermo intero (`_FullPhotoTopBar.onShowOnMap`) **già**
  chiamava `mapFlyToPointProvider` da prima (aggiunta con "Vedi sulla mappa", 29 luglio
  2026) — non toccata, si comporta già come richiesto.
- **Non toccato**: lo swipe fra le foto nel `PageView` del visualizzatore a schermo intero
  non muove la mappa né cambia il pallino (solo stato locale `_page`) — l'utente ha chiesto
  esplicitamente solo tap su miniatura/icona location, non un "segui" continuo durante lo
  swipe.
- Effetto collaterale accettato: tappare un pallino **sulla mappa** per selezionare una
  foto (`_onPhotoTap`, rimasto) ora ha senso solo quando un pallino è già visibile — prima
  era un modo per scoprire le foto direttamente dalla mappa, ora quell'affordance sparisce
  insieme ai pallini permanenti: è esattamente ciò che l'utente ha chiesto ("vanno fatti
  sparire").
- **Terzo punto mancato al primo giro**, trovato in verifica su simulatore: la miniatura
  grande in cima a `PhotoDetailCard` (quella che apre il visualizzatore a schermo intero,
  `openFullPhoto`) non passava da `_selectPhoto` — apriva la foto ma non spostava il
  pallino né centrava la mappa, a differenza della riga sessione e del filmstrip già
  sistemati. Stesso fix: `onTap` ora chiama `_selectPhoto(ref, current)` prima di
  `openFullPhoto`. Verificato sul simulatore.

## 15 agosto 2026 — Tempo di percorrenza stimato (metodo CAI)

P1.2 della roadmap: una traccia mostrava distanza, D+/D- e difficoltà, ma non "quanto ci
metto" — il dato che ogni cartello CAI riporta.

- **Formula: CAI / "ora di marcia"**, combinata alla svizzera (SAC). Velocità di
  riferimento **4 km/h in piano**, **300 m/h in salita**, **500 m/h in discesa** (estremo
  prudente delle forbici 300-350/500-600 valutate in roadmap). Combinazione:
  `t = max(t_oriz, t_vert) + min(t_oriz, t_vert) / 2`, dove `t_vert = t_salita + t_discesa`.
  Scartate Naismith (sottostima sui sentieri alpini) e Tobler per-segmento (richiederebbe
  una taratura sul tipo di terreno che non abbiamo).
- **`lib/domain/services/hiking_time.dart`** — `HikingTimeCalculator.estimate()`, servizio
  di dominio puro: input distanza + D+/D- (non i punti grezzi — il D+/D- passato è già
  quello **con deadband** calcolato da `ElevationCalculator`, altrimenti il tempo si gonfia
  come si gonfiava il dislivello prima del filtro). `HikingPace` (lento/medio/veloce) come
  fattore moltiplicativo sulle tre velocità di riferimento; "medio" = fattore 1 = il
  riferimento CAI. Coperto da test (`test/domain/hiking_time_test.dart`): piano/salita/
  discesa isolati, combinato, caso con verticale dominante, passo lento/veloce, input a
  zero.
- **Applicato ovunque c'è un `TrackMetrics`** — non un calcolo separato per traccia in
  disegno/salvata/importata: tutte e tre leggono `DrawnTrack.metrics` (già popolato da
  `TrackMetricsCalculator`), quindi il tempo compare in `draw_route_controls.dart`
  (`_SelectedBody`, riga con icona orologio sotto le metriche) e in
  `tracks_list_screen.dart` (subtitle della riga tracciato) senza logica duplicata. I GPX
  importati passano dallo stesso `route_editor_provider.dart` e quindi dallo stesso
  `TrackMetrics` — nessun codice aggiuntivo necessario.
- **Passo dell'escursionista** — `features/settings/hiking_pace_provider.dart`
  (`HikingPaceController`), stesso pattern di `AppThemeModeController`
  (`app/theme_provider.dart`): `Notifier` persistito in `shared_preferences`, restore
  best-effort (silenzioso se non disponibile, es. nei test). Riga "Passo" in
  Impostazioni → Escursionismo (`settings_screen.dart`, `_HikingSection`), stesso
  bottom sheet di selezione già usato per tema/variante scura.
- **Il tempo mostrato non include le soste** (convenzione CAI): dichiarato in UI ("Circa
  Xh Ymin **di cammino**") invece di lasciarlo implicito.
- **Decisione presa: `TrailSegment.caiScale` resta fuori dalla formula** per questa
  iterazione — pesare EE/EEA come "più lenti" richiederebbe una taratura che oggi non
  abbiamo dati per fare bene, e il passo lento/veloce copre già in parte lo stesso bisogno
  lasciandolo alla scelta dell'utente. Da riconsiderare se il feedback dei tester segnala
  stime sistematicamente ottimiste sui tratti impegnativi.
- `Format.duration(Duration)` aggiunto a `core/util/format.dart` ("Xh Ymin" / "Y min").
- **Resta da fare** (spostato in `docs/validazione-device.md`): confrontare la stima con i
  tempi sui cartelli CAI reali lungo un'escursione nota — i casi di test sono sintetici, non
  presi da un percorso vero.

**Secondo giro, stesso giorno** (l'utente segnala un caso non coperto: andata e ritorno, o
salita a un rifugio con partenza/arrivo nello stesso punto — lì il totale non basta, serve
sapere quanto è la salita e quanto la discesa separatamente; su un sentiero punto-a-punto
resta invece giusto avere una sola previsione):

- **`HikingTimeCalculator.estimateForTrack(ElevationProfile, ...)`** — nuovo metodo accanto
  a `estimate()` (rimasto invariato, usato anche internamente). Percorso **chiuso** se
  distanza fra primo e ultimo campione del profilo < 150 m (`closedLoopThresholdMeters`):
  copre sia l'andata-e-ritorno esatto sia un anello che rientra vicino alla partenza. In
  quel caso divide il profilo nel punto di **quota massima** — non a metà distanza, che sul
  ramo di rientro non coincide col punto di svolta — e ricalcola D+/D- **con deadband**
  separatamente sulle due metà (non l'aggregato: altrimenti la salita si vedrebbe anche il
  D- della discesa). Niente split se il picco è a meno del 10% della distanza totale da un
  capo (es. un percorso che sale per tutta la tratta senza un vero punto di svolta).
  `HikingTimeEstimate` porta sempre `total`; `ascent`/`descent` sono `null` sui percorsi
  punto-a-punto. Quando c'è lo split, `total` è la **somma** di `ascent` e `descent`, non
  una terza stima applicando la formula SAC all'intero percorso: quella darebbe un numero
  leggermente più basso (lo sconto `min(t_oriz,t_vert)/2` si applicherebbe una volta sola
  invece che una per tratta) — **scoperto verificando a schermo** sul simulatore con una
  traccia di prova scritta a mano nel DB (`test-rifugio-1`, 6 km / D+300 / D-300): la lista
  mostrava "2h 21min" mentre la card "Salita 1h23 + Discesa 1h03" = 2h26min, un
  disallineamento che sembrava un bug. Coperto da 4 nuovi test in `hiking_time_test.dart`:
  andata e ritorno esatta (verificati a mano i minuti attesi con la formula SAC, incluso
  che `total == ascent + descent`), anello con rientro vicino ma non identico,
  punto-a-punto (nessuno split), picco troppo vicino a un capo (nessuno split).
- **`_HikingTimeRow`** in `draw_route_controls.dart` — sostituisce la riga a icona singola:
  se `isSplit`, mostra "↗ Salita" / "↘ Discesa" con le stesse frecce/colori di `_GainLoss`
  (coerenza visiva col D+/D- appena sopra), altrimenti la riga singola "Circa Xh Ymin di
  cammino" di prima. La lista tracciati (`tracks_list_screen.dart`) mostra solo `.total`,
  compatta: il dettaglio salita/discesa si apre dalla card.

**Terzo giro, stesso giorno — validazione su una traccia reale**: l'utente segnala che per
la traccia "alpe toso" (Rassa → punto d'appoggio Alpe Toso, VC — 6,4 km, D+ 800 m, D- ~0)
l'app stima **3h43**, mentre due fonti CAI indipendenti riportano **2h15-2h20** per lo
stesso percorso (D+ 732 m, quasi identico):
[caivarallo.com](https://www.caivarallo.com/rifugi-cai-varallo/punto-appoggio-alpe-toso-val-sorba/)
(2h15), [escursionismo.it](https://www.escursionismo.it/rifugi-bivacchi/alpe-toso-14777)
(2h20, D+732, T).

- **Causa: `ascentMetersPerHour` di default a 300 m/h.** Era stato scelto come l'estremo
  prudente della forbice 300-350 indicata nell'analisi iniziale della roadmap (P1.2), ma è
  **più lento del valore standard della formula SAC stessa**, che usa 400 m/h. Con 300 m/h
  la stima su questa traccia usciva 60% più lenta del tempo reale.
- **Corretto a 400 m/h.** Ricalcolando: verticale 800/400=2h, orizzontale 6,4/4=1,6h →
  max(2, 1.6) + min/2 = 2,8h = **2h48**. Resta ~20% più lento delle fonti, ma è un margine
  ragionevole per una formula generica confrontata con un tempo di cartello di un sentiero
  specifico (le fonti locali riportano tempi misurati/vissuti, non calcolati con una
  formula). La velocità di discesa (500 m/h) resta invariata — non validabile con questa
  traccia, quasi tutta in salita.
- **Aggiornati i test esistenti** che usavano il vecchio default (300 m/h) nei loro numeri
  di comodo, e aggiunto un test di regressione con i dati reali di Alpe Toso
  (`test/domain/hiking_time_test.dart`, gruppo "validazione su traccia reale"): verifica il
  risultato esatto (2h48) e che non torni sopra le 3h20.
- **Resta da fare**: passo Lento/Medio/Veloce non ancora confrontato con tempi reali; la
  velocità di discesa (500 m/h) non validata da un caso reale a discesa dominante.

**Quarto giro, stesso giorno — la prima correzione non bastava**: l'utente ha aperto la
traccia reale "Alpe Toso" nell'app (non il caso semplificato usato per verificare a mano) e
riporta **3h15** anziché i ~2h48 attesi — sulla traccia vera D+ è 810 m e D- 107 m (non 0),
leggermente più del caso di prova. Ancora troppo lontano dalle fonti (2h15-2h20).

- **La causa non era (solo) la velocità di salita, ma il correttivo della formula.**
  Verificati due esempi numerici del modello ufficiale svizzero (Schweizer Wanderwege, la
  fonte del metodo CAI — [geopop.it](https://www.geopop.it/come-si-calcolano-i-tempi-di-percorrenza-nei-sentieri-di-montagna-il-modello-cai/)):
  +100 m di dislivello su 1000 m orizzontali ≈ 20 min; +300 m su 1000 m ≈ 49 min. Con la
  formula `max + min/2` e ascesa a 400 m/h questi due casi escono rispettivamente **22 min**
  e **52 min** — plausibili isolatamente, ma il pattern è sistematico: il correttivo (metà
  del tempo minore) è tarato per percorsi con distanza e dislivello **bilanciati** (è il
  caso per cui esiste la formula SAC completa). Su un percorso dove uno dei due domina
  nettamente — una salita diretta come Alpe Toso, dove il verticale (2h) supera parecchio
  l'orizzontale (1,6h) — il correttivo pieno aggiunge più tempo di quanto il modello
  ufficiale suggerirebbe.
- **Corretto il peso del correttivo da `/2` a `/4`.** Stessi due esempi con `/4`: **18,6
  min** (atteso 20) e **48,6 min** (atteso 49) — molto più vicini. Su Alpe Toso (traccia
  reale, D+810/D-107): verticale 2,24h, orizzontale 1,61h → max(2,24,1,61) + min/4 = 2,64h
  = **~2h39**, contro 3h15 di prima. Resta un margine (~15-25%) verso le fonti — atteso: il
  trail è un T (mulattiera/carrozzabile) e il modello non pesa ancora la difficoltà CAI per
  tratto (`TrailSegment.caiScale`), decisione già rimandata in P1.2 — un T si cammina più
  veloce del riferimento medio, un EE/EEA più lento.
- **Ridenominata la formula** nei commenti: non è più "la formula SAC" tal quale (quella
  usa `/2`), ma una variante calibrata sugli stessi riferimenti di velocità con un
  correttivo più leggero — spiegato nel doc di classe di `HikingTimeCalculator`.
- **Aggiornati tutti i test** che usavano `/2` nei numeri attesi (`hiking_time_test.dart`):
  combinato, verticale dominante, i due lati dello split andata/ritorno, il test di
  regressione Alpe Toso (ora attende 2h24 sul caso semplificato D-0, invariato l'assert di
  non-regressione sotto le 3h).
- **Resta da fare**: la difficoltà CAI per tratto come possibile prossimo correttivo, se il
  margine residuo (~15-25%) risultasse fastidioso su altre tracce reali — vedi P1.2 in
  `docs/ROADMAP.md`.

## 12 agosto 2026 — Foto: anteprime alla dimensione dello schermo, precarico, miniature più leggere

**Causa-radice della lentezza** (P1.1 della roadmap): il visualizzatore a schermo intero
caricava l'**originale a piena risoluzione**. `_FullPhotoPage` faceva
`AssetEntity.fromId(...).file` e lo passava a `Image.file` **senza `cacheWidth`**: per gli
scatti di prova (4288×2848, 12,2 MP) sono ~48 MB di bitmap decodificata per riempire un
riquadro che, sullo schermo del simulatore, ne usa ~3,9 MB (1206×801) — **12×** di lavoro
in più a ogni foto, ogni volta che una pagina del `PageView` entrava nell'albero.

Cosa è cambiato:

- **`PhotoLibraryService.preview(id, maxWidth, maxHeight)`** — è la libreria di sistema a
  ridimensionare, non noi dopo aver decodificato tutto. Su iOS serve
  `thumbnailDataWithOption(ThumbnailOption.ios(...))` e **non** `thumbnailDataWithSize`:
  quest'ultima forza `ResizeContentMode.fill`, che **ritaglia** la foto per riempire il
  riquadro (va bene per una miniatura quadrata con `BoxFit.cover`, non per la foto intera).
  `DeliveryMode.highQualityFormat` invece dell'`opportunistic` di default: quello
  consegnerebbe prima una versione degradata, un lampo sfocato a ogni swipe. Su Android
  Glide (`submit(w, h)`, nessuna trasformazione) rimpicciolisce già senza ritagliare.
- **`PhotoLibraryService.originalFile(id)`** — l'originale resta disponibile ma si carica
  **solo sopra 1,6× di zoom** (`TransformationController` + soglia), dove i pixel in più si
  vedono davvero.
- **`PhotoPreviewCache`** (`lib/data/photos/photo_preview_cache.dart`) — LRU di 5 voci con
  deduplica delle richieste in volo e **precarico delle pagine ±1**; si svuota all'uscita
  dal visualizzatore (un'anteprima a piena pagina sono megabyte, non serve a nessun'altra
  schermata). Coperta da test (`test/data/photo_preview_cache_test.dart`): sfratto LRU,
  richieste condivise, errori che non sporcano la cache.
- **`cacheWidth` sulle miniature salvate** (riquadri da 44/52/64 pt): senza, ogni miniatura
  200×200 restava in memoria a piena bitmap anche in un riquadro da 44 pt.
- **Qualità JPEG della miniatura salvata a 80** (il default di `photo_manager` è 100).
  Misurato sul simulatore, 8 foto collegate alla stessa traccia:

  | | miniatura JPEG | JSON traccia (base64) |
  |---|---|---|
  | q100 (prima) | 79,0 KB | 105,5 KB/foto — 843,6 KB in tutto |
  | q80 (ora) | 23,8 KB | 31,9 KB/foto — 255,0 KB in tutto |

  Sono **3,3× di byte in meno** su ogni sincronizzazione iCloud/Drive, invisibili a 200 px.

**Secondo giro, dopo la prova su foto grandi** (l'utente segnala che sul telefono, con
scatti di un iPhone recente, resta un piccolo scatto nello scorrimento e che si aspetta un
indicatore di caricamento):

- **Indicatore di caricamento** al centro mentre l'anteprima arriva, al posto della
  miniatura da 200 px stirata a schermo intero: quella si legge come "foto sgranata", non
  come "sto caricando", e cambiando in corsa faceva l'effetto di un salto di qualità a metà
  swipe. La miniatura salvata resta il ripiego per gli asset **non più sul dispositivo**
  (traccia sincronizzata da un altro telefono), dove nessuna attesa risolverebbe.
- **Decodifica anticipata, non solo byte anticipati.** Il precarico scaricava le anteprime
  vicine ma **nessuno le decodificava**: il lavoro (e lo scatto) si spostava soltanto al
  momento dello swipe. Ora il precarico chiama `precacheImage(MemoryImage(bytes))`, e
  `Image.memory` sugli **stessi byte** ritrova l'immagine già nella `ImageCache` di Flutter.
  Aggiunto anche `allowImplicitScrolling: true` al `PageView`, che costruisce la pagina
  adiacente prima che entri in vista.
- **Zoom con decodifica limitata:** `Image.file(..., cacheWidth: larghezza × dpr × 2,5)`.
  Su uno scatto da 48 MP la decodifica piena sarebbe ~195 MB di bitmap — il salto si
  sentirebbe tutto, ed è esattamente lo scenario del telefono reale.
- Verificato sul simulatore con **6 foto da 48 MP** (8064×6048) generate apposta e aggiunte
  alla libreria, oltre alle 8 da 12 MP: 14 foto sulla stessa traccia, navigazione fluida,
  foto a schermo entro ~250 ms anche saltando da una miniatura all'altra.

⚠️ **`DeliveryMode.highQualityFormat` è obbligatorio, non una preferenza estetica.** Con
`opportunistic` (default) PhotoKit chiama il result handler più volte — prima una versione
degradata, poi quella buona — ma `photo_manager` risponde **solo alla prima** e scarta le
successive: si resterebbe con l'anteprima sfocata per sempre. Il prezzo è che su una foto
ancora solo in **iCloud** (spazio ottimizzato) la risposta arriva dopo il download — il
plugin abilita `networkAccessAllowed` per le thumbnail, quindi la foto arriva, ma può
metterci secondi. È il caso in cui l'indicatore di caricamento serve davvero.

**Smentito un sospetto della roadmap:** la copertina della sessione foto *non* è sgranata —
i riquadri più grandi in cui la miniatura viene mostrata sono 44/52/64 pt (192 px a 3×),
sotto i 200 px salvati. Nessun secondo taglio di miniatura da introdurre.

**Fix di contorno:** la doppia **sottolineatura gialla** di debug su data e "Altitudine" nel
visualizzatore — la rotta è un `PageRouteBuilder` senza `Scaffold`, quindi i testi senza
stile esplicito ereditavano `DefaultTextStyle.fallback`. Risolto con un `Material`
trasparente attorno al corpo della vista.

⚠️ **Nota di metodo (verifica sul simulatore):** i click sintetici (`osascript`) **non**
arrivano né alla vista Mapbox né ai picker di sistema (`UIDocumentPicker`), quindi né
disegnare una traccia né importare un GPX è automatizzabile. Per provare il flusso foto la
traccia è stata scritta **direttamente nel DB** (`track_rows`, con `metrics` non nullo:
senza, "Trova foto vicine" resta disabilitato) e le foto generate con GPS EXIF lungo il
percorso e aggiunte con `xcrun simctl addmedia`. Da lì in poi tutto è UI Flutter, che ai
click risponde.

---

## 29 luglio 2026 — Focus mappa dopo l'import, nome dal file, card Novità

**Il focus sulla traccia importata non è mai partito** (1.0.0+8). Due bug sovrapposti,
trovati solo strumentando il percorso: il primo nascondeva il secondo.

1. **Id sempre `null`.** `_importGpx()` leggeva `tracksProvider.selectedId` per sapere cosa
   inquadrare, ma nella **fase 1** la traccia viene aggiunta alla lista *senza* essere
   selezionata né messa in editing (è scritto nel commento di `importGpx`: esiste "per il
   focus mappa"). `selectedId` era null e `focusTrack` non veniva mai chiamato. Ora si legge
   `importLoadingProvider`, l'unico posto dove quell'id esiste in fase 1.
2. **`flyTo` scartato durante la transizione.** Corretto il punto 1, il log mostrava id,
   listener, traccia e camera **tutti giusti** (`lng 7.965 lat 45.729 zoom 11.14`) e un
   `flyTo` eseguito senza errori — ma la camera letta subito dopo era ancora quella di
   partenza, invariata al decimale. Causa: `ModalRoute.isCurrent` diventa `true` appena il
   `pop` è *avviato*, non a transizione finita. `_importGpx` chiama il focus **dopo** il
   `pop`, quindi cadeva sempre nel ramo "immediato" di `_scheduleFocusTrack` e il volo
   partiva mentre la lista tracce copriva ancora la mappa: con la vista nativa non in
   animazione, un `flyTo` viene **perso** (un `setCamera` istantaneo invece passa — è così
   che la camera era arrivata sul GPS all'avvio).

   Il tap dalla lista tracce funzionava solo per **ordine delle chiamate**: lì il focus è
   prima del `pop`, quindi `isCurrent` era `false` e scattava l'attesa di 350 ms. Una
   guardia che dipende da chi chiama per prima non è una guardia: sostituita da
   `_whenMapInForeground`, agganciata alla `secondaryAnimation` della route della mappa —
   `dismissed` esattamente quando sopra non c'è più nulla, in entrambi gli ordini, senza
   ritardi a tempo da indovinare. Ne beneficia anche `_scheduleFlyToPoint` ("Vedi sulla
   mappa" dal visualizzatore foto), che aveva lo stesso schema fragile.

⚠️ Trappola diagnostica incontrata: `flyTo` **ritorna prima** che l'animazione finisca.
Leggere `getCameraState()` subito dopo dà uno stato intermedio (zoom 14.98 invece di 15.0)
e fa sembrare rotto un volo che sta partendo — serve leggere a volo concluso.

**Nome della traccia importata**: `importGpx` accetta ora `fileName` e gli dà la
**precedenza** sul `<name>` interno al GPX (che resta come ripiego), perché è il nome che
l'utente ha appena letto nel selettore file. Caso limite gestito: un file `.gpx` è tutto
nome, non un'estensione con basename vuoto.

**Card "Novità" al primo avvio dopo un aggiornamento** (`lib/ui/whats_new.dart`): confronta
la build corrente con quella registrata in `shared_preferences` e mostra le novità della
release appena installata. Niente card su **prima installazione** (nessuna build
precedente: non è un aggiornamento). Pesca da `kReleaseNotes` — non è una quarta lista da
mantenere — tramite un campo opzionale `spotlight` (icona + titolo + spiegazione) che serve
solo alla release distribuita; se manca, ripiega sugli `highlights`.

- **Bottom sheet e non card centrata**, a differenza del mockup di riferimento: §7/§10 delle
  linee guida vietano i dialog centrati e una card centrata non esiste altrove nell'app.
  Segnalato all'utente come deroga consapevole al mockup.
- La **build 7 non è mai stata distribuita**: chi aggiorna arriva dalla 6, quindi la
  `spotlight` della 8 copre l'intero salto 6 → 8 ed è l'unica in circolazione (nessun doppio
  elenco che racconta le stesse cose).
- Provata sul simulatore forzando la build precedente nelle preferenze
  (`PlistBuddy -c "Set :flutter.whats_new_seen_build 6"` sul plist del container dati).
  ⚠️ Il container cambia UUID a ogni reinstallazione: dopo un `simctl uninstall` il valore
  va riscritto.

---

## 29 luglio 2026 — Import GPX su iOS: il file .gpx non era selezionabile

Nel selettore file di iOS il tracciato `.gpx` compariva in grigio, non selezionabile. Causa
radice: `openFile` (`file_selector`) su iOS usa `UIDocumentPickerViewController`, che filtra
**solo** per `uniformTypeIdentifiers` — il campo `extensions: ['gpx']` di `XTypeGroup` vale su
desktop e lì viene ignorato. Dei due UTI richiesti in `tracks_list_screen.dart`, nessuno
corrispondeva:
- `com.topografix.gpx` non è un tipo di sistema: esiste solo se un'app installata lo dichiara,
  e nessuna lo faceva;
- `public.xml` neanche, perché iOS deriva l'UTI dall'estensione e `.gpx` non è nel suo
  database — il file finiva classificato `public.data` generico.

**Fix**: `UTImportedTypeDeclarations` in `ios/Runner/Info.plist` — dichiara
`com.topografix.gpx` conforme a `public.xml`, con estensione `gpx` e MIME
`application/gpx+xml`. *Imported* e non *Exported*: il formato non è nostro, lo sappiamo solo
leggere. Il legame Dart↔plist è annotato in `_importGpx()`, perché è il tipo di dipendenza che
si rompe in silenzio.

⚠️ Essendo un cambio nativo, LaunchServices registra i tipi **all'installazione**: serve
disinstallare e reinstallare l'app (`xcrun simctl uninstall` + `flutter run`), un hot restart
non basta.

---

## 29 luglio 2026 — Rifiniture card foto (prima verifica a schermo) e conferme uniformi

Prima sessione con l'app effettivamente in esecuzione sul simulatore dopo le tre voci qui
sotto, tutte marcate "non verificato": revisione a schermo della card foto e delle sheet di
conferma, in due giri di feedback.

**`PhotoDetailCard` ridisegnata** (`draw_route_controls.dart`):
- Non più impilata *sopra* la card traccia in colonna, ma **sovrapposta** e incollata al bordo
  inferiore — `map_gl_screen.dart` avvolge il fondo schermo in uno `Stack`
  (`alignment: bottomCenter`) invece di mettere le due card nella stessa `Column`. Prende il
  posto della card traccia invece di spingerla su. La card si dà da sé il padding di sicurezza
  inferiore (`SafeArea(top: false)`), essendo ora il foglio più in basso quando è a schermo.
- Via l'header "Dettaglio foto" (non aggiungeva informazione): una riga sola — miniatura,
  dati, e a destra le azioni **ridotte a icone** (matita + cestino rosso). Quota e coordinate
  passano su due righe: con le icone accanto, in riga unica le coordinate si troncavano.
- Lo spazio delle vecchie pillole a tutta larghezza ospita ora il **carosello
  dell'escursione**: riuso di `_PhotoFilmstrip` (già scritto per il viewer a schermo intero)
  parametrizzandone i colori — bianco su nero lì, blu accento su superficie chiara qui —
  invece di scriverne un secondo.
- Aprire un dettaglio foto **riduce la card traccia** (listener su `selectedPhotoProvider` in
  `map_gl_screen.dart`, riusa `TrackCardExpanded.collapse()`): sovrapponendosi, con la traccia
  espansa resterebbe nascosta sotto e non si vedrebbe più la mappa.

**Sezione FOTO**: spostata **sotto** il profilo altimetrico (le foto approfondiscono il
percorso già descritto sopra, non sono informazione di pari livello). Tap su un'escursione va
**dritto alla prima foto** in `PhotoDetailCard` — rimosso `_PhotoSessionSheet`, il foglio con
la griglia: era un passaggio in più per la stessa informazione, ora che la card ha già il
carosello del gruppo sotto. ⚠️ L'ordinamento per distanza-lungo-percorso viveva *dentro* quel
foglio: estratto in `_sessionsByDistance()` prima di cancellarlo, così ora vale anche per il
carosello e per la copertina delle righe — "la prima foto" è la prima che si incontra
camminando, non la prima collegata.

**Foto a schermo intero** (`_FullPhotoPage`): era `Center(child: Image.file(file))`, cioè
l'immagine alla sua dimensione **naturale** in mezzo al nero — su scatti piccoli restava
minuscola. Ora `SizedBox.expand` + `BoxFit.contain`. Tolto anche l'`Opacity(0.6)` dal ripiego
a thumbnail: il velo faceva leggere una versione a bassa risoluzione come un errore di
caricamento.

**Chiusura per trascinamento** al posto della × (card traccia e card foto): nuovo
`AppSheetSurface.onDismiss` — la superficie diventa `StatefulWidget` e segue il dito
(`Transform.translate`), chiude oltre 48px o con uno scatto veloce. La presa è il **solo
handle**, non tutta la superficie: la card traccia contiene il grafico del profilo (che
intercetta il trascinamento per muovere il cursore) e il carosello foto, un drag globale se li
mangerebbe. Non attivo durante il **disegno** di una traccia: chiuderla per sbaglio con uno
scorrimento farebbe perdere il percorso in corso, lì si esce da "Annulla" con conferma.

**Conferme uniformate** (`showIosConfirm`, `ios_menu.dart`): erano due voci di menu impilate
(riga rossa + riga "Annulla"), incoerenti con la sheet "Modifica titolo" accanto a cui
comparivano. Ora stessa struttura: header titolo + ×, messaggio, e **una riga** di due bottoni
— "Annulla" terziario a sinistra, conferma **piena** ed espansa fino al bordo destro. Essendo
una funzione condivisa il cambio copre in un colpo tutte e 5 le conferme dell'app (scollega
foto, elimina traccia, annulla modifiche, elimina punto, permesso libreria negato). Rimossi
`_ConfirmHeader`/`_Sep`, ora morti. `showIosMenu` resta a righe impilate: lì le voci sono
*scelte* omogenee, non una coppia conferma/annulla.

⚠️ **Due deroghe consapevoli a `design/DESIGN_GUIDELINES.md`**, entrambe su richiesta
esplicita dell'utente, da riportare nel documento se confermate:
- §4 "niente bottoni pieni rossi" — la conferma distruttiva è ora piena rossa, per coerenza di
  impaginato con il pieno blu "Salva" di "Modifica titolo".
- §5 non prevede un icon-button distruttivo — aggiunto `AppIconButton.tint`, documentato come
  eccezione per le sole azioni distruttive senza etichetta (lo stato *attivo* resta blu, §10).

Test: aggiornati i 4 di `draw_route_controls_test.dart` che cercavano le etichette testuali
delle azioni foto (ora tooltip) e il foglio-griglia dell'escursione (ora rimosso).

---

## 28 luglio 2026 — Tolta la mini-mappa dal viewer foto, aggiunto "Vedi sulla mappa"

Seguito della voce sotto (pannello Altitudine/Mappa): la mini-mappa Mapbox era stata segnalata
esplicitamente come la parte a rischio più alto (API `mapbox_maps_flutter` usate senza un
precedente già collaudato nel codebase) — rimossa su richiesta prima ancora di arrivare al
test su device, non serve tenersi debito rischioso "per dopo".

**`PhotoLocationPanel` semplificato**: via il selettore a due schede (`_TabSelector`), via
`_PhotoMapPreview` e la seconda istanza Mapbox, via l'import di `mapbox_maps_flutter`/
`latlong2` nel file. Resta solo un tasto — riga "Altitudine" + chevron, **stessa convenzione
di espandi/riduci già in uso nell'app** (`AppSheetHeader`, sezione FOTO della card: chevron
down quando espanso, chevron up quando ridotto) — che mostra/nasconde il profilo altimetrico
col punto di scatto evidenziato (riuso di `ElevationProfileChart.cursor`, invariato dalla
versione precedente). `lib/features/map_gl/map_style.dart` (estratto per la mini-mappa)
resta: è usato comunque da `map_gl_screen.dart` dopo quella pulizia, non è tornato codice morto.

**Nuovo: "Vedi sulla mappa"** (icona `location` in `_FullPhotoTopBar`, tra titolo e Modifica):
chiude il visualizzatore, centra la mappa principale sul punto di scatto e riduce la card
traccia — valutato prima di implementare (richiesta esplicita: procedere solo se facilmente
realizzabile e coerente), risultato fattibile riusando quasi di peso un pattern già
collaudato nel codebase:
- **Nuovo provider** `mapFlyToPointProvider`/`MapFlyToTarget` (`lib/features/map/
  map_providers.dart`), stesso schema di `mapFocusProvider`/`MapFocusTarget` già esistente
  (usato dalla lista tracce per centrare su una traccia) ma per un singolo punto a zoom fisso
  invece dei bounds di un'intera traccia.
- **`map_gl_screen.dart`**: nuovo listener + `_scheduleFlyToPoint`/`_flyToPoint`, ricalcati su
  `_scheduleFocusTrack`/`_focusTrack` esistenti (stesso differimento di 350ms se la route non
  è ancora quella in primo piano — il visualizzatore foto sta ancora facendo il pop).
- **`TrackCardExpanded`** (`route_editor_provider.dart`): aggiunto `collapse()` accanto al
  `toggle()` già esistente — serviva un'operazione idempotente ("riduci sempre", non
  "inverti") per non rischiare di espandere la card per errore se era già ridotta.
- **Nessun'altra azione da coordinare per il thumbnail**: `selectedPhotoProvider` non viene
  toccato da "Vedi sulla mappa" (resta quello impostato quando si è aperta la foto), quindi al
  pop del visualizzatore `PhotoDetailCard` con la thumbnail ricompare da sola sopra la card
  ora ridotta — comportamento già esistente, non serviva replicarlo.

⚠️ Non verificato su device/simulatore, ma rischio più contenuto della mini-mappa rimossa: le
API di `MapFocus`/`flyTo`/`cameraForCoordinatesPadding` riusate qui erano già in produzione
nel codebase per il caso "lista tracce → centra mappa".

---

## 28 luglio 2026 — Pannello Altitudine/Mappa nel viewer foto, rimossi i pin dal grafico in card

**Rimossi i pin foto dal profilo altimetrico della card traccia** (`troppa confusione` con
molte foto collegate): `ElevationProfileChart` non riceve più `photos`/`onPhotoTap`/
`highlightedPhotoId` dalla card (`draw_route_controls.dart`, `_SelectedBody`) — anche tutta
la logica che calcolava quale foto evidenziare (priorità selezione > cursore, tolleranza 50m)
è stata rimossa, non più usata da nessuno. Pulizia a cascata in `elevation_profile_chart.dart`:
tolti da `ElevationProfileChart`/`_ProfilePainter` i parametri `photos`/`onPhotoTap`/
`highlightedPhotoId`, `_photoAt`, `_chartHeight` e il blocco di disegno dei pin — confermato
con grep che `ElevationProfileChart` non ha altri call site in tutto il repo, quindi nessuna
funzionalità residua da preservare. Anche 2 test in `draw_route_controls_test.dart` che
verificavano l'evidenziazione dei pin sono stati rimossi (testavano un comportamento voluto
rimosso, non un bug).

**Nuovo pannello "Altitudine/Mappa" nel visualizzatore foto a schermo intero** (come Komoot,
da screenshot dell'utente), sotto il filmstrip: `PhotoLocationPanel`
(`lib/features/draw_route/photo_location_panel.dart`, nuovo file — `draw_route_controls.dart`
era già grande). Un selettore a due pillole sceglie fra:
- **Altitudine**: `ElevationProfileChart` col punto di scatto della foto evidenziato via
  `cursor` (non più via `photos`, rimosso sopra) — riuso diretto, nessuna modifica al
  componente per questo. Card bianca con tema forzato `AppTheme.light()` (il grafico è
  calibrato per stare su sfondo chiaro, non per il nero della galleria).
- **Mappa**: mini-mappa Mapbox **sola lettura** (gesti disabilitati: competerebbero con lo
  swipe orizzontale del carosello) col tracciato e un pin nel punto di scatto. Stile
  chiaro/scuro coordinato con `Theme.of(context).brightness`. Istanza Mapbox **separata** da
  quella della schermata principale (prima volta nel progetto con 2 `MapWidget` vivi insieme).
  Estratti gli URI di stile (`outdoorsMapStyleUri`/`darkMapStyleUri`/`satelliteMapStyleUri`,
  prima privati in `map_gl_screen.dart`) in un nuovo `lib/features/map_gl/map_style.dart`
  condiviso, per non duplicare le costanti Mapbox tra i due file.
- **Lazy loading della mappa**: creare una seconda istanza Mapbox è costoso (rete/GL) — non
  costruita finché l'utente non tocca "Mappa" la prima volta, poi tenuta viva con `Offstage`
  (non uno switch condizionale) ai toggle successivi, per non ripagare il costo ad ogni tap.
- **Marker che segue il carosello**: siccome lo stato del pannello/della mini-mappa **non**
  viene ricreato scorrendo tra le foto (stessa posizione nell'albero, `Offstage` non elimina
  lo `State`), il marker va spostato esplicitamente in `didUpdateWidget` (`CircleAnnotation
  .geometry` riassegnato + `manager.update(...)`) invece di ricreare tutta la mappa — altrimenti
  sarebbe rimasto fermo sulla prima foto aperta.

⚠️ **Rischio più alto di questa sessione**: la mini-mappa è la parte meno verificabile senza
device/simulatore — API `GesturesSettings`/`ScaleBarSettings`/`CircleAnnotationManager.update`
usate da conoscenza generale dell'SDK `mapbox_maps_flutter` 2.25, non da un precedente già
presente nel codebase (a differenza di `CompassSettings`/`PolylineAnnotationOptions`/
`cameraForCoordinatesPadding`, questi sì già usati altrove e quindi a rischio più basso). Da
verificare per primo appena disponibile un ambiente Flutter.

---

## 28 luglio 2026 — Rifiniture grafiche: card ancorate, viewer foto a galleria, fix bug

**Card ancorate in basso, non più fluttuanti**: `DrawRouteControls` (selezione **e**
modifica — condividono lo stesso wrapper) e `PhotoDetailCard` passano da `AppSheetSurface
(floating: true)` con margine su tutti i lati a `floating: false`, a tutta larghezza, angoli
arrotondati solo sopra — stesso trattamento dei fogli modali (legenda/changelog/tema).
`map_gl_screen.dart`: la `SafeArea` che avvolge la colonna in basso ora passa `bottom:
!showCard`, così quando la card è a schermo lei (e l'eventuale `PhotoDetailCard` sopra)
toccano il vero bordo inferiore invece di fermarsi al di sopra del padding di sicurezza;
`DrawRouteControls` riapplica quel padding solo al proprio contenuto con un
`SafeArea(top: false)` interno (stesso schema di `showAppBottomSheet`).

**Viewer foto a schermo intero in stile "galleria"** (`openFullPhoto`/`_FullPhotoView`,
riscritti): prima era una singola immagine statica con solo una × in alto a sinistra. Ora:
titolo (o data come fallback) in alto con Modifica titolo/Scollega; `PageView` centrale che
scorre tra **tutte le foto della stessa escursione** (non solo quella toccata), calcolata al
volo con `PhotoSessionGrouper`; filmstrip in basso (tap per saltare a una foto, si scrolla da
sé su quella corrente); chiusura sia con la × sia trascinando l'immagine verso il basso
(l'opacità dello sfondo segue il trascinamento, rilascio oltre soglia chiude). Ogni pagina
risolve il proprio asset dalla libreria in modo indipendente, con la thumbnail salvata come
fallback onesto se l'originale non risolve più. Nota aperta: lo swipe-to-dismiss verticale
può competere con lo zoom/pan dell'`InteractiveViewer` quando l'immagine è ingrandita — non
verificato su device reale, da rifinire se risulta fastidioso in pratica.

**Fix "Modifica titolo" che sembrava non aprire il campo di testo**: l'unica differenza
strutturale rispetto al campo nome-traccia (che invece funzionava) era `autofocus: true` sul
`CupertinoTextField` dentro un `showModalBottomSheet` — pattern noto per gareggiare con
l'animazione di apertura dello sheet e perdere il focus/la tastiera. Sostituito con un
`FocusNode` esplicito + `requestFocus()` in un `addPostFrameCallback` (a sheet già montato).
Non riproducibile in questo ambiente (nessun device/simulatore disponibile): diagnosi basata
sul pattern noto e sulla differenza col campo che funzionava, da confermare sul device.

**Fix: chiudere la card traccia lascia orfana la card foto**: aprire una foto (pin mappa o
dal foglio di un'escursione) mostra `PhotoDetailCard` sopra `DrawRouteControls`, ma chiudere
la traccia (× o fine disegno) non azzerava `selectedPhotoProvider` → la card foto restava a
schermo da sola, senza senso. `map_gl_screen.dart`: il listener su `showCard` ora chiama
`selectedPhotoProvider.notifier.clear()` quando passa a `false`.

**Debito di test scoperto e sistemato**: la sostituzione della striscia orizzontale con la
sezione "FOTO" a gruppi (voce sotto) aveva rotto 3 test in `draw_route_controls_test.dart`
che non erano stati verificati in quella sessione (nessun `flutter test` disponibile in
questo ambiente) — testavano l'evidenziazione a bordo colorato della vecchia striscia durante
lo scrubbing, l'ordine delle thumbnail per tap diretto su icona, e l'apertura della card foto
da una thumbnail sempre visibile. Riscritti sulla via attuale (espandi sezione → tap
escursione → tap nella griglia del foglio) più uno spostato a verificare `highlightedPhotoId`
di `ElevationProfileChart` invece del bordo della striscia (rimossa). Aggiunto anche
l'ordinamento per distanza-lungo-percorso delle foto **dentro** ciascun foglio-escursione
(mancava: `PhotoSessionGrouper` raggruppa per data, non riordina per distanza), che uno dei
test riscritti verifica.

⚠️ **Nessuna di queste modifiche è stata verificata su device/simulatore** (Flutter SDK non
disponibile in questo ambiente): solo lettura attenta del codice e bilanciamento
parentesi/graffe. Da controllare a schermo prima di considerarle definitive, in particolare
il gesto di swipe-to-dismiss e il comportamento del `FocusNode` sul campo titolo.

---

## 28 luglio 2026 — Sezione "FOTO" a gruppi nella card traccia (redesign UX)

**Perché**: con il fix del cap di scansione (voce sotto), "Trova foto" ora restituisce
correttamente tutte le foto vicine al percorso — ma per una traccia percorsa più volte negli
anni, la vecchia striscia orizzontale (`_PhotoStrip`) le mostrava tutte mischiate, senza modo
di distinguere a quale escursione appartenesse ciascuna. Serviva un raggruppamento.

**Nuovo modello/servizio di dominio** (puri, testati, nessuna dipendenza da UI — §9):
- `PhotoSession` (`lib/domain/models/photo_session.dart`): un gruppo di `TrackPhoto` più una
  data rappresentativa (`null` se nessuna foto del gruppo ha `takenAt`).
- `PhotoSessionGrouper` (`lib/domain/services/photo_session_grouper.dart`): raggruppa le foto
  di una traccia per "escursione" deducendola dai timestamp EXIF (non esiste un concetto
  esplicito di "visita" sulla traccia, vedi domanda aperta #1 in `docs/eval-photo-sync.md`).
  Gap massimo tra scatti consecutivi = **30h** (non 24h, per non spezzare in due un'uscita con
  pernottamento in bivacco/rifugio solo perché attraversa la mezzanotte). Le foto senza data
  finiscono in un unico gruppo finale (`date: null`), non una ciascuna. Test:
  `test/domain/photo_session_grouper_test.dart`.
- `Format.longDate` (`lib/core/util/format.dart`): data in italiano esteso ("18 agosto 2025"),
  nomi mese hardcoded come il resto del progetto (nessuna dipendenza `intl` mai aggiunta).

**UI** (`lib/features/draw_route/draw_route_controls.dart`): `_PhotoStrip` rimossa e sostituita
da `_PhotoSection`, collassata di default:
- Intestazione "FOTO · N FOTO" (tap per espandere/riducere) + pulsante "+" (avvia "Trova foto
  vicine", spostato qui dalla riga strumenti in alto — non più ridondante in due posti).
- **Traccia senza foto**: l'intestazione diventa "Nessuna foto collegata" senza conteggio né
  freccia (niente da espandere), ma il "+" resta sempre presente e attivo — altrimenti non ci
  sarebbe più alcun modo di avviare la prima ricerca foto su una traccia.
- **Espansa**: una riga per escursione (`_PhotoSessionRow`, copertina + titolo con data +
  conteggio + freccia), tap → foglio con la griglia delle foto del gruppo
  (`_PhotoSessionSheet`); tap su una foto nel foglio apre `PhotoDetailCard` come già avveniva
  dalla vecchia striscia.
- **Non toccato**: i pin foto sul grafico del profilo altimetrico (`ElevationProfileChart`) e
  l'evidenziazione durante lo scrubbing — restano l'unico punto di ingresso "spaziale" alle
  foto, la nuova sezione è quello "per data/escursione". Persa l'auto-scroll-to-thumbnail della
  vecchia striscia durante lo scrubbing (non aveva un equivalente sensato nella vista a gruppi).

---

## 28 luglio 2026 — Fix "Trova foto" che non trovava nessuna foto

**Causa radice**: `PhotoManagerLibraryService.photoLocations()` limitava la scansione alle
`_maxAssetsScanned = 3000` foto più recenti dell'intera libreria (ordinamento per data di
scatto decrescente, nessun filtro data passato dalla UI). Per un utente con più di 3000 foto
scattate *dopo* un'escursione, le foto dell'escursione restavano fuori dalla finestra
scandita e non arrivavano mai al matcher spaziale — zero risultati nonostante permesso pieno
e foto con GPS valido. Segnalato dallo sviluppatore dopo il rilascio di stamattina: traccia
percorsa più volte, "Trova foto" restituiva sempre 0 foto.

**Fix**: rimosso il tetto — `photoLocations()` ora scandisce l'intera libreria, in blocchi da
500 asset (`_batchSize`) con le chiamate `latlngAsync()` di ogni blocco in parallelo
(`Future.wait`), per restare comunque ragionevole su librerie molto grandi senza bloccare
l'esecuzione su un singolo asset lento. File: `lib/data/photos/photo_manager_library_service.dart`.

**UX**: `findNearbyPhotos` (`lib/features/draw_route/nearby_photos_action.dart`) già
escludeva dall'elenco le foto già collegate alla traccia (`alreadyLinked`), ma mostrava lo
stesso messaggio generico "Nessuna foto trovata" sia quando non c'era nessuna foto vicina sia
quando ce n'erano ma erano già tutte collegate — messaggio ora distinto ("Le foto vicine a
questo percorso sono già tutte collegate").

**Verificato ma non un bug**: foto senza coordinate GPS nell'EXIF vengono scartate a monte
(comportamento voluto, non tutte le foto hanno il tag posizione). Foto iCloud "ottimizzate"
(non scaricate per intero sul device, solo proxy locale): la posizione GPS è metadato del
database Foto, disponibile anche per asset non scaricati — dovrebbero quindi essere trovate
comunque; da confermare con un test reale su un asset in questo stato. Su Android, foto
"liberate" da Google Photos (originale rimosso dal device dopo il backup) escono dal
`MediaStore` e non sono raggiungibili da `photo_manager` — limite di piattaforma, nessuna
soluzione lato app senza integrare l'API Google Photos (già scartata in
`docs/eval-photo-sync.md` per altri motivi).

**Fuori scope di questo fix** (rimandato: se ne occupa lo sviluppatore con istruzioni
dedicate): redesign della UI di ricerca per il caso "stessa traccia percorsa più volte" (oggi
tutte le foto di tutte le occasioni compaiono mischiate in un'unica griglia) — vedi domanda
aperta #1 in `docs/eval-photo-sync.md`.

---

## 28 luglio 2026 — Fix overflow testo bottoni compressi + icona ripidità (confluito in `1.0.0+6`)

Regressione dal round di rifiniture precedente: nella barra del punto selezionato
(`_SelectedWaypointBar`), "Aggiungi punto prima" e "Elimina" sono due `AppButton` avvolti
ciascuno in un `Expanded` (per dividersi la riga a metà). `AppButton` renderizzava
l'etichetta con un `Text` nudo dentro una `Row` — in una `Row`, un figlio non-flex riceve
larghezza principale **non vincolata**, quindi il testo si dimensiona alla sua larghezza
naturale su una riga sola: se più largo dello spazio compresso dall'`Expanded` esterno, il
risultato è un overflow orizzontale (visibile in debug come banda gialla/nera "RIGHT
OVERFLOWED BY N PIXELS"), non un a-capo automatico. Fix: l'etichetta è ora dentro un
`Flexible` (`maxLines: 2`, `overflow: TextOverflow.ellipsis` come rete di sicurezza) — va a
capo su due righe quando il bottone è compresso, il pulsante cresce in altezza
(`minimumSize` è un minimo, non un massimo) invece di traboccare in larghezza.

Icona "Colori dislivelli": il pennello scelto nel round precedente (per liberare
`graph_square`, passata al profilo altimetrico) non comunicava il concetto giusto — il
bottone non riguarda "il colore" in sé ma l'**intensità/difficoltà della pendenza**. Sostituito
con `CupertinoIcons.flame`.

---

## 28 luglio 2026 — Rifiniture redesign: bordi, margini, icone, sotto-menu incollati in basso (confluito in `1.0.0+6`)

Seguito diretto del redesign completo sotto, con feedback puntuale dell'utente su uno
screenshot della card foto + card traccia impilate:

- **`AppSheetSurface`** (`app_bottom_sheet.dart`): nuovo flag `floating` — di default `false`
  (bottom sheet vere, a filo del bordo inferiore, angoli arrotondati solo sopra); `true` per
  le card **fluttuanti** sopra la mappa con un margine tutto attorno (card traccia/foto:
  `DrawRouteControls`, `PhotoDetailCard`), che ora arrotondano tutti e 4 gli angoli — prima
  ereditavano lo stesso taglio "sheet vera" (fondo squadrato) pur non essendo a filo schermo,
  quindi il fondo squadrato "galleggiava" in modo innaturale sopra la mappa. Ombra anche
  differenziata: verso l'alto per le sheet vere (l'unico lato visibile), centrata per le card
  fluttuanti (visibile su tutti i lati).
- `PhotoDetailCard`: thumbnail 88px → 64px (bumped a 88 nella sessione precedente, feedback
  esplicito "troppo grande").
- `_SelectedBody` (card traccia): margine 6px aggiunto tra tutti gli icon-button della riga
  azioni — "Trova foto vicine"/"Modifica"/"Salva offline" erano attaccati senza `SizedBox` di
  separazione (l'unico gap esistente era tra le prime due icone a sinistra).
- Icona "Profilo altimetrico": `CupertinoIcons.waveform_path` (introdotta nella sessione
  precedente per sostituire la vecchia pillola "Percorso") → `CupertinoIcons.graph_square`
  ("meglio un'icona di un grafico a linee", feedback utente). "Colori dislivelli" liberata su
  `CupertinoIcons.paintbrush` per non avere due bottoni con la stessa icona nella stessa riga.

**Unificazione di tutti i sotto-menu di azione come bottom sheet incollate al bordo
inferiore** — richiesta esplicita e generale ("tutti i sotto-menu... non solo quello"),
prendendo la sheet "Selezione tema" (già così) come riferimento:

- `ios_menu.dart` (`showIosMenu`/`showIosConfirm`): riscritto da zero. Prima: popup
  posizionato vicino al punto di tocco (via `anchorContext`, con logica di apertura sopra/
  sotto in base allo spazio disponibile) per i menu, dialog centrato con `BackdropFilter`
  proprio per le conferme — due meccanismi diversi, nessuno dei due una vera bottom sheet.
  Ora entrambi passano da `showAppBottomSheet` (stesso `AppSheetSurface` di ogni altro
  pannello), con un titolo opzionale in testa. `showIosMenu` non richiede più
  `anchorContext` — i 2 call site in `tracks_list_screen.dart` ("Ordina per", "Azioni
  traccia") non hanno più bisogno del wrapper `Builder` per catturare un `BuildContext`
  ancora, e ora mostrano un titolo (rispettivamente "Ordina per" e il nome della traccia).
- `showAppBottomSheet` (`app_bottom_sheet.dart`): aggiunto un parametro `padding` (default
  invariato, `EdgeInsets.fromLTRB(20,0,20,14)`) — i menu/conferme di `ios_menu.dart` passano
  `EdgeInsets.zero` e gestiscono da sé il padding orizzontale di titolo/righe, per poter
  disegnare righe e divisori a tutta larghezza (stile action sheet nativo), diversamente
  dalle sheet "a modulo" (impostazioni avanzate, selezione tema) che hanno contenuto sempre
  inset di 20px.
- `nearby_photos_action.dart` (`_NearbyPhotosSheet`, "Trova foto vicine"): passata da
  `GlassSurface` (ultimo angolo ancora "vetro" dell'app, con `showCupertinoModalPopup`) a
  `AppSheetSurface`/`AppSheetHeader`/`AppButton` via `showAppBottomSheet` — non era tra le 9
  schermate esplicitamente coperte dai mockup, ma lasciarla "vetro" in mezzo a un'app ormai
  tutta opaca sarebbe stata l'incoerenza più vistosa rimasta, aperta proprio dal bottone
  "Trova foto vicine" appena ridisegnato.

**Deliberatamente non toccati** (non sono menu/scelte d'azione): `legends.dart`/
`release_notes.dart` (sheet informative, già bottom sheet con chrome ragionevolmente
coerente) e `ios_progress.dart` (overlay di attesa/spinner, nessuna scelta da fare).

Test: nessuna asserzione rotta (icone/testo dei menu non erano coperte da test dedicati);
verificato con `flutter analyze` + `flutter test` (122 test) dopo ogni blocco di modifiche.

---

## 28 luglio 2026 — Redesign grafico completo secondo `design/DESIGN_GUIDELINES.md` (confluito in `1.0.0+6`)

L'utente ha preparato un intero sistema di design (`design/DESIGN_GUIDELINES.md` + 9
mockup PNG, non versionati) partendo dalla revisione grafica di un prototipo HTML di
riferimento (`Sentei Redesign.dc.html`, non incluso nel repo — solo riferimento visivo,
ricostruito qui in widget Flutter). Cambio radicale rispetto al linguaggio "vetro
smerigliato" usato finora: superfici **opache**, un solo sistema di bottoni, badge di
difficoltà/tag sentiero con forme sempre distinte, bottom sheet come unico pattern modale.

**Decisioni chiarite con l'utente prima di scrivere codice** (`AskUserQuestion`, entrambe le
opzioni consigliate scelte):
1. **Dark mode** — le linee guida coprono solo il tema chiaro; le 3 varianti scure esistenti
   (`AppPalette.darkStandard/darkNight/darkOled`) **mantengono i loro colori attuali**
   (incluso l'accento ambra di `darkNight`), il nuovo sistema si applica solo come
   *struttura* (bottom sheet, forma bottoni/badge) sopra quei colori.
2. **Vetro → opaco** — le card/sheet delle schermate coperte diventano completamente opache
   (niente `BackdropFilter`/blur), coerente con tutti i mockup. La chrome di navigazione
   (menubar/ricerca/controlli mappa/punto ispezionato in esplorazione) **non è coperta** da
   nessun mockup esplicito e resta invariata (vecchio linguaggio `GlassSurface`).

Salvato l'intento e le decisioni in memoria di progetto
(`sentei-design-guidelines-2026`) per le sessioni future.

### Nuovi widget condivisi (`lib/ui/`)

- **`app_buttons.dart`** — `AppButton` (4 varianti: primario pieno, secondario bordato,
  testo, distruttivo bordato — stessa altezza 48px, stesso raggio pill) e `AppIconButton`
  (icon-button circolare 44px, sfondo neutro di default / tinta d'accento se `active`).
  Formalizza esplicitamente la regola a due livelli già introdotta in sessione precedente
  (icone nude per righe dense da 3+ azioni, pillole con testo per righe da 1-2) — ora come
  commento sui widget condivisi invece che sulle classi private di `draw_route_controls.dart`.
- **`app_bottom_sheet.dart`** — `AppSheetSurface` (superficie opaca, handle 36×5px, angoli
  superiori r22, ombra) + `AppSheetHeader` (titolo + chevron opzionale + × 36px, più uno slot
  `trailing` per casi come la quota nella barra del punto selezionato) + `showAppBottomSheet`
  (wrapper di `showModalBottomSheet` con backdrop nero ~45%) — un solo meccanismo per tutti i
  pannelli modali, sheet persistenti (card traccia, non è una route) inclusi.
- **`badges.dart`** — `AppDifficultyBadge` (rettangolo r9, sfondo pieno colore, testo bianco)
  e `AppTrailTag` (pill, sfondo bianco/superficie, bordo `borderDivider`) — forme sempre
  distinte, mai per colore casuale (prima erano entrambi `Chip`/container ad-hoc).

### Token (`lib/ui/tokens.dart`, `lib/ui/cai_difficulty.dart`)

- Blu di brand aggiornato `#1565C0` → `#0071E0` (+ `primaryPressed` `#0058C4`).
- `AppColors.destructive` **unificato** al rosso della scala CAI `EEA`
  (`AppDifficultyColors.eea`, `#CC3336`) invece del vecchio *systemRed* iOS indipendente — un
  solo rosso "attenzione/distruttivo/dislivello negativo" in tutta l'app, coerente con la
  tabella colori delle linee guida (`difficulty.EEA` è esplicitamente anche "distruttivo").
- Nuova palette `AppDifficultyColors` (T/E/EE/EEA): `caiScaleColor` in `cai_difficulty.dart`
  ora la usa. **"E" non è più blu** (`#1565C0`, lo stesso del brand — ambiguo con lo stato
  attivo) ma teal (`#009192`).
- Nuovi campi `AppPalette.borderDivider`/`iconBgNeutral` per variante di tema: valori nuovi
  in `light` (`#E2E1DD`/`#F1F0EC` dalle linee guida), **derivati** per le 3 varianti scure
  (nessun valore specificato dalle linee guida, che coprono solo il chiaro — scelte in modo
  da restare "flat" e coerenti con i toni già esistenti di ciascuna variante).
- `scaffoldBg` chiaro `#F2F2F7` → `#F5F3EF` (`bg.app` delle linee guida).

### Schermate aggiornate

- **Card percorso/traccia selezionata** (`draw_route_controls.dart`, `_SelectedBody`):
  `GlassSurface` → `AppSheetSurface`; header con `AppSheetHeader` (chevron riduci/espandi +
  ×); riga azioni con `AppIconButton`; `_TrailInfo` con `AppTrailTag`/`AppDifficultyBadge`;
  D+/D- con icone Cupertino diagonali (`arrow_up_right`/`arrow_down_right`) invece di
  `Icons.trending_up/down` (Material) e colori `AppDifficultyColors.t/eea` invece di verde/
  rosso indipendenti; icona/testo della distanza non più tinti d'accento (il blu è riservato
  ad azioni/stati attivi, non ai dati).
- **Card foto** (`PhotoDetailCard`): superficie opaca, header con titolo statico "Dettaglio
  foto" (prima il titolo/data della foto faceva anche da header) + ×; **bug fix**: quando non
  c'è un titolo personalizzato, la data/ora non compare più due volte (una come titolo-
  fallback, una come riga a sé) — ora una singola volta; bottoni "Modifica titolo"/"Scollega"
  con `AppButton` (secondario/distruttivo) invece di pillole locali.
- **"Modifica titolo" foto**: da dialog centrato (`showGeneralDialog`) a vera bottom sheet
  (`showAppBottomSheet`) — l'esempio esplicitamente citato dalle linee guida (§10) da
  convertire.
- **Edit percorso** (`_DrawingBody`): footer con `AppIconButton` (annulla/undo) + `AppButton`
  primario espanso per "Salva" (prima pillola a larghezza fissa); riga "Impostazioni
  avanzate" ora su una barra piena (sfondo `hairline@10%`, non più testo nudo con icona).
- **Impostazioni avanzate traccia**: sheet convertita a `showAppBottomSheet` +
  `AppSheetHeader`; **color swatch** ridisegnato — il selezionato ha un anello d'accento e
  una spunta bianca sopra la tinta, gli altri sono cerchi pieni senza contorno (prima: tutti
  con un anello, quello attivo solo più spesso — ambiguo); switch "Segui i sentieri" blu
  (`activeTrackColor: palette.accent`) invece del verde di sistema di default.
- **Impostazioni** (`settings_screen.dart`): nuovo `_SettingsIcon` (contenitore icona
  uniforme, quadrato arrotondato 30×30 r8, sfondo tinta d'accento — rosso solo per
  "Disconnetti") su tutte le righe. Selezione tema/variante scura: da menu ancorato
  (`showIosMenu`, popup posizionato accanto al tap) a bottom sheet dedicata
  (`_SelectionSheet<T>`, generica su `AppThemeMode`/`AppDarkVariant`) con righe testo e
  spunta sul valore corrente.
- **Elenco tracciati** (`tracks_list_screen.dart`): pallino colore tracciato 16px → 13px
  (spec §6, "12–13px"); pulsante "altre azioni" da icona nuda `ellipsis_circle` a
  `AppIconButton` (cerchio neutro).

**Deliberatamente fuori scope** (nessun mockup li copre esplicitamente): i menu "Ordina"/
"Azioni traccia" e le conferme di eliminazione restano sul componente condiviso
`ios_menu.dart` (popup ancorato / dialog centrato) — usato in decine di altri punti dell'app
non toccati da questo redesign; convertirlo a bottom sheet avrebbe un raggio d'impatto molto
più ampio delle 9 schermate coperte dalle linee guida.

Test: aggiornati i finder che assumevano la vecchia struttura in
`draw_route_controls_test.dart` (icona rimossa da "Impostazioni avanzate" collassata,
`CupertinoIcons.xmark` invece di `clear_circled_solid` per la ×, testo "COLORE" maiuscolo
nello sheet, asserzioni `GlassSurface`/opacità sostituite con `AppSheetSurface`, doppia
data/ora nella card foto corretta a singola). Nessuna modifica ai test di
`settings_appearance_test.dart` (già indipendenti dal meccanismo di menu/sheet sottostante).

---

## 27 luglio 2026 — Regola a due livelli per le azioni delle card: pillola vs icona (confluito in `1.0.0+6`)

Domanda diretta dell'utente su uno screenshot con card foto + card traccia affiancate: "sono
coerenti tutti i bottoni?" — la risposta onesta, dopo lettura del codice, era no. La riga azioni
della card traccia (`_SelectedBody`) mescolava `_PillAction` "Percorso" (icona+testo+sfondo) con
4 `_CardIconButton` icon-only (Colori dislivelli, Trova foto vicine, Modifica, Salva offline);
`_SelectedWaypointBar`, `PhotoDetailCard` e `_NearbyPhotosSheet` invece usano solo `_PillAction`.
Nessun commento nel codice spiegava perché — le 4 icone erano finite icon-only una alla volta,
in round diversi di feedback (audit coerenza grafica, foto lungo il percorso), senza rivalutare
la riga nel suo insieme.

Chiarito con l'utente (via `AskUserQuestion`, opzioni con preview ASCII delle 3 alternative) che
la scelta preferita è formalizzare **due livelli** invece di uniformare tutto a un solo stile:
righe con **3+ azioni** (card traccia: 5 azioni in una riga) restano icon-only — con
testo+sfondo per ognuna andrebbe fuori schermo o su due righe; righe con **1-2 azioni** (punto
selezionato, card foto, foto vicine) restano a pillole con label, più leggibili quando c'è
spazio. Regola scritta come commento su entrambe le classi (`_CardIconButton`, `_PillAction`,
`draw_route_controls.dart`) così il criterio resta esplicito per le prossime azioni aggiunte.

Applicata la regola al caso concreto che l'aveva rotta: "Percorso" (toggle apertura/chiusura
del grafico altimetrico) non è più una `_PillAction` ma un `_CardIconButton` con icona fissa
`CupertinoIcons.waveform_path` e stato `active: showingChart` — stesso linguaggio di "Colori
dislivelli" accanto (icona fissa + pastiglia tinta quando attivo), invece del testo + chevron
direzionale che aveva prima.

Test: sostituiti i `find.text('Percorso')` con `find.byTooltip('Profilo altimetrico')` in
`draw_route_controls_test.dart` (3 asserzioni: apertura grafico, card ridotta/espansa).

---

## 27 luglio 2026 — Token `contentGlassOpacity`/`contentGlassBlur`, card più trasparenti (confluito in `1.0.0+6`)

Seguito diretto dell'audit di coerenza grafica sotto: l'utente ha chiesto più trasparenza per
`DrawRouteControls`/`PhotoDetailCard` (che l'audit aveva appena reso coerenti a 0.92/30, un
valore isolato senza un token dedicato) e per `_PointInfoCard` (punto selezionato fuori
dall'editing). Prima di implementare, chiarito con l'utente (frase ambigua "trasparenza/opacità
in più") che l'intento era **abbassare** il valore di opacità, non alzarlo.

Aggiunta una seconda coppia di token in `AppPalette` (`lib/ui/tokens.dart`):
`contentGlassOpacity`/`contentGlassBlur` (default 0.85/30), distinta da `glassOpacity`/
`glassBlur` già esistente per la chrome di navigazione (menubar, controlli laterali, ricerca).
Aggiornati i 4 call site che avevano il vecchio valore hardcoded 0.92/30:
`DrawRouteControls` e `PhotoDetailCard` (`draw_route_controls.dart`), `_ImportLoadingCard`
(`map_gl_screen.dart`), `_NearbyPhotosSheet` (`nearby_photos_action.dart`). `darkOled` imposta
esplicitamente `contentGlassOpacity/Blur` a 0.98/0, stesso valore "flat, senza blur" già usato
per la chrome in quella variante (coerente con l'intento "risparmio energetico" del tema).

`_PointInfoCard` non condivide il tier "contenuto" (leggibilità dati non prioritaria quanto
traccia/foto): opacità impostata a `palette.glassOpacity - 0.08` (clampata), relativa così da
restare coerente se in futuro `glassOpacity` cambiasse per variante di tema.

Test: aggiornate le due asserzioni di opacità in `draw_route_controls_test.dart` da `0.92`
letterale a `AppPalette.light.contentGlassOpacity`, per non irrigidire il test su un valore che
può cambiare.

---

## 27 luglio 2026 — Audit coerenza grafica (opacità, icone, pesi visivi) (confluito in `1.0.0+6`)

Prima revisione grafica trasversale dell'app (non un fix puntuale come le voci precedenti):
partita da 4 problemi concreti indicati su uno screenshot (card foto vs card traccia con
opacità diverse, X di chiusura con pesi diversi, icona "Modifica" non allineata alle altre,
chevron riduci/espandi più opaco della X adiacente), estesa a una ricognizione di tutte le
`GlassSurface(...)`, icone `Icons.*`/`CupertinoIcons.*` e usi di
`Theme.of(context).colorScheme` in `draw_route_controls.dart`, `map_gl_screen.dart`,
`nearby_photos_action.dart`, `legends.dart`.

**Causa radice del problema più sistemico (chevron vs X):** `_CardIconButton` — usato per
Undo, Annulla-e-chiudi, Colori dislivelli, Trova foto vicine, Modifica, Salva offline e il
nuovo Riduci/Espandi — leggeva `Theme.of(context).colorScheme.onSurface`/`.primary` invece
dei token `context.palette` dell'app. `colorScheme` è generato da
`ColorScheme.fromSeed(seedColor: palette.accent)` (vedi `app/theme.dart`): `.primary` è
esplicitamente forzato a combaciare con `palette.accent` (`.copyWith(primary: ...)`), ma
`.onSurface` **no** — resta il tono calcolato dall'algoritmo tonale M3, senza alcuna garanzia
di combaciare con `palette.tertiaryIcon`/`iconGrey` usati ovunque nel resto della card. Da lì
il chevron (via `_CardIconButton`, `onSurface@75%`, piuttosto scuro) risultava percepibilmente
più opaco della X adiacente (`palette.tertiaryIcon`, grigio chiaro) pur essendo due azioni di
pari peso nella stessa riga. Fix: `_CardIconButton` ora usa `palette.iconGrey` (enabled),
`palette.tertiaryIcon` (disabled), `palette.accent` (attivo); icona portata da 22 a 24px
(altro scostamento minore dalla X, che era già a 24px). Il chevron riduci/espandi in
`_SelectedBody` non passa comunque da `_CardIconButton` (tarato per la riga di azioni sotto,
un contesto diverso) ma replica esattamente lo stile della X adiacente (stesso file, stessa
riga, stesso peso — la scelta più diretta per garantire identità visiva tra i due).

**Altri scostamenti trovati e corretti:**
- `PhotoDetailCard`: `GlassSurface` non passava `opacity`/`blur` → usava il default della
  palette (tarato per la "chrome" di navigazione — menubar, controlli laterali, ricerca:
  tutti volutamente più trasparenti) invece del livello "card di contenuto" (`opacity: 0.92,
  blur: 30`) di `DrawRouteControls`/`_ImportLoadingCard`, con cui condivide lo stesso
  contesto visivo (impilate una sopra l'altra nello stesso `Column` in fondo allo schermo).
  X di chiusura anche lei disallineata: 22px/32×32 invece di 24px/40×40 come le altre tre X
  dell'app (`_SelectedBody`, `_SelectedWaypointBar`, `_PointInfoCard` in `map_gl_screen.dart`).
- `_NearbyPhotosSheet` (`nearby_photos_action.dart`): opacità 0.94, un valore isolato senza
  un motivo per differire dalle altre card di contenuto → 0.92.
- **Icona "Modifica"** in `_SelectedBody`: `Icons.edit_rounded` (Material) — stonava sia con
  le altre icone Cupertino nella stessa riga (Trova foto vicine, Salva offline) sia con le
  altre matite dell'app (nome traccia in `_NameField`, titolo foto in `PhotoDetailCard`,
  entrambe già `CupertinoIcons.pencil`) → uniformata a `CupertinoIcons.pencil`.
- `legends.dart`: stesso tipo di scostamento, `Icons.info_outline` (Material) → uniformato a
  `CupertinoIcons.info`, la stessa icona già usata in Impostazioni → Informazioni → Sentèi
  per lo stesso concetto "info".
- `_NameField`: riempimento campo (`scheme.onSurface.withValues(alpha:0.06)`) e icona matita
  (`scheme.onSurface.withValues(alpha:0.5)`) non allineati al campo concettualmente identico
  in `_promptEditPhotoTitle` (`palette.hairline.withValues(alpha:0.1)`) → uniformati
  (`palette.hairline`/`palette.iconGreyLight`).
- `map_gl_screen.dart`, testo "2D"/"3D" nei controlli laterali: `scheme.onSurface.
  withValues(alpha:0.85)` → `palette.label`.

**Non toccato deliberatamente** (uso legittimo, non un'incoerenza): `Icons.straighten`/
`trending_up`/`trending_down`/`signpost_outlined`/`search_rounded` — icone Material scelte
perché non esiste un buon equivalente Cupertino per quel concetto specifico, usate sempre
allo stesso modo per lo stesso concetto (nessun conflitto con un'icona Cupertino usata altrove
per la stessa cosa); `ios_menu.dart`/`ios_progress.dart`/il dialog "Modifica titolo" (tutti a
opacità 0.96) — tier deliberatamente diverso per dialog/menu centrati, non card impilate sulla
mappa; `bandTextColor: scheme.onSecondaryContainer` nel grafico profilo — abbinamento
Material corretto (testo pensato apposta per il contrasto su `secondaryContainer`).

Aggiunti 2 test di regressione mirati in `draw_route_controls_test.dart` (icona "Modifica"
Cupertino, opacità di `PhotoDetailCard` allineata a `DrawRouteControls`).

---

## 27 luglio 2026 — Pin foto in mappa evidenziato + card traccia riducibile (feedback utente diretto, confluito in `1.0.0+6`)

Sesto e ultimo giro di feedback diretto sul tema foto (stesso giorno), più una richiesta
indipendente sulla card della traccia selezionata.

1. **Pin foto in mappa** — l'evidenziazione gialla introdotta per thumbnail e pin nel
   grafico non arrivava al terzo posto dove compare una foto: il pin sulla **mappa**
   (`_renderPhotos` in `map_gl_screen.dart`). Ora la foto selezionata ha lì un pin più
   grande (raggio 10 vs 7) con anello giallo (`0xFFFFD600`) invece del bianco. Serviva
   anche un nuovo `ref.listen(selectedPhotoProvider, (_, __) => _renderPhotos())`: prima
   nessun listener triggerava un ridisegno dei pin al cambio di foto selezionata (il
   provider veniva solo letto una volta dentro `_renderPhotos`, senza guardarlo).
2. **Card traccia riducibile** — richiesta indipendente per vedere più mappa: nuovo
   `trackCardExpandedProvider` (`bool`, sempre `true` a un cambio traccia, stesso pattern
   di `profileVisibleProvider`/`ProfileVisible` — riparte espansa scegliendo un'altra
   traccia). `_SelectedBody` ora avvolge tutto il contenuto sotto la riga del titolo in
   `if (expanded) ...[ ... ]`; ridotta mostra solo nome + il nuovo tasto riduci/espandi
   (`_CardIconButton`, chevron su/giù) + il tasto chiudi/deseleziona già esistente.

---

## 27 luglio 2026 — Rifinitura card foto: 3 righe, ordine, evidenziazione gialla (feedback utente diretto su screenshot, confluito in `1.0.0+6`)

Quinto giro di feedback diretto (stesso giorno) sulla card foto appena introdotta.

1. **Layout a 3 righe**: titolo; quota (solo `Format.meters(m)`, senza l'etichetta "Quota
   ") + coordinate sulla stessa riga (`Row` con due `Text`); data/ora sempre in una riga a
   sé, non più condizionata a `hasTitle` — prima veniva mostrata solo se c'era un titolo
   custom (altrimenti sarebbe stata un doppione del titolo-default). Ora può effettivamente
   duplicare il titolo quando questo è ancora il default data/ora: accettato esplicitamente,
   l'utente vuole comunque sempre 3 righe fisse.
2. **Ordine della striscia**: `_PhotoStrip` ordina `track.photos` per `distanceMeters`
   crescente prima di renderle (`[...track.photos]..sort(...)`), invece di seguire l'ordine
   di collegamento/import — più intuitivo scorrendo insieme al grafico.
3. **Evidenziazione gialla, non blu**: sia la thumbnail (`_PhotoStrip`) sia il pin nel
   grafico (`ElevationProfileChart`/`_ProfilePainter`, nuovo parametro
   `highlightedPhotoId`) usano ora `0xFFFFD600` invece dell'accento blu dell'app — il pin
   evidenziato è anche più grande (raggio 7 vs 5). Si applica in due casi, con priorità
   alla selezione esplicita:
   - foto **selezionata** (tap su thumbnail o pin, `selectedPhotoProvider` valorizzato,
     `PhotoDetailCard` aperta) — nuovo, prima nessuna evidenziazione avveniva in questo caso;
   - foto **sotto il cursore** durante lo scrubbing sul grafico (come già introdotto), ora
     con tolleranza aumentata da 25 a 50 m lungo il percorso (più facile "agganciarla").
   `_SelectedBody` calcola `highlightedPhotoId` con questa priorità e lo passa a entrambi i
   widget.

Aggiornati/aggiunti test in `draw_route_controls_test.dart`: ordine (foto collegate in
ordine "sbagliato", verificato tappando la prima da sinistra), colore esatto
`0xFFFFD600` (non solo "non trasparente"), priorità selezione-su-cursore con verifica del
`highlightedPhotoId` passato a `ElevationProfileChart`.

---

## 27 luglio 2026 — Foto lungo il percorso: card unificata + titolo + evidenziazione (feedback utente diretto, confluito in `1.0.0+6`)

Quarto giro di feedback diretto (stesso giorno), questa volta sull'epica "Foto lungo il
percorso" (P1, analisi in `docs/eval-photo-sync.md`) e su un dettaglio residuo della card
del punto selezionato.

1. **Riga Annulla/Undo/Salva nella vista del punto selezionato** — non ha senso lì
   (riguardano la traccia intera, non il punto); rimossa quando `selectingPoint` è vero in
   `_DrawingBody` — la X in alto nella vista del punto chiude già, tornando alla card
   normale dove quei tasti ricompaiono.
2. **Thumbnail più piccole**: `_PhotoStrip` da 56 a 44px (minimo target di tocco iOS,
   restano tappabili).
3. **Evidenziazione + auto-scroll scorrendo il grafico**: `_SelectedBody` calcola ora
   `highlightedPhotoId` confrontando `profileCursorProvider` con `photo.distanceMeters` di
   ciascuna foto (tolleranza 25 m lungo il percorso — costante `_photoHighlightToleranceMeters`
   in `draw_route_controls.dart`); `_PhotoStrip` (diventato `ConsumerStatefulWidget`) disegna
   un bordo (`AnimatedContainer`) sulla thumbnail corrispondente e, in `didUpdateWidget`,
   scorre fino a renderla visibile (`Scrollable.ensureVisible` via `GlobalKey` per foto,
   assegnata in un post-frame callback — la thumbnail deve già essere nell'albero).
4. **Card di dettaglio foto unificata**: prima, tap su una thumbnail nella card apriva
   direttamente `_confirmRemovePhoto` (nessun dettaglio, solo "Scollega?"), mentre tap su un
   pin foto in mappa apriva `_PhotoInfoCard` (thumbnail + sola data). Ora **entrambi** i tap
   passano da `selectedPhotoProvider` (già mostrato sopra `DrawRouteControls` in
   `map_gl_screen.dart` — bastava riusare lo stesso provider dalla striscia invece di aprire
   un action-sheet separato) e mostrano la stessa `PhotoDetailCard` (nuovo widget pubblico
   in `draw_route_controls.dart`, sostituisce `_PhotoInfoCard`): thumbnail (tap → foto a
   schermo intero), titolo (o data/ora come default), coordinate + quota del punto di scatto
   (`waypointElevationProvider`, lo stesso già introdotto per il punto selezionato — riusato
   qui passandogli `photo.position` invece della posizione di un waypoint), data/ora, azioni
   "Modifica titolo"/"Scollega" come pillole (`_PillAction`, stesso linguaggio del resto
   della card, non più testo puro/action-sheet).
   - **Titolo**: nuovo campo `TrackPhoto.title` (nullable, chiave `'t'` in
     `track_codec.dart`), `Tracks.updatePhotoTitle(trackId, photoId, title)`. Titolo vuoto →
     resta un valore esplicito (stringa vuota, non torna a `null`: limite di
     `TrackPhoto.copyWith`, che usa `??` per tutti i campi) — l'interfaccia tratta comunque
     vuoto/null allo stesso modo (mostra la data come titolo di default).
   - **Foto a schermo intero**: `openFullPhoto` usa `AssetEntity.fromId(photo.id)` — l'id è
     già l'id `photo_manager` **di questo device** (nonostante il commento originale di
     `TrackPhoto.id` scoraggiasse di affidarsi a un id di libreria non portabile: di fatto è
     già quello che viene salvato da `NearbyPhotosFinder._toTrackPhoto`). Se l'asset non
     risolve (traccia sincronizzata da un altro device) l'apertura è un no-op silenzioso, come
     richiesto — nessun re-match per posizione/orario implementato qui (fuori scope, l'id
     esistente basta per il caso "stesso device" richiesto). Viewer minimale con
     `InteractiveViewer` (pinch-zoom), niente dipendenza nuova.
   - **Coordinate/data-ora**: nuovi `Format.coordinates`/`Format.dateTime` in
     `core/util/format.dart` — `_PointInfoCard` in `map_gl_screen.dart` (punto ispezionato in
     esplorazione) aggiornato per riusare `Format.coordinates` invece di duplicare la
     formattazione.

Non incluso in questo giro (restano aperti in `ROADMAP.md` P1): import/toggle
mostra-nascondi dalla card, vista a griglia con selezione multipla, zoom/focus mappa al tap
su un'anteprima, fix del testo sottolineato "Trovate X immagini".

---

## 27 luglio 2026 — Rifinitura design su screenshot (skill mobile-app-design-mastery, confluito in `1.0.0+6`)

Terzo giro di feedback diretto sulla stessa card (stesso giorno), questa volta caricando
la skill `mobile-app-design-mastery` per applicare linee guida UX/UI esplicite invece di
giudizio estetico non strutturato.

1. **Pallino colore in "Impostazioni avanzate"** — la riga collassata mostrava lo swatch
   del colore corrente come icona leading: ridondante/fuorviante ora che il colore vive
   nel foglio dedicato (sembrava un'informazione a sé, non un trigger per aprire altro).
   Sostituito con un'icona neutra (`CupertinoIcons.slider_horizontal_3`), coerente con le
   righe "Impostazioni" del resto dell'app (`settings_screen.dart`).
2. **Punto selezionato: cambio di contesto vero, non una fascia aggiunta** — richiamando
   la formulazione originale della roadmap ("sparisce nome/colore traccia, compaiono i
   dati del punto"), superata la scelta di una sessione precedente (stesso giorno) di
   tenere nome/distanza/impostazioni avanzate sempre visibili sopra i dati del punto.
   `_DrawingBody` ora nasconde quella sezione quando un punto è selezionato, mostrando
   **solo** `_SelectedWaypointBar` — "Salva"/Annulla/Undo restano comunque raggiungibili
   in fondo, quelli riguardano la traccia nel suo complesso, non il singolo punto.
   Rimosso anche il contenitore con sfondo tinto (`accent.withValues(alpha:0.08)`): con
   la vista a sé stante non serve più distinguerla visivamente dal resto.
3. **Coerenza dei pulsanti** — "Aggiungi punto prima"/"Elimina" erano `CupertinoButton`
   di solo testo, incoerenti con `_PillAction`/`_CardIconButton` già usati nel resto
   della card. Convertiti in `_PillAction` (pillola chiara, icona + testo); `_PillAction`
   esteso con un parametro `color` opzionale (default `scheme.primary`) per la variante
   distruttiva ("Elimina", `AppColors.destructive`) — evita di duplicare il widget solo
   per il colore.

Guida applicata da `mobile-hierarchy.md` (skill `mobile-app-design-mastery`): pulsanti
distruttivi in stile terziario/testo su schermate normali sarebbero corretti in
astratto, ma qui il criterio decisivo era la coerenza *interna* con il linguaggio già
stabilito nella stessa card, non la linea guida generica isolata.

---

## 27 luglio 2026 — Impostazioni avanzate, quota sul punto, aggiungi punto prima (feedback utente diretto su screenshot della card, confluito in `1.0.0+6`)

Seguito diretto della voce precedente (stesso giorno): altro giro di feedback puntuale
sulla stessa card di disegno/editing (`lib/features/draw_route/draw_route_controls.dart`),
questa volta a schermata mostrata.

1. **Colore ancora troppo in vista** → spostato, insieme a "Segui i sentieri", in un
   foglio **Impostazioni avanzate** (`_showAdvancedSettingsSheet`, stesso linguaggio
   visivo di `showDifficultyLegend`/`showReleaseNotes`): nella card resta solo una riga
   riassuntiva (swatch corrente + chevron). Superata la versione "collassa/espande in
   riga" della voce precedente — non bastava, il colore andava proprio tolto da lì.
2. **Quota sul punto selezionato** — `waypointElevationProvider`
   (`FutureProvider.family<double?, LatLng>`, stessa fonte DEM Terrarium di
   `InspectedPointNotifier`) aggiunta a `_SelectedWaypointBar`, con lo stesso trattamento
   (spinner mentre carica, "non disponibile" se la tile manca). Aggiunto anche il
   suggerimento "Tieni premuto per spostare" (il gesto esisteva già — drag sul pallino —
   ma non era comunicato in UI).
3. **Elimina senza conferma?** — verificato: `_confirmDeleteWaypoint` passava già da
   `showIosConfirm` (nessuna regressione trovata leggendo il codice); il test
   `draw_route_controls_test.dart` "eliminare un punto chiede conferma prima di
   rimuoverlo" lo conferma esplicitamente (tappare "Elimina" apre il dialog, il punto
   resta finché non si conferma).
4. **Maniglia di metà-segmento → "Aggiungi punto prima"** — implementa il punto
   roadmap P1 "Editing punti intermedi": rimossi `_midpointHandles`,
   `_drawMidpointHandles`, `_onMidpointDragEnd` e il relativo
   `CircleAnnotationManager` in `map_gl_screen.dart`. Nuovo
   `Tracks.insertPointBefore(index)` (route_editor_provider.dart): inserisce un waypoint
   a metà tra `index` e il precedente, assente sul primo punto (`index == 0`, nessun
   precedente). **Nota architetturale**: `insertPointBefore` non sposta la selezione
   (`selectedWaypointProvider`) al suo interno — farlo dal notifier di `tracksProvider`
   genera `CircularDependencyError` in Riverpod, perché `SelectedWaypoint.build()`
   osserva `activeTrackIdProvider` che a sua volta osserva `tracksProvider` (ciclo
   `Tracks → SelectedWaypoint → tracksProvider`). Lo sposta chi chiama, nel widget
   (`ref` lì non è vincolato al notifier di `tracksProvider`).
5. **Riordino card**: nome → distanza (se ≥2 waypoint) → Impostazioni avanzate → (se
   selezionato) dettagli punto → azioni (Annulla/Undo/Salva).

Aggiornati i test (`route_editor_test.dart`, `draw_route_controls_test.dart`).

---

## 27 luglio 2026 — Rifinitura card di disegno (feedback utente diretto, confluito in `1.0.0+6`)

Tre richieste puntuali sulla card di creazione/modifica (`_DrawingBody` in
`lib/features/draw_route/draw_route_controls.dart`), non ancora in `ROADMAP.md` P1
(risolte su richiesta diretta prima di riprendere la lista):

1. **Selettore colore sempre tutto visibile** → `_ColorPicker` diventato
   `ConsumerStatefulWidget` con stato `_expanded` locale: collassato mostra solo il colore
   scelto (`_ColorSwatch` con `Key('colorPickerSelectedSwatch')` per i test) + label
   "Colore"; un tocco espande la riga con gli altri colori della palette (scrollabile
   orizzontalmente), sceglierne uno la richiude. Anticipa parte di quanto già previsto in
   `ROADMAP.md` P1 ("Selettore colore traccia espandibile") — la sola parte "ampliare la
   palette con più tonalità" non era richiesta ora, quindi il punto è stato **rimosso**
   dalla roadmap (non "ampliare la palette con più tonalità" da sola: se servirà, va
   riaperta con un punto dedicato).
2. **Nessuna distanza/dislivello live durante il disegno** → aggiunta la sola
   **distanza totale**, riusando `routeDistanceProvider` (già esistente e usato da
   `_SelectedBody` per lo stesso scopo): haversine sul percorso live
   (`livePathProvider`), nessuna chiamata di rete. **D+/D- volutamente esclusi**:
   richiederebbero `TrackMetricsCalculator.compute()` (densificazione + fetch quote
   Terrarium) ad ogni spostamento di un punto — troppo costoso per un aggiornamento live,
   restano disponibili solo dopo il Salva (o per un import, a fine fase 1).
3. **Icona poco chiara accanto a "Segui i sentieri"** — `CupertinoIcons.arrow_turn_up_right`/
   `minus` non comunicava nulla di più del testo + switch già presenti → rimossa.

**Verifica:** i tap sintetici via `osascript`/System Events sul simulatore (vedi
[[sentei-simulator-tap-automation]]) funzionano sui widget Flutter standard ma **non**
sulla vista nativa Mapbox (piattaforma view) —i tap sulla mappa per aggiungere waypoint
non venivano recapitati, rendendo impossibile una verifica visiva end-to-end del disegno.
Sostituita con un test widget dedicato, `test/features/draw_route_controls_test.dart` (3
casi: colore collassato/espandibile, icona assente, distanza live con ≥2 waypoint), che
pilota `tracksProvider` direttamente (`startNewDrawing`/`addPoint`) senza passare dal
gesto sulla mappa.

---

## 27 luglio 2026 — Testo pulsante conferma annulla editing (P1, confluito in `1.0.0+6`)

`_confirmCancel` (`lib/features/draw_route/draw_route_controls.dart`) è condiviso tra la
creazione di un nuovo percorso e la modifica di una traccia esistente (`cancelEditing`
gestisce entrambi i casi, vedi `_editSnapshot`). Il `confirmLabel` del dialog era
"Annulla percorso" in entrambi i casi — fuorviante quando si sta modificando una traccia già
salvata (non si sta affatto annullando "il percorso", solo le modifiche non salvate). Fix a
una riga: `confirmLabel: 'Annulla modifiche'`.

---

## 27 luglio 2026 — Traccia "fantasma" dopo import GPX (P1, confluito in `1.0.0+6`)

**Sintomo segnalato testando `1.0.0+4`:** nel flusso di import a 2 fasi (grezza tratteggiata
→ editing → Salva), la traccia grezza originale poteva restare visibile in mappa per sempre,
senza più alcun modo di rimuoverla, e le altre tracce salvate sparivano insieme ad essa.

**Causa:** `TracksListScreen` (`lib/features/tracks_list/tracks_list_screen.dart:47`) legge
`tracksProvider` — lo stato **live** di tutte le tracce, incluse quelle con un import ancora
in caricamento (fase 1) o in revisione (fase 2) — non un elenco filtrato alle sole tracce
persistite. La sua azione "Elimina" (menu riga → `_confirmDeleteTrack` → `remove(t.id)`)
è quindi disponibile anche su una traccia del genere, ma `Tracks.remove()`
(`lib/features/draw_route/route_editor_provider.dart`) rimuoveva solo la traccia da
`TracksState` senza passare da `cancelImport`/`cancelEditing`: non ripuliva
`importPreviewProvider` (il riferimento grezzo tratteggiato, `_importRawLine` in
`map_gl_screen.dart`) né `importLoadingProvider`. Risultato: il riferimento grezzo restava
disegnato per sempre — nessuna card/pulsante può più rimuoverlo, dato che la traccia (e
quindi la card) non esiste già più — e `importLoadingProvider` restava valorizzato,
facendo sì che `_renderAll`'s `importing` restasse sempre vero, nascondendo tutte le altre
tracce salvate (branch "in creazione/modifica ... nascondi TUTTE le altre").

**Fix:** `remove()` ora controlla, prima di rimuovere la traccia, se l'id coincide con
`importLoadingProvider` e/o con l'id tracciato da `importPreviewProvider`: in tal caso li
ripulisce (e incrementa `_importGen` per invalidare un eventuale `_runImport` ancora in
volo, anche se già protetto dal controllo `state.byId(id) == null` in `cancelled()`).
Aggiunti 2 test di regressione in `test/features/route_editor_test.dart` (rimozione durante
fase 1 e fase 2 dell'import) che avrebbero fallito prima del fix.

---

## 27 luglio 2026 — Tema rispettato fin dal primo frame (P1 #1, confluito in `1.0.0+6`)

**Sintomo segnalato testando `1.0.0+4`:** con il tema impostato manualmente (es. Chiaro) su
un telefono col sistema in Dark Mode, all'avvio l'app mostrava per un istante lo Scuro di
sistema. **Causa:** `AppThemeModeController.build()`/`AppDarkVariantController.build()`
(`lib/app/theme_provider.dart`) ritornavano sempre il default (`AppThemeMode.auto`/
`AppDarkVariant.standard`) al primo frame, poi un `_restore()` asincrono (await
`SharedPreferences.getInstance()`) aggiornava lo stato — nel frattempo `SenteiApp`
(`lib/app/app.dart`) risolveva `themeMode: ThemeMode.system`, quindi seguiva il sistema
(Scuro) invece della preferenza salvata, per la finestra fra il primo frame e la risoluzione
del restore.

**Fix:** `main()` (`lib/main.dart`) ora è `async`, attende `SharedPreferences.getInstance()`
**prima** di `runApp` e legge da lì mode/variant salvati (nuovi metodi statici
`AppThemeModeController.readFrom`/`AppDarkVariantController.readFrom`); i due `Notifier`
accettano ora un valore iniziale opzionale via costruttore, iniettato con
`ProviderScope(overrides: ...)` — se valorizzato, `build()` lo ritorna direttamente senza
passare dal restore asincrono, azzerando la finestra sbagliata. Il costruttore di default
(nessun argomento) resta invariato per i test esistenti (`test/app/theme_provider_test.dart`,
comportamento asincrono con `SharedPreferences.setMockInitialValues`), a cui si sono
aggiunti due test per il nuovo percorso sincrono.

---

## 27 luglio 2026 — Altezza fissa per la card Novità/Roadmap (confluito in `1.0.0+6`)

Il bottom sheet di Impostazioni → Informazioni → Sentèi (`showReleaseNotes`,
`lib/ui/release_notes.dart`) si dimensionava sul contenuto: `constraints` impostava solo un
`maxHeight` (tetto massimo, non un vincolo fisso) e la `Column` interna usava
`mainAxisSize: MainAxisSize.min` con l'area scrollabile in `Flexible` — la tab "Novità"
(lunga, più versioni) e "Roadmap" (corta, poche righe) producevano quindi altezze diverse
della card, con un cambio dimensione vistoso ad ogni tocco del segmented control. Fix:
`BoxConstraints(minHeight: h, maxHeight: h)` con lo stesso valore (0.88 dell'altezza
schermo, invariato) forza il bottom sheet a un'altezza sempre fissa; `Flexible` →
`Expanded` sull'area scrollabile perché ora riempie sempre lo spazio disponibile (contenuto
corto = spazio bianco sotto, non più un contenitore più piccolo). Verificato a occhio sul
simulatore (screenshot + tap automatizzati, vedi anche `CLAUDE.md`/memoria di sessione).

---

## 24 luglio 2026 — Icone provider cloud distinte (confluito in `1.0.0+6`)

In Impostazioni → Sincronizzazione cloud, la riga di accesso/account mostrava sempre
`CupertinoIcons.cloud`/`cloud_fill` sia per iCloud sia per Google Drive — a colpo d'occhio
indistinguibili. `_CloudSection` (`lib/features/settings/settings_screen.dart`) ora sceglie
l'icona in base al `cloudProviderProvider` attivo: **iCloud** resta la nuvola (coerente con
l'iconografia reale del servizio Apple), **Google Drive** usa `Icons.add_to_drive` (Material,
triangolo/cartella — nessun asset o dipendenza aggiuntiva, `uses-material-design: true` già
presente). Il selettore segmentato (`_CloudProviderSelector`) resta solo testuale, non
toccato: il problema segnalato era specificamente l'icona della riga account.

---

## 24 luglio 2026 — Roadmap sintetica in-app (confluito in `1.0.0+6`)

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
segmenti adiacenti).

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

> Bug emerso dal test su device (la grezza può restare "fantasma" in mappa, eliminando
> l'import da Tracks List invece che da Annulla) → causa e fix nella voce datata 27 luglio
> 2026 più sopra.

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
(tap/drag/seleziona) wired a `Tracks`. `flutter_map` rimosso. *(Decisa in due passi: prima
un ibrido — 2D `flutter_map` + una vista 3D separata su `mapbox_maps_flutter` — poi
superato dalla migrazione totale qui sopra, un solo motore per 2D e 3D; i documenti di
analisi di quei due passi sono stati rimossi una volta completata la migrazione, il loro
esito è tutto in questa voce.)*

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
