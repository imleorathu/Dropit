import 'package:dropit_app/config/theme.dart';
import 'package:dropit_app/model/persistence/glass_quality.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_press.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:flutter/material.dart';

/// A [DropdownButton] with Liquid Glass hover/press response and adaptive menu translucency.
class CustomDropdownButton<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T>? onChanged;
  final bool expanded;

  const CustomDropdownButton({
    required this.value,
    required this.items,
    this.onChanged,
    this.expanded = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final config = AppGlassConfigScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final menuColor = config.effectiveQuality == AppGlassQuality.flat
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerHigh.withValues(alpha: dark ? 0.88 : 0.92);

    return AppGlassPress(
      radius: 16,
      enabled: onChanged != null && config.animateMotion,
      child: DropitSurface(
        radius: 16,
        tonal: true,
        child: CustomPaint(
          foregroundPainter: config.outlines
              ? DropitGlassHighlight(
                  radius: 16,
                  brightness: theme.brightness,
                  refractionIntensity: config.refractionIntensity,
                  clarity: config.clarity,
                  emphasis: 0.95,
                  smoothCorners: true,
                )
              : null,
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: theme.inputDecorationTheme.borderRadius),
            child: DropdownButton<T>(
              value: value,
              isExpanded: expanded,
              elevation: 6,
              dropdownColor: menuColor,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              underline: const SizedBox.shrink(),
              borderRadius: theme.inputDecorationTheme.borderRadius,
              items: items,
              onChanged: onChanged == null
                  ? null
                  : (value) {
                      if (value != null) {
                        onChanged!(value);
                      }
                    },
            ),
          ),
        ),
      ),
    );
  }
}
