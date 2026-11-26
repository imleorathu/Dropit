import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_press.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

enum AppGlassButtonVariant { glass, clear, tinted, tintedFilled, filled }

enum AppGlassButtonSize { sm, md, lg }

/// Interactive capsule Liquid Glass button with Mornye spring press physics,
/// pointer hover highlight, and optical chromatic edge refraction.
class AppGlassButton extends StatefulWidget {
  const AppGlassButton({
    this.variant = AppGlassButtonVariant.glass,
    this.size = AppGlassButtonSize.md,
    this.destructive = false,
    this.loading = false,
    this.tint,
    this.icon,
    this.label,
    this.child,
    this.onPressed,
    this.clarity,
    super.key,
  });

  final AppGlassButtonVariant variant;
  final AppGlassButtonSize size;
  final bool destructive;
  final bool loading;
  final Color? tint;
  final IconData? icon;
  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final double? clarity;

  @override
  State<AppGlassButton> createState() => _AppGlassButtonState();
}

class _AppGlassButtonState extends State<AppGlassButton> {
  bool _focused = false;

  bool get _isEnabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final config = AppGlassConfigScope.of(context);

    final enabled = _isEnabled;
    final height = switch (widget.size) {
      AppGlassButtonSize.sm => 36.0,
      AppGlassButtonSize.md => 44.0,
      AppGlassButtonSize.lg => 52.0,
    };
    final hPad = switch (widget.size) {
      AppGlassButtonSize.sm => 14.0,
      AppGlassButtonSize.md => 20.0,
      AppGlassButtonSize.lg => 26.0,
    };
    final fontSize = switch (widget.size) {
      AppGlassButtonSize.sm => 13.0,
      AppGlassButtonSize.md => 15.0,
      AppGlassButtonSize.lg => 16.5,
    };
    final iconSize = switch (widget.size) {
      AppGlassButtonSize.sm => 16.0,
      AppGlassButtonSize.md => 18.0,
      AppGlassButtonSize.lg => 20.0,
    };

    final baseAccent = widget.destructive ? CupertinoColors.systemRed.resolveFrom(context) : (widget.tint ?? scheme.primary);

    final Color? lensTint;
    final double? lensTintOpacity;
    final Color? hoverTintColor;
    final double hoverTintDelta;
    final bool strongTint;
    final Color fg;

    switch (widget.variant) {
      case AppGlassButtonVariant.filled:
        lensTint = baseAccent;
        lensTintOpacity = 0.78;
        hoverTintColor = baseAccent;
        hoverTintDelta = 0.10;
        strongTint = true;
        fg = Colors.white;
      case AppGlassButtonVariant.tintedFilled:
        lensTint = baseAccent;
        lensTintOpacity = dark ? 0.34 : 0.26;
        hoverTintColor = baseAccent;
        hoverTintDelta = 0.10;
        strongTint = true;
        fg = dark ? Colors.white : baseAccent;
      case AppGlassButtonVariant.tinted:
        lensTint = baseAccent;
        lensTintOpacity = dark ? 0.18 : 0.14;
        hoverTintColor = baseAccent;
        hoverTintDelta = dark ? 0.10 : 0.08;
        strongTint = false;
        fg = dark ? Color.lerp(baseAccent, Colors.white, 0.45)! : baseAccent;
      case AppGlassButtonVariant.clear:
        lensTint = null;
        lensTintOpacity = dark ? 0.08 : 0.14;
        hoverTintColor = dark ? scheme.surfaceContainerHigh : const Color(0xFFEAF1FF);
        hoverTintDelta = dark ? 0.16 : 0.14;
        strongTint = false;
        fg = widget.destructive ? baseAccent : scheme.onSurface;
      case AppGlassButtonVariant.glass:
        lensTint = null;
        lensTintOpacity = null;
        hoverTintColor = Colors.white;
        hoverTintDelta = dark ? 0.08 : 0.14;
        strongTint = false;
        fg = widget.destructive ? baseAccent : scheme.onSurface;
    }

    final iconOnly = (widget.icon != null || widget.loading) && widget.label == null && widget.child == null;

    return RepaintBoundary(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.label,
        child: FocusableActionDetector(
          enabled: enabled,
          onShowFocusHighlight: (focused) {
            if (_focused != focused) setState(() => _focused = focused);
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                if (enabled) widget.onPressed?.call();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (_) {
                if (enabled) widget.onPressed?.call();
                return null;
              },
            ),
          },
          child: MouseRegion(
            cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? widget.onPressed : null,
              child: AnimatedOpacity(
                duration: config.animateMotion ? const Duration(milliseconds: 120) : Duration.zero,
                opacity: enabled || widget.loading ? 1.0 : 0.48,
                child: AppGlassPress(
                  radius: 999,
                  enabled: enabled && config.animateMotion,
                  child: AppLiquidGlass(
                    radius: 999,
                    preset: DropitOpticalPreset.capsuleButton,
                    clarity: widget.clarity,
                    strongTint: strongTint,
                    tintColor: lensTint,
                    tintOpacity: lensTintOpacity,
                    refractionDepth: widget.variant == AppGlassButtonVariant.clear ? 0.18 : 0.34,
                    highlightIntensity: 1.0,
                    highlightBorder: widget.variant == AppGlassButtonVariant.tinted || widget.destructive,
                    focused: _focused && enabled,
                    focusColor: baseAccent,
                    nativeClear: widget.variant == AppGlassButtonVariant.glass || widget.variant == AppGlassButtonVariant.clear,
                    nativeInteractive: enabled,
                    child: _GlassButtonHoverOverlay(
                      hoverTintColor: hoverTintColor,
                      hoverTintDelta: hoverTintDelta,
                      dark: dark,
                      child: SizedBox(
                        height: height,
                        width: iconOnly ? height : null,
                        child: Padding(
                          padding: iconOnly ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: hPad),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (widget.loading)
                                SizedBox(
                                  width: iconSize,
                                  height: iconSize,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: fg,
                                  ),
                                )
                              else if (widget.icon != null)
                                Icon(widget.icon, size: iconSize, color: fg),
                              if ((widget.icon != null || widget.loading) && (widget.label != null || widget.child != null)) const SizedBox(width: 8),
                              if (widget.child != null)
                                Flexible(
                                  child: DefaultTextStyle(
                                    style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: fg),
                                    child: widget.child!,
                                  ),
                                )
                              else if (widget.label != null)
                                Flexible(
                                  child: Text(
                                    widget.label!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                      color: fg,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zero-rebuild hover & press tint/rim overlay driven directly by [AppGlassPress]'s
/// `ValueListenable<double>` progress notifier.
class _GlassButtonHoverOverlay extends StatelessWidget {
  const _GlassButtonHoverOverlay({
    required this.hoverTintColor,
    required this.hoverTintDelta,
    required this.dark,
    required this.child,
  });

  final Color hoverTintColor;
  final double hoverTintDelta;
  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final interaction = AppGlassPress.maybeOf(context);
    if (interaction == null) return child;
    return CustomPaint(
      foregroundPainter: _GlassButtonHoverPainter(
        progress: interaction.progress,
        hoverTintColor: hoverTintColor,
        hoverTintDelta: hoverTintDelta,
        dark: dark,
      ),
      child: child,
    );
  }
}

class _GlassButtonHoverPainter extends CustomPainter {
  _GlassButtonHoverPainter({
    required this.progress,
    required this.hoverTintColor,
    required this.hoverTintDelta,
    required this.dark,
  }) : super(repaint: progress);

  final ValueListenable<double> progress;
  final Color hoverTintColor;
  final double hoverTintDelta;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    if (p <= 0.01 || size.isEmpty) return;
    // Map hoverLevel (0.3) -> 1.0 hover factor, clamping smoothly under press overshoot.
    final t = (p / AppGlassPressState.hoverLevel).clamp(0.0, 1.15);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide * 0.5));
    canvas.save();
    canvas.clipRRect(rrect);
    if (hoverTintDelta > 0) {
      canvas.drawRRect(
        rrect,
        Paint()..color = hoverTintColor.withValues(alpha: (hoverTintDelta * t).clamp(0.0, 0.35)),
      );
    }
    final rimAlpha = ((dark ? 0.14 : 0.28) * t).clamp(0.0, 0.42);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.45), Radius.circular(size.shortestSide * 0.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85
        ..color = Colors.white.withValues(alpha: rimAlpha),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassButtonHoverPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.hoverTintColor != hoverTintColor ||
      oldDelegate.hoverTintDelta != hoverTintDelta ||
      oldDelegate.dark != dark;
}
