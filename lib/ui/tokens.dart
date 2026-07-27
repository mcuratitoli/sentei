import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

// **Design token** dell'app (chiaro + 3 varianti scure). Centralizzano i valori che
// prima erano hardcoded e duplicati nelle schermate → una sola fonte di verità
// per colore, spaziatura, raggi e testo. Vedi l'audit in `docs/ROADMAP.md` (P1).
//
// Regola: le schermate NON usano più `Color(0x…)`/`fontSize:` sparsi ma questi
// token (o `Theme.of(context).colorScheme`/`textTheme`). Eccezione già ok:
// `lib/ui/cai_difficulty.dart` (palette semantica di dominio).

/// Colori dell'app — allineati a `new design/DESIGN_GUIDELINES.md` (luglio 2026):
/// blu di brand aggiornato, `destructive` **unificato** al rosso della scala di
/// difficoltà CAI `EEA` (stesso significato "attenzione/pericolo/rimozione" —
/// vedi [AppDifficultyColors.eea]), non più lo *systemRed* iOS storico.
abstract final class AppColors {
  /// Blu del brand (= seed del tema; anche `colorScheme.primary`). Unico
  /// colore di "brand/azione" nell'app — non riusare altrove (badge di
  /// difficoltà e dati hanno la propria palette, [AppDifficultyColors]).
  static const Color primary = Color(0xFF0071E0);

  /// Stato *pressed* del blu di brand (bottoni primari).
  static const Color primaryPressed = Color(0xFF0058C4);

  /// Azione distruttiva (elimina/disconnetti/scollega) — stesso rosso di
  /// [AppDifficultyColors.eea], non un rosso indipendente.
  static const Color destructive = AppDifficultyColors.eea;

  /// Sfondo raggruppato stile iOS (`systemGroupedBackground`).
  static const Color groupedBg = Color(0xFFF5F3EF);

  // Testo / icone (grigi di sistema iOS, dal più scuro al più chiaro)
  static const Color label = Color(0xFF11161F); // testo primario
  static const Color bodyText = Color(0xFF3A3A3C); // corpo descrittivo
  static const Color secondaryLabel = Color(0xFF5E646C); // sottotitoli/caption
  static const Color iconGrey = Color(0xFF8E8E93); // icone/valori inattivi (systemGray)
  static const Color iconGreyLight = Color(0xFF9A9AA0); // icone tenui (copia, hint)
  static const Color tertiaryIcon = Color(0xFF94999F); // placeholder/chiudi

  // Vetro / linee / overlay
  static const Color glassFill = Color(0xFFFFFFFF); // riempimento superfici vetro
  static const Color hairline = Color(0xFF3C3C43); // separatori (usare con alpha)
  static const Color overlayDark = Color(0xF01C1C1E); // tooltip/toast scuri
}

/// Palette **semantica** della scala di difficoltà escursionistica CAI
/// (T/E/EE/EEA) — condivisa da `cai_difficulty.dart` (badge/grafico) e da
/// [AppColors.destructive] (l'EEA rosso è anche il rosso "distruttivo").
/// Non riusare il blu qui: è riservato al brand ([AppColors.primary]).
abstract final class AppDifficultyColors {
  static const Color t = Color(0xFF348F4F);
  static const Color e = Color(0xFF009192);
  static const Color ee = Color(0xFFDD7B2B);
  static const Color eea = Color(0xFFCC3336);
}

/// Palette **strutturale** dipendente dal tema (chiaro/scuro): sfondi, testo,
/// grigi, vetro, linee. Si risolve da `context.palette`. I colori
/// **brand/semantici** (primary, destructive, difficoltà CAI, palette tracce)
/// restano costanti in [AppColors].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.scaffoldBg,
    required this.glassFill,
    required this.glassBorder,
    required this.label,
    required this.secondaryLabel,
    required this.bodyText,
    required this.iconGrey,
    required this.iconGreyLight,
    required this.tertiaryIcon,
    required this.hairline,
    required this.accent,
    required this.borderDivider,
    required this.iconBgNeutral,
    this.glassOpacity = 0.66,
    this.glassBlur = 24,
    this.contentGlassOpacity = 0.85,
    this.contentGlassBlur = 30,
  });

  final Color scaffoldBg; // sfondo grouped delle schermate
  final Color glassFill; // colore base delle superfici in vetro
  final Color glassBorder; // bordo chiaro delle superfici in vetro
  final Color label; // testo primario
  final Color secondaryLabel; // sottotitoli/caption
  final Color bodyText; // corpo descrittivo
  final Color iconGrey; // icone/valori inattivi
  final Color iconGreyLight; // icone tenui
  final Color tertiaryIcon; // placeholder/chiudi
  final Color hairline; // separatori (usare con alpha)

  /// Colore di accento interattivo (bottoni, selezioni, link). **Blu di brand**
  /// in tutte le varianti tranne [AppDarkVariant.night], dove diventa un ambra
  /// caldo: il senso della variante notturna è **azzerare la luce blu**, quindi
  /// anche l'accento (non solo testo/sfondi) deve restare sui toni caldi.
  final Color accent;

  /// Bordo dei separatori/contorni pill "opachi" (badge tag sentiero, righe
  /// impostazioni) — distinto da [hairline] (usato con alpha sul vetro):
  /// qui il colore è già alla tinta finale, nessun alpha da applicare.
  final Color borderDivider;

  /// Sfondo di default degli icon-button "opachi" (card ridisegnate secondo
  /// `new design/DESIGN_GUIDELINES.md`): cerchio neutro, non tinto d'accento —
  /// quello è riservato allo stato attivo/selezionato (vedi `AppIconButton`).
  final Color iconBgNeutral;

  /// Opacità/blur del riempimento "vetro" (`GlassSurface`) per la **chrome**
  /// di navigazione (menubar, controlli laterali, ricerca, punto ispezionato
  /// in esplorazione): più trasparente, pensata per restare leggera sopra la
  /// mappa. Diversi solo per [AppDarkVariant.oled]: pannelli quasi opachi e
  /// **senza blur** — oltre a leggersi come "flat/minimal", evita il lavoro
  /// GPU del `BackdropFilter` (coerente col nome "risparmio energetico").
  final double glassOpacity;
  final double glassBlur;

  /// Opacità/blur delle card di **contenuto** (traccia/punto selezionato,
  /// dettaglio foto, import GPX, foto vicine): meno trasparenti della chrome
  /// per la leggibilità di testo/dati, ma non del tutto opache. Stesso valore
  /// in ogni variante tranne [AppDarkVariant.oled] (eredita le stesse
  /// [glassOpacity]/[glassBlur] "flat" della chrome, coerenti col resto).
  final double contentGlassOpacity;
  final double contentGlassBlur;

  /// Palette **chiara** (= valori storici in [AppColors]).
  static const light = AppPalette(
    scaffoldBg: AppColors.groupedBg,
    glassFill: AppColors.glassFill,
    glassBorder: Color(0x99FFFFFF),
    label: AppColors.label,
    secondaryLabel: AppColors.secondaryLabel,
    bodyText: AppColors.bodyText,
    iconGrey: AppColors.iconGrey,
    iconGreyLight: AppColors.iconGreyLight,
    tertiaryIcon: AppColors.tertiaryIcon,
    hairline: AppColors.hairline,
    accent: AppColors.primary,
    borderDivider: Color(0xFFE2E1DD),
    iconBgNeutral: Color(0xFFF1F0EC),
  );

  /// **Standard** — dark elegante in stile iOS (superfici elevate #1C1C1E su
  /// nero, testo bianco). Variante di default.
  static const darkStandard = AppPalette(
    scaffoldBg: Color(0xFF000000),
    glassFill: Color(0xFF1C1C1E),
    glassBorder: Color(0x1FFFFFFF),
    label: Color(0xFFFFFFFF),
    secondaryLabel: Color(0x99EBEBF5),
    bodyText: Color(0xFFEBEBF5),
    iconGrey: Color(0xFF8E8E93),
    iconGreyLight: Color(0xFF98989D),
    tertiaryIcon: Color(0xFF636366),
    hairline: Color(0xFF545458),
    accent: AppColors.primary,
    borderDivider: Color(0xFF545458),
    iconBgNeutral: Color(0xFF2C2C2E),
  );

  /// **Notturno** — uso in montagna: toni caldi/smorzati (niente bianco puro né
  /// blu freddo) per minimizzare l'abbagliamento e preservare la visione notturna.
  static const darkNight = AppPalette(
    scaffoldBg: Color(0xFF120A05),
    glassFill: Color(0xFF1F140C),
    glassBorder: Color(0x1FFFEEDD),
    label: Color(0xFFF5D9C0),
    secondaryLabel: Color(0xFFB08F72),
    bodyText: Color(0xFFE0BFA0),
    iconGrey: Color(0xFF8A7460),
    iconGreyLight: Color(0xFF9C8670),
    tertiaryIcon: Color(0xFF6B5A48),
    hairline: Color(0xFF4A3B2E),
    // Ambra bruciato, non blu: lo scopo della variante è azzerare la luce blu,
    // quindi anche l'accento interattivo (bottoni, selezioni) deve restare
    // caldo — contrasto col bianco verificato (~5.6:1, alla pari del blu).
    accent: Color(0xFF9C551A),
    borderDivider: Color(0xFF4A3B2E),
    iconBgNeutral: Color(0xFF2A1D12),
  );

  /// **Risparmio energetico** — nero puro (OLED) ovunque possibile, per
  /// minimizzare i pixel accesi; grigi ridotti all'essenziale per la leggibilità.
  /// Rispetto a [darkStandard]: vetro **quasi opaco e senza blur** (niente
  /// `BackdropFilter` = meno lavoro GPU) invece che semitrasparente, bordi/hairline
  /// quasi invisibili — deve leggersi "flat" a colpo d'occhio, non solo nei valori hex.
  static const darkOled = AppPalette(
    scaffoldBg: Color(0xFF000000),
    glassFill: Color(0xFF000000),
    glassBorder: Color(0x0DFFFFFF),
    label: Color(0xFFFFFFFF),
    secondaryLabel: Color(0xFF8E8E93),
    bodyText: Color(0xFFD0D0D0),
    iconGrey: Color(0xFF7A7A7D),
    iconGreyLight: Color(0xFF86868A),
    tertiaryIcon: Color(0xFF59595C),
    hairline: Color(0xFF1A1A1A),
    accent: AppColors.primary,
    borderDivider: Color(0xFF1A1A1A),
    iconBgNeutral: Color(0xFF141414),
    glassOpacity: 0.98,
    glassBlur: 0,
    // Stessa scelta "flat" della chrome: niente blur nemmeno per le card di
    // contenuto, coerente col nome "risparmio energetico".
    contentGlassOpacity: 0.98,
    contentGlassBlur: 0,
  );

  @override
  AppPalette copyWith({
    Color? scaffoldBg,
    Color? glassFill,
    Color? glassBorder,
    Color? label,
    Color? secondaryLabel,
    Color? bodyText,
    Color? iconGrey,
    Color? iconGreyLight,
    Color? tertiaryIcon,
    Color? hairline,
    Color? accent,
    Color? borderDivider,
    Color? iconBgNeutral,
    double? glassOpacity,
    double? glassBlur,
    double? contentGlassOpacity,
    double? contentGlassBlur,
  }) =>
      AppPalette(
        scaffoldBg: scaffoldBg ?? this.scaffoldBg,
        glassFill: glassFill ?? this.glassFill,
        glassBorder: glassBorder ?? this.glassBorder,
        label: label ?? this.label,
        secondaryLabel: secondaryLabel ?? this.secondaryLabel,
        bodyText: bodyText ?? this.bodyText,
        iconGrey: iconGrey ?? this.iconGrey,
        iconGreyLight: iconGreyLight ?? this.iconGreyLight,
        tertiaryIcon: tertiaryIcon ?? this.tertiaryIcon,
        hairline: hairline ?? this.hairline,
        accent: accent ?? this.accent,
        borderDivider: borderDivider ?? this.borderDivider,
        iconBgNeutral: iconBgNeutral ?? this.iconBgNeutral,
        glassOpacity: glassOpacity ?? this.glassOpacity,
        glassBlur: glassBlur ?? this.glassBlur,
        contentGlassOpacity: contentGlassOpacity ?? this.contentGlassOpacity,
        contentGlassBlur: contentGlassBlur ?? this.contentGlassBlur,
      );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      label: Color.lerp(label, other.label, t)!,
      secondaryLabel: Color.lerp(secondaryLabel, other.secondaryLabel, t)!,
      bodyText: Color.lerp(bodyText, other.bodyText, t)!,
      iconGrey: Color.lerp(iconGrey, other.iconGrey, t)!,
      iconGreyLight: Color.lerp(iconGreyLight, other.iconGreyLight, t)!,
      tertiaryIcon: Color.lerp(tertiaryIcon, other.tertiaryIcon, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      borderDivider: Color.lerp(borderDivider, other.borderDivider, t)!,
      iconBgNeutral: Color.lerp(iconBgNeutral, other.iconBgNeutral, t)!,
      glassOpacity: lerpDouble(glassOpacity, other.glassOpacity, t)!,
      glassBlur: lerpDouble(glassBlur, other.glassBlur, t)!,
      contentGlassOpacity:
          lerpDouble(contentGlassOpacity, other.contentGlassOpacity, t)!,
      contentGlassBlur: lerpDouble(contentGlassBlur, other.contentGlassBlur, t)!,
    );
  }
}

/// Accesso rapido alla [AppPalette] del tema corrente (fallback: chiara).
extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
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
