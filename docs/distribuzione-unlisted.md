# Rilascio su App Store come app *Unlisted* — guida passo passo

> **Obiettivo:** portare Sentèi dall'attuale distribuzione TestFlight a una release
> **pubblicata sull'App Store ma non elencata** (Unlisted App Distribution): non compare
> in ricerca, classifiche, "ti potrebbe piacere". È raggiungibile **solo** da chi ha il
> link diretto (`https://apps.apple.com/app/id<APP_STORE_ID>`).
>
> App: **Sentèi**, bundle `com.mattiacuratitoli.sentei`, team Apple `W8XCSNY6V3`.
> Decisione di riferimento: `docs/ROADMAP.md` §P6. Flusso TestFlight (che resta valido
> in parallelo): `docs/testflight-amici.md`.

---

## "Non tracciata" = due cose distinte

| | Cos'è | Dove si imposta |
|---|---|---|
| **Unlisted App Distribution** | L'app non è elencata; solo link diretto | Richiesta separata ad Apple (form dedicato, passo 8) |
| **Privacy label "Data Not Collected" + nessun tracciamento** | La dichiarazione App Privacy: Sentèi non raccoglie dati né fa tracking ATT/IDFA | Questionario **App Privacy** in App Store Connect (passo 3) |

Vanno fatte **entrambe**. L'una non implica l'altra.

---

## Prerequisiti (verificare prima di iniziare)

- [ ] Apple Developer Program attivo per il team `W8XCSNY6V3`, e tu sei **Account Holder**
      o **Admin** (serve per il form Unlisted del passo 8).
- [ ] Record app già esistente in App Store Connect (c'è già: lo usi per TestFlight).
- [ ] Firma iOS di distribuzione già configurata (c'è già: gli upload TestFlight funzionano).
- [ ] `ITSAppUsesNonExemptEncryption` = `false` in `ios/Runner/Info.plist` (**già presente**,
      righe 13-14) → niente prompt "Missing Compliance".
- [ ] Privacy Policy pubblicata: `https://mcuratitoli.github.io/sentei/privacy-policy.html`
      (**già online** via GitHub Pages).
- [x] **Telemetria Mapbox: lasciata ON** (decisione Sentèi, 1 set 2026) → in App Privacy va
      **dichiarata** la raccolta dati di Mapbox, non si usa "Data Not Collected" (vedi passo 3).

---

## Passo 1 — Preparare la build da rilasciare

1. **Bump versione** in `pubspec.yaml`: da `1.0.0+10` a `1.0.0+11` (il build number deve
   essere **maggiore** dell'ultimo caricato, cioè 10). La *marketing version* può restare
   `1.0.0`.
2. **Allineare la documentazione nella stessa sessione** — esegui la
   [`docs/release-checklist.md`](release-checklist.md) per intero:
   `CHANGELOG.md`, `lib/ui/release_notes.dart` (`kReleaseNotes` + `kUpcomingHighlights`),
   `docs/CHANGELOG-DEV.md`, header di `docs/ROADMAP.md`, `README.md`.
3. **Build IPA** (stessi `--dart-define` di TestFlight/APK — token Mapbox pubblico `pk.…` e
   client id Google, **mai committati**, vedi `docs/android-apk-setup.md` per i valori):
   ```bash
   flutter build ipa --release \
     --dart-define=MAPBOX_TOKEN=pk.<token pubblico> \
     --dart-define=GOOGLE_CLIENT_ID=<client id>.apps.googleusercontent.com
   ```
   Output: `build/ios/ipa/sentei.ipa`.
4. **Upload** con l'app **Transporter** (Mac App Store, gratis): trascina `sentei.ipa` →
   **Deliver**. Vedi `docs/testflight-amici.md` Parte A per i dettagli.
5. Attendi ~5–15 min: la build compare in **App Store Connect → Sentèi → TestFlight**
   (da *Processing* a *Ready to Submit*) **e** diventa selezionabile nella sezione App Store.
6. *(Consigliato)* Assegna la build al gruppo esterno **Amici** in TestFlight e falla
   provare 1–2 giorni **prima** di sottoporla alla review App Store. La **stessa** build
   serve sia TestFlight sia App Store — non serve ricompilare.

> ⚠️ La build usata per l'App Store deve essere **identica** a quella testata su TestFlight.
> Se cambi qualcosa, incrementa di nuovo il build number e ricarica.

---

## Passo 2 — App Information (metadati a livello app)

**App Store Connect → Sentèi → (colonna sinistra) General → App Information**

1. **Localizable Information** (lingua primaria, presumibilmente Italiano):
   - **Name:** `Sentèi`
   - **Subtitle:** max 30 caratteri, es. `Sentieri e tracciati delle Alpi`
   - **Privacy Policy URL:** `https://mcuratitoli.github.io/sentei/privacy-policy.html`
2. **General Information:**
   - **Category → Primary:** `Navigation` (secondaria opzionale: `Travel`).
   - **Content Rights:** l'app mostra contenuti di terzi (tile Mapbox, dati OpenStreetMap).
     Rispondi **"Sì, contiene/usa contenuti di terzi"** e conferma di averne i diritti
     (ToS Mapbox + OSM/ODbL con **attribuzione mostrata in-app**).
   - **Age Rating:** compila il questionario → risultato atteso **4+** (nessun contenuto
     sensibile).
3. **Apple ID dell'app:** annota il numero a 10 cifre in *General Information → Apple ID*.
   Serve al passo 8 e per costruire il link finale.

---

## Passo 3 — App Privacy (la dichiarazione "non tracciata")

**App Store Connect → Sentèi → App Privacy → Get Started**

Domanda chiave: *"Do you or your third-party partners collect data from this app?"*

**Sentèi in sé non raccoglie nulla:** nessun account, nessuna analitica di terze parti,
nessun IDFA. Da chiarire prima di rispondere:

| Componente | Cosa fa coi dati | Impatto sulla dichiarazione |
|---|---|---|
| `geolocator` | Posizione **solo on-device** per HUD/mappa, foreground | Non "raccolta" da te — non trasmessa |
| `photo_manager` | Match spaziale foto **on-device**; solo miniatura nel JSON del **tuo** cloud | Non "raccolta" da te |
| `google_sign_in` / `googleapis` | OAuth verso il **Drive dell'utente** (scope `drive.file`), su iniziativa dell'utente | Accesso al cloud dell'utente, non raccolta dati da parte tua |
| **Mapbox Maps SDK** | Telemetria d'uso (posizione approssimata, device, uso) **attiva di default** | ⚠️ **Se attiva, va dichiarata** |
| Controllo aggiornamenti (`latest.json`) | GET di un file statico pubblico; l'IP è tecnicamente visibile a GitHub Pages | Nessun dato raccolto (fetch di file statico) |

**Decisione presa (Sentèi, 1 settembre 2026): la telemetria Mapbox resta ATTIVA.** Di
conseguenza in App Privacy **non** si dichiara "Data Not Collected": va dichiarato ciò che il
Mapbox Maps SDK raccoglie, secondo la sua informativa
(<https://www.mapbox.com/legal/privacy>):

| Categoria dati | Uso dichiarato | Linked to identity | Used for tracking |
|---|---|---|---|
| **Location** (approssimata/precisa) | App Functionality, Analytics | **No** | **No** |
| **Usage Data** | Analytics | **No** | **No** |
| **Diagnostics** | App Functionality | **No** | **No** |

Nessun **altro** componente dell'app aggiunge raccolta dati (vedi tabella sopra: `geolocator`,
`photo_manager`, `google_sign_in`, controllo aggiornamenti non contano). Alla domanda
**"Used for tracking"** del questionario si risponde comunque **No** a livello app: Mapbox non
fa tracking cross-app ATT/IDFA, coerente con §6 della privacy policy. La `privacy-policy.html`
§5 già menziona la telemetria Mapbox — nessuna modifica necessaria lì.

**Tracking:** rispondi sempre **"No"** — Sentèi non fa ATT, non usa IDFA, non condivide dati
con data broker. (Coerente con §6 della privacy policy: "nessun tracciamento a fini di
marketing".)

**Privacy manifest (`PrivacyInfo.xcprivacy`):** dal 2024 Apple lo richiede. I plugin recenti
(Mapbox, `shared_preferences`, `path_provider`, `package_info_plus`…) portano il proprio, ma
il target **Runner** spesso ne vuole comunque uno che dichiari le *required-reason API* usate
(es. `NSPrivacyAccessedAPICategoryUserDefaults`, timestamp file). Se l'upload o la review
segnala l'assenza, aggiungi `ios/Runner/PrivacyInfo.xcprivacy`.

---

## Passo 4 — Pricing and Availability

**App Store Connect → Sentèi → Pricing and Availability**

1. **Price:** `Free` (tier 0).
2. **Availability:** lascia **tutti i paesi** (per un'app unlisted non cambia nulla; limitare
   crea solo attriti se un amico è all'estero).
3. **Non esiste** qui un interruttore "unlisted": lo status Unlisted lo concede Apple
   separatamente (passo 8). **Finché non è concesso, se rilasci l'app è pubblica a tutti gli
   effetti** — da qui l'ordine dei passi 6→8→9.

---

## Passo 5 — Compilare la versione (la scheda "1.0")

**App Store Connect → Sentèi → (colonna sinistra, sotto "App Store") → 1.0 Prepare for Submission**

1. **Screenshot** (obbligatori, PNG/JPG senza canale alfa, risoluzione esatta del device):
   - **iPhone 6.9"** — `1320 × 2868` (portrait) — **set obbligatorio**.
   - iPhone 6.5" — `1242 × 2688` — set opzionale di fallback.
   - iPad 13" — solo se dichiari il supporto iPad.
   - Da 1 a 10 immagini. Generali sul simulatore: `flutter run -d <sim>`, poi
     `Cmd+S` sul Simulator (o `xcrun simctl io <udid> screenshot out.png`), su un modello con
     display 6.9".
2. **Promotional Text** (opzionale, 170 caratteri, modificabile **senza** review).
3. **Description** (max 4000 caratteri): cosa fa l'app, in italiano. Puoi partire dal
   `README.md` e da `CHANGELOG.md`.
4. **Keywords** (100 caratteri, separate da virgola): **obbligatorie anche se unlisted**
   (non servono alla scoperta, ma ASC le pretende). Es.
   `escursionismo,sentieri,CAI,trekking,GPX,dislivello,mappa,offline,Alpi`.
5. **Support URL** (obbligatorio): `https://github.com/mcuratitoli/sentei` o la pagina Pages.
6. **Marketing URL** (opzionale).
7. **Version → What's New in This Version:** per la 1.0 basta `Prima versione pubblica.`
   Dalla 1.0.1 in poi: incolla la voce di `CHANGELOG.md`.
8. **Build:** clicca **"Select a Build" / "+"** e scegli `1.0.0 (11)` (dal passo 1). Se non
   compare, l'upload non è ancora stato processato — attendi.
9. **App Review Information:**
   - **Sign-in required?** → **No** (Sentèi è pienamente usabile senza iCloud/Drive).
   - **Contact:** nome, cognome, telefono, email `m.curatitoli@gmail.com`.
   - **Notes** — importante, riduce i rimbalzi. Esempio:
     > App per l'escursionismo. Per provarla: schermata mappa → "Disegna" → tocca due o più
     > punti sulla mappa: viene tracciato un percorso lungo i sentieri con distanza e
     > dislivello. Salvataggio locale in "I miei tracciati". La sincronizzazione iCloud /
     > Google Drive è **opzionale** e non necessaria per usare l'app; il login Google serve
     > solo ad accedere al Drive dell'utente (scope `drive.file`), non è un login
     > applicativo. Le mappe funzionano offline dopo aver scaricato un'area da
     > Impostazioni → Mappe offline.
   - **Attachment** (opzionale): breve video demo.
10. **Version Release:** seleziona **"Manually release this version"**.
    *Non* "Automatically" e *non* la release a fasi — così, dopo l'approvazione, l'app resta
    in *Pending Developer Release* e tu la pubblichi solo **dopo** aver ottenuto lo status
    Unlisted (passo 9).
11. **Export Compliance:** se chiesto (non dovrebbe, vista la chiave in `Info.plist`),
    rispondi che **non** usi crittografia non esente (HTTPS standard è esente).
12. **Advertising Identifier (IDFA):** **No**.

Salva tutto (**Save**, in alto a destra).

---

## Passo 6 — Inviare alla review App Store

1. In alto a destra nella scheda della versione: **"Add for Review"** → poi
   **"Submit to App Review"** (l'etichetta del pulsante blu cambia tra le versioni di ASC).
2. Stato: **Waiting for Review** → **In Review** → **Pending Developer Release**
   (perché hai scelto *Manually release*) oppure **Rejected**.
3. Tempi tipici: **24–48 h**, a volte meno.
4. **Se rifiutata:** apri il **Resolution Center**, leggi la motivazione, correggi,
   riinvia. Rimbalzi più probabili per Sentèi:
   - **Guideline 4.8 (Sign in with Apple):** scatta *solo* se offri un login social a
     livello app. Qui Google serve solo per il Drive → chiariscilo nelle Notes (passo 5.9).
   - **Guideline 5.1.1 (Privacy):** disallineamento tra ciò che dichiari in App Privacy e
     ciò che l'app fa (es. telemetria Mapbox non dichiarata). Vedi passo 3.
   - **Guideline 2.1 (Performance / crash):** Notes migliori + eventuale video.

> ⚠️ **Non** premere "Release This Version" quando arriva l'approvazione. Prima il passo 7–8.

---

## Passo 7 — (In parallelo alla review) Preparare la richiesta Unlisted

Puoi inviare la richiesta **prima o dopo** l'approvazione, purché l'app sia in uno stato
distribuibile. Il momento più pulito è **appena la versione è in *Pending Developer
Release*** (approvata ma non pubblicata). Prepara intanto:

- **Apple ID dell'app** (numero a 10 cifre, dal passo 2.3).
- **Nome app:** Sentèi.
- **Motivazione** (2–3 frasi), es.:
  > Sentèi è un progetto personale, gratuito e non commerciale, distribuito a una cerchia
  > ristretta di amici e tester. Non è destinato alla distribuzione pubblica sull'App Store:
  > chiedo la distribuzione *unlisted* per condividerlo tramite link diretto.

---

## Passo 8 — Richiedere Unlisted App Distribution

1. Vai su **<https://developer.apple.com/contact/request/unlisted-app>**.
2. Accedi con l'Apple ID **Account Holder / Admin** del team `W8XCSNY6V3`.
3. Compila: Apple ID dell'app, nome, motivazione (passo 7).
4. **Invia.** Apple valuta la richiesta **separatamente** dalla review: tempi da **pochi
   giorni a ~2 settimane**. Ricevi l'esito via email.
5. Ad approvazione, la disponibilità dell'app diventa **automaticamente unlisted**: sparisce
   da ricerca, classifiche, sezioni "consigliati" e "ti potrebbe piacere". Resta
   raggiungibile dal **link diretto** e via Apple Business/School Manager. URL, recensioni e
   valutazioni eventuali restano invariati.

---

## Passo 9 — Pubblicare

1. Attendi **entrambe** le condizioni: versione in *Pending Developer Release* **e** email
   di concessione Unlisted.
2. App Store Connect → Sentèi → scheda della versione → **"Release This Version"**.
3. L'app è ora **live ma non elencata**.
4. **Link da condividere:** `https://apps.apple.com/app/id<APP_STORE_ID>`
   (sostituisci con l'Apple ID a 10 cifre). Mettilo anche nel campo `ios.url` di
   `latest.json` — vedi [`docs/notifica-aggiornamenti.md`](notifica-aggiornamenti.md).

> **Se hai fretta e accetti una finestra pubblica:** puoi rilasciare (passo 9.2) subito dopo
> l'approvazione della review e richiedere Unlisted dopo. In quella finestra (giorni)
> l'app è cercabile da chiunque. Per un'app così di nicchia è un rischio basso, ma la via
> pulita è aspettare.

---

## Passo 10 — Aggiornamenti futuri (dopo la 1.0)

Per ogni nuova versione:

1. `pubspec.yaml`: bump build number (`1.0.0+12`, `+13`, …) e, se cambia, marketing version.
2. Esegui `docs/release-checklist.md` **nella stessa sessione** (inclusa la riga
   `latest.json`, vedi doc collegato).
3. `flutter build ipa` → upload con Transporter.
4. App Store Connect → **"+ Version or Platform"** → crea es. `1.0.1` → compila
   **What's New** (da `CHANGELOG.md`) → seleziona la build → **"Manually release"** →
   **Submit to App Review**.
5. **Ogni aggiornamento passa dalla review** (~24–48 h): non c'è l'esenzione "solo la prima
   build" che hanno i gruppi esterni TestFlight.
6. Ad approvazione → **"Release This Version"**. Gli utenti si aggiornano da soli dall'App
   Store (se hanno gli aggiornamenti automatici attivi).
7. Lo status **Unlisted persiste** tra le versioni: non va richiesto di nuovo.
8. **TestFlight resta in parallelo:** carichi la build, la fai provare al gruppo *Amici*,
   poi sottoponi la stessa build alla review App Store.

---

## Errori comuni

| Sintomo | Causa / rimedio |
|---|---|
| "Missing Compliance" dopo l'upload | Manca la chiave encryption — già presente in `Info.plist`; se ricompare, rispondi "No" all'export compliance nella scheda versione. |
| Build non selezionabile nella scheda App Store | Ancora in *Processing*, oppure build number ≤ a uno già usato. |
| Privacy Policy URL "non valido" in review | Verifica che `https://mcuratitoli.github.io/sentei/privacy-policy.html` si apra nel browser (GitHub Pages: repo → Settings → Pages → branch `main`, cartella `/docs`). |
| Rifiuto 4.8 (Sign in with Apple) | Chiarisci nelle Review Notes che Google = accesso al Drive dell'utente, non login applicativo. |
| Rifiuto 5.1.1 (privacy) | Allinea la dichiarazione App Privacy a ciò che l'app fa davvero (telemetria Mapbox: disattivala o dichiarala). |
| L'app è cercabile da tutti dopo il rilascio | Unlisted non ancora concesso: hai rilasciato prima del passo 8. Attendi l'email; nel frattempo puoi rimettere la versione in stato non pubblicato solo con "Remove from Sale". |

---

## Checklist rapida

- [ ] `pubspec.yaml` bumpato + `release-checklist.md` eseguita
- [ ] IPA buildato e caricato con Transporter
- [ ] (opz.) build provata dal gruppo TestFlight *Amici*
- [ ] App Information: categoria, content rights, age rating, privacy policy URL
- [ ] App Privacy: telemetria Mapbox ON → dichiarata (Location / Usage Data / Diagnostics, non *linked*, no tracking); "Used for tracking" a livello app = No
- [ ] Pricing: Free, tutti i paesi
- [ ] Versione: screenshot 6.9", descrizione, keyword, support URL, What's New, build, Review Notes
- [ ] Version Release = **Manually release**
- [ ] Submit to App Review → attesa *Pending Developer Release*
- [ ] Form Unlisted inviato (Account Holder/Admin) con Apple ID dell'app
- [ ] Email di concessione Unlisted ricevuta
- [ ] **Release This Version**
- [ ] Link `apps.apple.com/app/id…` salvato e messo in `latest.json`

---

Vedi anche: [`testflight-amici.md`](testflight-amici.md) · [`notifica-aggiornamenti.md`](notifica-aggiornamenti.md) · [`release-checklist.md`](release-checklist.md) · [`ROADMAP.md`](ROADMAP.md) §P6
