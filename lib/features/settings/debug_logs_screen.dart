import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/logging/app_log_service.dart';
import '../../ui/app_buttons.dart';
import '../../ui/ios_menu.dart';
import '../../ui/ios_toast.dart';
import '../../ui/tokens.dart';

/// Consultazione dei log dell'app — voce **volutamente non in vista** in
/// Impostazioni (sblocco con 7 tap sul footer versione, non un tasto come
/// gli altri): utile a chi segue da vicino la beta per mandare la
/// diagnostica di un problema senza un Mac collegato, non pensata per l'uso
/// quotidiano. Sorgente: `AppLogService` (cattura `debugPrint` su file, con
/// rotazione).
class DebugLogsScreen extends StatefulWidget {
  const DebugLogsScreen({super.key});

  static const String routeName = 'debug-logs';
  static const String routePath = '/settings/debug-logs';

  @override
  State<DebugLogsScreen> createState() => _DebugLogsScreenState();
}

/// Una riga di log **interpretata**: timestamp, categoria (il tag
/// `[qualcosa]` iniziale, se c'è) e il resto del messaggio. Ogni punto del
/// codice che scrive `debugPrint('[categoria] ...')` guadagna qui
/// un'etichetta colorata — vedi `_categoryColor` per l'elenco.
class _LogEntry {
  const _LogEntry({required this.timestamp, this.category, required this.body});

  final String timestamp;
  final String? category;
  final String body;

  /// Il file scrive sempre `<timestamp>  <messaggio>` (due spazi): si separa
  /// lì, indipendentemente da quante cifre di frazione di secondo ha il
  /// timestamp (righe vecchie, scritte prima del taglio a 3 cifre, restano
  /// leggibili). La categoria è il tag `[...]` in testa al messaggio, se c'è.
  static _LogEntry parse(String line) {
    final sep = line.indexOf('  ');
    final timestamp = sep == -1 ? '' : line.substring(0, sep);
    final rest = sep == -1 ? line : line.substring(sep + 2);
    final match = RegExp(r'^\[([a-zA-Z0-9_-]+)\]\s?(.*)$').firstMatch(rest);
    if (match != null) {
      return _LogEntry(
          timestamp: timestamp, category: match.group(1), body: match.group(2)!);
    }
    return _LogEntry(timestamp: timestamp, category: null, body: rest);
  }
}

/// Colore per categoria (badge del tag `[...]`): stessa tinta ogni volta che
/// si vede quella categoria, per riconoscerla a colpo d'occhio scorrendo. Se
/// se ne aggiunge una nuova nel codice non serve toccare questa mappa: le
/// categorie non elencate prendono `_defaultCategoryColor`.
const Map<String, Color> _categoryColors = {
  'export': Color(0xFFBA68C8), // viola
  'routing': Color(0xFFFFA726), // arancio
  'storage': Color(0xFF64B5F6), // blu
  'metrics': Color(0xFF4DB6AC), // teal
  'trails': Color(0xFF81C784), // verde
  'gpx': Color(0xFFF06292), // magenta
  'terrain': Color(0xFFBCAAA4), // marrone chiaro
  'cloud': Color(0xFF4DD0E1), // ciano
  'log': Color(0xFF9E9E9E), // grigio (diagnostica interna)
};
const Color _defaultCategoryColor = Color(0xFFB0B0B8);

class _DebugLogsScreenState extends State<DebugLogsScreen> {
  final _scrollController = ScrollController();
  List<_LogEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final text = await AppLogService.instance.readAll();
    final entries = text.isEmpty
        ? const <_LogEntry>[]
        : text
            .split('\n')
            .where((l) => l.isNotEmpty)
            .map(_LogEntry.parse)
            .toList();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
    // Le righe più recenti sono in fondo: si parte da lì, non dall'inizio
    // di una settimana di log.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _share() async {
    final text = await AppLogService.instance.readAll();
    if (text.isEmpty) {
      if (mounted) showIosToast(context, 'Nessun log da condividere');
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sentei-log.txt');
    await file.writeAsString(text);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Log Sentèi'),
    );
  }

  Future<void> _confirmClear() async {
    await showIosConfirm(
      context: context,
      title: 'Cancellare i log?',
      message: 'Tutte le righe registrate finora verranno eliminate.',
      confirmLabel: 'Cancella',
      onConfirm: () async {
        await AppLogService.instance.clear();
        if (mounted) {
          setState(() {
            _entries = const [];
            _loading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.scaffoldBg,
      appBar: AppBar(
        title: const Text('Log'),
        centerTitle: true,
        backgroundColor: palette.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        actions: [
          AppIconButton(
            tooltip: 'Cancella',
            icon: CupertinoIcons.trash,
            onPressed: _entries.isEmpty ? null : _confirmClear,
          ),
          const SizedBox(width: 4),
          AppIconButton(
            tooltip: 'Condividi',
            icon: CupertinoIcons.square_arrow_up,
            onPressed: _entries.isEmpty ? null : _share,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Text('Nessun log ancora registrato.',
                      style: AppText.body
                          .copyWith(color: palette.secondaryLabel)),
                )
              : Container(
                  color: const Color(0xFF1C1C1E),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: _entries.length,
                    itemBuilder: (context, i) => _LogRow(entry: _entries[i]),
                  ),
                ),
    );
  }
}

/// Una voce di log: timestamp + categoria colorata su una riga, il
/// messaggio sotto — invece di un'unica riga lunga timestamp-messaggio,
/// difficile da scorrere a occhio (richiesta esplicita dell'utente, 24 ago
/// 2026, dopo aver provato l'export dei log).
class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final _LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final categoryColor = entry.category == null
        ? null
        : (_categoryColors[entry.category!] ?? _defaultCategoryColor);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(entry.timestamp,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 10,
                    fontFamily: 'Menlo',
                  )),
              if (entry.category != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: categoryColor!.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.category!,
                    style: TextStyle(
                      color: categoryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Menlo',
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 1),
          Text(
            entry.body,
            style: const TextStyle(
              color: Color(0xFFD1D1D6),
              fontSize: 12,
              fontFamily: 'Menlo',
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
