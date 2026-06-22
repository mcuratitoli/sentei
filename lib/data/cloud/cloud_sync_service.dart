import '../../features/draw_route/route_editor_provider.dart';

/// Metadati di una traccia remota: bastano per decidere cosa scaricare o
/// sovrascrivere senza leggere l'intero contenuto.
class RemoteTrackMeta {
  const RemoteTrackMeta({
    required this.id,
    required this.updatedAt,
    this.providerFileId,
  });

  /// Id della traccia (= [DrawnTrack.id]).
  final String id;

  /// Ultima modifica nota lato cloud (per il last-write-wins).
  final DateTime updatedAt;

  /// Id interno del file presso il provider (es. Drive fileId), se serve per
  /// aggiornare/eliminare. Opzionale.
  final String? providerFileId;
}

/// Eccezione di sincronizzazione cloud (login, rete, parsing…).
class CloudSyncException implements Exception {
  const CloudSyncException(this.message);
  final String message;
  @override
  String toString() => 'CloudSyncException: $message';
}

/// Interfaccia comune per la sincronizzazione delle tracce su un cloud
/// personale dell'utente (Google Drive, iCloud Drive). (§6.5)
///
/// Modello a **file**: una traccia = un JSON autosufficiente (+ eventuale GPX
/// per interoperabilità), conflitti risolti **last-write-wins** per timestamp.
/// Niente backend: i file vivono nel cloud dell'utente.
abstract class CloudSyncService {
  /// Nome leggibile del provider (es. "Google Drive").
  String get providerName;

  /// Sessione già attiva (token valido), senza interazione utente.
  Future<bool> isSignedIn();

  /// Login interattivo. Ritorna l'identificativo dell'account (es. email) o
  /// `null` se l'utente annulla.
  Future<String?> signIn();

  /// Termina la sessione locale.
  Future<void> signOut();

  /// Account attualmente connesso (email/nome), `null` se non loggato.
  Future<String?> currentAccount();

  /// Elenco delle tracce remote con il loro timestamp di modifica.
  Future<List<RemoteTrackMeta>> listRemote();

  /// Scarica e deserializza una traccia remota (`null` se non leggibile).
  Future<DrawnTrack?> downloadTrack(RemoteTrackMeta meta);

  /// Crea o aggiorna una traccia remota, marcandola con [updatedAt].
  Future<void> uploadTrack(DrawnTrack track, {required DateTime updatedAt});

  /// Elimina una traccia remota.
  Future<void> deleteTrack(RemoteTrackMeta meta);
}
