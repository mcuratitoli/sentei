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

## 5. Android (più avanti)

1. Altro **ID client OAuth** tipo **Android**.
2. Package name `com.mattiacuratitoli.sentei` + **SHA-1** della chiave di firma
   (debug: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`).
3. Su Android `google_sign_in` trova il client dal certificato: di norma **non**
   serve passare `GOOGLE_CLIENT_ID`. Se usi un *server client id*, passalo come
   `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.

## Modello di sincronizzazione

- Una traccia = `Sentèi/<id>.json` (fonte di verità, round-trip completo) +
  `Sentèi/<id>.gpx` (per aprirla in altre app).
- **Last-write-wins** per timestamp (`updatedAt` in `appProperties` del file).
- **Le eliminazioni non si propagano** (v1): una traccia cancellata da un lato
  viene ri-copiata dall'altro, mai rimossa. Da rivedere se diventa un problema.
- "Sincronizza ora" è manuale (Impostazioni). Sync automatico: eventuale step
  successivo.
