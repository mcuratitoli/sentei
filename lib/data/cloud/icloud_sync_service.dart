import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:icloud_storage/icloud_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/draw_route/route_editor_provider.dart';
import '../gpx/gpx_service.dart';
import '../storage/track_codec.dart';
import 'cloud_sync_service.dart';

/// Sincronizzazione su **iCloud Drive** (§6.5), implementazione gemella di
/// [GoogleDriveSyncService] dietro la stessa interfaccia [CloudSyncService].
///
/// Ogni traccia è un `Sentèi/<id>.json` (autosufficiente, fonte di verità) +
/// `Sentèi/<id>.gpx` (interoperabilità), nel **container iCloud dedicato**.
///
/// Differenze rispetto a Drive:
/// - iCloud non ha un login interattivo né "appProperties": l'account è quello
///   **di sistema** di iOS. `signIn` verifica solo che il container sia
///   raggiungibile (utente loggato in iCloud + iCloud Drive attivo per l'app).
/// - Il timestamp `updatedAt` per il last-write-wins è letto **dal contenuto**
///   del JSON (lo include [TrackCodec]); fallback su `contentChangeDate` del file.
///   Per evitare un doppio download, `listRemote` mette in cache le tracce lette
///   e `downloadTrack` le riusa.
class IcloudSyncService implements CloudSyncService {
  IcloudSyncService({String? containerId})
      : _containerId = containerId ?? _defaultContainerId;

  /// Container iCloud (convenzione `iCloud.<bundleId>`). Deve combaciare con la
  /// capability iCloud configurata in Xcode/portale Apple.
  static const _defaultContainerId = 'iCloud.com.mattiacuratitoli.sentei';
  static const _folder = 'Sentèi';

  final String _containerId;

  /// Tracce lette durante l'ultimo [listRemote], per non riscaricarle in
  /// [downloadTrack].
  final Map<String, DrawnTrack> _downloaded = {};

  @override
  String get providerName => 'iCloud Drive';

  // ---- disponibilità / "sessione" -----------------------------------------

  /// Il container è raggiungibile (utente loggato in iCloud)?
  Future<bool> _available() async {
    try {
      await ICloudStorage.gather(containerId: _containerId);
      return true;
    } on PlatformException catch (e) {
      if (e.code == PlatformExceptionCode.iCloudConnectionOrPermission) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Future<bool> isSignedIn() => _available();

  @override
  Future<String?> signIn() async {
    // Nessun login interattivo: si usa l'account iCloud di sistema.
    if (await _available()) return 'iCloud';
    throw const CloudSyncException(
        'iCloud non disponibile. Accedi a iCloud nelle Impostazioni di iOS e '
        'attiva iCloud Drive per Sentèi.');
  }

  @override
  Future<void> signOut() async {
    // Non si "esce" dall'account iCloud di sistema: azzeriamo solo la cache.
    _downloaded.clear();
  }

  @override
  Future<String?> currentAccount() async =>
      (await _available()) ? 'iCloud' : null;

  // ---- sync ----------------------------------------------------------------

  @override
  Future<List<RemoteTrackMeta>> listRemote() async {
    _downloaded.clear();
    final files = await ICloudStorage.gather(containerId: _containerId);
    final prefix = '$_folder/';
    final out = <RemoteTrackMeta>[];
    for (final f in files) {
      final path = f.relativePath;
      if (!path.startsWith(prefix) || !path.endsWith('.json')) continue;
      final id = path.substring(prefix.length, path.length - '.json'.length);
      final json = await _readJson(path);
      if (json == null) continue;
      _downloaded[id] = TrackCodec.fromJson(json);
      final updated = TrackCodec.updatedAtOf(json) ?? f.contentChangeDate;
      out.add(RemoteTrackMeta(id: id, updatedAt: updated, providerFileId: path));
    }
    return out;
  }

  @override
  Future<DrawnTrack?> downloadTrack(RemoteTrackMeta meta) async {
    final cached = _downloaded[meta.id];
    if (cached != null) return cached;
    final path = meta.providerFileId ?? '$_folder/${meta.id}.json';
    final json = await _readJson(path);
    return json == null ? null : TrackCodec.fromJson(json);
  }

  @override
  Future<void> uploadTrack(DrawnTrack track,
      {required DateTime updatedAt}) async {
    final json = TrackCodec.toJson(track, updatedAt: updatedAt);
    await _uploadBytes(
        '$_folder/${track.id}.json', utf8.encode(jsonEncode(json)));
    // Sidecar GPX per interoperabilità (best-effort; il JSON è la verità).
    try {
      final gpx = const GpxService().exportToGpx(track);
      await _uploadBytes('$_folder/${track.id}.gpx', utf8.encode(gpx));
    } catch (_) {/* ignora: il JSON basta */}
  }

  @override
  Future<void> deleteTrack(RemoteTrackMeta meta) async {
    for (final ext in const ['json', 'gpx']) {
      try {
        await ICloudStorage.delete(
          containerId: _containerId,
          relativePath: '$_folder/${meta.id}.$ext',
        );
      } catch (_) {/* potrebbe non esistere (es. nessun .gpx) */}
    }
  }

  // ---- I/O su file ---------------------------------------------------------

  /// Scarica e deserializza il JSON in [relativePath] (`null` se illeggibile).
  Future<Map<String, dynamic>?> _readJson(String relativePath) async {
    final tmp = await _tempFile(relativePath);
    try {
      await _downloadToFile(relativePath, tmp.path);
      if (!await tmp.exists()) return null;
      final content = await tmp.readAsString();
      if (content.isEmpty) return null;
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  /// `download` ritorna appena avviato: attendiamo `onDone` dello stream di
  /// progresso (o un timeout) per essere certi che il file sia materializzato.
  Future<void> _downloadToFile(String relativePath, String destPath) async {
    final done = Completer<void>();
    await ICloudStorage.download(
      containerId: _containerId,
      relativePath: relativePath,
      destinationFilePath: destPath,
      onProgress: (stream) {
        stream.listen(
          (_) {},
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          onError: (Object e) {
            if (!done.isCompleted) done.completeError(e);
          },
          cancelOnError: true,
        );
      },
    );
    await done.future.timeout(const Duration(seconds: 30));
  }

  Future<void> _uploadBytes(String relativePath, List<int> bytes) async {
    final tmp = await _tempFile(relativePath);
    await tmp.writeAsBytes(bytes, flush: true);
    try {
      final done = Completer<void>();
      await ICloudStorage.upload(
        containerId: _containerId,
        filePath: tmp.path,
        destinationRelativePath: relativePath,
        onProgress: (stream) {
          stream.listen(
            (_) {},
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
            onError: (Object e) {
              if (!done.isCompleted) done.completeError(e);
            },
            cancelOnError: true,
          );
        },
      );
      await done.future.timeout(const Duration(seconds: 30));
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  /// File temporaneo locale per upload/download (nome derivato dal path remoto).
  Future<File> _tempFile(String relativePath) async {
    final dir = await getTemporaryDirectory();
    final safe = relativePath.replaceAll('/', '_');
    return File('${dir.path}/icloud_$safe');
  }
}
