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

  test('round-trip export → parseTrack preserva nome e geometria', () {
    const track = DrawnTrack(
      id: 't1',
      name: 'Anello',
      waypoints: [LatLng(45.0, 7.0), LatLng(45.02, 7.02)],
      routedPath: [LatLng(45.0, 7.0), LatLng(45.01, 7.01), LatLng(45.02, 7.02)],
    );
    final xml = service.exportToGpx(track);
    final parsed = service.parseTrack(xml);

    expect(parsed.name, 'Anello');
    expect(parsed.path.length, 3);
    expect(parsed.path.first.latitude, closeTo(45.0, 1e-6));
    expect(parsed.path.last.longitude, closeTo(7.02, 1e-6));
  });

  test('GPX senza traccia => FormatException', () {
    expect(
      () => service.parseTrack('<gpx></gpx>'),
      throwsA(isA<FormatException>()),
    );
  });
}
