import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show DebugPrintCallback, debugPrint;
import 'package:path_provider/path_provider.dart';

/// Cattura tutto quello che l'app scrive con `debugPrint` (già usato per la
/// diagnostica dell'export immagine — `route_snapshot.dart`,
/// `export_image_screen.dart` — e per il routing BRouter) e lo scrive su
/// file, con rotazione — per poterlo rileggere da un telefono reale in beta
/// senza un Mac collegato (Impostazioni → footer versione, 7 tap, §export
/// non pianificato del 24 ago 2026).
///
/// **Nessuna modifica ai punti che già chiamano `debugPrint`**: si
/// sovrascrive la funzione globale `debugPrint` di Flutter (una variabile di
/// primo livello riassegnabile), quindi ogni chiamata esistente o futura
/// finisce qui automaticamente.
///
/// **Rotazione**: file corrente fino a [maxFileBytes] (512 KB, scelto per
/// restare leggero da leggere/condividere anche in rete scarsa in
/// montagna), poi ruotato; tenuti al più [maxFiles] file (quindi ~2 MB
/// totali). In più, potatura per **età** all'avvio: file più vecchi di
/// [maxAgeDays] (7) vengono scartati — un log di debug per un'app beta fra
/// amici non ha senso conservarlo più a lungo, ed è anche meglio per la
/// privacy (niente accumulo indefinito di percorsi/coordinate nei log).
class AppLogService {
  AppLogService._();
  static final AppLogService instance = AppLogService._();

  static const int maxFileBytes = 512 * 1024;
  static const int maxFiles = 4;
  static const int maxAgeDays = 7;
  static const String _baseName = 'sentei.log';

  Directory? _dir;
  IOSink? _sink;
  int _currentBytes = 0;
  DebugPrintCallback? _previous;
  bool _installed = false;

  bool get isInstalled => _installed;

  /// Da chiamare una sola volta, presto in `main()` (prima di `runApp`), così
  /// nessuna riga di log si perde. Fallisce in silenzio se la directory non
  /// è disponibile: il logging è un aiuto diagnostico, non deve mai impedire
  /// all'app di avviarsi.
  Future<void> install() async {
    if (_installed) return;
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/logs');
      await dir.create(recursive: true);
      _dir = dir;
      await _purgeOldFiles();
      final file = File('${dir.path}/$_baseName');
      _currentBytes = await file.exists() ? await file.length() : 0;
      _sink = file.openWrite(mode: FileMode.append);
    } catch (e) {
      debugPrint('[log] AppLogService.install fallito: $e');
      return;
    }
    _previous = debugPrint;
    debugPrint = _onDebugPrint;
    _installed = true;
  }

  void _onDebugPrint(String? message, {int? wrapWidth}) {
    _previous?.call(message, wrapWidth: wrapWidth);
    final sink = _sink;
    if (sink == null || message == null) return;
    final line = '${_timestamp(DateTime.now())}  $message\n';
    sink.write(line);
    _currentBytes += line.length;
    if (_currentBytes >= maxFileBytes) {
      // Fire-and-forget: la rotazione non deve bloccare chi ha chiamato
      // `debugPrint` in attesa che torni.
      unawaited(_rotate());
    }
  }

  /// `yyyy-MM-ddTHH:mm:ss.mmm` — millisecondi (3 cifre), non i microsecondi
  /// (fino a 6) di `DateTime.toIso8601String()`: per un log di debug letto a
  /// occhio non servono, sono solo rumore visivo (richiesta esplicita
  /// dell'utente, 24 ago 2026). Costruito a mano invece di troncare la
  /// stringa ISO: quella omette la frazione quando cade su un secondo
  /// esatto, qui il formato resta sempre della stessa lunghezza.
  static String _timestamp(DateTime t) {
    String p2(int n) => n.toString().padLeft(2, '0');
    String p3(int n) => n.toString().padLeft(3, '0');
    return '${t.year}-${p2(t.month)}-${p2(t.day)}T${p2(t.hour)}:'
        '${p2(t.minute)}:${p2(t.second)}.${p3(t.millisecond)}';
  }

  Future<void> _rotate() async {
    final dir = _dir;
    if (dir == null) return;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;

    // Fa scorrere sentei.log.(N-1) → .N, ..., sentei.log → sentei.log.1
    // (il più vecchio, oltre `maxFiles`, viene sovrascritto/perso).
    for (var i = maxFiles - 1; i >= 1; i--) {
      final from = File('${dir.path}/$_baseName.$i');
      final to = File('${dir.path}/$_baseName.${i + 1}');
      if (await from.exists()) {
        if (i + 1 > maxFiles) {
          await from.delete();
        } else {
          await from.rename(to.path);
        }
      }
    }
    final current = File('${dir.path}/$_baseName');
    if (await current.exists()) {
      await current.rename('${dir.path}/$_baseName.1');
    }
    _currentBytes = 0;
    _sink = File('${dir.path}/$_baseName').openWrite(mode: FileMode.append);
  }

  Future<void> _purgeOldFiles() async {
    final dir = _dir;
    if (dir == null) return;
    final cutoff = DateTime.now().subtract(const Duration(days: maxAgeDays));
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!entity.path.contains(_baseName)) continue;
      final stat = await entity.stat();
      if (stat.modified.isBefore(cutoff)) {
        await entity.delete();
      }
    }
  }

  /// Tutti i file di log esistenti, dal più vecchio al più recente (stesso
  /// ordine di lettura naturale: le righe più vecchie in cima).
  Future<List<File>> _logFilesOldestFirst() async {
    final dir = _dir;
    if (dir == null) return const [];
    final files = <File>[];
    for (var i = maxFiles; i >= 1; i--) {
      final f = File('${dir.path}/$_baseName.$i');
      if (await f.exists()) files.add(f);
    }
    final current = File('${dir.path}/$_baseName');
    if (await current.exists()) files.add(current);
    return files;
  }

  /// Contenuto di tutti i log concatenati, dal più vecchio al più recente.
  /// Usato sia dalla schermata di consultazione sia dalla condivisione.
  Future<String> readAll() async {
    final files = await _logFilesOldestFirst();
    final buffer = StringBuffer();
    for (final f in files) {
      try {
        buffer.write(await f.readAsString());
      } catch (_) {
        // File illeggibile/corrotto: salta, non deve bloccare la lettura
        // degli altri.
      }
    }
    return buffer.toString();
  }

  /// Cancella tutti i log su disco (correnti e ruotati) e riparte da un file
  /// vuoto.
  Future<void> clear() async {
    final dir = _dir;
    if (dir == null) return;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.contains(_baseName)) {
        await entity.delete();
      }
    }
    _currentBytes = 0;
    _sink = File('${dir.path}/$_baseName').openWrite(mode: FileMode.append);
  }
}
