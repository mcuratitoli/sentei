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
  /// La geometria importata diventa il `routedPath` (snap disattivato: è già una
  /// traccia reale); i waypoint sono un sottocampione per consentire la modifica
  /// senza migliaia di marker.
  DrawnTrack importFromGpx(String xml, {required String id}) {
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

    return DrawnTrack(
      id: id,
      name: name.isNotEmpty ? name : 'Importato',
      snapToTrail: false,
      waypoints: _downsample(pts, 60),
      routedPath: pts,
    );
  }

  /// Sottocampiona [pts] ad al massimo [max] punti, estremi inclusi.
  static List<LatLng> _downsample(List<LatLng> pts, int max) {
    if (pts.length <= max) return pts;
    final step = (pts.length / max).ceil();
    final out = <LatLng>[];
    for (var i = 0; i < pts.length; i += step) {
      out.add(pts[i]);
    }
    if (out.last != pts.last) out.add(pts.last);
    return out;
  }
}
