// Smoke test: l'app si avvia e mostra la schermata mappa.
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sentei/app/app.dart';
import 'package:sentei/data/storage/tracks_repository.dart';
import 'package:sentei/features/draw_route/route_editor_provider.dart';

/// Repository finto: evita di aprire il DB su disco nei test.
class _FakeRepo implements TracksRepository {
  @override
  Future<List<DrawnTrack>> loadAll() async => const [];
  @override
  Future<List<({DrawnTrack track, DateTime updatedAt})>>
      loadAllWithUpdatedAt() async => const [];
  @override
  Future<void> save(DrawnTrack track, {DateTime? updatedAt}) async {}
  @override
  Future<void> delete(String id) async {}
}

void main() {
  testWidgets('L\'app si avvia sulla schermata mappa', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tracksRepositoryProvider.overrideWithValue(_FakeRepo())],
        child: const SenteiApp(),
      ),
    );

    // La barra in basso contiene il pulsante "+" per una nuova traccia.
    expect(find.byIcon(CupertinoIcons.add), findsOneWidget);
  });
}
