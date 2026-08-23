import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/domain/services/track_runs.dart';

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
}
