import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Tipo di sorgente cartografica.
enum MapSourceKind { base, overlay }

/// Filtro "muted" ispirato a GaiaGPS: riduce la saturazione al ~60% e alza di
/// poco la luminosità. La base topografica risulta con **meno colori** e più
/// **gradienti dello stesso tono** → mappa più leggibile e meno "confusionaria".
/// Matrice 4x5 luminanza-preservante (coeff. Rec.709) applicata via [ColorFiltered].
const ColorFilter mutedTopoFilter = ColorFilter.matrix(<double>[
  0.56693, 0.39336, 0.03971, 0, 12, //
  0.11693, 0.84336, 0.03971, 0, 12, //
  0.11693, 0.39336, 0.48971, 0, 12, //
  0, 0, 0, 1, 0, //
]);

/// Descrive una sorgente di tile (base o overlay) con i metadati necessari
/// a costruire il [TileLayer] e a mostrare l'attribuzione obbligatoria.
///
/// Ogni nuova sorgente va aggiunta qui con la sua attribuzione (vedi §4 e §11
/// del CLAUDE.md). Tutte le sorgenti previste sono in Web Mercator (EPSG:3857),
/// quindi compatibili con flutter_map senza riproiezione.
class MapSource {
  const MapSource({
    required this.id,
    required this.name,
    required this.urlTemplate,
    required this.attribution,
    this.kind = MapSourceKind.base,
    this.subdomains = const <String>[],
    this.maxNativeZoom = 17,
    this.maxZoom = 19,
    this.attributionUrl,
    this.note,
    this.muteByDefault = true,
  });

  /// Identificatore tecnico stabile (usato per persistenza/preferenze).
  final String id;

  /// Nome visualizzato nel selettore sorgente.
  final String name;

  /// Template XYZ/WMTS-RESTful. Supporta `{x}`, `{y}`, `{z}` e `{s}`.
  final String urlTemplate;

  /// Testo di attribuzione obbligatorio mostrato in mappa.
  final String attribution;

  /// Link aperto dal tap sull'attribuzione (licenza/sito).
  final String? attributionUrl;

  /// Base layer selezionabile oppure overlay sovrapponibile.
  final MapSourceKind kind;

  /// Sottodomini per il placeholder `{s}` (es. `['a','b','c']`).
  final List<String> subdomains;

  /// Massimo zoom con tile native disponibili dalla sorgente.
  final int maxNativeZoom;

  /// Massimo zoom di visualizzazione (oltre [maxNativeZoom] si fa upscaling).
  final int maxZoom;

  /// Nota interna (licenza/fair-use) — non mostrata all'utente.
  final String? note;

  /// Se applicare di default il filtro [mutedTopoFilter] (palette calma).
  /// Falso per le basi già tenui (es. Stamen Terrain), che altrimenti
  /// risulterebbero slavate.
  final bool muteByDefault;

  /// Costruisce il [TileLayer] per flutter_map.
  ///
  /// Con [muted] la base viene resa con il filtro [mutedTopoFilter] (palette
  /// calma stile GaiaGPS). Da usare solo sui layer base, non sugli overlay.
  TileLayer toTileLayer({bool muted = false}) => TileLayer(
        urlTemplate: urlTemplate,
        subdomains: subdomains,
        maxNativeZoom: maxNativeZoom,
        maxZoom: maxZoom.toDouble(),
        userAgentPackageName: 'com.mattiacuratitoli.sentei',
        tileBuilder: muted
            ? (context, tileWidget, tile) => ColorFiltered(
                  colorFilter: mutedTopoFilter,
                  child: tileWidget,
                )
            : null,
        // Degradazione graziosa dei 404: alcune sorgenti (es. IGN) coprono solo
        // una parte del territorio (la Francia) e restituiscono 404 altrove
        // (lato italiano, ad alto zoom). Evizione delle tile in errore quando
        // escono dalla vista → niente tile "rotte" persistenti né loop di retry.
        evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
        // TODO(offline): collegare il tileProvider FMTC per il caching (§6.1).
      );
}
