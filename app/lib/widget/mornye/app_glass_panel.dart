import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:flutter/material.dart';

/// Elevated optical Liquid Glass surface panel used for cards, sections,
/// and status containers across all Dropit screens.
class AppGlassPanel extends StatelessWidget {
  const AppGlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 30,
    this.chrome = false,
    this.tonal = false,
    this.selected = false,
    this.tintColor,
    this.refractionDepth = 0.46,
    this.dispersion,
    this.nativeClear = true,
    this.preset,
    this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool chrome;
  final bool tonal;
  final bool selected;
  final Color? tintColor;
  final double refractionDepth;
  final double? dispersion;
  final bool nativeClear;
  final DropitOpticalPreset? preset;
  final String? title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final resolvedTint = usesAndroidMornye
        ? (selected ? scheme.primaryContainer : (tintColor ?? (tonal ? scheme.primaryContainer : null)))
        : (selected
              ? scheme.primary
              : (tintColor ?? (tonal ? Color.lerp(scheme.surfaceContainerHigh, const Color(0xFF13234D), dark ? 0.45 : 0.08) : null)));

    return AppLiquidGlass(
      radius: radius,
      strongTint: chrome || selected,
      // Ordinary page panels sit on the uniform Android canvas. Reflections
      // and tint remain visible without filtering identical background pixels.
      samplesBackdrop: !usesAndroidMornye || chrome || preset == DropitOpticalPreset.modalSheet,
      tintColor: resolvedTint,
      tintOpacity: usesAndroidMornye && (selected || tonal) ? (selected ? 0.45 : 0.25) : null,
      highlightBorder: selected,
      refractionDepth: refractionDepth,
      dispersion: dispersion,
      nativeClear: nativeClear,
      preset: preset ?? (chrome ? DropitOpticalPreset.toolbar : DropitOpticalPreset.panel),
      smoothCorners: radius >= 18,
      child: Padding(
        padding: padding,
        child: (title == null && subtitle == null && trailing == null)
            ? child
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != null)
                              Text(
                                title!,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 12),
                        trailing!,
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  child,
                ],
              ),
      ),
    );
  }
}
