import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/core/util/tile_math.dart';

void main() {
  group('TileMath.locate', () {
    test('centro mappa (0,0) a z0 => tile 0/0, pixel centrale', () {
      final t = TileMath.locate(const LatLng(0, 0), 0);
      expect(t.tileX, 0);
      expect(t.tileY, 0);
      expect(t.pixelX, 128);
      expect(t.pixelY, 128);
    });

    test('esempio noto OSM (Berlino) a z17', () {
      // Riferimento slippy map: lon=13.37771, lat=52.51628 -> x=70406, y=42987
      final t = TileMath.locate(const LatLng(52.51628, 13.37771), 17);
      expect(t.tileX, 70406);
      expect(t.tileY, 42987);
    });

    test('pixel sempre dentro [0, 255]', () {
      final t = TileMath.locate(const LatLng(45.9369, 7.8694), 13);
      expect(t.pixelX, inInclusiveRange(0, 255));
      expect(t.pixelY, inInclusiveRange(0, 255));
    });
  });
}
