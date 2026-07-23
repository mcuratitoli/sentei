import 'package:gpx/gpx.dart';
import 'package:latlong2/latlong.dart';

import '../../features/draw_route/route_editor_provider.dart';

/// Export/import di tracce in formato **GPX** (§6.4).
class GpxService {
  const GpxService();

  /// Genera il GPX di una traccia: un `<trk>` con la geometria che segue i
  /// sentieri (e la quota, se calcolata).
  String exportToGpx(DrawnTrack track) {
    final List<Wpt> points;
    final samples = track.metrics?.profile.samples ?? const [];
    if (samples.isNotEmpty) {
      points = [
        for (final s in samples)
          Wpt(lat: s.position.latitude, lon: s.position.longitude, ele: s.elevation),
      ];
    } else {
      final geo = track.routedPath.isNotEmpty ? track.routedPath : track.waypoints;
      points = [for (final p in geo) Wpt(lat: p.latitude, lon: p.longitude)];
    }

    final gpx = Gpx()
      ..creator = 'Sentèi'
      ..trks = [
        Trk(
          name: track.name.isNotEmpty ? track.name : 'Senza nome',
          trksegs: [Trkseg(trkpts: points)],
        ),
      ];
    return GpxWriter().asString(gpx, pretty: true);
  }

  /// Importa la prima traccia (o rotta) da un GPX. Lancia [FormatException] se
  /// non contiene una traccia valida.
  ///
  /// Parsa un GPX in **nome + polilinea grezza** (tutti i trackpoint; in
  /// mancanza di `<trk>`, i routepoint `<rte>`). La trasformazione in traccia
  /// Sentèi (semplificazione + instradamento ibrido) avviene poi nell'import
  /// (`Tracks.importGpx`). Lancia [FormatException] se non c'è una traccia valida.
  ({String name, List<LatLng> path}) parseTrack(String xml) {
    final gpx = GpxReader().fromString(xml);

    var name = '';
    final pts = <LatLng>[];
    for (final trk in gpx.trks) {
      name = trk.name ?? name;
      for (final seg in trk.trksegs) {
        for (final p in seg.trkpts) {
          if (p.lat != null && p.lon != null) pts.add(LatLng(p.lat!, p.lon!));
        }
      }
    }
    if (pts.isEmpty) {
      for (final rte in gpx.rtes) {
        name = rte.name ?? name;
        for (final p in rte.rtepts) {
          if (p.lat != null && p.lon != null) pts.add(LatLng(p.lat!, p.lon!));
        }
      }
    }
    if (pts.length < 2) {
      throw const FormatException('GPX senza una traccia valida');
    }
    return (name: name, path: pts);
  }
}
