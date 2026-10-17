import 'package:flutter/material.dart';

/// Tokens for the "Classical" design system: a warm paper ground, ink text,
/// a single gold accent, hairline rules instead of cards, and a serif pairing
/// (Cormorant Garamond for figures/headings, Lora for prose).
///
/// Everything the screens need is derived from here — nothing hardcodes a hex
/// value outside this file.
@immutable
class SpendlyTokens extends ThemeExtension<SpendlyTokens> {
  const SpendlyTokens({
    required this.background,
    required this.surface,
    required this.ink,
    required this.accent,
    required this.accentSoft,
    required this.accentBorder,
    required this.accentStrong,
    required this.accentDeep,
    required this.accentInk,
    required this.danger,
    required this.series,
  });

  /// Page ground.
  final Color background;

  /// Very slightly raised ground (sheets, inset blocks).
  final Color surface;

  /// Primary text colour; every muted tone is a transparency of this.
  final Color ink;

  /// The single accent — gold.
  final Color accent;

  /// accent-100: tinted fill for callouts and selected chips.
  final Color accentSoft;

  /// accent-300: border for tinted blocks.
  final Color accentBorder;

  /// accent-600: filled bars and meters.
  final Color accentStrong;

  /// accent-700: emphasised figures (avatar initials, pace).
  final Color accentDeep;

  /// accent-800: text that sits on [accentSoft].
  final Color accentInk;

  /// Destructive actions only.
  final Color danger;

  /// Rank-ordered chart palette — gold first, then warm neutrals.
  final List<Color> series;

  /// Hairline rule between rows and sections.
  Color get divider => ink.withValues(alpha: 0.16);

  /// Unfilled portion of a meter.
  Color get track => ink.withValues(alpha: 0.07);

  /// Text at a reduced presence. 0.52–0.62 covers most secondary copy.
  Color muted([double opacity = 0.55]) => ink.withValues(alpha: opacity);

  Color seriesAt(int index) => series[index % series.length];

  static SpendlyTokens of(BuildContext context) =>
      Theme.of(context).extension<SpendlyTokens>() ?? light;

  // ── Type ───────────────────────────────────────────────────────────────────

  /// Cormorant Garamond — headings, and every figure in the app.
  TextStyle heading(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.14,
    double letterSpacingEm = -0.015,
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: 'CormorantGaramond',
      fontSize: size,
      fontWeight: weight,
      color: color ?? ink,
      height: height,
      letterSpacing: letterSpacingEm * size,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
  }

  /// Cormorant Garamond with tabular figures — amounts, counts, percentages.
  TextStyle figure(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.1,
    double letterSpacingEm = -0.015,
  }) {
    return heading(
      size,
      weight: weight,
      color: color,
      height: height,
      letterSpacingEm: letterSpacingEm,
      tabular: true,
    );
  }

  /// Lora — body copy, labels, row text.
  TextStyle body(
    double size, {
    Color? color,
    double height = 1.55,
    FontWeight weight = FontWeight.w400,
    double letterSpacingEm = 0,
    bool tabular = false,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: 'Lora',
      fontSize: size,
      fontWeight: weight,
      color: color ?? ink,
      height: height,
      fontStyle: fontStyle,
      letterSpacing: letterSpacingEm * size,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
  }

  /// The small tracked-out uppercase label that opens every section.
  TextStyle kicker({Color? color, double size = 10.5}) =>
      body(size, color: color ?? accent, height: 1.2, letterSpacingEm: 0.13);

  /// Uppercase caption under a metric.
  TextStyle metricLabel({double size = 10.5}) =>
      body(size, color: muted(0.52), height: 1.2, letterSpacingEm: 0.08);

  // ── ThemeExtension plumbing ────────────────────────────────────────────────

  @override
  SpendlyTokens copyWith({
    Color? background,
    Color? surface,
    Color? ink,
    Color? accent,
    Color? accentSoft,
    Color? accentBorder,
    Color? accentStrong,
    Color? accentDeep,
    Color? accentInk,
    Color? danger,
    List<Color>? series,
  }) {
    return SpendlyTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentBorder: accentBorder ?? this.accentBorder,
      accentStrong: accentStrong ?? this.accentStrong,
      accentDeep: accentDeep ?? this.accentDeep,
      accentInk: accentInk ?? this.accentInk,
      danger: danger ?? this.danger,
      series: series ?? this.series,
    );
  }

  /// The two grounds are too far apart to interpolate meaningfully; snap.
  @override
  SpendlyTokens lerp(ThemeExtension<SpendlyTokens>? other, double t) {
    if (other is! SpendlyTokens) return this;
    return t < 0.5 ? this : other;
  }

  static const SpendlyTokens light = SpendlyTokens(
    background: Color(0xFFF3F2F2),
    surface: Color(0xFFEAE9E9),
    ink: Color(0xFF201F1D),
    accent: Color(0xFFB68235),
    accentSoft: Color(0xFFFFF3E4),
    accentBorder: Color(0xFFFACB8D),
    accentStrong: Color(0xFFA06F24),
    accentDeep: Color(0xFF7D5411),
    accentInk: Color(0xFF5A3B0A),
    danger: Color(0xFF8D2F22),
    series: [
      Color(0xFFB68235),
      Color(0xFF6D675F),
      Color(0xFFA06F24),
      Color(0xFF8A8177),
      Color(0xFF7D5411),
      Color(0xFFB39A72),
      Color(0xFF444141),
      Color(0xFFC28D41),
    ],
  );

  static const SpendlyTokens dark = SpendlyTokens(
    background: Color(0xFF191817),
    surface: Color(0xFF232120),
    ink: Color(0xFFF2EFE9),
    accent: Color(0xFFD9A961),
    accentSoft: Color(0x23D9A961),
    accentBorder: Color(0x66D9A961),
    accentStrong: Color(0xFFD9A961),
    accentDeep: Color(0xFFE8C48F),
    accentInk: Color(0xFFF0D6AE),
    danger: Color(0xFFD98C7A),
    series: [
      Color(0xFFD9A961),
      Color(0xFFC8C2B6),
      Color(0xFFB39A72),
      Color(0xFF8A8177),
      Color(0xFF6D675F),
      Color(0xFFE8C48F),
      Color(0xFF9B9797),
      Color(0xFFF0D6AE),
    ],
  );
}

ThemeData buildSpendlyTheme(Brightness brightness) {
  final tokens = brightness == Brightness.dark
      ? SpendlyTokens.dark
      : SpendlyTokens.light;

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: tokens.accent,
        brightness: brightness,
      ).copyWith(
        surface: tokens.background,
        onSurface: tokens.ink,
        primary: tokens.accent,
        onPrimary: tokens.background,
        secondary: tokens.accentStrong,
        error: tokens.danger,
        outline: tokens.divider,
      );

  final textTheme = TextTheme(
    displayLarge: tokens.heading(40),
    displayMedium: tokens.heading(34),
    displaySmall: tokens.heading(30),
    headlineMedium: tokens.heading(25),
    headlineSmall: tokens.heading(21, weight: FontWeight.w600),
    titleLarge: tokens.heading(19, weight: FontWeight.w600),
    titleMedium: tokens.body(14.5),
    titleSmall: tokens.body(13.5),
    bodyLarge: tokens.body(15),
    bodyMedium: tokens.body(14),
    bodySmall: tokens.body(12.5, color: tokens.muted(0.6)),
    labelLarge: tokens.body(13),
    labelMedium: tokens.body(11.5, color: tokens.muted(0.52)),
    labelSmall: tokens.body(10.5, color: tokens.muted(0.52)),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    extensions: [tokens],
    scaffoldBackgroundColor: tokens.background,
    canvasColor: tokens.background,
    dividerColor: tokens.divider,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    iconTheme: IconThemeData(color: tokens.ink, size: 20),
    dividerTheme: DividerThemeData(
      color: tokens.divider,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: tokens.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: tokens.ink,
      toolbarHeight: 64,
      titleTextStyle: tokens.heading(18, weight: FontWeight.w600),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(color: tokens.divider),
      ),
      titleTextStyle: tokens.heading(20, weight: FontWeight.w600),
      contentTextStyle: tokens.body(13.5, color: tokens.muted(0.75)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.ink,
      contentTextStyle: tokens.body(13, color: tokens.background),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      hintStyle: tokens.body(14, color: tokens.muted(0.42)),
      labelStyle: tokens.body(12, color: tokens.muted(0.7)),
      floatingLabelStyle: tokens.body(12, color: tokens.accent),
      errorStyle: tokens.body(11.5, color: tokens.danger),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: tokens.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: tokens.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: tokens.accent),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: tokens.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: tokens.danger),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: tokens.accent,
      selectionColor: tokens.accent.withValues(alpha: 0.3),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.accent,
        textStyle: tokens.heading(13, weight: FontWeight.w600, height: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: tokens.accent,
      linearTrackColor: tokens.track,
      circularTrackColor: Colors.transparent,
      strokeWidth: 2,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: EdgeInsets.zero,
      iconColor: tokens.accent,
      titleTextStyle: tokens.body(14.5),
      subtitleTextStyle: tokens.body(11.5, color: tokens.muted(0.52)),
    ),
  );
}
