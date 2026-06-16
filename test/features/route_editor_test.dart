import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/features/draw_route/route_editor_provider.dart';

void main() {
  late ProviderContainer container;
  RouteEditor editor() => container.read(routeEditorProvider.notifier);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('addPoint / undo / clear', () {
    editor().addPoint(const LatLng(45, 7));
    editor().addPoint(const LatLng(45.01, 7));
    expect(container.read(routeEditorProvider).waypoints.length, 2);

    editor().undo();
    expect(container.read(routeEditorProvider).waypoints.length, 1);

    editor().clear();
    expect(container.read(routeEditorProvider).waypoints, isEmpty);
  });

  test('movePoint aggiorna la coordinata', () {
    editor().addPoint(const LatLng(45, 7));
    editor().movePoint(0, const LatLng(46, 8));
    expect(
        container.read(routeEditorProvider).waypoints.first, const LatLng(46, 8));
  });

  test('removePoint elimina per indice', () {
    editor()
      ..addPoint(const LatLng(45, 7))
      ..addPoint(const LatLng(45.01, 7))
      ..addPoint(const LatLng(45.02, 7));
    editor().removePoint(1);
    final pts = container.read(routeEditorProvider).waypoints;
    expect(pts.length, 2);
    expect(pts[1], const LatLng(45.02, 7));
  });

  test('toggleSnap inverte lo snap-to-trail', () {
    expect(container.read(routeEditorProvider).snapToTrail, isTrue);
    editor().toggleSnap();
    expect(container.read(routeEditorProvider).snapToTrail, isFalse);
  });

  test('canCompute richiede almeno 2 punti', () {
    editor().addPoint(const LatLng(45, 7));
    expect(container.read(routeEditorProvider).canCompute, isFalse);
    editor().addPoint(const LatLng(45.01, 7));
    expect(container.read(routeEditorProvider).canCompute, isTrue);
  });
}
