# Changelog — Sentèi

Novità per versione. Le voci sono scritte per chi usa l'app, non un log tecnico —
per i dettagli di sviluppo vedi **[`docs/CHANGELOG-DEV.md`](docs/CHANGELOG-DEV.md)**;
per cosa resta da fare vedi **[`docs/ROADMAP.md`](docs/ROADMAP.md)**.

Il numero fra parentesi è il **build** (`CFBundleVersion`/`versionCode`); la app in
Impostazioni → Informazioni mostra `versione (build)`, es. `1.0.0 (4)`.

## In lavorazione (non ancora rilasciato)

_Nessuna novità in coda al momento._

## 1.0.0 (5) — 24 luglio 2026

- 🌙 **Modalità scura** con 3 varianti — Standard, Notturno (toni caldi per
  preservare la visione notturna in montagna) e Risparmio energetico (nero
  puro, pannelli senza sfocatura); cambio tema con transizione morbida invece
  che a scatto, accento caldo coerente in tutta l'app (non solo testo/icone).
- 🗺️ **Mappa scura automatica**, coordinata col tema dell'app.
- ✏️ **Editing avanzato dei tracciati**: aggiungere/spostare punti intermedi,
  undo multiplo, ri-instradamento incrementale sui sentieri.
- 📥 **Import GPX migliorato**: riallineamento ibrido dei tracciati importati
  da altre app/dispositivi.
- 📖 **Legenda estesa**: gradi alpinistici, scala Welzenbach e abbreviazioni
  ricorrenti sulle guide CAI.
- 🎬 Nuovo **splash screen** animato (isoipse + dissolvenza in ingresso).
- 📸 Prime fondamenta per collegare le **foto scattate lungo il percorso**
  alla traccia (ricerca nella libreria, non ancora in interfaccia).
- 📍 All'apertura la mappa si centra sempre sulla posizione GPS corrente.
- 📋 **Novità in-app**: questo changelog, in versione sintetica, ora si vede
  toccando Impostazioni → Informazioni → Sentèi.

## 1.0.0 (4) — 5 luglio 2026

- **Menu e conferme in stile iOS** (à la Apple Photos) — es. conferma prima
  di eliminare una traccia.
- **Ordinamento tracciati** salvato: alfabetico, per data, dislivello (D+) o
  quota più alta.
- **Cloud per piattaforma**: iCloud Drive su iOS, Google Drive su Android.

## 1.0.0 (3) — 2 luglio 2026

- **Legenda difficoltà CAI** in Impostazioni + tooltip nel grafico del
  profilo altimetrico.
- **Info punto**: tocca un punto qualsiasi della mappa per vedere quota,
  coordinate e località/provincia/nazione.
- **Vista satellite** agganciata al tasto livelli; barra di ricerca in stile
  vetro.
- Privacy policy pubblicata (richiesta da App Store/TestFlight).

## 1.0.0 (2) — 25 giugno 2026

- **Ricerca** di località e rifugi alpini.
- **Segnavia CAI ufficiali** (catasto OSM2CAI, con fallback OpenStreetMap) e
  **grado di difficoltà CAI** (T/E/EE/EEA) nella card del percorso.
- Riordino dei controlli mappa (bussola sempre visibile, passaggio 2D/3D).
- Prima interfaccia in stile **"vetro smerigliato"** iOS (Apple Maps).
- Guida per generare e distribuire l'APK Android.

## 1.0.0 (1) — 16 giugno 2026

Prima beta, distribuita su TestFlight.

- Mappa **Mapbox Outdoors** con terreno 3D e vista satellite.
- **Disegno tracciati** con snap-to-trail sui sentieri reali (BRouter).
- Calcolo di **distanza**, **dislivello** (D+/D-) e **profilo altimetrico**.
- Numeri sentiero CAI sul profilo altimetrico.
- **Posizione GPS** in tempo reale e bussola.
- **Salvataggio locale** (libreria tracciati) ed **export/import GPX**.
- **Download mappe ed elevazione offline**, per l'uso senza connessione.
- **Sync** su Google Drive e iCloud Drive.
