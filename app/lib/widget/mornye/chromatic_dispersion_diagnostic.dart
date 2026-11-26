import 'dart:ui' as ui;

import 'package:dropit_app/model/persistence/glass_quality.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/dropit_chromatic_glass.dart';
import 'package:flutter/material.dart';

/// Development- and test-only high-contrast optical calibration pattern
/// featuring black/white checkerboard squares, 2px vertical & horizontal lines,
/// and saturated geometric shapes to verify real geometry-aware RGB chromatic
/// dispersion across curved Liquid Glass edges.
///
/// Not mounted in production UI routes.
class ChromaticCalibrationBackdrop extends StatelessWidget {
  const ChromaticCalibrationBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChromaticCalibrationPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _ChromaticCalibrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    paintCalibrationPattern(canvas, size);
  }

  static void paintCalibrationPattern(Canvas canvas, Size size) {
    final whitePaint = Paint()..color = const Color(0xFFFFFFFF);
    final blackPaint = Paint()..color = const Color(0xFF000000);
    canvas.drawRect(Offset.zero & size, whitePaint);

    // Top-left & bottom-right checkerboard quadrants.
    const cell = 14.0;
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final col = (x / cell).floor();
        final row = (y / cell).floor();
        if (((col + row) & 1) == 0 && (y < size.height * 0.45 || x > size.width * 0.68)) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), blackPaint);
        }
      }
    }

    // Fine vertical bars (middle-left band) to test horizontal edge dispersion.
    final barPaint = Paint()..color = const Color(0xFF000000);
    for (double x = 8; x < size.width * 0.50; x += 6) {
      canvas.drawRect(
        Rect.fromLTWH(x, size.height * 0.48, 2.5, size.height * 0.24),
        barPaint,
      );
    }

    // Fine horizontal bars (bottom band) to test top/bottom edge dispersion.
    for (double y = size.height * 0.74; y < size.height - 6; y += 6) {
      canvas.drawRect(
        Rect.fromLTWH(8, y, size.width * 0.62, 2.5),
        barPaint,
      );
    }

    // High-contrast shapes for diagonal / corner refraction inspection.
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.25),
      size.shortestSide * 0.12,
      Paint()..color = const Color(0xFF0A84FF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.56, size.height * 0.52, size.width * 0.26, size.height * 0.16),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFFF3B30),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Captures or rasterizes the optical calibration scene through
/// `assets/shaders/dropit_chromatic_glass.frag` at the requested [dispersionPx]
/// so automated tests and visual comparison tools can verify exact RGB separation
/// without requiring live WindowServer desktop pixels.
Future<ui.Image> renderChromaticDiagnosticImage({
  required ui.FragmentProgram program,
  required double dispersionPx,
  Size size = const Size(320, 180),
  double cornerRadius = 32.0,
  double refractionWidth = 28.0,
  double refractionIndex = 1.56,
  double magnification = 1.10,
}) async {
  // 1. Rasterize the crisp calibration backdrop into an Image.
  final bgRecorder = ui.PictureRecorder();
  final bgCanvas = Canvas(bgRecorder, Offset.zero & size);
  _ChromaticCalibrationPainter.paintCalibrationPattern(bgCanvas, size);
  final bgPicture = bgRecorder.endRecording();
  final bgImage = await bgPicture.toImage(size.width.round(), size.height.round());
  bgPicture.dispose();

  // 2. Render the transparent rounded Liquid Glass capsule over the backdrop.
  final lensRect = Rect.fromCenter(
    center: Offset(size.width * 0.5, size.height * 0.5),
    width: size.width * 0.76,
    height: size.height * 0.64,
  );
  final shader = program.fragmentShader();
  packDropitChromaticGlassUniforms(
    shader,
    scale: 1.0,
    resolution: size,
    lensOrigin: lensRect.topLeft,
    lensSize: lensRect.size,
    cornerRadius: cornerRadius,
    refractionWidth: refractionWidth,
    dispersion: dispersionPx,
    magnification: magnification,
    refractionIndex: refractionIndex,
    curvatureExponent: 2.1,
    rimStrength: 0.20,
    blurSigma: 0.0,
  );
  shader.setImageSampler(0, bgImage);

  final outRecorder = ui.PictureRecorder();
  final outCanvas = Canvas(outRecorder, Offset.zero & size);
  outCanvas.drawImage(bgImage, Offset.zero, Paint());
  outCanvas.drawRRect(
    RRect.fromRectAndRadius(lensRect, Radius.circular(cornerRadius)),
    Paint()..shader = shader,
  );
  final outPicture = outRecorder.endRecording();
  final outImage = await outPicture.toImage(size.width.round(), size.height.round());
  outPicture.dispose();
  shader.dispose();
  bgImage.dispose();
  return outImage;
}

/// Dev-only side-by-side comparison grid comparing `0.0`, `1.32`, `3.0`, and
/// `4.0` px chromatic dispersion over high-contrast calibration geometry.
class ChromaticDispersionDiagnosticView extends StatelessWidget {
  const ChromaticDispersionDiagnosticView({
    this.dispersions = const [0.0, 1.32, 3.0, 4.0],
    super.key,
  });

  final List<double> dispersions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final dispersion in dispersions)
          SizedBox(
            width: 300,
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ChromaticCalibrationBackdrop(),
                  Center(
                    child: SizedBox(
                      width: 220,
                      height: 112,
                      child: AppGlassConfigScope(
                        config: AppGlassConfigData(
                          quality: AppGlassQuality.liquid,
                          clarity: 0.92,
                          refractionIntensity: 1.50,
                          dispersion: dispersion <= 0.005 ? 0.0 : 1.32,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: DropitChromaticGlass(
                            radius: 32,
                            dispersion: dispersion,
                            refractionWidth: 28,
                            refractionIndex: 1.56,
                            magnification: 1.10,
                            curvatureExponent: 2.1,
                            enabled: dispersion > 0.005,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.0),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Dispersion ${dispersion.toStringAsFixed(2)} px',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
