import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Impostazioni dell'app. La mappa è **Mapbox Outdoors** (con terreno 3D e
/// numeri sentiero CAI); non c'è più un selettore di sorgente.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String routeName = 'settings';
  static const String routePath = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.map_outlined),
            title: Text('Mappa'),
            subtitle: Text('Mapbox Outdoors · terreno 3D · numeri sentiero CAI'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Sentèi'),
            subtitle: Text('App escursionismo'),
          ),
          ListTile(
            leading: Icon(Icons.cloud_off),
            title: Text('Sincronizzazione cloud'),
            subtitle: Text('In arrivo (Google Drive)'),
            enabled: false,
          ),
        ],
      ),
    );
  }
}
