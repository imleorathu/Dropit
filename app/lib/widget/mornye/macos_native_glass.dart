import 'dart:async';

import 'package:dropit_app/model/persistence/glass_quality.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

enum MacosNativeGlassMaterial {
  sidebar('sidebar'),
  hud('hud'),
  popover('popover'),
  menu('menu'),
  underWindow('underWindow')
  ;

  const MacosNativeGlassMaterial(this.channelName);
  final String channelName;
}

/// Coordinates native AppKit glass surfaces (`NSGlassEffectView` on macOS 26+
/// with `NSVisualEffectView` fallback) hosted behind Flutter's transparent view.
abstract final class MacosNativeGlass {
  static const MethodChannel channel = MethodChannel('dropit/native_glass');
  static bool _channelMissing = false;
  static bool _handlerRegistered = false;
  static bool _frameSyncRegistered = false;
  static String? _lastAppearance;
  static final Set<VoidCallback> _invalidateListeners = <VoidCallback>{};
  static final Set<VoidCallback> _frameSyncListeners = <VoidCallback>{};

  static void _ensureIncomingHandler() {
    if (_handlerRegistered || _channelMissing) return;
    _handlerRegistered = true;
    try {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'invalidateSurfaces') {
          for (final listener in List<VoidCallback>.of(_invalidateListeners)) {
            listener();
          }
        }
      });
    } catch (_) {
      // Headless or mocked environments may replace binary messenger handlers.
    }
  }

  static void _ensureFrameSyncCallback() {
    if (_frameSyncRegistered) return;
    _frameSyncRegistered = true;
    WidgetsBinding.instance.addPersistentFrameCallback((_) {
      if (_frameSyncListeners.isEmpty) return;
      for (final listener in List<VoidCallback>.of(_frameSyncListeners)) {
        listener();
      }
    });
  }

  static void addInvalidateListener(VoidCallback listener) {
    _invalidateListeners.add(listener);
    if (isSupported) _ensureIncomingHandler();
  }

  static void removeInvalidateListener(VoidCallback listener) {
    _invalidateListeners.remove(listener);
  }

  static void addFrameSyncListener(VoidCallback listener) {
    _frameSyncListeners.add(listener);
    if (isSupported) _ensureFrameSyncCallback();
  }

  static void removeFrameSyncListener(VoidCallback listener) {
    _frameSyncListeners.remove(listener);
  }

  /// Optional test override to exercise the macOS native glass bridge inside
  /// headless widget tests using a mock `MethodChannel`.
  @visibleForTesting
  static bool? debugSupportedOverride;

  /// Whether native AppKit desktop glass compositing should be active.
  static bool get isSupported {
    final override = debugSupportedOverride;
    if (override != null) return override;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS || _channelMissing) {
      return false;
    }
    // Headless widget tests run without MainFlutterWindow unless explicitly
    // opted in via [debugSupportedOverride].
    return WidgetsBinding.instance is WidgetsFlutterBinding && !WidgetsBinding.instance.runtimeType.toString().contains('Test');
  }

  /// Syncs the native NSWindow / AppKit glass appearance (`light`, `dark`, or
  /// `system`) with Dropit's resolved theme brightness.
  static Future<void> setAppearance(String mode) async {
    if (!isSupported || _lastAppearance == mode) return;
    _lastAppearance = mode;
    try {
      await channel.invokeMethod<void>('setAppearance', {'appearance': mode});
    } on MissingPluginException {
      _channelMissing = true;
    } on PlatformException {
      // Ignore transient shutdown / startup channel errors.
    }
  }

  @visibleForTesting
  static void resetForTest() {
    debugSupportedOverride = null;
    _channelMissing = false;
    _handlerRegistered = false;
    _lastAppearance = null;
    _invalidateListeners.clear();
    _frameSyncListeners.clear();
  }
}

/// Marks Flutter material rendered directly above an AppKit visual-effect or
/// `NSGlassEffectView` surface. Shader refraction over desktop pixels is
/// disabled in this scope because Flutter cannot sample WindowServer pixels.
class MacosNativeGlassBackdropScope extends InheritedWidget {
  const MacosNativeGlassBackdropScope({required super.child, super.key});

  static bool isInside(BuildContext context) => context.dependOnInheritedWidgetOfExactType<MacosNativeGlassBackdropScope>() != null;

  @override
  bool updateShouldNotify(MacosNativeGlassBackdropScope oldWidget) => false;
}

/// Positions a stable AppKit glass view (`NSGlassEffectView` / `NSVisualEffectView`)
/// behind this Flutter subtree and keeps its frame synced across resizes,
/// scrolls, and route transitions.
///
/// The AppKit view never receives pointer events; Flutter remains responsible
/// for semantics, focus, keyboard interaction, drag-and-drop, and controls.
class MacosNativeGlassSurface extends StatefulWidget {
  const MacosNativeGlassSurface({
    required this.child,
    this.id,
    this.material = MacosNativeGlassMaterial.hud,
    this.radius = 24,
    this.clear = false,
    this.interactive = false,
    this.tintColor,
    super.key,
  });

  final String? id;
  final Widget child;
  final MacosNativeGlassMaterial material;
  final double radius;
  final bool clear;
  final bool interactive;
  final Color? tintColor;

  @override
  State<MacosNativeGlassSurface> createState() => _MacosNativeGlassSurfaceState();
}

class _MacosNativeGlassSurfaceState extends State<MacosNativeGlassSurface> with WidgetsBindingObserver {
  final _surfaceKey = GlobalKey();
  late String _surfaceId;
  _NativeSurfaceSnapshot? _lastSnapshot;
  bool _reportScheduled = false;
  bool _environmentDirty = true;
  bool _appActive = true;
  final List<ScrollPosition> _scrollPositions = [];
  final List<BuildContext> _scrollContexts = [];
  Animation<double>? _routeAnimation;
  Animation<double>? _routeSecondaryAnimation;
  ModalRoute<dynamic>? _route;
  Size _screenSize = Size.zero;
  AppGlassConfigData? _glassConfig;
  Size? _cachedSize;
  final Matrix4 _cachedTransform = Matrix4.zero();
  bool _hasCachedTransform = false;
  bool _cachedVisibleInTree = false;
  bool _cachedRouteOwnsSurface = false;
  int _cachedAncestorSignature = 0;

  String get _effectiveId => widget.id ?? _surfaceId;

  @override
  void initState() {
    super.initState();
    _surfaceId = 'glass-${identityHashCode(this)}';
    WidgetsBinding.instance.addObserver(this);
    MacosNativeGlass.addInvalidateListener(_onNativeInvalidated);
    MacosNativeGlass.addFrameSyncListener(_onFrameRendered);
  }

  static bool _matricesClose(Matrix4 a, Matrix4 b) {
    final as = a.storage;
    final bs = b.storage;
    for (var i = 0; i < 16; i++) {
      if ((as[i] - bs[i]).abs() > 0.1) return false;
    }
    return true;
  }

  static int _computeAncestorSignature(RenderObject node) {
    var hash = 17;
    RenderObject? current = node.parent;
    while (current != null) {
      if (current is RenderBox && current.hasSize) {
        final s = current.size;
        hash = Object.hash(hash, s.width.round(), s.height.round());
      }
      current = current.parent;
    }
    return hash;
  }

  void _onFrameRendered() {
    if (!mounted || !_appActive || _reportScheduled) return;
    if (_environmentDirty || _lastSnapshot == null) {
      _scheduleReport();
      return;
    }
    final renderObject = _surfaceKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached || !renderObject.hasSize) {
      return;
    }
    final route = _route;
    final routeOwnsSurface = route == null || (route.isCurrent && !route.offstage);
    final visibleInTree = routeOwnsSurface && _isVisibleInRenderTree(renderObject);
    final ancestorSig = _computeAncestorSignature(renderObject);
    final transform = renderObject.getTransformTo(null);
    if (_hasCachedTransform &&
        _cachedSize == renderObject.size &&
        _cachedRouteOwnsSurface == routeOwnsSurface &&
        _cachedVisibleInTree == visibleInTree &&
        _cachedAncestorSignature == ancestorSig &&
        _matricesClose(transform, _cachedTransform)) {
      // Child control animations (hover, slider drag, switch, shimmer) do not
      // move or clip the enclosing native glass surface — skip redundant layout
      // walks and post-frame reports completely.
      return;
    }
    _scheduleReport();
  }

  void _onNativeInvalidated() {
    if (!mounted) return;
    _lastSnapshot = null;
    _environmentDirty = true;
    _scheduleReport(ensureFrame: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    for (final pos in _scrollPositions) {
      pos.removeListener(_onEnvironmentChanged);
      pos.isScrollingNotifier.removeListener(_onEnvironmentChanged);
    }
    _scrollPositions.clear();
    _scrollContexts.clear();
    context.visitAncestorElements((element) {
      if (element.widget is Scrollable) {
        _scrollContexts.add(element);
        final state = (element as StatefulElement).state;
        if (state is ScrollableState) {
          final pos = state.position;
          _scrollPositions.add(pos);
          pos.addListener(_onEnvironmentChanged);
          pos.isScrollingNotifier.addListener(_onEnvironmentChanged);
        }
      }
      return true;
    });

    _screenSize = MediaQuery.sizeOf(context);
    _glassConfig = AppGlassConfigScope.of(context);
    _route = ModalRoute.of(context);
    final route = _route;
    final nextPrimary = route?.animation;
    if (nextPrimary != _routeAnimation) {
      _routeAnimation?.removeListener(_onEnvironmentChanged);
      _routeAnimation?.removeStatusListener(_onRouteStatusChanged);
      _routeAnimation = nextPrimary;
      _routeAnimation?.addListener(_onEnvironmentChanged);
      _routeAnimation?.addStatusListener(_onRouteStatusChanged);
    }

    final nextSecondary = route?.secondaryAnimation;
    if (nextSecondary != _routeSecondaryAnimation) {
      _routeSecondaryAnimation?.removeListener(_onEnvironmentChanged);
      _routeSecondaryAnimation?.removeStatusListener(_onRouteStatusChanged);
      _routeSecondaryAnimation = nextSecondary;
      _routeSecondaryAnimation?.addListener(_onEnvironmentChanged);
      _routeSecondaryAnimation?.addStatusListener(_onRouteStatusChanged);
    }
    _environmentDirty = true;
    _scheduleReport();
  }

  void _onEnvironmentChanged() {
    _environmentDirty = true;
    _scheduleReport();
  }

  void _onRouteStatusChanged(AnimationStatus _) {
    _environmentDirty = true;
    _scheduleReport();
  }

  @override
  void didChangeMetrics() {
    _lastSnapshot = null;
    _environmentDirty = true;
    _scheduleReport(ensureFrame: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    _appActive = active;
    if (active) {
      _lastSnapshot = null;
      _environmentDirty = true;
      _scheduleReport(ensureFrame: true);
    }
  }

  @override
  void didUpdateWidget(MacosNativeGlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      unawaited(_remove(oldWidget.id ?? _surfaceId));
      _lastSnapshot = null;
    }
    _environmentDirty = true;
    _scheduleReport();
  }

  @override
  void dispose() {
    for (final pos in _scrollPositions) {
      pos.removeListener(_onEnvironmentChanged);
      pos.isScrollingNotifier.removeListener(_onEnvironmentChanged);
    }
    _scrollPositions.clear();
    _scrollContexts.clear();
    _routeAnimation?.removeListener(_onEnvironmentChanged);
    _routeAnimation?.removeStatusListener(_onRouteStatusChanged);
    _routeAnimation = null;
    _routeSecondaryAnimation?.removeListener(_onEnvironmentChanged);
    _routeSecondaryAnimation?.removeStatusListener(_onRouteStatusChanged);
    _routeSecondaryAnimation = null;
    MacosNativeGlass.removeInvalidateListener(_onNativeInvalidated);
    MacosNativeGlass.removeFrameSyncListener(_onFrameRendered);
    WidgetsBinding.instance.removeObserver(this);
    if (MacosNativeGlass.isSupported) unawaited(_remove(_effectiveId));
    super.dispose();
  }

  void _scheduleReport({bool ensureFrame = false}) {
    if (!MacosNativeGlass.isSupported || _reportScheduled || !_appActive) return;
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (mounted) unawaited(_reportSurface());
    });
    if (ensureFrame && WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  static bool _isVisibleInRenderTree(RenderObject? node) {
    var current = node;
    while (current != null) {
      if (current is RenderOffstage && current.offstage) {
        return false;
      }
      if (current is RenderOpacity && current.opacity <= 0.01) {
        return false;
      }
      if (current is RenderAnimatedOpacity && current.opacity.value <= 0.01) {
        return false;
      }
      if (current is RenderSliverOpacity && current.opacity <= 0.01) {
        return false;
      }
      if (current is RenderSliverAnimatedOpacity && current.opacity.value <= 0.01) {
        return false;
      }
      current = current.parent;
    }
    return true;
  }

  static Rect _globalBounds(RenderBox box) {
    final rect = Offset.zero & box.size;
    if (rect.isEmpty) return rect;
    return MatrixUtils.transformRect(box.getTransformTo(null), rect);
  }

  static bool _isFiniteRect(Rect rect) => rect.left.isFinite && rect.top.isFinite && rect.right.isFinite && rect.bottom.isFinite;

  Rect _computeClipRect(Rect fullRect, RenderBox surfaceBox) {
    if (!_isFiniteRect(fullRect)) return Rect.zero;
    final screenBounds = Offset.zero & _screenSize;
    if (!_isFiniteRect(screenBounds)) return Rect.zero;
    var clipped = fullRect.intersect(screenBounds);
    if (!_isFiniteRect(clipped) || clipped.isEmpty) return Rect.zero;

    // 1. Intersect every enclosing render clip/viewport boundary along the
    // RenderObject ancestor chain (handles ClipRect, ClipRRect, ClipPath,
    // PageView, CustomScrollView, SingleChildScrollView, ListView, and scaled
    // ancestors cleanly).
    RenderObject child = surfaceBox;
    RenderObject? parent = surfaceBox.parent;
    while (parent != null) {
      if (parent is RenderBox && parent.attached && parent.hasSize) {
        final localClip = parent.describeApproximatePaintClip(child);
        if (localClip != null && _isFiniteRect(localClip)) {
          final globalClip = localClip.isEmpty ? Rect.zero : MatrixUtils.transformRect(parent.getTransformTo(null), localClip);
          if (_isFiniteRect(globalClip)) {
            clipped = clipped.intersect(globalClip);
            if (!_isFiniteRect(clipped) || clipped.isEmpty) return Rect.zero;
          }
        }
      }
      child = parent;
      parent = parent.parent;
    }

    // 2. Also intersect ancestor Scrollable boxes in case a viewport delegates
    // clipping without returning a paint clip for its child directly.
    for (final scrollContext in _scrollContexts) {
      if (!scrollContext.mounted) continue;
      final vpRender = scrollContext.findRenderObject();
      if (vpRender is RenderBox && vpRender.attached && vpRender.hasSize && vpRender != surfaceBox) {
        final vpRect = _globalBounds(vpRender);
        if (_isFiniteRect(vpRect)) {
          clipped = clipped.intersect(vpRect);
          if (!_isFiniteRect(clipped) || clipped.isEmpty) break;
        }
      }
    }
    return _isFiniteRect(clipped) && !clipped.isEmpty ? clipped : Rect.zero;
  }

  Future<void> _reportSurface() async {
    if (!mounted) return;
    _environmentDirty = false;
    final renderObject = _surfaceKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached || !renderObject.hasSize) return;

    final config = _glassConfig ?? const AppGlassConfigData();
    // Native AppKit surfaces are siblings of Flutter's Metal view, so
    // Flutter route opacity/offstage painting cannot hide them for us. A
    // covered route commonly remains mounted and `offstage == false`; using
    // that value leaves its native glass visible through the next transparent
    // route. Resolve currentness at report time so secondary route animation
    // ticks hide the old surfaces immediately and restore them after a pop.
    final route = _route ?? ModalRoute.of(context);
    final routeOwnsSurface = route == null || (route.isCurrent && !route.offstage);
    final visibleInTree = routeOwnsSurface && _isVisibleInRenderTree(renderObject);
    final transform = renderObject.getTransformTo(null);
    _cachedSize = renderObject.size;
    _cachedTransform.setFrom(transform);
    _hasCachedTransform = true;
    _cachedRouteOwnsSurface = routeOwnsSurface;
    _cachedVisibleInTree = visibleInTree;
    _cachedAncestorSignature = _computeAncestorSignature(renderObject);

    final rect = Offset.zero & renderObject.size;
    final rawFullRect = rect.isEmpty ? rect : MatrixUtils.transformRect(transform, rect);
    final fullRect = _isFiniteRect(rawFullRect) ? rawFullRect : Rect.zero;
    final clipRect = visibleInTree && !fullRect.isEmpty ? _computeClipRect(fullRect, renderObject) : Rect.zero;
    final visible =
        visibleInTree && config.effectiveQuality != AppGlassQuality.flat && !config.highContrast && clipRect.width > 1 && clipRect.height > 1;

    final snapshot = _NativeSurfaceSnapshot(
      rect: fullRect,
      clipRect: clipRect,
      material: widget.material,
      radius: widget.radius,
      opacity: (0.68 + config.clarity * 0.28).clamp(0.35, 0.96),
      frost: config.effectiveQuality == AppGlassQuality.liquid ? config.glassFrost.clamp(0.0, 1.0) : 0.0,
      clear: widget.clear,
      interactive: widget.interactive,
      tintArgb: widget.tintColor?.toARGB32(),
      visible: visible,
    );
    if (snapshot == _lastSnapshot) return;
    _lastSnapshot = snapshot;

    try {
      await MacosNativeGlass.channel.invokeMethod<void>('setSurface', {
        'id': _effectiveId,
        'x': snapshot.rect.left,
        'y': snapshot.rect.top,
        'width': snapshot.rect.width,
        'height': snapshot.rect.height,
        'clipX': snapshot.clipRect.left,
        'clipY': snapshot.clipRect.top,
        'clipWidth': snapshot.clipRect.width,
        'clipHeight': snapshot.clipRect.height,
        'material': snapshot.material.channelName,
        'radius': snapshot.radius,
        'opacity': snapshot.opacity,
        'frost': snapshot.frost,
        'clear': snapshot.clear,
        'interactive': snapshot.interactive,
        if (snapshot.tintArgb != null) 'tintArgb': snapshot.tintArgb,
        'visible': snapshot.visible,
      });
    } on MissingPluginException {
      MacosNativeGlass._channelMissing = true;
    } on PlatformException {
      // Keep Flutter material usable if AppKit composition is unavailable.
    }
  }

  Future<void> _remove(String id) async {
    try {
      await MacosNativeGlass.channel.invokeMethod<void>('removeSurface', {'id': id});
    } on MissingPluginException {
      MacosNativeGlass._channelMissing = true;
    } on PlatformException {
      // The native window may already be shutting down.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!MacosNativeGlass.isSupported) return widget.child;
    _environmentDirty = true;
    _scheduleReport();
    return KeyedSubtree(
      key: _surfaceKey,
      child: MacosNativeGlassBackdropScope(child: widget.child),
    );
  }
}

@immutable
class _NativeSurfaceSnapshot {
  const _NativeSurfaceSnapshot({
    required this.rect,
    required this.clipRect,
    required this.material,
    required this.radius,
    required this.opacity,
    required this.frost,
    required this.clear,
    required this.interactive,
    required this.tintArgb,
    required this.visible,
  });

  final Rect rect;
  final Rect clipRect;
  final MacosNativeGlassMaterial material;
  final double radius;
  final double opacity;
  final double frost;
  final bool clear;
  final bool interactive;
  final int? tintArgb;
  final bool visible;

  static bool _rectsClose(Rect a, Rect b) {
    if (identical(a, b)) return true;
    return (a.left - b.left).abs() < 0.2 && (a.top - b.top).abs() < 0.2 && (a.right - b.right).abs() < 0.2 && (a.bottom - b.bottom).abs() < 0.2;
  }

  @override
  bool operator ==(Object other) =>
      other is _NativeSurfaceSnapshot &&
      _rectsClose(rect, other.rect) &&
      _rectsClose(clipRect, other.clipRect) &&
      other.material == material &&
      (other.radius - radius).abs() < 0.1 &&
      (other.opacity - opacity).abs() < 0.01 &&
      (other.frost - frost).abs() < 0.01 &&
      other.clear == clear &&
      other.interactive == interactive &&
      other.tintArgb == tintArgb &&
      other.visible == visible;

  @override
  int get hashCode => Object.hash(rect, clipRect, material, radius, opacity, frost, clear, interactive, tintArgb, visible);
}
