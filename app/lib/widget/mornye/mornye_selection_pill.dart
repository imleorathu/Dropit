import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_liquid_backdrop.dart';
import 'package:dropit_app/widget/mornye/dropit_chromatic_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

Future<ui.FragmentProgram>? _selectionMaskProgram;
ui.FragmentProgram? _loadedSelectionMaskProgram;
const _heldWidthGrowth = 0.28;
const _heldHeightGrowth = 0.24;
const _pillRadius = 32.0;

/// Selection with a transient lens over the fixed-size foreground while held.
/// It refracts both the bar's backdrop and its icons, rendered only once.
class MornyeSelectionPill extends StatefulWidget {
  const MornyeSelectionPill({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(4),
    this.liquidInteraction = false,
    this.contrastBlocked,
    this.selectionColor,
    this.maskItemForeground = true,
    this.interactionBuilder,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Widget Function(BuildContext context, int index, bool selected) itemBuilder;
  final EdgeInsets padding;
  final bool liquidInteraction;

  /// The parent's glass contrast policy, including an explicit user override.
  /// Standalone controls respect the system contrast request by default.
  final bool? contrastBlocked;

  /// Recolors the foreground under the moving pill instead of switching an
  /// entire item at a tab boundary. Builders receive `selected: false` in this
  /// mode so the unmasked foreground retains its normal color.
  final Color? selectionColor;
  final bool maskItemForeground;

  /// Lets the bar animate its glass behind the fixed-size foreground using the
  /// same press/release animation as the selection lens.
  final Widget Function(BuildContext context, double progress, Widget child)? interactionBuilder;

  @override
  State<MornyeSelectionPill> createState() => _MornyeSelectionPillState();
}

class _MornyeSelectionPillState extends State<MornyeSelectionPill> with TickerProviderStateMixin, WidgetsBindingObserver {
  int? _dragIndex;
  bool _dragCancelled = false;
  bool _pressed = false;
  int? _pressedIndex;
  double? _dragAlignment;
  int? _activePointer;
  final _foregroundKey = GlobalKey();
  late final AnimationController _pressController;
  late final CurvedAnimation _pressAnimation;
  late final AnimationController _glideController;
  ui.FragmentProgram? _maskProgram;
  Widget? _items;
  int? _itemsSelected;

  double _targetAlignment(int index, int count) => count <= 1 ? 0.0 : (-1.0 + 2.0 * index.clamp(0, count - 1) / (count - 1)).clamp(-1.0, 1.0);

  void _syncGlide({bool immediate = false}) {
    final count = widget.labels.length;
    if (count == 0) return;
    final selected = _dragIndex ?? _pressedIndex ?? widget.selectedIndex;
    final target = _dragAlignment ?? _targetAlignment(selected, count);
    if (immediate || _dragAlignment != null || AppGlassConfigScope.of(context).reduceMotion) {
      if (_glideController.isAnimating) _glideController.stop(canceled: true);
      if (_glideController.value != target) _glideController.value = target;
      return;
    }
    if ((_glideController.value - target).abs() > 0.0005) {
      unawaited(
        _glideController.animateWith(
          SpringSimulation(kDropitSelectionGlideSpring, _glideController.value, target, usesAndroidMornye ? _glideController.velocity : 0.0),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _pressAnimation = CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _glideController = AnimationController.unbounded(
      vsync: this,
      value: _targetAlignment(widget.selectedIndex, widget.labels.length),
    );
    if (widget.selectionColor != null) unawaited(_loadMaskProgram());
  }

  void _resetTransientInteraction({bool immediate = false}) {
    _activePointer = null;
    _dragCancelled = true;
    _pressed = false;
    _pressedIndex = null;
    _dragIndex = null;
    _dragAlignment = null;
    if (immediate || !mounted) {
      _pressController.value = 0.0;
    } else if (_pressController.value > 0) {
      unawaited(_pressController.reverse());
    }
    _syncGlide(immediate: immediate || !mounted);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && (_pressed || _activePointer != null || _dragAlignment != null)) {
      if (mounted) {
        setState(_resetTransientInteraction);
      } else {
        _resetTransientInteraction(immediate: true);
      }
    }
  }

  @override
  void deactivate() {
    _activePointer = null;
    _dragCancelled = true;
    _pressed = false;
    _pressedIndex = null;
    _dragIndex = null;
    _dragAlignment = null;
    if (_pressController.isAnimating) {
      _pressController.stop(canceled: true);
    }
    super.deactivate();
  }

  Future<void> _loadMaskProgram() async {
    if (usesAndroidMornye) return;
    try {
      final program =
          _loadedSelectionMaskProgram ??
          await (_selectionMaskProgram ??= ui.FragmentProgram.fromAsset(
            'assets/shaders/mornye_selection_mask.frag',
          ));
      _loadedSelectionMaskProgram = program;
      if (mounted) setState(() => _maskProgram = program);
    } catch (error) {
      debugPrint('Selection mask unavailable: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pressAnimation.dispose();
    _pressController.dispose();
    _glideController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _items = null;
  }

  @override
  void didUpdateWidget(MornyeSelectionPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    _items = null;
    if (oldWidget.selectionColor == null && widget.selectionColor != null) {
      unawaited(_loadMaskProgram());
    }
    if (oldWidget.labels.length != widget.labels.length || oldWidget.selectedIndex != widget.selectedIndex) {
      _dragIndex = null;
      _dragAlignment = null;
      _pressedIndex = null;
      _syncGlide();
    }
  }

  void _preview(double x, double width) {
    if (width <= 0 || widget.labels.isEmpty) return;
    final visual = (x / width * widget.labels.length).floor().clamp(
      0,
      widget.labels.length - 1,
    );
    final logical = Directionality.of(context) == TextDirection.rtl ? widget.labels.length - 1 - visual : visual;
    final halfItem = width / widget.labels.length / 2;
    final position = width <= halfItem * 2 ? 0.0 : ((x.clamp(halfItem, width - halfItem) - halfItem) / (width - 2 * halfItem)) * 2 - 1;
    setState(() {
      _dragIndex = logical;
      _dragAlignment = Directionality.of(context) == TextDirection.rtl ? -position : position;
    });
    _syncGlide(immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.labels.length;
    if (count == 0) return const SizedBox.shrink();
    final selected = _dragIndex ?? _pressedIndex ?? widget.selectedIndex;
    final scheme = Theme.of(context).colorScheme;
    final glassConfig = AppGlassConfigScope.of(context);
    final lensEnabled =
        widget.liquidInteraction &&
        (kIsWeb || defaultTargetPlatform != TargetPlatform.android) &&
        ui.ImageFilter.isShaderFilterSupported &&
        !glassConfig.reduceMotion &&
        !(widget.contrastBlocked ?? glassConfig.highContrast);
    final showInteractionLens = lensEnabled;
    final activeDispersion = glassConfig.dispersion <= 0.005 ? 0.0 : (4.0 * (glassConfig.dispersion / 1.32)).clamp(0.0, 12.0);
    final content = Listener(
      // An accepted drag can end with a PointerCancelEvent. Do not navigate
      // when the OS interrupts the gesture (e.g. opening system controls).
      onPointerDown: (event) {
        if (_activePointer != null) return;
        _activePointer = event.pointer;
        _dragCancelled = false;
        if (!lensEnabled || _pressed) return;
        final box = context.findRenderObject()! as RenderBox;
        final width = box.size.width - widget.padding.horizontal;
        if (width <= 0) return;
        final visual = ((event.localPosition.dx - widget.padding.left) / width * count).floor().clamp(0, count - 1);
        setState(() {
          _pressed = true;
          _pressedIndex = Directionality.of(context) == TextDirection.rtl ? count - visual - 1 : visual;
        });
        _syncGlide();
        unawaited(_pressController.forward());
      },
      onPointerUp: (event) {
        if (event.pointer != _activePointer) return;
        _activePointer = null;
        unawaited(_pressController.reverse());
        setState(() {
          _pressed = false;
          _pressedIndex = null;
          _dragAlignment = null;
        });
        _syncGlide();
      },
      onPointerCancel: (event) {
        if (event.pointer != _activePointer) return;
        _activePointer = null;
        unawaited(_pressController.reverse());
        setState(() {
          _dragCancelled = true;
          _pressed = false;
          _pressedIndex = null;
          _dragAlignment = null;
        });
        _syncGlide();
      },
      child: Padding(
        padding: widget.padding,
        child: LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (event) => _preview(event.localPosition.dx, constraints.maxWidth),
            onHorizontalDragUpdate: (event) => _preview(event.localPosition.dx, constraints.maxWidth),
            onHorizontalDragEnd: (_) {
              final index = _dragIndex;
              setState(() {
                _dragIndex = null;
                _dragAlignment = null;
              });
              _syncGlide();
              if (index != null && !_dragCancelled) widget.onChanged(index);
            },
            onHorizontalDragCancel: () {
              setState(() {
                _dragIndex = null;
                _dragAlignment = null;
              });
              _syncGlide();
            },
            child: Stack(
              fit: StackFit.passthrough,
              clipBehavior: Clip.none,
              children: [
                if (selected >= 0 && selected < count)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_glideController, _pressAnimation]),
                        builder: (context, _) {
                          final progress = lensEnabled ? _pressAnimation.value : 0.0;
                          final restingOpacity = showInteractionLens ? 1 - progress : 1.0;
                          return Align(
                            alignment: AlignmentDirectional(_glideController.value.clamp(-1.35, 1.35), 0),
                            child: FractionallySizedBox(
                              widthFactor: 1 / count,
                              heightFactor: 1,
                              // Share the lens outline while fading into it. A
                              // fixed resting pill leaves a second capsule inside
                              // the held glass, especially during release.
                              child: Transform.scale(
                                scaleX: 1 + _heldWidthGrowth * progress,
                                scaleY: 1 + _heldHeightGrowth * progress,
                                child: DropitChromaticGlass(
                                  radius: _pillRadius,
                                  dispersion: lensEnabled ? activeDispersion * 0.72 : 0.0,
                                  refractionWidth: 16.0,
                                  refractionIndex: 1.52,
                                  magnification: 1.07,
                                  shapeScale: Offset(
                                    1 + _heldWidthGrowth * progress,
                                    1 + _heldHeightGrowth * progress,
                                  ),
                                  enabled: lensEnabled && activeDispersion > 0.005,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: restingOpacity * (scheme.brightness == Brightness.dark ? 0.24 : 0.78),
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        _pillRadius,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: (scheme.brightness == Brightness.dark ? 0.22 : 0.10) * restingOpacity,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 1.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                _foreground(
                  selected,
                  count,
                  lensEnabled,
                  _buildItems(selected),
                ),
                // The lens must sample the foreground as well as the page.
                // On desktop-backed macOS windows the AppKit glass host sits
                // behind Flutter's transparent Metal layer, so skip mounting
                // the resting shader pass over transparent pixels.
                if (showInteractionLens && selected >= 0 && selected < count) _interactionLens(selected, count, lensEnabled),
              ],
            ),
          ),
        ),
      ),
    );
    if (widget.interactionBuilder != null) {
      return AnimatedBuilder(
        animation: _pressAnimation,
        builder: (context, _) => widget.interactionBuilder!(context, lensEnabled ? _pressAnimation.value : 0.0, content),
      );
    }
    return content;
  }

  Widget _buildItems(int selected) {
    // Masked foreground keeps the same icons and labels during a press or
    // drag. Only its shader scope and the lens depend on that animation.
    final itemSelection = widget.selectionColor == null ? selected : null;
    if (_itemsSelected != itemSelection) _items = null;
    _itemsSelected = itemSelection;
    return _items ??= Row(
      key: _foregroundKey,
      children: [
        for (var index = 0; index < widget.labels.length; index++)
          Expanded(
            child: Semantics(
              button: true,
              selected: index == widget.selectedIndex,
              label: widget.labels[index],
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(_pillRadius),
                  // The moving pill supplies press feedback. An ink highlight
                  // would leave a colored patch where the drag started.
                  splashFactory: widget.selectionColor == null ? null : NoSplash.splashFactory,
                  highlightColor: widget.selectionColor == null ? null : Colors.transparent,
                  onTap: () => widget.onChanged(index),
                  child: ExcludeSemantics(
                    child: _item(context, index, selected),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _item(BuildContext context, int index, int selected) {
    final child = widget.itemBuilder(
      context,
      index,
      widget.selectionColor == null && index == selected,
    );
    return widget.maskItemForeground ? MornyeSelectionForeground(child: child) : child;
  }

  Widget _foreground(
    int selected,
    int count,
    bool lensEnabled,
    Widget child,
  ) {
    final color = widget.selectionColor;
    if (color == null) return child;
    return AnimatedBuilder(
      animation: Listenable.merge([_glideController, _pressAnimation]),
      builder: (context, child) {
        final alignment = _glideController.value;
        final progress = lensEnabled ? _pressAnimation.value : 0.0;
        return _SelectionForegroundScope(
          rowKey: _foregroundKey,
          alignment: Directionality.of(context) == TextDirection.rtl ? -alignment : alignment,
          count: count,
          scaleX: 1 + _heldWidthGrowth * progress,
          scaleY: 1 + _heldHeightGrowth * progress,
          program: _maskProgram,
          color: selected >= 0 && selected < count ? color : color.withValues(alpha: 0),
          child: child!,
        );
      },
      child: child,
    );
  }

  Widget _interactionLens(
    int selected,
    int count,
    bool lensEnabled,
  ) => Positioned.fill(
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_glideController, _pressAnimation]),
        builder: (context, child) {
          final progress = lensEnabled ? _pressAnimation.value : 0.0;
          if (progress <= 0.001) return const SizedBox.shrink();
          return Align(
            alignment: AlignmentDirectional(_glideController.value.clamp(-1.35, 1.35), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / count,
              heightFactor: 1,
              child: Transform.scale(
                scaleX: 1 + _heldWidthGrowth * progress,
                scaleY: 1 + _heldHeightGrowth * progress,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_pillRadius),
                  child: LiquidGlassBatch.exclude(
                    child: AppLiquidBackdrop(
                      borderRadius: BorderRadius.circular(_pillRadius),
                      clarity: 1,
                      blurSigma: 0,
                      // A broader bevel makes the held lens visible as it crosses
                      // the icons, while leaving its center undistorted.
                      refractionDepth: 0.24 * progress,
                      refractionWidth: 18,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(_pillRadius),
                          color: Colors.white.withValues(
                            alpha: progress * (Theme.of(context).brightness == Brightness.light ? 0.24 : 0.08),
                          ),
                          border: AppGlassConfigScope.of(context).outlines
                              ? Border.all(
                                  color: Colors.white.withValues(
                                    alpha: 0.6 * progress,
                                  ),
                                  width: 0.75,
                                )
                              : null,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// Paint only icons and labels with the sliding selection color. Badge fills
/// and counters can remain outside this widget and retain their own contrast.
class MornyeSelectionForeground extends StatefulWidget {
  const MornyeSelectionForeground({super.key, required this.child});

  final Widget child;

  @override
  State<MornyeSelectionForeground> createState() => _MornyeSelectionForegroundState();
}

class _MornyeSelectionForegroundState extends State<MornyeSelectionForeground> {
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SelectionForegroundScope>();
    if (scope == null) return widget.child;
    if (_program != scope.program) {
      _shader?.dispose();
      _program = scope.program;
      _shader = _program?.fragmentShader();
    }
    late Rect local;
    late double width;
    late double rowHeight;
    return _SelectionShaderMask(
      maskIntersects: (bounds) {
        // A transparent srcATop source leaves the foreground unchanged.
        if (scope.color.a == 0) return false;
        final rowObj = scope.rowKey.currentContext?.findRenderObject();
        final boxObj = context.findRenderObject();
        if (rowObj is! RenderBox ||
            !rowObj.attached ||
            !rowObj.hasSize ||
            rowObj.size.isEmpty ||
            boxObj is! RenderBox ||
            !boxObj.attached ||
            !boxObj.hasSize ||
            boxObj.size.isEmpty) {
          return false;
        }
        final row = rowObj;
        final box = boxObj;
        width = row.size.width / scope.count;
        rowHeight = row.size.height;
        if (width <= 0 || rowHeight <= 0) return false;
        final left = (scope.alignment + 1) * (row.size.width - width) / 2;
        final lens = Rect.fromCenter(
          center: Offset(left + width / 2, rowHeight / 2),
          width: width * scope.scaleX,
          height: rowHeight * scope.scaleY,
        );
        local = Rect.fromPoints(
          box.globalToLocal(row.localToGlobal(lens.topLeft)),
          box.globalToLocal(row.localToGlobal(lens.bottomRight)),
        );
        // Keep generous AA room, including inverse foreground scaling.
        final padX = 2 * math.max(1.0, local.width / width);
        final padY = 2 * math.max(1.0, local.height / rowHeight);
        return bounds.right >= local.left - padX &&
            bounds.left <= local.right + padX &&
            // The gradient fallback is vertically unbounded.
            (_shader == null || (bounds.bottom >= local.top - padY && bounds.top <= local.bottom + padY));
      },
      shaderCallback: (bounds) {
        // Use the same rounded, expanding bounds as the glass, including the
        // inverse scale of each icon. A one-tab rectangular mask cuts through
        // the foreground before it reaches the held lens's curved edge.
        final shader = _shader;
        if (shader != null) {
          shader
            ..setFloat(0, local.left)
            ..setFloat(1, local.top)
            ..setFloat(2, local.width)
            ..setFloat(3, local.height)
            ..setFloat(4, local.width / width)
            ..setFloat(5, local.height / rowHeight)
            ..setFloat(6, math.min(_pillRadius, math.min(width, rowHeight) / 2))
            ..setFloat(7, scope.color.r)
            ..setFloat(8, scope.color.g)
            ..setFloat(9, scope.color.b)
            ..setFloat(10, scope.color.a);
          return shader;
        }
        return ui.Gradient.linear(
          Offset(local.left, 0),
          Offset(local.right, 0),
          [scope.color, scope.color],
          null,
          TileMode.decal,
        );
      },
      child: widget.child,
    );
  }
}

class _SelectionShaderMask extends ShaderMask {
  const _SelectionShaderMask({
    required this.maskIntersects,
    required super.shaderCallback,
    required super.child,
  }) : super(blendMode: BlendMode.srcATop);

  final bool Function(Rect) maskIntersects;

  @override
  RenderShaderMask createRenderObject(BuildContext context) => _SelectionRenderShaderMask(
    maskIntersects: maskIntersects,
    shaderCallback: shaderCallback,
  );

  @override
  void updateRenderObject(BuildContext context, RenderShaderMask renderObject) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _SelectionRenderShaderMask).maskIntersects = maskIntersects;
  }
}

class _SelectionRenderShaderMask extends RenderShaderMask {
  _SelectionRenderShaderMask({
    required this.maskIntersects,
    required super.shaderCallback,
  }) : super(blendMode: BlendMode.srcATop);

  bool Function(Rect) maskIntersects;

  @override
  void paint(PaintingContext context, Offset offset) {
    final foreground = child;
    if (foreground != null && !maskIntersects(foreground.paintBounds)) {
      // Drop any layer retained from a previous intersecting frame.
      layer = null;
      context.paintChild(foreground, offset);
    } else {
      // The predicate prepared this paint's geometry for shaderCallback.
      super.paint(context, offset);
    }
  }
}

class _SelectionForegroundScope extends InheritedWidget {
  const _SelectionForegroundScope({
    required this.rowKey,
    required this.alignment,
    required this.count,
    required this.scaleX,
    required this.scaleY,
    required this.program,
    required this.color,
    required super.child,
  });

  final GlobalKey rowKey;
  final double alignment;
  final int count;
  final double scaleX;
  final double scaleY;
  final ui.FragmentProgram? program;
  final Color color;

  @override
  bool updateShouldNotify(_SelectionForegroundScope oldWidget) =>
      alignment != oldWidget.alignment ||
      count != oldWidget.count ||
      scaleX != oldWidget.scaleX ||
      scaleY != oldWidget.scaleY ||
      program != oldWidget.program ||
      color != oldWidget.color ||
      rowKey != oldWidget.rowKey;
}
