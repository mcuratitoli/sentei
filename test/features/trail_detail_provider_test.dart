import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/data/trails/trail_service.dart';
import 'package:sentei/domain/models/elevation_profile.dart' show TrailSegment;
import 'package:sentei/features/draw_route/route_editor_provider.dart'
    show trailServiceProvider;
import 'package:sentei/features/map_gl/trail_detail_provider.dart';

/// Fake controllabile: [nearby] cosa risponde `trailsNear`, [detail] cosa
/// risponde `fetchDetail` una volta risolta la relazione.
class _FakeTrailService implements TrailService {
  _FakeTrailService({this.nearby = const [], this.detail});
  final List<TrailRelation> nearby;
  final TrailDetail? detail;

  @override
  Future<List<TrailRelation>> fetchRelations(List<LatLng> path,
          {double? radiusMeters}) async =>
      const [];

  @override
  Future<TrailDetail?> fetchDetail(TrailRelation relation) async => detail;

  @override
  Future<List<TrailSegment>> trailSegmentsAlong(List<LatLng> path) async => const [];

  @override
  Future<List<TrailRelation>> trailsNear(LatLng point,
          {double thresholdMeters = 60}) async =>
      nearby;
}

void main() {
  test('openByRef: risolve il ref vicino e completa il fetch', () async {
    final container = ProviderContainer(overrides: [
      trailServiceProvider.overrideWithValue(_FakeTrailService(
        nearby: [
          TrailRelation('999', const [], TrailSource.overpass, id: 'x'),
          TrailRelation('203', const [], TrailSource.overpass, id: '42'),
        ],
        detail: const TrailDetail(ref: '203', points: [], name: 'Sentiero test'),
      )),
    ]);
    addTearDown(container.dispose);

    await container
        .read(trailDetailProvider.notifier)
        .openByRef('203', const LatLng(45.9, 7.9));

    final state = container.read(trailDetailProvider);
    expect(state?.stage, TrailDetailStage.ready);
    expect(state?.detail?.name, 'Sentiero test');
    // La relazione risolta ha guadagnato id/fonte, non è più il placeholder.
    expect(state?.relation.id, '42');
  });

  test('openByRef: nessun ref corrispondente nelle vicinanze → errore', () async {
    final container = ProviderContainer(overrides: [
      trailServiceProvider.overrideWithValue(_FakeTrailService(
        nearby: [TrailRelation('999', const [], TrailSource.overpass, id: 'x')],
      )),
    ]);
    addTearDown(container.dispose);

    await container
        .read(trailDetailProvider.notifier)
        .openByRef('203', const LatLng(45.9, 7.9));

    final state = container.read(trailDetailProvider);
    expect(state?.stage, TrailDetailStage.error);
  });

  test('openByRef: trailsNear vuoto (nessun sentiero vicino) → errore, nessuna eccezione',
      () async {
    final container = ProviderContainer(overrides: [
      trailServiceProvider.overrideWithValue(_FakeTrailService(nearby: const [])),
    ]);
    addTearDown(container.dispose);

    await container
        .read(trailDetailProvider.notifier)
        .openByRef('203', const LatLng(45.9, 7.9));

    expect(container.read(trailDetailProvider)?.stage, TrailDetailStage.error);
  });

  test('clear() azzera lo stato', () async {
    final container = ProviderContainer(overrides: [
      trailServiceProvider.overrideWithValue(_FakeTrailService(
        detail: const TrailDetail(ref: '203', points: []),
      )),
    ]);
    addTearDown(container.dispose);

    await container
        .read(trailDetailProvider.notifier)
        .open(TrailRelation('203', const [], TrailSource.overpass, id: '42'));
    expect(container.read(trailDetailProvider), isNotNull);

    container.read(trailDetailProvider.notifier).clear();
    expect(container.read(trailDetailProvider), isNull);
  });
}
