import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_press.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Shared Apple Liquid Glass capsule thumb used by [DropitSlider] and
/// [DropitSwitch].
///
/// At rest (or when [solidIdleFill] is true and [glassMorph] is zero), the
/// thumb keeps a crisp solid/frosted pill body. On hover, press, drag, or
/// toggle flight, it elastically stretches and morphs into a clear refractive
/// optical lens backed by [LiquidGlassLens] on Impeller with calibrated specular
/// and chromatic highlights.
class _LiquidGlassControlThumb extends StatelessWidget {
  const _LiquidGlassControlThumb({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.interaction,
    required this.glassMorph,
    required this.scaleX,
    required this.scaleY,
    required this.accentColor,
    required this.focused,
    required this.enabled,
    this.solidIdleFill = false,
    this.direction = 0.0,
    this.androidSwitch = false,
  });

  final double width;
  final double height;
  final double borderRadius;
  final double interaction;
  final double glassMorph;
  final double scaleX;
  final double scaleY;
  final Color accentColor;
  final bool focused;
  final bool enabled;
  final bool solidIdleFill;
  final double direction;
  final bool androidSwitch;

  @override
  Widget build(BuildContext context) {
    final config = AppGlassConfigScope.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final morph = androidSwitch && config.effectiveQuality == AppGlassQuality.flat ? 0.0 : glassMorph.clamp(0.0, 1.0);
    final pressT = interaction.clamp(0.0, 1.0);
    final shaderSupported = AppLiquidGlass.isShaderFilterSupported;
    final useShaderLens =
        morph > 0.04 && shaderSupported && config.effectiveQuality == AppGlassQuality.liquid && !config.highContrast && config.clarity > 0.08;

    final opticalAndroid = androidSwitch && config.effectiveQuality != AppGlassQuality.flat && !config.highContrast;
    final thumbFillColor = (solidIdleFill && morph <= 0.01)
        ? Colors.white
        : Colors.white.withValues(
            alpha: useShaderLens
                ? ui.lerpDouble(dark ? 0.88 : 0.96, 0.05, morph)!
                : (solidIdleFill ? ui.lerpDouble(1.0, dark ? 0.24 : 0.34, morph)! : ui.lerpDouble(dark ? 0.94 : 0.98, dark ? 0.18 : 0.28, morph)!),
          );

    final shadows = config.highContrast
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: ui.lerpDouble(dark ? 0.30 : 0.16, dark ? 0.42 : 0.22, math.max(pressT, morph))!,
              ),
              blurRadius: ui.lerpDouble(5.5, 11.0, math.max(pressT, morph))!,
              spreadRadius: ui.lerpDouble(0.0, 0.5, morph)!,
              offset: Offset(0, ui.lerpDouble(1.5, 3.0, math.max(pressT, morph))!),
            ),
          ];

    Widget core = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: opticalAndroid && morph > 0.01 ? null : thumbFillColor,
        // Keep a visible glass body on the frosted/software-renderer path too.
        // These reflections use the same motion value as the lens and thumb.
        gradient: opticalAndroid && morph > 0.01
            ? LinearGradient(
                begin: Alignment(-0.8 + direction * 0.2, -1),
                end: Alignment(0.8 + direction * 0.2, 1),
                colors: [
                  Colors.white.withValues(alpha: ui.lerpDouble(1, 0.88, morph)!),
                  Colors.white.withValues(alpha: ui.lerpDouble(1, useShaderLens ? 0.10 : 0.38, morph)!),
                  accentColor.withValues(alpha: 0.14 * morph),
                  Colors.white.withValues(alpha: ui.lerpDouble(1, 0.72, morph)!),
                ],
                stops: const [0, 0.36, 0.70, 1],
              )
            : null,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );

    if (opticalAndroid && morph > 0.01) {
      core = CustomPaint(
        foregroundPainter: _SwitchCausticPainter(morph: morph, direction: direction),
        child: core,
      );
    }

    if (useShaderLens) {
      final spec = DropitOpticalGlassSpec.resolve(
        config: config,
        preset: DropitOpticalPreset.capsuleButton,
        clarityOverride: 1.0,
        radiusOverride: borderRadius,
        blurSigmaOverride: config.glassFrost > 0.01 ? (0.35 + config.glassFrost * 2.4) : 0.25,
      );
      final disp = config.dispersion <= 0.005 ? 0.0 : ((2.6 + 1.4 * morph) * (config.dispersion / 1.32)).clamp(0.0, 14.0);
      core = LiquidGlassBatch.exclude(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: LiquidGlassLens(
            style: spec.toShaderStyle(
              brightness: theme.brightness,
              radius: borderRadius,
              smoothCorners: true,
              widthOverride: (height * 0.48).clamp(5.0, 12.0),
              tintColor: Colors.white.withValues(alpha: dark ? 0.06 : 0.10),
              outlines: config.outlines,
              depthOverride: 0.44 + 0.24 * morph,
              bendScale: 0.95 + 0.45 * morph,
              dispersionOverride: usesAndroidMornye ? disp.clamp(0.0, 0.65) : disp,
            ),
            child: core,
          ),
        ),
      );
    }

    // Add optical specular highlight & focus halo cleanly around the pill silhouette.
    final highlightAlpha = (!solidIdleFill || morph > 0.01 || pressT > 0.01 || focused) ? (0.95 + 0.55 * pressT + 0.50 * morph) : 0.0;

    if (highlightAlpha > 0 && (config.outlines || focused)) {
      core = CustomPaint(
        foregroundPainter: DropitGlassHighlight(
          radius: borderRadius,
          brightness: theme.brightness,
          refractionIntensity: config.refractionIntensity,
          clarity: config.clarity,
          edgeThickness: 3.6 + morph * 1.4,
          emphasis: highlightAlpha,
          smoothCorners: true,
          focused: focused && enabled,
          focusColor: accentColor,
        ),
        child: core,
      );
    }

    if (shadows.isNotEmpty) {
      core = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: shadows,
        ),
        child: core,
      );
    }

    if ((scaleX - 1.0).abs() > 0.001 || (scaleY - 1.0).abs() > 0.001) {
      core = Transform.scale(
        scaleX: scaleX,
        scaleY: scaleY,
        alignment: Alignment.center,
        child: core,
      );
    }

    return core;
  }
}

/// Small clipped optical reflections; no timers, backdrop capture or idle work.
class _SwitchCausticPainter extends CustomPainter {
  const _SwitchCausticPainter({required this.morph, required this.direction});

  final double morph;
  final double direction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)));
    final reflection = Rect.fromLTWH(size.width * (0.15 + 0.22 * direction), 0, size.width * 0.62, size.height);
    canvas.drawRect(
      reflection,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.55 * morph),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(reflection),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.7), Radius.circular(size.height / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95 * morph),
            Colors.white.withValues(alpha: 0.1 * morph),
            Colors.white.withValues(alpha: 0.7 * morph),
          ],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SwitchCausticPainter oldDelegate) => morph != oldDelegate.morph || direction != oldDelegate.direction;
}

/// Apple Liquid Glass capsule toggle switch preserving Dropit geometry (`63x28`
/// track, `37x24` idle thumb, `22` px travel, `#34C759` active track) while
/// adding hover optical lift, spring-driven elastic stretching, and real
/// crystal glass morphing during drag and toggle transitions.
class DropitSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final FocusNode? focusNode;
  final bool autofocus;

  const DropitSwitch({
    required this.value,
    required this.onChanged,
    this.label,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  @override
  State<DropitSwitch> createState() => _DropitSwitchState();
}

class _DropitSwitchState extends State<DropitSwitch> with TickerProviderStateMixin {
  static const double _trackWidth = 63.0;
  static const double _trackHeight = 28.0;
  static const double _trackPadding = 2.0;
  static const double _thumbWidth = 37.0;
  static const double _thumbHeight = 24.0;
  static const double _travelSpan = _trackWidth - _trackPadding * 2 - _thumbWidth; // 22.0

  late final AnimationController _positionController;
  late final AnimationController _interactionController;
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;
  bool _dragging = false;
  double? _dragStartValue;
  double _dragDistance = 0.0;
  double? _positionTarget;

  double get _textDirection => Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

  @override
  void initState() {
    super.initState();
    _positionController = AnimationController.unbounded(
      vsync: this,
      value: widget.value ? 1.0 : 0.0,
    );
    _interactionController = AnimationController.unbounded(
      vsync: this,
      value: 0.0,
    );
  }

  @override
  void didUpdateWidget(DropitSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_dragging) {
      _animatePosition(widget.value ? 1.0 : 0.0);
    }
    if (widget.onChanged == null) {
      _hovered = false;
      _pressed = false;
      _dragging = false;
      _animatePosition(widget.value ? 1.0 : 0.0);
      _settleInteraction(immediate: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animateMotion) {
      _positionController.value = widget.value ? 1.0 : 0.0;
      _interactionController.value = 0;
    }
  }

  @override
  void dispose() {
    _positionController.dispose();
    _interactionController.dispose();
    super.dispose();
  }

  bool get _animateMotion {
    final config = AppGlassConfigScope.maybeOf(context);
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return !disable && (config?.animateMotion ?? true);
  }

  void _animatePosition(double target) {
    if (!mounted) return;
    if (!_animateMotion) {
      _positionController.value = target;
      _positionTarget = target;
      return;
    }
    if (_positionTarget == target && _positionController.isAnimating) return;
    _positionTarget = target;
    unawaited(
      _positionController.animateWith(
        SpringSimulation(
          kDropitSelectionGlideSpring,
          _positionController.value,
          target,
          _positionController.velocity,
          snapToEnd: true,
        ),
      ),
    );
  }

  void _settleInteraction({bool immediate = false}) {
    if (!mounted) return;
    final target = (_pressed || _dragging)
        ? 1.0
        : _hovered
        ? AppGlassPressState.hoverLevel
        : 0.0;
    if (immediate || !_animateMotion) {
      _interactionController.value = target;
      return;
    }
    unawaited(
      _interactionController.animateWith(
        SpringSimulation(
          AppGlassPressState.pressSpring,
          _interactionController.value,
          target,
          _interactionController.velocity,
          snapToEnd: true,
        ),
      ),
    );
  }

  void _pulseToggle() {
    final next = !widget.value;
    widget.onChanged?.call(next);
    if (_animateMotion && !usesAndroidMornye) {
      // Brief glass morph peak as the thumb glides across the capsule.
      _interactionController.value = math.max(_interactionController.value, 0.85);
      _settleInteraction();
    }
    _animatePosition(next ? 1.0 : 0.0);
  }

  void _onDragStart(DragStartDetails details) {
    if (widget.onChanged == null) return;
    _dragging = true;
    _pressed = true;
    _positionController.stop();
    _positionTarget = null;
    _dragStartValue = _positionController.value.clamp(0.0, 1.0);
    _dragDistance = 0.0;
    _settleInteraction();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging || widget.onChanged == null) return;
    _dragDistance += (details.primaryDelta ?? 0.0) * _textDirection;
    final base = _dragStartValue ?? (widget.value ? 1.0 : 0.0);
    final nextPos = (base + _dragDistance / _travelSpan).clamp(0.0, 1.0);
    _positionController.value = nextPos;
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    final vx = details.velocity.pixelsPerSecond.dx * _textDirection;
    final current = _positionController.value;
    final movedEnough = _dragDistance.abs() > 3.0;
    final next = !movedEnough
        ? !widget.value
        : vx.abs() > 140
        ? vx > 0
        : current >= 0.5;
    _dragging = false;
    _pressed = false;
    _dragStartValue = null;
    if (next != widget.value) {
      widget.onChanged?.call(next);
    }
    _animatePosition(next ? 1.0 : 0.0);
    _settleInteraction();
  }

  void _onDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _pressed = false;
    _dragStartValue = null;
    _animatePosition(widget.value ? 1.0 : 0.0);
    _settleInteraction();
  }

  @override
  Widget build(BuildContext context) {
    final config = AppGlassConfigScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = widget.onChanged != null;
    final activeColor = const Color(0xFF34C759);
    final inactiveColor = usesAndroidMornye
        ? (theme.brightness == Brightness.dark ? const Color(0xFF39393D) : const Color(0xFF8E8E93))
        : scheme.onSurface.withValues(alpha: theme.brightness == Brightness.dark ? 0.24 : 0.16);
    final trackDuration = _animateMotion ? const Duration(milliseconds: 180) : Duration.zero;

    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      label: widget.label,
      onTap: enabled ? _pulseToggle : null,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowFocusHighlight: (focused) {
          if (_focused != focused) setState(() => _focused = focused);
        },
        onShowHoverHighlight: (hovered) {
          if (_hovered != hovered) {
            setState(() => _hovered = hovered);
            _settleInteraction();
          }
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (!enabled) return null;
              _pulseToggle();
              return null;
            },
          ),
        },
        child: Listener(
          onPointerDown: enabled
              ? (_) {
                  _pressed = true;
                  _settleInteraction();
                }
              : null,
          onPointerUp: enabled
              ? (_) {
                  if (!_dragging) {
                    _pressed = false;
                    _settleInteraction();
                  }
                }
              : null,
          onPointerCancel: enabled
              ? (_) {
                  if (_dragging) {
                    _onDragCancel();
                  } else {
                    _pressed = false;
                    _settleInteraction();
                  }
                }
              : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onTap: enabled
                ? () {
                    _pressed = false;
                    _pulseToggle();
                  }
                : null,
            onHorizontalDragStart: enabled ? _onDragStart : null,
            onHorizontalDragUpdate: enabled ? _onDragUpdate : null,
            onHorizontalDragEnd: enabled ? _onDragEnd : null,
            onHorizontalDragCancel: enabled ? _onDragCancel : null,
            child: SizedBox(
              width: usesAndroidMornye ? 71 : _trackWidth,
              height: usesAndroidMornye ? 48 : _trackHeight,
              child: Center(
                child: AnimatedOpacity(
                  duration: trackDuration,
                  opacity: enabled ? 1.0 : 0.45,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_positionController, _interactionController]),
                    builder: (context, _) {
                      final pos = _positionController.value.clamp(0.0, 1.0);
                      final interact = enabled && _animateMotion ? _interactionController.value.clamp(0.0, 1.0) : 0.0;
                      final motionSpeed = (_positionController.velocity.abs() / 6.0).clamp(0.0, 1.0);
                      final flight = usesAndroidMornye && _positionController.isAnimating && _animateMotion ? math.sin(math.pi * pos) : 0.0;
                      final morph = enabled && _animateMotion
                          ? math
                                .max(
                                  _dragging || _pressed ? interact : interact * 0.65,
                                  math.max(motionSpeed * 0.90, flight),
                                )
                                .clamp(0.0, 1.0)
                          : 0.0;
                      final settleReady = !enabled || (interact <= 0.01 && motionSpeed <= 0.01 && !_dragging && !_pressed);
                      final trackColor = settleReady ? (pos >= 0.5 ? activeColor : inactiveColor) : Color.lerp(inactiveColor, activeColor, pos)!;

                      final stretchX = 1.0 + 0.14 * interact + 0.10 * motionSpeed;
                      final stretchY = 1.0 + (usesAndroidMornye ? 0.06 : 0.12) * interact - 0.03 * motionSpeed;

                      return SizedBox(
                        width: _trackWidth,
                        height: _trackHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            AnimatedContainer(
                              // Position and color follow one spring. A second implicit
                              // color animation here trails every drag/reversal frame.
                              duration: usesAndroidMornye || _dragging ? Duration.zero : trackDuration,
                              width: _trackWidth,
                              height: _trackHeight,
                              padding: const EdgeInsets.all(_trackPadding),
                              decoration: BoxDecoration(
                                color: trackColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Align(
                                alignment: AlignmentDirectional(-1.0 + pos * 2.0, 0.0),
                                child: _LiquidGlassControlThumb(
                                  width: _thumbWidth,
                                  height: _thumbHeight,
                                  borderRadius: 12,
                                  interaction: interact,
                                  glassMorph: morph,
                                  scaleX: stretchX,
                                  scaleY: stretchY,
                                  accentColor: scheme.primary,
                                  focused: _focused,
                                  enabled: enabled,
                                  solidIdleFill: true,
                                  androidSwitch: usesAndroidMornye,
                                  direction: (pos * 2 - 1) * _textDirection,
                                ),
                              ),
                            ),
                            if (config.outlines || _focused)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _focused
                                            ? Color.lerp(Colors.white, scheme.primary, 0.55)!.withValues(alpha: 0.9)
                                            : Colors.white.withValues(alpha: pos >= 0.5 ? 0.24 : (theme.brightness == Brightness.dark ? 0.16 : 0.36)),
                                        width: _focused ? 1.5 : 0.75,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
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

/// Apple Liquid Glass range slider supporting smooth continuous and discrete
/// (`divisions`) tracking, keyboard adjustment shortcuts, hover elevation,
/// velocity-elastic thumb stretch, and live refractive crystal thumb morphing.
class DropitSlider extends StatefulWidget {
  const DropitSlider({
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    this.semanticFormatterCallback,
    this.activeColor,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final SemanticFormatterCallback? semanticFormatterCallback;
  final Color? activeColor;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<DropitSlider> createState() => _DropitSliderState();
}

class _DropitSliderState extends State<DropitSlider> with TickerProviderStateMixin {
  static const double _controlHeight = 36.0;
  static const double _trackHeight = 6.0;
  static const double _thumbWidth = 34.0;
  static const double _thumbHeight = 20.0;

  late final AnimationController _interactionController;
  late final AnimationController _stretchController;

  bool _hovered = false;
  bool _focused = false;
  bool _dragging = false;
  bool _gestureActive = false;
  double _lastValue = 0.0;

  @override
  void initState() {
    super.initState();
    _interactionController = AnimationController.unbounded(vsync: this, value: 0.0);
    _stretchController = AnimationController.unbounded(vsync: this, value: 0.0);
    _lastValue = _clampValue(widget.value);
  }

  @override
  void didUpdateWidget(DropitSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lastValue = _clampValue(widget.value);
    if (widget.onChanged == null) {
      _hovered = false;
      _dragging = false;
      _gestureActive = false;
      _settleInteraction(immediate: true);
      _settleStretch(immediate: true);
    }
  }

  @override
  void dispose() {
    _interactionController.dispose();
    _stretchController.dispose();
    super.dispose();
  }

  bool get _animateMotion {
    final config = AppGlassConfigScope.maybeOf(context);
    final disable = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return !disable && (config?.animateMotion ?? true);
  }

  double _clampValue(double raw) => widget.max > widget.min ? raw.clamp(widget.min, widget.max).toDouble() : widget.min;

  double _fractionForValue(double raw) {
    if (widget.max <= widget.min) return 0.0;
    return ((_clampValue(raw) - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
  }

  double _quantize(double raw) {
    final clamped = _clampValue(raw);
    final divs = widget.divisions;
    if (divs == null || divs <= 0 || widget.max <= widget.min) return clamped;
    final t = ((clamped - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    final snapped = (t * divs).round() / divs;
    return (widget.min + snapped * (widget.max - widget.min)).clamp(widget.min, widget.max).toDouble();
  }

  void _settleInteraction({bool immediate = false}) {
    if (!mounted) return;
    final target = _dragging
        ? 1.0
        : _hovered
        ? AppGlassPressState.hoverLevel
        : 0.0;
    if (immediate || !_animateMotion) {
      _interactionController.value = target;
      return;
    }
    unawaited(
      _interactionController.animateWith(
        SpringSimulation(
          AppGlassPressState.pressSpring,
          _interactionController.value,
          target,
          _interactionController.velocity,
          snapToEnd: true,
        ),
      ),
    );
  }

  void _settleStretch({bool immediate = false}) {
    if (!mounted) return;
    if (immediate || !_animateMotion) {
      _stretchController.value = 0.0;
      return;
    }
    unawaited(
      _stretchController.animateWith(
        SpringSimulation(
          kDropitOpticalSpring,
          _stretchController.value,
          0.0,
          _stretchController.velocity,
          snapToEnd: true,
        ),
      ),
    );
  }

  void _emitFromLocalX(double localDx, double totalWidth, {double deltaDx = 0.0}) {
    if (widget.onChanged == null || totalWidth <= 0) return;
    final halfThumb = _thumbWidth * 0.5;
    final usable = math.max(1.0, totalWidth - _thumbWidth);
    final t = ((localDx - halfThumb) / usable).clamp(0.0, 1.0);
    final next = _quantize(widget.min + t * (widget.max - widget.min));
    if (deltaDx.abs() > 0.2 && _animateMotion) {
      final impulse = (deltaDx.abs() / 16.0).clamp(0.0, 1.0);
      _stretchController.value = ui.lerpDouble(_stretchController.value, impulse, 0.45)!;
    }
    if ((next - _lastValue).abs() > 1e-9 || (next - widget.value).abs() > 1e-9) {
      _lastValue = next;
      widget.onChanged?.call(next);
    }
  }

  void _stepBy(double deltaFraction) {
    if (widget.onChanged == null || widget.max <= widget.min) return;
    final current = _clampValue(widget.value);
    final step = deltaFraction * (widget.max - widget.min);
    final next = _quantize(current + step);
    widget.onChangeStart?.call(current);
    if ((next - widget.value).abs() > 1e-9) {
      widget.onChanged?.call(next);
    }
    widget.onChangeEnd?.call(next);
    if (_animateMotion) {
      _interactionController.value = math.max(_interactionController.value, 0.72);
      _stretchController.value = 0.38;
      _settleInteraction();
      _settleStretch();
    }
  }

  void _jumpTo(double targetValue) {
    if (widget.onChanged == null) return;
    final current = _clampValue(widget.value);
    final next = _quantize(targetValue);
    widget.onChangeStart?.call(current);
    if ((next - widget.value).abs() > 1e-9) {
      widget.onChanged?.call(next);
    }
    widget.onChangeEnd?.call(next);
  }

  void _beginGesture(double clamped) {
    if (!_gestureActive) {
      _gestureActive = true;
      widget.onChangeStart?.call(clamped);
    }
    _dragging = true;
    _settleInteraction();
  }

  void _endGesture() {
    if (_gestureActive) {
      _gestureActive = false;
      widget.onChangeEnd?.call(_clampValue(widget.value));
    }
    _dragging = false;
    _settleInteraction();
    _settleStretch();
  }

  String _formatSemanticValue(double val) {
    if (widget.semanticFormatterCallback != null) {
      return widget.semanticFormatterCallback!(val);
    }
    return widget.label ?? val.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final config = AppGlassConfigScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final enabled = widget.onChanged != null;
    final accent = widget.activeColor ?? scheme.primary;
    final clamped = _clampValue(widget.value);
    final fraction = _fractionForValue(clamped);
    final stepFraction = (widget.divisions != null && widget.divisions! > 0) ? 1.0 / widget.divisions! : 0.05;
    final increaseVal = _quantize(clamped + stepFraction * (widget.max - widget.min));
    final decreaseVal = _quantize(clamped - stepFraction * (widget.max - widget.min));

    return Semantics(
      slider: true,
      enabled: enabled,
      value: _formatSemanticValue(clamped),
      increasedValue: _formatSemanticValue(increaseVal),
      decreasedValue: _formatSemanticValue(decreaseVal),
      onIncrease: enabled ? () => _stepBy(stepFraction) : null,
      onDecrease: enabled ? () => _stepBy(-stepFraction) : null,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: enabled ? SystemMouseCursors.grab : SystemMouseCursors.basic,
        onShowFocusHighlight: (focused) {
          if (_focused != focused) setState(() => _focused = focused);
        },
        onShowHoverHighlight: (hovered) {
          if (_hovered != hovered) {
            setState(() => _hovered = hovered);
            _settleInteraction();
          }
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowRight): _SliderAdjustIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowUp): _SliderAdjustIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _SliderAdjustIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _SliderAdjustIntent(-1),
          SingleActivator(LogicalKeyboardKey.pageUp): _SliderAdjustIntent(4),
          SingleActivator(LogicalKeyboardKey.pageDown): _SliderAdjustIntent(-4),
          SingleActivator(LogicalKeyboardKey.home): _SliderBoundaryIntent(isEnd: false),
          SingleActivator(LogicalKeyboardKey.end): _SliderBoundaryIntent(isEnd: true),
        },
        actions: <Type, Action<Intent>>{
          _SliderAdjustIntent: CallbackAction<_SliderAdjustIntent>(
            onInvoke: (intent) {
              _stepBy(stepFraction * intent.steps);
              return null;
            },
          ),
          _SliderBoundaryIntent: CallbackAction<_SliderBoundaryIntent>(
            onInvoke: (intent) {
              _jumpTo(intent.isEnd ? widget.max : widget.min);
              return null;
            },
          ),
        },
        child: AnimatedOpacity(
          duration: _animateMotion ? const Duration(milliseconds: 140) : Duration.zero,
          opacity: enabled ? 1.0 : 0.45,
          child: SizedBox(
            height: _controlHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 240.0;
                final halfThumb = _thumbWidth * 0.5;
                final trackLeft = halfThumb;
                final trackWidth = math.max(1.0, totalWidth - _thumbWidth);
                final thumbCenterX = trackLeft + fraction * trackWidth;

                return Listener(
                  onPointerDown: enabled
                      ? (details) {
                          _beginGesture(clamped);
                          _emitFromLocalX(details.localPosition.dx, totalWidth);
                        }
                      : null,
                  onPointerUp: enabled ? (_) => _endGesture() : null,
                  onPointerCancel: enabled ? (_) => _endGesture() : null,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onTapUp: enabled ? (_) => _endGesture() : null,
                    onHorizontalDragStart: enabled
                        ? (details) {
                            _beginGesture(clamped);
                            _emitFromLocalX(details.localPosition.dx, totalWidth);
                          }
                        : null,
                    onHorizontalDragUpdate: enabled
                        ? (details) => _emitFromLocalX(
                            details.localPosition.dx,
                            totalWidth,
                            deltaDx: details.delta.dx,
                          )
                        : null,
                    onHorizontalDragEnd: enabled ? (_) => _endGesture() : null,
                    onHorizontalDragCancel: enabled ? _endGesture : null,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_interactionController, _stretchController]),
                      builder: (context, _) {
                        final interact = enabled ? _interactionController.value.clamp(0.0, 1.0) : 0.0;
                        final stretch = enabled ? _stretchController.value.clamp(0.0, 1.0) : 0.0;
                        final activeGlass = (_dragging ? math.max(interact, 0.88) : interact * 0.55).clamp(0.0, 1.0);
                        final scaleX = 1.0 + 0.16 * interact + 0.12 * stretch;
                        final scaleY = 1.0 + 0.15 * interact - 0.04 * stretch;

                        return Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.centerLeft,
                          children: [
                            Positioned(
                              left: trackLeft,
                              right: trackLeft,
                              child: _SliderTrack(
                                height: _trackHeight,
                                fraction: fraction,
                                accentColor: accent,
                                dark: dark,
                                divisions: widget.divisions,
                                showOutlines: config.outlines,
                              ),
                            ),
                            Positioned(
                              left: thumbCenterX - halfThumb,
                              child: _LiquidGlassControlThumb(
                                width: _thumbWidth,
                                height: _thumbHeight,
                                borderRadius: _thumbHeight * 0.5,
                                interaction: interact,
                                glassMorph: activeGlass,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                accentColor: accent,
                                focused: _focused,
                                enabled: enabled,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SliderTrack extends StatelessWidget {
  const _SliderTrack({
    required this.height,
    required this.fraction,
    required this.accentColor,
    required this.dark,
    required this.divisions,
    required this.showOutlines,
  });

  final double height;
  final double fraction;
  final Color accentColor;
  final bool dark;
  final int? divisions;
  final bool showOutlines;

  @override
  Widget build(BuildContext context) {
    final trackBase = Colors.white.withValues(alpha: dark ? 0.14 : 0.36);
    final rimColor = Colors.white.withValues(alpha: dark ? 0.14 : 0.42);
    final showTicks = divisions != null && divisions! > 1 && divisions! <= 25;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: trackBase,
        borderRadius: BorderRadius.circular(height * 0.5),
        border: showOutlines ? Border.all(color: rimColor, width: 0.5) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height * 0.5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                heightFactor: 1.0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.86),
                        Color.lerp(accentColor, Colors.white, 0.16)!,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (showTicks)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i <= divisions!; i++)
                    Container(
                      width: 2.2,
                      height: 2.2,
                      margin: EdgeInsets.only(
                        left: i == 0 ? 3.0 : 0.0,
                        right: i == divisions! ? 3.0 : 0.0,
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (i / divisions! <= fraction)
                            ? Colors.white.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: dark ? 0.24 : 0.45),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SliderAdjustIntent extends Intent {
  const _SliderAdjustIntent(this.steps);
  final int steps;
}

class _SliderBoundaryIntent extends Intent {
  const _SliderBoundaryIntent({required this.isEnd});
  final bool isEnd;
}
