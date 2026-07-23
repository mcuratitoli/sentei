// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TrackRowsTable extends TrackRows
    with TableInfo<$TrackRowsTable, TrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
      'color', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _snapToTrailMeta =
      const VerificationMeta('snapToTrail');
  @override
  late final GeneratedColumn<bool> snapToTrail = GeneratedColumn<bool>(
      'snap_to_trail', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("snap_to_trail" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _waypointsMeta =
      const VerificationMeta('waypoints');
  @override
  late final GeneratedColumn<String> waypoints = GeneratedColumn<String>(
      'waypoints', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _routedPathMeta =
      const VerificationMeta('routedPath');
  @override
  late final GeneratedColumn<String> routedPath = GeneratedColumn<String>(
      'routed_path', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _trailRefsMeta =
      const VerificationMeta('trailRefs');
  @override
  late final GeneratedColumn<String> trailRefs = GeneratedColumn<String>(
      'trail_refs', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _metricsMeta =
      const VerificationMeta('metrics');
  @override
  late final GeneratedColumn<String> metrics = GeneratedColumn<String>(
      'metrics', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _trailsResolvedMeta =
      const VerificationMeta('trailsResolved');
  @override
  late final GeneratedColumn<bool> trailsResolved = GeneratedColumn<bool>(
      'trails_resolved', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("trails_resolved" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _photosMeta = const VerificationMeta('photos');
  @override
  late final GeneratedColumn<String> photos = GeneratedColumn<String>(
      'photos', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        color,
        snapToTrail,
        waypoints,
        routedPath,
        trailRefs,
        metrics,
        trailsResolved,
        createdAt,
        updatedAt,
        photos
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_rows';
  @override
  VerificationContext validateIntegrity(Insertable<TrackRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('snap_to_trail')) {
      context.handle(
          _snapToTrailMeta,
          snapToTrail.isAcceptableOrUnknown(
              data['snap_to_trail']!, _snapToTrailMeta));
    }
    if (data.containsKey('waypoints')) {
      context.handle(_waypointsMeta,
          waypoints.isAcceptableOrUnknown(data['waypoints']!, _waypointsMeta));
    } else if (isInserting) {
      context.missing(_waypointsMeta);
    }
    if (data.containsKey('routed_path')) {
      context.handle(
          _routedPathMeta,
          routedPath.isAcceptableOrUnknown(
              data['routed_path']!, _routedPathMeta));
    }
    if (data.containsKey('trail_refs')) {
      context.handle(_trailRefsMeta,
          trailRefs.isAcceptableOrUnknown(data['trail_refs']!, _trailRefsMeta));
    }
    if (data.containsKey('metrics')) {
      context.handle(_metricsMeta,
          metrics.isAcceptableOrUnknown(data['metrics']!, _metricsMeta));
    }
    if (data.containsKey('trails_resolved')) {
      context.handle(
          _trailsResolvedMeta,
          trailsResolved.isAcceptableOrUnknown(
              data['trails_resolved']!, _trailsResolvedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('photos')) {
      context.handle(_photosMeta,
          photos.isAcceptableOrUnknown(data['photos']!, _photosMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color'])!,
      snapToTrail: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}snap_to_trail'])!,
      waypoints: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}waypoints'])!,
      routedPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}routed_path'])!,
      trailRefs: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trail_refs'])!,
      metrics: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metrics']),
      trailsResolved: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}trails_resolved'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      photos: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}photos']),
    );
  }

  @override
  $TrackRowsTable createAlias(String alias) {
    return $TrackRowsTable(attachedDatabase, alias);
  }
}

class TrackRow extends DataClass implements Insertable<TrackRow> {
  final String id;
  final String name;
  final int color;
  final bool snapToTrail;
  final String waypoints;
  final String routedPath;
  final String trailRefs;
  final String? metrics;
  final bool trailsResolved;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? photos;
  const TrackRow(
      {required this.id,
      required this.name,
      required this.color,
      required this.snapToTrail,
      required this.waypoints,
      required this.routedPath,
      required this.trailRefs,
      this.metrics,
      required this.trailsResolved,
      required this.createdAt,
      required this.updatedAt,
      this.photos});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    map['snap_to_trail'] = Variable<bool>(snapToTrail);
    map['waypoints'] = Variable<String>(waypoints);
    map['routed_path'] = Variable<String>(routedPath);
    map['trail_refs'] = Variable<String>(trailRefs);
    if (!nullToAbsent || metrics != null) {
      map['metrics'] = Variable<String>(metrics);
    }
    map['trails_resolved'] = Variable<bool>(trailsResolved);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || photos != null) {
      map['photos'] = Variable<String>(photos);
    }
    return map;
  }

  TrackRowsCompanion toCompanion(bool nullToAbsent) {
    return TrackRowsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      snapToTrail: Value(snapToTrail),
      waypoints: Value(waypoints),
      routedPath: Value(routedPath),
      trailRefs: Value(trailRefs),
      metrics: metrics == null && nullToAbsent
          ? const Value.absent()
          : Value(metrics),
      trailsResolved: Value(trailsResolved),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      photos:
          photos == null && nullToAbsent ? const Value.absent() : Value(photos),
    );
  }

  factory TrackRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
      snapToTrail: serializer.fromJson<bool>(json['snapToTrail']),
      waypoints: serializer.fromJson<String>(json['waypoints']),
      routedPath: serializer.fromJson<String>(json['routedPath']),
      trailRefs: serializer.fromJson<String>(json['trailRefs']),
      metrics: serializer.fromJson<String?>(json['metrics']),
      trailsResolved: serializer.fromJson<bool>(json['trailsResolved']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      photos: serializer.fromJson<String?>(json['photos']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
      'snapToTrail': serializer.toJson<bool>(snapToTrail),
      'waypoints': serializer.toJson<String>(waypoints),
      'routedPath': serializer.toJson<String>(routedPath),
      'trailRefs': serializer.toJson<String>(trailRefs),
      'metrics': serializer.toJson<String?>(metrics),
      'trailsResolved': serializer.toJson<bool>(trailsResolved),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'photos': serializer.toJson<String?>(photos),
    };
  }

  TrackRow copyWith(
          {String? id,
          String? name,
          int? color,
          bool? snapToTrail,
          String? waypoints,
          String? routedPath,
          String? trailRefs,
          Value<String?> metrics = const Value.absent(),
          bool? trailsResolved,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<String?> photos = const Value.absent()}) =>
      TrackRow(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
        snapToTrail: snapToTrail ?? this.snapToTrail,
        waypoints: waypoints ?? this.waypoints,
        routedPath: routedPath ?? this.routedPath,
        trailRefs: trailRefs ?? this.trailRefs,
        metrics: metrics.present ? metrics.value : this.metrics,
        trailsResolved: trailsResolved ?? this.trailsResolved,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        photos: photos.present ? photos.value : this.photos,
      );
  TrackRow copyWithCompanion(TrackRowsCompanion data) {
    return TrackRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      snapToTrail:
          data.snapToTrail.present ? data.snapToTrail.value : this.snapToTrail,
      waypoints: data.waypoints.present ? data.waypoints.value : this.waypoints,
      routedPath:
          data.routedPath.present ? data.routedPath.value : this.routedPath,
      trailRefs: data.trailRefs.present ? data.trailRefs.value : this.trailRefs,
      metrics: data.metrics.present ? data.metrics.value : this.metrics,
      trailsResolved: data.trailsResolved.present
          ? data.trailsResolved.value
          : this.trailsResolved,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      photos: data.photos.present ? data.photos.value : this.photos,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('snapToTrail: $snapToTrail, ')
          ..write('waypoints: $waypoints, ')
          ..write('routedPath: $routedPath, ')
          ..write('trailRefs: $trailRefs, ')
          ..write('metrics: $metrics, ')
          ..write('trailsResolved: $trailsResolved, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('photos: $photos')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      color,
      snapToTrail,
      waypoints,
      routedPath,
      trailRefs,
      metrics,
      trailsResolved,
      createdAt,
      updatedAt,
      photos);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.snapToTrail == this.snapToTrail &&
          other.waypoints == this.waypoints &&
          other.routedPath == this.routedPath &&
          other.trailRefs == this.trailRefs &&
          other.metrics == this.metrics &&
          other.trailsResolved == this.trailsResolved &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.photos == this.photos);
}

class TrackRowsCompanion extends UpdateCompanion<TrackRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> color;
  final Value<bool> snapToTrail;
  final Value<String> waypoints;
  final Value<String> routedPath;
  final Value<String> trailRefs;
  final Value<String?> metrics;
  final Value<bool> trailsResolved;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> photos;
  final Value<int> rowid;
  const TrackRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.snapToTrail = const Value.absent(),
    this.waypoints = const Value.absent(),
    this.routedPath = const Value.absent(),
    this.trailRefs = const Value.absent(),
    this.metrics = const Value.absent(),
    this.trailsResolved = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.photos = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackRowsCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    required int color,
    this.snapToTrail = const Value.absent(),
    required String waypoints,
    this.routedPath = const Value.absent(),
    this.trailRefs = const Value.absent(),
    this.metrics = const Value.absent(),
    this.trailsResolved = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.photos = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        color = Value(color),
        waypoints = Value(waypoints),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<TrackRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<bool>? snapToTrail,
    Expression<String>? waypoints,
    Expression<String>? routedPath,
    Expression<String>? trailRefs,
    Expression<String>? metrics,
    Expression<bool>? trailsResolved,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? photos,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (snapToTrail != null) 'snap_to_trail': snapToTrail,
      if (waypoints != null) 'waypoints': waypoints,
      if (routedPath != null) 'routed_path': routedPath,
      if (trailRefs != null) 'trail_refs': trailRefs,
      if (metrics != null) 'metrics': metrics,
      if (trailsResolved != null) 'trails_resolved': trailsResolved,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (photos != null) 'photos': photos,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<int>? color,
      Value<bool>? snapToTrail,
      Value<String>? waypoints,
      Value<String>? routedPath,
      Value<String>? trailRefs,
      Value<String?>? metrics,
      Value<bool>? trailsResolved,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String?>? photos,
      Value<int>? rowid}) {
    return TrackRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      snapToTrail: snapToTrail ?? this.snapToTrail,
      waypoints: waypoints ?? this.waypoints,
      routedPath: routedPath ?? this.routedPath,
      trailRefs: trailRefs ?? this.trailRefs,
      metrics: metrics ?? this.metrics,
      trailsResolved: trailsResolved ?? this.trailsResolved,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photos: photos ?? this.photos,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (snapToTrail.present) {
      map['snap_to_trail'] = Variable<bool>(snapToTrail.value);
    }
    if (waypoints.present) {
      map['waypoints'] = Variable<String>(waypoints.value);
    }
    if (routedPath.present) {
      map['routed_path'] = Variable<String>(routedPath.value);
    }
    if (trailRefs.present) {
      map['trail_refs'] = Variable<String>(trailRefs.value);
    }
    if (metrics.present) {
      map['metrics'] = Variable<String>(metrics.value);
    }
    if (trailsResolved.present) {
      map['trails_resolved'] = Variable<bool>(trailsResolved.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (photos.present) {
      map['photos'] = Variable<String>(photos.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('snapToTrail: $snapToTrail, ')
          ..write('waypoints: $waypoints, ')
          ..write('routedPath: $routedPath, ')
          ..write('trailRefs: $trailRefs, ')
          ..write('metrics: $metrics, ')
          ..write('trailsResolved: $trailsResolved, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('photos: $photos, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TrackRowsTable trackRows = $TrackRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [trackRows];
}

typedef $$TrackRowsTableCreateCompanionBuilder = TrackRowsCompanion Function({
  required String id,
  Value<String> name,
  required int color,
  Value<bool> snapToTrail,
  required String waypoints,
  Value<String> routedPath,
  Value<String> trailRefs,
  Value<String?> metrics,
  Value<bool> trailsResolved,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<String?> photos,
  Value<int> rowid,
});
typedef $$TrackRowsTableUpdateCompanionBuilder = TrackRowsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> color,
  Value<bool> snapToTrail,
  Value<String> waypoints,
  Value<String> routedPath,
  Value<String> trailRefs,
  Value<String?> metrics,
  Value<bool> trailsResolved,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String?> photos,
  Value<int> rowid,
});

class $$TrackRowsTableFilterComposer
    extends Composer<_$AppDatabase, $TrackRowsTable> {
  $$TrackRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get snapToTrail => $composableBuilder(
      column: $table.snapToTrail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get waypoints => $composableBuilder(
      column: $table.waypoints, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get routedPath => $composableBuilder(
      column: $table.routedPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get trailRefs => $composableBuilder(
      column: $table.trailRefs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metrics => $composableBuilder(
      column: $table.metrics, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get trailsResolved => $composableBuilder(
      column: $table.trailsResolved,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get photos => $composableBuilder(
      column: $table.photos, builder: (column) => ColumnFilters(column));
}

class $$TrackRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackRowsTable> {
  $$TrackRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get snapToTrail => $composableBuilder(
      column: $table.snapToTrail, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get waypoints => $composableBuilder(
      column: $table.waypoints, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get routedPath => $composableBuilder(
      column: $table.routedPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get trailRefs => $composableBuilder(
      column: $table.trailRefs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metrics => $composableBuilder(
      column: $table.metrics, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get trailsResolved => $composableBuilder(
      column: $table.trailsResolved,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get photos => $composableBuilder(
      column: $table.photos, builder: (column) => ColumnOrderings(column));
}

class $$TrackRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackRowsTable> {
  $$TrackRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get snapToTrail => $composableBuilder(
      column: $table.snapToTrail, builder: (column) => column);

  GeneratedColumn<String> get waypoints =>
      $composableBuilder(column: $table.waypoints, builder: (column) => column);

  GeneratedColumn<String> get routedPath => $composableBuilder(
      column: $table.routedPath, builder: (column) => column);

  GeneratedColumn<String> get trailRefs =>
      $composableBuilder(column: $table.trailRefs, builder: (column) => column);

  GeneratedColumn<String> get metrics =>
      $composableBuilder(column: $table.metrics, builder: (column) => column);

  GeneratedColumn<bool> get trailsResolved => $composableBuilder(
      column: $table.trailsResolved, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get photos =>
      $composableBuilder(column: $table.photos, builder: (column) => column);
}

class $$TrackRowsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TrackRowsTable,
    TrackRow,
    $$TrackRowsTableFilterComposer,
    $$TrackRowsTableOrderingComposer,
    $$TrackRowsTableAnnotationComposer,
    $$TrackRowsTableCreateCompanionBuilder,
    $$TrackRowsTableUpdateCompanionBuilder,
    (TrackRow, BaseReferences<_$AppDatabase, $TrackRowsTable, TrackRow>),
    TrackRow,
    PrefetchHooks Function()> {
  $$TrackRowsTableTableManager(_$AppDatabase db, $TrackRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> color = const Value.absent(),
            Value<bool> snapToTrail = const Value.absent(),
            Value<String> waypoints = const Value.absent(),
            Value<String> routedPath = const Value.absent(),
            Value<String> trailRefs = const Value.absent(),
            Value<String?> metrics = const Value.absent(),
            Value<bool> trailsResolved = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> photos = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TrackRowsCompanion(
            id: id,
            name: name,
            color: color,
            snapToTrail: snapToTrail,
            waypoints: waypoints,
            routedPath: routedPath,
            trailRefs: trailRefs,
            metrics: metrics,
            trailsResolved: trailsResolved,
            createdAt: createdAt,
            updatedAt: updatedAt,
            photos: photos,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String> name = const Value.absent(),
            required int color,
            Value<bool> snapToTrail = const Value.absent(),
            required String waypoints,
            Value<String> routedPath = const Value.absent(),
            Value<String> trailRefs = const Value.absent(),
            Value<String?> metrics = const Value.absent(),
            Value<bool> trailsResolved = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<String?> photos = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TrackRowsCompanion.insert(
            id: id,
            name: name,
            color: color,
            snapToTrail: snapToTrail,
            waypoints: waypoints,
            routedPath: routedPath,
            trailRefs: trailRefs,
            metrics: metrics,
            trailsResolved: trailsResolved,
            createdAt: createdAt,
            updatedAt: updatedAt,
            photos: photos,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TrackRowsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TrackRowsTable,
    TrackRow,
    $$TrackRowsTableFilterComposer,
    $$TrackRowsTableOrderingComposer,
    $$TrackRowsTableAnnotationComposer,
    $$TrackRowsTableCreateCompanionBuilder,
    $$TrackRowsTableUpdateCompanionBuilder,
    (TrackRow, BaseReferences<_$AppDatabase, $TrackRowsTable, TrackRow>),
    TrackRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TrackRowsTableTableManager get trackRows =>
      $$TrackRowsTableTableManager(_db, _db.trackRows);
}
