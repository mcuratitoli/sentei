import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cloud/cloud_sync_engine.dart';
import '../../data/cloud/cloud_sync_service.dart';
import '../../data/cloud/google_drive_sync_service.dart';
import '../draw_route/route_editor_provider.dart';

/// Servizio cloud attivo. Per ora Google Drive; iCloud si aggiungerà come
/// implementazione alternativa di [CloudSyncService].
///
/// Le credenziali OAuth si passano via `--dart-define` (mai nel repo, §9):
/// `GOOGLE_CLIENT_ID` (iOS client id) e, se serve, `GOOGLE_SERVER_CLIENT_ID`.
final cloudServiceProvider = Provider<CloudSyncService>((ref) {
  const clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  return GoogleDriveSyncService(
    clientId: clientId.isEmpty ? null : clientId,
    serverClientId: serverClientId.isEmpty ? null : serverClientId,
  );
});

/// Stato della sezione cloud nelle Impostazioni.
class CloudState {
  const CloudState({this.account, this.busy = false, this.message});

  /// Account connesso (email), `null` se non loggato.
  final String? account;

  /// Login o sincronizzazione in corso.
  final bool busy;

  /// Ultimo esito o messaggio d'errore (per uno SnackBar/etichetta).
  final String? message;

  bool get signedIn => account != null;

  CloudState copyWith({
    Object? account = _unset,
    bool? busy,
    Object? message = _unset,
  }) =>
      CloudState(
        account: account == _unset ? this.account : account as String?,
        busy: busy ?? this.busy,
        message: message == _unset ? this.message : message as String?,
      );

  static const _unset = Object();
}

/// Controller della sincronizzazione cloud: login/logout e "Sincronizza ora"
/// (merge last-write-wins tra tracce locali e remote).
class CloudSyncController extends Notifier<CloudState> {
  @override
  CloudState build() {
    _checkSession();
    return const CloudState(busy: true);
  }

  CloudSyncService get _service => ref.read(cloudServiceProvider);

  Future<void> _checkSession() async {
    try {
      final acct = await _service.currentAccount();
      state = CloudState(account: acct);
    } catch (_) {
      state = const CloudState(); // non configurato / non loggato
    }
  }

  Future<void> signIn() async {
    if (state.busy) return;
    state = state.copyWith(busy: true, message: null);
    try {
      final acct = await _service.signIn();
      state = CloudState(
        account: acct,
        message: acct == null ? 'Accesso annullato' : null,
      );
    } on CloudSyncException catch (e) {
      state = state.copyWith(busy: false, message: e.message);
    } catch (e) {
      state = state.copyWith(busy: false, message: 'Errore accesso: $e');
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(busy: true);
    try {
      await _service.signOut();
    } catch (_) {/* best-effort */}
    state = const CloudState();
  }

  Future<void> syncNow() async {
    if (state.busy || !state.signedIn) return;
    state = state.copyWith(busy: true, message: null);
    try {
      final repo = ref.read(tracksRepositoryProvider);
      final remote = await _service.listRemote();
      final locals = await repo.loadAllWithUpdatedAt();
      final localUpdatedAt = {for (final e in locals) e.track.id: e.updatedAt};
      final trackById = {for (final e in locals) e.track.id: e.track};

      final plan =
          computeSyncPlan(localUpdatedAt: localUpdatedAt, remote: remote);

      for (final id in plan.toUpload) {
        await _service.uploadTrack(trackById[id]!,
            updatedAt: localUpdatedAt[id]!);
      }
      for (final meta in plan.toDownload) {
        final t = await _service.downloadTrack(meta);
        if (t != null) await repo.save(t, updatedAt: meta.updatedAt);
      }
      if (plan.toDownload.isNotEmpty) {
        await ref.read(tracksProvider.notifier).reloadFromDisk();
      }

      state = state.copyWith(
        busy: false,
        message: 'Sincronizzato · ↑${plan.toUpload.length} '
            '↓${plan.toDownload.length} · ${plan.upToDate} già allineate',
      );
    } on CloudSyncException catch (e) {
      state = state.copyWith(busy: false, message: e.message);
    } catch (e) {
      state = state.copyWith(busy: false, message: 'Errore sync: $e');
    }
  }
}

final cloudSyncProvider =
    NotifierProvider<CloudSyncController, CloudState>(CloudSyncController.new);
