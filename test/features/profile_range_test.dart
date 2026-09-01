import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentei/features/draw_route/route_editor_provider.dart';

/// Selezione del "tratto scelto" sul profilo altimetrico (§P1.C2): due maniglie
/// trascinabili con estremi di default a inizio/fine e che non si scavalcano.
void main() {
  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        activeTrackIdProvider.overrideWithValue(null),
      ]);

  group('ProfileRangeSel', () {
    test('lo/hi ordinano gli estremi', () {
      expect(const ProfileRangeSel(a: 3, b: 9).lo, 3);
      expect(const ProfileRangeSel(a: 3, b: 9).hi, 9);
      expect(const ProfileRangeSel(a: 9, b: 3).lo, 3);
      expect(const ProfileRangeSel(a: 9, b: 3).hi, 9);
    });
  });

  group('ProfileRange', () {
    test('beginFull mette gli estremi a 0 e ultimo indice', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      c.read(profileRangeProvider.notifier).beginFull(120);
      final s = c.read(profileRangeProvider)!;
      expect(s.a, 0);
      expect(s.b, 120);
    });

    test('beginFull ignora tracce degeneri (lastIndex <= 0)', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      c.read(profileRangeProvider.notifier).beginFull(0);
      expect(c.read(profileRangeProvider), isNull);
    });

    test('moveHandle: le maniglie non si scavalcano', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final n = c.read(profileRangeProvider.notifier);
      n.beginFull(100);
      n.moveHandle(0, 80, 100);
      expect(c.read(profileRangeProvider)!.a, 80);
      n.moveHandle(1, 50, 100); // b tirata sotto a=80 → clampata a 80
      expect(c.read(profileRangeProvider)!.b, 80);
      n.moveHandle(0, 200, 100); // a oltre b=80 → clampata a 80
      expect(c.read(profileRangeProvider)!.a, 80);
    });

    test('moveHandle: clamp a [0, lastIndex]', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final n = c.read(profileRangeProvider.notifier);
      n.beginFull(100);
      n.moveHandle(0, -10, 100);
      expect(c.read(profileRangeProvider)!.a, 0);
      n.moveHandle(1, 999, 100);
      expect(c.read(profileRangeProvider)!.b, 100);
    });

    test('moveHandle su stato nullo è un no-op', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      c.read(profileRangeProvider.notifier).moveHandle(0, 10, 100);
      expect(c.read(profileRangeProvider), isNull);
    });
  });
}
