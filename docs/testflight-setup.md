# Distribuzione beta su TestFlight

> Per far testare **Sentèi** ad amici su iPhone senza pubblicare sull'App Store.
> Richiede l'**Apple Developer Program** (attivo) — team `W8XCSNY6V3`,
> bundle id `com.mattiacuratitoli.sentei`.

## A. Crea il record dell'app su App Store Connect

1. <https://appstoreconnect.apple.com> → **App** → **+** → **Nuova app**.
2. Piattaforma **iOS**; Nome **Sentèi**; Lingua principale **Italiano**;
   **Bundle ID** = `com.mattiacuratitoli.sentei` (è già nel menu: registrato
   quando hai aggiunto la capability iCloud); **SKU** = una stringa libera (es.
   `sentei-001`); accesso utente: completo.
3. **Crea**. (Non serve compilare le schede dell'App Store per la sola beta.)

## B. Build dell'IPA firmato (release)

La build scarica l'SDK Mapbox col **secret token** in `~/.netrc` (già configurato,
CLAUDE.md §2) e ha bisogno dei valori runtime via `--dart-define`:

```bash
flutter build ipa --release \
  --dart-define=MAPBOX_TOKEN=pk.eyJ1IjoidGlhY3VyYSIsImEiOiJjbTE1Mnp2YnAwNGtsMmtzOG5lbjdobmhoIn0.zNpZe_QP3YQ_AGkYLSt7YA \
  --dart-define=GOOGLE_CLIENT_ID=150992964606-fqbqhenliiobosg4uu6b62vk7savqskk.apps.googleusercontent.com
```

Output: `build/ios/ipa/*.ipa` (+ archivio in `build/ios/archive/Runner.xcarchive`).
Con "Automatically manage signing" attivo, Flutter usa il profilo di distribuzione
del tuo team. Se la firma fallisce: apri `ios/Runner.xcworkspace` in Xcode →
**Product → Archive** → **Distribute App → App Store Connect → Upload** (path GUI
equivalente che gestisce la firma).

## C. Carica la build

Scelta più semplice: app **Transporter** (gratis sul Mac App Store) →
accedi col tuo Apple ID → trascina il `.ipa` → **Deliver**.

In alternativa: Xcode **Organizer** (Window → Organizer) → seleziona l'archivio →
**Distribute App → App Store Connect**.

La build viene "processata" da Apple (~5–15 min): comparirà nella tab **TestFlight**.
Grazie a `ITSAppUsesNonExemptEncryption=false` non chiede l'export compliance.

## D. Invita gli amici (External testing)

Gli amici non sono nel tuo team → **tester esterni**:

1. App Store Connect → la tua app → **TestFlight** → **Gruppi** → **+** → crea un
   gruppo (es. "Amici").
2. Compila **Test Information** (descrizione beta, email di feedback, "cosa
   testare") — obbligatorio per i tester esterni.
3. Aggiungi i tester per **email** (non serve siano nel team).
4. Assegna la build al gruppo. La **prima** build per tester esterni passa per una
   **Beta App Review** (di solito poche ore / <24h).
5. Approvata: ricevono un'email → installano l'app **TestFlight** dall'App Store →
   **Redeem** → installano Sentèi.

> **Tester interni** (alternativa rapida, niente review): fino a 100 persone, ma
> devono essere aggiunte in **Users and Access** del tuo account (di solito solo
> tu/collaboratori, non amici occasionali).

## Aggiornamenti successivi

⚠️ **Ogni upload richiede un build number nuovo:** incrementa il `+N` in
`pubspec.yaml` (`version: 1.0.0+2`, `+3`, …) **prima** di ribuildare, altrimenti
Transporter rifiuta l'upload (numero già usato). Le build successive per un gruppo
già approvato non rifanno la Beta App Review.

## Warning di validazione già risolti

- **90683 — `Missing purpose string ... NSLocationAlwaysAndWhenInUseUsageDescription`**:
  il plugin `geolocator` referenzia l'API di location "always" (anche se l'app usa
  solo il foreground), quindi Apple pretende la purpose string. Aggiunte in
  `ios/Runner/Info.plist`: `NSLocationAlwaysAndWhenInUseUsageDescription` +
  `NSLocationAlwaysUsageDescription` (oltre a `NSLocationWhenInUseUsageDescription`).
  Risolto dalla build `1.0.0+2` in poi.

## Note

- I valori `--dart-define` finiscono *dentro* la build: il `pk` Mapbox e il client
  id Google non sono segreti (ok). Il secret `sk` Mapbox resta solo in `~/.netrc`,
  non nell'app.
- Le mappe offline / iCloud / Drive funzionano in release come in debug.
