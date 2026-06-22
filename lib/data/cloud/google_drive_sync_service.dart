import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../../features/draw_route/route_editor_provider.dart';
import '../gpx/gpx_service.dart';
import '../storage/track_codec.dart';
import 'cloud_sync_service.dart';

/// Sincronizzazione su **Google Drive** (§6.5). Login con `google_sign_in` v7,
/// I/O file con `googleapis` (Drive v3). Ogni traccia è salvata come
/// `<id>.json` (autosufficiente, fonte di verità) **+** `<id>.gpx` (per usarla
/// in altre app), dentro una cartella dedicata **"Sentèi"**.
///
/// Scope: `drive.file` → l'app vede e tocca **solo i file che ha creato**
/// (minimo privilegio; i file restano comunque visibili all'utente nel Drive).
class GoogleDriveSyncService implements CloudSyncService {
  GoogleDriveSyncService({String? clientId, String? serverClientId})
      : _clientId = clientId,
        _serverClientId = serverClientId;

  final String? _clientId;
  final String? _serverClientId;

  static const _folderName = 'Sentèi';
  static const _scopes = <String>[drive.DriveApi.driveFileScope];
  static const _folderMime = 'application/vnd.google-apps.folder';

  bool _initialized = false;
  GoogleSignInAccount? _account;
  String? _folderId;

  @override
  String get providerName => 'Google Drive';

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance
        .initialize(clientId: _clientId, serverClientId: _serverClientId);
    _initialized = true;
  }

  @override
  Future<bool> isSignedIn() async {
    await _ensureInitialized();
    _account ??= await GoogleSignIn.instance.attemptLightweightAuthentication();
    return _account != null;
  }

  @override
  Future<String?> signIn() async {
    await _ensureInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const CloudSyncException(
          'Login Google non supportato su questa piattaforma');
    }
    try {
      _account = await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
      // Forza subito l'autorizzazione agli scope Drive (può chiedere conferma).
      await _authorizedClient();
      return _account?.email;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw CloudSyncException('Login Google fallito: ${e.description ?? e.code}');
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    _account = null;
    _folderId = null;
    await GoogleSignIn.instance.signOut();
  }

  @override
  Future<String?> currentAccount() async {
    if (await isSignedIn()) return _account?.email;
    return null;
  }

  // ---- client autenticato -------------------------------------------------

  Future<drive.DriveApi> _api() async {
    final account = _account ??
        await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (account == null) {
      throw const CloudSyncException('Non connesso a Google Drive');
    }
    _account = account;
    final client = await _authorizedClient();
    return drive.DriveApi(client);
  }

  Future<http.Client> _authorizedClient() async {
    final account = _account!;
    var authz = await account.authorizationClient.authorizationForScopes(_scopes);
    authz ??= await account.authorizationClient.authorizeScopes(_scopes);
    return authz.authClient(scopes: _scopes);
  }

  /// Id della cartella "Sentèi", creandola se non esiste.
  Future<String> _ensureFolder(drive.DriveApi api) async {
    if (_folderId != null) return _folderId!;
    final found = await api.files.list(
      q: "mimeType='$_folderMime' and name='$_folderName' and trashed=false",
      $fields: 'files(id,name)',
      spaces: 'drive',
    );
    final existing = found.files;
    if (existing != null && existing.isNotEmpty) {
      return _folderId = existing.first.id!;
    }
    final folder = await api.files.create(drive.File()
      ..name = _folderName
      ..mimeType = _folderMime);
    return _folderId = folder.id!;
  }

  // ---- sync ---------------------------------------------------------------

  @override
  Future<List<RemoteTrackMeta>> listRemote() async {
    final api = await _api();
    final folderId = await _ensureFolder(api);
    final res = await api.files.list(
      q: "'$folderId' in parents and trashed=false and "
          "mimeType='application/json'",
      $fields: 'files(id,name,modifiedTime,appProperties)',
      spaces: 'drive',
      pageSize: 1000,
    );
    final out = <RemoteTrackMeta>[];
    for (final f in res.files ?? const <drive.File>[]) {
      final id = f.appProperties?['trackId'] ??
          (f.name?.endsWith('.json') ?? false
              ? f.name!.substring(0, f.name!.length - 5)
              : null);
      if (id == null) continue;
      final updated = TrackCodec.parseDate(f.appProperties?['updatedAt']) ??
          f.modifiedTime ??
          DateTime.fromMillisecondsSinceEpoch(0);
      out.add(RemoteTrackMeta(
          id: id, updatedAt: updated, providerFileId: f.id));
    }
    return out;
  }

  @override
  Future<DrawnTrack?> downloadTrack(RemoteTrackMeta meta) async {
    final api = await _api();
    final fileId = meta.providerFileId;
    if (fileId == null) return null;
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return TrackCodec.fromJson(json);
  }

  @override
  Future<void> uploadTrack(DrawnTrack track,
      {required DateTime updatedAt}) async {
    final api = await _api();
    final folderId = await _ensureFolder(api);
    final json = TrackCodec.toJson(track, updatedAt: updatedAt);
    final appProps = {
      'trackId': track.id,
      'updatedAt': updatedAt.toIso8601String(),
    };
    await _upsertFile(
      api,
      folderId: folderId,
      name: '${track.id}.json',
      mimeType: 'application/json',
      bytes: utf8.encode(jsonEncode(json)),
      appProperties: appProps,
    );
    // Sidecar GPX per interoperabilità (best-effort; non blocca la sync).
    try {
      final gpx = const GpxService().exportToGpx(track);
      await _upsertFile(
        api,
        folderId: folderId,
        name: '${track.id}.gpx',
        mimeType: 'application/gpx+xml',
        bytes: utf8.encode(gpx),
        appProperties: {'trackId': track.id},
      );
    } catch (_) {/* il JSON è la fonte di verità */}
  }

  @override
  Future<void> deleteTrack(RemoteTrackMeta meta) async {
    final api = await _api();
    final folderId = await _ensureFolder(api);
    // Elimina sia il .json sia l'eventuale .gpx della traccia.
    final res = await api.files.list(
      q: "'$folderId' in parents and trashed=false and "
          "(name='${meta.id}.json' or name='${meta.id}.gpx')",
      $fields: 'files(id)',
      spaces: 'drive',
    );
    for (final f in res.files ?? const <drive.File>[]) {
      if (f.id != null) await api.files.delete(f.id!);
    }
  }

  /// Crea il file se assente, altrimenti ne aggiorna il contenuto.
  Future<void> _upsertFile(
    drive.DriveApi api, {
    required String folderId,
    required String name,
    required String mimeType,
    required List<int> bytes,
    required Map<String, String> appProperties,
  }) async {
    final media = drive.Media(Stream.value(bytes), bytes.length,
        contentType: mimeType);
    final existing = await api.files.list(
      q: "'$folderId' in parents and trashed=false and name='$name'",
      $fields: 'files(id)',
      spaces: 'drive',
    );
    final files = existing.files ?? const <drive.File>[];
    if (files.isNotEmpty) {
      await api.files.update(
        drive.File()..appProperties = appProperties,
        files.first.id!,
        uploadMedia: media,
      );
    } else {
      await api.files.create(
        drive.File()
          ..name = name
          ..parents = [folderId]
          ..appProperties = appProperties,
        uploadMedia: media,
      );
    }
  }
}
