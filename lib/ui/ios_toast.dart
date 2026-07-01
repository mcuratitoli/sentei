import 'package:flutter/cupertino.dart';

/// Toast transitorio in stile iOS: una pillola scura arrotondata che scivola
/// dal basso, resta qualche secondo e si dissolve. Sostituisce le `SnackBar`
/// Material per un feedback più coerente con l'estetica Apple.
///
/// Uso: `showIosToast(context, 'Traccia salvata')`.
void showIosToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late final OverlayEntry entry;
  final controller = _ToastController();
  entry = OverlayEntry(
    builder: (_) => _IosToast(
      message: message,
      controller: controller,
      onDismissed: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(duration, controller.hide);
}

/// Segnala al toast di iniziare l'uscita (fade/slide out).
class _ToastController extends ChangeNotifier {
  bool _visible = true;
  bool get visible => _visible;
  void hide() {
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }
}

class _IosToast extends StatefulWidget {
  const _IosToast({
    required this.message,
    required this.controller,
    required this.onDismissed,
  });

  final String message;
  final _ToastController controller;
  final VoidCallback onDismissed;

  @override
  State<_IosToast> createState() => _IosToastState();
}

class _IosToastState extends State<_IosToast> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    // Frame successivo: attiva l'animazione d'ingresso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  void _onControllerChanged() {
    if (mounted) setState(() => _shown = widget.controller.visible);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Positioned(
      left: 24,
      right: 24,
      bottom: media.padding.bottom + 90,
      child: IgnorePointer(
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          offset: _shown ? Offset.zero : const Offset(0, 0.4),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            opacity: _shown ? 1 : 0,
            onEnd: () {
              if (!_shown) widget.onDismissed();
            },
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xF01C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
