import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../draw_route/route_editor_provider.dart' show elevationServiceProvider;

/// Punto della mappa ispezionato in modalità **esplorazione**: quando l'utente
/// tocca un punto dove non c'è una traccia da selezionare, mostriamo una
/// mini-card con coordinate e **altitudine** (risolta dal DEM Terrarium, quindi
/// anche offline sulle aree scaricate).
class InspectedPoint {
  const InspectedPoint({
    required this.point,
    this.elevation,
    this.loading = true,
  });

  final LatLng point;

  /// Quota in metri, oppure `null` se non disponibile (tile mancante / fuori
  /// copertura) — valida solo quando [loading] è `false`.
  final double? elevation;

  /// `true` finché la quota è in fase di risoluzione.
  final bool loading;
}

/// Stato del punto ispezionato (`null` = nessuno). Risolve la quota in modo
/// asincrono; un nuovo `inspect` invalida quello precedente (token).
class InspectedPointNotifier extends Notifier<InspectedPoint?> {
  int _token = 0;

  @override
  InspectedPoint? build() => null;

  /// Avvia l'ispezione di [point]: mostra subito coordinate + spinner, poi
  /// aggiorna con la quota quando è pronta.
  Future<void> inspect(LatLng point) async {
    final t = ++_token;
    state = InspectedPoint(point: point);
    double? elev;
    try {
      elev = await ref.read(elevationServiceProvider).elevationAt(point);
    } catch (_) {
      elev = null;
    }
    if (_token != t) return; // superato da una nuova ispezione o da clear()
    state = InspectedPoint(point: point, elevation: elev, loading: false);
  }

  /// Azzera il punto ispezionato (chiusura card / selezione traccia / disegno).
  void clear() {
    _token++;
    state = null;
  }
}

final inspectedPointProvider =
    NotifierProvider<InspectedPointNotifier, InspectedPoint?>(
  InspectedPointNotifier.new,
);
