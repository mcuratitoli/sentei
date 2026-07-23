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

## Il nodo "Sync" — decisione da prendere

Il nome "**sync** album fotografico" e l'architettura cloud esistente
(`CloudSyncService`, iCloud/Google Drive già sincronizzano le tracce) creano
un'aspettativa: che le foto **viaggino con la traccia** tra dispositivi. Ma:

- Un **asset della libreria foto** (identificato da `PHAsset.localIdentifier`
  su iOS o l'id MediaStore su Android) è **locale al dispositivo** — non è
  portabile via iCloud Drive/Google Drive insieme al GPX/JSON della traccia.
  Se la traccia sincronizza su un secondo dispositivo, i riferimenti alle
  foto **non risolverebbero** lì.
- Per una vera sincronizzazione cross-device servirebbe **caricare i file
  foto stessi** (non solo il riferimento) nella stessa cartella cloud della
  traccia — più oneroso: spazio/banda, gestione duplicati, parità tra iCloud
  e Google Drive.

**Due scenari alternativi, da scegliere:**

1. **Collegamento locale** (più semplice, più veloce da realizzare): le foto
   restano nella libreria del dispositivo che ha fatto il match; il
   collegamento traccia↔foto è **solo locale a quel dispositivo**. Chi apre
   la traccia sincronizzata su un altro device non vede le foto (a meno di
   rifare il match lì, se le foto sono anche su quel device/libreria).
2. **Sync vero** (più oneroso): le foto (o miniature+originale) vengono
   caricate nella cartella cloud della traccia, accanto al GPX/JSON, così
   viaggiano insieme ovunque. Più vicino al nome della feature, ma
   architettura e costo (spazio cloud dell'utente, tempo di upload,
   duplicazione dei file) molto maggiori.

## Domande aperte (da decidere prima di implementare)

1. **Scope "sync"**: collegamento locale (1) o sincronizzazione vera dei file
   foto (2)? Cambia moltissimo l'effort.
2. **Data dell'escursione**: va bene leggere `<time>` dal GPX quando presente
   (e altrimenti chiedere/non filtrare per data), o si preferisce sempre
   chiedere conferma all'utente?
3. **Retro-matching vs automatico**: la ricerca foto è un'azione manuale
   ("Trova foto" nella card) o automatica dopo ogni salvataggio/import
   (costo: scansione libreria ad ogni traccia)?
4. **Permesso "libreria completa" vs "foto selezionate"**: iOS offre un
   permesso limitato (l'utente sceglie quali foto condividere) — più
   privacy-friendly ma UX diversa (l'utente deve scegliere a mano le foto
   pertinenti anziché lasciare fare all'app la scansione automatica per
   posizione/data). Preferenza?
