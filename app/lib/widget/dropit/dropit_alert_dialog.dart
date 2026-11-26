import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/macos_native_glass.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Retains Flutter's alert layout, intrinsic sizing, scrolling, action overflow
/// and route semantics inside a real-time optical Liquid Glass surface.
class DropitAlertDialog extends AlertDialog {
  const DropitAlertDialog({
    super.key,
    super.icon,
    super.title,
    super.titlePadding,
    super.titleTextStyle,
    super.content,
    super.contentPadding,
    super.contentTextStyle,
    super.actions,
    super.actionsPadding,
    super.actionsAlignment,
    super.actionsOverflowAlignment,
    super.actionsOverflowDirection,
    super.actionsOverflowButtonSpacing,
    super.buttonPadding,
    super.semanticLabel,
    super.insetPadding,
    super.constraints,
    super.alignment,
    super.scrollable,
  });

  @override
  Widget build(BuildContext context) {
    final layout = super.build(context);
    if (layout is! Dialog) return layout;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: layout.insetPadding,
      insetAnimationDuration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : layout.insetAnimationDuration,
      insetAnimationCurve: layout.insetAnimationCurve,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(34)),
      alignment: layout.alignment,
      constraints: layout.constraints,
      semanticsRole: layout.semanticsRole,
      child: LiquidGlassBatch.exclude(
        child: AppLiquidGlass(
          radius: 34,
          strongTint: true,
          refractionDepth: 0.46,
          dispersion: 3.2,
          smoothCorners: true,
          nativeMaterial: MacosNativeGlassMaterial.popover,
          nativeModalOverlay: true,
          child: layout.child!,
        ),
      ),
    );
  }
}
