# Changelog — Sentèi

Novità per versione. Le voci sono scritte per chi usa l'app, non un log tecnico —
per i dettagli di sviluppo vedi **[`docs/CHANGELOG-DEV.md`](docs/CHANGELOG-DEV.md)**;
per cosa resta da fare vedi **[`docs/ROADMAP.md`](docs/ROADMAP.md)**.

Il numero fra parentesi è il **build** (`CFBundleVersion`/`versionCode`); la app in
Impostazioni → Informazioni mostra `versione (build)`, es. `1.0.0 (4)`.

L'emoji a inizio riga dice **di che tipo** è la novità: ✨ nuova funzione · 🐛 correzione ·
🎨 grafica e interfaccia · 🗺️ mappa · 📸 foto · ✏️ disegno e modifica tracciati ·
📥 import/export GPX · ☁️ sincronizzazione · 📖 legende e documentazione. In-app la stessa
distinzione è resa dall'icona accanto a ogni voce (`kReleaseNotes` in
`lib/ui/release_notes.dart`), non dall'emoji.

## Non ancora rilasciato

- 🗺️ **Quota e posizione sempre in vista.** Un riquadro in alto a sinistra
  mostra di continuo la tua **quota**, letta dal GPS, mentre cammini.
  Toccandolo si apre e aggiunge l'**accuratezza** del segnale e le
  **coordinate**, con un tasto per copiarle. Se il GPS non è abbastanza
  preciso sulla quota, al suo posto compare un trattino. La barra della
  scala, il logo e l'icona informazioni sulla mappa si sono spostati per
  fargli spazio.
- ⏱️ **Tempo di percorrenza di un tratto scelto.** La card della traccia
  mostra un unico tempo stimato per l'intero percorso (partenza → arrivo);
  tolto lo spezzone automatico "salita / discesa" sui percorsi ad anello. In
  più, con il profilo altimetrico aperto, il tasto **"Tempo di un tratto"**
  fa scegliere due punti sul grafico e stima tempo, distanza e dislivelli di
  quel solo tratto — utile per sapere "da qui a lì quanto manca". Una × torna
  al totale.
- 🗺️ **Difficoltà del sentiero visibile sulla linea del tracciato.** Come
  su una cartina di montagna, la linea cambia stile in base al grado CAI:
  **piena** per i tratti turistici (T), **a trattini** per gli
  escursionistici (E), **a puntini** per quelli da esperti (EE), **tratto e
  punto** per i tratti attrezzati / via ferrata (EEA). Il colore del
  tracciato non cambia. La linea dei tracciati salvati ha ora un **bordo
  bianco più sottile**: i trattini si vedevano poco perché il bordo se li
  "mangiava". La legenda "Difficoltà dei percorsi" mostra il campione di
  ogni linea.
- 🐛 **La card della traccia mostra tutti i gradi di difficoltà, non solo
  il più duro.** Se un percorso è per lo più EE con un tratto EEA, prima si
  vedeva solo "EEA" e sembrava tutta la gita di quel livello; ora compare un
  badge per ogni grado presente (es. `EE` e `EEA`), dal più facile al più
  difficile. Gestito anche il grado `EEA:F` (tratto di **via ferrata** vera
  e propria, con la difficoltà alpinistica indicata dopo i due punti), che
  prima restava senza colore e con linea piena; ora ha un badge, una voce
  in legenda e lo stile "tratto e punto" come EEA.

## 1.0.0 (10) — 26 agosto 2026

- ✏️ **Traccia "mista": tratti liberi fuori sentiero.** Disegnando o
  modificando un percorso, il tasto "Libero" (icona a scarabocchio) fa sì
  che i punti aggiunti da lì in poi si colleghino in linea retta invece di
  seguire i sentieri — utile per un tratto specifico (es. l'ultima salita a
  una cima) senza dover disattivare lo snap per l'intera traccia. Si trova
  sia nella barra di disegno sia nella card del singolo punto selezionato
  (comodo per inserire un punto libero **dentro** un tratto già disegnato,
  non solo aggiungendo in coda). I tratti liberi si vedono tratteggiati
  sulla mappa.
- ✏️ **Punto selezionato**: mostra ora anche le coordinate (non solo la
  quota) e permette di aggiungere un punto anche **dopo**, non solo prima.
- 🎨 **Menu a tre pallini più coerenti**: stesse voci nel menu della card
  traccia sulla mappa e in quello della lista tracciati (mancava "Modifica"
  in quest'ultimo); le icone hanno lo stesso sfondo tinta d'accento delle
  righe di Impostazioni, prima erano "nude"; righe leggermente meno spaziate.
- ✏️ **Il punto inserito tra due nodi già sul sentiero ora nasce sul
  sentiero**, non a metà della linea retta tra i due — su un tratto
  tortuoso poteva cadere lontano dal percorso reale.
- 🎨 **Log di debug più leggibili**: timestamp e categoria (colorata) su una
  riga, il messaggio sotto invece di un'unica riga lunga; timestamp con i
  millisecondi, non più sei cifre di frazione di secondo; più eventi
  registrati (salvataggi, sincronizzazione cloud, ricerca segnavia, import
  GPX).
- 🗺️ **Un segnavia per intero**: tocca il numero di un sentiero (sulla card
  di un punto toccato sulla mappa, o sulla card di una tua traccia) per
  vedere dove parte, dove arriva, lunghezza e dislivelli, e il link a
  OpenStreetMap — con conferma prima di caricarlo. Il percorso completo del
  segnavia compare temporaneamente sulla mappa (tratteggiato), con la
  visuale che si sposta per inquadrarlo tutto; la card resta aperta sopra
  una mappa che si può comunque esplorare (zoom/spostamento), e sparisce
  solo chiudendola esplicitamente. In Valsesia e dintorni, se il segnavia è
  nell'elenco ufficiale di CAI Varallo, compare anche un link diretto alla
  sua scheda.

## 1.0.0 (9) — 23 agosto 2026

- ✨ **Esporta un'immagine del percorso**, pronta per essere condivisa: mappa
  3D con la traccia in evidenza, nome e dati (distanza, dislivello, tempo)
  in sovraimpressione, e i punti interessanti incontrati lungo il percorso
  (rifugi, alpeggi, laghi, colli, cime) etichettati come su una cartina di
  montagna — si sceglie quali mostrare prima di salvare in galleria o
  condividere. Si trova nel menu "Altro" della card traccia sulla mappa
  (voce "Esporta immagine", insieme a "Esporta GPX") e nel menu ⋯ della
  lista tracciati.
- ✏️ **Indicatore "salvata offline"**: un segno di spunta accanto a ogni
  traccia già scaricata per l'uso senza connessione, sia in lista tracciati
  sia nel menu azioni — prima non c'era modo di saperlo senza riprovare a
  scaricarla.
- ✏️ **Pulsante «Elimina» anche nella card della traccia selezionata sulla
  mappa** (prima solo dal menu ⋯ della lista tracciati). Le altre azioni
  della card (Modifica, Esporta GPX/immagine, Salva offline, Elimina) sono
  ora raccolte in un menu "Altro", per lasciare in vista solo le due icone
  di visualizzazione (profilo altimetrico, colori dislivelli).
- 🗺️ **Con una traccia selezionata, le altre si attenuano sulla mappa** per
  leggibilità nelle zone con più tracce vicine; i pallini di inizio/fine
  ora compaiono solo su quella selezionata, e il punto di arrivo è una
  bandiera a scacchi invece del pallino rosso pieno.
- 🎨 **Impostazioni riorganizzate**: la voce "Sentèi" (nome e versione) è
  diventata un footer in fondo alla schermata; "Novità e roadmap" è ora un
  tasto a parte in "Informazioni". La scheda "Mappa" apre un foglio con
  fonte dati e attribuzione (Mapbox, OpenStreetMap) — l'icona "i" sulla
  mappa resta comunque al suo posto, i termini d'uso Mapbox non ne
  permettono la rimozione.
- ⏱️ **Tempo di percorrenza stimato**, calcolato con lo stesso metodo dei
  cartelli CAI (distanza in piano + dislivello, combinati con la formula
  svizzera). Compare sulla card di ogni traccia e nella lista dei tracciati
  salvati; vale anche per i GPX importati. Per un'andata e ritorno (o un
  anello con partenza e arrivo nello stesso punto, come la salita a un
  rifugio) mostra **salita e discesa separate**, non solo il totale. In
  Impostazioni → Escursionismo si può regolare il passo (Lento/Medio/Veloce)
  — il tempo mostrato non include le soste.
- 📸 **Mappa più pulita: niente più pallini gialli lungo tutta la traccia.**
  Ne compare uno solo, quello della foto che si sta guardando, toccando una
  miniatura o l'icona posizione — e la mappa si centra lì.
- 📸 **Le foto si aprono e si scorrono molto più in fretta.** Prima l'app
  caricava ogni scatto alla sua risoluzione piena — su una foto da 48 megapixel
  è come srotolare un poster per guardarlo in cartolina — e lo rifaceva da capo
  ad ogni scorrimento. Ora chiede al telefono l'immagine già della misura dello
  schermo e prepara in anticipo la foto precedente e la successiva.
- 📸 **Indicatore di caricamento** al centro mentre la foto arriva, al posto
  della miniatura ingrandita che sembrava una foto sgranata. Si vede soprattutto
  con le foto che stanno solo in iCloud e vanno scaricate.
- ☁️ **Sincronizzazione più leggera:** i dati di una traccia con foto pesano
  circa **un terzo** di prima (su 8 foto: da 844 a 255 KB), quindi meno traffico
  e meno spazio su iCloud/Google Drive.
- 🔍 Ingrandendo una foto non c'è più il blocco di qualche istante.
- 🎨 **Novità e Roadmap ridisegnate** (Impostazioni → Informazioni → Novità e
  roadmap): ogni voce ha un'icona, un titolo e una riga che spiega cosa cambia; la Roadmap
  è divisa in "In lavorazione", "Prossime" e "Più avanti".
- 🐛 Tolte le righe gialle sotto la data e "Altitudine" nella foto a schermo
  intero (un residuo di debug).
- 🐛 **Corretta una cache che cresceva senza limiti**: i dati di elevazione
  usati per calcolare il dislivello di ogni traccia si accumulavano sul
  telefono senza un tetto né un modo per svuotarli — su un uso prolungato
  potevano arrivare a pesare centinaia di megabyte. Con questo aggiornamento
  lo spazio già occupato viene liberato automaticamente, la cache resta
  entro un limite (200 MB) e si può svuotare a mano da Impostazioni →
  Mappe offline → "Cache elevazione".
- ✨ **Log di debug consultabili in-app**, per chi vuole segnalare un
  problema senza collegare il telefono a un Mac: si trovano toccando 7
  volte il nome/versione in fondo a Impostazioni, con possibilità di
  condividerli o cancellarli. Si conservano al massimo ~2 MB e non più di 7
  giorni.
- 🎨 La card **Novità** al primo avvio dopo un aggiornamento non si chiude
  più toccando fuori o trascinandola: va letta e chiusa con "Continua".

## 1.0.0 (8) — 29 luglio 2026

- ✨ **Al primo avvio dopo un aggiornamento compare una card con le novità**
  di quella versione, con un tocco su "Continua" per chiuderla. Appare una
  volta sola per aggiornamento, e mai a chi installa Sentèi per la prima
  volta. Il changelog completo resta comunque in Impostazioni →
  Informazioni → Sentèi.
- 🗺️ **Importando un GPX la mappa si sposta sulla traccia importata**, invece
  di restare dov'era: prima capitava di ritrovarsi la traccia caricata a
  centinaia di chilometri da quello che si stava guardando, senza capire se
  l'import fosse riuscito.
- 📄 **Una traccia importata prende il nome del file GPX** (senza estensione).
  Prima usava il nome scritto dentro al file, spesso generico o assente, che
  non corrispondeva a quello appena scelto nella schermata File.

## 1.0.0 (7) — 29 luglio 2026

- 📸 **"Trova foto vicine" ora trova davvero le foto.** Prima cercava solo
  fra i 3000 scatti più recenti dell'intera libreria: se dopo l'escursione
  avevi fatto più foto di così, quelle del percorso restavano fuori e non
  compariva mai nulla — nonostante permesso concesso e GPS nelle foto. Ora
  cerca in tutta la libreria. Il messaggio distingue anche "nessuna foto
  trovata" da "trovate, ma già tutte collegate a questa traccia".
- 📸 **Le foto di una traccia sono raggruppate per escursione**, in una
  sezione "FOTO" che si apre e chiude nella card: gli scatti vicini nel
  tempo finiscono nello stesso gruppo, con copertina, data e conteggio (una
  pausa di oltre 30 ore apre un gruppo nuovo, così un'uscita con
  pernottamento non viene spezzata in due). Toccare un gruppo apre
  direttamente la sua prima foto, in ordine di percorso.
- 📸 **Visualizzatore foto a schermo intero in stile galleria**: scorri fra
  tutte le foto della stessa escursione, con la striscia di miniature in
  basso, e chiudi trascinando verso il basso. Sotto la foto un pannello
  mostra il **profilo altimetrico con il punto di scatto evidenziato**, e
  "Vedi sulla mappa" chiude la foto e centra la mappa in quel punto.
- 📸 **Card della foto ridisegnata**: niente più titolo "Dettaglio foto",
  ora è una riga sola — miniatura, data, quota e coordinate, con Modifica
  titolo e Scollega ridotti a icone — e sotto il **carosello delle altre
  foto della stessa escursione**, per passare da una all'altra senza uscire.
  Si sovrappone alla card della traccia, che si riduce da sé per lasciare
  vedere la mappa.
- 🐛 **Import GPX su iPhone**: nella schermata File il tracciato `.gpx`
  appariva in grigio e non era selezionabile. iOS non conosce il formato
  GPX e lo trattava come un file generico; ora l'app glielo dichiara.
- 🎨 **Le card di traccia e foto si chiudono trascinandole verso il basso**
  dalla maniglia in alto, come i pannelli di sistema: la "X" non serve più
  ed è stata tolta. Durante il disegno di un percorso resta il tasto
  "Annulla" con conferma, per non perdere il lavoro con uno scorrimento.
- 🎨 **Tutte le richieste di conferma hanno ora la stessa forma** (elimina
  traccia, elimina punto, scollega foto, annulla modifiche): testo
  esplicativo e una riga con "Annulla" a sinistra e l'azione a destra, come
  la finestra "Modifica titolo". Prima erano due voci in elenco.
- 🐛 In "Modifica titolo" la tastiera a volte non si apriva e il campo
  restava senza cursore: sembrava non ci fosse niente da scrivere.
- 🐛 Chiudendo la card di una traccia, la card della foto non resta più
  orfana a mezz'aria.
- 🐛 La foto a schermo intero non è più minuscola in mezzo al nero: ora
  riempie lo schermo. Se lo scatto originale non è più nella libreria di
  questo dispositivo si vede la miniatura salvata, non più velata di grigio
  (sembrava un errore di caricamento).

## 1.0.0 (6) — 28 luglio 2026

- 🎨 **Redesign grafico** di percorso/foto/impostazioni: card e pannelli
  ora hanno uno sfondo **pieno** (non più "vetro" semitrasparente),
  bottoni coerenti in tutta l'app (pieno/bordato/testo/distruttivo),
  badge di difficoltà e numeri sentiero con forme distinte, switch "Segui
  i sentieri" blu invece che verde. *(Sostituisce le voci più sotto su
  trasparenza/coerenza grafica della sessione precedente, mai rilasciate:
  qui lo sfondo torna pieno.)*
- 🐛 Corretto un testo che usciva dai bordi del pulsante "Aggiungi punto
  prima" nella modifica di un punto del percorso.
- 🎨 **Tutti i pannelli a comparsa** (modifica titolo foto, selezione
  tema, ordina tracciati, azioni su una traccia, conferme di eliminazione,
  foto vicine al percorso) ora si aprono allo stesso modo: incollati al
  bordo inferiore dello schermo, con angoli arrotondati solo sopra; le
  card fluttuanti sopra la mappa (traccia/foto selezionata) restano invece
  arrotondate su tutti i lati.
- 🎨 Il tasto "Percorso" nella card traccia (mostra/nasconde il grafico
  altimetrico) ora è un'icona, coerente con le altre azioni della stessa
  riga (prima era l'unico pulsante con testo in quella riga).
- 🎨 Prima passata di **coerenza grafica**: card e pulsanti "X" con la
  stessa trasparenza/dimensione ovunque, icone allineate allo stesso stile
  in tutta l'app (era capitato qualche pulsante fuori tono, es. l'icona
  "Modifica" o il tasto per ridurre la card traccia).
- 📸 Toccare una foto (sia dalla card traccia sia dal pin in mappa) apre ora
  la stessa card con **titolo** (impostabile), **quota e coordinate** del
  punto di scatto, data e ora, e i tasti "Modifica titolo"/"Scollega" —
  toccando la thumbnail si apre la foto originale a schermo intero (se
  ancora presente nella libreria del dispositivo). Le foto nella card sono
  ora in **ordine lungo il percorso**; scorrendo il grafico del profilo, o
  selezionando una foto, la thumbnail, il punto sul grafico **e il pin in
  mappa** si evidenziano in **giallo** e la striscia scorre per mostrarla;
  le thumbnail sono anche più piccole.
- 🗺️ La card di una traccia selezionata si può ora **ridurre** al solo nome
  (tasto dedicato accanto alla X di chiusura), per vedere più mappa senza
  perdere la selezione.
- 🎨 Card di **disegno/modifica percorso** rifinita: colore e "Segui i
  sentieri" ora vivono in un foglio **Impostazioni avanzate** dedicato
  (invece di occupare sempre spazio nella card), la **distanza totale** si
  vede in tempo reale mentre si disegna (non solo dopo il Salva), ed è
  sparita l'icona poco chiara accanto a "Segui i sentieri".
- 📍 Selezionando un punto del percorso in modifica la card mostra ora **solo**
  i dati di quel punto (quota, un suggerimento per spostarlo, i tasti
  "Aggiungi punto prima" ed Elimina in stile coerente col resto dell'app) —
  al posto della maniglia sempre visibile a metà segmento (poco scopribile
  e mal posizionata).
- ✏️ Il messaggio di conferma per uscire dall'editing di un percorso dice ora
  "Annulla modifiche" invece di "Annulla percorso" — più corretto quando si
  sta modificando una traccia già esistente, non solo disegnandone una nuova.
- 🧹 Se si elimina dalla lista tracciati una traccia appena importata da GPX
  mentre è ancora in caricamento/revisione, non resta più una linea
  tratteggiata "fantasma" bloccata sulla mappa (e le altre tracce salvate non
  spariscono più insieme ad essa).
- 🌗 Il tema **Chiaro/Scuro** scelto in Impostazioni ora viene rispettato fin
  dall'apertura dell'app — prima, con il sistema in Dark Mode, poteva mostrare
  per un istante lo Scuro anche con Chiaro selezionato manualmente.
- 🗺️ Impostazioni → Informazioni → Sentèi ora si apre con due schede: **Novità** (come
  prima) e **Roadmap**, un'anteprima sintetica delle prossime priorità di sviluppo. La
  card ha sempre la stessa dimensione passando da una scheda all'altra (prima si
  restringeva/allargava in modo scomodo).
- ☁️ Icona distinta per **iCloud** e **Google Drive** in Impostazioni → Sincronizzazione
  cloud (prima era la stessa nuvola generica per entrambi).

## 1.0.0 (5) — 24 luglio 2026

- 🌙 **Modalità scura** con 3 varianti — Standard, Notturno (toni caldi per
  preservare la visione notturna in montagna) e Risparmio energetico (nero
  puro, pannelli senza sfocatura); cambio tema con transizione morbida invece
  che a scatto, accento caldo coerente in tutta l'app (non solo testo/icone).
- 🗺️ **Mappa scura automatica**, coordinata col tema dell'app.
- ✏️ **Editing avanzato dei tracciati**: aggiungere/spostare punti intermedi,
  undo multiplo, ri-instradamento incrementale sui sentieri.
- 📥 **Import GPX migliorato**: riallineamento ibrido dei tracciati importati
  da altre app/dispositivi.
- 📖 **Legenda estesa**: gradi alpinistici, scala Welzenbach e abbreviazioni
  ricorrenti sulle guide CAI.
- 🎬 Nuovo **splash screen** animato (isoipse + dissolvenza in ingresso).
- 📸 Prime fondamenta per collegare le **foto scattate lungo il percorso**
  alla traccia (ricerca nella libreria, non ancora in interfaccia).
- 📍 All'apertura la mappa si centra sempre sulla posizione GPS corrente.
- 📋 **Novità in-app**: questo changelog, in versione sintetica, ora si vede
  toccando Impostazioni → Informazioni → Sentèi.

## 1.0.0 (4) — 5 luglio 2026

- **Menu e conferme in stile iOS** (à la Apple Photos) — es. conferma prima
  di eliminare una traccia.
- **Ordinamento tracciati** salvato: alfabetico, per data, dislivello (D+) o
  quota più alta.
- **Cloud per piattaforma**: iCloud Drive su iOS, Google Drive su Android.

## 1.0.0 (3) — 2 luglio 2026

- **Legenda difficoltà CAI** in Impostazioni + tooltip nel grafico del
  profilo altimetrico.
- **Info punto**: tocca un punto qualsiasi della mappa per vedere quota,
  coordinate e località/provincia/nazione.
- **Vista satellite** agganciata al tasto livelli; barra di ricerca in stile
  vetro.
- Privacy policy pubblicata (richiesta da App Store/TestFlight).

## 1.0.0 (2) — 25 giugno 2026

- **Ricerca** di località e rifugi alpini.
- **Segnavia CAI ufficiali** (catasto OSM2CAI, con fallback OpenStreetMap) e
  **grado di difficoltà CAI** (T/E/EE/EEA) nella card del percorso.
- Riordino dei controlli mappa (bussola sempre visibile, passaggio 2D/3D).
- Prima interfaccia in stile **"vetro smerigliato"** iOS (Apple Maps).
- Guida per generare e distribuire l'APK Android.

## 1.0.0 (1) — 16 giugno 2026

Prima beta, distribuita su TestFlight.

- Mappa **Mapbox Outdoors** con terreno 3D e vista satellite.
- **Disegno tracciati** con snap-to-trail sui sentieri reali (BRouter).
- Calcolo di **distanza**, **dislivello** (D+/D-) e **profilo altimetrico**.
- Numeri sentiero CAI sul profilo altimetrico.
- **Posizione GPS** in tempo reale e bussola.
- **Salvataggio locale** (libreria tracciati) ed **export/import GPX**.
- **Download mappe ed elevazione offline**, per l'uso senza connessione.
- **Sync** su Google Drive e iCloud Drive.
