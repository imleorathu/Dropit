import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/widget/mornye/app_glass_press.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:flutter/material.dart';

class CustomListTile extends StatelessWidget {
  final Widget? icon;
  final Widget title;
  final Widget subTitle;
  final Widget? trailing;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const CustomListTile({
    this.icon,
    required this.title,
    required this.subTitle,
    this.trailing,
    this.padding = const EdgeInsets.all(15),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassPress(
      radius: 24,
      enabled: onTap != null,
      child: AppLiquidGlass(
        radius: 24,
        refractionDepth: 0.24,
        dispersion: 1.5,
        smoothCorners: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: usesAndroidMornye ? null : Colors.transparent,
            highlightColor: usesAndroidMornye ? null : Colors.transparent,
            hoverColor: usesAndroidMornye ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: padding,
              child: Row(
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 15),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          child: title,
                        ),
                        const SizedBox(height: 5),
                        subTitle,
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
