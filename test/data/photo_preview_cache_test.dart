import 'dart:async' show Completer;
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentei/data/photos/photo_library_service.dart';
import 'package:sentei/data/photos/photo_preview_cache.dart';
import 'package:sentei/domain/models/photo_candidate.dart';

/// Libreria finta: conta le richieste (è quello che la cache deve evitare) e
/// permette di completarle a mano, per osservare cosa succede *mentre* una
/// richiesta è in volo.
class _FakeLibrary extends PhotoLibraryService {
  final Map<String, Completer<Uint8List?>> pending = {};
  final List<String> requested = [];

  @override
  Future<PhotoLibraryPermission> requestPermission() async =>
      PhotoLibraryPermission.authorized;

  @override
  Future<List<RawPhotoLocation>> photoLocations({
    DateTime? after,
    DateTime? before,
  }) async =>
      const [];

  @override
  Future<Uint8List?> thumbnail(String assetId, {int size = 200}) async => null;

  @override
  Future<Uint8List?> preview(
    String assetId, {
    required int maxWidth,
    required int maxHeight,
  }) {
    requested.add(assetId);
    return (pending[assetId] = Completer<Uint8List?>()).future;
  }

  @override
  Future<File?> originalFile(String assetId) async => null;

  /// Completa la richiesta in volo per [assetId] con byte riconoscibili.
  Future<void> complete(String assetId, int marker) async {
    pending.remove(assetId)!.complete(Uint8List.fromList([marker]));
    // Lascia girare i `then` della cache prima di tornare al test.
    await Future<void>.delayed(Duration.zero);
  }
}

Future<Uint8List?> _load(
  PhotoPreviewCache cache,
  _FakeLibrary library,
  String id,
  int marker,
) async {
  final future = cache.preview(id, width: 100, height: 100);
  await library.complete(id, marker);
  return future;
}

void main() {
  late _FakeLibrary library;

  setUp(() => library = _FakeLibrary());

  test('la seconda richiesta della stessa foto non tocca la libreria',
      () async {
    final cache = PhotoPreviewCache(library);
    await _load(cache, library, 'a', 1);

    final again = await cache.preview('a', width: 100, height: 100);

    expect(library.requested, ['a']);
    expect(again, isNotNull);
    expect(cache.cached('a'), isNotNull);
  });

  test('due richieste in volo sulla stessa foto ne condividono una sola',
      () async {
    final cache = PhotoPreviewCache(library);
    final first = cache.preview('a', width: 100, height: 100);
    final second = cache.preview('a', width: 100, height: 100);
    await library.complete('a', 1);

    expect(library.requested, ['a']);
    expect((await first)!.first, 1);
    expect((await second)!.first, 1);
  });

  test('oltre la capienza esce la foto usata meno di recente', () async {
    final cache = PhotoPreviewCache(library, maxEntries: 2);
    await _load(cache, library, 'a', 1);
    await _load(cache, library, 'b', 2);
    await _load(cache, library, 'c', 3);

    expect(cache.cached('a'), isNull, reason: 'la più vecchia esce');
    expect(cache.cached('b'), isNotNull);
    expect(cache.cached('c'), isNotNull);
  });

  test('rileggere una foto la salva dallo sfratto successivo', () async {
    final cache = PhotoPreviewCache(library, maxEntries: 2);
    await _load(cache, library, 'a', 1);
    await _load(cache, library, 'b', 2);

    await cache.preview('a', width: 100, height: 100); // 'a' torna in coda
    await _load(cache, library, 'c', 3);

    expect(cache.cached('a'), isNotNull);
    expect(cache.cached('b'), isNull);
  });

  test('il precarico salta quelle già in cache o già in volo', () async {
    final cache = PhotoPreviewCache(library);
    await _load(cache, library, 'a', 1);
    cache.preview('b', width: 100, height: 100); // in volo, non completata

    cache.prefetch(['a', 'b', 'c'], width: 100, height: 100);

    expect(library.requested, ['a', 'b', 'c'],
        reason: 'solo "c" è una richiesta nuova');
  });

  test('un errore della libreria non propaga e non sporca la cache', () async {
    final cache = PhotoPreviewCache(library);
    final future = cache.preview('a', width: 100, height: 100);
    library.pending.remove('a')!.completeError(StateError('asset sparito'));

    expect(await future, isNull);
    expect(cache.cached('a'), isNull);

    // E la foto resta richiedibile di nuovo (nessuna richiesta "fantasma"
    // rimasta in volo che blocchi i tentativi successivi).
    await _load(cache, library, 'a', 1);
    expect(library.requested, ['a', 'a']);
    expect(cache.cached('a'), isNotNull);
  });

  test('clear svuota la cache', () async {
    final cache = PhotoPreviewCache(library);
    await _load(cache, library, 'a', 1);

    cache.clear();

    expect(cache.cached('a'), isNull);
  });
}
