<div align="center">

# 🏔️ Sentèi

**Mappe e tracciati per l'escursionismo sulle Alpi.**
Disegna, salva ed esporta i tuoi percorsi — anche senza segnale.

<sub>«Sentèi» = sentieri in dialetto piemontese · nome tecnico del progetto: `sentei`</sub>

_Un'alternativa open e gratuita a GaiaGPS, pensata per il Nord Italia e le zone di confine con Francia e Svizzera._

</div>

---

## ✨ Funzionalità

- 🗺️ **Mappe topografiche affidabili** — OpenTopoMap + cartografia ufficiale SwissTopo (CH) e IGN (FR), con overlay dei sentieri segnati.
- ✏️ **Disegno tracciati** — crea percorsi sulla mappa con calcolo automatico di **distanza** e **dislivello** (D+/D-).
- 💾 **Salvataggio** — la tua libreria di tracciati sempre a portata di mano.
- 📤 **Import/Export GPX** — compatibile con gli altri strumenti che già usi.
- ☁️ **Sync su iCloud Drive e Google Drive** — i tuoi tracciati sul tuo cloud personale.
- 📴 **Offline-first** — scarica le aree e usa l'app dove il segnale non arriva.

## 📱 Piattaforme

iOS e Android, da un unico codebase **Flutter**.

## 🛠️ Stack

| | |
|---|---|
| Framework | Flutter (Dart) |
| Mappa | `flutter_map` (tile raster multi-sorgente) |
| Dati | OpenStreetMap · OpenTopoMap · SwissTopo · IGN · Waymarked Trails |
| Offline | tile caching (FMTC) + elevazione da DEM Terrarium |
| Storage | SQLite (`drift`) + file GPX |
| Cloud | iCloud Drive · Google Drive |

## 🚀 Avvio rapido

```bash
flutter pub get      # installa le dipendenze
flutter devices      # elenca i device disponibili
flutter run          # avvia su device/simulatore
flutter test         # esegue i test
```

## 🗺️ Roadmap

- **Fase 0** — Setup + mappa con sorgenti selezionabili
- **Fase 1 (MVP)** — Disegno tracciati, distanza/dislivello, GPX, aree offline
- **Fase 2** — Sync cloud + snap-to-trail (routing sui sentieri)
- **Fase 3** — Rifiniture: ricerca località, waypoint, statistiche

## 📖 Documentazione

Le scelte architetturali, le sorgenti dati e le note di licenza sono in **[`CLAUDE.md`](./CLAUDE.md)**.

## ⚖️ Licenze & attribuzioni

I dati cartografici appartengono ai rispettivi proprietari (OpenStreetMap, OpenTopoMap, SwissTopo, IGN) e sono usati nel rispetto delle relative licenze, con attribuzione in-app. **Sentèi** è un progetto personale ispirato a GaiaGPS e non ne riusa codice o dati proprietari.

---

<div align="center">
<sub>Fatto con ❤️ per la montagna.</sub>
</div>
