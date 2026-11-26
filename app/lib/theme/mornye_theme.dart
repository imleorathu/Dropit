import 'package:dropit_app/theme/app_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double kDefaultMornyeGlassClarity = 0.90;

double normalizeMornyeGlassClarity(num? value) => value != null && value.isFinite ? value.toDouble().clamp(0.0, 1.0) : kDefaultMornyeGlassClarity;

enum MornyeAccent { red, orange, green, teal, blue, purple, pink }

@immutable
class MornyeTheme extends ThemeExtension<MornyeTheme> {
  const MornyeTheme({
    this.chromeSurface,
    this.accent = MornyeAccent.blue,
    this.useSystemFont = false,
    this.fontFamily,
    this.glassClarity = kDefaultMornyeGlassClarity,
    this.glassOutlines = true,
  });

  final Color? chromeSurface;
  final MornyeAccent accent;
  final bool useSystemFont;
  final String? fontFamily;
  final double glassClarity;
  final bool glassOutlines;

  static double glassClarityOf(BuildContext context) => Theme.of(context).extension<MornyeTheme>()?.glassClarity ?? kDefaultMornyeGlassClarity;

  static bool glassOutlinesOf(BuildContext context) => Theme.of(context).extension<MornyeTheme>()?.glassOutlines ?? true;

  static Color controlFill(BuildContext context, {bool enabled = true}) {
    final theme = Theme.of(context);
    return theme.colorScheme.onSurface.withValues(
      alpha: !enabled
          ? 0.04
          : theme.brightness == Brightness.dark
          ? 0.10
          : 0.07,
    );
  }

  static Color metadataDividerColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.colorScheme.onSurface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.14 : 0.17,
    );
  }

  static double chromeOpacity(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.extension<MornyeTheme>()?.chromeSurface != null) return 0.36;
    return theme.brightness == Brightness.dark ? 0.60 : 0.70;
  }

  static double navigationOpacity(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.extension<MornyeTheme>()?.chromeSurface != null) return 0.24;
    return theme.brightness == Brightness.dark ? 0.36 : 0.49;
  }

  static const lightAccent = Color.fromRGBO(204, 46, 51, 1);
  static const darkAccent = Color.fromRGBO(255, 69, 58, 1);

  static Color accentColor(MornyeAccent accent, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final color = switch (accent) {
      MornyeAccent.red => const CupertinoDynamicColor.withBrightness(color: lightAccent, darkColor: darkAccent),
      MornyeAccent.orange => CupertinoColors.systemOrange,
      MornyeAccent.green => CupertinoColors.systemGreen,
      MornyeAccent.teal => CupertinoColors.systemTeal,
      MornyeAccent.blue => CupertinoColors.systemBlue,
      MornyeAccent.purple => CupertinoColors.systemPurple,
      MornyeAccent.pink => CupertinoColors.systemPink,
    };
    if (!dark && accent == MornyeAccent.green) return const Color(0xff24863d);
    if (!dark && accent == MornyeAccent.blue) return const Color(0xff0071e3);
    return dark ? color.darkColor : color.highContrastColor;
  }

  static MornyeAccent accentFromColor(Color color) {
    var closest = MornyeAccent.blue;
    var distance = double.infinity;
    for (final accent in MornyeAccent.values) {
      final candidate = accentColor(accent, Brightness.light);
      final dr = candidate.r - color.r;
      final dg = candidate.g - color.g;
      final db = candidate.b - color.b;
      final next = dr * dr + dg * dg + db * db;
      if (next < distance) {
        distance = next;
        closest = accent;
      }
    }
    return closest;
  }

  static final tokens = AppTokens.standard.copyWith(
    radiusBadge: 5,
    radiusThumb: 6,
    radiusCover: 10,
    radiusControl: 12,
    radiusCard: 12,
    radiusSheet: 32,
    coverMini: 38,
    headerExpandedTitleSize: 34,
    headerCollapsedTitleSize: 17,
    motionFast: const Duration(milliseconds: 180),
    motionMedium: const Duration(milliseconds: 220),
    motionSlow: const Duration(milliseconds: 380),
    rowPaddingH: 16,
    rowPaddingV: 10,
    rowPaddingVCompact: 8,
    rowIconGap: 12,
    rowIconDividerIndent: 52,
    rowChevronSize: 18,
    rowMinHeight: 28,
    trackRowPaddingV: 12,
    headerSubtitleSize: 20,
    lyricsLineHeight: 1.3,
    lyricsLinePaddingV: 16,
    playerControlGap: 12,
    dialogInsetH: 24,
  );

  static final _themeCache = <(TargetPlatform, Brightness, Color?, MornyeAccent, bool, String?, Color?), ThemeData>{};
  static final _glassVariants = Expando<ThemeData>();

  static ThemeData build(
    Brightness brightness, {
    Color? chromeSurface,
    MornyeAccent accent = MornyeAccent.blue,
    Color? accentOverride,
    bool useSystemFont = false,
    String? fontFamily,
    double glassClarity = kDefaultMornyeGlassClarity,
    bool glassOutlines = true,
  }) {
    final key = (
      defaultTargetPlatform,
      brightness,
      chromeSurface,
      accent,
      useSystemFont,
      fontFamily,
      accentOverride,
    );
    var theme = _themeCache.remove(key);
    theme ??= chromeSurface == null
        ? _build(
            brightness,
            selectedAccent: accent,
            accentOverride: accentOverride,
            useSystemFont: useSystemFont,
            fontFamily: fontFamily,
          )
        : _withChromeSurface(
            build(
              brightness,
              accent: accent,
              accentOverride: accentOverride,
              useSystemFont: useSystemFont,
              fontFamily: fontFamily,
            ),
            chromeSurface,
          );
    if (_themeCache.length >= 16) {
      _themeCache.remove(_themeCache.keys.first);
    }
    _themeCache[key] = theme;
    return _withGlassPreferences(theme, glassClarity, glassOutlines);
  }

  static ThemeData _withChromeSurface(ThemeData theme, Color chromeSurface) {
    final scheme = theme.colorScheme.copyWith(
      surfaceContainerHigh: Color.lerp(chromeSurface, Colors.black, 0.16),
    );
    return theme.copyWith(
      colorScheme: scheme,
      buttonTheme: theme.buttonTheme.copyWith(colorScheme: scheme),
      snackBarTheme: theme.snackBarTheme.copyWith(backgroundColor: scheme.surfaceContainerHigh),
      extensions: [
        for (final extension in theme.extensions.values)
          if (extension is MornyeTheme) extension.copyWith(chromeSurface: chromeSurface) else extension,
      ],
    );
  }

  static ThemeData _withGlassPreferences(ThemeData theme, double value, bool outlines) {
    final clarity = normalizeMornyeGlassClarity(value);
    bool matches(ThemeData? candidate) {
      final preferences = candidate?.extension<MornyeTheme>();
      return preferences?.glassClarity == clarity && preferences?.glassOutlines == outlines;
    }

    if (matches(theme)) return theme;
    final variant = _glassVariants[theme];
    if (matches(variant)) return variant!;
    return _glassVariants[theme] = theme.copyWith(
      extensions: [
        for (final extension in theme.extensions.values)
          if (extension is MornyeTheme) extension.copyWith(glassClarity: clarity, glassOutlines: outlines) else extension,
      ],
    );
  }

  static ThemeData fromContext(
    BuildContext context, {
    Brightness? brightness,
    Color? chromeSurface,
  }) {
    final theme = Theme.of(context);
    final preferences = theme.extension<MornyeTheme>();
    return build(
      brightness ?? theme.brightness,
      chromeSurface: chromeSurface,
      accent: preferences?.accent ?? MornyeAccent.blue,
      useSystemFont: preferences?.useSystemFont ?? false,
      fontFamily: preferences?.fontFamily,
      glassClarity: preferences?.glassClarity ?? kDefaultMornyeGlassClarity,
      glassOutlines: preferences?.glassOutlines ?? true,
    );
  }

  static ThemeData _build(
    Brightness brightness, {
    required MornyeAccent selectedAccent,
    Color? accentOverride,
    required bool useSystemFont,
    String? fontFamily,
  }) {
    final dark = brightness == Brightness.dark;
    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    final accent = accentOverride ?? accentColor(selectedAccent, brightness);
    final foreground = dark ? Colors.white : Colors.black;
    final surface = dark ? Colors.black : Colors.white;
    final grouped = dark ? const Color(0xff1c1c1e) : const Color(0xfff2f2f7);
    final secondaryOutline = dark ? const Color(0xffaeb0b8) : const Color(0xff3d3d44);
    final secondaryText = dark ? (isMacOS ? Colors.white : const Color(0xffaeb0b8)) : const Color(0xff3d3d44);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          onPrimary: accent.computeLuminance() < 0.179 ? Colors.white : Colors.black,
          primaryContainer: grouped,
          onPrimaryContainer: accent,
          secondary: accent,
          onSecondary: Colors.white,
          secondaryContainer: grouped,
          onSecondaryContainer: foreground,
          surface: surface,
          onSurface: foreground,
          surfaceContainerLowest: surface,
          surfaceContainerLow: grouped,
          surfaceContainer: grouped,
          surfaceContainerHigh: dark ? const Color(0xff2c2c2e) : grouped,
          surfaceContainerHighest: dark ? const Color(0xff3a3a3c) : const Color(0xffe5e5ea),
          onSurfaceVariant: secondaryText,
          outline: secondaryOutline,
          outlineVariant: dark ? const Color(0xff38383a) : const Color(0xffc6c6c8),
          surfaceTint: Colors.transparent,
        );
    final apple = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
    final type = CupertinoThemeData(brightness: brightness).textTheme;
    final text = type.textStyle.copyWith(
      inherit: true,
      color: foreground,
      fontFamily: fontFamily ?? (apple || useSystemFont ? type.textStyle.fontFamily : 'Inter'),
    );
    final display = type.navLargeTitleTextStyle.copyWith(
      inherit: true,
      color: foreground,
      fontFamily: fontFamily ?? (apple || useSystemFont ? type.navLargeTitleTextStyle.fontFamily : 'Inter'),
    );
    final typography = TextTheme(
      displayLarge: display.copyWith(fontSize: 57),
      displayMedium: display.copyWith(fontSize: 45),
      displaySmall: display.copyWith(fontSize: 36),
      headlineLarge: display,
      headlineMedium: display.copyWith(fontSize: 28, letterSpacing: 0.36),
      headlineSmall: display.copyWith(fontSize: 22, letterSpacing: 0.35),
      titleLarge: display.copyWith(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.38),
      titleMedium: text.copyWith(fontWeight: FontWeight.w500),
      titleSmall: text.copyWith(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.23),
      bodyLarge: text,
      bodyMedium: text.copyWith(fontSize: 15, letterSpacing: -0.23),
      bodySmall: text.copyWith(fontSize: 13, letterSpacing: -0.08, color: secondaryText),
      labelLarge: text.copyWith(fontWeight: FontWeight.w600),
      labelMedium: text.copyWith(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: -0.08),
      labelSmall: text.copyWith(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: -0.24, color: secondaryText),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      fontFamily: text.fontFamily,
      splashFactory: NoSplash.splashFactory,
      extensions: <ThemeExtension<dynamic>>[
        MornyeTheme(
          accent: selectedAccent,
          useSystemFont: useSystemFont,
          fontFamily: fontFamily,
        ),
        tokens,
      ],
    );
    final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return base.copyWith(
      textTheme: typography,
      primaryTextTheme: typography.apply(bodyColor: scheme.onPrimary, displayColor: scheme.onPrimary),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: accent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.copyWith(fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: grouped,
        elevation: 0,
        shape: controlShape,
      ),
      dividerTheme: DividerThemeData(
        color: dark ? const Color(0xff38383a) : const Color(0x2E000000),
        thickness: 0.5,
        space: 0.5,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: accent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: controlShape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: controlShape,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: controlShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: controlShape),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: grouped,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: grouped,
        surfaceTintColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 640),
        shape: tokens.sheetShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: grouped,
        shape: controlShape,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: text.copyWith(fontSize: 15, color: foreground),
        actionTextColor: accent,
        disabledActionTextColor: secondaryText,
        closeIconColor: foreground,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: grouped,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? const Color(0xff34c759) : (dark ? const Color(0xff39393d) : const Color(0xff8e8e93)),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: scheme.outline),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? accent : scheme.outline),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(999),
        thickness: const WidgetStatePropertyAll(6),
        thumbColor: WidgetStatePropertyAll(scheme.onSurfaceVariant.withValues(alpha: 0.28)),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: dark ? const Color(0xEB2C2C2E) : const Color(0xF7FFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .24 : .10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        textStyle: TextStyle(color: foreground, fontSize: 12.5, fontWeight: FontWeight.w500),
      ),
    );
  }

  @override
  MornyeTheme copyWith({
    Color? chromeSurface,
    MornyeAccent? accent,
    bool? useSystemFont,
    String? fontFamily,
    double? glassClarity,
    bool? glassOutlines,
  }) => MornyeTheme(
    chromeSurface: chromeSurface ?? this.chromeSurface,
    accent: accent ?? this.accent,
    useSystemFont: useSystemFont ?? this.useSystemFont,
    fontFamily: fontFamily ?? this.fontFamily,
    glassClarity: glassClarity ?? this.glassClarity,
    glassOutlines: glassOutlines ?? this.glassOutlines,
  );

  @override
  MornyeTheme lerp(covariant MornyeTheme? other, double t) => MornyeTheme(
    chromeSurface: Color.lerp(chromeSurface, other?.chromeSurface, t),
    accent: t < 0.5 ? accent : other?.accent ?? accent,
    fontFamily: t < 0.5 ? fontFamily : other?.fontFamily,
    useSystemFont: t < 0.5 ? useSystemFont : other?.useSystemFont ?? useSystemFont,
    glassClarity: glassClarity + ((other?.glassClarity ?? glassClarity) - glassClarity) * t,
    glassOutlines: t < 0.5 ? glassOutlines : other?.glassOutlines ?? glassOutlines,
  );

  @override
  bool operator ==(Object other) =>
      other is MornyeTheme &&
      other.chromeSurface == chromeSurface &&
      other.accent == accent &&
      other.useSystemFont == useSystemFont &&
      other.fontFamily == fontFamily &&
      other.glassClarity == glassClarity &&
      other.glassOutlines == glassOutlines;

  @override
  int get hashCode => Object.hash(chromeSurface, accent, useSystemFont, fontFamily, glassClarity, glassOutlines);
}

extension MornyeThemeContext on BuildContext {
  bool get isMornye => Theme.of(this).extension<MornyeTheme>() != null;
}

class MornyeSettingsTheme extends StatelessWidget {
  const MornyeSettingsTheme({super.key, required this.child});

  final Widget child;

  static final _themes = Expando<ThemeData>();

  @override
  Widget build(BuildContext context) {
    if (!context.isMornye) return child;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final background = dark ? Colors.black : const Color(0xfff2f2f7);
    final group = dark ? const Color(0xff1c1c1e) : Colors.white;
    return Theme(
      data: _themes[theme] ??= theme.copyWith(
        scaffoldBackgroundColor: background,
        extensions: [
          for (final extension in theme.extensions.values)
            if (extension is AppTokens) extension.copyWith(radiusCard: 24) else extension,
        ],
        colorScheme: theme.colorScheme.copyWith(
          surface: background,
          surfaceContainer: group,
        ),
        appBarTheme: theme.appBarTheme.copyWith(backgroundColor: background),
      ),
      child: ColoredBox(color: background, child: child),
    );
  }
}
