# Indagine API OSM2CAI — segnavia CAI ufficiali

> Fonte: codice sorgente del repository **`webmappsrl/osm2cai`** (branch `develop`), lettura
> di `routes/api.php`, `app/Http/Controllers/HikingRouteController.php`,
> `app/Http/Controllers/V2/HikingRoutesRegionControllerV2.php`, `app/Models/HikingRoute.php`.
> Endpoint **non testati live** (dominio `osm2cai.cai.it` bloccato dalla network policy del sandbox);
> la struttura è ricavata dal sorgente, autoritativa ma da confermare in esecuzione reale.

## Cos'è

OSM2CAI / INFOMONT è la piattaforma ufficiale **CAI + Wikimedia Italia** (struttura tecnica **SOSEC**)
per il **Catasto digitale della Rete Escursionistica Italiana (REI)**. Dati open (**ODbL**).

**Punto chiave:** la *geometria* dei sentieri **è OSM** — CAI usa OSM come database di base. OSM2CAI
aggiunge sopra uno **strato di validazione CAI** (accatastamento) + codici ufficiali + metadati.
Non è un database geometricamente alternativo: è OSM arricchito e validato.

## Endpoint utili

Opzione migliore (GeoJSON completo in una sola chiamata, ideale per il matching lungo un percorso):

```
POST /api/geojson/hiking_routes/bounding_box
  body: osm2cai_status=<sda>, lo0=<lonMin>, la0=<latMin>, lo1=<lonMax>, la1=<latMax>
  → FeatureCollection GeoJSON (geometria + tutti i metadati)
```

Alternativa REST (lista ID → poi singolo percorso):
```
GET /api/v2/hiking-routes/bb/{lonMin,latMin,lonMax,latMax}/{sda}   → lista di ID
GET /api/v2/hiking-route/{id}                                       → singolo percorso (GeoJSON)
GET /api/v2/hiking-routes/{id}.gpx                                  → export GPX diretto
```

### Vincoli verificati nel sorgente
- **Limite area bbox:** se troppo grande → HTTP 500 `"Bounding box is too large"`. Non è un problema:
  si interroga intorno al percorso disegnato (area piccola).
- **`sda` (= `osm2cai_status`):** lista separata da virgola, valori `0,1,2,3,4`. È il **livello di
  accatastamento**: `4` = validato sul campo (geometria ufficiale CAI), valori bassi = geometria OSM
  non ancora verificata. Per i segnavia conviene `1,2,3,4` (escludere solo lo 0 = non lavorato).

## Campi della risposta (più ricchi di Overpass)

| Campo | Contenuto |
|---|---|
| `ref` | Numero sentiero **CAI validato** (es. "102") |
| `ref_osm` | Lo stesso dal tag OSM grezzo (quello usato oggi via Overpass) |
| `ref_REI` / `ref_REI_comp` | Codice **nazionale REI** (catasto ufficiale) |
| `osmc_symbol` | **Simbolo segnavia** (bianco/rosso CAI…) → futuro: segnavia colorato |
| `cai_scale` | Difficoltà CAI (T/E/EE/EEA) |
| `name`, `from`, `to` | Nome e capi-percorso |
| `osm2cai_status` | Livello di validazione (per filtro affidabilità) |
| `ascent`/`descent`/`distance` | Dislivello/distanza **precalcolati** |
| `geometry` *o* `geometry_osm` | Geometria (CAI se sda=4, altrimenti OSM) |

**Per il problema "segnavia mancanti in Valle d'Aosta":** la risposta espone **sia `ref` (CAI) sia
`ref_osm`**. Quando il tag OSM grezzo manca ma il sentiero è accatastato CAI, `ref`/`ref_REI` lo
recupera comunque → OSM2CAI può trovare segnavia dove oggi Overpass torna vuoto.

## Limiti

- **Solo Italia.** Per zone di confine (Monte Rosa lato CH, Alpi FR) serve sempre Overpass.
- **Non sostituisce BRouter** (routing punto-a-punto): OSM2CAI dà percorsi predefiniti, non instrada.
- **Stabilità servizio pubblico** da monitorare → tutto best-effort con fallback.

## Piano di integrazione

1. **`Osm2CaiTrailService`** in `data/trails/` (stessa forma di `OverpassTrailService`): bbox dal
   percorso → `POST /api/geojson/hiking_routes/bounding_box` con `osm2cai_status=1,2,3,4` → matching
   locale punto→sentiero (riuso logica `_nearestRef`), preferendo `ref` su `ref_osm`.
2. **Strategia combinata** (come geocoding Nominatim+Mapbox): **OSM2CAI primario**, **Overpass
   fallback** quando OSM2CAI è vuoto (confine, o servizio giù).
3. **Bonus a basso costo (futuro):** `osmc_symbol` → segnavia colorati; `cai_scale` → chip difficoltà.
