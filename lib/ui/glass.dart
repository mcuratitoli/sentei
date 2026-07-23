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

/// Colore di riempimento base dei controlli in vetro. Più basso = più
/// translucido (la mappa traspare); il blur aiuta dove il contenuto retrostante
/// è Flutter (menu/liste), non sulla platform view Mapbox.
const double _kGlassOpacity = 0.66;
const double _kGlassBlur = 24;

/// Superficie in vetro con [borderRadius] arbitrario. Il [child] va dentro il
/// riempimento translucido; l'ombra è disegnata attorno (fuori dal clip).
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.opacity = _kGlassOpacity,
    this.blur = _kGlassBlur,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double opacity;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.glassFill.withValues(alpha: opacity),
              borderRadius: borderRadius,
              border: Border.all(
                color: palette.glassBorder,
                width: 0.6,
              ),
            ),
            child: child,
          ),
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
