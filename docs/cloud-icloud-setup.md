# Setup sincronizzazione iCloud Drive

> Necessario **una volta** per attivare il sync delle tracce su iCloud (iOS).
> A differenza di Google Drive, iCloud usa l'**account di sistema** del device:
> non c'è login interattivo nell'app. Richiede però l'**Apple Developer Program**
> (a pagamento) perché i *container iCloud* non sono creabili col team personale.

L'app usa un **container iCloud dedicato** (`iCloud.com.mattiacuratitoli.sentei`):
una cartella `Sentèi` con `<id>.json` + `<id>.gpx` per traccia. Stesso modello
last-write-wins di Drive (vedi `docs/cloud-google-drive-setup.md`).

## 0. Prerequisito — Apple Developer Program

1. <https://developer.apple.com/programs/> → **Enroll**.
2. Accedi con il tuo Apple ID, accetta i termini, paga la quota annuale (99 €/$).
3. L'attivazione può richiedere da qualche ora a un paio di giorni (verifica Apple).
   Finché non è attiva, in Xcode non potrai aggiungere la capability iCloud.

## 1. App ID + capability iCloud (portale Apple)

1. <https://developer.apple.com/account> → **Certificates, Identifiers & Profiles
   → Identifiers**.
2. Apri (o crea) l'App ID `com.mattiacuratitoli.sentei`.
3. Abilita **iCloud** → **Edit** → crea/associa un **iCloud Container**:
   `iCloud.com.mattiacuratitoli.sentei`. Salva.

> Spesso è più rapido farlo direttamente da Xcode (passo 2), che crea container e
> profilo automaticamente.

## 2. Capability in Xcode (questo lo facciamo insieme)

Apri `ios/Runner.xcworkspace` in Xcode → target **Runner** → **Signing &
Capabilities**:

1. Verifica che **Team** sia il tuo account a pagamento e il **Bundle Identifier**
   sia `com.mattiacuratitoli.sentei`.
2. **+ Capability → iCloud**.
3. Spunta **iCloud Documents** (NON CloudKit).
4. Nei **Containers** spunta `iCloud.com.mattiacuratitoli.sentei` (o crealo col
   pulsante **+** se non c'è).

Xcode genererà `ios/Runner/Runner.entitlements` con, in sostanza:

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array><string>iCloud.com.mattiacuratitoli.sentei</string></array>
<key>com.apple.developer.icloud-services</key>
<array><string>CloudDocuments</string></array>
<key>com.apple.developer.ubiquity-container-identifiers</key>
<array><string>iCloud.com.mattiacuratitoli.sentei</string></array>
```

> Se il container id qui differisse, aggiornare `_defaultContainerId` in
> `lib/data/cloud/icloud_sync_service.dart` di conseguenza.

## 3. Sul device

1. Il device/simulatore deve essere **loggato in iCloud** (Impostazioni iOS →
   Account) con **iCloud Drive** attivo.
2. `flutter run` (rebuild completo per i nuovi entitlement).
3. In **Impostazioni → sezione cloud** seleziona **iCloud** nel selettore →
   **Accedi** (verifica solo la disponibilità del container) → **Sincronizza ora**.
4. I file compaiono in **File → iCloud Drive → Sentèi**.

## Note

- Niente login OAuth, niente `--dart-define` per iCloud.
- Il selettore Drive/iCloud in Impostazioni è **iOS-only** (iCloud non esiste
  altrove); la scelta è persistita in `shared_preferences`.
- Auto-sync (come Drive): salva/import → upload, elimina → delete remoto
  (best-effort). "Sincronizza ora" resta per il merge completo.
- **Codice già scritto** (`IcloudSyncService`): manca solo la capability nativa
  del passo 2, da fare quando l'Apple Developer Program è attivo.
