import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Riga di una traccia salvata. I dati strutturati (waypoint, percorso, profilo,
/// sentieri) sono serializzati in JSON; la decodifica avviene nel repository.
class TrackRows extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get color => integer()();
  BoolColumn get snapToTrail => boolean().withDefault(const Constant(true))();
  TextColumn get waypoints => text()(); // JSON [[lat,lng],...]
  TextColumn get routedPath => text().withDefault(const Constant('[]'))();
  TextColumn get trailRefs => text().withDefault(const Constant('[]'))();
  TextColumn get metrics => text().nullable()(); // JSON o null
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [TrackRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'sentei'));

  @override
  int get schemaVersion => 1;

  Future<List<TrackRow>> allTracks() =>
      (select(trackRows)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  Future<void> upsertTrack(TrackRowsCompanion row) =>
      into(trackRows).insertOnConflictUpdate(row);

  Future<void> deleteTrack(String id) =>
      (delete(trackRows)..where((t) => t.id.equals(id))).go();
}
