import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../map_sources/map_sources.dart';
import 'terrarium_elevation_service.dart';

/// Fetcher HTTP di default per le tile Terrarium (uso online).
///
/// In Fase 1.F questo verrà sostituito/affiancato da un fetcher che legge dalla
/// cache offline FMTC. La firma [TerrariumTileFetcher] resta invariata.
TerrariumTileFetcher httpTerrariumFetcher({http.Client? client}) {
  final c = client ?? http.Client();
  return (int z, int x, int y) async {
    final url = MapSources.terrariumTemplate
        .replaceFirst('{z}', '$z')
        .replaceFirst('{x}', '$x')
        .replaceFirst('{y}', '$y');
    try {
      final res = await c.get(Uri.parse(url));
      if (res.statusCode != 200) return null;
      return Uint8List.fromList(res.bodyBytes);
    } catch (_) {
      return null; // rete assente o errore: quota non disponibile
    }
  };
}
