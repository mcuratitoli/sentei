import 'package:latlong2/latlong.dart';

/// Costanti globali dell'app.
abstract final class AppConstants {
  static const String appDisplayName = 'Sentèi';
  static const String bundleId = 'com.mattiacuratitoli.sentei';

  /// Centro di default all'avvio: Alpi del Nord Italia (zona Monte Rosa).
  static const LatLng defaultCenter = LatLng(45.9369, 7.8694);
  static const double defaultZoom = 11;
  static const double minZoom = 5;
  static const double maxZoom = 18;
}
