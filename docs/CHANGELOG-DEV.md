# Changelog tecnico — Sentèi

Cronologia dettagliata di sviluppo: cosa è stato implementato, perché, con quali file
coinvolti e quali bug/cause-radice sono stati risolti lungo il percorso. Organizzato per
**data**, ordine cronologico inverso (più recente in cima).

- Per le **novità in linguaggio utente** (cosa cambia per chi usa l'app) vedi
  [`CHANGELOG.md`](../CHANGELOG.md) alla radice del repo — la stessa lista è mostrata
  in-app in Impostazioni → Informazioni → Sentèi.
- Per **cosa resta da fare**, in ordine di priorità, vedi [`ROADMAP.md`](./ROADMAP.md).

---

## 27 luglio 2026 — Rifinitura card foto: 3 righe, ordine, evidenziazione gialla (feedback utente diretto su screenshot, in lavorazione, non ancora rilasciato)

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

## 27 luglio 2026 — Foto lungo il percorso: card unificata + titolo + evidenziazione (feedback utente diretto, in lavorazione, non ancora rilasciato)

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

## 27 luglio 2026 — Rifinitura design su screenshot (skill mobile-app-design-mastery, in lavorazione, non ancora rilasciato)

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

## 27 luglio 2026 — Impostazioni avanzate, quota sul punto, aggiungi punto prima (feedback utente diretto su screenshot della card, in lavorazione, non ancora rilasciato)

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

## 27 luglio 2026 — Rifinitura card di disegno (feedback utente diretto, in lavorazione, non ancora rilasciato)

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

## 27 luglio 2026 — Testo pulsante conferma annulla editing (P1, in lavorazione, non ancora rilasciato)

`_confirmCancel` (`lib/features/draw_route/draw_route_controls.dart`) è condiviso tra la
creazione di un nuovo percorso e la modifica di una traccia esistente (`cancelEditing`
gestisce entrambi i casi, vedi `_editSnapshot`). Il `confirmLabel` del dialog era
"Annulla percorso" in entrambi i casi — fuorviante quando si sta modificando una traccia già
salvata (non si sta affatto annullando "il percorso", solo le modifiche non salvate). Fix a
una riga: `confirmLabel: 'Annulla modifiche'`.

---

## 27 luglio 2026 — Traccia "fantasma" dopo import GPX (P1, in lavorazione, non ancora rilasciato)

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

## 27 luglio 2026 — Tema rispettato fin dal primo frame (P1 #1, in lavorazione, non ancora rilasciato)

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

## 27 luglio 2026 — Altezza fissa per la card Novità/Roadmap (in lavorazione, non ancora rilasciato)

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

## 24 luglio 2026 — Icone provider cloud distinte (in lavorazione, non ancora rilasciato)

In Impostazioni → Sincronizzazione cloud, la riga di accesso/account mostrava sempre
`CupertinoIcons.cloud`/`cloud_fill` sia per iCloud sia per Google Drive — a colpo d'occhio
indistinguibili. `_CloudSection` (`lib/features/settings/settings_screen.dart`) ora sceglie
l'icona in base al `cloudProviderProvider` attivo: **iCloud** resta la nuvola (coerente con
l'iconografia reale del servizio Apple), **Google Drive** usa `Icons.add_to_drive` (Material,
triangolo/cartella — nessun asset o dipendenza aggiuntiva, `uses-material-design: true` già
presente). Il selettore segmentato (`_CloudProviderSelector`) resta solo testuale, non
toccato: il problema segnalato era specificamente l'icona della riga account.

---

## 24 luglio 2026 — Roadmap sintetica in-app (in lavorazione, non ancora rilasciato)

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
