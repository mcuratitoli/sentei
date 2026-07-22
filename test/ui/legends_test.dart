import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentei/ui/legends.dart';

/// Verifica che le legende (difficoltà + abbreviazioni) si costruiscano e
/// contengano i contenuti tratti dal libro (Guida CAI / Welzenbach / sigle).
void main() {
  Widget host(void Function(BuildContext) open) => MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => open(c),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  testWidgets('legenda difficoltà: escursionistiche, alpinistiche e Welzenbach',
      (tester) async {
    await tester.pumpWidget(host(showDifficultyLegend));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Difficoltà dei percorsi'), findsOneWidget);
    // Escursionistiche (scala CAI)
    expect(find.text('T'), findsOneWidget);
    expect(find.text('EEA'), findsOneWidget);
    // Alpinistiche
    expect(find.text('F'), findsOneWidget);
    expect(find.text('Poco difficile'), findsOneWidget);
    // Welzenbach (l'intestazione di sezione è resa in maiuscolo)
    expect(find.textContaining('WELZENBACH'), findsWidgets);
    expect(find.text('Primo grado'), findsOneWidget);
    expect(find.text('Terzo grado'), findsOneWidget);
    // Nota condizioni
    expect(find.textContaining('condizioni ottimali'), findsOneWidget);
  });

  testWidgets('legenda abbreviazioni: sigle e significati dal libro',
      (tester) async {
    await tester.pumpWidget(host(showAbbreviationsLegend));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Abbreviazioni'), findsOneWidget);
    expect(find.text('UGET'), findsOneWidget);
    expect(find.text('Unione Giovani Escursionisti Torino'), findsOneWidget);
    expect(find.text('IGN'), findsOneWidget);
    expect(find.text('Institut Géographique National (francese)'),
        findsOneWidget);
  });
}
