import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentei/app/theme.dart';
import 'package:sentei/data/cloud/cloud_sync_service.dart';
import 'package:sentei/features/draw_route/route_editor_provider.dart';
import 'package:sentei/features/settings/cloud_sync_controller.dart';
import 'package:sentei/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cloud finto non connesso: l'auto-sync è no-op nei test (niente plugin).
class _FakeCloud implements CloudSyncService {
  @override
  String get providerName => 'Fake';
  @override
  Future<bool> isSignedIn() async => false;
  @override
  Future<String?> signIn() async => null;
  @override
  Future<void> signOut() async {}
  @override
  Future<String?> currentAccount() async => null;
  @override
  Future<List<RemoteTrackMeta>> listRemote() async => const [];
  @override
  Future<DrawnTrack?> downloadTrack(RemoteTrackMeta meta) async => null;
  @override
  Future<void> uploadTrack(DrawnTrack track,
      {required DateTime updatedAt}) async {}
  @override
  Future<void> deleteTrack(RemoteTrackMeta meta) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget host() => ProviderScope(
        overrides: [cloudServiceProvider.overrideWithValue(_FakeCloud())],
        child: const MaterialApp(home: SettingsScreen()),
      );

  testWidgets(
      'sezione Aspetto: default Automatico/Standard, variante nascosta in luce',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Aspetto'), findsOneWidget);
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Automatico'), findsOneWidget);
    // In chiaro (piattaforma di test = light) la variante scura non si mostra.
    expect(find.text('Variante scura'), findsNothing);
  });

  testWidgets('selezionare Scuro dal menu Tema mostra la Variante scura',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tema'));
    await tester.pumpAndSettle();
    expect(find.text('Scuro'), findsWidgets); // voce di menu + eventuali echi

    await tester.tap(find.text('Scuro').last);
    await tester.pumpAndSettle();

    expect(find.text('Variante scura'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget); // default variante
  });

  testWidgets('selezionare una variante scura aggiorna la riga', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scuro').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Variante scura'));
    await tester.pumpAndSettle();
    expect(find.text('Notturno'), findsWidgets);

    await tester.tap(find.text('Notturno').last);
    await tester.pumpAndSettle();

    expect(find.text('Notturno'), findsOneWidget); // ora solo l'additionalInfo
  });

  test('AppTheme.dark applica palette distinte per ciascuna variante', () {
    final fills = {for (final v in AppDarkVariant.values) v.palette.glassFill};
    expect(fills.length, AppDarkVariant.values.length);
  });
}
