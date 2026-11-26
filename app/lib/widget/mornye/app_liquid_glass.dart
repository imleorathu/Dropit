import 'dart:ui';

import 'package:dropit_app/model/persistence/glass_quality.dart';
import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/widget/mornye/android_mornye_widgets.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_press.dart';
import 'package:dropit_app/widget/mornye/app_liquid_backdrop.dart';
import 'package:dropit_app/widget/mornye/dropit_chromatic_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:dropit_app/widget/mornye/macos_native_glass.dart';
import 'package:dropit_app/widget/mornye/mornye_squircle_border.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

export 'package:dropit_app/model/persistence/glass_quality.dart' show AppGlassQuality;

/// Quantized Mornye blur steps matching GPU shader cache buckets.
/// Liquid lenses keep low blur (0.6-2.2) so refracted background geometry
/// remains sharp, while frosted and modal surfaces use stronger diffusion.
const List<double> _kMornyeBlurLevels = [0.6, 1.4, 2.2, 10.0];
final List<ImageFilter> _kMornyeBlurs = [
  for (final sigma in _kMornyeBlurLevels) ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
];

const List<double> _kLiquidFrostBlurLevels = [2.4, 4.2, 6.2, 8.4, 10.5, 12.5];
final List<ImageFilter> _kLiquidFrostBlurs = [
  for (final sigma in _kLiquidFrostBlurLevels) ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
];

/// Core Liquid Glass container used across Dropit.
///
/// Renders according to [AppGlassQuality]:
/// - [AppGlassQuality.liquid]: GPU shader optical refraction + RGB dispersion +
///   dynamic specular/glow rim (`AppLiquidBackdrop`).
/// - [AppGlassQuality.frosted]: Quantized `BackdropFilter` frost + Mornye tint
///   + painted hairline specular border.
/// - [AppGlassQuality.flat]: High-contrast / zero-blur solid surface.
class AppLiquidGlass extends StatelessWidget {
  const AppLiquidGlass({
    required this.child,
    this.radius = 32,
    this.clarity,
    this.strongTint = false,
    this.tintOpacity,
    this.tintColor,
    this.blurEnabled = true,
    this.samplesBackdrop = true,
    this.quality,
    this.firstInGroup = true,
    this.lastInGroup = true,
    this.highlightBorder = false,
    this.refractionDepth = 0.42,
    this.dispersion,
    this.smoothCorners = false,
    this.highlightIntensity = 1,
    this.glassProgress = 1,
    this.outlines,
    this.touch,
    this.shadow,
    this.nativeId,
    this.nativeMaterial = MacosNativeGlassMaterial.hud,
    this.nativeClear = false,
    this.nativeInteractive = false,
    this.nativeModalOverlay = false,
    this.preset = DropitOpticalPreset.panel,
    this.focused = false,
    this.focusColor,
    super.key,
  });

  final Widget child;
  final double radius;
  final double? clarity;
  final bool strongTint;
  final double? tintOpacity;
  final Color? tintColor;
  final bool blurEnabled;
  final bool samplesBackdrop;
  final AppGlassQuality? quality;
  final bool firstInGroup;
  final bool lastInGroup;
  final bool highlightBorder;
  final double refractionDepth;
  final double? dispersion;
  final bool smoothCorners;
  final double highlightIntensity;
  final double glassProgress;
  final bool? outlines;
  final LiquidGlassTouch? touch;
  final LiquidGlassShadow? shadow;
  final String? nativeId;
  final MacosNativeGlassMaterial nativeMaterial;
  final bool nativeClear;
  final bool nativeInteractive;
  final bool nativeModalOverlay;
  final DropitOpticalPreset preset;
  final bool focused;
  final Color? focusColor;

  /// Widget tests cannot initialize a platform shader backend. Production
  /// leaves this null and follows Flutter's real renderer capability.
  @visibleForTesting
  static bool? debugShaderFilterSupport;

  /// Effective runtime check for Impeller backdrop `ImageFilter.shader` support.
  static bool get isShaderFilterSupported => debugShaderFilterSupport ?? ImageFilter.isShaderFilterSupported;

  @override
  Widget build(BuildContext context) {
    if (usesAndroidMornye) {
      final modal = preset == DropitOpticalPreset.modalSheet || nativeModalOverlay;
      final control = preset == DropitOpticalPreset.capsuleButton || preset == DropitOpticalPreset.searchField;
      final navigation = preset == DropitOpticalPreset.segmented || preset == DropitOpticalPreset.sidebar || preset == DropitOpticalPreset.toolbar;
      return AndroidMornyeSurface(
        radius: radius,
        tintColor: tintColor,
        tintOpacity: tintOpacity,
        firstInGroup: firstInGroup,
        lastInGroup: lastInGroup,
        focused: focused || highlightBorder,
        focusColor: focusColor,
        modal: modal,
        control: control,
        navigation: navigation,
        samplesBackdrop: samplesBackdrop,
        blurEnabled: blurEnabled,
        clarity: clarity,
        quality: quality,
        preset: preset,
        refractionDepth: refractionDepth,
        dispersion: dispersion,
        outlines: outlines,
        child: child,
      );
    }
    final config = AppGlassConfigScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final deepEdgeSurface = switch (preset) {
      DropitOpticalPreset.sidebar ||
      DropitOpticalPreset.dropZone ||
      DropitOpticalPreset.panel ||
      DropitOpticalPreset.modalSheet ||
      DropitOpticalPreset.deviceCard => true,
      _ => false,
    };
    final applyConfigTint = config.allGlassTintEnabled || (config.deepEdgeTintEnabled && deepEdgeSurface);
    final effectiveTintColor = tintColor ?? (applyConfigTint ? config.deepEdgeTintColor : null);
    final effectiveTintOpacity = (applyConfigTint && tintColor == null && tintOpacity != null && tintOpacity! < 0.28) ? 0.28 : tintOpacity;

    final resolvedQuality = config.highContrast ? AppGlassQuality.flat : (quality ?? config.effectiveQuality);
    final glassClarity = (clarity ?? config.clarity).clamp(0.0, 1.0);
    final showOutlines = outlines ?? config.outlines;
    final progress = glassProgress.clamp(0.0, 1.0);
    final hasAncestorNativeGlass = MacosNativeGlassBackdropScope.isInside(context);
    final nativeGlassHost = MacosNativeGlass.isSupported;
    final attachNativeSurface =
        nativeGlassHost && !hasAncestorNativeGlass && samplesBackdrop && blurEnabled && resolvedQuality != AppGlassQuality.flat && progress > 0;
    final nativeDesktopBackdrop = hasAncestorNativeGlass || attachNativeSurface;

    final borderRadius = BorderRadius.circular(radius);

    final translucent = progress > 0 && resolvedQuality != AppGlassQuality.flat && (glassClarity > 0 || !blurEnabled);
    var tint = scheme.surfaceContainerHigh;
    if (translucent) {
      final tintSource = effectiveTintColor ?? (dark ? scheme.surfaceContainerHigh : Colors.white);
      final opacity = effectiveTintOpacity ?? (strongTint ? 0.80 : 0.60);
      var baseTint = tintSource.withValues(
        alpha: !blurEnabled ? opacity.clamp(0.05, 0.95) : (dark ? opacity * 0.82 : (opacity * 0.88).clamp(0.50, 1.0)),
      );
      if (dark && blurEnabled) {
        baseTint = Color.alphaBlend(baseTint, Colors.black.withValues(alpha: 0.35));
      }
      final tintStrength = !blurEnabled ? 0.0 : (1 - glassClarity) * (1 - glassClarity);
      tint = Color.alphaBlend(
        scheme.surfaceContainerHigh.withValues(alpha: tintStrength),
        baseTint,
      );
    }

    final liquidFrost = resolvedQuality == AppGlassQuality.liquid ? config.glassFrost.clamp(0.0, 1.0) : 0.0;
    final insideGlass = context.dependOnInheritedWidgetOfExactType<_GlassBackdropScope>() != null;
    // Android Impeller can run the optical lens: sibling lenses share one
    // backdrop read through the root batch, while glass stacked on glass keeps
    // its own read. Hardware without shader-filter support falls back to the
    // grouped backdrop blur below instead of flattening the surface.
    final blurThreshold = resolvedQuality == AppGlassQuality.frosted ? 0.5 : 0.2;
    final frostFlutterBackdrop = liquidFrost > 0.01 && !insideGlass;
    final sampleBackdrop =
        translucent &&
        samplesBackdrop &&
        !insideGlass &&
        (!nativeDesktopBackdrop || nativeModalOverlay || frostFlutterBackdrop) &&
        (glassClarity > blurThreshold || frostFlutterBackdrop);
    final useLens =
        sampleBackdrop &&
        !nativeDesktopBackdrop &&
        firstInGroup &&
        lastInGroup &&
        resolvedQuality == AppGlassQuality.liquid &&
        isShaderFilterSupported;
    final filterIndex = resolvedQuality == AppGlassQuality.frosted
        ? 2
        : glassClarity >= 0.85
        ? 0
        : glassClarity >= 0.55
        ? 1
        : 2;
    final useClearNative =
        liquidFrost < 0.25 &&
        (nativeClear ||
            (resolvedQuality == AppGlassQuality.liquid &&
                !nativeModalOverlay &&
                (nativeMaterial != MacosNativeGlassMaterial.sidebar || glassClarity >= 0.98) &&
                glassClarity >= 0.45));
    final clearFill = (dark ? const Color(0xFF8C9BB8) : Colors.white).withValues(alpha: dark ? 0.11 : 0.28);
    var surfaceColor = resolvedQuality == AppGlassQuality.flat
        ? scheme.surfaceContainerHigh.withValues(alpha: (config.highContrast ? 0.96 : 0.92) * progress)
        : Color.lerp(
            scheme.surfaceContainerHigh,
            useLens && !strongTint ? Color.lerp(tint, clearFill, ((glassClarity - 0.2) / 0.8).clamp(0, 1)) : tint,
            progress,
          )!;
    if (resolvedQuality == AppGlassQuality.liquid && liquidFrost > 0.0 && !nativeDesktopBackdrop && !strongTint) {
      final frostTint = effectiveTintColor ?? (dark ? scheme.surfaceContainerHigh : Colors.white);
      surfaceColor = Color.alphaBlend(
        frostTint.withValues(alpha: lerpDouble(0.0, dark ? 0.26 : 0.34, liquidFrost)! * progress),
        surfaceColor,
      );
    }
    if (nativeDesktopBackdrop && resolvedQuality != AppGlassQuality.flat) {
      if (nativeModalOverlay) {
        // Modal dialogs & sheets sit above sibling Flutter UI inside the same
        // Metal layer; pair Flutter BackdropFilter blur with an elevated tint
        // so underlying route text never bleeds unreadably through the modal.
        final nativeTint = effectiveTintColor ?? (dark ? scheme.surfaceContainerHigh : Colors.white);
        surfaceColor = nativeTint.withValues(
          alpha: ((dark ? 0.68 : 0.78) * progress).clamp(0.0, 0.92),
        );
      } else {
        // AppKit NSGlassEffectView renders optical lens distortion behind this
        // subtree. Clear optical lenses keep Flutter's overlay veil minimal so
        // real refraction stays crisp while dark/light contrast remains intact,
        // and drop the surface veil to full transparency at 100% clarity.
        final clearLensMode = useClearNative && resolvedQuality == AppGlassQuality.liquid;
        final crystalScale = (resolvedQuality == AppGlassQuality.liquid && effectiveTintColor == null)
            ? DropitGlassQualityController.crystalClarityScale(glassClarity)
            : 1.0;
        final baseAlpha = DropitGlassQualityController.surfaceTintAlpha(
          brightness: theme.brightness,
          clarity: glassClarity,
          quality: resolvedQuality,
          preset: preset,
          nativeClear: clearLensMode,
          liquidFrost: liquidFrost,
          hasExplicitTint: effectiveTintColor != null,
        );
        final strongBump = strongTint ? (clearLensMode ? 0.045 : 0.065) * crystalScale : 0.0;
        final frostedBump = resolvedQuality == AppGlassQuality.frosted ? 0.10 : 0.0;
        final nestedBump = insideGlass ? (clearLensMode ? 0.065 : 0.085) * crystalScale : 0.0;
        final minAlpha = (effectiveTintColor != null || liquidFrost > 0.01)
            ? (clearLensMode ? 0.03 : 0.06)
            : ((clearLensMode ? 0.03 : 0.06) * crystalScale);
        final nativeTint = effectiveTintColor ?? (dark ? scheme.surfaceContainerHigh : Colors.white);
        surfaceColor = nativeTint.withValues(
          alpha: ((baseAlpha + strongBump + frostedBump + nestedBump) * progress).clamp(
            minAlpha,
            clearLensMode ? lerpDouble(0.38, 0.52, liquidFrost)! : lerpDouble(0.68, 0.78, liquidFrost)!,
          ),
        );
      }
    }

    final surfaceDecorated = DecoratedBox(
      key: const ValueKey('app-liquid-glass-surface'),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: borderRadius,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: _GlassBackdropScope(child: child),
      ),
    );

    if (resolvedQuality == AppGlassQuality.flat) {
      return _wrapBorderAndShadow(
        context: context,
        radius: radius,
        dark: dark,
        scheme: scheme,
        showOutlines: showOutlines || config.highContrast,
        highlightBorder: highlightBorder,
        smoothCorners: smoothCorners,
        highlightIntensity: highlightIntensity,
        highContrast: config.highContrast,
        suppressOuterShadow: insideGlass || nativeDesktopBackdrop,
        child: _clipShape(radius: radius, smoothCorners: smoothCorners, child: surfaceDecorated),
      );
    }

    final quantizedBlur = _kMornyeBlurLevels[filterIndex];
    final liquidBlurSigma = resolvedQuality == AppGlassQuality.liquid && liquidFrost > 0.0
        ? lerpDouble(quantizedBlur, 12.5, liquidFrost)!
        : quantizedBlur;
    final frostFilterIndex = (liquidFrost * (_kLiquidFrostBlurs.length - 1)).round().clamp(0, _kLiquidFrostBlurs.length - 1);
    final effectiveBlur = nativeModalOverlay
        ? _kMornyeBlurs[3]
        : (resolvedQuality == AppGlassQuality.liquid && liquidFrost > 0.01 ? _kLiquidFrostBlurs[frostFilterIndex] : _kMornyeBlurs[filterIndex]);

    if (resolvedQuality == AppGlassQuality.frosted) {
      final Widget blurred = sampleBackdrop
          ? (nativeModalOverlay
                ? BackdropFilter(filter: effectiveBlur, child: surfaceDecorated)
                : BackdropFilter.grouped(filter: effectiveBlur, child: surfaceDecorated))
          : surfaceDecorated;
      final frostedWidget = _wrapBorderAndShadow(
        context: context,
        radius: radius,
        dark: dark,
        scheme: scheme,
        showOutlines: showOutlines,
        highlightBorder: highlightBorder,
        smoothCorners: smoothCorners,
        highlightIntensity: highlightIntensity,
        highContrast: false,
        suppressOuterShadow: insideGlass || nativeDesktopBackdrop,
        child: _clipShape(radius: radius, smoothCorners: smoothCorners, child: blurred),
      );
      return attachNativeSurface
          ? MacosNativeGlassSurface(
              id: nativeId,
              material: nativeMaterial,
              radius: radius,
              clear: false,
              tintColor: _resolveNativeTint(
                tint: effectiveTintColor,
                opacityOverride: effectiveTintOpacity,
                suppressLowOpacity: false,
              ),
              child: frostedWidget,
            )
          : frostedWidget;
    }

    // AppGlassQuality.liquid: Real-time optical GPU lens with refraction, RGB
    // dispersion, magnification, and dynamic specular/glow edge pickup, or
    // AppKit NSGlassEffectView + NSVisualEffectView when backed by the desktop.
    final spec = DropitOpticalGlassSpec.resolve(
      config: config,
      preset: preset,
      clarityOverride: glassClarity,
      radiusOverride: radius,
      refractionDepthOverride: refractionDepth,
    );
    final chromaticDispersion = spec.resolvedChromaticDispersion(
      config,
      dispersionOverride: dispersion,
    );
    final enableFlutterChromatic =
        sampleBackdrop &&
        !insideGlass &&
        chromaticDispersion > 0.005 &&
        resolvedQuality == AppGlassQuality.liquid &&
        isShaderFilterSupported &&
        (!nativeDesktopBackdrop ||
            nativeModalOverlay ||
            preset == DropitOpticalPreset.toolbar ||
            preset == DropitOpticalPreset.capsuleButton ||
            preset == DropitOpticalPreset.segmented ||
            preset == DropitOpticalPreset.searchField ||
            preset == DropitOpticalPreset.dropZone);

    final lens = useLens
        ? AppLiquidBackdrop(
            borderRadius: borderRadius,
            clarity: glassClarity,
            blurSigma: samplesBackdrop && blurEnabled ? liquidBlurSigma : 0.0,
            refractionDepth: refractionDepth,
            dispersion: dispersion,
            smoothCorners: smoothCorners,
            highlightIntensity: highlightIntensity,
            outlines: showOutlines,
            tintColor: Colors.transparent,
            touch: touch,
            shadow: shadow,
            preset: preset,
            child: surfaceDecorated,
          )
        : null;
    final Widget chromaticBase = (lens == null && enableFlutterChromatic)
        ? DropitChromaticGlass(
            radius: radius,
            dispersion: chromaticDispersion,
            refractionWidth: spec.refractionWidth,
            refractionIndex: 1.48 + refractionDepth.clamp(0.0, 1.0) * 0.25,
            magnification: spec.magnification,
            curvatureExponent: spec.profile.curvatureExponent,
            blurSigma: liquidFrost > 0.05 ? liquidBlurSigma * 0.45 : 0.0,
            enabled: true,
            child: surfaceDecorated,
          )
        : surfaceDecorated;
    final backdrop = lens == null
        ? (sampleBackdrop
              ? (nativeModalOverlay
                    ? BackdropFilter(filter: effectiveBlur, child: chromaticBase)
                    : BackdropFilter.grouped(filter: effectiveBlur, child: chromaticBase))
              : chromaticBase)
        : (LiquidGlassBatch.backdropIdOf(context) == null ? LiquidGlassBatch(child: lens) : lens);

    final wrapped = _wrapBorderAndShadow(
      context: context,
      radius: radius,
      dark: dark,
      scheme: scheme,
      // LiquidGlassLens already renders optical specular & glow rims when outlines
      // are enabled; only paint an extra vector rim for explicit selection highlights.
      showOutlines: showOutlines && (!useLens || highlightBorder),
      highlightBorder: highlightBorder,
      smoothCorners: smoothCorners,
      highlightIntensity: highlightIntensity,
      highContrast: false,
      focused: focused,
      focusColor: focusColor ?? scheme.primary,
      interaction: AppGlassPress.maybeOf(context)?.progress,
      suppressOuterShadow: insideGlass || nativeDesktopBackdrop,
      child: _clipShape(radius: radius, smoothCorners: smoothCorners, child: backdrop),
    );
    return attachNativeSurface
        ? MacosNativeGlassSurface(
            id: nativeId,
            material: nativeMaterial,
            radius: radius,
            clear: useClearNative,
            interactive: nativeInteractive,
            tintColor: _resolveNativeTint(
              tint: effectiveTintColor,
              opacityOverride: effectiveTintOpacity,
              suppressLowOpacity: tintColor != null,
            ),
            child: wrapped,
          )
        : wrapped;
  }

  /// Attenuates custom tint colors before handing them to AppKit
  /// `NSGlassEffectView` so clear/tinted buttons never become opaque overlays.
  Color? _resolveNativeTint({
    required Color? tint,
    required double? opacityOverride,
    required bool suppressLowOpacity,
  }) {
    if (tint == null) return null;
    if (suppressLowOpacity && !strongTint && opacityOverride != null && opacityOverride <= 0.16) {
      return null;
    }
    final factor = (opacityOverride ?? (strongTint ? 0.72 : 0.28)).clamp(0.0, 0.80);
    return tint.withValues(alpha: (tint.a * factor).clamp(0.0, 0.80));
  }

  Widget _clipShape({
    required double radius,
    required bool smoothCorners,
    required Widget child,
  }) {
    if (radius <= 0) return child;
    if (smoothCorners) {
      return ClipPath(
        clipper: ShapeBorderClipper(
          shape: MornyeSquircleBorder(radius),
        ),
        child: child,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }

  Widget _wrapBorderAndShadow({
    required BuildContext context,
    required double radius,
    required bool dark,
    required ColorScheme scheme,
    required bool showOutlines,
    required bool highlightBorder,
    required bool smoothCorners,
    required double highlightIntensity,
    required bool highContrast,
    bool focused = false,
    Color? focusColor,
    ValueListenable<double>? interaction,
    bool suppressOuterShadow = false,
    required Widget child,
  }) {
    final depthShadow = suppressOuterShadow
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.14 : 0.08),
              blurRadius: 8,
              blurStyle: BlurStyle.outer,
              offset: const Offset(0, 2),
            ),
          ];

    final shapeBorder = radius <= 0
        ? const RoundedRectangleBorder()
        : (smoothCorners ? MornyeSquircleBorder(radius) : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)));

    final shadowed = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shapeBorder,
        shadows: depthShadow,
      ),
      child: child,
    );

    if (!showOutlines && !focused) {
      return shadowed;
    }

    final spec = DropitOpticalGlassSpec.resolve(
      config: AppGlassConfigScope.of(context),
      preset: preset,
      clarityOverride: clarity,
      radiusOverride: radius,
    );

    return CustomPaint(
      foregroundPainter: _AppGlassRimPainter(
        radius: radius,
        smoothCorners: smoothCorners,
        dark: dark,
        accent: highlightBorder ? scheme.primary : null,
        intensity: highlightIntensity,
        refractionIntensity: spec.refractionIntensity,
        clarity: spec.clarity,
        edgeThickness: spec.edgeThickness,
        highContrast: highContrast,
        outlineColor: scheme.outlineVariant,
        focused: focused,
        focusColor: focusColor,
        interaction: interaction,
      ),
      child: shadowed,
    );
  }
}

/// Marks descendants that already sit inside a sampled glass surface.
/// Nested controls keep their tint and interaction but never re-read the same
/// backdrop, avoiding stacked blur/refraction and costly offscreen passes.
class _GlassBackdropScope extends InheritedWidget {
  const _GlassBackdropScope({required super.child});

  @override
  bool updateShouldNotify(_GlassBackdropScope oldWidget) => false;
}

class _AppGlassRimPainter extends CustomPainter {
  const _AppGlassRimPainter({
    required this.radius,
    required this.smoothCorners,
    required this.dark,
    required this.accent,
    required this.intensity,
    required this.refractionIntensity,
    required this.clarity,
    required this.edgeThickness,
    required this.highContrast,
    required this.outlineColor,
    this.focused = false,
    this.focusColor,
    this.interaction,
  }) : super(repaint: interaction);

  final double radius;
  final bool smoothCorners;
  final bool dark;
  final Color? accent;
  final double intensity;
  final double refractionIntensity;
  final double clarity;
  final double edgeThickness;
  final bool highContrast;
  final Color outlineColor;
  final bool focused;
  final Color? focusColor;
  final ValueListenable<double>? interaction;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final path = radius <= 0
        ? (Path()..addRect(rect))
        : (smoothCorners ? liquidGlassSquirclePath(size, radius, 1) : (Path()..addRRect(BorderRadius.circular(radius).toRRect(rect))));
    final interact = (interaction?.value ?? 0.0).clamp(0.0, 1.0);
    final activeIntensity = intensity + interact * 0.42;

    if (highContrast) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = focused ? 2.0 : 1.6
          ..color = focused && focusColor != null ? focusColor! : (accent ?? outlineColor.withValues(alpha: 0.72)),
      );
      return;
    }

    if (accent != null && !focused) {
      final topAlpha = (0.58 * activeIntensity).clamp(0.0, 0.92);
      final bottomAlpha = (0.36 * activeIntensity).clamp(0.0, 0.62);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.15
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.48, 1.0],
            colors: [
              Color.lerp(Colors.white, accent!, 0.45)!.withValues(alpha: topAlpha),
              Colors.white.withValues(alpha: (0.16 * activeIntensity).clamp(0.0, 0.45)),
              accent!.withValues(alpha: bottomAlpha),
            ],
          ).createShader(rect),
      );
      return;
    }

    DropitGlassHighlight(
      radius: radius <= 0 ? 0.0 : radius,
      brightness: dark ? Brightness.dark : Brightness.light,
      refractionIntensity: refractionIntensity,
      clarity: clarity,
      edgeThickness: edgeThickness,
      emphasis: activeIntensity,
      smoothCorners: smoothCorners,
      focused: focused,
      focusColor: focusColor,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_AppGlassRimPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.smoothCorners != smoothCorners ||
      oldDelegate.dark != dark ||
      oldDelegate.accent != accent ||
      oldDelegate.intensity != intensity ||
      oldDelegate.refractionIntensity != refractionIntensity ||
      oldDelegate.clarity != clarity ||
      oldDelegate.edgeThickness != edgeThickness ||
      oldDelegate.highContrast != highContrast ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.focused != focused ||
      oldDelegate.focusColor != focusColor ||
      oldDelegate.interaction != interaction;
}

typedef DropitOpticalGlass = AppLiquidGlass;
