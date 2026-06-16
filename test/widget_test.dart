// Smoke test: l'app si avvia e mostra la schermata mappa.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sentei/app/app.dart';

void main() {
  testWidgets('L\'app si avvia sulla schermata mappa', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SenteiApp()),
    );

    // Il titolo dell'AppBar è il nome dell'app.
    expect(find.text('Sentèi'), findsOneWidget);
  });
}
