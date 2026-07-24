# Analitiche d'uso — analisi

> Roadmap P6 ("Accesso & analitiche"). Analisi 24 lug 2026, **nessuna implementazione** —
> richiesta esplicitamente solo l'analisi, per decidere come procedere.

## Obiettivo (dalla richiesta)

Capire quanto e come viene usata Sentèi, su base temporale (settimana/mese), senza
per forza richiedere un login. Metriche desiderate, testuali:

1. Quante tracce vengono create/salvate.
2. Quante volte viene aperta l'app.
3. Quanti accessi si fanno alle API Mapbox.
4. Quanti utenti sincronizzano i dati (iCloud/Google Drive).
5. In generale: "analitiche di utilizzo".

Valutare sia lo status quo (niente analitiche) sia un eventuale login, restando aperti a
tutto.

---

## Il vincolo che conta più di ogni scelta tecnica

Sentèi **ha già dichiarato pubblicamente**, nella privacy policy (`docs/privacy-policy.html`
§1) e nel README (§"Natura del progetto"):

> "non raccogliamo né conserviamo i tuoi dati personali su nostri sistemi"

e nel `CLAUDE.md` (§2, decisione architetturale fissata): **zero backend, privacy-first**.
Qualunque opzione qui sotto che preveda l'invio di dati — anche solo un contatore anonimo
— a un server (tuo o di terzi) **richiede aggiornare questa dichiarazione** e, trattandosi
di beta distribuita ad amici che l'hanno già installata sulla parola di quella promessa,
avvisarli esplicitamente del cambio (non è solo un dettaglio tecnico: è una promessa di
fiducia già fatta). Questo non blocca nessuna opzione, ma va tenuto in conto nel costo
reale di ciascuna, non solo in quello di sviluppo.

---

## Prima cosa: due delle quattro metriche sono già disponibili gratis, senza scrivere una riga

| Metrica richiesta | Fonte già esistente | Costo |
|---|---|---|
| **Accessi alle API Mapbox** | **Dashboard Mapbox** (account.mapbox.com → Statistics): map loads, tile request, per-token, con grafici temporali giornalieri/mensili | Zero — è già lì, serve solo guardarla. Nessun impatto privacy (Mapbox conta le richieste lato suo, indipendentemente da cosa fa l'app). |
| **Quante volte si apre l'app / quante installazioni** (aggregato, non per singolo evento in-app) | **App Store Connect → Analytics** (iOS, già configurato: sessioni, installazioni, dispositivi attivi, retention) e, quando sarà pronto Play Console (Roadmap P6), le **Play Console Statistics** equivalenti su Android | Zero. Copertura più grossolana di un evento custom `app_open` (niente breakdown per singola sessione/orario), ma per "quanto viene usata l'app in generale" è spesso sufficiente. |

**Conseguenza pratica:** per Mapbox e per un primo polso sull'utilizzo generale, **non
serve costruire nulla** — basta guardare due pannelli che esistono già e sono coerenti con
la privacy policy attuale (Mapbox è già dichiarato al punto 5 della privacy policy; App
Store Connect Analytics è dati che Apple fornisce allo sviluppatore su ciò che già gestisce
per la distribuzione, non una nuova raccolta).

Restano scoperte con questo solo approccio: **tracce create/salvate** e **quanti utenti
sincronizzano** (specialmente lato iCloud, vedi sotto) — per queste serve dell'altro.

---

## Perché "login" non risolve, da solo, "quanti utenti sincronizzano"

Un'osservazione che vale la pena esplicitare perché non è ovvia: **aggiungere un login non
dà automaticamente questo numero**.

- **Google Drive**: usa già OAuth (`google_sign_in`). Google Cloud Console mostra un
  conteggio approssimativo di utenti che hanno completato il consenso OAuth per il progetto
  (APIs & Services → schermata di consenso OAuth) — **già disponibile oggi**, senza alcun
  login aggiuntivo, perché l'"account" è già Google stesso.
- **iCloud**: usa `icloud_storage` (contenitore iCloud Drive), non CloudKit database — Apple
  **non espone alcuna dashboard** con "quanti utenti della tua app hanno iCloud Drive
  attivo". Un login separato in-app (es. "Sign in with Apple") **non cambia questo fatto**:
  Sign in with Apple identificherebbe l'utente nella tua UI, ma non ti direbbe se quello
  stesso utente ha *anche* attivato la sincronizzazione iCloud Drive — quell'informazione
  vive lato Apple, non lato tuo, con o senza login.

L'unico modo per sapere davvero "quanti utenti hanno sincronizzato" (iCloud **incluso**) è
un **evento anonimo che l'app stessa registra** quando la sincronizzazione va a buon fine
("ho sincronizzato con successo, provider = iCloud/Drive") — il login non è un prerequisito
per questo, è un problema ortogonale.

---

## Le opzioni per "tracce create/salvate" + "utenti che sincronizzano" (i due numeri che servono davvero costruire)

### Opzione A — Status quo, nessuna analitica custom

- **Costo:** zero.
- **Cosa hai:** Mapbox dashboard + App Store Connect/Play Console (vedi sopra). Nessun dato
  su tracce create o adozione della sync.
- **Coerenza:** perfetta con la privacy policy attuale, nessuna comunicazione da fare ai
  tester.
- Alla scala attuale (beta privata tra amici, poche decine di installazioni) potrebbe
  essere **onestamente sufficiente**: i numeri "grezzi" che contano di più (te lo usano? la
  mappa Mapbox costa? crashano?) sono già coperti gratis; il resto è curiosità in più, non
  decisioni operative bloccate dalla sua assenza.

### Opzione B — SDK di terze parti (es. Firebase Analytics / Google Analytics for Firebase)

- **Costo di sviluppo:** basso (poche ore: pacchetto `firebase_analytics`, inizializzazione,
  `logEvent()` nei punti giusti). Dashboard, funnel, retention già pronti.
- **Contro:**
  - Riporta l'app dentro l'infrastruttura Google anche per le funzioni che oggi non ce
    l'hanno (oggi Google è usato solo per chi *sceglie* Google Drive; l'analitica invece
    girerebbe per **tutti**, anche chi non ha mai toccato la sync) — è una rottura più
    profonda della promessa "zero backend" di quanto sembri.
  - Va aggiornata la privacy policy e la sezione "App Privacy" su App Store Connect
    (nutrition label: anche dati anonimi/aggregati vanno dichiarati come "Usage Data").
  - Serve un file `PrivacyInfo.xcprivacy` (privacy manifest, obbligatorio da Apple per SDK
    che usano "Required Reason API") — un piccolo costo di manutenzione in più ad ogni
    aggiornamento del pacchetto.
  - Non richiede login: l'identificatore è un ID di installazione anonimo generato dall'SDK.

### Opzione C — Anonima, "fatta in casa", senza login (raccomandata se si vuole più di A)

Un contatore minimo, coerente con lo spirito privacy-first, che risponde esattamente alle
metriche mancanti e nient'altro:

1. **ID anonimo locale**: UUID generato una volta, salvato in `shared_preferences` — non
   email, non device ID di sistema, non collegato ad alcun account.
2. **Manciata di eventi discreti**, non un log dettagliato dell'uso:
   - `app_open` (una volta per sessione/avvio)
   - `track_saved` (alla creazione o import di una traccia, con un flag `origin:
     drawn|imported`)
   - `sync_connected` (quando la connessione a un provider va a buon fine, con
     `provider: icloud|google_drive` — **nessun dato del tracciato**, solo l'evento)
3. **Un endpoint di ingestione minimale**, non un "backend" nel senso pieno: una funzione
   serverless (Cloudflare Workers, tier gratuito ~100k richieste/giorno; o Supabase Edge
   Functions, tier gratuito) che riceve `{event, anon_id, timestamp, app_version}` e lo
   scrive in un KV/tabella. Query periodiche (te le fai tu, non serve una dashboard
   sofisticata) aggregano per settimana/mese: "N tracce salvate questa settimana", "N id
   distinti che hanno fatto `sync_connected` questo mese" (proxy di "utenti che
   sincronizzano" — imperfetto se qualcuno reinstalla l'app, accettabile per una beta tra
   amici).
4. **Nessun contenuto delle tracce** lascia mai il dispositivo per motivi di analitica — la
   sync vera (GPX/JSON) resta quello che è oggi, sul cloud personale dell'utente.

- **Costo di sviluppo:** medio (il codice client è semplice; la parte nuova è mettere in
  piedi e mantenere, anche minimamente, un endpoint — è la prima volta che il progetto
  avrebbe *qualcosa* fuori dal dispositivo dell'utente sotto il tuo controllo diretto).
- **Costo economico:** presumibilmente zero, nei tier gratuiti, alla scala attuale.
- **Contro:** rompe comunque, anche se in modo minimo e onesto, la frase "zero backend" —
  va detto chiaramente nella privacy policy ("un contatore anonimo e aggregato, senza dati
  personali, per capire quanto viene usata l'app"), ma è un cambiamento piccolo e onesto da
  comunicare, non uno strutturale.

### Opzione D — Login obbligatorio/opzionale (Google/Apple) + analitiche per-utente

Questa è la parte che la roadmap aveva già segnato come "questione architetturale aperta"
(§10 CLAUDE.md, P6 ROADMAP) — e la conferma dell'analisi è: **è una decisione a sé,
indipendente e molto più pesante di quella sulle analitiche**.

Cosa comporterebbe, oltre a quanto sopra:

- **Un vero gate di login** in app (schermata prima della mappa o opzionale da
  Impostazioni), persistenza sessione, logout — oggi non esiste (Google Sign-In è usato
  *solo* come autorizzazione OAuth per Drive, non come "account Sentèi"; iCloud usa
  l'account di sistema, non un login applicativo).
- **Sign in with Apple obbligatorio su iOS** (Guideline 4.8) se offri login social — un
  intero flusso in più da implementare e mantenere, con la sua UX di gestione account,
  eliminazione account (Guideline 5.1.1(v): un'app con account deve permettere di
  cancellarlo dall'app stessa).
- **Un backend reale** per collegare eventi/dati a un utente autenticato (non basta più un
  endpoint anonimo: serve gestione identità, sessioni, probabilmente un database utenti) —
  un salto di complessità e manutenzione enorme rispetto all'Opzione C, per un'app gratuita
  di un solo sviluppatore.
- **Riscrittura sostanziale della privacy policy** e della sezione "Natura del progetto" del
  README: da "zero backend, nessun dato raccolto" a "esiste un account, esistono dati
  legati alla tua identità su un server" — un posizionamento diverso del progetto, non un
  dettaglio.
- **Vantaggio reale che porta**: metriche per-utente vere (non solo conteggi aggregati),
  possibilità di supporto/comunicazione diretta agli utenti, continuità multi-dispositivo
  legata all'identità invece che al solo cloud provider. Nessuno di questi benefici è
  necessario per rispondere alle 4 domande di partenza — servirebbero per obiettivi diversi
  (prodotto multi-dispositivo più maturo, community, ecc.).

**In breve: il login non è un prerequisito per le analitiche che hai chiesto.** È una
decisione di prodotto separata (vale la pena? per un'app gratuita per gli amici, quasi
certamente non ancora) che va presa sui suoi meriti, non "tanto che ci siamo".

---

## Tabella riassuntiva

| Opzione | Risponde a Mapbox | Risponde a "app aperta" | Risponde a "tracce salvate" | Risponde a "chi sincronizza" | Serve un backend? | Tocca la privacy policy? | Effort |
|---|---|---|---|---|---|---|---|
| **A — status quo** | ✅ (dashboard Mapbox) | 🟡 parziale (App Store/Play Analytics) | ❌ | ❌ | No | No | Zero |
| **B — SDK terze parti (Firebase)** | ✅ | ✅ | ✅ | ✅ (parziale, anonimo) | No (Google lo ospita) | Sì (nutrition label + policy) | Basso |
| **C — anonimo fatto in casa** | ✅ | ✅ | ✅ | ✅ (anonimo) | Sì, minimale | Sì (una frase onesta) | Medio |
| **D — login + backend utenti** | ✅ | ✅ | ✅ | ✅ (per-utente reale) | Sì, completo | Sì, riscrittura | Alto |

---

## Raccomandazione

1. **Subito, a costo zero:** inizia a guardare **Mapbox Dashboard** e **App Store Connect
   Analytics** — coprono già 1.5 delle 4 domande di partenza senza toccare una riga di
   codice né la privacy policy.
2. **Se servono davvero "tracce salvate" e "chi sincronizza":** **Opzione C** (contatore
   anonimo fatto in casa, 3 eventi, endpoint minimale) — è l'unica che risponde a tutte e
   quattro le domande restando coerente con lo spirito del progetto, con un costo di
   sviluppo contenuto e un impatto sulla privacy policy onesto e circoscritto a una frase.
   Scarterei la B (Firebase) a meno che la velocità di implementazione conti più della
   coerenza con "zero backend/no Google se non richiesto" — è comunque un'alternativa
   valida se preferisci non mantenere nemmeno un endpoint minimale.
3. **Non legare questa decisione al login.** Il login/identità (Opzione D) è una domanda di
   prodotto diversa e più grande, da valutare da sola quando/se emerge un motivo concreto
   (non "per avere analitiche migliori", che si ottengono già con C). Resta un quesito
   aperto separato in `docs/ROADMAP.md` (P6).

Se si procede con l'opzione C, i prossimi passi concreti sarebbero: scegliere la piattaforma
serverless (Cloudflare Workers vs Supabase Edge Functions — entrambe hanno tier gratuiti
adeguati alla scala attuale), definire lo schema dei 3 eventi, aggiornare la privacy policy
e il README, poi implementare lato client (`data/analytics/` seguendo lo stesso pattern a
interfaccia comune già usato per `CloudSyncService`/`TrailService`).
