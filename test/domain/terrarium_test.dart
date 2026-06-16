import 'package:flutter_test/flutter_test.dart';
import 'package:sentei/data/offline/terrarium.dart';

void main() {
  group('Terrarium.decodeElevation', () {
    test('livello del mare: R=128,G=0,B=0 => 0 m', () {
      expect(Terrarium.decodeElevation(128, 0, 0), 0);
    });

    test('valore minimo: 0,0,0 => -32768 m', () {
      expect(Terrarium.decodeElevation(0, 0, 0), -32768);
    });

    test('frazione di metro dal canale blu', () {
      // (0*256 + 0 + 128/256) - 32768 = 0.5 - 32768
      expect(Terrarium.decodeElevation(0, 0, 128), closeTo(-32767.5, 1e-9));
    });

    test('esempio quota positiva ~2000 m', () {
      // 2000 + 32768 = 34768 = 135*256 + 208  -> R=135, G=208
      expect(Terrarium.decodeElevation(135, 208, 0), closeTo(2000, 1e-9));
    });
  });
}
