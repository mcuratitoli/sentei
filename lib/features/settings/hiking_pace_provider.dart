import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/services/hiking_time.dart';

/// Passo dell'escursionista (Lento/Medio/Veloce), **persistito** in
/// `shared_preferences` — moltiplicatore sulla stima del tempo di
/// percorrenza (`domain/services/hiking_time.dart`, §ROADMAP P1.2). Default:
/// **Medio** (il riferimento CAI, nessuna correzione).
class HikingPaceController extends Notifier<HikingPace> {
  static const _key = 'hiking_pace';

  @override
  HikingPace build() {
    _restore();
    return HikingPace.medium;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == null) return;
      for (final p in HikingPace.values) {
        if (p.name == saved) {
          if (p != state) state = p;
          return;
        }
      }
    } catch (_) {
      // shared_preferences non disponibile (es. in test): resta il default.
    }
  }

  Future<void> set(HikingPace pace) async {
    state = pace;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, pace.name);
    } catch (_) {
      // best-effort
    }
  }
}

final hikingPaceProvider =
    NotifierProvider<HikingPaceController, HikingPace>(
        HikingPaceController.new);
