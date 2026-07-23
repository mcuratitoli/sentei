import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Estetica "vetro smerigliato" stile iOS (Apple Maps): superfici translucide con
/// blur del contenuto retrostante, bordo sottile chiaro e ombra morbida. Da usare
/// per i controlli flottanti al posto delle Card/Material con elevazione.
///
/// Nota: sopra una *platform view* nativa (mappa Mapbox) il blur potrebbe non
/// applicarsi; il riempimento bianco translucido mantiene comunque un look pulito.

/// Superficie in vetro con [borderRadius] arbitrario. Il [child] va dentro il
/// riempimento translucido; l'ombra è disegnata attorno (fuori dal clip).
///
/// Opacità e blur di default vengono dalla palette del tema corrente
/// ([AppPalette.glassOpacity]/[AppPalette.glassBlur]) — passare [opacity]/[blur]
/// esplicitamente solo per scostarsi dal default della variante (vedi
/// l'uso in `map_gl_screen.dart` per la card informazioni punto).
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.opacity,
    this.blur,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double? opacity;
  final double? blur;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final effectiveBlur = blur ?? palette.glassBlur;
    final fill = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.glassFill.withValues(alpha: opacity ?? palette.glassOpacity),
        borderRadius: borderRadius,
        border: Border.all(
          color: palette.glassBorder,
          width: 0.6,
        ),
      ),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        // Blur 0 (variante OLED): niente BackdropFilter — pannello flat e
        // senza il costo GPU della cattura/sfocatura dello sfondo.
        child: effectiveBlur <= 0
            ? fill
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
                child: fill,
              ),
      ),
    );
  }
}

/// Bottone circolare in vetro (~44px) con press-dim iOS (niente ripple Material).
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.size = 44,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback onPressed;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget button = GlassSurface(
      borderRadius: BorderRadius.circular(size / 2),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size(size, size),
        onPressed: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
