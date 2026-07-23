# Sync album fotografico — analisi

> Roadmap P2. Analisi 23 lug 2026, **nessuna implementazione** (richiesta
> esplicitamente solo l'analisi).

## Obiettivo (dalla roadmap)

Foto lungo il percorso (match EXIF+timestamp) + marker in mappa/profilo
altimetrico.

## Scoperta chiave: oggi **non esiste un asse temporale** sulla traccia

Verificato sul codice (`gpx_service.dart`, `DrawnTrack`, `ElevationProfile`,
`ProfileSample`): il parsing GPX **scarta** il tag `<time>` di ogni trackpoint
(non c'è alcun riferimento a "time" in `gpx_service.dart`); `DrawnTrack` ha
solo un `createdAt` **unico per l'intera traccia**, che rappresenta "quando è
stata creata/importata in Sentèi" — **non** "quando si è fatta l'escursione"
(per un import, `createdAt` è impostato a `DateTime.now()` al momento
dell'import, non alla data reale dell'uscita). `ProfileSample` (il singolo
campione del profilo altimetrico) ha `distanceMeters`/`elevation`/`position`:
**nessun campo tempo**.

Conseguenza pratica: **non possiamo** dire "questa foto è stata scattata al
minuto 23 dell'escursione" — non abbiamo quel dato. Le tracce **disegnate a
mano** (tap-to-add) non hanno proprio un concetto di tempo (si disegnano spesso
a tavolino, non durante il cammino).

## Ridefinizione realistica del matching

Buona notizia: il grafico del profilo altimetrico ha l'asse X in **distanza**,
non in tempo (`ProfileSample.distanceMeters`) — quindi il posizionamento di
un pin sul profilo **non richiede affatto un asse tempo sulla traccia**, basta
sapere a quale punto del percorso (in metri) corrisponde la foto.

Il matching realistico è quindi a **due segnali indipendenti**:

1. **Posizione (segnale primario, per il piazzamento)**: le coordinate GPS
   dell'EXIF della foto vengono proiettate sul `routedPath` — riusando
   `PathGeometry.distanceToPath` (già in `lib/domain/services/path_geometry.dart`,
   usata altrove) per la distanza dal percorso, estesa con un nuovo metodo
   (es. `nearestOnPath`) che ritorni **anche** la distanza cumulata lungo il
   percorso nel punto più vicino (piccola estensione, stessa logica già
   presente). Foto entro una soglia (es. 60-100 m dal percorso) → candidate.
   Questo **funziona per qualsiasi traccia**, disegnata o importata, con o
   senza tempo.
2. **Data (segnale secondario, per restringere la ricerca)**: l'EXIF
   `DateTimeOriginal` della foto filtra le foto **in un intorno della data
   dell'escursione**, per non scandire l'intera libreria foto e per evitare
   falsi positivi geografici (es. una via di casa ripercorsa in un'altra
   occasione). Serve però una **data dell'escursione** affidabile — oggi non
   c'è (`createdAt` non è adatto, vedi sopra). Opzioni: (a) leggere `<time>`
   dal primo trackpoint GPX **quando presente** (spesso lo è, per tracce
   esportate da Strava/Garmin/altre app) — richiede di **smettere di scartarlo**
   nel parsing; (b) chiedere all'utente di confermare/scegliere una data (o un
   intervallo) al momento di avviare la ricerca foto; (c) fallback: nessun
   filtro data, solo spaziale (più lento, più falsi positivi in aree ripetute).

## Building block tecnici

- **Libreria foto del dispositivo**: nessun pacchetto oggi in `pubspec.yaml`
  per l'accesso alla galleria/EXIF (verificato: nessuna dipendenza photo/gallery/
  image_picker/exif, nessuna `NSPhotoLibraryUsageDescription` in
  `Info.plist` — solo i permessi di localizzazione esistono). Servirebbe un
  pacchetto tipo **`photo_manager`** (query per intervallo di date +
  geolocalizzazione dell'asset, permessi cross-platform) — **da verificare
  l'ultima versione stabile su pub.dev** prima di aggiungerlo (convenzione
  progetto). Nota: l'accesso alle coordinate GPS dell'asset può essere
  limitato da iOS in modalità "Selected Photos" (permesso limitato) — da
  verificare in pratica.
- **Permessi nuovi**: `NSPhotoLibraryUsageDescription` (iOS), `READ_MEDIA_IMAGES`
  (Android 13+) o `READ_MEDIA_VISUAL_USER_SELECTED` per il flusso "seleziona
  foto" più privacy-friendly. È una **superficie di privacy nuova** per
  un'app che finora non tocca la libreria foto — coerente da dichiarare
  nell'informativa privacy già pubblicata (TestFlight).
- **Geometria**: estendere `PathGeometry` con un metodo che ritorni distanza-dal-
  percorso **e** distanza-cumulata-lungo-il-percorso nel punto più vicino
  (oggi `distanceToPath` ritorna solo la prima). Piccola estensione, stessa
  struttura di calcolo già presente.
- **Persistenza**: nuova tabella drift `track_photos` (trackId, assetId,
  lat/lon, scattata-il, distanceMetersOnPath, eventuale cache thumbnail) →
  **migrazione schema** (`schemaVersion`++, stesso pattern già usato per
  `trailsResolved`).
- **UI**: striscia di miniature nella card traccia (selezione) + marker
  fotocamera in mappa (alla posizione GPS **reale** della foto, non
  agganciata al percorso — più onesto: mostra dove è stata scattata anche se
  un po' fuori sentiero) + pin sul profilo altimetrico (alla distanza-lungo-
  percorso del punto più vicino, quello sì). Tap → viewer foto.

## Il nodo "Sync" — risolto senza server (decisione 23 lug 2026)

Il nome "**sync** album fotografico" e l'architettura cloud esistente
(`CloudSyncService`, iCloud/Google Drive già sincronizzano le tracce) creano
un'aspettativa: che le foto **viaggino con la traccia** tra dispositivi. Un
**asset della libreria foto** (`PHAsset.localIdentifier` su iOS, id MediaStore
su Android) è però **locale al dispositivo**: non è portabile via iCloud
Drive/Google Drive insieme al GPX/JSON, e caricare i file foto stessi nella
cartella cloud sarebbe l'unica alternativa "vera" — ma oneroso (spazio/banda,
duplicati, parità iCloud/Drive) e contrario al requisito **"le foto restano
in galleria"**.

### Soluzione scelta: metadati come "ricetta", non come puntatore

Invece di salvare l'id della foto (valido solo su quel device), si salvano nel
JSON della traccia (già sincronizzato via iCloud/Google Drive — **nessun nuovo
backend**) per ogni foto collegata:
- **posizione GPS** + **timestamp** originali (dall'EXIF)
- **distanza-lungo-percorso** (calcolata una volta al collegamento, per il pin
  sul profilo)
- un **thumbnail piccolo** (poche KB, es. 200×200 JPEG) — **incluso nei
  metadati sync**, così viaggia sempre con la traccia
- **l'originale non viene mai caricato né copiato**: resta solo nella galleria
  del dispositivo, recuperato al tap sul pin.

Al momento di mostrare il pin, **ogni dispositivo** rifà una ricerca *locale*
nella propria galleria per una foto che combacia con GPS+timestamp salvati
("re-match", non un id diretto):
- **stesso dispositivo** che ha fatto il collegamento → trova sempre l'originale;
- **altro dispositivo dello stesso utente** → lo trova **se** quella foto è
  arrivata lì tramite la sincronizzazione **nativa** della libreria foto del
  telefono (iCloud Photos/Google Photos), indipendente da Sentèi;
- **foto assente su quel device** → si mostra comunque il **thumbnail** (i
  metadati ce l'hanno) con un badge "originale non disponibile qui" invece di
  un errore muto — degrado onesto, non rotto.

Questo copre il caso reale (utente singolo, stessi device, foto già
sincronizzate a modo loro dal sistema operativo) senza introdurre login,
server o storage centralizzato. Un server centralizzato risolverebbe solo il
caso limite "foto trovata sempre e ovunque anche senza sync nativo del
telefono" — non necessario per un'app single-user senza social.

**Alternative scartate**: Google Photos API / iCloud Photos API dirette —
Apple non espone un'API pubblica iCloud Photos a sviluppatori terzi; Google
Photos richiederebbe un secondo OAuth solo per Android → asimmetria inutile
rispetto allo schema sopra.

### Suggerimento foto vicine — richiede permesso pieno + griglia nostra

Due strade per far scegliere le foto all'utente:
- **Picker di sistema** (Apple/Google): niente permesso esteso, ma è una
  scatola nera — non possiamo ordinarlo per vicinanza al percorso.
- **Griglia nostra dentro Sentèi** (**scelta**): serve il **permesso pieno**
  alla libreria foto (`NSPhotoLibraryUsageDescription`/`READ_MEDIA_IMAGES`),
  ma permette di leggere la posizione di ogni foto, calcolare la distanza dal
  percorso e mostrare **"Trovate N foto vicino al percorso"** ordinate per
  vicinanza, con possibilità di sfogliare comunque tutta la libreria.

### Decisione finale (23 lug 2026)

- **Permesso pieno** alla libreria foto, richiesto dalla UI di Sentèi.
- **Griglia in-app** ("Trovate N foto vicino al percorso") invece del picker
  di sistema.
- **Metadati + thumbnail** sincronizzati nel JSON della traccia; **originale
  sempre e solo dalla galleria locale**, mai caricato/copiato.
- **Nessun server/login/backend**: si procede sulla soluzione serverless sopra.
- Lavoro su **branch dedicato** (`feature/photo-sync` o simile), non su `main`.

## Domande aperte residue (da chiarire durante l'implementazione)

1. **Data dell'escursione** (per il filtro secondario): leggere `<time>` dal
   GPX quando presente, altrimenti niente filtro data (solo spaziale)? O
   sempre chiedere conferma dell'intervallo di date all'utente?
2. **Retro-matching vs automatico**: la ricerca foto è un'azione manuale
   ("Trova foto" nella card) o automatica dopo ogni salvataggio/import (costo:
   scansione libreria ad ogni traccia)? *Consiglio: manuale*, per non
   scansionare la libreria senza che l'utente lo chieda.
3. **Soglia di distanza** dal percorso per considerare una foto "candidata"
   (proposta iniziale: 60-100 m, da tarare).
