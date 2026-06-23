<div align="center">

# 🏔️ Sentèi

**Mappe e tracciati per l'escursionismo sulle Alpi.**
Disegna, salva ed esporta i tuoi percorsi — anche senza segnale.

<sub>«Sentèi» = sentieri in dialetto piemontese · nome tecnico del progetto: `sentei`</sub>

_Un'alternativa open e gratuita a GaiaGPS, pensata per il Nord Italia e le zone di confine con Francia e Svizzera._

</div>

---

## ✨ Funzionalità

- 🗺️ **Mappa topografica con terreno 3D** — Mapbox Outdoors con hillshade/rilievo e numeri sentiero **CAI** lungo i tracciati.
- ✏️ **Disegno tracciati con snap-to-trail** — i punti vengono instradati sui sentieri reali (BRouter), con calcolo automatico di **distanza** e **dislivello** (D+/D-) e profilo altimetrico interattivo.
- 💾 **Salvataggio locale** — libreria di tracciati ordinabile e ricercabile; nascondi/mostra le tracce sulla mappa.
- 📤 **Import/Export GPX** — compatibile con gli altri strumenti che già usi.
- ☁️ **Sync su iCloud Drive e Google Drive** — i tuoi tracciati sul tuo cloud personale, con **sincronizzazione automatica** dopo salvataggi ed eliminazioni.
- 📴 **Offline-first** — scarica aree (mappa + elevazione) e usa l'app dove il segnale non arriva.

## 📱 Piattaforme

iOS e Android, da un unico codebase **Flutter**. (Sviluppo e test attuali: iOS.)

## 🛠️ Stack

| | |
|---|---|
| Framework | Flutter (Dart) |
| Mappa | **Mapbox GL** (`mapbox_maps_flutter`) — stile Outdoors, terreno 3D |
| Dati | Mapbox Outdoors · OpenStreetMap (numeri sentiero CAI via Overpass) · DEM Terrarium (quota) |
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

- **Fase 0** — Setup + mappa ✅
- **Fase 1 (MVP)** — Disegno + snap-to-trail, distanza/dislivello, GPX, aree offline ✅ *(download offline da validare su device)*
- **Fase 2** — Sync cloud (Drive + iCloud, auto-sync) ✅ · registrazione traccia live ⏳
- **Fase 3** — Rifiniture: ricerca località, waypoint, statistiche ⏳

Stato dettagliato e prossimi passi: **[`docs/ROADMAP.md`](./docs/ROADMAP.md)**.

## 📖 Documentazione

Scelte architetturali, sorgenti dati e licenze in **[`CLAUDE.md`](./CLAUDE.md)**. Setup sviluppo: **[`docs/dev-setup.md`](./docs/dev-setup.md)**. Cloud: [`docs/cloud-google-drive-setup.md`](./docs/cloud-google-drive-setup.md) · [`docs/cloud-icloud-setup.md`](./docs/cloud-icloud-setup.md). Beta: [`docs/testflight-setup.md`](./docs/testflight-setup.md).

## ⚖️ Licenze & attribuzioni

I dati cartografici appartengono ai rispettivi proprietari (OpenStreetMap, OpenTopoMap, SwissTopo, IGN) e sono usati nel rispetto delle relative licenze, con attribuzione in-app. **Sentèi** è un progetto personale ispirato a GaiaGPS e non ne riusa codice o dati proprietari.

---

<div align="center">
<sub>Fatto con ❤️ per la montagna.</sub>
</div>
