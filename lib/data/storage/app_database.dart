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
  // Foto collegate (§"Sync album fotografico"): JSON [{id,la,ln,d,at,thumb},...]
  // o null. `thumb` è il thumbnail in base64 (l'originale resta in galleria).
  TextColumn get photos => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [TrackRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'sentei'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2: aggiunge la colonna trailsResolved (default false) alle tracce
          // esistenti, così vengono risolte in modo lazy alla selezione.
          if (from < 2) {
            await m.addColumn(trackRows, trackRows.trailsResolved);
          }
          // v3: sblocca le tracce marcate "risolte" ma senza segnavia. Con la
          // vecchia logica un fallimento transitorio della ricerca (timeout/
          // errore rete) veniva scambiato per "nessun segnavia" e la traccia
          // restava senza numeri e senza retry. Ora la ricerca lancia su errore
          // → azzeriamo il flag dove i segnavia sono vuoti, così vengono
          // ri-cercati (una volta) alla prossima selezione.
          if (from < 3) {
            await customStatement(
                "UPDATE track_rows SET trails_resolved = 0 "
                "WHERE trail_refs = '[]' OR trail_refs IS NULL");
          }
          // v4: aggiunge la colonna photos (foto collegate, nullable — le
          // tracce esistenti non ne hanno finché non si usa la funzionalità).
          if (from < 4) {
            await m.addColumn(trackRows, trackRows.photos);
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
