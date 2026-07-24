# Analitiche d'uso — analisi

> Roadmap P6 ("Accesso & analitiche"). Analisi 24 lug 2026, **nessuna implementazione** —
> richiesta esplicitamente solo l'analisi, per decidere come procedere.
>
> **Aggiornamento 24 lug 2026:** la privacy policy **non è un vincolo** in questa fase (due
> soli tester, entrambi consapevoli) — vedi nota in fondo alla sezione "Vincoli". Le metriche
> elencate dall'utente nella richiesta iniziale (tracce salvate, aperture app, accessi
> Mapbox, utenti che sincronizzano) erano **proposte indicative**, non requisiti: questa
> versione ragiona a tutto campo su cosa sarebbe davvero utile sapere per Sentèi, oltre alla
> lista di partenza, e chiude con due proposte di implementazione concrete.

---

## 1. Cosa conterebbe davvero, per Sentèi, in questa fase

Prima di scegliere uno strumento, vale la pena chiedersi: **quali numeri cambierebbero
davvero una decisione**, per un progetto hobby di uno sviluppatore solo, con 2 tester oggi e
un gruppo di amici in prospettiva (Roadmap P6)? Non tutte le metriche hanno lo stesso
valore. Le ordino per quanto informerebbero le prossime scelte, non per quanto sono facili
da raccogliere.

### Livello 1 — Affidabilità: quello che oggi è invisibile e ha già causato bug reali

Sentèi dipende da **quattro servizi terzi gratuiti e non garantiti** (BRouter, OSM2CAI,
Overpass, Terrarium/tile Mapbox) più iCloud/Google Drive. La cronologia del progetto
(`docs/CHANGELOG-DEV.md`) mostra che i problemi più seri finora sono stati proprio guasti
**silenziosi** di questi servizi, scoperti solo grazie a un tester che si accorgeva di un
sintomo:

- Il bug "ricerca fallita ≠ vuota" (1 lug 2026): i servizi segnavia inghiottivano errori di
  rete/timeout e la traccia restava marcata come "nessun segnavia trovato" invece che "la
  ricerca è fallita, riprova" — scoperto solo perché un tester ha notato un caso specifico
  (Bivacco Ravelli) senza numeri sentiero.
- BRouter che degrada un tratto a linea retta per timeout del server pubblico (documentato
  più volte, es. *"operation killed by thread-priority-watchdog"*).
- Il codice ha oggi **41 blocchi `catch (_) { }`** che ignorano silenziosamente l'errore
  (best-effort esplicito in alcuni casi, ma senza alcuna visibilità se il tasso di
  fallimento sale).

**Perché conta più delle metriche "di prodotto":** sapere che BRouter fallisce nel 30% dei
tratti su una certa zona, o che la sync iCloud fallisce spesso su un device, ti direbbe
*cosa aggiustare domani*. Sapere "quante volte si è aperta l'app" no. A questa scala, con
pochi utenti, un solo crash o un solo servizio che degrada silenziosamente **è già un
segnale**, non serve un campione grande per essere utile — il contrario delle metriche di
prodotto "vanity" che servono numeri alti per dire qualcosa.

### Livello 2 — Adozione delle feature: aiuta a pesare la roadmap

Diverse voci della roadmap sono "epiche" costose (es. P1#11 "Foto lungo il percorso", *SP
13*) prese di petto sulla fiducia che serviranno. Sapere se le feature già spedite vengono
**davvero toccate** aiuterebbe a validare quella fiducia prima di investirci ancora:

- Variante di tema scelta (Standard/Notturno/Risparmio energetico) — la "Notturno" è stata
  pensata apposta per l'uso in montagna: viene scelta?
- Tracciato disegnato a mano vs importato da GPX — dice se il flusso principale è "creo qui"
  o "porto da fuori".
- Download aree offline usato o no — è dichiarato "priorità alta" nel CLAUDE.md, ma è
  davvero usato?
- Provider di sync scelto (iCloud vs Google Drive) e se la sync viene poi **usata** dopo il
  primo collegamento (non solo "connesso una volta e mai più sincronizzato").
- Vista Satellite vs Outdoors vs Scura — quale si usa per davvero.
- Apertura delle legende (difficoltà CAI, abbreviazioni) — dice se sono scoperte/utili o
  ignorate.

### Livello 3 — Le metriche "di conteggio" della richiesta iniziale

Aperture app, tracce salvate, "quanti utenti sincronizzano" nel senso di conteggio grezzo:
utili come polso generale, ma da sole dicono poco senza il livello 1/2 sopra. Restano nella
proposta (sono economiche da avere una volta strumentato il resto), ma non sarebbero, da
sole, la ragione per costruire qualcosa.

### Ho scartato (per ora)

- **Session replay / heatmap** (tipici di tool come PostHog/Firebase): utili per prodotti
  con UX da ottimizzare su grandi numeri; con 2-10 utenti che sono amici e danno feedback a
  voce, il segnale in più non giustifica l'invasività.
- **Metriche di performance/frame rate**: utili più avanti se emergono lamentele su
  lentezza/jank; oggi nessun segnale che serva.

---

## 2. Vincoli (aggiornati)

- **Privacy policy**: **non è più un freno** — l'utente ha deciso che con due tester
  consapevoli è pienamente accettabile modificarla senza cerimonie. Resta comunque buona
  norma **tenerla aggiornata e onesta** (repo pubblico, §9 CLAUDE.md) — un paio di frasi,
  non una riscrittura drammatica. **Attenzione futura:** se/quando la distribuzione si
  allarga oltre la cerchia stretta (Roadmap P6, gruppo "Amici"), vale la pena ridare
  un'occhiata a cosa si raccoglie e a come è comunicato, perché i nuovi tester potrebbero
  non essere consapevoli quanto i due attuali — non è un blocco oggi, è un promemoria per
  quando cambierà la scala.
- **Zero backend** resta comunque una scelta architetturale dichiarata (`CLAUDE.md` §2): non
  è vietato uscirne, ma è una decisione da prendere con consapevolezza, non un dettaglio.
- **Effort**: sei l'unico sviluppatore — qualunque soluzione che richieda manutenzione
  continua (dashboard da guardare, infra da tenere in piedi) ha un costo ricorrente, non
  solo iniziale.

---

## 3. Quick win a costo zero, prima di scrivere codice

| Metrica | Fonte già esistente | Costo |
|---|---|---|
| Accessi Mapbox | Dashboard Mapbox (account.mapbox.com → Statistics): map load/tile request nel tempo | Zero, già lì |
| Aperture app / sessioni (aggregato) | App Store Connect → Analytics (iOS, già attivo su TestFlight); Play Console Statistics quando pronto (Android) | Zero, grana grossa |

Vale sempre la pena guardarle per prime — coprono due voci della richiesta iniziale senza
scrivere nulla.

---

## 4. Perché "login" non risolve, da solo, "chi sincronizza"

Resta valido indipendentemente da tutto il resto: **Google Drive** ha già un proxy gratuito
(Google Cloud Console → schermata di consenso OAuth mostra quanti hanno dato il consenso).
**iCloud** no: usa `icloud_storage` (contenitore Drive, non CloudKit database), e Apple non
espone alcuna dashboard sull'uso di iCloud Drive della tua app. Un login separato in-app
(anche "Sign in with Apple") **non risolverebbe questo specifico buco**: ti direbbe chi ha
fatto login nella tua UI, non se quella persona ha *anche* la sync iCloud attiva — quel dato
vive solo lato Apple. L'unico modo per saperlo è un evento che l'app registra da sé quando la
sync riesce. Il login è quindi una decisione di prodotto indipendente (vedi §6), non un
prerequisito per le analitiche.

---

## 5. Due proposte di implementazione

Entrambe strumentano gli stessi tre livelli (§1): errori/affidabilità, adozione feature,
conteggi grezzi. Cambia lo strumento, non cosa si misura.

### Proposta 1 — Firebase (Crashlytics + Analytics): la più rapida e completa

Ora che la privacy policy non è un vincolo, questa è probabilmente la scelta con il miglior
rapporto valore/sforzo.

- **`firebase_crashlytics`**: crash automatici + `recordError()` per errori non fatali. Si
  aggancia **esattamente** ai punti già esistenti nel codice: i blocchi `catch` di
  `TrailLookupException` (`data/trails/`), `CloudSyncException` (`data/cloud/`), i fallback
  BRouter a linea retta (`brouter_routing_service.dart`), e via via gli altri dei 41
  `catch (_)` che oggi non riportano nulla. Avrebbe **intercettato prima** il bug "ricerca
  fallita ≠ vuota" invece di aspettare che un tester notasse il sintomo.
- **`firebase_analytics`**: eventi custom (`logEvent`) per il livello 2/3 — schema eventi
  proposto sotto. Sessioni/retention/DAU-WAU arrivano automatiche, senza codice aggiuntivo.
- **Setup**: file di configurazione (`google-services.json` / `GoogleService-Info.plist`) —
  stesso trattamento di `configs/` già in uso per i client OAuth Google (gitignorato, mai nel
  repo pubblico).
- **Costo**: tier gratuito ampiamente sufficiente a questa scala; nessun costo di
  manutenzione infrastrutturale (Google ospita tutto); dashboard pronte, zero query da
  scrivere a mano.
- **Contro onesto**: dipendenza da Google anche per chi non usa Google Drive; un file
  `PrivacyInfo.xcprivacy` (privacy manifest Apple) da mantenere ad ogni aggiornamento SDK —
  un costo piccolo, non bloccante.

### Proposta 2 — Sentry (errori) — eventualmente + PostHog (prodotto): più mirata, meno Google

Se preferisci non portare Google dentro l'app per questo, o vuoi uno strumento pensato
apposta per gli errori (più ricco di Crashlytics su stack trace/breadcrumb/contesto):

- **Sentry** (`sentry_flutter`): cattura crash + errori non fatali con contesto ricco
  (breadcrumb delle azioni precedenti, stack trace completo, tag per servizio: `brouter`,
  `osm2cai`, `overpass`, `icloud`, `google_drive`). Tier gratuito generoso (5k errori/mese),
  open-source (self-hostabile in futuro se mai volessi uscirne). Copre bene tutto il
  **Livello 1** (§1), il più prezioso.
- **PostHog** (`posthog_flutter`), opzionale, per il **Livello 2/3**: alternativa a Firebase
  Analytics con tier gratuito (1M eventi/mese), posizionata come più privacy-conscious,
  open-source e self-hostabile se in futuro si volesse riportare tutto "in casa" senza
  riscrivere il client. Funnel/retention inclusi.
- **Costo**: due strumenti invece di uno (due dashboard, due SDK) — leggermente più lavoro
  di setup rispetto alla Proposta 1, ma ciascuno più specializzato nel suo compito.
- **Vantaggio**: nessuna dipendenza Google; se un domani si volesse davvero "zero terze
  parti", PostHog è l'unico dei quattro (Firebase/Crashlytics/Sentry/PostHog) auto-ospitabile
  senza cambiare SDK lato client.

### Schema eventi proposto (valido per entrambe le proposte)

| Evento | Quando | Payload minimo |
|---|---|---|
| *(automatico)* crash/errore | catch esistenti + crash non gestiti | stack trace, tag servizio (`brouter`/`osm2cai`/`overpass`/`icloud`/`google_drive`/`terrarium`) |
| `track_saved` | fine disegno o import GPX | `origin: drawn\|imported` |
| `sync_connected` | login provider riuscito | `provider: icloud\|google_drive` |
| `sync_run` | "Sincronizza ora" completata | `provider`, `uploaded`, `downloaded` (già calcolati da `computeSyncPlan`) |
| `offline_area_downloaded` | fine download area offline | `kind: map\|elevation` |
| `theme_variant_selected` | cambio variante scura | `variant: standard\|notturno\|oled` |
| `map_style_switched` | cambio Outdoors/Satellite/Scura | `style` |
| `legend_opened` | apertura legenda difficoltà/abbreviazioni | `legend` |
| *(automatico)* sessioni/aperture | gestito dall'SDK stesso | — |

Nessun contenuto di traccia (geometria, nome, foto) in nessun evento — solo cosa succede,
mai il contenuto di cosa l'utente ha creato.

---

## 6. Login (Google/Apple) — resta una decisione separata

Non cambia rispetto alla versione precedente dell'analisi: introdurre un vero login
applicativo (oggi Google Sign-In è solo autorizzazione OAuth per Drive, iCloud usa
l'account di sistema) comporta un gate in-app, **Sign in with Apple obbligatorio su iOS**
(Guideline 4.8) se offri login social, gestione/cancellazione account (Guideline 5.1.1(v)),
e — soprattutto — non aggiunge nulla che la Proposta 1 o 2 non diano già per rispondere alle
domande di analitica. Vale la pena valutarlo **solo** se emerge un motivo diverso (es.
continuità multi-dispositivo legata all'identità, supporto utenti diretto), non per avere
"analitiche migliori".

---

## 7. Raccomandazione

1. **Subito, gratis:** guarda Mapbox Dashboard e App Store Connect Analytics (§3).
2. **Se si vuole strumentare per davvero:** priorità al **Livello 1** (errori/affidabilità)
   — è quello con il rapporto valore/sforzo più alto, ed è lo stesso indipendentemente dalla
   proposta scelta.
   - **Proposta 1 (Firebase)** se conta la velocità e non preoccupa la dipendenza Google.
   - **Proposta 2 (Sentry [+ PostHog])** se preferisci restare fuori dall'ecosistema Google
     o vuoi un'opzione auto-ospitabile in futuro.
3. **Il login resta una domanda a parte** (§6) — non necessaria per nessuna delle due
   proposte.

Nessuna implementazione fatta: in attesa di una decisione su quale proposta (o nessuna)
procedere.
