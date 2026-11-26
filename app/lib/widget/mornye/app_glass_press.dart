import 'dart:async';
import 'dart:math' as math;

import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/liquid_glass_motion.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Exposes live spring press/hover progress and pointer position from an
/// ancestor [AppGlassPress] so glass rims and highlights can respond at 120Hz
/// without rebuilding the widget subtree.
class AppGlassPressInteraction {
  const AppGlassPressInteraction({
    required this.progress,
    required this.pointer,
  });

  final ValueListenable<double> progress;
  final ValueListenable<Offset?> pointer;
}

class _AppGlassPressScope extends InheritedWidget {
  const _AppGlassPressScope({
    required this.interaction,
    required super.child,
  });

  final AppGlassPressInteraction interaction;

  @override
  bool updateShouldNotify(_AppGlassPressScope oldWidget) =>
      interaction.progress != oldWidget.interaction.progress || interaction.pointer != oldWidget.interaction.pointer;
}

class AppGlassPress extends StatefulWidget {
  const AppGlassPress({required this.radius, required this.child, this.enabled = true, super.key});

  final double radius;
  final Widget child;
  final bool enabled;

  static AppGlassPressInteraction? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_AppGlassPressScope>()?.interaction;
  }

  @override
  State<AppGlassPress> createState() => AppGlassPressState();
}

class AppGlassPressState extends State<AppGlassPress> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const pressSpring = SpringDescription(mass: 1, stiffness: 420, damping: 24);
  static const hoverLevel = 0.3;
  static final Matrix4 _identityMatrix = Matrix4.identity();

  late final AnimationController press;
  final drag = ValueNotifier<Offset>(Offset.zero);
  final pointerNotifier = ValueNotifier<Offset?>(null);
  late final Listenable motion = Listenable.merge([press, drag]);
  late final AppGlassPressInteraction _interaction = AppGlassPressInteraction(
    progress: press,
    pointer: pointerNotifier,
  );
  final Matrix4 _deformMatrixA = Matrix4.identity();
  final Matrix4 _deformMatrixB = Matrix4.identity();
  bool _useDeformA = false;
  LiquidGlassMemberHandle? _memberHandle;
  Offset? get pointer => pointerNotifier.value;
  set pointer(Offset? value) => pointerNotifier.value = value;
  Offset origin = Offset.zero;
  Size size = Size.zero;
  int? activePointer;
  bool hovered = false;

  @override
  void initState() {
    super.initState();
    // Eager initialization is intentional: disabled controls still dispose
    // cleanly even when their build path never reads the controller.
    press = AnimationController.unbounded(vsync: this);
    press.addListener(_onPressValueChanged);
    press.addStatusListener(_onPressStatusChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onPressValueChanged() {
    _memberHandle?.updateEnergy(press.value, localPointer: pointerNotifier.value);
  }

  void _onPressStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed || (press.value == 0.0 && !press.isAnimating)) {
      if (!hovered && activePointer == null) {
        if (pointer != null) pointer = null;
        if (drag.value != Offset.zero) drag.value = Offset.zero;
      }
    }
  }

  void _resetTransientInteraction({bool immediate = false}) {
    final hadInteraction = hovered || activePointer != null || pointer != null || drag.value != Offset.zero || press.value != 0 || press.isAnimating;
    hovered = false;
    activePointer = null;
    pointer = null;
    if (!hadInteraction) return;
    if (immediate || !mounted) {
      press.stop(canceled: true);
      if (drag.value != Offset.zero) drag.value = Offset.zero;
      if (press.value != 0.0) press.value = 0.0;
    } else {
      drag.value = Offset.zero;
      _settle();
    }
  }

  void _scheduleReset({bool immediate = false}) {
    hovered = false;
    activePointer = null;
    pointer = null;
    if (!press.isAnimating && press.value == 0.0 && drag.value == Offset.zero) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resetTransientInteraction(immediate: immediate);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _memberHandle = LiquidGlassMember.maybeOf(context);
    _memberHandle?.updateEnergy(press.value, localPointer: pointerNotifier.value);
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final motionAllowed = widget.enabled && AppGlassConfigScope.of(context).animateMotion;
    if (!motionAllowed || !routeCurrent) {
      _scheduleReset(immediate: !motionAllowed);
    }
  }

  @override
  void didUpdateWidget(AppGlassPress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _scheduleReset(immediate: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _resetTransientInteraction();
    }
  }

  @override
  void deactivate() {
    hovered = false;
    activePointer = null;
    pointer = null;
    if (press.isAnimating) {
      press.stop(canceled: true);
    }
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    press.removeListener(_onPressValueChanged);
    press.dispose();
    drag.dispose();
    pointerNotifier.dispose();
    super.dispose();
  }

  void _measure() {
    final box = context.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize) size = box.size;
  }

  void _settle() {
    if (!mounted) return;
    final target = activePointer != null
        ? 1.0
        : hovered
        ? hoverLevel
        : 0.0;
    if (MediaQuery.disableAnimationsOf(context) || !AppGlassConfigScope.of(context).animateMotion) {
      press.value = target;
      if (target == 0.0) {
        pointer = null;
        if (drag.value != Offset.zero) drag.value = Offset.zero;
      }
      return;
    }
    unawaited(
      press.animateWith(SpringSimulation(pressSpring, press.value, target, press.velocity, snapToEnd: true)).whenComplete(() {
        if (mounted && target == 0.0 && !hovered && activePointer == null) {
          if (pointer != null) pointer = null;
          if (drag.value != Offset.zero) drag.value = Offset.zero;
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = AppGlassConfigScope.of(context);
    if (!widget.enabled || !config.animateMotion) return widget.child;
    final still = MediaQuery.disableAnimationsOf(context);
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      opaque: false,
      onEnter: (event) {
        if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
        _measure();
        hovered = true;
        pointer = event.localPosition;
        _settle();
      },
      onHover: (event) {
        if (!hovered || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
        if (size.isEmpty) _measure();
        pointer = event.localPosition;
      },
      onExit: (_) {
        hovered = false;
        _settle();
      },
      child: Listener(
        onPointerDown: (event) {
          if (activePointer != null || !routeCurrent) return;
          _measure();
          activePointer = event.pointer;
          origin = event.localPosition;
          pointer = event.localPosition;
          drag.value = Offset.zero;
          _settle();
        },
        onPointerMove: (event) {
          if (event.pointer != activePointer) return;
          if (size.isEmpty) _measure();
          pointer = event.localPosition;
          drag.value = event.localPosition - origin;
        },
        onPointerUp: (event) {
          if (event.pointer != activePointer) return;
          activePointer = null;
          _settle();
        },
        onPointerCancel: (event) {
          if (event.pointer != activePointer) return;
          activePointer = null;
          _settle();
        },
        child: AnimatedBuilder(
          animation: motion,
          child: _AppGlassPressScope(
            interaction: _interaction,
            child: widget.child,
          ),
          builder: (context, child) {
            if (size.isEmpty) _measure();
            final strength = press.value.clamp(0.0, 1.0);
            return Transform(
              alignment: Alignment.center,
              transform: still || size.isEmpty || press.value == 0 ? _identityMatrix : _deformation(press.value),
              transformHitTests: false,
              child: CustomPaint(
                foregroundPainter: _GlassLightPainter(
                  center: pointerNotifier,
                  strength: strength,
                  radius: widget.radius,
                  dark: dark,
                ),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }

  Matrix4 _deformation(double amount) {
    final swell = (size.shortestSide * 0.10).clamp(2.0, 5.0) * amount;
    var scaleX = 1 + swell / size.width;
    var scaleY = 1 + swell / size.height;
    final lean = Offset((drag.value.dx / 40).clamp(-1.0, 1.0), (drag.value.dy / 40).clamp(-1.0, 1.0));
    final bias = math.max(amount, 0.0);
    scaleX += (lean.dx.abs() * 0.05 - lean.dy.abs() * 0.025) * bias;
    scaleY += (lean.dy.abs() * 0.05 - lean.dx.abs() * 0.025) * bias;
    _useDeformA = !_useDeformA;
    final m = _useDeformA ? _deformMatrixA : _deformMatrixB;
    return m
      ..setIdentity()
      ..translateByDouble(lean.dx * 3 * bias, lean.dy * 3 * bias, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1);
  }
}

class _GlassLightPainter extends CustomPainter {
  const _GlassLightPainter({
    required this.center,
    required this.strength,
    required this.radius,
    required this.dark,
  }) : super(repaint: center);

  final ValueListenable<Offset?> center;
  final double strength;
  final double radius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0 || size.isEmpty) return;
    final bounds = Offset.zero & size;
    final maxR = math.min(size.width, size.height) * 0.5;
    final clampedR = radius.clamp(0.0, maxR);
    final rrect = RRect.fromRectAndRadius(bounds, Radius.circular(clampedR));
    final focusCenter = center.value ?? bounds.center;
    final glowRadius = size.longestSide.clamp(42.0, 180.0);

    canvas
      ..save()
      ..clipRRect(rrect)
      ..drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: (dark ? 0.16 : 0.24) * strength),
              Colors.white.withValues(alpha: (dark ? 0.04 : 0.08) * strength),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: focusCenter, radius: glowRadius)),
      );

    // Subtle pointer-reactive optical sidewall pickup on rounded rims.
    if (center.value != null) {
      final rimRRect = RRect.fromRectAndRadius(
        bounds.deflate(0.45),
        Radius.circular(math.max(0.0, clampedR - 0.45)),
      );
      canvas.drawRRect(
        rimRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: (dark ? 0.34 : 0.52) * strength),
              Colors.white.withValues(alpha: (dark ? 0.08 : 0.14) * strength),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: focusCenter, radius: (glowRadius * 0.85).clamp(28.0, 130.0))),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassLightPainter oldDelegate) =>
      center != oldDelegate.center || strength != oldDelegate.strength || radius != oldDelegate.radius || dark != oldDelegate.dark;
}
