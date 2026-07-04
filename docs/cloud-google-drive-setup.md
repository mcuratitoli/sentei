# Setup sincronizzazione Google Drive

> Necessario **una volta** per attivare il login Google e il sync delle tracce.
> Senza questa configurazione l'app funziona lo stesso: la sezione "Google Drive"
> in Impostazioni mostra "Accedi", ma il login fallirà con un messaggio d'errore.

L'app usa lo scope **`drive.file`**: vede e modifica **solo i file che crea lei**
(una cartella `Sentèi` con un `<id>.json` + `<id>.gpx` per traccia). Nessun accesso
al resto del Drive. Niente segreti nel repo: il client id si passa con `--dart-define`.

## 1. Progetto Google Cloud + API Drive

1. Vai su <https://console.cloud.google.com/> → crea un progetto (es. "Sentei").
2. **API e servizi → Libreria** → cerca **Google Drive API** → **Abilita**.

## 2. Schermata consenso OAuth

1. **API e servizi → Schermata consenso OAuth**.
2. Tipo utente: **Esterno** → crea.
3. Compila nome app ("Sentèi"), email di supporto, email sviluppatore.
4. **Scopi**: puoi lasciare vuoto (lo scope `drive.file` è "non sensibile" e viene
   richiesto a runtime).
5. **Utenti di test**: aggiungi il tuo indirizzo Google (finché l'app è in
   "Testing" solo gli utenti di test possono accedere — sufficiente per noi).

## 3. Client OAuth — iOS

1. **API e servizi → Credenziali → Crea credenziali → ID client OAuth**.
2. Tipo applicazione: **iOS**.
3. **Bundle ID**: `com.mattiacuratitoli.sentei`.
4. Copia due valori dalla credenziale creata:
   - **iOS client ID**: `XXXXXX.apps.googleusercontent.com`
   - **Reversed client ID** (lo schema URL): `com.googleusercontent.apps.XXXXXX`

### 3a. Schema URL in Info.plist (obbligatorio su iOS)

Il redirect del login torna all'app via uno **URL scheme** = reversed client ID.
Va aggiunto in `ios/Runner/Info.plist` (è config nativa, non un dart-define):

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.XXXXXX</string>
    </array>
  </dict>
</array>
```

> Dimmi il reversed client ID e lo aggiungo io al plist, oppure incollalo lì.

## 4. Avvio con il client id

```bash
flutter run \
  --dart-define=MAPBOX_TOKEN=pk... \
  --dart-define=GOOGLE_CLIENT_ID=XXXXXX.apps.googleusercontent.com \
  -d <device>
```

Poi: **Impostazioni → Google Drive → Accedi** → consenti → **Sincronizza ora**.

## 5. Android

> **Prerequisito toolchain (questo Mac, lug 2026):** attualmente **JDK e Android SDK
> non sono installati** (`flutter doctor` → "Unable to locate Android SDK", nessun
> `java`). Per buildare l'APK e ricavare la SHA-1 va prima ripristinata la toolchain
> Android — vedi **`docs/android-apk-setup.md`** (JDK 17 + Android SDK 36 + NDK).

Con `google_sign_in` **v7**, su Android servono **due** cose lato Google Cloud
(stesso progetto della credenziale iOS):

### 5a. Client OAuth — Android
1. **Credenziali → Crea credenziali → ID client OAuth → Android**.
2. **Package name**: `com.mattiacuratitoli.sentei`.
3. **SHA-1** della chiave di firma. Per l'**APK sideload** (debug-signed) è la debug key:
   ```bash
   # (dopo aver reinstallato JDK 17; il keystore lo crea il primo build Android)
   keytool -list -v -keystore ~/.android/debug.keystore \
     -alias androiddebugkey -storepass android -keypass android | grep SHA1
   ```
   Per una futura pubblicazione su **Play Store** aggiungere anche la SHA-1 della
   **release/upload key**.

### 5b. Client OAuth — Web (per il serverClientId)
`google_sign_in` v7 su Android richiede un **ID client OAuth di tipo "Applicazione
web"**: il suo client id va passato all'app come **`GOOGLE_SERVER_CLIENT_ID`** (serve
per ottenere l'autorizzazione agli scope Drive). Se non esiste ancora:
1. **Credenziali → Crea credenziali → ID client OAuth → Applicazione web** → crea.
2. Copia il **Web client ID** (`XXXX.apps.googleusercontent.com`).

### 5c. Build Android con le credenziali
Su Android **non** serve `GOOGLE_CLIENT_ID` (il client Android è riconosciuto da
package + SHA-1); serve invece il **server (web) client id**:
```bash
flutter build apk --release \
  --dart-define=MAPBOX_TOKEN=pk... \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=XXXX.apps.googleusercontent.com
# (per il run in debug: flutter run -d <android> con gli stessi --dart-define)
```
> Il codice è già pronto: `cloudServiceProvider` legge `GOOGLE_SERVER_CLIENT_ID`
> e lo passa a `GoogleSignIn.instance.initialize(serverClientId: …)`. Su Android la
> sezione Impostazioni mostra **solo Google Drive** (iCloud è nascosto).

### 5d. Consenso OAuth
Aggiungi il tuo account Google come **utente di test** (§2) anche per l'uso su Android
(finché l'app resta in "Testing").

## Modello di sincronizzazione

- Una traccia = `Sentèi/<id>.json` (fonte di verità, round-trip completo) +
  `Sentèi/<id>.gpx` (per aprirla in altre app).
- **Last-write-wins** per timestamp (`updatedAt` in `appProperties` del file).
- **Auto-sync** (giu 2026): salvataggio/import → upload della traccia; eliminazione
  → cancellazione anche dal cloud. Best-effort e silenzioso (no-op se non connessi).
- "Sincronizza ora" (Impostazioni) resta per il merge completo bidirezionale
  (utile dopo modifiche da un altro device). NB: il merge manuale ri-scarica le
  tracce presenti solo nel cloud (le eliminazioni offline non lasciano tombstone).
