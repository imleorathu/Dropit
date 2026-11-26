import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:dropit_app/model/persistence/glass_quality.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Optical role presets mapping Dropit components to physically coherent
/// glass wall thickness, refraction curvature, dispersion, and highlight polish.
enum DropitOpticalPreset {
  sidebar,
  toolbar,
  dropZone,
  capsuleButton,
  searchField,
  segmented,
  deviceCard,
  modalSheet,
  panel,
}

/// Shared spring physics used across interactive glass capsules and sliding
/// selection indicators.
const SpringDescription kDropitOpticalSpring = SpringDescription(
  mass: 1.0,
  stiffness: 420.0,
  damping: 24.0,
);

const SpringDescription kDropitSelectionGlideSpring = SpringDescription(
  mass: 1.0,
  stiffness: 460.0,
  damping: 28.0,
);

/// Default glass clarity (`90%`) and refraction intensity (`150%`, range `0%..200%`).
const double kDefaultOpticalClarity = 0.90;
const double kDefaultOpticalRefraction = 1.50;
const double kMaxOpticalRefraction = 2.0;

/// Unified three-tier optical lens profiles:
/// - [convexButton] (Profile A): capsule buttons (`File`, `Folder`, `Text`, `Paste`)
/// - [deepEdgePanel] (Profile B): dropZone, sidebar, cards, panels, modals
/// - [thickCapsule] (Profile C): toolbar, search field, segmented switcher
enum OpticalLensTier {
  convexButton,
  deepEdgePanel,
  thickCapsule,
}

/// Coherent analytical optical lens model unifying SDF geometry, convex
/// surface height, continuous 2D/3D normals, edge curvature, inverse-UV
/// center magnification, Snell-inspired sidewall refraction, chromatic
/// dispersion gating, and directional specular/glow weighting.
@immutable
class OpticalLensProfile {
  const OpticalLensProfile({
    required this.tier,
    required this.magnification,
    required this.refractionStrengthMultiplier,
    required this.edgeWidth,
    required this.curvatureExponent,
    required this.maxRefractionIndex,
  });

  final OpticalLensTier tier;
  final double magnification;
  final double refractionStrengthMultiplier;
  final double edgeWidth;
  final double curvatureExponent;
  final double maxRefractionIndex;

  /// Profile A — Convex Lens (`File`, `Folder`, `Text`, `Paste`, capsule pills).
  static const OpticalLensProfile profileA = OpticalLensProfile(
    tier: OpticalLensTier.convexButton,
    magnification: 1.12,
    refractionStrengthMultiplier: 1.6,
    edgeWidth: 18.0,
    curvatureExponent: 2.0,
    maxRefractionIndex: 1.94,
  );

  /// Profile B — Deep Edge Lens (`sidebar`, `dropZone`, `panel`, `modalSheet`, `deviceCard`).
  static const OpticalLensProfile profileB = OpticalLensProfile(
    tier: OpticalLensTier.deepEdgePanel,
    magnification: 1.08,
    refractionStrengthMultiplier: 2.65,
    edgeWidth: 34.0,
    curvatureExponent: 2.15,
    maxRefractionIndex: 2.28,
  );

  /// Profile B variant for subtle compact cards inside scrollable lists.
  static const OpticalLensProfile profileBCard = OpticalLensProfile(
    tier: OpticalLensTier.deepEdgePanel,
    magnification: 1.06,
    refractionStrengthMultiplier: 2.40,
    edgeWidth: 32.0,
    curvatureExponent: 2.15,
    maxRefractionIndex: 2.20,
  );

  /// Profile C — Thick Capsule Lens (`toolbar`, `searchField`, `segmented`).
  static const OpticalLensProfile profileC = OpticalLensProfile(
    tier: OpticalLensTier.thickCapsule,
    magnification: 1.18,
    refractionStrengthMultiplier: 2.2,
    edgeWidth: 22.0,
    curvatureExponent: 2.2,
    maxRefractionIndex: 2.24,
  );

  factory OpticalLensProfile.forPreset(DropitOpticalPreset preset) => switch (preset) {
    DropitOpticalPreset.capsuleButton => profileA,
    DropitOpticalPreset.deviceCard => profileBCard,
    DropitOpticalPreset.sidebar || DropitOpticalPreset.dropZone || DropitOpticalPreset.panel || DropitOpticalPreset.modalSheet => profileB,
    DropitOpticalPreset.toolbar || DropitOpticalPreset.searchField || DropitOpticalPreset.segmented => profileC,
  };

  /// Rounded-rectangle signed distance (`sdRoundRect`).
  /// Returns negative inside the shape, `0` on the rim, and positive outside.
  static double signedDistanceRect({
    required Offset point,
    required Size size,
    required double radius,
  }) {
    final halfW = size.width * 0.5;
    final halfH = size.height * 0.5;
    final clampedR = radius.clamp(0.0, math.min(halfW, halfH));
    final dx = (point.dx - halfW).abs() - (halfW - clampedR);
    final dy = (point.dy - halfH).abs() - (halfH - clampedR);
    final qx = math.max(dx, 0.0);
    final qy = math.max(dy, 0.0);
    final outside = math.sqrt(qx * qx + qy * qy);
    final inside = math.min(math.max(dx, dy), 0.0);
    return outside + inside - clampedR;
  }

  /// Normalized convex glass thickness height in `[0, 1]`.
  /// Plateau (`1.0`) across the lens interior, curving smoothly down to `0.0`
  /// at the perimeter (`distanceInside == 0`).
  double surfaceHeight({
    required double distanceInside,
    double? edgeWidthOverride,
  }) {
    final ew = math.max(1.0, edgeWidthOverride ?? edgeWidth);
    if (distanceInside <= 0.0) return 0.0;
    if (distanceInside >= ew) return 1.0;
    final s = 1.0 - (distanceInside / ew);
    final radialTerm = math.pow(s, curvatureExponent).toDouble();
    return math.pow((1.0 - radialTerm).clamp(0.0, 1.0), 1.0 / curvatureExponent).toDouble();
  }

  /// Nonlinear edge curvature strength in `[0, 1]`. Zero in the magnified center
  /// dome and steepest at the curved convex rim.
  double curvatureAt({
    required double distanceInside,
    double? edgeWidthOverride,
  }) {
    final ew = math.max(1.0, edgeWidthOverride ?? edgeWidth);
    if (distanceInside <= 0.0) return 1.0;
    if (distanceInside >= ew) return 0.0;
    final s = 1.0 - (distanceInside / ew);
    return math.pow(s, math.max(1.0, curvatureExponent - 0.6)).toDouble().clamp(0.0, 1.0);
  }

  /// Smooth outward 2D unit surface normal continuous around straight walls and corners.
  Offset surfaceNormal2D({
    required Offset point,
    required Size size,
    required double radius,
  }) {
    const eps = 0.75;
    final gx =
        signedDistanceRect(point: point.translate(eps, 0), size: size, radius: radius) -
        signedDistanceRect(point: point.translate(-eps, 0), size: size, radius: radius);
    final gy =
        signedDistanceRect(point: point.translate(0, eps), size: size, radius: radius) -
        signedDistanceRect(point: point.translate(0, -eps), size: size, radius: radius);
    final len = math.sqrt(gx * gx + gy * gy);
    if (len < 1e-5) return Offset.zero;
    return Offset(gx / len, gy / len);
  }

  /// 3D optical surface normal `(nx, ny, nz)` tilting cleanly from `(0, 0, 1)`
  /// in the lens center outward across the curved sidewall.
  ({double nx, double ny, double nz}) surfaceNormal3D({
    required Offset point,
    required Size size,
    required double radius,
    double? edgeWidthOverride,
  }) {
    final sdf = signedDistanceRect(point: point, size: size, radius: radius);
    final distanceInside = math.max(0.0, -sdf);
    final ew = math.max(1.0, edgeWidthOverride ?? edgeWidth);
    final n2 = surfaceNormal2D(point: point, size: size, radius: radius);
    final h = surfaceHeight(distanceInside: distanceInside, edgeWidthOverride: ew);
    final tilt = math.sqrt(math.max(0.0, 1.0 - h * h));
    final vx = n2.dx * tilt;
    final vy = n2.dy * tilt;
    final vz = math.max(h, 1e-4);
    final len = math.sqrt(vx * vx + vy * vy + vz * vz);
    return (nx: vx / len, ny: vy / len, nz: vz / len);
  }

  /// Inverse-UV magnification mapping around the lens center.
  /// For `m > 1.0`, samples closer to the center (`delta / m`), optically
  /// enlarging background details without scaling child UI.
  Offset mapMagnifiedOffset({
    required Offset point,
    required Size size,
    double? magnificationOverride,
  }) {
    final center = size.center(Offset.zero);
    final m = math.max(1.0, magnificationOverride ?? magnification);
    return center + (point - center) / m;
  }

  /// Nonlinear normal-driven sidewall refraction offset blending smoothly to zero
  /// at the center interior dome.
  Offset mapRefractedOffset({
    required Offset point,
    required Size size,
    required double radius,
    double refractionStrengthScale = 1.0,
    double? edgeWidthOverride,
  }) {
    final sdf = signedDistanceRect(point: point, size: size, radius: radius);
    if (sdf >= 0.0) return Offset.zero;
    final distanceInside = -sdf;
    final c = curvatureAt(distanceInside: distanceInside, edgeWidthOverride: edgeWidthOverride);
    if (c <= 0.0) return Offset.zero;
    final n2 = surfaceNormal2D(point: point, size: size, radius: radius);
    final strength = c * refractionStrengthMultiplier * refractionStrengthScale;
    return Offset(-n2.dx * strength, -n2.dy * strength);
  }

  /// Unified coordinate mapping combining convex center magnification and
  /// curved sidewall refraction from one geometric model.
  Offset combinedSampleOffset({
    required Offset point,
    required Size size,
    required double radius,
    double? magnificationOverride,
    double refractionStrengthScale = 1.0,
    double? edgeWidthOverride,
  }) {
    final magnified = mapMagnifiedOffset(
      point: point,
      size: size,
      magnificationOverride: magnificationOverride,
    );
    final refracted = mapRefractedOffset(
      point: point,
      size: size,
      radius: radius,
      refractionStrengthScale: refractionStrengthScale,
      edgeWidthOverride: edgeWidthOverride,
    );
    return magnified + refracted;
  }

  /// Confines RGB chromatic dispersion strictly to the curved perimeter (`0.0` at center).
  double dispersionScaleAt({required double distanceInside, double? edgeWidthOverride}) =>
      curvatureAt(distanceInside: distanceInside, edgeWidthOverride: edgeWidthOverride);

  /// Directional specular/edge glow weight aligned to the convex sidewall rim.
  double specularWeightAt({required double distanceInside, double? edgeWidthOverride}) =>
      curvatureAt(distanceInside: distanceInside, edgeWidthOverride: edgeWidthOverride);
}

/// Unified optical material descriptor driving both Flutter GPU shader lenses
/// (`LiquidGlassLens`) and physical edge highlights/bevels on desktop-backed
/// macOS surfaces.
@immutable
class DropitOpticalGlassSpec {
  const DropitOpticalGlassSpec({
    this.profile = OpticalLensProfile.profileB,
    this.clarity = kDefaultOpticalClarity,
    this.blur = 2.0,
    this.refractionIntensity = kDefaultOpticalRefraction,
    this.refractionWidth = 28.0,
    this.edgeThickness = 4.2,
    this.dispersion = 2.6,
    this.specularIntensity = 1.15,
    this.glowIntensity = 0.45,
    this.tintOpacity = 0.14,
    this.cornerRadius = 24.0,
    this.surfaceDepth = 1.0,
    this.interactionDeformation = 1.0,
    this.magnification = 1.08,
    this.saturation = 1.06,
  });

  final OpticalLensProfile profile;
  final double clarity;
  final double blur;
  final double refractionIntensity;
  final double refractionWidth;
  final double edgeThickness;
  final double dispersion;
  final double specularIntensity;
  final double glowIntensity;
  final double tintOpacity;
  final double cornerRadius;
  final double surfaceDepth;
  final double interactionDeformation;
  final double magnification;
  final double saturation;

  static final Map<_SpecCacheKey, DropitOpticalGlassSpec> _specCache = <_SpecCacheKey, DropitOpticalGlassSpec>{};

  /// Resolves physically scaled optical parameters from global user settings
  /// and component role without allocating transient objects during frames.
  factory DropitOpticalGlassSpec.resolve({
    required AppGlassConfigData config,
    DropitOpticalPreset preset = DropitOpticalPreset.panel,
    double? clarityOverride,
    double? radiusOverride,
    double? refractionDepthOverride,
    double? refractionWidthOverride,
    double? blurSigmaOverride,
  }) {
    final cacheKey = _SpecCacheKey(
      quality: config.quality,
      clarity: config.clarity,
      refractionIntensity: config.refractionIntensity,
      dispersion: config.dispersion,
      reduceMotion: config.reduceMotion,
      highContrast: config.highContrast,
      preset: preset,
      clarityOverride: clarityOverride,
      radiusOverride: radiusOverride,
      refractionDepthOverride: refractionDepthOverride,
      refractionWidthOverride: refractionWidthOverride,
      blurSigmaOverride: blurSigmaOverride,
    );
    final cached = _specCache[cacheKey];
    if (cached != null) return cached;

    final resolvedClarity = (clarityOverride ?? config.clarity).clamp(0.0, 1.0);
    final rawIntensity = (config.refractionIntensity / kMaxOpticalRefraction).clamp(0.0, 1.0);
    // Boost perceptual curve so optical refraction and curved bending read clearly across 50%-200%.
    final intensityCurve = config.reduceMotion ? rawIntensity * 0.55 : math.pow(rawIntensity, 0.72).toDouble();
    final profile = OpticalLensProfile.forPreset(preset);

    final baseSpec = switch (preset) {
      DropitOpticalPreset.sidebar => _PresetTuning(
        refractionWidth: 48.0,
        edgeThickness: 5.8,
        specular: 1.28,
        glow: 0.54,
        dispersion: 2.5,
        tintOpacity: 0.22,
        surfaceDepth: 1.15,
        magnification: profile.magnification,
        blurBase: 2.2,
        cornerRadius: 34.0,
      ),
      DropitOpticalPreset.toolbar => _PresetTuning(
        refractionWidth: profile.edgeWidth,
        edgeThickness: 4.5,
        specular: 1.25,
        glow: 0.52,
        dispersion: 3.5,
        tintOpacity: 0.16,
        surfaceDepth: 1.08,
        magnification: profile.magnification,
        blurBase: 1.5,
        cornerRadius: 30.0,
      ),
      DropitOpticalPreset.dropZone => _PresetTuning(
        refractionWidth: 50.0,
        edgeThickness: 6.2,
        specular: 1.52,
        glow: 0.68,
        dispersion: 3.0,
        tintOpacity: 0.18,
        surfaceDepth: 1.18,
        magnification: profile.magnification,
        blurBase: 1.3,
        cornerRadius: 40.0,
      ),
      DropitOpticalPreset.capsuleButton => _PresetTuning(
        refractionWidth: profile.edgeWidth,
        edgeThickness: 4.4,
        specular: 1.42,
        glow: 0.62,
        dispersion: 4.0,
        tintOpacity: 0.19,
        surfaceDepth: 1.12,
        magnification: profile.magnification,
        blurBase: 1.1,
        cornerRadius: 999.0,
      ),
      DropitOpticalPreset.searchField => _PresetTuning(
        refractionWidth: profile.edgeWidth,
        edgeThickness: 3.8,
        specular: 1.15,
        glow: 0.44,
        dispersion: 2.5,
        tintOpacity: 0.20,
        surfaceDepth: 1.02,
        magnification: profile.magnification,
        blurBase: 1.3,
        cornerRadius: 999.0,
      ),
      DropitOpticalPreset.segmented => _PresetTuning(
        refractionWidth: profile.edgeWidth,
        edgeThickness: 4.2,
        specular: 1.36,
        glow: 0.54,
        dispersion: 4.0,
        tintOpacity: 0.21,
        surfaceDepth: 1.08,
        magnification: profile.magnification,
        blurBase: 1.1,
        cornerRadius: 999.0,
      ),
      DropitOpticalPreset.deviceCard => _PresetTuning(
        refractionWidth: profile.edgeWidth,
        edgeThickness: 4.2,
        specular: 1.16,
        glow: 0.44,
        dispersion: 2.2,
        tintOpacity: 0.17,
        surfaceDepth: 0.95,
        magnification: profile.magnification,
        blurBase: 1.4,
        cornerRadius: 30.0,
      ),
      DropitOpticalPreset.modalSheet => _PresetTuning(
        refractionWidth: 48.0,
        edgeThickness: 6.0,
        specular: 1.48,
        glow: 0.62,
        dispersion: 3.2,
        tintOpacity: 0.24,
        surfaceDepth: 1.20,
        magnification: profile.magnification,
        blurBase: 2.0,
        cornerRadius: 36.0,
      ),
      DropitOpticalPreset.panel => _PresetTuning(
        refractionWidth: 44.0,
        edgeThickness: 5.2,
        specular: 1.38,
        glow: 0.57,
        dispersion: 1.44,
        tintOpacity: 0.16,
        surfaceDepth: 1.10,
        magnification: profile.magnification,
        blurBase: 1.4,
        cornerRadius: 30.0,
      ),
    };

    final opticalScale = config.quality == AppGlassQuality.liquid ? intensityCurve : 0.0;
    // Normalize magnification curve so default 150% intensity (rawIntensity=0.75)
    // hits each OpticalLensProfile's calibrated center magnification cleanly while
    // smoothly scaling from 1.0x (0%) up toward 1.25x (200% + press deformation).
    const defaultCurve = 0.812945; // math.pow(0.75, 0.72)
    final magScale = config.quality == AppGlassQuality.liquid ? (intensityCurve / defaultCurve) : 0.0;
    final resolvedBlur = blurSigmaOverride ?? (baseSpec.blurBase * (1.15 - resolvedClarity * 0.65)).clamp(0.4, 2.8);
    final dispersionScale = (config.dispersion <= 0.005 || opticalScale == 0.0) ? 0.0 : (config.dispersion / 1.32).clamp(0.0, 12.0);
    final effectiveDispersion = (baseSpec.dispersion * dispersionScale * (0.85 + 0.15 * opticalScale)).clamp(0.0, 16.0);

    final resolvedSpec = DropitOpticalGlassSpec(
      profile: profile,
      clarity: resolvedClarity,
      blur: resolvedBlur,
      refractionIntensity: config.refractionIntensity.clamp(0.0, kMaxOpticalRefraction),
      refractionWidth: refractionWidthOverride ?? baseSpec.refractionWidth,
      edgeThickness: (baseSpec.edgeThickness * (0.72 + 0.52 * opticalScale)).clamp(2.4, 7.2),
      dispersion: effectiveDispersion,
      specularIntensity: (baseSpec.specular * (0.75 + 0.45 * opticalScale)).clamp(0.45, 2.0),
      glowIntensity: (baseSpec.glow * (0.65 + 0.55 * opticalScale)).clamp(0.18, 1.1),
      tintOpacity: baseSpec.tintOpacity,
      cornerRadius: radiusOverride ?? baseSpec.cornerRadius,
      surfaceDepth: baseSpec.surfaceDepth,
      interactionDeformation: config.reduceMotion ? 0.0 : 1.0,
      magnification: (1.0 + (baseSpec.magnification - 1.0) * magScale).clamp(1.0, 1.25),
      saturation: 1.0 + 0.09 * opticalScale,
    );
    if (_specCache.length >= 48) {
      _specCache.remove(_specCache.keys.first);
    }
    _specCache[cacheKey] = resolvedSpec;
    return resolvedSpec;
  }

  /// Resolves final logical pixel dispersion for this optical role and optional
  /// component [dispersionOverride], returning `0.0` when disabled or flat.
  double resolvedChromaticDispersion(
    AppGlassConfigData config, {
    double? dispersionOverride,
  }) {
    if (config.effectiveQuality == AppGlassQuality.flat || config.dispersion <= 0.005 || config.refractionIntensity <= 0.005) {
      return 0.0;
    }
    if (dispersionOverride != null) {
      if (dispersionOverride <= 0.005) return 0.0;
      return (dispersionOverride * (config.dispersion / 1.32)).clamp(0.0, 16.0);
    }
    return dispersion.clamp(0.0, 16.0);
  }

  /// Builds a `LiquidGlassStyle` configured for GPU shader lenses in
  /// `liquid_glass_easy 5.1.0`.
  LiquidGlassStyle toShaderStyle({
    required Brightness brightness,
    required double radius,
    required Color tintColor,
    required bool outlines,
    bool smoothCorners = false,
    double? widthOverride,
    double depthOverride = 0.0,
    double bendScale = 1.0,
    double? dispersionOverride,
    LiquidGlassShadow? shadow,
  }) {
    final normalizedIntensity = (refractionIntensity / kMaxOpticalRefraction).clamp(0.0, 1.0);
    final depthFactor = depthOverride > 0 ? (depthOverride / 0.38).clamp(0.0, 1.75) : 1.0;
    final indexT = (normalizedIntensity * (0.64 + 0.36 * depthFactor)).clamp(0.0, 1.0);
    final baseIndex = normalizedIntensity <= 0.005 || depthFactor <= 0.005 ? 1.0 : lerpDouble(1.16, profile.maxRefractionIndex, indexT)!;
    final effectiveIndex = lerpDouble(1.0, baseIndex, bendScale.clamp(0.0, 1.45))!.clamp(1.0, 2.28);
    final magBoost = bendScale < 0.65 ? (bendScale / 0.65).clamp(0.25, 1.0) : 1.0 + ((bendScale - 1.0).clamp(0.0, 0.45) * 0.25);
    final effectiveMagnification = normalizedIntensity < 0.05 ? 1.0 : (1.0 + (magnification - 1.0) * magBoost).clamp(1.0, 1.25);
    final dark = brightness == Brightness.dark;
    final specAlpha = dark ? 0.92 : 0.98;
    final glowAlpha = dark ? 0.42 : 0.56;
    final activeDispersion = dispersionOverride != null
        ? (dispersion <= 0.005
              ? 0.0
              : (dispersionOverride * (dispersion / 1.32).clamp(0.0, 12.0) * (0.80 + 0.20 * normalizedIntensity)).clamp(0.0, 16.0))
        : (dispersion * (0.80 + 0.20 * bendScale.clamp(0.5, 1.5)));

    return LiquidGlassStyle(
      shape: smoothCorners
          ? LiquidGlassShape.continuousRoundedRectangle(cornerRadius: radius)
          : LiquidGlassShape.roundedRectangle(cornerRadius: radius),
      color: tintColor,
      blur: blur,
      saturation: saturation,
      magnification: effectiveMagnification,
      refractionIndex: effectiveIndex,
      refractionWidth: (widthOverride ?? refractionWidth).clamp(0.0, 52.0),
      dispersion: (dispersion <= 0.005 || normalizedIntensity < 0.08) ? 0.0 : activeDispersion.clamp(0.0, 16.0),
      shadow: shadow,
      specular: outlines
          ? LiquidGlassLight.specular(
              thickness: (edgeThickness * 1.15).clamp(3.2, 7.0),
              sharpness: 0.64,
              angle: 39.0,
              spread: 0.90,
              intensity: (specularIntensity * specAlpha).clamp(0.4, 2.1),
              oppositeIntensity: 0.42,
              color: Colors.white.withValues(alpha: dark ? 0.78 : 0.88),
            )
          : const LiquidGlassLight.specular(thickness: 0, intensity: 0),
      glow: outlines
          ? LiquidGlassLight.glow(
              thickness: (edgeThickness * 2.4).clamp(7.0, 14.0),
              angle: 118.0,
              spread: 0.68,
              intensity: (glowIntensity * glowAlpha).clamp(0.14, 1.05),
              oppositeIntensity: 0.55,
              color: (dark ? const Color(0xFFD8EBFF) : Colors.white).withValues(alpha: dark ? 0.34 : 0.42),
            )
          : const LiquidGlassLight.glow(thickness: 0, intensity: 0),
    );
  }
}

class _PresetTuning {
  const _PresetTuning({
    required this.refractionWidth,
    required this.edgeThickness,
    required this.specular,
    required this.glow,
    required this.dispersion,
    required this.tintOpacity,
    required this.surfaceDepth,
    required this.magnification,
    required this.blurBase,
    required this.cornerRadius,
  });

  final double refractionWidth;
  final double edgeThickness;
  final double specular;
  final double glow;
  final double dispersion;
  final double tintOpacity;
  final double surfaceDepth;
  final double magnification;
  final double blurBase;
  final double cornerRadius;
}

/// Central resolver mapping `SettingsState` / `AppGlassConfigData` and system
/// accessibility toggles into concrete optical rendering choices.
abstract final class DropitGlassQualityController {
  static bool isInteractiveShaderActive(AppGlassConfigData config) =>
      config.quality == AppGlassQuality.liquid && !config.highContrast && !config.reduceMotion;

  static double nativeRimMultiplier(AppGlassConfigData config) {
    if (config.highContrast) return 0.5;
    final normalized = (config.refractionIntensity / kMaxOpticalRefraction).clamp(0.0, 1.0);
    return lerpDouble(0.68, 1.38, normalized)!;
  }

  /// Smooth taper from `1.0` (at `<= 90%` Clarity) down to `0.0` at `100%`
  /// Clarity so crystal-clear Liquid Glass panels render with full
  /// transparency when no explicit tint or liquid frost is applied.
  static double crystalClarityScale(double clarity) {
    final c = clarity.clamp(0.0, 1.0);
    if (c <= 0.90) return 1.0;
    if (c >= 0.9999) return 0.0;
    return ((1.0 - c) / 0.10).clamp(0.0, 1.0);
  }

  /// Suggested adaptive tint alpha over desktop pixels so white or yellow
  /// wallpapers do not wash out body copy while preserving true transparency.
  static double surfaceTintAlpha({
    required Brightness brightness,
    required double clarity,
    required AppGlassQuality quality,
    required DropitOpticalPreset preset,
    required bool nativeClear,
    double liquidFrost = 0.0,
    bool hasExplicitTint = false,
  }) {
    final dark = brightness == Brightness.dark;
    if (quality == AppGlassQuality.flat) {
      return dark ? 0.90 : 0.94;
    }
    if (quality == AppGlassQuality.frosted) {
      final t = (1.0 - clarity).clamp(0.0, 1.0);
      return dark ? lerpDouble(0.24, 0.54, t)! : lerpDouble(0.32, 0.64, t)!;
    }
    final frostLift = (liquidFrost.clamp(0.0, 1.0)) * (dark ? 0.16 : 0.20);
    final clarityFade = ((1.0 - clarity) * 0.22).clamp(0.0, 0.22);
    final crystalScale = hasExplicitTint ? 1.0 : crystalClarityScale(clarity);
    return switch (preset) {
      DropitOpticalPreset.sidebar => ((dark ? 0.11 : 0.22) + clarityFade * 0.55) * crystalScale + frostLift * 0.75,
      DropitOpticalPreset.toolbar => ((dark ? 0.08 : 0.18) + clarityFade * 0.45) * crystalScale + frostLift * 0.85,
      DropitOpticalPreset.dropZone => ((dark ? 0.09 : 0.20) + clarityFade * 0.45) * crystalScale + frostLift * 0.95,
      DropitOpticalPreset.capsuleButton => ((dark ? 0.11 : 0.22) + clarityFade * 0.35) * crystalScale + frostLift * 0.85,
      DropitOpticalPreset.searchField => ((dark ? 0.10 : 0.21) + clarityFade * 0.40) * crystalScale + frostLift * 0.85,
      DropitOpticalPreset.segmented => ((dark ? 0.11 : 0.23) + clarityFade * 0.40) * crystalScale + frostLift * 0.85,
      DropitOpticalPreset.deviceCard => ((dark ? 0.09 : 0.19) + clarityFade * 0.40) * crystalScale + frostLift * 0.95,
      DropitOpticalPreset.modalSheet => (dark ? 0.22 : 0.38) + clarityFade * 0.40 + frostLift * 0.60,
      DropitOpticalPreset.panel =>
        (nativeClear ? (dark ? 0.06 : 0.14) + clarityFade * 0.30 : (dark ? 0.09 : 0.18) + clarityFade * 0.40) * crystalScale + frostLift,
    };
  }
}

/// Subtle optical surface sheen and whisper-thin specular hairline painter.
/// Keeps Liquid Glass edges light and borderless without heavy bevel rings.
class DropitGlassHighlight extends CustomPainter {
  const DropitGlassHighlight({
    required this.radius,
    required this.brightness,
    required this.refractionIntensity,
    this.clarity = kDefaultOpticalClarity,
    this.edgeThickness = 4.2,
    this.emphasis = 1.0,
    this.smoothCorners = false,
    this.focused = false,
    this.focusColor,
  });

  final double radius;
  final Brightness brightness;
  final double refractionIntensity;
  final double clarity;
  final double edgeThickness;
  final double emphasis;
  final bool smoothCorners;
  final bool focused;
  final Color? focusColor;

  Path _shapePath(Rect r, double rCorner) {
    if (rCorner <= 0) return Path()..addRect(r);
    if (!smoothCorners) {
      return Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(rCorner)));
    }
    final inner = liquidGlassSquirclePath(r.size, rCorner, 1);
    return r.topLeft == Offset.zero ? inner : inner.shift(r.topLeft);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final maxR = math.min(size.width, size.height) * 0.5;
    final clampedR = radius.clamp(0.0, maxR);
    final outerPath = _shapePath(rect, clampedR);
    final dark = brightness == Brightness.dark;
    final intensityFactor = (refractionIntensity / kMaxOpticalRefraction).clamp(0.0, 1.0);
    final rimScale = (lerpDouble(0.75, 1.15, intensityFactor)! * emphasis).clamp(0.0, 1.35);

    canvas.save();
    canvas.clipPath(outerPath);

    // 1. Subtle interior convex glass sheen (top-left skylight sweep fading inward)
    final sheenAlpha = ((dark ? 0.045 : 0.095) * (0.75 + 0.25 * intensityFactor)).clamp(0.02, 0.14);
    final interiorSheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: sheenAlpha),
          Colors.white.withValues(alpha: sheenAlpha * 0.22),
          Colors.transparent,
        ],
        stops: const [0.0, 0.44, 1.0],
      ).createShader(rect);
    canvas.drawPath(outerPath, interiorSheen);

    // 2. Delicate hairline specular edge (never thick bevels or dark outer borders)
    final specRect = rect.deflate(0.375);
    if (!specRect.isEmpty) {
      final topAlpha = ((dark ? 0.17 : 0.42) * rimScale).clamp(0.05, 0.50);
      final bottomAlpha = ((dark ? 0.07 : 0.20) * rimScale).clamp(0.02, 0.26);
      final specStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = focused ? 1.1 : 0.75
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: focused && focusColor != null
              ? [
                  Color.lerp(Colors.white, focusColor!, 0.45)!.withValues(alpha: (topAlpha * 2.2).clamp(0.35, 0.78)),
                  Colors.white.withValues(alpha: topAlpha * 0.65),
                  focusColor!.withValues(alpha: (bottomAlpha * 2.8).clamp(0.22, 0.52)),
                ]
              : [
                  Colors.white.withValues(alpha: topAlpha),
                  Colors.white.withValues(alpha: dark ? 0.025 : 0.08),
                  Colors.white.withValues(alpha: bottomAlpha),
                ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect);
      canvas.drawPath(_shapePath(specRect, math.max(0.0, clampedR - 0.375)), specStroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(DropitGlassHighlight old) =>
      old.radius != radius ||
      old.brightness != brightness ||
      old.refractionIntensity != refractionIntensity ||
      old.clarity != clarity ||
      old.edgeThickness != edgeThickness ||
      old.emphasis != emphasis ||
      old.smoothCorners != smoothCorners ||
      old.focused != focused ||
      old.focusColor != focusColor;
}

@immutable
class _SpecCacheKey {
  const _SpecCacheKey({
    required this.quality,
    required this.clarity,
    required this.refractionIntensity,
    required this.dispersion,
    required this.reduceMotion,
    required this.highContrast,
    required this.preset,
    this.clarityOverride,
    this.radiusOverride,
    this.refractionDepthOverride,
    this.refractionWidthOverride,
    this.blurSigmaOverride,
  });

  final AppGlassQuality quality;
  final double clarity;
  final double refractionIntensity;
  final double dispersion;
  final bool reduceMotion;
  final bool highContrast;
  final DropitOpticalPreset preset;
  final double? clarityOverride;
  final double? radiusOverride;
  final double? refractionDepthOverride;
  final double? refractionWidthOverride;
  final double? blurSigmaOverride;

  @override
  bool operator ==(Object other) =>
      other is _SpecCacheKey &&
      other.quality == quality &&
      other.clarity == clarity &&
      other.refractionIntensity == refractionIntensity &&
      other.dispersion == dispersion &&
      other.reduceMotion == reduceMotion &&
      other.highContrast == highContrast &&
      other.preset == preset &&
      other.clarityOverride == clarityOverride &&
      other.radiusOverride == radiusOverride &&
      other.refractionDepthOverride == refractionDepthOverride &&
      other.refractionWidthOverride == refractionWidthOverride &&
      other.blurSigmaOverride == blurSigmaOverride;

  @override
  int get hashCode => Object.hash(
    quality,
    clarity,
    refractionIntensity,
    dispersion,
    reduceMotion,
    highContrast,
    preset,
    clarityOverride,
    radiusOverride,
    refractionDepthOverride,
    refractionWidthOverride,
    blurSigmaOverride,
  );
}
