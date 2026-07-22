import 'package:flutter/widgets.dart';

// **Design token** dell'app (tema unico *chiaro*). Centralizzano i valori che
// prima erano hardcoded e duplicati nelle schermate → una sola fonte di verità
// per colore, spaziatura, raggi e testo. Vedi l'audit in `docs/ROADMAP.md` (P1).
//
// Regola: le schermate NON usano più `Color(0x…)`/`fontSize:` sparsi ma questi
// token (o `Theme.of(context).colorScheme`/`textTheme`). Eccezione già ok:
// `lib/ui/cai_difficulty.dart` (palette semantica di dominio).

/// Colori dell'app. Valori 1:1 con quelli storici, salvo `destructive` che è
/// stato **unificato** a iOS *systemRed* (prima convivevano `C62828` e `FF3B30`).
abstract final class AppColors {
  /// Blu del brand (= seed del tema; anche `colorScheme.primary`).
  static const Color primary = Color(0xFF1565C0);

  /// Azione distruttiva (elimina/disconnetti). iOS `systemRed`.
  static const Color destructive = Color(0xFFFF3B30);

  /// Sfondo raggruppato stile iOS (`systemGroupedBackground`).
  static const Color groupedBg = Color(0xFFF2F2F7);

  // Testo (grigi di sistema iOS)
  static const Color label = Color(0xFF1C1C1E); // testo primario
  static const Color secondaryLabel = Color(0xFF6E6E73); // sottotitoli/caption
  static const Color bodyText = Color(0xFF3A3A3C); // corpo descrittivo
  static const Color tertiaryIcon = Color(0xFFB0B0B5); // icone tenui/placeholder

  // Vetro / linee
  static const Color glassFill = Color(0xFFFFFFFF); // riempimento superfici vetro
  static const Color hairline = Color(0xFF3C3C43); // separatori (usare con alpha)
}

/// Scala di spaziatura su griglia 4dp.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapBase = SizedBox(width: base, height: base);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
}

/// Raggi di curvatura ricorrenti.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double pill = 22; // pillole/controlli in vetro
  static const double card = 24; // card traccia
  static const double sheet = 22; // bottom sheet

  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius rCard = BorderRadius.all(Radius.circular(card));
}

/// Stili di testo app-specifici ricorrenti (oltre al `TextTheme` del tema).
/// Il colore va applicato al call-site quando serve differenziarlo.
abstract final class AppText {
  static const TextStyle sheetTitle =
      TextStyle(fontSize: 22, fontWeight: FontWeight.w700);
  static const TextStyle sectionValue =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  static const TextStyle body = TextStyle(fontSize: 14);
  static const TextStyle bodyDetail = TextStyle(fontSize: 13.5, height: 1.35);
  static const TextStyle caption =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
  static const TextStyle captionSmall = TextStyle(fontSize: 12);
  static const TextStyle pillLabel =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
}
