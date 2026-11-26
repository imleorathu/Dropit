import 'package:dropit_app/model/persistence/glass_quality.dart';
import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Shared static product canvas and optical glass pipeline host.
///
/// The pure-white/midnight canvas avoids a full-screen animated repaint while
/// [LiquidGlassView] provides the capture context required by descendant
/// optical lenses on Skia/Web. On Impeller every page lens shares one batched
/// backdrop read; components that stack glass keep their own read via
/// [LiquidGlassBatch.exclude].
class AppAtmosphericBackdrop extends StatelessWidget {
  const AppAtmosphericBackdrop({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (usesAndroidMornye) return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: child);
    final config = AppGlassConfigScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final flatMode = config.effectiveQuality == AppGlassQuality.flat || config.highContrast;

    final background = RepaintBoundary(
      child: ColoredBox(
        color: dark ? const Color(0xFF080D1B) : const Color(0xFFFFFFFF),
        child: const SizedBox.expand(),
      ),
    );

    if (flatMode) {
      return Stack(
        fit: StackFit.expand,
        children: [
          background,
          child,
        ],
      );
    }

    return LiquidGlassView(
      batch: true,
      pixelRatio: 0.72,
      realTimeCapture: false,
      refreshRate: LiquidGlassRefreshRate.low,
      adaptiveSampling: const LiquidGlassAdaptiveSampling(),
      backgroundWidget: background,
      child: BackdropGroup(child: child),
    );
  }
}
