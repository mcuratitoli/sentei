import 'package:flutter_test/flutter_test.dart';
import 'package:sentei/data/cloud/cloud_sync_engine.dart';
import 'package:sentei/data/cloud/cloud_sync_service.dart';

RemoteTrackMeta _r(String id, DateTime ts) =>
    RemoteTrackMeta(id: id, updatedAt: ts);

void main() {
  final t1 = DateTime.utc(2026, 6, 1);
  final t2 = DateTime.utc(2026, 6, 10);

  test('traccia solo locale → upload', () {
    final plan = computeSyncPlan(
      localUpdatedAt: {'a': t1},
      remote: const [],
    );
    expect(plan.toUpload, ['a']);
    expect(plan.toDownload, isEmpty);
  });

  test('traccia solo remota → download', () {
    final plan = computeSyncPlan(
      localUpdatedAt: const {},
      remote: [_r('b', t1)],
    );
    expect(plan.toUpload, isEmpty);
    expect(plan.toDownload.single.id, 'b');
  });

  test('locale più recente → upload', () {
    final plan = computeSyncPlan(
      localUpdatedAt: {'a': t2},
      remote: [_r('a', t1)],
    );
    expect(plan.toUpload, ['a']);
    expect(plan.toDownload, isEmpty);
  });

  test('remoto più recente → download', () {
    final plan = computeSyncPlan(
      localUpdatedAt: {'a': t1},
      remote: [_r('a', t2)],
    );
    expect(plan.toDownload.single.id, 'a');
    expect(plan.toUpload, isEmpty);
  });

  test('stesso timestamp → allineate, nessuna azione', () {
    final plan = computeSyncPlan(
      localUpdatedAt: {'a': t1},
      remote: [_r('a', t1)],
    );
    expect(plan.isEmpty, isTrue);
    expect(plan.upToDate, 1);
  });

  test('scenario misto', () {
    final plan = computeSyncPlan(
      localUpdatedAt: {'a': t2, 'b': t1, 'c': t1, 'soloLocale': t1},
      remote: [
        _r('a', t1), // locale più recente → upload
        _r('b', t2), // remoto più recente → download
        _r('c', t1), // pari → up to date
        _r('soloRemota', t2), // solo remota → download
      ],
    );
    expect(plan.toUpload..sort(), ['a', 'soloLocale']);
    expect(plan.toDownload.map((r) => r.id).toList()..sort(),
        ['b', 'soloRemota']);
    expect(plan.upToDate, 1);
  });
}
