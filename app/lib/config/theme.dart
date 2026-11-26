import 'package:dropit_app/model/persistence/color_mode.dart';
import 'package:dropit_app/provider/device_info_provider.dart';
import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/theme/mornye_theme.dart';
import 'package:dropit_app/util/native/platform_check.dart';
import 'package:dropit_app/util/ui/dynamic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:yaru/yaru.dart' as yaru;

final _borderRadius = BorderRadius.circular(16);

ThemeData getTheme(
  ColorMode colorMode,
  Color customColor,
  Brightness brightness,
  DynamicColors? dynamicColors, {
  double glassClarity = kDefaultMornyeGlassClarity,
  bool glassOutlines = true,
}) {
  final (accent, accentOverride) = _determineAccent(colorMode, customColor, brightness, dynamicColors);
  final base = MornyeTheme.build(
    brightness,
    accent: accent,
    accentOverride: accentOverride,
    glassClarity: glassClarity,
    glassOutlines: glassOutlines,
  );
  final colorScheme = base.colorScheme;
  final dark = brightness == Brightness.dark;
  final grouped = colorScheme.surfaceContainer;

  final styled = base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    cardColor: grouped.withValues(alpha: dark ? .32 : .44),
    dividerColor: colorScheme.outlineVariant,
    appBarTheme: base.appBarTheme.copyWith(backgroundColor: Colors.transparent),
    cardTheme: base.cardTheme.copyWith(
      color: grouped.withValues(alpha: dark ? .32 : .44),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: .5)),
      ),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: grouped.withValues(alpha: dark ? .72 : .84),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: .5)),
      ),
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: .18)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: colorScheme.primary.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(6),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: grouped.withValues(alpha: dark ? .82 : .90),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: .5)),
      ),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      backgroundColor: dark ? const Color(0xF21C1C1E) : const Color(0xF7FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      selectedColor: colorScheme.primary,
      selectedTileColor: colorScheme.primary.withValues(alpha: dark ? .16 : .09),
      iconColor: colorScheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, thickness: 1),
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh.withValues(alpha: .30),
      border: OutlineInputBorder(borderRadius: _borderRadius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: _borderRadius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: _borderRadius, borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: colorScheme.surfaceContainerHigh.withValues(alpha: .34),
        foregroundColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
  );
  if (!usesAndroidMornye) return styled;
  return AndroidMornyeTheme.build(
    styled,
    seed: accentOverride ?? MornyeTheme.accentColor(accent, brightness),
    dynamicScheme: colorMode == ColorMode.system ? (brightness == Brightness.light ? dynamicColors?.light : dynamicColors?.dark) : null,
    oled: colorMode == ColorMode.oled,
  );
}

Future<void> updateSystemOverlayStyle(BuildContext context) async {
  final brightness = Theme.of(context).brightness;
  await updateSystemOverlayStyleWithBrightness(brightness);
}

Future<void> updateSystemOverlayStyleWithBrightness(Brightness brightness) async {
  if (checkPlatform([TargetPlatform.android])) {
    // See https://github.com/flutter/flutter/issues/90098
    final darkMode = brightness == Brightness.dark;
    final androidSdkInt = RefenaScope.defaultRef.read(deviceInfoProvider).androidSdkInt ?? 0;
    final bool edgeToEdge = androidSdkInt >= 29;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // ignore: unawaited_futures

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.light ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: edgeToEdge ? Colors.transparent : (darkMode ? Colors.black : Colors.white),
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: darkMode ? Brightness.light : Brightness.dark,
      ),
    );
  } else {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: brightness, // iOS
        statusBarColor: Colors.transparent, // Not relevant to this issue
      ),
    );
  }
}

extension ThemeDataExt on ThemeData {
  /// This is the actual [cardColor] being used.
  Color get cardColorWithElevation {
    return ElevationOverlay.applySurfaceTint(cardColor, colorScheme.surfaceTint, 1);
  }
}

extension ColorSchemeExt on ColorScheme {
  Color get warning {
    return Colors.orange;
  }

  Color? get secondaryContainerIfDark {
    return brightness == Brightness.dark ? secondaryContainer : null;
  }

  Color? get onSecondaryContainerIfDark {
    return brightness == Brightness.dark ? onSecondaryContainer : null;
  }
}

extension InputDecorationThemeExt on InputDecorationThemeData {
  BorderRadius get borderRadius => _borderRadius;
}

(MornyeAccent, Color?) _determineAccent(
  ColorMode mode,
  Color customColor,
  Brightness brightness,
  DynamicColors? dynamicColors,
) {
  return switch (mode) {
    ColorMode.system => switch (brightness == Brightness.light ? dynamicColors?.light : dynamicColors?.dark) {
      final scheme? => (MornyeTheme.accentFromColor(scheme.primary), scheme.primary),
      null => (MornyeAccent.blue, null),
    },
    ColorMode.dropit => (MornyeAccent.blue, null),
    ColorMode.oled => (MornyeAccent.blue, null),
    ColorMode.yaru => (
      MornyeTheme.accentFromColor(brightness == Brightness.light ? yaru.yaruLight.colorScheme.primary : yaru.yaruDark.colorScheme.primary),
      brightness == Brightness.light ? yaru.yaruLight.colorScheme.primary : yaru.yaruDark.colorScheme.primary,
    ),
    ColorMode.custom => (MornyeTheme.accentFromColor(customColor), customColor),
  };
}
