import 'cloud_sync_service.dart';
import '../../features/draw_route/route_editor_provider.dart';

/// Piano di sincronizzazione calcolato confrontando lo stato locale e remoto.
/// Logica pura (nessun I/O): facile da testare.
class SyncPlan {
  const SyncPlan({
    required this.toUpload,
    required this.toDownload,
    required this.upToDate,
  });

  /// Id delle tracce locali da caricare (assenti o più recenti del remoto).
  final List<String> toUpload;

  /// Tracce remote da scaricare (assenti in locale o più recenti).
  final List<RemoteTrackMeta> toDownload;

  /// Numero di tracce già allineate (stesso timestamp).
  final int upToDate;

  bool get isEmpty => toUpload.isEmpty && toDownload.isEmpty;
}

/// Calcola il piano **last-write-wins** confrontando i timestamp.
///
/// [localUpdatedAt]: id traccia → ultima modifica locale. [remote]: metadati
/// remoti. Regole: presente solo da un lato → si copia dall'altro; presente da
/// entrambi → vince il timestamp più recente; pari → nulla da fare.
///
/// Le **eliminazioni non si propagano** (v1): una traccia cancellata da un lato
/// viene ri-copiata dall'altro, mai rimossa. Limite documentato.
SyncPlan computeSyncPlan({
  required Map<String, DateTime> localUpdatedAt,
  required List<RemoteTrackMeta> remote,
}) {
  final remoteById = {for (final r in remote) r.id: r};
  final toUpload = <String>[];
  final toDownload = <RemoteTrackMeta>[];
  var upToDate = 0;

  // Lato locale.
  localUpdatedAt.forEach((id, localTs) {
    final r = remoteById[id];
    if (r == null) {
      toUpload.add(id); // solo locale
    } else if (localTs.isAfter(r.updatedAt)) {
      toUpload.add(id); // locale più recente
    } else if (r.updatedAt.isAfter(localTs)) {
      toDownload.add(r); // remoto più recente
    } else {
      upToDate++; // allineate
    }
  });

  // Tracce presenti solo nel remoto.
  for (final r in remote) {
    if (!localUpdatedAt.containsKey(r.id)) toDownload.add(r);
  }

  return SyncPlan(
    toUpload: toUpload,
    toDownload: toDownload,
    upToDate: upToDate,
  );
}

/// Esito di una sincronizzazione completata.
class SyncResult {
  const SyncResult({
    required this.uploaded,
    required this.downloaded,
    required this.upToDate,
    required this.pulled,
  });

  final int uploaded;
  final int downloaded;
  final int upToDate;

  /// Tracce scaricate dal cloud, da salvare/aggiornare in locale.
  final List<DrawnTrack> pulled;
}
