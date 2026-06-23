# Setup di sviluppo su un nuovo Mac

> Checklist per riprendere a lavorare su **Sentèi** da un'altra macchina.
> I **segreti non sono nel repo** (§9 CLAUDE.md): vanno riconfigurati a mano.

## 1. Strumenti da installare

| Strumento | Note |
|---|---|
| **Flutter 3.44.2** (stable) | `flutter --version` deve dire 3.44.2. ⚠️ Se hai `dart` di Homebrew nel PATH, per i tool usa **`flutter pub run …`**, NON `dart run …`. |
| **Xcode** (+ Command Line Tools) | Aprilo una volta per accettare la licenza e installare i componenti iOS. `xcode-select --install` per le CLT. |
| **CocoaPods** | `sudo gem install cocoapods` (o `brew install cocoapods`). Serve per i plugin iOS. |
| **Git** | Per clonare il repo. |
| **Transporter** (Mac App Store) | Solo per caricare build su **TestFlight** (`docs/testflight-setup.md`). |
| (Android, opzionale) **Android Studio + SDK** | Solo se si vuole buildare Android. |

Verifica generale: **`flutter doctor`** non deve avere errori bloccanti per iOS.

## 2. Segreti da riconfigurare (NON nel repo)

### Mapbox — secret download token (`sk`) → per scaricare l'SDK in build
Senza questo, `pod install` / la build iOS **falliscono** nel fetch dell'SDK Mapbox.
Copia il token `sk....` dall'altro Mac (è in `~/.netrc`) o rigenerane uno con scope
**Downloads:Read** su <https://account.mapbox.com/access-tokens/>.

`~/.netrc`:
```
machine api.mapbox.com
login mapbox
password sk.XXXXXXXX
```
(Android: stesso token anche in `~/.gradle/gradle.properties` come `MAPBOX_DOWNLOADS_TOKEN=sk.XXXX`.)

### Mapbox — public token (`pk`) + Google client id → runtime via `--dart-define`
Non sono segreti critici; si passano all'avvio (vedi §4). Il **reversed client id**
iOS di Google è già in `ios/Runner/Info.plist` (committato).

## 3. Firma iOS (Apple Developer)

1. Xcode → **Settings → Accounts** → accedi con l'**Apple ID** proprietario del team
   `W8XCSNY6V3` (Apple Developer Program).
2. Apri `ios/Runner.xcworkspace` → target **Runner** → **Signing & Capabilities**:
   "Automatically manage signing" ON, **Team** = quello del Developer Program.
3. La capability **iCloud Documents** + container `iCloud.com.mattiacuratitoli.sentei`
   sono già in `Runner.entitlements` (committato): vanno solo firmati col team giusto.

## 4. Avvio

```bash
flutter pub get
# (se servono modifiche a drift) flutter pub run build_runner build
flutter devices                       # trova l'id del device/simulatore

flutter run \
  --dart-define=MAPBOX_TOKEN=pk... \
  --dart-define=GOOGLE_CLIENT_ID=...apps.googleusercontent.com \
  -d <device-id>
```

> La prima build iOS esegue `pod install` e scarica l'SDK Mapbox (serve il `sk` in
> `~/.netrc`, §2): può richiedere qualche minuto. I valori `pk`/`GOOGLE_CLIENT_ID`
> correnti sono in `docs/testflight-setup.md` e `docs/cloud-google-drive-setup.md`.

## 5. Comandi utili

```bash
flutter analyze        # lint (deve passare pulito prima di un commit)
flutter test           # suite di test (logica geo/sync)
dart format .          # formattazione
```

## Dove guardare per ripartire

- **Stato e prossimi passi:** `docs/ROADMAP.md` (sezione "Ripartenza rapida" in cima).
- **Decisioni/architettura:** `CLAUDE.md`.
- **Cloud:** `docs/cloud-google-drive-setup.md`, `docs/cloud-icloud-setup.md`.
- **Beta:** `docs/testflight-setup.md`.
