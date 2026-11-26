import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/macos_native_glass.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:routerino/routerino.dart';

class CustomBottomSheet extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  const CustomBottomSheet({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: LiquidGlassBatch.exclude(
          child: AppLiquidGlass(
            radius: 32,
            strongTint: true,
            refractionDepth: 0.34,
            dispersion: 2.6,
            smoothCorners: true,
            nativeMaterial: MacosNativeGlassMaterial.popover,
            nativeModalOverlay: true,
            child: RouterinoBottomSheet(
              title: title,
              description: description,
              backgroundColor: Colors.transparent,
              borderRadius: 32,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
