# Changelog — Sentèi

Novità per versione. Le voci sono scritte per chi usa l'app, non un log tecnico —
per i dettagli di sviluppo vedi **[`docs/CHANGELOG-DEV.md`](docs/CHANGELOG-DEV.md)**;
per cosa resta da fare vedi **[`docs/ROADMAP.md`](docs/ROADMAP.md)**.

Il numero fra parentesi è il **build** (`CFBundleVersion`/`versionCode`); la app in
Impostazioni → Informazioni mostra `versione (build)`, es. `1.0.0 (4)`.

## In lavorazione (non ancora rilasciato)

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
