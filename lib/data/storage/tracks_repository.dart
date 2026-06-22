import 'dart:convert';
import 'dart:ui' show Color;

import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/services/track_metrics.dart';
import '../../features/draw_route/route_editor_provider.dart';
import 'app_database.dart';
import 'track_codec.dart';

/// Persiste le tracce su SQLite (drift) convertendo tra [DrawnTrack] di dominio
/// e righe del database (dati strutturati serializzati in JSON).
class TracksRepository {
  TracksRepository(this._db);

  final AppDatabase _db;

  Future<List<DrawnTrack>> loadAll() async {
    final rows = await _db.allTracks();
    return rows.map(_fromRow).toList();
  }

  /// Tracce con il loro timestamp di ultima modifica (per la sync cloud).
  Future<List<({DrawnTrack track, DateTime updatedAt})>>
      loadAllWithUpdatedAt() async {
    final rows = await _db.allTracks();
    return [for (final r in rows) (track: _fromRow(r), updatedAt: r.updatedAt)];
  }

  /// Salva una traccia. [updatedAt] esplicito quando si applica una versione
  /// remota (per preservarne il timestamp ed evitare ri-upload inutili);
  /// altrimenti si usa "adesso".
  Future<void> save(DrawnTrack track, {DateTime? updatedAt}) async {
    final now = DateTime.now();
    await _db.upsertTrack(TrackRowsCompanion(
      id: Value(track.id),
      name: Value(track.name),
      color: Value(track.color.toARGB32()),
      snapToTrail: Value(track.snapToTrail),
      waypoints: Value(_encodePoints(track.waypoints)),
      routedPath: Value(_encodePoints(track.routedPath)),
      trailRefs: Value(jsonEncode(track.trailRefs)),
      metrics: Value(_encodeMetrics(track.metrics)),
      createdAt: Value(track.createdAt ?? now),
      updatedAt: Value(updatedAt ?? now),
    ));
  }

  Future<void> delete(String id) => _db.deleteTrack(id);

  // ---- serializzazione (delegata a TrackCodec, fonte di verità) -----------

  static String _encodePoints(List<LatLng> pts) =>
      jsonEncode(TrackCodec.pointsToJson(pts));

  static List<LatLng> _decodePoints(String json) =>
      TrackCodec.pointsFromJson(jsonDecode(json) as List);

  static String? _encodeMetrics(TrackMetrics? m) {
    final map = TrackCodec.metricsToJson(m);
    return map == null ? null : jsonEncode(map);
  }

  static TrackMetrics? _decodeMetrics(String? json) => json == null
      ? null
      : TrackCodec.metricsFromJson(jsonDecode(json) as Map<String, dynamic>);

  static DrawnTrack _fromRow(TrackRow r) => DrawnTrack(
        id: r.id,
        name: r.name,
        color: Color(r.color),
        snapToTrail: r.snapToTrail,
        waypoints: _decodePoints(r.waypoints),
        routedPath: _decodePoints(r.routedPath),
        trailRefs: (jsonDecode(r.trailRefs) as List).cast<String>(),
        metrics: _decodeMetrics(r.metrics),
        createdAt: r.createdAt,
      );
}
