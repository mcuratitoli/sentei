import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/domain/models/elevation_profile.dart';
import 'package:sentei/domain/services/track_runs.dart';

/// Percorso lungo un meridiano: [n] punti a ~111 m l'uno dall'altro
/// (0.001° di latitudine all'equatore).
List<LatLng> _meridianPath(int n) =>
    [for (var i = 0; i < n; i++) LatLng(i * 0.001, 0)];

void main() {
  group('sliceTrackRuns', () {
    test('nessun dato di run: un unico tratto pieno', () {
      final path = [
        const LatLng(45.0, 7.0),
        const LatLng(45.01, 7.0),
        const LatLng(45.02, 7.0),
      ];
      final runs = sliceTrackRuns(
          routedPath: path, segmentPointCounts: const [], freeSegments: const {});
      expect(runs.length, 1);
      expect(runs.single.free, false);
      expect(runs.single.points, path);
    });

    test('due segmenti, nessuno libero: un unico run pieno (fusi)', () {
      // Segmento 0: wp0→p1 (1 punto extra). Segmento 1: p1→p2 (1 punto extra).
      final path = [
        const LatLng(45.0, 7.0),
        const LatLng(45.01, 7.0),
        const LatLng(45.02, 7.0),
      ];
      final runs = sliceTrackRuns(
          routedPath: path,
          segmentPointCounts: const [1, 1],
          freeSegments: const {});
      expect(runs.length, 1);
      expect(runs.single.free, false);
      expect(runs.single.points, path);
    });

    test('segmento centrale libero: tre run alternati', () {
      // 4 waypoint, ciascun segmento contribuisce esattamente 1 punto extra
      // (nessuna densificazione, per semplicità del test).
      final path = [
        const LatLng(0, 0),
        const LatLng(0, 1),
        const LatLng(0, 2),
        const LatLng(0, 3),
      ];
      final runs = sliceTrackRuns(
        routedPath: path,
        segmentPointCounts: const [1, 1, 1],
        freeSegments: const {1},
      );
      expect(runs.length, 3);
      expect(runs[0].free, false);
      expect(runs[0].points, [const LatLng(0, 0), const LatLng(0, 1)]);
      expect(runs[1].free, true);
      expect(runs[1].points, [const LatLng(0, 1), const LatLng(0, 2)]);
      expect(runs[2].free, false);
      expect(runs[2].points, [const LatLng(0, 2), const LatLng(0, 3)]);
    });

    test('due segmenti liberi consecutivi si fondono in un solo run', () {
      final path = [
        const LatLng(0, 0),
        const LatLng(0, 1),
        const LatLng(0, 2),
        const LatLng(0, 3),
      ];
      final runs = sliceTrackRuns(
        routedPath: path,
        segmentPointCounts: const [1, 1, 1],
        freeSegments: const {0, 1},
      );
      expect(runs.length, 2);
      expect(runs[0].free, true);
      expect(runs[0].points, [
        const LatLng(0, 0),
        const LatLng(0, 1),
        const LatLng(0, 2),
      ]);
      expect(runs[1].free, false);
    });

    test('segmento con più punti densificati (BRouter) viene ritagliato correttamente', () {
      final path = [
        const LatLng(0, 0), // wp0
        const LatLng(0, 0.3), // intermedio segmento 0
        const LatLng(0, 0.6), // intermedio segmento 0
        const LatLng(0, 1), // wp1
        const LatLng(0, 2), // wp2 (segmento 1: libero, retta, nessun intermedio)
      ];
      final runs = sliceTrackRuns(
        routedPath: path,
        segmentPointCounts: const [3, 1], // segmento 0: 3 punti extra, segmento 1: 1
        freeSegments: const {1},
      );
      expect(runs.length, 2);
      expect(runs[0].free, false);
      expect(runs[0].points.length, 4); // wp0 + 3 intermedi/wp1
      expect(runs[1].free, true);
      expect(runs[1].points, [const LatLng(0, 1), const LatLng(0, 2)]);
    });

    test('conteggi disallineati dal percorso: fallback a un unico tratto pieno', () {
      final path = [
        const LatLng(0, 0),
        const LatLng(0, 1),
        const LatLng(0, 2),
      ];
      final runs = sliceTrackRuns(
        routedPath: path,
        segmentPointCounts: const [1, 5], // somma 6, ma routedPath ha solo 2 tratti
        freeSegments: const {},
      );
      expect(runs.length, 1);
      expect(runs.single.free, false);
      expect(runs.single.points, path);
    });
  });

  group('sliceStyledRuns (stile-linea per grado CAI, §P1.B)', () {
    test('nessun trailSegment: come sliceTrackRuns, caiScale sempre null', () {
      final path = _meridianPath(4);
      final runs = sliceStyledRuns(
        routedPath: path,
        segmentPointCounts: const [1, 1, 1],
        freeSegments: const {1},
        trailSegments: const [],
      );
      expect(runs.length, 3);
      expect(runs.map((r) => r.free).toList(), [false, true, false]);
      expect(runs.every((r) => r.caiScale == null), isTrue);
    });

    test('un solo grado su tutto: un run unico con quel grado', () {
      final path = _meridianPath(5);
      final runs = sliceStyledRuns(
        routedPath: path,
        segmentPointCounts: const [4],
        freeSegments: const {},
        trailSegments: const [
          TrailSegment(fromMeters: 0, toMeters: 100000, ref: '1', caiScale: 'E'),
        ],
      );
      expect(runs.length, 1);
      expect(runs.single.caiScale, 'E');
      expect(runs.single.points.length, 5);
    });

    test('due gradi con confine: due run in ordine, punti coprono tutto', () {
      final path = _meridianPath(5); // distanze ~ 0,111,222,333,444 m
      final runs = sliceStyledRuns(
        routedPath: path,
        segmentPointCounts: const [4],
        freeSegments: const {},
        trailSegments: const [
          TrailSegment(fromMeters: 0, toMeters: 250, ref: '1', caiScale: 'T'),
          TrailSegment(
              fromMeters: 250, toMeters: 100000, ref: '1', caiScale: 'EE'),
        ],
      );
      expect(runs.map((r) => r.caiScale).toList(), ['T', 'EE']);
      // giunzione condivisa: la somma dei punti è lunghezza+1
      expect(runs.fold<int>(0, (a, r) => a + r.points.length),
          path.length + 1);
      expect(runs.first.points.first, path.first);
      expect(runs.last.points.last, path.last);
    });

    test('tratto senza copertura CAI → caiScale null (linea piena)', () {
      final path = _meridianPath(5);
      final runs = sliceStyledRuns(
        routedPath: path,
        segmentPointCounts: const [4],
        freeSegments: const {},
        trailSegments: const [
          // copre solo i primi ~200 m, il resto resta scoperto
          TrailSegment(fromMeters: 0, toMeters: 200, ref: '1', caiScale: 'E'),
        ],
      );
      expect(runs.map((r) => r.caiScale).toList(), ['E', null]);
    });

    test('grado non normalizzato in ingresso viene normalizzato', () {
      final path = _meridianPath(4);
      final runs = sliceStyledRuns(
        routedPath: path,
        segmentPointCounts: const [3],
        freeSegments: const {},
        trailSegments: const [
          TrailSegment(
              fromMeters: 0, toMeters: 100000, ref: '1', caiScale: ' ee '),
        ],
      );
      expect(runs.single.caiScale, 'EE');
    });

    test('tratto libero: un solo run, caiScale null anche se un grado overlappa',
        () {
      final path = _meridianPath(4);
      final runs = sliceStyledRuns(
        routedPath: path,
        segmentPointCounts: const [1, 1, 1],
        freeSegments: const {1},
        trailSegments: const [
          TrailSegment(fromMeters: 0, toMeters: 100000, ref: '1', caiScale: 'E'),
        ],
      );
      expect(runs.map((r) => r.free).toList(), [false, true, false]);
      expect(runs[1].caiScale, isNull);
      expect(runs[0].caiScale, 'E');
      expect(runs[2].caiScale, 'E');
    });
  });
}
