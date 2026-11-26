import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Current optical interaction phase of a Liquid Glass element.
enum GlassInteractionPhase {
  idle,
  hovered,
  pressed,
  dragging,
  morphing,
}

/// Snapshot describing interactive fluid deformation and optical energy for a
/// Liquid Glass control or selection capsule.
@immutable
class GlassInteractionState {
  const GlassInteractionState({
    this.energy = 0.0,
    this.phase = GlassInteractionPhase.idle,
    this.localPointer,
    this.stretch = Offset.zero,
    this.bridgeReach = 18.0,
  });

  static const GlassInteractionState idle = GlassInteractionState();

  final double energy;
  final GlassInteractionPhase phase;
  final Offset? localPointer;
  final Offset stretch;
  final double bridgeReach;

  bool get isActive => energy > 0.008 || stretch.distanceSquared > 0.0001;

  GlassInteractionState copyWith({
    double? energy,
    GlassInteractionPhase? phase,
    Offset? localPointer,
    bool clearPointer = false,
    Offset? stretch,
    double? bridgeReach,
  }) => GlassInteractionState(
    energy: energy ?? this.energy,
    phase: phase ?? this.phase,
    localPointer: clearPointer ? null : (localPointer ?? this.localPointer),
    stretch: stretch ?? this.stretch,
    bridgeReach: bridgeReach ?? this.bridgeReach,
  );

  static GlassInteractionState lerp(GlassInteractionState a, GlassInteractionState b, double t) {
    final clamped = t.clamp(0.0, 1.0);
    return GlassInteractionState(
      energy: lerpDouble(a.energy, b.energy, clamped) ?? b.energy,
      phase: clamped < 0.5 ? a.phase : b.phase,
      localPointer: Offset.lerp(a.localPointer, b.localPointer, clamped),
      stretch: Offset.lerp(a.stretch, b.stretch, clamped) ?? b.stretch,
      bridgeReach: lerpDouble(a.bridgeReach, b.bridgeReach, clamped) ?? b.bridgeReach,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlassInteractionState &&
      other.energy == energy &&
      other.phase == phase &&
      other.localPointer == localPointer &&
      other.stretch == stretch &&
      other.bridgeReach == bridgeReach;

  @override
  int get hashCode => Object.hash(energy, phase, localPointer, stretch, bridgeReach);
}

/// Pure geometry and liquid-bridge interpolation helpers shared by morphing
/// indicators and grouped [LiquidGlassContainer] surfaces.
abstract final class GlassGeometryInterpolator {
  /// Smooth Hermite easing used across specular ramps and bridge necks.
  static double smoothCubic(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * (3.0 - 2.0 * x);
  }

  /// Interpolates two rounded radii smoothly while guarding degenerate bounds.
  static double lerpRadius(double a, double b, double t) => math.max(0.0, lerpDouble(a, b, t) ?? b);

  /// Continuously interpolates [a] to [b] while adding subtle elastic liquid
  /// elongation along the axis of travel proportional to remaining velocity /
  /// mid-flight travel progress.
  static Rect lerpRect(
    Rect a,
    Rect b,
    double t, {
    double stretchStrength = 0.0,
  }) {
    final base = Rect.lerp(a, b, t) ?? b;
    if (stretchStrength <= 0.001) return base;
    // Peak mid-transition (sin pi * t) and vanish smoothly at both endpoints.
    final flightBell = math.sin(t.clamp(0.0, 1.0) * math.pi).clamp(0.0, 1.0);
    final delta = b.center - a.center;
    final horizontalBias = delta.dx.abs() >= delta.dy.abs();
    final extraAlong = (stretchStrength * flightBell).clamp(0.0, 16.0);
    final compressCross = (extraAlong * 0.16).clamp(0.0, 2.5);
    if (horizontalBias) {
      return Rect.fromCenter(
        center: base.center,
        width: base.width + extraAlong,
        height: math.max(8.0, base.height - compressCross),
      );
    }
    return Rect.fromCenter(
      center: base.center,
      width: math.max(8.0, base.width - compressCross),
      height: base.height + extraAlong,
    );
  }

  /// Computes normalized liquid bridge factor `[0..1]` between two logically
  /// grouped sibling bounds separated by up to [mergeSpacing] logical pixels.
  ///
  /// Returns `0.0` immediately when both elements are idle (`max <= 0.008`), when
  /// elements do not share a row/column alignment, or when gap exceeds
  /// [mergeSpacing].
  static double bridgeFactor(
    Rect a,
    Rect b,
    double mergeSpacing,
    double energyA,
    double energyB,
  ) {
    final combinedEnergy = math.max(energyA, energyB);
    if (combinedEnergy <= 0.008 || mergeSpacing <= 0.0 || a.isEmpty || b.isEmpty) {
      return 0.0;
    }

    final yOverlap = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
    final minH = math.min(a.height, b.height);
    final horizontalGap = math.max(0.0, math.max(a.left - b.right, b.left - a.right));

    final xOverlap = math.min(a.right, b.right) - math.max(a.left, b.left);
    final minW = math.min(a.width, b.width);
    final verticalGap = math.max(0.0, math.max(a.top - b.bottom, b.top - a.bottom));

    final sameRow = minH > 0 && yOverlap >= minH * 0.45 && horizontalGap <= mergeSpacing;
    final sameColumn = minW > 0 && xOverlap >= minW * 0.45 && verticalGap <= mergeSpacing;
    if (!sameRow && !sameColumn) return 0.0;

    final gap = sameRow ? horizontalGap : verticalGap;
    final proximity = smoothCubic(1.0 - (gap / math.max(1.0, mergeSpacing)));
    // Hover gently wakes a translucent neck (~0.45..0.65); press/adjacent hover deepens it.
    final energyCurve = (0.35 + 0.65 * math.min(1.0, combinedEnergy * 2.2)) * smoothCubic(combinedEnergy / 0.14);
    final mutualBoost = math.min(energyA, energyB) > 0.05 ? 1.18 : 1.0;
    return (proximity * energyCurve * mutualBoost).clamp(0.0, 1.0);
  }

  /// Constructs a continuous concave metaball-like neck path linking [a] and [b].
  ///
  /// Returns `null` when separation or idle energy drops [strength] below paint
  /// visibility so callers perform zero path rasterization.
  static Path? buildLiquidBridgePath({
    required Rect a,
    required Rect b,
    required double radiusA,
    required double radiusB,
    required double strength,
  }) {
    if (strength <= 0.01 || a.isEmpty || b.isEmpty) return null;

    final yOverlap = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
    final minH = math.min(a.height, b.height);
    final sameRow = minH > 0 && yOverlap >= minH * 0.45;

    if (sameRow) {
      final leftRect = a.center.dx <= b.center.dx ? a : b;
      final rightRect = identical(leftRect, a) ? b : a;
      final leftR = identical(leftRect, a) ? radiusA : radiusB;
      final rightR = identical(leftRect, a) ? radiusB : radiusA;

      final gap = rightRect.left - leftRect.right;
      if (gap < -2.0) return null;

      final topSpan = math.max(leftRect.top, rightRect.top);
      final bottomSpan = math.min(leftRect.bottom, rightRect.bottom);
      final spanH = bottomSpan - topSpan;
      if (spanH < 8.0) return null;

      final midY = (topSpan + bottomSpan) * 0.5;
      // Anchor slightly inside curved corners so the neck merges flush into each capsule rim.
      final leftAnchorInset = math.min(leftR * 0.42, 7.0).clamp(1.5, leftRect.width * 0.25);
      final rightAnchorInset = math.min(rightR * 0.42, 7.0).clamp(1.5, rightRect.width * 0.25);
      final x0 = leftRect.right - leftAnchorInset;
      final x1 = rightRect.left + rightAnchorInset;
      final midX = (x0 + x1) * 0.5;

      final halfContact = (spanH * (0.22 + 0.16 * strength)).clamp(3.0, spanH * 0.42);
      final waistHalf = (halfContact * (0.34 + 0.48 * strength)).clamp(1.5, halfContact);

      return Path()
        ..moveTo(x0, midY - halfContact)
        ..quadraticBezierTo(midX, midY - waistHalf, x1, midY - halfContact)
        ..lineTo(x1, midY + halfContact)
        ..quadraticBezierTo(midX, midY + waistHalf, x0, midY + halfContact)
        ..close();
    }

    // Vertical liquid bridge fallback for stacked grouped controls.
    final topRect = a.center.dy <= b.center.dy ? a : b;
    final bottomRect = identical(topRect, a) ? b : a;
    final topR = identical(topRect, a) ? radiusA : radiusB;
    final bottomR = identical(topRect, a) ? radiusB : radiusA;
    final gap = bottomRect.top - topRect.bottom;
    if (gap < -2.0) return null;

    final leftSpan = math.max(topRect.left, bottomRect.left);
    final rightSpan = math.min(topRect.right, bottomRect.right);
    final spanW = rightSpan - leftSpan;
    if (spanW < 8.0) return null;

    final midX = (leftSpan + rightSpan) * 0.5;
    final topAnchorInset = math.min(topR * 0.42, 7.0).clamp(1.5, topRect.height * 0.25);
    final bottomAnchorInset = math.min(bottomR * 0.42, 7.0).clamp(1.5, bottomRect.height * 0.25);
    final y0 = topRect.bottom - topAnchorInset;
    final y1 = bottomRect.top + bottomAnchorInset;
    final midY = (y0 + y1) * 0.5;

    final halfContact = (spanW * (0.22 + 0.16 * strength)).clamp(3.0, spanW * 0.42);
    final waistHalf = (halfContact * (0.34 + 0.48 * strength)).clamp(1.5, halfContact);

    return Path()
      ..moveTo(midX - halfContact, y0)
      ..quadraticBezierTo(midX - waistHalf, midY, midX - halfContact, y1)
      ..lineTo(midX + halfContact, y1)
      ..quadraticBezierTo(midX + waistHalf, midY, midX + halfContact, y0)
      ..close();
  }
}

/// Shared spring motion controller for coordinated slot morphing and transitions.
///
/// Uses a single [AnimationController.unbounded] driven by [SpringSimulation] so
/// animations run only during active transitions, reverse seamlessly with
/// continuous velocity on interruption, and halt when settled or backgrounded.
class LiquidGlassMotionController {
  LiquidGlassMotionController({
    required TickerProvider vsync,
    this.spring = kDropitSelectionGlideSpring,
    double initialValue = 0.0,
  }) : controller = AnimationController.unbounded(vsync: vsync, value: initialValue);

  final AnimationController controller;
  final SpringDescription spring;

  double get value => controller.value;
  double get velocity => controller.velocity;
  bool get isAnimating => controller.isAnimating;

  void snapTo(double target) {
    if (controller.isAnimating) controller.stop(canceled: true);
    if (controller.value != target) controller.value = target;
  }

  void animateTo(double target, {required bool animate, bool snapToEnd = true}) {
    if (!animate) {
      snapTo(target);
      return;
    }
    if ((controller.value - target).abs() < 0.0005 && !controller.isAnimating) {
      controller.value = target;
      return;
    }
    unawaited(
      controller.animateWith(
        SpringSimulation(
          spring,
          controller.value,
          target,
          controller.velocity,
          snapToEnd: snapToEnd,
        ),
      ),
    );
  }

  void dispose() {
    controller.dispose();
  }
}

class _LiquidGlassMemberEntry {
  _LiquidGlassMemberEntry({
    required this.id,
    required this.groupId,
    required this.context,
    required this.radius,
    required this.tintColor,
    required this.energy,
  });

  final Object id;
  String groupId;
  final BuildContext context;
  double radius;
  Color? tintColor;
  double energy;
  Offset? localPointer;
  Rect? cachedLocalRect;
}

/// Mutable handle exposed to nested interactive widgets (e.g. [AppGlassPress])
/// so existing hover/press springs feed liquid bridge calculations without
/// allocating duplicate animation controllers or pointer listeners.
class LiquidGlassMemberHandle {
  LiquidGlassMemberHandle._(this._coordinator, this._entry);

  final GlassAnimationCoordinator _coordinator;
  final _LiquidGlassMemberEntry _entry;

  void updateEnergy(double energy, {Offset? localPointer}) {
    _coordinator._updateMemberEnergy(_entry, energy, localPointer: localPointer);
  }
}

/// Coordinates logically grouped [LiquidGlassMember] controls inside one
/// [LiquidGlassContainer] with zero idle tickers and a single shared repaint
/// pass while any member has active hover/press energy.
class GlassAnimationCoordinator extends ChangeNotifier {
  final Map<Object, _LiquidGlassMemberEntry> _members = <Object, _LiquidGlassMemberEntry>{};
  bool _hasActiveEnergy = false;
  bool _notifyScheduled = false;

  bool get hasActiveEnergy => _hasActiveEnergy;
  int get memberCount => _members.length;

  _LiquidGlassMemberEntry _register({
    required Object id,
    required String groupId,
    required BuildContext context,
    required double radius,
    required Color? tintColor,
    required double initialEnergy,
  }) {
    final existing = _members[id];
    if (existing != null) {
      existing
        ..groupId = groupId
        ..radius = radius
        ..tintColor = tintColor;
      return existing;
    }
    final created = _LiquidGlassMemberEntry(
      id: id,
      groupId: groupId,
      context: context,
      radius: radius,
      tintColor: tintColor,
      energy: initialEnergy,
    );
    _members[id] = created;
    _recomputeActiveFlag();
    return created;
  }

  void _unregister(Object id) {
    if (_members.remove(id) != null) {
      _recomputeActiveFlag();
      _scheduleNotify();
    }
  }

  void _updateMemberEnergy(_LiquidGlassMemberEntry entry, double energy, {Offset? localPointer}) {
    final normalized = energy.clamp(0.0, 1.25);
    if ((entry.energy - normalized).abs() < 0.002 && entry.localPointer == localPointer) {
      return;
    }
    entry
      ..energy = normalized
      ..localPointer = localPointer;
    final wasActive = _hasActiveEnergy;
    _recomputeActiveFlag();
    if (_hasActiveEnergy || wasActive) {
      notifyListeners();
    }
  }

  void clearEnergy() {
    var changed = false;
    for (final member in _members.values) {
      if (member.energy != 0.0 || member.localPointer != null) {
        member
          ..energy = 0.0
          ..localPointer = null;
        changed = true;
      }
    }
    _hasActiveEnergy = false;
    if (changed) notifyListeners();
  }

  void _recomputeActiveFlag() {
    for (final m in _members.values) {
      if (m.energy > 0.008) {
        _hasActiveEnergy = true;
        return;
      }
    }
    _hasActiveEnergy = false;
  }

  void _scheduleNotify() {
    if (_notifyScheduled || !_hasActiveEnergy) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (_members.isNotEmpty && _hasActiveEnergy) {
        notifyListeners();
      }
    });
  }

  Iterable<_LiquidGlassMemberEntry> get _entries => _members.values;
}

class _LiquidGlassContainerScope extends InheritedWidget {
  const _LiquidGlassContainerScope({
    required this.coordinator,
    required super.child,
  });

  final GlassAnimationCoordinator coordinator;

  @override
  bool updateShouldNotify(_LiquidGlassContainerScope oldWidget) => coordinator != oldWidget.coordinator;
}

class _LiquidGlassMemberScope extends InheritedWidget {
  const _LiquidGlassMemberScope({
    required this.handle,
    required super.child,
  });

  final LiquidGlassMemberHandle handle;

  @override
  bool updateShouldNotify(_LiquidGlassMemberScope oldWidget) => handle != oldWidget.handle;
}

/// Logical liquid-glass group equivalent to Apple's `GlassEffectContainer`.
///
/// Adjacent [LiquidGlassMember] controls sharing the same `groupId` smoothly
/// blend connected liquid necks when hovered, pressed, or approaching each
/// other within [spacing], without creating stacked `BackdropFilter`s or
/// repainting while idle.
class LiquidGlassContainer extends StatefulWidget {
  const LiquidGlassContainer({
    required this.child,
    this.spacing = 18.0,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final double spacing;
  final bool enabled;

  @override
  State<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends State<LiquidGlassContainer> with WidgetsBindingObserver {
  final GlobalKey _containerKey = GlobalKey();
  final GlassAnimationCoordinator _coordinator = GlassAnimationCoordinator();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _coordinator.clearEnergy();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = AppGlassConfigScope.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final active = widget.enabled && config.animateMotion && !disableAnimations && !config.highContrast;
    if (usesAndroidMornye || !active) return widget.child;

    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = Theme.of(context).colorScheme.primary;
    return _LiquidGlassContainerScope(
      coordinator: _coordinator,
      child: RepaintBoundary(
        child: KeyedSubtree(
          key: _containerKey,
          child: CustomPaint(
            painter: _LiquidBridgePainter(
              coordinator: _coordinator,
              containerKey: _containerKey,
              spacing: widget.spacing,
              dark: dark,
              accent: tint,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Marks a glass control inside a [LiquidGlassContainer] as participating in
/// same-group optical liquid merging (`glassEffectID` + `glassEffectUnion`).
class LiquidGlassMember extends StatefulWidget {
  const LiquidGlassMember({
    required this.id,
    required this.child,
    this.groupId = 'default',
    this.radius = 999,
    this.tintColor,
    this.progress,
    super.key,
  });

  final Object id;
  final String groupId;
  final double radius;
  final Color? tintColor;
  final ValueListenable<double>? progress;
  final Widget child;

  static LiquidGlassMemberHandle? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_LiquidGlassMemberScope>()?.handle;

  @override
  State<LiquidGlassMember> createState() => _LiquidGlassMemberState();
}

class _LiquidGlassMemberState extends State<LiquidGlassMember> {
  GlassAnimationCoordinator? _coordinator;
  _LiquidGlassMemberEntry? _entry;
  LiquidGlassMemberHandle? _handle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextCoordinator = context.dependOnInheritedWidgetOfExactType<_LiquidGlassContainerScope>()?.coordinator;
    if (nextCoordinator != _coordinator) {
      if (_coordinator != null && _entry != null) {
        _coordinator!._unregister(_entry!.id);
      }
      _coordinator = nextCoordinator;
      _entry = null;
      _handle = null;
    }
    _syncRegistration();
  }

  @override
  void didUpdateWidget(LiquidGlassMember oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      oldWidget.progress?.removeListener(_onProgressChanged);
      widget.progress?.addListener(_onProgressChanged);
    }
    if (oldWidget.id != widget.id && _coordinator != null) {
      _coordinator!._unregister(oldWidget.id);
      _entry = null;
      _handle = null;
    }
    _syncRegistration();
  }

  void _syncRegistration() {
    final coordinator = _coordinator;
    if (coordinator == null) return;
    _entry = coordinator._register(
      id: widget.id,
      groupId: widget.groupId,
      context: context,
      radius: widget.radius,
      tintColor: widget.tintColor,
      initialEnergy: widget.progress?.value ?? 0.0,
    );
    _handle ??= LiquidGlassMemberHandle._(coordinator, _entry!);
    widget.progress?.removeListener(_onProgressChanged);
    widget.progress?.addListener(_onProgressChanged);
  }

  void _onProgressChanged() {
    final entry = _entry;
    final coordinator = _coordinator;
    final progress = widget.progress;
    if (entry != null && coordinator != null && progress != null) {
      coordinator._updateMemberEnergy(entry, progress.value);
    }
  }

  @override
  void dispose() {
    widget.progress?.removeListener(_onProgressChanged);
    _coordinator?._unregister(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handle = _handle;
    if (handle == null) return widget.child;
    return _LiquidGlassMemberScope(handle: handle, child: widget.child);
  }
}

class _LiquidBridgePainter extends CustomPainter {
  _LiquidBridgePainter({
    required this.coordinator,
    required this.containerKey,
    required this.spacing,
    required this.dark,
    required this.accent,
  }) : super(repaint: coordinator);

  final GlassAnimationCoordinator coordinator;
  final GlobalKey containerKey;
  final double spacing;
  final bool dark;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (!coordinator.hasActiveEnergy || size.isEmpty || coordinator.memberCount < 2) return;
    final containerBox = containerKey.currentContext?.findRenderObject();
    if (containerBox is! RenderBox || !containerBox.attached || !containerBox.hasSize) return;

    final entries = coordinator._entries.toList(growable: false);
    final rects = List<Rect?>.filled(entries.length, null);
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (!entry.context.mounted) continue;
      final ro = entry.context.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      final offset = ro.localToGlobal(Offset.zero, ancestor: containerBox);
      final rect = offset & ro.size;
      entry.cachedLocalRect = rect;
      rects[i] = rect;
    }

    for (var i = 0; i < entries.length; i++) {
      final aRect = rects[i];
      if (aRect == null) continue;
      final a = entries[i];

      for (var j = i + 1; j < entries.length; j++) {
        final bRect = rects[j];
        if (bRect == null) continue;
        final b = entries[j];
        if (a.groupId != b.groupId) continue;

        final strength = GlassGeometryInterpolator.bridgeFactor(aRect, bRect, spacing, a.energy, b.energy);
        if (strength <= 0.01) continue;

        // Skip non-adjacent pairs if another same-group member sits strictly between them.
        if (_hasIntermediateMember(i, j, aRect, bRect, a.groupId, entries, rects)) {
          continue;
        }

        final path = GlassGeometryInterpolator.buildLiquidBridgePath(
          a: aRect,
          b: bRect,
          radiusA: a.radius,
          radiusB: b.radius,
          strength: strength,
        );
        if (path == null) continue;

        final bounds = path.getBounds();
        final tint = a.tintColor ?? b.tintColor ?? accent;
        final bodyPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: (dark ? 0.16 : 0.34) * strength),
              Color.lerp(Colors.white, tint, dark ? 0.35 : 0.25)!.withValues(alpha: (dark ? 0.11 : 0.22) * strength),
              Colors.white.withValues(alpha: (dark ? 0.14 : 0.28) * strength),
            ],
          ).createShader(bounds);
        canvas.drawPath(path, bodyPaint);

        final rimPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.85
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: (dark ? 0.42 : 0.68) * strength),
              Colors.white.withValues(alpha: (dark ? 0.14 : 0.24) * strength),
            ],
          ).createShader(bounds);
        canvas.drawPath(path, rimPaint);
      }
    }
  }

  static bool _hasIntermediateMember(
    int i,
    int j,
    Rect aRect,
    Rect bRect,
    String groupId,
    List<_LiquidGlassMemberEntry> entries,
    List<Rect?> rects,
  ) {
    final minX = math.min(aRect.center.dx, bRect.center.dx);
    final maxX = math.max(aRect.center.dx, bRect.center.dx);
    final minY = math.min(aRect.center.dy, bRect.center.dy);
    final maxY = math.max(aRect.center.dy, bRect.center.dy);
    final horizontal = (bRect.center.dx - aRect.center.dx).abs() >= (bRect.center.dy - aRect.center.dy).abs();

    for (var k = 0; k < entries.length; k++) {
      if (k == i || k == j || entries[k].groupId != groupId) continue;
      final c = rects[k];
      if (c == null) continue;
      if (horizontal) {
        if (c.center.dx > minX && c.center.dx < maxX && (c.center.dy - (minY + maxY) * 0.5).abs() < math.max(aRect.height, bRect.height)) {
          return true;
        }
      } else {
        if (c.center.dy > minY && c.center.dy < maxY && (c.center.dx - (minX + maxX) * 0.5).abs() < math.max(aRect.width, bRect.width)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  bool shouldRepaint(covariant _LiquidBridgePainter oldDelegate) =>
      oldDelegate.coordinator != coordinator || oldDelegate.spacing != spacing || oldDelegate.dark != dark || oldDelegate.accent != accent;
}
