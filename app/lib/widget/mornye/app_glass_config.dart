import 'package:dropit_app/model/persistence/glass_quality.dart';
import 'package:dropit_app/theme/mornye_theme.dart';
import 'package:flutter/material.dart';

/// Resolved Liquid Glass configuration active for the current widget subtree.
@immutable
class AppGlassConfigData {
  const AppGlassConfigData({
    this.quality = AppGlassQuality.liquid,
    this.clarity = 0.90,
    this.glassFrost = 0.0,
    this.refractionIntensity = 1.50,
    this.dispersion = 1.32,
    this.deepEdgeTintEnabled = false,
    this.allGlassTintEnabled = false,
    this.deepEdgeTintColor = const Color(0xFF0A84FF),
    this.outlines = true,
    this.backgroundAnimation = true,
    this.reduceMotion = false,
    this.highContrast = false,
  });

  final AppGlassQuality quality;
  final double clarity;
  final double glassFrost;
  final double refractionIntensity;
  final double dispersion;
  final bool deepEdgeTintEnabled;
  final bool allGlassTintEnabled;
  final Color deepEdgeTintColor;
  final bool outlines;
  final bool backgroundAnimation;
  final bool reduceMotion;
  final bool highContrast;

  /// Effective rendering tier respecting accessibility high-contrast overrides.
  AppGlassQuality get effectiveQuality => highContrast ? AppGlassQuality.flat : quality;

  /// Whether floating spring/press/drift animations should play.
  bool get animateMotion => !reduceMotion;

  /// Whether atmospheric background motion should play.
  bool get animateBackground => backgroundAnimation && !reduceMotion;

  /// Runtime material changes retain every user/accessibility preference.
  AppGlassConfigData withQuality(AppGlassQuality quality) => AppGlassConfigData(
    quality: quality,
    clarity: clarity,
    glassFrost: glassFrost,
    refractionIntensity: refractionIntensity,
    dispersion: dispersion,
    deepEdgeTintEnabled: deepEdgeTintEnabled,
    allGlassTintEnabled: allGlassTintEnabled,
    deepEdgeTintColor: deepEdgeTintColor,
    outlines: outlines,
    backgroundAnimation: backgroundAnimation,
    reduceMotion: reduceMotion,
    highContrast: highContrast,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppGlassConfigData &&
          other.quality == quality &&
          other.clarity == clarity &&
          other.glassFrost == glassFrost &&
          other.refractionIntensity == refractionIntensity &&
          other.dispersion == dispersion &&
          other.deepEdgeTintEnabled == deepEdgeTintEnabled &&
          other.allGlassTintEnabled == allGlassTintEnabled &&
          other.deepEdgeTintColor == deepEdgeTintColor &&
          other.outlines == outlines &&
          other.backgroundAnimation == backgroundAnimation &&
          other.reduceMotion == reduceMotion &&
          other.highContrast == highContrast;

  @override
  int get hashCode => Object.hash(
    quality,
    clarity,
    glassFrost,
    refractionIntensity,
    dispersion,
    deepEdgeTintEnabled,
    allGlassTintEnabled,
    deepEdgeTintColor,
    outlines,
    backgroundAnimation,
    reduceMotion,
    highContrast,
  );
}

/// Propagates user and accessibility Liquid Glass preferences down the tree.
class AppGlassConfigScope extends InheritedWidget {
  const AppGlassConfigScope({
    required this.config,
    required super.child,
    super.key,
  });

  final AppGlassConfigData config;

  static AppGlassConfigData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppGlassConfigScope>()?.config;
  }

  static AppGlassConfigData of(BuildContext context) {
    final scoped = maybeOf(context);
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (scoped != null) {
      if (scoped.highContrast == highContrast && scoped.reduceMotion == disableAnimations) {
        return scoped;
      }
      return AppGlassConfigData(
        quality: scoped.quality,
        clarity: scoped.clarity,
        glassFrost: scoped.glassFrost,
        refractionIntensity: scoped.refractionIntensity,
        dispersion: scoped.dispersion,
        deepEdgeTintEnabled: scoped.deepEdgeTintEnabled,
        allGlassTintEnabled: scoped.allGlassTintEnabled,
        deepEdgeTintColor: scoped.deepEdgeTintColor,
        outlines: scoped.outlines,
        backgroundAnimation: scoped.backgroundAnimation,
        reduceMotion: scoped.reduceMotion || disableAnimations,
        highContrast: scoped.highContrast || highContrast,
      );
    }

    return AppGlassConfigData(
      quality: highContrast ? AppGlassQuality.flat : AppGlassQuality.liquid,
      clarity: MornyeTheme.glassClarityOf(context),
      outlines: MornyeTheme.glassOutlinesOf(context),
      reduceMotion: disableAnimations,
      highContrast: highContrast,
    );
  }

  @override
  bool updateShouldNotify(AppGlassConfigScope oldWidget) => config != oldWidget.config;
}
