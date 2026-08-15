# Changelog tecnico — Sentèi

Cronologia dettagliata di sviluppo: cosa è stato implementato, perché, con quali file
coinvolti e quali bug/cause-radice sono stati risolti lungo il percorso. Organizzato per
**data**, ordine cronologico inverso (più recente in cima).

- Per le **novità in linguaggio utente** (cosa cambia per chi usa l'app) vedi
  [`CHANGELOG.md`](../CHANGELOG.md) alla radice del repo — la stessa lista è mostrata
  in-app in Impostazioni → Informazioni → Sentèi.
- Per **cosa resta da fare**, in ordine di priorità, vedi [`ROADMAP.md`](./ROADMAP.md).

---

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
- **Resta da fare** (spostato in P4 della roadmap): confrontare la stima con i tempi sui
  cartelli CAI reali lungo un'escursione nota — i casi di test sono sintetici, non presi da
  un percorso vero.

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

⚠️ **Due deroghe consapevoli a `new design/DESIGN_GUIDELINES.md`**, entrambe su richiesta
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

## 28 luglio 2026 — Redesign grafico completo secondo `new design/DESIGN_GUIDELINES.md` (confluito in `1.0.0+6`)

L'utente ha preparato un intero sistema di design (`new design/DESIGN_GUIDELINES.md` + 9
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

Aggiornati `docs/eval-waypoint-editing.md` (Step 4 superato) e i test
(`route_editor_test.dart`, `draw_route_controls_test.dart`).

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
segmenti adiacenti). Analisi/piano: `docs/eval-waypoint-editing.md`.

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
(tap/drag/seleziona) wired a `Tracks`. `flutter_map` rimosso. Piano:
`docs/plan-mapbox-gl-migration.md`, `docs/eval-3d-map.md`.

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
