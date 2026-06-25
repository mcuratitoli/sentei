# Far provare Sentèi agli amici (TestFlight) — guida passo passo

> Guida operativa per **caricare una nuova build** e **invitare amici** con iPhone.
> Per il setup iniziale completo vedi `testflight-setup.md`.
> App: **Sentèi**, bundle `com.mattiacuratitoli.sentei`, team `W8XCSNY6V3`.

---

## Parte A — Caricare la nuova build

> La build la genera Claude con `flutter build ipa` (output `build/ios/ipa/sentei.ipa`).
> Ricorda: **ogni upload deve avere un build number nuovo** (`1.0.0+2`, `+3`, …),
> già incrementato in `pubspec.yaml`.

1. Apri l'app **Transporter** sul Mac (gratis sul Mac App Store) e accedi col tuo Apple ID.
2. Trascina dentro `build/ios/ipa/sentei.ipa` → **Deliver**.
3. Aspetta che Apple "processi" la build (~5–15 min). La trovi in
   **App Store Connect → Sentèi → tab TestFlight**: deve passare da
   *Processing* a **Ready to Submit**.

---

## Parte B — Renderla disponibile agli amici (tester esterni)

Gli amici non sono nel tuo team Apple → vanno aggiunti come **tester esterni**.
La distinzione importante:

| | Internal Testing | **External Testing** ← amici |
|---|---|---|
| Chi | solo membri del tuo team Apple | **chiunque, via email** |
| Beta Review | no, immediato | sì, una volta (poche ore) |

### Se NON hai ancora un gruppo esterno

1. App Store Connect → **Sentèi → TestFlight**.
2. Colonna di sinistra, accanto a **`EXTERNAL TESTING`**, clicca il **➕**.
3. Nome gruppo: **`Amici`** → **Create**.

### Aggiungi gli amici e la build

4. Apri il gruppo esterno → sezione **Testers** → **➕ Add New Testers** →
   inserisci **email + nome + cognome** di ogni amico → **Add**.
5. Stesso gruppo → sezione **Builds** → **➕** → seleziona la build
   (es. `1.0.0 (2)`) → **Add**.
6. Compila, se richiesto, le **Test Information** a livello app (menu sinistro
   *Additional → Test Information*): Beta Description, **Feedback Email**
   `m.curatitoli@gmail.com`, e **Privacy Policy URL**
   `https://mcuratitoli.github.io/sentei/privacy-policy.html`.

### Invia alla Beta Review

7. Aggiungendo la build a un gruppo esterno parte il **Submit for Beta Review**
   (conferma se te lo chiede). Stato → **Waiting for Beta Review**.
8. **Solo la prima** build per il gruppo passa la review (poche ore, <24h). Le
   build successive per lo stesso gruppo sono disponibili **subito**.

### Gli amici installano

9. Approvata la review, gli amici ricevono un'**email di invito**.
10. Sull'iPhone installano l'app **TestFlight** dall'App Store → aprono l'invito
    (o inseriscono il codice) → **Accetta** → installano **Sentèi**.

> **Aggiornamenti futuri:** Claude genera una build con numero incrementato →
> tu la carichi con Transporter (Parte A) → in TestFlight la **assegni al gruppo
> Amici** (Builds → ➕). Niente nuova review se il gruppo è già approvato; gli
> amici ricevono la notifica di aggiornamento in TestFlight.

---

## Problemi comuni

- **"Missing Compliance" / export encryption:** già gestito
  (`ITSAppUsesNonExemptEncryption=false` in `Info.plist`), non dovrebbe chiederlo.
- **Privacy Policy URL non valido:** assicurati che
  `https://mcuratitoli.github.io/sentei/privacy-policy.html` si apra nel browser
  (GitHub Pages attivo: repo pubblico → Settings → Pages → branch `main`, `/docs`).
- **Build "Invalid" dopo l'upload:** apri la build in TestFlight, leggi il motivo
  (di solito metadati/entitlement) e ricarica con un nuovo build number.
