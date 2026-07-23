# Mappa scura in dark mode — analisi

> Roadmap P2, step "prossimo" del dark mode. Analisi 23 lug 2026, **nessuna
> implementazione** (solo ricerca/valutazione, come richiesto).

## Stato attuale

- Stile base: **Outdoors** (`MapboxStyles.OUTDOORS`, `mapbox://styles/mapbox/outdoors-v12`),
  fissato in CLAUDE.md §2 ("scelte fissate, discuterne prima di cambiare").
- L'app ha già **un secondo stile**: Satellite (`satellite-streets-v12`), scelto
  manualmente dall'utente col tasto "vista" nella barra (`MapStyleChoice`,
  `_setStyle`/`loadStyleURI`). Ogni cambio stile **re-imposta** (`_styleSetup`,
  chiamato da `onStyleLoaded`): terreno 3D (DEM), sky/atmosfera, hillshade
  extra, source+layer numeri sentiero CAI, i manager annotation (tracce,
  waypoint, cursore, ecc.). Questo re-setup è **già la stessa identica
  meccanica** che servirebbe per aggiungere un terzo stile scuro — nessuna
  nuova architettura, solo un'altra `loadStyleURI` + le stesse routine.
- Elementi **nostri** (non dello stile Mapbox), quindi già sotto il nostro
  controllo indipendentemente dallo stile base: hillshade, terreno, sky,
  layer/etichette sentieri CAI, linea ripidezza, tracce disegnate, waypoint.
  Solo la **label dei sentieri CAI** ha colori hardcoded pensati per sfondo
  chiaro (`textColor 0xFF1B5E20` verde scuro, `textHaloColor` bianco) — da
  rivedere per un fondo scuro.
- L'icona attribuzione "i" ha un `iconColor` impostabile (oggi antracite
  `0xFF3A3A3C`) — andrebbe schiarita in dark. Il **logo Mapbox** invece si
  auto-adatta chiaro/scuro nativamente in base allo stile (nessuna proprietà
  di colore in `LogoSettings`: enabled/position/margini soltanto).

## Opzioni per lo stile scuro (verificate sul plugin installato, non ipotizzate)

`lib/.../mapbox_styles.dart` (v2.25.0 installata) espone questi stili pronti:
`STANDARD`, `STANDARD_SATELLITE`, `MAPBOX_STREETS`, `OUTDOORS`, `LIGHT`, `DARK`
(`dark-v11`), `SATELLITE`, `SATELLITE_STREETS`.

### Opzione A — Aggiungere `MapboxStyles.DARK` come terzo stile (consigliata)

Stesso pattern di Satellite: `loadStyleURI(dark-v11)` quando il tema app è
scuro, `_styleSetup` fa il resto. **Nessun cambio architetturale**, rischio
basso, riusa tutto quello che c'è già.

- **Limite onesto**: `dark-v11` è descritto da Mapbox come "subtle dark
  backdrop for **data visualization**" — è uno stile generico (stradale/POI),
  **non** una versione scura di Outdoors. Perde le sfumature outdoor-specifiche
  della vettoriale Outdoors (vegetazione, curve di livello native, colori
  terreno), ma buona parte del "carattere outdoor" di Sentèi è già nei **nostri**
  layer sopra (hillshade, sentieri CAI, terreno 3D) → il degrado percepito
  potrebbe essere minore del previsto. Da **verificare a schermo** prima di
  giudicare se è accettabile.
- Modifiche necessarie: (1) nuovo `_darkStyleUri` costante; (2) `MapStyleChoice`
  → aggiungere `dark` (o meglio: **separare** "vista" [Mappa/Satellite, scelta
  utente] da "tema mappa" [chiaro/scuro, derivato dall'app] — vedi §Domande);
  (3) ricolorare la label CAI per contrasto su sfondo scuro; (4) `iconColor`
  attribuzione più chiaro in dark; (5) eventualmente hillshade/sky con
  parametri diversi (il colore ombra/luce di `sentei-hillshade` è tarato per
  Outdoors chiaro).

### Opzione B — Stile Studio custom "Outdoors Dark"

Creare in Mapbox Studio una variante scura *disegnata apposta* per l'escursionismo
(curve di livello, vegetazione, sentieri leggibili su fondo scuro). Risultato
migliore ma: richiede lavoro di design **fuori dal codice** (Mapbox Studio),
un nuovo style ID da mantenere nel tempo, e verificare i limiti del piano
Mapbox (numero di stili custom). Non fattibile "da codice" in questa sessione.

### Opzione C — Migrare a `MapboxStyles.STANDARD` + `lightPreset`

Lo stile **Standard** (v3, `mapbox://styles/mapbox/standard`) supporta
nativamente **preset di luce runtime** senza cambiare URI:
```dart
mapboxMap.style.setStyleImportConfigProperties("basemap", {
  "lightPreset": "night", // dawn | day | dusk | night
});
```
(verificato negli esempi ufficiali del plugin, `standard_style_import_example.dart`).
È il meccanismo "giusto" secondo Mapbox per day/night — ma **Standard non è
Outdoors**: è lo stile generico 3D "stile Google/Apple Maps" con edifici/POI,
non tarato per l'escursionismo. Sostituire Outdoors con Standard è **la stessa
categoria di scelta che CLAUDE.md §2 marca come fissata** ("se emergono motivi
per cambiarle, discuterne prima") → richiede una decisione esplicita, non è
un'estensione a basso rischio come l'Opzione A.

## Legame con le 3 varianti dark (Standard/Notturno/Risparmio energetico)

Né l'Opzione A né la C offrono 3 "sapori" di scurezza nativi — Mapbox non ha
un dark-v11 "notturno caldo" o "OLED". Realisticamente: **un'unica mappa scura
condivisa** dalle 3 varianti (la differenza Standard/Notturno/OLED resta solo
nella UI Flutter — barra, controlli, card — non nella mappa nativa). Un domani
si potrebbe aggiungere una tinta overlay semi-trasparente per differenziare
"Notturno" (più caldo), ma è un extra, non necessario al primo giro.

## Raccomandazione

**Opzione A** (terzo stile `DARK`, stesso meccanismo di Satellite), con
verifica visiva prima di decidere se il compromesso "generico ma via
tutti-i-layer-nostri" è accettabile o se serve poi l'Opzione B (Studio) per
rifinire. Effort: medio-basso (stesso pattern esistente + 4-5 piccole
modifiche di colore). Scartare/rimandare l'Opzione C (cambio di stile base,
fuori scope di una singola sessione, richiede discussione dedicata).

## Domande aperte (da decidere prima di implementare)

1. **Automatico o manuale?** La mappa scura scatta da sola quando il tema app
   è scuro (coerenza totale, meno controllo utente) oppure resta una scelta
   separata nel tasto "vista" (Mappa/Satellite/**Buio**, indipendente dal tema
   app)? *Consiglio: automatico*, coerente con l'aspettativa "dark mode = tutto
   scuro" e con quanto deciso finora.
2. **Satellite in dark**: resta invariata (l'ortofoto non ha un "verso scuro"
   sensato) — confermare che va bene lasciarla com'è anche a tema scuro.
3. **Timing**: procedo con un primo giro implementativo dell'Opzione A (analisi
   già fatta), o preferisci prima vedere uno screenshot/mockup dello stile
   `dark-v11` "grezzo" con i nostri overlay sopra, per giudicare se è
   accettabile prima di investire nelle rifiniture di colore?
