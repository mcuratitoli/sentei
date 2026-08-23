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

class _DebugLogsScreenState extends State<DebugLogsScreen> {
  final _scrollController = ScrollController();
  List<String> _lines = const [];
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
    final lines = text.isEmpty
        ? const <String>[]
        : text.split('\n').where((l) => l.isNotEmpty).toList();
    if (!mounted) return;
    setState(() {
      _lines = lines;
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
            _lines = const [];
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
            onPressed: _lines.isEmpty ? null : _confirmClear,
          ),
          const SizedBox(width: 4),
          AppIconButton(
            tooltip: 'Condividi',
            icon: CupertinoIcons.square_arrow_up,
            onPressed: _lines.isEmpty ? null : _share,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _lines.isEmpty
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
                    itemCount: _lines.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        _lines[i],
                        style: const TextStyle(
                          color: Color(0xFFD1D1D6),
                          fontSize: 11,
                          fontFamily: 'Menlo',
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
