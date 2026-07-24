<div align="center">

# 🏔️ Sentèi

**Mappe e tracciati per l'escursionismo sulle Alpi.**
Disegna, salva ed esporta i tuoi percorsi — anche senza segnale.

<sub>«Sentèi» = sentieri in dialetto piemontese · nome tecnico del progetto: `sentei`</sub>

_Un'alternativa open e gratuita a GaiaGPS, pensata per il Nord Italia e le zone di confine con Francia e Svizzera._

</div>

---

## ✨ Funzionalità

- 🗺️ **Mappa topografica con terreno 3D + vista satellite** — Mapbox Outdoors con hillshade/rilievo e numeri sentiero **CAI** (dal catasto ufficiale **OSM2CAI/REI**, con fallback OpenStreetMap) lungo i tracciati; passaggio Mappa ⇄ Satellite con un tocco.
- 📡 **GPS e ricerca** — posizione in tempo reale con bussola; **all'apertura la mappa si centra sulla tua posizione corrente**; ricerca di località e rifugi.
- ✏️ **Disegno multi-traccia con snap-to-trail** — i punti vengono instradati sui sentieri reali (BRouter), con calcolo automatico di **distanza**, **dislivello** (D+/D-), profilo altimetrico interattivo e **grado di difficoltà CAI** (T/E/EE/EEA, con legenda in-app).
- 📍 **Info punto** — tocca un punto qualsiasi della mappa per vederne **quota**, **coordinate** e **località/provincia/nazione**.
- 💾 **Salvataggio locale** — libreria di tracciati ordinabile e ricercabile.
- 📤 **Import/Export GPX** — compatibile con gli altri strumenti che già usi.
- ☁️ **Sync su iCloud Drive e Google Drive** — i tuoi tracciati sul tuo cloud personale, con **sincronizzazione automatica** dopo salvataggi ed eliminazioni.
- 📴 **Offline-first** — scarica aree (mappa + elevazione) e usa l'app dove il segnale non arriva.
- 🍎 **Interfaccia iOS-native** — controlli in vetro smerigliato, liste e sheet Cupertino, tipografia di sistema.
- 🌙 **Modalità scura** — automatica o manuale, con 3 varianti (Standard, Notturno per la montagna, Risparmio energetico) e mappa scura coordinata.
- ✏️ **Editing avanzato dei tracciati** — sposta, inserisci ed elimina punti intermedi con ri-instradamento incrementale; import GPX riallineato ai sentieri rilevati.

## 📱 Piattaforme

iOS e Android, da un unico codebase **Flutter**. (Sviluppo e test attuali: iOS.)

## 🛠️ Stack

| | |
|---|---|
| Framework | Flutter (Dart) |
| Mappa | **Mapbox GL** (`mapbox_maps_flutter`) — stile Outdoors, terreno 3D |
| Dati | Mapbox Outdoors · **OSM2CAI** (catasto ufficiale CAI/REI) + OpenStreetMap/Overpass per i numeri sentiero · DEM Terrarium (quota) |
| Routing | **BRouter** (snap-to-trail escursionistico) |
| Offline | Mapbox OfflineManager/TileStore + DEM Terrarium cacheato |
| Storage | SQLite (`drift`) + file GPX |
| Cloud | iCloud Drive · Google Drive |

## 🚀 Avvio rapido

```bash
flutter pub get
flutter run \
  --dart-define=MAPBOX_TOKEN=pk... \
  --dart-define=GOOGLE_CLIENT_ID=...apps.googleusercontent.com \
  -d <device-id>
```

> Servono un **token Mapbox** (`pk`, a runtime) + il **secret download token** (`sk`) in `~/.netrc` per scaricare l'SDK in build. Setup completo da zero (nuovo Mac, segreti, firma iOS): **[`docs/dev-setup.md`](./docs/dev-setup.md)**.

## 🗺️ Roadmap

> **Stato attuale (24 lug 2026):** beta **`1.0.0+5`** rilasciata ai tester — **iOS su TestFlight** + **APK Android**. UI iOS-native con **modalità scura**, editing avanzato dei tracciati, import GPX riallineato, sync **iCloud** (iOS) e **Google Drive** (iOS + Android).

- **Fase 0** — Setup + mappa ✅
- **Fase 1 (MVP)** — Disegno + snap-to-trail, distanza/dislivello, GPX, aree offline ✅ *(download offline implementato, da validare in modalità aereo su device)*
- **Fase 2** — Sync cloud (Drive + iCloud, auto-sync) ✅ *(iCloud su iOS; **Google Drive su iOS + Android**)* · registrazione traccia live ⏳
- **Fase 3** — Rifiniture: ricerca località, waypoint, statistiche ⏳

Stato dettagliato e prossimi passi, in ordine di priorità: **[`docs/ROADMAP.md`](./docs/ROADMAP.md)**.

## 📝 Changelog

Novità per versione, in linguaggio semplice (la stessa lista è in-app, Impostazioni → Informazioni → Sentèi): **[`CHANGELOG.md`](./CHANGELOG.md)**. Versione tecnica estesa, con dettagli di implementazione: **[`docs/CHANGELOG-DEV.md`](./docs/CHANGELOG-DEV.md)**.

## 📖 Documentazione

Scelte architetturali, sorgenti dati e licenze in **[`CLAUDE.md`](./CLAUDE.md)**. Setup sviluppo: **[`docs/dev-setup.md`](./docs/dev-setup.md)**. Cloud: [`docs/cloud-google-drive-setup.md`](./docs/cloud-google-drive-setup.md) · [`docs/cloud-icloud-setup.md`](./docs/cloud-icloud-setup.md). Beta: [`docs/testflight-setup.md`](./docs/testflight-setup.md). Privacy: [`docs/privacy-policy.html`](./docs/privacy-policy.html).

## 🎯 Natura del progetto

**Sentèi è un progetto personale e senza fini di lucro**, sviluppato e distribuito unicamente per **scopi ricreativi e di test personale**. Non è un prodotto commerciale: nessuna pubblicità, nessuna monetizzazione, nessuna raccolta di dati su server propri. Le mappe e i servizi di terze parti sono usati nei limiti delle rispettive licenze per uso non commerciale.

## ⚖️ Licenze & attribuzioni

La mappa di base è **Mapbox** (Outdoors/Dark/Satellite), con attribuzione in-app come richiesto dai termini del servizio. I numeri dei sentieri e il grado di difficoltà CAI provengono dal **Catasto della Rete Escursionistica Italiana (OSM2CAI/INFOMONT — CAI + Wikimedia Italia, licenza ODbL)**, con fallback su **OpenStreetMap** (Overpass API) nelle zone di confine con Francia e Svizzera. **Sentèi** è un progetto personale ispirato a GaiaGPS e non ne riusa codice o dati proprietari.

---

<div align="center">
<sub>Fatto con ❤️ per la montagna.</sub>
</div>
