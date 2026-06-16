import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:sentei/data/offline/terrarium_elevation_service.dart';

/// Crea una tile PNG 256x256 monocroma con i canali dati.
Uint8List _solidTile(int r, int g, int b) {
  final image = img.Image(width: 256, height: 256);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return img.encodePng(image);
}

void main() {
  group('TerrariumElevationService', () {
    test('decodifica la quota dal pixel della tile (~2000 m)', () async {
      // (135,208,0) -> (135*256 + 208) - 32768 = 2000
      final tile = _solidTile(135, 208, 0);
      final service = TerrariumElevationService(
        fetchTile: (z, x, y) async => tile,
      );

      final ele = await service.elevationAt(const LatLng(45.9369, 7.8694));
      expect(ele, closeTo(2000, 1e-6));
    });

    test('ritorna null se la tile non è disponibile', () async {
      final service = TerrariumElevationService(
        fetchTile: (z, x, y) async => null,
      );
      expect(await service.elevationAt(const LatLng(45, 7)), isNull);
    });

    test('usa la cache: punti nella stessa tile => un solo fetch', () async {
      var fetches = 0;
      final tile = _solidTile(128, 0, 0); // 0 m
      final service = TerrariumElevationService(
        fetchTile: (z, x, y) async {
          fetches++;
          return tile;
        },
      );

      // Due punti vicinissimi: stessa tile a z13.
      await service.elevationAt(const LatLng(45.9369, 7.8694));
      await service.elevationAt(const LatLng(45.9370, 7.8695));
      expect(fetches, 1);
    });
  });
}
