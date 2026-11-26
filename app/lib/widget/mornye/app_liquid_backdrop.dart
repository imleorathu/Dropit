import 'dart:math' as math;

import 'package:dropit_app/theme/mornye_theme.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Real-time optical SDF shader lens powered by `liquid_glass_easy 5.1.0` and
/// calibrated through [DropitOpticalGlassSpec].
///
/// Renders curved edge light bending, calibrated chromatic dispersion, subtle
/// convex magnification, and dual directional specular + opposite glow arcs
/// over Flutter-rendered backdrops.
class AppLiquidBackdrop extends StatelessWidget {
  const AppLiquidBackdrop({
    required this.borderRadius,
    required this.child,
    this.clarity,
    this.blurSigma = 1.4,
    this.refractionWidth,
    this.refractionDepth = 0.48,
    this.dispersion,
    this.tintColor = Colors.transparent,
    this.smoothCorners = false,
    this.highlightIntensity = 1.0,
    this.outlines,
    this.touch,
    this.shadow,
    this.preset = DropitOpticalPreset.panel,
    super.key,
  });

  final BorderRadius borderRadius;
  final Widget child;
  final double? clarity;
  final double blurSigma;
  final double? refractionWidth;
  final double refractionDepth;
  final double? dispersion;
  final Color tintColor;
  final bool smoothCorners;
  final double highlightIntensity;
  final bool? outlines;
  final LiquidGlassTouch? touch;
  final LiquidGlassShadow? shadow;
  final DropitOpticalPreset preset;

  @override
  Widget build(BuildContext context) {
    final config = AppGlassConfigScope.of(context);
    final effectiveClarity = (clarity ?? config.clarity).clamp(0.0, 1.0);
    final showOutlines = outlines ?? config.outlines;
    final cornerRadius = borderRadius.topLeft.x;
    final brightness = Theme.of(context).brightness;

    final spec = DropitOpticalGlassSpec.resolve(
      config: config,
      preset: preset,
      clarityOverride: effectiveClarity,
      radiusOverride: cornerRadius,
      refractionDepthOverride: refractionDepth,
      refractionWidthOverride: refractionWidth,
      blurSigmaOverride: blurSigma.clamp(0.0, 12.0),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final finiteW = constraints.maxWidth.isFinite ? constraints.maxWidth : 120.0;
        final finiteH = constraints.maxHeight.isFinite ? constraints.maxHeight : 120.0;
        final shortest = math.min(finiteW, finiteH);
        final safeWidth = shortest <= 0 ? 0.0 : spec.refractionWidth.clamp(0.0, shortest * 0.48);
        final safeCorner = shortest <= 0 ? 0.0 : math.min(cornerRadius, shortest * 0.5);
        final depth = refractionDepth.clamp(0.0, 1.0);
        final bendScale = (highlightIntensity * (depth / 0.38).clamp(0.0, 1.45)).clamp(0.0, 1.45);

        return LiquidGlassLens(
          touch: touch,
          style: spec.toShaderStyle(
            brightness: brightness,
            radius: safeCorner,
            smoothCorners: smoothCorners,
            widthOverride: safeWidth,
            tintColor: tintColor,
            outlines: showOutlines,
            depthOverride: depth,
            bendScale: bendScale,
            dispersionOverride: dispersion,
            shadow: shadow,
          ),
          // LiquidGlassLens already performs refraction and chromatic
          // dispersion in one backdrop pass. Nesting DropitChromaticGlass here
          // creates a second backdrop read inside the first filter subpass. On
          // Android Impeller that can feed already-filtered foreground pixels
          // back into the lens, producing duplicated/inverted text and stale
          // content while also doubling the offscreen compositing work.
          child: child,
        );
      },
    );
  }
}

/// Unified optical shader lens alias.
typedef DropitLiquidLens = AppLiquidBackdrop;

double defaultGlassClarity(BuildContext context) => MornyeTheme.glassClarityOf(context);
