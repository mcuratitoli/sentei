import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/gpx/gpx_service.dart';
import '../route_editor_provider.dart';

/// Esporta [track] in GPX e apre il foglio di condivisione di sistema.
/// Condiviso tra la card traccia sulla mappa (foglio "Esporta") e il menu
/// ⋯ della lista tracciati — stessa azione, due punti d'ingresso.
Future<void> exportTrackGpx(BuildContext context, DrawnTrack track) async {
  final xml = const GpxService().exportToGpx(track);
  final dir = await getTemporaryDirectory();
  final safe = (track.name.isNotEmpty ? track.name : 'tracciato')
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final path = '${dir.path}/$safe.gpx';
  await File(path).writeAsString(xml);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(path)], text: track.name),
  );
}
