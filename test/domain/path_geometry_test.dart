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

  group('nearestOnPath', () {
    // Percorso rettilineo lungo la longitudine (verso est), ~3 segmenti uguali.
    final path = [
      const LatLng(45.0, 7.00),
      const LatLng(45.0, 7.01),
      const LatLng(45.0, 7.02),
      const LatLng(45.0, 7.03),
    ];
    final segLen = distance(path[0], path[1]);

    test('punto vicino al 2° vertice => distanceAlongPath ≈ 2 segmenti', () {
      final r = calc.nearestOnPath(const LatLng(45.0001, 7.02), path);
      expect(r.distanceToPath, lessThan(50));
      expect(r.distanceAlongPath, closeTo(2 * segLen, segLen * 0.05));
    });

    test('punto a metà del primo segmento => distanceAlongPath ≈ metà', () {
      final r = calc.nearestOnPath(const LatLng(45.0, 7.005), path);
      expect(r.distanceAlongPath, closeTo(segLen / 2, segLen * 0.05));
    });

    test('inizio del percorso => distanceAlongPath ≈ 0', () {
      final r = calc.nearestOnPath(const LatLng(45.0, 7.00), path);
      expect(r.distanceAlongPath, closeTo(0, 1));
    });

    test('un solo punto nel percorso => distanceAlongPath 0', () {
      final r = calc.nearestOnPath(const LatLng(45, 7), [path.first]);
      expect(r.distanceAlongPath, 0);
      expect(r.distanceToPath, 0);
    });

    test('percorso vuoto => infinito, distanceAlongPath 0', () {
      final r = calc.nearestOnPath(const LatLng(45, 7), const []);
      expect(r.distanceToPath, double.infinity);
      expect(r.distanceAlongPath, 0);
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

  group('pointAtFraction', () {
    test('a metà (0.5) di un percorso rettilineo coincide col punto medio', () {
      final path = [const LatLng(45.0, 7.0), const LatLng(45.02, 7.0)];
      final mid = calc.pointAtFraction(path, 0.5);
      expect(mid.latitude, closeTo(45.01, 1e-9));
      expect(mid.longitude, closeTo(7.0, 1e-9));
    });

    test('su un percorso tortuoso, il centro per lunghezza NON è la media degli estremi', () {
      // "L" molto asimmetrica: un lato lunghissimo, uno cortissimo — la media
      // degli estremi cadrebbe fuori dal percorso, pointAtFraction resta sopra.
      final path = [
        const LatLng(0, 0),
        const LatLng(0, 10), // lato lungo (~1113 km)
        const LatLng(0.01, 10), // lato corto (~1.1 km)
      ];
      final mid = calc.pointAtFraction(path, 0.5);
      // Il centro per lunghezza cade ancora sul primo, lunghissimo segmento.
      expect(mid.longitude, closeTo(5.0, 0.1));
      expect(mid.latitude, closeTo(0, 1e-6));
    });

    test('frazione 0 e 1 tornano gli estremi', () {
      final path = [const LatLng(45.0, 7.0), const LatLng(45.02, 7.03)];
      expect(calc.pointAtFraction(path, 0).latitude, closeTo(45.0, 1e-9));
      expect(calc.pointAtFraction(path, 1).latitude, closeTo(45.02, 1e-9));
    });

    test('un solo punto: ritorna quel punto per qualunque frazione', () {
      const p = LatLng(45.0, 7.0);
      expect(calc.pointAtFraction([p], 0.3), p);
    });
  });

  group('stitchSegments', () {
    test('segmenti già nello stesso verso: concatenati così come sono', () {
      final result = calc.stitchSegments([
        [const LatLng(0, 0), const LatLng(0, 1)],
        [const LatLng(0, 1), const LatLng(0, 2)],
      ]);
      expect(result, [
        const LatLng(0, 0),
        const LatLng(0, 1),
        const LatLng(0, 1),
        const LatLng(0, 2),
      ]);
    });

    test(
        'un segmento invertito rispetto al precedente viene raddrizzato '
        '(bug osservato dal vivo: rami a linea retta inesistenti sul segnavia 251)',
        () {
      // Il secondo segmento è dato "al contrario": il suo ULTIMO punto è
      // quello che in realtà continua dal primo segmento, non il primo.
      final result = calc.stitchSegments([
        [const LatLng(0, 0), const LatLng(0, 1)],
        [const LatLng(0, 2), const LatLng(0, 1)], // invertito
      ]);
      expect(result, [
        const LatLng(0, 0),
        const LatLng(0, 1),
        const LatLng(0, 1), // raddrizzato: parte da qui...
        const LatLng(0, 2), // ...non da (0,2) come nell'ordine originale
      ]);
    });

    test('catena di più segmenti con inversioni alternate', () {
      final result = calc.stitchSegments([
        [const LatLng(0, 0), const LatLng(0, 1)],
        [const LatLng(0, 2), const LatLng(0, 1)], // invertito
        [const LatLng(0, 2), const LatLng(0, 3)], // dritto
      ]);
      expect(result.first, const LatLng(0, 0));
      expect(result.last, const LatLng(0, 3));
      // Nessun salto: ogni punto consecutivo è vicino al precedente (non un
      // balzo da un capo sbagliato all'altro).
      const distance = Distance();
      for (var i = 0; i < result.length - 1; i++) {
        expect(distance(result[i], result[i + 1]), lessThan(150000));
      }
    });

    test('segmenti vuoti vengono ignorati', () {
      final result = calc.stitchSegments([
        [const LatLng(0, 0), const LatLng(0, 1)],
        const [],
        [const LatLng(0, 1), const LatLng(0, 2)],
      ]);
      expect(result, [
        const LatLng(0, 0),
        const LatLng(0, 1),
        const LatLng(0, 1),
        const LatLng(0, 2),
      ]);
    });

    test('nessun segmento: lista vuota', () {
      expect(calc.stitchSegments(const []), isEmpty);
      expect(calc.stitchSegments(const [[]]), isEmpty);
    });

    test('un solo segmento: ritornato invariato', () {
      final seg = [const LatLng(0, 0), const LatLng(0, 1)];
      expect(calc.stitchSegments([seg]), seg);
    });
  });
}
