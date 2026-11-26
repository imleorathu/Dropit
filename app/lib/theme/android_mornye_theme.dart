import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Dedicated Mornye-inspired Liquid Glass layer exclusively on Android.
/// Never enabled on macOS, iOS, desktop targets, or Android browsers.
bool get usesAndroidMornye => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Android typography and layout helpers over the verified Mornye glass style.
/// Dropit's layout constraints, routing, and business logic remain unchanged.
abstract final class AndroidMornyeTheme {
  static const String fontFamily = 'Google Sans Flex';
  static const List<String> fontFallback = ['Inter'];
  static const List<FontVariation> _roundedVariations = [FontVariation('ROND', 100)];

  static ThemeData build(
    ThemeData existing, {
    required Color seed,
    ColorScheme? dynamicScheme,
    bool oled = false,
  }) {
    final brightness = existing.brightness;
    final dark = brightness == Brightness.dark;
    final isAmoled = oled && dark;

    var scheme = dynamicScheme ?? ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    if (isAmoled) {
      scheme = scheme.copyWith(
        surface: Colors.black,
        onSurface: Colors.white,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF111111),
        surfaceContainer: const Color(0xFF161616),
        surfaceContainerHigh: const Color(0xFF1F1F1F),
        surfaceContainerHighest: const Color(0xFF2A2A2A),
        inverseSurface: Colors.white,
        onInverseSurface: Colors.black,
      );
    }

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
    );
    final textTheme = _buildExpressiveTextTheme(base.textTheme, scheme);

    // Keep the Android type scale and existing layout metrics, while retaining
    // the Mornye palette/extension and glass settings from the shared base.
    return existing.copyWith(
      scaffoldBackgroundColor: isAmoled ? Colors.black : (dark ? const Color(0xFF080D1B) : const Color(0xFFF2F2F7)),
      textTheme: textTheme.apply(bodyColor: existing.colorScheme.onSurface, displayColor: existing.colorScheme.onSurface),
      appBarTheme: existing.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: existing.colorScheme.onSurface),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: CupertinoPageTransitionsBuilder()},
      ),
    );
  }

  static TextTheme _buildExpressiveTextTheme(TextTheme base, ColorScheme scheme) {
    TextStyle? withRounded(TextStyle? style) => style?.copyWith(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      fontVariations: _roundedVariations,
      color: scheme.onSurface,
    );

    TextStyle? withPlain(TextStyle? style) => style?.copyWith(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      color: scheme.onSurface,
    );

    return base.copyWith(
      displayLarge: withRounded(base.displayLarge),
      displayMedium: withRounded(base.displayMedium),
      displaySmall: withRounded(base.displaySmall),
      headlineLarge: withRounded(base.headlineLarge),
      headlineMedium: withRounded(base.headlineMedium),
      headlineSmall: withRounded(base.headlineSmall),
      titleLarge: withRounded(base.titleLarge),
      titleMedium: withRounded(base.titleMedium),
      titleSmall: withRounded(base.titleSmall),
      bodyLarge: withPlain(base.bodyLarge),
      bodyMedium: withPlain(base.bodyMedium),
      bodySmall: withPlain(base.bodySmall),
      labelLarge: withPlain(base.labelLarge),
      labelMedium: withPlain(base.labelMedium),
      labelSmall: withPlain(base.labelSmall),
    );
  }

  /// Tonal group surface matching Mornye's `settingsGroupColor(context)`.
  static Color groupSurfaceColor(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    if (theme.brightness == Brightness.dark) {
      return Color.alphaBlend(Colors.white.withValues(alpha: 0.08), surface);
    }
    return Color.alphaBlend(Colors.black.withValues(alpha: 0.04), surface);
  }

  /// Connected row corners matching Mornye's Expressive grouped rows:
  /// outer corners `20dp`, inner adjacent corners `4dp`.
  static BorderRadius connectedRadius({
    required int index,
    required int count,
    double outer = 20,
    double inner = 4,
  }) {
    if (count <= 1) return BorderRadius.circular(outer);
    final isFirst = index == 0;
    final isLast = index == count - 1;
    return BorderRadius.vertical(
      top: Radius.circular(isFirst ? outer : inner),
      bottom: Radius.circular(isLast ? outer : inner),
    );
  }

  /// Circular tonal back button matching Mornye's `AppSliverHeader`.
  static Widget backButton(BuildContext context, {VoidCallback? onPressed, String? tooltip}) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: tooltip ?? MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
      icon: const Icon(Symbols.arrow_back_rounded, size: 20),
    );
  }
}
