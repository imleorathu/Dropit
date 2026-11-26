import 'dart:math' as math;

import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/macos_native_glass.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Spring-driven modal Liquid Glass dialog that inherits live backdrop
/// refraction and respects reduced-motion / high-contrast settings.
Future<T?> showAppGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
}) {
  final reduceMotion = AppGlassConfigScope.of(context).reduceMotion;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final defaultBarrier = MacosNativeGlass.isSupported ? Colors.black.withValues(alpha: dark ? 0.30 : 0.16) : Colors.black.withValues(alpha: 0.42);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? defaultBarrier,
    barrierLabel: barrierLabel ?? MaterialLocalizations.of(context).modalBarrierDismissLabel,
    useRootNavigator: useRootNavigator,
    transitionDuration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
    pageBuilder: (dialogContext, _, _) => LiquidGlassBatch.exclude(child: builder(dialogContext)),
    transitionBuilder: (dialogContext, animation, _, child) {
      if (reduceMotion) return child;
      final curved = CurveTween(curve: const Cubic(0.16, 1.0, 0.3, 1.0)).animate(animation);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Presents a floating Liquid Glass modal sheet across all platforms.
Future<T?> showAppGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? ariaLabel,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: MacosNativeGlass.isSupported ? Colors.black.withValues(alpha: dark ? 0.30 : 0.16) : Colors.black.withValues(alpha: 0.42),
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: math.max(16, MediaQuery.viewInsetsOf(ctx).bottom + 16),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Semantics(
            label: ariaLabel,
            child: LiquidGlassBatch.exclude(
              child: AppLiquidGlass(
                radius: 36,
                strongTint: true,
                refractionDepth: 0.46,
                dispersion: 3.2,
                smoothCorners: true,
                nativeMaterial: MacosNativeGlassMaterial.popover,
                nativeModalOverlay: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      builder(ctx),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Drop-in Liquid Glass replacement for standard modal dialog containers.
class AppGlassDialog extends StatelessWidget {
  const AppGlassDialog({
    required this.child,
    this.radius = 34,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      child: LiquidGlassBatch.exclude(
        child: AppLiquidGlass(
          radius: radius,
          strongTint: true,
          refractionDepth: 0.46,
          dispersion: 3.2,
          smoothCorners: true,
          nativeMaterial: MacosNativeGlassMaterial.popover,
          nativeModalOverlay: true,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
