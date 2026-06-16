import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/data/gpx/gpx_service.dart';
import 'package:sentei/features/draw_route/route_editor_provider.dart';

void main() {
  const service = GpxService();

  test('export genera GPX con nome e punti', () {
    const track = DrawnTrack(
      id: 't1',
      name: 'Giro',
      waypoints: [LatLng(45.0, 7.0), LatLng(45.01, 7.01)],
      routedPath: [LatLng(45.0, 7.0), LatLng(45.005, 7.005), LatLng(45.01, 7.01)],
    );
    final xml = service.exportToGpx(track);
    expect(xml, contains('<trk>'));
    expect(xml, contains('Giro'));
    expect(xml, contains('lat="45.0"'));
  });

  test('round-trip export → import preserva nome e geometria', () {
    const track = DrawnTrack(
      id: 't1',
      name: 'Anello',
      waypoints: [LatLng(45.0, 7.0), LatLng(45.02, 7.02)],
      routedPath: [LatLng(45.0, 7.0), LatLng(45.01, 7.01), LatLng(45.02, 7.02)],
    );
    final xml = service.exportToGpx(track);
    final imported = service.importFromGpx(xml, id: 't2');

    expect(imported.name, 'Anello');
    expect(imported.snapToTrail, isFalse);
    expect(imported.routedPath.length, 3);
    expect(imported.routedPath.first.latitude, closeTo(45.0, 1e-6));
    expect(imported.routedPath.last.longitude, closeTo(7.02, 1e-6));
  });

  test('GPX senza traccia => FormatException', () {
    expect(
      () => service.importFromGpx('<gpx></gpx>', id: 'x'),
      throwsA(isA<FormatException>()),
    );
  });
}
