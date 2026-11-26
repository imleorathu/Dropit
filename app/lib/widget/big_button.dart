import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/widget/mornye/app_glass_press.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/responsive_builder.dart';
import 'package:flutter/material.dart';

class BigButton extends StatelessWidget {
  static const double desktopWidth = 100.0;
  static const double mobileWidth = 90.0;

  final IconData icon;
  final String label;
  final bool filled;
  final double? width;
  final VoidCallback onTap;

  const BigButton({
    required this.icon,
    required this.label,
    required this.filled,
    this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sizingInformation = SizingInformation(MediaQuery.sizeOf(context).width);
    final buttonWidth = width ?? (sizingInformation.isDesktop ? desktopWidth : mobileWidth);
    final foreground = filled ? colorScheme.primary : colorScheme.onSurface;
    return SizedBox(
      width: buttonWidth,
      height: 68.0,
      child: AppGlassPress(
        radius: 18,
        child: AppLiquidGlass(
          radius: 18,
          strongTint: filled,
          tintColor: filled ? colorScheme.primary : null,
          highlightBorder: filled,
          refractionDepth: 0.24,
          smoothCorners: true,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              splashColor: usesAndroidMornye ? null : Colors.transparent,
              highlightColor: usesAndroidMornye ? null : Colors.transparent,
              hoverColor: usesAndroidMornye ? null : Colors.transparent,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: foreground),
                    FittedBox(
                      alignment: Alignment.bottomCenter,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(color: foreground, fontWeight: filled ? FontWeight.w600 : FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
