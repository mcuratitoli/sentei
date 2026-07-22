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

  // Testo / icone (grigi di sistema iOS, dal più scuro al più chiaro)
  static const Color label = Color(0xFF1C1C1E); // testo primario
  static const Color bodyText = Color(0xFF3A3A3C); // corpo descrittivo
  static const Color secondaryLabel = Color(0xFF6E6E73); // sottotitoli/caption
  static const Color iconGrey = Color(0xFF8E8E93); // icone/valori inattivi (systemGray)
  static const Color iconGreyLight = Color(0xFF9A9AA0); // icone tenui (copia, hint)
  static const Color tertiaryIcon = Color(0xFFB0B0B5); // placeholder/chiudi

  // Vetro / linee / overlay
  static const Color glassFill = Color(0xFFFFFFFF); // riempimento superfici vetro
  static const Color hairline = Color(0xFF3C3C43); // separatori (usare con alpha)
  static const Color overlayDark = Color(0xF01C1C1E); // tooltip/toast scuri
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

/// Type scale app-specifica (oltre al `TextTheme` del tema), allineata iOS.
/// Il colore va applicato al call-site (`.copyWith(color: …)`) quando serve.
abstract final class AppText {
  /// 22/700 — titolo di sheet/legenda.
  static const TextStyle sheetTitle =
      TextStyle(fontSize: 22, fontWeight: FontWeight.w700);

  /// 17/400 — riga di menu iOS (body).
  static const TextStyle menuItem = TextStyle(fontSize: 17);

  /// 16/700 — valore/etichetta forte (header di sezione).
  static const TextStyle sectionValue =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

  /// 16/600 — valore enfatizzato / titolo di dialog.
  static const TextStyle value =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  /// 15/600 — etichetta di pillola/bottone.
  static const TextStyle pillLabel =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600);

  /// 14.5/500 — testo del toast.
  static const TextStyle toast =
      TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500);

  /// 14/400 — corpo.
  static const TextStyle body = TextStyle(fontSize: 14);

  /// 13.5 + interlinea — corpo descrittivo su più righe.
  static const TextStyle bodyDetail = TextStyle(fontSize: 13.5, height: 1.35);

  /// 13/400 — footnote/hint.
  static const TextStyle footnote = TextStyle(fontSize: 13);

  /// 13/500 — caption.
  static const TextStyle caption =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w500);

  /// 13/600 — caption enfatizzata (tooltip grafico).
  static const TextStyle captionEmphasis =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

  /// 12/400 — caption piccola (chip/hint).
  static const TextStyle captionSmall = TextStyle(fontSize: 12);

  /// 12/700 — badge (sigla difficoltà su fondo colorato).
  static const TextStyle badge =
      TextStyle(fontSize: 12, fontWeight: FontWeight.w700);

  /// 11/600 — etichette assi del grafico.
  static const TextStyle chartLabel =
      TextStyle(fontSize: 11, fontWeight: FontWeight.w600);
}
