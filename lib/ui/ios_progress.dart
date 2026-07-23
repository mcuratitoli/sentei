import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;

import 'glass.dart';
import 'tokens.dart';

/// Dialog di **progresso** in stile vetro, coerente con `showIosMenu`/
/// `showIosConfirm` (`ios_menu.dart`): card centrata, non dismissibile, con
/// spinner + messaggio. Sostituisce i `CupertinoAlertDialog` nativi (chrome da
/// alert di sistema, stonano con l'estetica in vetro del resto dell'app).
///
/// [message] può essere aggiornato mentre il dialog è aperto (es. percentuale
/// di avanzamento). Ritorna la funzione per chiuderlo.
VoidCallback showIosProgress(
  BuildContext context, {
  String? title,
  required ValueListenable<String> message,
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'progress',
    barrierColor: const Color(0x14000000),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (_, __, ___) => _ProgressCard(title: title, message: message),
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return () {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  };
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({this.title, required this.message});

  final String? title;
  final ValueListenable<String> message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 270),
        child: GlassSurface(
          opacity: 0.96,
          borderRadius: AppRadii.rMd,
          child: Padding(
            padding: const EdgeInsets.all(20),
            // Dentro showGeneralDialog non c'è un DefaultTextStyle "buono":
            // senza questo il testo mostra la doppia sottolineatura di debug
            // (stesso problema già risolto in ios_menu.dart).
            child: DefaultTextStyle(
              style: AppText.footnote.copyWith(
                decoration: TextDecoration.none,
                color: palette.label,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null && title!.isNotEmpty) ...[
                    Text(
                      title!,
                      textAlign: TextAlign.center,
                      style: AppText.value.copyWith(
                        color: palette.label,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const CupertinoActivityIndicator(radius: 11),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<String>(
                    valueListenable: message,
                    builder: (_, v, __) => Text(
                      v,
                      textAlign: TextAlign.center,
                      style: AppText.footnote.copyWith(
                        color: palette.secondaryLabel,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
