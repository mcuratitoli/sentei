import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/domain/services/path_geometry.dart';

void main() {
  const calc = PathGeometry();
  const distance = Distance();

  group('totalDistance', () {
    test('ritorna 0 per 0 o 1 punto', () {
      expect(calc.totalDistance(const []), 0);
      expect(calc.totalDistance(const [LatLng(45, 7)]), 0);
    });

    test('somma cumulativa su più segmenti', () {
      final pts = [
        const LatLng(45.0, 7.0),
        const LatLng(45.01, 7.0),
        const LatLng(45.02, 7.0),
      ];
      final expected = distance(pts[0], pts[1]) + distance(pts[1], pts[2]);
      expect(calc.totalDistance(pts), closeTo(expected, 1e-6));
    });
  });

  group('distanceToPath', () {
    final path = [
      const LatLng(45.0, 7.0),
      const LatLng(45.0, 7.01),
    ];

    test('punto sul segmento => ~0', () {
      expect(calc.distanceToPath(const LatLng(45.0, 7.005), path),
          lessThan(1));
    });

    test('punto lontano dal segmento => distanza grande', () {
      // ~0.01° di latitudine ≈ 1.1 km a nord del segmento
      final d = calc.distanceToPath(const LatLng(45.01, 7.005), path);
      expect(d, greaterThan(900));
      expect(d, lessThan(1300));
    });

    test('percorso vuoto => infinito', () {
      expect(calc.distanceToPath(const LatLng(45, 7), const []),
          double.infinity);
    });
  });

  group('densify', () {
    test('preserva i vertici originali e infittisce', () {
      final pts = [const LatLng(45.0, 7.0), const LatLng(45.01, 7.0)];
      final dense = calc.densify(pts, stepMeters: 100);

      expect(dense.first, pts.first);
      expect(dense.last, pts.last);
      expect(dense.length, greaterThan(pts.length));
    });

    test('nessun passo supera (di molto) stepMeters', () {
      final pts = [const LatLng(45.0, 7.0), const LatLng(45.05, 7.05)];
      const step = 50.0;
      final dense = calc.densify(pts, stepMeters: step);
      for (var i = 0; i < dense.length - 1; i++) {
        expect(distance(dense[i], dense[i + 1]), lessThanOrEqualTo(step + 1));
      }
    });

    test('lista con meno di 2 punti torna invariata', () {
      expect(calc.densify(const [LatLng(45, 7)]).length, 1);
      expect(calc.densify(const []).length, 0);
    });
  });
}
