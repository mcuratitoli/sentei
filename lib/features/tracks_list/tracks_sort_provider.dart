import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Criteri di ordinamento della lista tracciati.
enum TrackSortMode { alpha, date, elevationGain, maxAltitude }

/// Ordinamento selezionato, **persistito** in `shared_preferences` così resta
/// invariato riaprendo la lista o l'app. Default: **alfabetico**.
class TrackSortController extends Notifier<TrackSortMode> {
  static const _key = 'tracks_sort';

  @override
  TrackSortMode build() {
    _restore();
    return TrackSortMode.alpha;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == null) return;
      for (final m in TrackSortMode.values) {
        if (m.name == saved) {
          if (m != state) state = m;
          return;
        }
      }
    } catch (_) {
      // shared_preferences non disponibile (es. in test): resta il default.
    }
  }

  Future<void> set(TrackSortMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {
      // best-effort
    }
  }
}

final tracksSortProvider =
    NotifierProvider<TrackSortController, TrackSortMode>(
        TrackSortController.new);
