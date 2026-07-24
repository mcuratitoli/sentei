# Analitiche d'uso — analisi

> Roadmap P6 ("Accesso & analitiche"). Analisi 24 lug 2026, **nessuna implementazione** —
> richiesta esplicitamente solo l'analisi, per decidere come procedere.
>
> **Aggiornamento 24 lug 2026 (1):** la privacy policy **non è un vincolo** in questa fase
> (due soli tester, entrambi consapevoli) — vedi nota in fondo alla sezione "Vincoli". Le
> metriche elencate dall'utente nella richiesta iniziale (tracce salvate, aperture app,
> accessi Mapbox, utenti che sincronizzano) erano **proposte indicative**, non requisiti:
> questa versione ragiona a tutto campo su cosa sarebbe davvero utile sapere per Sentèi.
>
> **Aggiornamento 24 lug 2026 (2):** l'utente ha una **VM DigitalOcean già pagata e
> disponibile** — nessun costo aggiuntivo accettabile oltre quello già in conto, ma massimo
> controllo granulare desiderato. Questo sposta la scelta verso il **self-hosting** invece
> delle proposte cloud SaaS della versione precedente (§5, ora riclassificate come
> alternative). Login **confermato non necessario** (vedi §4/§6) — decisione già presa
> dall'utente, resta fuori scope.

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

**Per l'obiettivo "non superare il tier gratuito Mapbox" specificamente**, c'è un'opzione
ancora più diretta della dashboard: Mapbox permette di **impostare soglie di allerta** su
account/token (Account → Usage & billing → alert a es. 75%/90% del tier gratuito) con
notifica via email automatica **prima** di sforare — zero codice, zero infrastruttura,
configurazione una tantum. Per l'obiettivo specifico "evitare costi", questa è la risposta
più diretta che esista, indipendentemente da qualunque altra scelta di questo documento.

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

## 5. Con una VM propria: le opzioni self-hosted

Avere una VM DigitalOcean già pagata cambia il calcolo: il costo marginale di self-hostare
diventa **zero** (paghi comunque la VM, a prescindere), e si ottiene esattamente ciò che
l'utente ha chiesto — **una dashboard operativa centralizzata**, sotto controllo diretto,
senza dipendere da un vendor terzo per i dati. La domanda diventa: *quanto self-hosting*, e
*quanto della VM ci si può permettere di dedicarci* — dipende dalle specifiche del droplet
(RAM soprattutto: gli stack "full" di alcuni tool open-source sono pensati per VM robuste,
non per il droplet più economico). Le opzioni sotto sono ordinate per impronta di risorse,
dalla più leggera alla più pesante.

### Layer 1 — Errori/affidabilità (il più prezioso, §1)

| Opzione | Cos'è | Impronta risorse | Note |
|---|---|---|---|
| **GlitchTip** (self-hosted) | Riscrittura open-source di Sentry, **compatibile con il protocollo/SDK Sentry** (`sentry_flutter` lato app, punti solo il DSN al tuo GlitchTip) | Leggera: app + Postgres + Redis, confortevole anche su droplet piccoli (1-2 GB RAM) | **Consigliata.** Ottieni gratis ciò che è difficile rifare bene da soli: raggruppamento errori, stack trace, breadcrumb, symbolication — con l'SDK ufficiale Flutter, zero reinvenzioni. |
| **Sentry self-hosted (stack completo)** | Il progetto originale, self-hostabile | Pesante: la doc ufficiale consiglia **16+ GB RAM** (Kafka, ClickHouse, Snuba, Symbolicator…) | Sconsigliata a questa scala — quasi certamente sovradimensionato per un droplet hobby. |
| **Fatto in casa** (endpoint + tabella) | Un piccolo endpoint che riceve `{errore, stacktrace, tag}` e scrive su Postgres/SQLite | Minima | Massimo controllo, ma **si perde gratis** ciò che Sentry/GlitchTip danno: raggruppamento/deduplica errori (algoritmo non banale da rifare bene), sessioni, breadcrumb automatici. Va bene se l'obiettivo è anche *imparare/costruire tutto*, non solo avere il segnale. |

### Layer 2/3 — Adozione feature + conteggi (§1)

| Opzione | Cos'è | Impronta risorse | Note |
|---|---|---|---|
| **Umami** (self-hosted) | Analytics privacy-friendly, leggero, con API per eventi custom + UI pronta | Molto leggera: un container Node + Postgres/MySQL | **Consigliata.** Il più leggero dei tool "con UI pronta"; eventi custom (`track_saved`, `sync_connected`, ecc.) supportati nativamente. |
| **Plausible** (self-hosted) | Simile a Umami, nato per siti web | Da leggera a media (alcune versioni usano ClickHouse) | Alternativa valida, verificare la versione/requisiti al momento dell'installazione. |
| **PostHog** (self-hosted, "hobby deploy") | Più ricco (funnel, session replay, feature flag) | Pesante: basato su ClickHouse, la doc consiglia **4+ GB RAM** solo per l'hobby deploy | Probabilmente overkill per adottare solo 5-8 eventi custom — la ricchezza in più non serve a questa scala. |
| **Fatto in casa** (endpoint + tabella + Grafana/Metabase) | Stesso endpoint del Layer 1 (o uno gemello), righe in Postgres, dashboard costruita a mano | Minima | **Massimo controllo possibile**: ogni pannello è una query SQL tua, nessun tool con la sua opinione su come mostrare i dati. Costo: costruisci tu i pannelli invece di trovarli già pronti. |

### La dashboard unificata (quello che hai chiesto esplicitamente)

Sia GlitchTip sia Umami (e Plausible) parlano **Postgres** — questo rende naturale
aggiungere **Grafana** (leggero, un solo container, gira bene anche su droplet piccoli) come
livello di visualizzazione **sopra entrambi**: un'unica dashboard con pannelli che
interrogano sia gli errori (GlitchTip) sia gli eventi prodotto (Umami), invece di avere due
schermate separate. Grafana supporta anche alert (es. "avvisami se gli errori `brouter`
superano N in un'ora") — utile proprio per il Livello 1.

Per Mapbox: gli **alert nativi Mapbox (§3)** restano la fonte autorevole per "sto per
sforare il tier gratuito" (solo Mapbox conosce i numeri esatti di fatturazione). Se vuoi
comunque un segnale *tuo*, correlato nel tempo con gli altri eventi nello stesso Grafana, puoi
loggare un evento leggero (`map_session_start`) come **proxy** — non sostituisce il dato di
billing reale di Mapbox, ma ti dà un trend visibile accanto al resto senza uscire dalla tua
dashboard.

### Architettura consigliata (concreta)

```
App Flutter
  ├─ sentry_flutter → GlitchTip (Docker: app + Postgres + Redis)
  └─ evento HTTP custom → Umami (Docker: app + Postgres)
                                        ↓
                              Grafana (Docker: 1 container)
                              legge entrambi i Postgres → dashboard unica
```

- **Tutto su Docker Compose sulla VM esistente**, nessun servizio a pagamento oltre la VM
  già in conto.
- Stima impronta totale: 4-5 container leggeri (GlitchTip app+worker, Postgres, Redis,
  Umami, Grafana) — confortevole su un droplet da **2 GB RAM**, probabilmente fattibile
  anche su 1 GB con qualche accorgimento (limitare memoria di Postgres/Redis), ma dipende
  da cos'altro gira già sulla VM.
- Se preferisci **massimo controllo invece di velocità**: sostituisci Umami con
  l'"endpoint fatto in casa + Grafana" del Layer 2/3 — perdi la UI pronta di Umami ma guadagni
  controllo totale su schema dati e pannelli, restando comunque leggerissimo. GlitchTip
  per gli errori lo terrei comunque: è l'unico pezzo dove "farlo in casa" costa più di
  quanto rende (raggruppamento errori non banale).

### Alternative cloud SaaS (versione precedente dell'analisi, ora secondarie)

Restano valide come opzioni se in futuro non volessi più gestire nulla sulla VM (es. la VM
cambia, si spegne, ecc.): **Firebase (Crashlytics + Analytics)** — più rapido da avviare,
ma introduce una dipendenza Google e un costo (seppur nel tier gratuito) fuori dal tuo
controllo diretto; oppure **Sentry cloud + PostHog cloud** — stessi SDK di GlitchTip/Umami
(compatibili), quindi è anche possibile **cambiare idea in seguito senza riscrivere il
client**: puntare lo stesso `sentry_flutter` da GlitchTip a Sentry cloud (o viceversa) è
solo un cambio di DSN.

### Schema eventi proposto (valido per qualunque opzione sopra)

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

## 6. Login (Google/Apple) — confermato fuori scope

Non cambia rispetto alla versione precedente dell'analisi, e l'utente ha nel frattempo
confermato la direzione: introdurre un vero login applicativo (oggi Google Sign-In è solo
autorizzazione OAuth per Drive, iCloud usa l'account di sistema) comporta un gate in-app,
**Sign in with Apple obbligatorio su iOS** (Guideline 4.8) se offri login social,
gestione/cancellazione account (Guideline 5.1.1(v)), e — soprattutto — non aggiunge nulla
che l'architettura self-hosted di §5 non dia già per rispondere alle domande di analitica.
Evitarlo "slega da problematiche" (parole dell'utente) senza perdere nulla sul fronte
analitiche. Resta un quesito a sé in `docs/ROADMAP.md` (P6), da riaprire solo per un motivo
diverso (continuità multi-dispositivo, supporto utenti diretto).

---

## 7. Raccomandazione

1. **Subito, gratis, indipendentemente da tutto il resto:** Mapbox Dashboard + **alert di
   soglia** (§3) e App Store Connect Analytics. Copre "accessi Mapbox" (compreso l'obiettivo
   esplicito "non sforare il tier gratuito") e un primo polso su "app aperta", a costo zero.
2. **Per il resto, self-hosting sulla VM già disponibile (§5)**, non SaaS: **GlitchTip**
   (errori, Livello 1 — il valore più alto) + **Umami o endpoint fatto in casa** (adozione
   feature, Livello 2/3) + **Grafana** sopra entrambi per la dashboard unica centralizzata
   richiesta. Costo marginale zero (la VM è già pagata), nessuna dipendenza da vendor
   esterni per i dati, massimo controllo — esattamente i tre criteri posti dall'utente.
3. **Non reinventare il raggruppamento errori**: usare `sentry_flutter` verso GlitchTip
   invece di costruire da zero anche il Layer 1, dove il "fatto in casa" costa più di quanto
   rende.
4. **Login confermato fuori scope** (§6) — nessuna delle opzioni sopra lo richiede.

Nessuna implementazione fatta: in attesa di conferma sull'architettura (GlitchTip+Umami+
Grafana vs tutto "fatto in casa" vs mix) prima di procedere. La scelta esatta tra Umami e
"fatto in casa" per il Layer 2/3, e le specifiche della VM (RAM/CPU, cosa gira già), sono i
due dettagli che restano da chiarire per dimensionare lo stack definitivo.
