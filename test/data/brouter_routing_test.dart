import 'package:flutter_test/flutter_test.dart';
import 'package:sentei/data/routing/brouter_routing_service.dart';
import 'package:sentei/domain/services/routing_service.dart';

const _sample = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "track-length": "1234",
        "filtered ascend": "210"
      },
      "geometry": {
        "type": "LineString",
        "coordinates": [
          [7.8694, 45.9369, 2000.0],
          [7.8700, 45.9375, 2050.0],
          [7.8720, 45.9400, 2100.0]
        ]
      }
    }
  ]
}
''';

void main() {
  group('BRouter parseGeoJson', () {
    test('estrae geometria, quote e proprietà', () {
      final r = BRouterRoutingService.parseGeoJson(_sample);

      expect(r.geometry.length, 3);
      expect(r.geometry.first.latitude, 45.9369);
      expect(r.geometry.first.longitude, 7.8694);
      expect(r.elevations, [2000.0, 2050.0, 2100.0]);
      expect(r.lengthMeters, 1234);
      expect(r.ascentMeters, 210);
    });

    test('risposta senza features => RoutingException', () {
      expect(
        () => BRouterRoutingService.parseGeoJson('{"features": []}'),
        throwsA(isA<RoutingException>()),
      );
    });

    test('corpo non JSON => RoutingException', () {
      expect(
        () => BRouterRoutingService.parseGeoJson('operation killed'),
        throwsA(isA<RoutingException>()),
      );
    });
  });
}
