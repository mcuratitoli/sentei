# Build e distribuzione APK Android (test)

> Per provare **Sentèi** su telefoni Android senza Play Store, condividendo un APK.
> App: bundle `com.mattiacuratitoli.sentei`.

---

## Prerequisiti toolchain (una tantum su questo Mac)

La toolchain Android è stata configurata via CLI (no Android Studio):

- **JDK 17** (Homebrew): `brew install openjdk@17` →
  `JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`.
- **Android SDK 36** + **build-tools 36.0.0** + **platform-tools**, installati con
  `sdkmanager` e licenze accettate (`yes | sdkmanager --licenses`).
- **Token Mapbox** per scaricare l'SDK in build: `MAPBOX_DOWNLOADS_TOKEN=sk...`
  in `~/.gradle/gradle.properties` (segreto, fuori dal repo).

> Se cambi Mac, rifai questi passi (vedi anche `dev-setup.md`).

---

## Build dell'APK

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
flutter build apk --release \
  --dart-define=MAPBOX_TOKEN=pk.eyJ1IjoidGlhY3VyYSIsImEiOiJjbTE1Mnp2YnAwNGtsMmtzOG5lbjdobmhoIn0.zNpZe_QP3YQ_AGkYLSt7YA \
  --dart-define=GOOGLE_CLIENT_ID=150992964606-fqbqhenliiobosg4uu6b62vk7savqskk.apps.googleusercontent.com
```

Output: **`build/app/outputs/flutter-apk/app-release.apk`**.

> ⚠️ Per ora l'APK è **firmato con la debug key** (in `android/app/build.gradle`
> il `release` usa `signingConfigs.debug`): va benissimo per **sideload/test**, ma
> NON è pubblicabile sul Play Store. Per il Play Store servirà una keystore di
> upload dedicata (lo facciamo quando serve).

---

## Condividere l'APK con gli amici

1. Invia il file `app-release.apk` (WhatsApp/Telegram/Drive/email — l'APK non è
   un segreto).
2. Sul telefono Android l'amico apre il file e conferma l'installazione.
3. Android chiede di **abilitare "Installa app sconosciute"** per l'app da cui
   apre l'APK (es. WhatsApp/File/Chrome): *Impostazioni → App → [app] → Consenti
   da questa origine*. Poi torna e installa.
4. Avvio: l'app funziona (mappa, disegno, GPS, offline, GPX).

### Limiti noti su Android (oggi)

- **Google Drive sync NON ancora attivo su Android**: manca il client OAuth
  Android (richiede SHA-1 della firma + configurazione su Google Cloud). Su
  Android il login Drive non funziona finché non lo configuriamo. Tutto il resto
  (mappa, tracce, GPX, offline) sì.
- iCloud è solo iOS (per natura).

---

## Aggiornamenti

Rigenera l'APK con lo stesso comando e ricondividi il file. Non serve cambiare il
build number per il sideload (a differenza di TestFlight), ma è buona norma
allinearlo a `pubspec.yaml`.
