import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/domain/services/polyline_simplify.dart';

void main() {
  const s = PolylineSimplifier();

  test('Douglas-Peucker scarta i punti collineari e tiene le svolte', () {
    // 0,1,2 su una retta N (lon costante); 3 svolta a E. La svolta è a idx 2.
    final pts = [
      const LatLng(45.000, 7.0),
      const LatLng(45.001, 7.0), // collineare → da scartare
      const LatLng(45.002, 7.0), // vertice della svolta → da tenere
      const LatLng(45.002, 7.002),
    ];
    final idx = s.douglasPeuckerIndices(pts, 5); // tolleranza 5 m
    expect(idx, [0, 2, 3]);
  });

  test('simplifyIndices rispetta il cap aumentando la tolleranza', () {
    // Zig-zag di 200 punti.
    final pts = [
      for (var i = 0; i < 200; i++)
        LatLng(45.0 + i * 0.0005, 7.0 + (i.isEven ? 0.0 : 0.0008)),
    ];
    final idx = s.simplifyIndices(pts, tolerance: 1, maxPoints: 20);
    expect(idx.length, lessThanOrEqualTo(20));
    expect(idx.first, 0);
    expect(idx.last, pts.length - 1);
  });

  test('tracce corte restano invariate', () {
    final pts = [const LatLng(45, 7), const LatLng(45.01, 7.01)];
    expect(s.simplifyIndices(pts), [0, 1]);
  });
}
