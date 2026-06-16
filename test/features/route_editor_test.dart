import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/features/draw_route/route_editor_provider.dart';

void main() {
  late ProviderContainer container;
  Tracks notifier() => container.read(tracksProvider.notifier);
  TracksState state() => container.read(tracksProvider);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('startNewDrawing crea una traccia in modifica', () {
    notifier().startNewDrawing();
    expect(state().tracks.length, 1);
    expect(state().drawing, isTrue);
    expect(state().editing, isNotNull);
  });

  test('addPoint / undo agiscono sulla traccia in modifica', () {
    notifier()
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7))
      ..addPoint(const LatLng(45.01, 7));
    expect(state().editing!.waypoints.length, 2);

    notifier().undo();
    expect(state().editing!.waypoints.length, 1);
  });

  test('finishDrawing scarta tracce con meno di 2 punti', () {
    notifier()
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7))
      ..finishDrawing();
    expect(state().tracks, isEmpty);
    expect(state().drawing, isFalse);
  });

  test('finishDrawing mantiene tracce valide e deseleziona', () {
    notifier()
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7))
      ..addPoint(const LatLng(45.01, 7))
      ..finishDrawing();
    expect(state().tracks.length, 1);
    expect(state().showCard, isFalse);
  });

  test('più tracce coesistono; select/deselect/editSelected', () {
    notifier()
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7))
      ..addPoint(const LatLng(45.01, 7))
      ..finishDrawing();
    final firstId = state().tracks.first.id;

    notifier()
      ..startNewDrawing()
      ..addPoint(const LatLng(46, 8))
      ..addPoint(const LatLng(46.01, 8))
      ..finishDrawing();
    expect(state().tracks.length, 2);

    notifier().select(firstId);
    expect(state().selectedId, firstId);
    expect(state().activeId, firstId);

    notifier().editSelected();
    expect(state().editingId, firstId);
    expect(state().selectedId, isNull);

    notifier().deselect();
    expect(state().showCard, isFalse);
  });

  test('setName / setColor / toggleSnap sulla traccia in modifica', () {
    notifier()
      ..startNewDrawing()
      ..setName('Giro del lago')
      ..setColor(kTrackPalette[2]);
    expect(state().editing!.name, 'Giro del lago');
    expect(state().editing!.color, kTrackPalette[2]);

    final snap = state().editing!.snapToTrail;
    notifier().toggleSnap();
    expect(state().editing!.snapToTrail, !snap);
  });

  test('remove elimina la traccia attiva', () {
    notifier()
      ..startNewDrawing()
      ..addPoint(const LatLng(45, 7))
      ..addPoint(const LatLng(45.01, 7))
      ..finishDrawing();
    final id = state().tracks.first.id;
    notifier().select(id);
    notifier().remove();
    expect(state().tracks, isEmpty);
    expect(state().showCard, isFalse);
  });
}
