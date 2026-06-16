import 'package:flutter_map/flutter_map.dart';

/// Tipo di sorgente cartografica.
enum MapSourceKind { base, overlay }

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

  /// Costruisce il [TileLayer] per flutter_map.
  TileLayer toTileLayer() => TileLayer(
        urlTemplate: urlTemplate,
        subdomains: subdomains,
        maxNativeZoom: maxNativeZoom,
        maxZoom: maxZoom.toDouble(),
        userAgentPackageName: 'com.mattiacuratitoli.sentei',
        // TODO(offline): collegare il tileProvider FMTC per il caching (§6.1).
      );
}
