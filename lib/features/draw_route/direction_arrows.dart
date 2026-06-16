import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'route_editor_provider.dart';

/// Frecce discrete lungo la traccia che indicano il senso di marcia.
///
/// Vengono posizionate a intervalli di [intervalMeters] lungo il percorso
/// instradato, orientate secondo la direzione locale.
class DirectionArrows extends ConsumerWidget {
  const DirectionArrows({super.key, this.intervalMeters = 350});

  final double intervalMeters;

  static const _distance = Distance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(routedPathProvider).value ?? const <LatLng>[];
    if (path.length < 2) return const SizedBox.shrink();

    final color = Theme.of(context).colorScheme.primary;
    final markers = <Marker>[];
    var sinceLast = intervalMeters; // così piazza la prima freccia presto

    for (var i = 1; i < path.length; i++) {
      final seg = _distance(path[i - 1], path[i]);
      sinceLast += seg;
      if (sinceLast < intervalMeters || seg == 0) continue;
      sinceLast = 0;

      final bearingDeg = _distance.bearing(path[i - 1], path[i]);
      markers.add(
        Marker(
          point: path[i],
          width: 30,
          height: 30,
          child: Transform.rotate(
            angle: bearingDeg * math.pi / 180.0,
            child: Icon(
              Icons.navigation,
              size: 22,
              color: color,
              shadows: const [Shadow(blurRadius: 2, color: Colors.black54)],
            ),
          ),
        ),
      );
    }

    // Key legata al percorso: forza un rebuild pulito quando cambia (evita
    // marker "fantasma" residui dopo rimozione/spostamento di un nodo).
    return MarkerLayer(
      key: ValueKey('arrows-${path.length}-${markers.length}'),
      markers: markers,
    );
  }
}
