# Notificare gli aggiornamenti in-app tramite manifest (`latest.json`)

> **Problema:** su **Android** Sentèi si distribuisce come **APK in una cartella condivisa**
> (niente Play Store) → **nessun aggiornamento automatico**: l'utente non sa che esiste un
> APK nuovo, non viene avvisato, deve accorgersene da solo.
> Su **iOS** (Unlisted) ci pensa l'App Store; la card "Novità" (`lib/ui/whats_new.dart`)
> copre già il *dopo*-aggiornamento. Manca il *prima*: "c'è una versione più recente, vai a
> prenderla".
>
> **Soluzione (zero backend):** un piccolo file JSON statico pubblicato su GitHub Pages che
> l'app scarica all'avvio e confronta con la propria build. Se ne esiste una più recente,
> mostra un avviso non invasivo con un link.

---

## Scelta fatta

**Decisione (1 settembre 2026): opzione A — controllo in-app via manifest.** L'opzione B
(Google Play closed testing, prevista in `ROADMAP.md` §P6 fino al 31 agosto 2026) è stata
scartata: 25 $ una tantum, upload keystore dedicata, build `.aab` e il vincolo "20 tester per
14 giorni" degli account personali recenti non si giustificano alla scala "amici". `ROADMAP.md`
§P6 è già stato allineato.

| Opzione | Pro | Contro |
|---|---|---|
| **A. Controllo in-app via manifest** ← scelta | Zero costi, zero infra, resta il flusso "cartella condivisa" attuale | Lo implementi e mantieni tu; l'utente aggiorna comunque a mano |
| **B. Google Play — closed testing** (scartata) | Aggiornamento automatico + notifica "gratis" | 25 $ una tantum, upload keystore dedicata, build `.aab`, vincolo "20 tester per 14 giorni" |

---

## 1. Il file manifest

### 1.1 Dove sta

Nel repo: **`docs/latest.json`**. GitHub Pages serve la cartella `/docs` del repo pubblico
`mcuratitoli/sentei`, quindi diventa raggiungibile a:

```
https://mcuratitoli.github.io/sentei/latest.json
```

(lo stesso sito che serve già `privacy-policy.html`). Dopo `git push`, Pages si rigenera in
~1 minuto.

> **Non** mettere il manifest nella cartella condivisa: iCloud non dà URL diretti stabili a
> un file JSON, e su Drive il link "condivisione" non è un raw JSON pulito. La cartella
> condivisa serve **solo per i binari APK**; il manifest sta su Pages.

### 1.2 Schema

```json
{
  "schema": 1,
  "android": {
    "build": 11,
    "version": "1.0.1",
    "url": "https://drive.google.com/drive/folders/XXXXXXXXXXXX",
    "apk": "sentei-1.0.1+11.apk",
    "notes": "Tempo di percorrenza per un tratto scelto; stile della linea per grado CAI.",
    "min_supported_build": 8
  },
  "ios": {
    "build": 11,
    "version": "1.0.1",
    "url": "https://apps.apple.com/app/id0000000000"
  }
}
```

| Campo | Tipo | Obblig. | Significato |
|---|---|---|---|
| `schema` | int | sì | Versione del formato. L'app ignora un manifest con `schema` che non conosce. |
| `<piattaforma>.build` | int | sì | **Chiave di confronto** autoritativa. Coincide con il `+N` di `pubspec.yaml`. |
| `<piattaforma>.version` | string | sì | Stringa mostrata all'utente (la parte prima di `+`). |
| `<piattaforma>.url` | string | sì | Android → link alla **cartella condivisa**; iOS → pagina App Store. |
| `android.apk` | string | no | Nome del file da cercare nella cartella (aiuta l'utente a scegliere). |
| `<piattaforma>.notes` | string | no | Riga singola per l'avviso. |
| `<piattaforma>.min_supported_build` | int | no | Sotto questa build l'aggiornamento è **obbligatorio** (avviso bloccante). Assente = mai obbligatorio. |

### 1.3 Regola d'oro sull'ordine di pubblicazione

Pubblica il manifest **solo dopo** che il binario è effettivamente disponibile:

1. Android: APK caricato nella cartella condivisa **→ poi** aggiorni `android.*` e fai push.
2. iOS: versione App Store **live** (passo 9 di `distribuzione-unlisted.md`) **→ poi**
   aggiorni `ios.*` e fai push.

Altrimenti gli utenti vengono mandati a scaricare qualcosa che non c'è ancora.

---

## 2. Comportamento dell'app

### 2.1 Quando controlla

- **All'avvio**, dopo il primo frame, in modo **non bloccante** (da un provider Riverpod).
- Anche **manualmente** da *Impostazioni → Informazioni* ("Controlla aggiornamenti").

### 2.2 Come controlla

1. `GET https://mcuratitoli.github.io/sentei/latest.json?t=<epochMillis>`
   (il query param è un **cache-buster**: Pages mette una cache breve, così eviti di leggere
   una copia vecchia).
2. `.timeout(const Duration(seconds: 4))`.
3. **Qualsiasi errore** (offline, timeout, 404, JSON malformato, `schema` sconosciuto):
   si ignora in silenzio, `debugPrint('[update] check fallito: $e')`
   (vedi memoria `sentei-logging-practice`), non si mostra nulla. Sentèi è un'app da
   montagna: offline è lo stato normale, non un errore da segnalare.
4. Scegli la sezione: `Platform.isAndroid ? json['android'] : json['ios']`.
5. Confronta `remote.build` (int) con `int.parse(PackageInfo.fromPlatform().buildNumber)`.

### 2.3 Stati risultanti

| Condizione | Stato | UI |
|---|---|---|
| `remote.build <= local` | `upToDate` | niente |
| `remote.build > local` **e** `min_supported_build != null` **e** `local < min_supported_build` | `mandatory` | avviso **non** dismissibile |
| `remote.build > local` (altrimenti) | `optional` | avviso dismissibile, **se** non già ignorato per quella build |

### 2.4 Persistenza (SharedPreferences — stesso pattern di `whats_new.dart`)

- Chiave `update_dismissed_build` (int).
- Tap su **"Più tardi"** → salva `remote.build`.
- L'avviso `optional` resta nascosto finché `dismissed >= remote.build`; quando arriva una
  build ancora più recente (`remote.build > dismissed`) **ricompare**.
- Lo stato `mandatory` **ignora** questa chiave: si mostra sempre.

### 2.5 UI

**Non** il bottom sheet bloccante di `showWhatsNew` — quello è per il *dopo*-aggiornamento.
Qui serve un **banner dismissibile** in cima alla schermata mappa (o una card in uno slot
coerente), stile opaco da `design/DESIGN_GUIDELINES.md`. Riusa i pattern esistenti in
`lib/ui/` (`ios_toast.dart`, `app_buttons.dart`).

- Testo: **"Aggiornamento disponibile — versione {version}"** + riga `notes` se presente.
- Android (`apk` presente): riga di aiuto **"File: {apk}"**.
- Azioni:
  - **Android / `optional`:** `[Apri la cartella]` + `[Più tardi]`.
  - **Android / `mandatory`:** solo `[Apri la cartella]`, banner non chiudibile (valuta di
    coprire l'app con una pagina a tutto schermo).
  - **iOS / `optional`:** `[Apri su App Store]` + `[Più tardi]`.
    *(Valuta un flag per sopprimerlo del tutto su iOS: lo store aggiorna già da solo.)*
- Apertura link:
  `launchUrl(Uri.parse(u.url), mode: LaunchMode.externalApplication)` (`url_launcher` è
  **già** in `pubspec.yaml`).

---

## 3. Struttura del codice

```
lib/data/update/
  update_manifest.dart      # modelli: UpdateManifest, PlatformUpdate + parse da JSON
  update_check_service.dart # Future<UpdateStatus> check(): fetch + confronto build
  update_providers.dart     # updateStatusProvider (FutureProvider), dismissUpdate(int)
lib/features/map_gl/
  ...                       # consuma il provider, disegna il banner
```

- Costante URL nel service:
  `const kUpdateManifestUrl = 'https://mcuratitoli.github.io/sentei/latest.json';`
- `UpdateStatus` = union: `upToDate` | `optional(PlatformUpdate)` | `mandatory(PlatformUpdate)`.
- Inietta un `http.Client` nel service (default `http.Client()`) per poterlo mockare.
- Dipendenze: **nessuna nuova** — `http`, `url_launcher`, `package_info_plus`,
  `shared_preferences` sono già presenti.

### Test — `test/data/update/update_check_service_test.dart`

Con `MockClient` di `package:http/testing.dart`, dai in pasto stringhe JSON e verifica:

- `remote.build < local` → `upToDate`
- `remote.build == local` → `upToDate`
- `remote.build > local`, senza `min_supported_build` → `optional`
- `remote.build > local`, `local < min_supported_build` → `mandatory`
- risposta 404 / body non-JSON / `schema: 99` → `upToDate` (fail-safe, nessuna eccezione)
- selezione della sezione giusta per piattaforma

---

## 4. Integrazione con la release-checklist

Aggiungere a [`docs/release-checklist.md`](release-checklist.md), sezione **§3 "File
pubblici di stato"**:

```markdown
- [ ] **`docs/latest.json`** — aggiornato alla build appena distribuita:
  - `android.build` / `android.version` / `android.notes` / `android.apk` **dopo** aver
    caricato l'APK nella cartella condivisa.
  - `ios.build` / `ios.version` **solo quando** la versione App Store corrispondente è
    *live* (non alla submission).
  - `git push` (GitHub Pages si aggiorna in ~1 min). Verifica che
    `https://mcuratitoli.github.io/sentei/latest.json` risponda col nuovo contenuto.
```

---

## 5. APK Android: firma e naming (importante)

- **Naming nella cartella condivisa:** `sentei-<version>+<build>.apk`
  (es. `sentei-1.0.1+11.apk`) — così il campo `android.apk` del manifest corrisponde.
  Tieni le ultime 2–3 versioni, elimina le più vecchie.
- **Stessa chiave di firma per sempre.** Oggi l'APK è firmato con la **debug key**
  (`android/app/build.gradle`, `release` usa `signingConfigs.debug` — vedi
  `docs/android-apk-setup.md`). Va bene per il sideload, **ma** Android rifiuta di
  installare un aggiornamento firmato con una chiave diversa ("package conflicts with an
  existing package") → l'utente dovrebbe disinstallare e reinstallare, perdendo i dati
  locali.
  - La `~/.android/debug.keystore` **cambia** se ricrei l'ambiente / cambi Mac.
  - **Raccomandazione:** genera **ora** una keystore dedicata e stabile per gli APK di
    rilascio, **fuori dal repo**, con backup (es. in un password manager). Così l'identità
    di firma è permanente e gli aggiornamenti si installano sopra senza attriti.
    È lo stesso keystore che servirebbe poi per l'eventuale opzione B (Play).

---

## 6. Privacy

Aggiungere una frase a `docs/privacy-policy.html` (§5 "Servizi di terze parti"):

> All'avvio l'app scarica un piccolo file pubblico (`latest.json`) da GitHub Pages per
> verificare se è disponibile una versione più recente. Come per ogni richiesta di rete,
> l'indirizzo IP è tecnicamente visibile al servizio; non viene trasmesso nessun altro dato.

Nel questionario **App Privacy** di App Store Connect questo non cambia nulla: è il fetch di
un file statico, **nessun dato raccolto**.

---

## 7. Possibile evoluzione (non ora)

Su Android l'app potrebbe **scaricare l'APK** e lanciare l'installer via intent
(`ACTION_VIEW` sul file). Richiede il permesso `REQUEST_INSTALL_PACKAGES` + un `FileProvider`
+ gestione runtime del consenso "installa app sconosciute" → lavoro nativo non banale e
rischio in più in fase di review se un giorno si passa al Play Store. Per una cerchia di
amici **non ne vale la pena**: il link alla cartella basta.

---

Vedi anche: [`distribuzione-unlisted.md`](distribuzione-unlisted.md) ·
[`android-apk-setup.md`](android-apk-setup.md) · [`release-checklist.md`](release-checklist.md) ·
[`ROADMAP.md`](ROADMAP.md) §P6
