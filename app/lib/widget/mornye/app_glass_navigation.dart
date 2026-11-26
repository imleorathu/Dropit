import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/theme/mornye_theme.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_press.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:dropit_app/widget/mornye/mornye_selection_pill.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

class AppGlassNavItem {
  const AppGlassNavItem({
    required this.label,
    required this.icon,
    this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData? activeIcon;
}

/// Floating capsule bottom navigation bar using `MornyeSelectionPill`,
/// custom fragment mask shader, and excluded `LiquidGlassBatch` reads so
/// the floating indicator refracts the dock beneath it cleanly.
class AppGlassNavigation extends StatelessWidget {
  const AppGlassNavigation({
    required this.items,
    required this.activeIndex,
    required this.onChanged,
    super.key,
  });

  final List<AppGlassNavItem> items;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final config = AppGlassConfigScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final active = items.isEmpty ? 0 : activeIndex.clamp(0, items.length - 1);
    final liquidPill = config.effectiveQuality == AppGlassQuality.liquid && config.clarity > 0.15;

    return LiquidGlassBatch.exclude(
      child: AppGlassPress(
        radius: 999,
        enabled: config.animateMotion,
        child: AppLiquidGlass(
          radius: 999,
          preset: DropitOpticalPreset.segmented,
          // A bounded frosted read keeps the fixed Android dock translucent
          // without moving-shader coordinate artifacts in Scaffold overlays.
          samplesBackdrop: usesAndroidMornye,
          quality: usesAndroidMornye && config.effectiveQuality == AppGlassQuality.liquid ? AppGlassQuality.frosted : null,
          strongTint: true,
          tintOpacity: MornyeTheme.navigationOpacity(context),
          refractionDepth: 0.34,
          dispersion: 4.0,
          smoothCorners: true,
          nativeClear: true,
          nativeInteractive: true,
          child: MornyeSelectionPill(
            labels: [for (final item in items) item.label],
            selectedIndex: active,
            onChanged: onChanged,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            // Android's fixed Scaffold chrome is composited in a separate
            // overlay path. A moving backdrop shader inside that overlay can
            // retain the page's old screen-space origin. The selection still
            // glides and scales normally; only the corrupting texture read is
            // disabled on Android.
            liquidInteraction: liquidPill && config.animateMotion && defaultTargetPlatform != TargetPlatform.android,
            itemBuilder: (context, index, selected) => ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: IconThemeData(
                      size: 24,
                      color: selected ? scheme.primary : scheme.onSurface,
                    ),
                    child: MornyeSelectionForeground(
                      child: Icon(selected ? (items[index].activeIcon ?? items[index].icon) : items[index].icon),
                    ),
                  ),
                  const SizedBox(height: 2),
                  MornyeSelectionForeground(
                    child: Text(
                      items[index].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppGlassSegmentOption {
  const AppGlassSegmentOption({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// Morphing Liquid Glass segmented control driven by `MornyeSelectionPill`.
class AppGlassSegmented extends StatelessWidget {
  const AppGlassSegmented({
    required this.options,
    required this.value,
    required this.onChanged,
    this.size = AppGlassButtonSize.md,
    super.key,
  });

  final List<AppGlassSegmentOption> options;
  final int value;
  final ValueChanged<int> onChanged;
  final AppGlassButtonSize size;

  @override
  Widget build(BuildContext context) {
    final config = AppGlassConfigScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final active = options.isEmpty ? 0 : value.clamp(0, options.length - 1);
    final compact = size == AppGlassButtonSize.sm;
    final liquidPill = config.effectiveQuality == AppGlassQuality.liquid && config.clarity > 0.15;

    final dark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = dark ? Color.lerp(scheme.primary, Colors.white, 0.42)! : scheme.primary;
    return LiquidGlassBatch.exclude(
      child: AppGlassPress(
        radius: 999,
        enabled: config.animateMotion,
        child: AppLiquidGlass(
          radius: 999,
          preset: DropitOpticalPreset.segmented,
          strongTint: false,
          tintOpacity: MornyeTheme.navigationOpacity(context),
          refractionDepth: 0.38,
          dispersion: 4.0,
          smoothCorners: true,
          nativeClear: true,
          nativeInteractive: true,
          child: MornyeSelectionPill(
            labels: [for (final option in options) option.label],
            selectedIndex: active,
            onChanged: onChanged,
            padding: EdgeInsets.all(compact ? 3 : 4),
            liquidInteraction: liquidPill && config.animateMotion,
            itemBuilder: (context, index, selected) {
              final inactiveColor = dark
                  ? (Theme.of(context).platform == TargetPlatform.macOS ? Colors.white : Colors.white.withValues(alpha: 0.80))
                  : const Color(0xFF0F172A).withValues(alpha: 0.74);
              return SizedBox(
                height: compact ? 28 : 34,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (options[index].icon != null) ...[
                          Icon(
                            options[index].icon,
                            size: compact ? 13 : 15,
                            color: selected ? activeColor : inactiveColor,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(
                            options[index].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 12.5 : 13,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              letterSpacing: -0.2,
                              color: selected ? (dark ? Colors.white : scheme.primary) : inactiveColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
