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
  // Segnavia/difficoltà CAI già cercati (a prescindere dall'esito). Le tracce
  // salvate prima della funzionalità hanno false → backfill lazy alla selezione.
  BoolColumn get trailsResolved =>
      boolean().withDefault(const Constant(false))();
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2: aggiunge la colonna trailsResolved (default false) alle tracce
          // esistenti, così vengono risolte in modo lazy alla selezione.
          if (from < 2) {
            await m.addColumn(trackRows, trackRows.trailsResolved);
          }
        },
      );

  Future<List<TrackRow>> allTracks() =>
      (select(trackRows)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  Future<void> upsertTrack(TrackRowsCompanion row) =>
      into(trackRows).insertOnConflictUpdate(row);

  Future<void> deleteTrack(String id) =>
      (delete(trackRows)..where((t) => t.id.equals(id))).go();
}
