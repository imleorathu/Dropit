import 'dart:async';
import 'dart:ui' as ui;

import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Lazy loader and cache for Dropit's geometry-aware normal-driven chromatic
/// dispersion fragment shader (`assets/shaders/dropit_chromatic_glass.frag`).
class DropitChromaticGlassShaders {
  static Future<ui.FragmentProgram>? _loading;
  static ui.FragmentProgram? _program;

  static ui.FragmentProgram? get program => _program;
  static bool get isLoaded => _program != null;

  static Future<ui.FragmentProgram?> ensureLoaded() async {
    if (_program != null) return _program;
    final pending = _loading ??= ui.FragmentProgram.fromAsset('assets/shaders/dropit_chromatic_glass.frag');
    try {
      return _program = await pending;
    } catch (_) {
      _loading = null;
      return null;
    }
  }

  static ui.FragmentShader? createShader() => _program?.fragmentShader();
}

/// Packs the shared uniform block for both live Impeller `BackdropFilterLayer`
/// rendering and Skia `Paint.shader` / golden verification passes.
void packDropitChromaticGlassUniforms(
  ui.FragmentShader shader, {
  required double scale,
  required Size resolution,
  required Offset lensOrigin,
  required Size lensSize,
  required double cornerRadius,
  required double refractionWidth,
  required double dispersion,
  required double magnification,
  required double refractionIndex,
  double curvatureExponent = 2.1,
  double rimStrength = 0.25,
  double blurSigma = 0.0,
  Offset shapeScale = const Offset(1.0, 1.0),
  double xformA = 1.0,
  double xformB = 0.0,
  double xformC = 0.0,
  double xformD = 1.0,
}) {
  final det = xformA * xformD - xformB * xformC;
  late final double invA;
  late final double invB;
  late final double invC;
  late final double invD;
  if (det.abs() > 1e-4) {
    invA = xformD / det;
    invB = -xformB / det;
    invC = -xformC / det;
    invD = xformA / det;
  } else {
    invA = 1.0;
    invB = 0.0;
    invC = 0.0;
    invD = 1.0;
  }

  var i = 0;
  // u_resolution (0, 1)
  shader.setFloat(i++, resolution.width * scale);
  shader.setFloat(i++, resolution.height * scale);
  // u_lensOrigin (2, 3)
  shader.setFloat(i++, lensOrigin.dx * scale);
  shader.setFloat(i++, lensOrigin.dy * scale);
  // u_lensSize (4, 5)
  shader.setFloat(i++, lensSize.width * scale);
  shader.setFloat(i++, lensSize.height * scale);
  // u_lensParams (6..9): cornerRadiusPx, refractionWidthPx, dispersionPx, magnification
  shader.setFloat(i++, cornerRadius * scale);
  shader.setFloat(i++, refractionWidth * scale);
  shader.setFloat(i++, dispersion * scale);
  shader.setFloat(i++, magnification);
  // u_opticsParams (10..13): refractionIndex, curvatureExponent, rimStrength, blurSigmaPx
  shader.setFloat(i++, refractionIndex);
  shader.setFloat(i++, curvatureExponent);
  shader.setFloat(i++, rimStrength);
  shader.setFloat(i++, blurSigma * scale);
  // u_shapeScale (14, 15)
  shader.setFloat(i++, shapeScale.dx);
  shader.setFloat(i++, shapeScale.dy);
  // u_xformInv (16..19)
  shader.setFloat(i++, invA);
  shader.setFloat(i++, invB);
  shader.setFloat(i++, invC);
  shader.setFloat(i++, invD);
}

/// Applies geometry-aware optical refraction and normal-aligned RGB chromatic
/// dispersion to the live Impeller backdrop behind [child] using a
/// `BackdropFilterLayer` inside its own RenderObject (without polluting widget
/// tests that check `find.byType(BackdropFilter)`).
///
/// On platforms/backends without `ui.ImageFilter.isShaderFilterSupported` or when
/// [enabled] is false / [dispersion] <= 0.005, renders [child] unmodified.
class DropitChromaticGlass extends SingleChildRenderObjectWidget {
  const DropitChromaticGlass({
    required this.radius,
    required this.dispersion,
    this.refractionWidth = 24.0,
    this.refractionIndex = 1.48,
    this.magnification = 1.08,
    this.curvatureExponent = 2.1,
    this.rimStrength = 0.24,
    this.blurSigma = 0.0,
    this.shapeScale = const Offset(1.0, 1.0),
    this.enabled = true,
    super.child,
    super.key,
  });

  final double radius;
  final double dispersion;
  final double refractionWidth;
  final double refractionIndex;
  final double magnification;
  final double curvatureExponent;
  final double rimStrength;
  final double blurSigma;
  final Offset shapeScale;
  final bool enabled;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderDropitChromaticGlass(
      radius: radius,
      dispersion: dispersion,
      refractionWidth: refractionWidth,
      refractionIndex: refractionIndex,
      magnification: magnification,
      curvatureExponent: curvatureExponent,
      rimStrength: rimStrength,
      blurSigma: blurSigma,
      shapeScale: shapeScale,
      enabled: enabled && !usesAndroidMornye,
      screenSize: MediaQuery.sizeOf(context),
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderDropitChromaticGlass renderObject) {
    renderObject
      ..radius = radius
      ..dispersion = dispersion
      ..refractionWidth = refractionWidth
      ..refractionIndex = refractionIndex
      ..magnification = magnification
      ..curvatureExponent = curvatureExponent
      ..rimStrength = rimStrength
      ..blurSigma = blurSigma
      ..shapeScale = shapeScale
      ..enabled = enabled && !usesAndroidMornye
      ..screenSize = MediaQuery.sizeOf(context)
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

class RenderDropitChromaticGlass extends RenderProxyBox {
  RenderDropitChromaticGlass({
    required double radius,
    required double dispersion,
    required double refractionWidth,
    required double refractionIndex,
    required double magnification,
    required double curvatureExponent,
    required double rimStrength,
    required double blurSigma,
    required Offset shapeScale,
    required bool enabled,
    required Size screenSize,
    required double devicePixelRatio,
  }) : _radius = radius,
       _dispersion = dispersion,
       _refractionWidth = refractionWidth,
       _refractionIndex = refractionIndex,
       _magnification = magnification,
       _curvatureExponent = curvatureExponent,
       _rimStrength = rimStrength,
       _blurSigma = blurSigma,
       _shapeScale = shapeScale,
       _enabled = enabled,
       _screenSize = screenSize,
       _devicePixelRatio = devicePixelRatio;

  double _radius;
  double get radius => _radius;
  set radius(double value) {
    if (_radius == value) return;
    _radius = value;
    markNeedsPaint();
  }

  double _dispersion;
  double get dispersion => _dispersion;
  set dispersion(double value) {
    if (_dispersion == value) return;
    _dispersion = value;
    markNeedsPaint();
  }

  double _refractionWidth;
  double get refractionWidth => _refractionWidth;
  set refractionWidth(double value) {
    if (_refractionWidth == value) return;
    _refractionWidth = value;
    markNeedsPaint();
  }

  double _refractionIndex;
  double get refractionIndex => _refractionIndex;
  set refractionIndex(double value) {
    if (_refractionIndex == value) return;
    _refractionIndex = value;
    markNeedsPaint();
  }

  double _magnification;
  double get magnification => _magnification;
  set magnification(double value) {
    if (_magnification == value) return;
    _magnification = value;
    markNeedsPaint();
  }

  double _curvatureExponent;
  double get curvatureExponent => _curvatureExponent;
  set curvatureExponent(double value) {
    if (_curvatureExponent == value) return;
    _curvatureExponent = value;
    markNeedsPaint();
  }

  double _rimStrength;
  double get rimStrength => _rimStrength;
  set rimStrength(double value) {
    if (_rimStrength == value) return;
    _rimStrength = value;
    markNeedsPaint();
  }

  double _blurSigma;
  double get blurSigma => _blurSigma;
  set blurSigma(double value) {
    if (_blurSigma == value) return;
    _blurSigma = value;
    markNeedsPaint();
  }

  Offset _shapeScale;
  Offset get shapeScale => _shapeScale;
  set shapeScale(Offset value) {
    if (_shapeScale == value) return;
    _shapeScale = value;
    markNeedsPaint();
  }

  bool _enabled;
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    markNeedsPaint();
  }

  Size _screenSize;
  Size get screenSize => _screenSize;
  set screenSize(Size value) {
    if (_screenSize == value) return;
    _screenSize = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  ui.FragmentShader? _shader;
  bool _loadingRequested = false;

  @override
  bool get alwaysNeedsCompositing => _enabled && _dispersion > 0.005 && ui.ImageFilter.isShaderFilterSupported;

  @override
  void dispose() {
    _shader?.dispose();
    _shader = null;
    super.dispose();
  }

  void _ensureShader() {
    if (_shader != null) return;
    _shader = DropitChromaticGlassShaders.createShader();
    if (_shader == null && !_loadingRequested) {
      _loadingRequested = true;
      unawaited(
        DropitChromaticGlassShaders.ensureLoaded().then((program) {
          if (program != null && attached) {
            markNeedsPaint();
          }
        }),
      );
    }
  }

  RenderObject? _findFilterSubpassAncestor() {
    RenderObject? cursor = parent;
    while (cursor != null) {
      // ignore: invalid_use_of_protected_member
      if (cursor.layer is ImageFilterLayer) {
        return cursor;
      }
      cursor = cursor.parent;
    }
    return null;
  }

  void _updateUniforms() {
    final shader = _shader;
    if (shader == null || !attached || !hasSize) return;
    final subpass = _findFilterSubpassAncestor();
    final transform = getTransformTo(subpass);
    final s = transform.storage;
    final subpassSize = subpass is RenderBox && subpass.hasSize ? subpass.size : null;
    final resolution = subpassSize ?? _screenSize;
    final origin = MatrixUtils.transformPoint(transform, Offset.zero);
    final cornerR = _radius >= 999 ? (size.shortestSide * 0.5) : _radius.clamp(0.0, size.shortestSide * 0.5);

    packDropitChromaticGlassUniforms(
      shader,
      scale: _devicePixelRatio,
      resolution: resolution,
      lensOrigin: origin,
      lensSize: size,
      cornerRadius: cornerR,
      refractionWidth: _refractionWidth,
      dispersion: _dispersion,
      magnification: _magnification,
      refractionIndex: _refractionIndex,
      curvatureExponent: _curvatureExponent,
      rimStrength: _rimStrength,
      blurSigma: _blurSigma,
      shapeScale: _shapeScale,
      xformA: s[0],
      xformB: s[4],
      xformC: s[1],
      xformD: s[5],
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final active = _enabled && _dispersion > 0.005 && hasSize && !size.isEmpty && ui.ImageFilter.isShaderFilterSupported;
    if (active) {
      _ensureShader();
      final shader = _shader;
      if (shader != null) {
        final filterLayer = (layer is _DropitChromaticBackdropLayer) ? layer! as _DropitChromaticBackdropLayer : _DropitChromaticBackdropLayer();
        filterLayer.onPrepareScene = _updateUniforms;
        filterLayer.filter = ui.ImageFilter.shader(shader);
        context.pushLayer(
          filterLayer,
          (innerContext, innerOffset) {
            super.paint(innerContext, innerOffset);
          },
          offset,
        );
        return;
      }
    }
    layer = null;
    super.paint(context, offset);
  }
}

class _DropitChromaticBackdropLayer extends BackdropFilterLayer {
  VoidCallback? onPrepareScene;

  @override
  void addToScene(ui.SceneBuilder builder) {
    onPrepareScene?.call();
    super.addToScene(builder);
  }
}
