import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/offline/terrarium_tile_cache.dart';
import '../../ui/ios_progress.dart';
import '../../ui/ios_toast.dart';
import '../draw_route/route_editor_provider.dart';
import 'offline_maps_providers.dart';

/// Scarica offline (mappa + elevazione) l'area attorno al bounding box della
/// traccia [t] (+~500 m), con un dialog di progresso. Riusabile da lista
/// tracciati e card di dettaglio.
Future<void> downloadTrackOffline(
  BuildContext context,
  WidgetRef ref,
  DrawnTrack t,
) async {
  final pts = t.routedPath.length >= 2 ? t.routedPath : t.waypoints;
  if (pts.length < 2) {
    showIosToast(context, 'Traccia senza percorso');
    return;
  }
  var minLa = 90.0, maxLa = -90.0, minLo = 180.0, maxLo = -180.0;
  for (final p in pts) {
    minLa = p.latitude < minLa ? p.latitude : minLa;
    maxLa = p.latitude > maxLa ? p.latitude : maxLa;
    minLo = p.longitude < minLo ? p.longitude : minLo;
    maxLo = p.longitude > maxLo ? p.longitude : maxLo;
  }
  const m = 0.005; // ~500 m di margine
  final s = minLa - m, n = maxLa + m, w = minLo - m, e = maxLo + m;

  final phase = ValueNotifier<String>('Avvio…');
  final closeProgress =
      showIosProgress(context, title: 'Salvataggio offline', message: phase);
  try {
    await ref.read(offlineMapsServiceProvider).downloadArea(
          id: 'track-${t.id}',
          name: t.name.isNotEmpty ? t.name : 'Traccia',
          south: s,
          west: w,
          north: n,
          east: e,
          maxZoom: 15,
          onProgress: (p) => phase.value = 'Mappa ${(p * 100).round()}%',
        );
    await downloadTerrariumArea(
      cache: ref.read(terrariumCacheProvider),
      south: s,
      west: w,
      north: n,
      east: e,
      onProgress: (p) => phase.value = 'Elevazione ${(p * 100).round()}%',
    );
    ref.invalidate(downloadedRegionsProvider);
    closeProgress();
    if (context.mounted) {
      showIosToast(context, '"${t.name}" salvata offline');
    }
  } catch (err) {
    closeProgress();
    if (context.mounted) {
      showIosToast(context, 'Salvataggio offline fallito: $err');
    }
  } finally {
    phase.dispose();
  }
}
