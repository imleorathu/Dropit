import 'dart:math' as math;

import 'package:dropit_app/theme/mornye_theme.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:dropit_app/widget/mornye/macos_native_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Development-only diagnostic backdrop containing checkerboard squares,
/// horizontal/vertical alignment lines, fine reference text, and two reference
/// markers for verifying optical center magnification vs unscaled foregrounds.
class _OpticalDiagnosticBackdrop extends StatelessWidget {
  const _OpticalDiagnosticBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _CheckerAndLinePainter(),
      child: Stack(
        children: const [
          Positioned(
            left: 140,
            top: 90,
            child: Text(
              'REFERENCE GRID 1.0x • AAAABBBBCCCC',
              style: TextStyle(fontSize: 11, color: Colors.white70, letterSpacing: 0.4),
            ),
          ),
          Positioned(
            left: 160,
            top: 150,
            child: SizedBox(
              width: 10,
              height: 10,
              child: ColoredBox(color: Colors.cyanAccent),
            ),
          ),
          Positioned(
            left: 240,
            top: 150,
            child: SizedBox(
              width: 10,
              height: 10,
              child: ColoredBox(color: Colors.amberAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckerAndLinePainter extends CustomPainter {
  const _CheckerAndLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 16.0;
    final dark = Paint()..color = const Color(0xFF141923);
    final light = Paint()..color = const Color(0xFF283347);
    final gridLine = Paint()
      ..color = const Color(0xFF60A5FA)
      ..strokeWidth = 1.2;

    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final odd = ((x ~/ cell) + (y ~/ cell)).isOdd;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), odd ? light : dark);
      }
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridLine);
    }
    for (double x = 0; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridLine);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _diagnosticHarness({
  required AppGlassConfigData config,
  required Widget lensChild,
}) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      body: AppGlassConfigScope(
        config: config,
        child: Stack(
          children: [
            const Positioned.fill(child: _OpticalDiagnosticBackdrop()),
            Center(child: lensChild),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    AppLiquidGlass.debugShaderFilterSupport = true;
  });

  tearDown(() {
    AppLiquidGlass.debugShaderFilterSupport = null;
  });

  group('OpticalLensProfile coherent mathematical model', () {
    test('defines three calibrated optical tiers across Dropit presets', () {
      final profileA = OpticalLensProfile.forPreset(DropitOpticalPreset.capsuleButton);
      final profileB = OpticalLensProfile.forPreset(DropitOpticalPreset.dropZone);
      final profileBCard = OpticalLensProfile.forPreset(DropitOpticalPreset.deviceCard);
      final profileC = OpticalLensProfile.forPreset(DropitOpticalPreset.toolbar);

      expect(profileA.tier, OpticalLensTier.convexButton);
      expect(profileA.magnification, 1.12);
      expect(profileA.refractionStrengthMultiplier, 1.6);
      expect(profileA.edgeWidth, 18.0);
      expect(profileA.curvatureExponent, 2.0);

      expect(profileB.tier, OpticalLensTier.deepEdgePanel);
      expect(profileB.magnification, 1.08);
      expect(profileB.refractionStrengthMultiplier, 2.65);
      expect(profileB.edgeWidth, 34.0);
      expect(profileB.curvatureExponent, 2.15);

      expect(profileBCard.tier, OpticalLensTier.deepEdgePanel);
      expect(profileBCard.magnification, 1.06);
      expect(profileBCard.refractionStrengthMultiplier, 2.40);
      expect(profileBCard.edgeWidth, 32.0);
      expect(profileBCard.curvatureExponent, 2.15);

      expect(profileC.tier, OpticalLensTier.thickCapsule);
      expect(profileC.magnification, 1.18);
      expect(profileC.refractionStrengthMultiplier, 2.2);
      expect(profileC.edgeWidth, 22.0);
      expect(profileC.curvatureExponent, 2.2);
    });

    test('SDF, convex surface height, continuous corner normals, and curvature behave coherently', () {
      const size = Size(200, 120);
      const radius = 28.0;
      const profile = OpticalLensProfile.profileB;

      final center = size.center(Offset.zero);
      final sdfCenter = OpticalLensProfile.signedDistanceRect(point: center, size: size, radius: radius);
      final sdfTopEdge = OpticalLensProfile.signedDistanceRect(
        point: const Offset(100, 0),
        size: size,
        radius: radius,
      );
      final cornerOuterPoint = Offset(
        size.width - radius + radius / math.sqrt2,
        size.height - radius + radius / math.sqrt2,
      );
      final sdfCorner = OpticalLensProfile.signedDistanceRect(
        point: cornerOuterPoint,
        size: size,
        radius: radius,
      );

      expect(sdfCenter, lessThan(-40));
      expect(sdfTopEdge, closeTo(0.0, 1e-6));
      expect(sdfCorner, closeTo(0.0, 1e-4));

      // Surface height forms a plateau inside and curves smoothly to 0 at boundary.
      expect(profile.surfaceHeight(distanceInside: 40), 1.0);
      expect(profile.surfaceHeight(distanceInside: 14), inInclusiveRange(0.7, 0.99));
      expect(profile.surfaceHeight(distanceInside: 0), 0.0);

      // Curvature & chromatic dispersion vanish in the magnified interior and peak near the edge.
      expect(profile.curvatureAt(distanceInside: 40), 0.0);
      expect(profile.dispersionScaleAt(distanceInside: 40), 0.0);
      expect(profile.curvatureAt(distanceInside: 2), greaterThan(0.85));
      expect(profile.specularWeightAt(distanceInside: 2), greaterThan(0.85));

      // Rounded-corner normal smoothly points along the diagonal.
      final cornerNormal = profile.surfaceNormal2D(
        point: Offset(size.width - radius + 12, size.height - radius + 12),
        size: size,
        radius: radius,
      );
      expect(cornerNormal.dx, closeTo(1 / math.sqrt2, 0.03));
      expect(cornerNormal.dy, closeTo(1 / math.sqrt2, 0.03));

      // 3D normal tilts from (0,0,1) in center toward rim outward normal.
      final n3Center = profile.surfaceNormal3D(point: center, size: size, radius: radius);
      expect(n3Center.nz, closeTo(1.0, 1e-3));
      final n3Edge = profile.surfaceNormal3D(
        point: const Offset(100, 3),
        size: size,
        radius: radius,
      );
      expect(n3Edge.ny, lessThan(-0.3));
      expect(
        math.sqrt(n3Edge.nx * n3Edge.nx + n3Edge.ny * n3Edge.ny + n3Edge.nz * n3Edge.nz),
        closeTo(1.0, 1e-5),
      );
    });

    test('center magnification shrinks source sampling delta while keeping refraction aligned to normals', () {
      const size = Size(240, 120);
      const radius = 32.0;
      const profile = OpticalLensProfile.profileC; // 1.18x
      final center = size.center(Offset.zero);

      final offsetPoint = center + const Offset(23.6, 0);
      final magnified = profile.mapMagnifiedOffset(point: offsetPoint, size: size);
      expect((magnified - center).dx, closeTo(20.0, 1e-6));

      // In the center dome, combined sample equals magnified offset (no edge kink).
      final combinedCenter = profile.combinedSampleOffset(
        point: offsetPoint,
        size: size,
        radius: radius,
      );
      expect((combinedCenter - magnified).distance, closeTo(0.0, 1e-6));

      // Near the curved sidewall, refraction shifts sampling smoothly along the inward normal.
      final nearLeftRim = Offset(6, center.dy);
      final refractedLeft = profile.mapRefractedOffset(
        point: nearLeftRim,
        size: size,
        radius: radius,
      );
      expect(refractedLeft.dx, greaterThan(0.5));
      expect(refractedLeft.dy.abs(), lessThan(1e-4));
    });

    test('Deep Edge presets preserve center magnification while exposing a wider, stronger sidewall', () {
      const size = Size(360, 180);
      const radius = 40.0;
      final center = size.center(Offset.zero);
      const panelProfile = OpticalLensProfile.profileB;
      const cardProfile = OpticalLensProfile.profileBCard;

      expect(panelProfile.mapMagnifiedOffset(point: center + const Offset(54, 0), size: size).dx - center.dx, closeTo(50.0, 1e-6));
      expect(cardProfile.mapMagnifiedOffset(point: center + const Offset(53, 0), size: size).dx - center.dx, closeTo(50.0, 1e-6));

      final panelSidewall = panelProfile.mapRefractedOffset(
        point: Offset(6, center.dy),
        size: size,
        radius: radius,
      );
      final cardSidewall = cardProfile.mapRefractedOffset(
        point: Offset(6, center.dy),
        size: size,
        radius: radius,
      );
      expect(panelSidewall.dx, greaterThan(1.9));
      expect(cardSidewall.dx, greaterThan(1.7));
      expect(panelProfile.curvatureAt(distanceInside: 30), greaterThan(0.03));
      expect(cardProfile.curvatureAt(distanceInside: 28), greaterThan(0.03));
    });

    test('all five Deep Edge roles resolve to the intensified geometry without changing magnification', () {
      const config = AppGlassConfigData(
        quality: AppGlassQuality.liquid,
        clarity: kDefaultOpticalClarity,
        refractionIntensity: kDefaultOpticalRefraction,
      );
      const expectedWidths = <DropitOpticalPreset, double>{
        DropitOpticalPreset.sidebar: 48.0,
        DropitOpticalPreset.dropZone: 50.0,
        DropitOpticalPreset.panel: 44.0,
        DropitOpticalPreset.modalSheet: 48.0,
        DropitOpticalPreset.deviceCard: 32.0,
      };

      for (final entry in expectedWidths.entries) {
        final spec = DropitOpticalGlassSpec.resolve(config: config, preset: entry.key);
        expect(spec.refractionWidth, entry.value, reason: entry.key.name);
        expect(spec.magnification, closeTo(entry.key == DropitOpticalPreset.deviceCard ? 1.06 : 1.08, 1e-5), reason: entry.key.name);
      }
    });
  });

  group('Diagnostic optical lens fixture verification', () {
    testGlassWidgets('applies Profile A, B, C shader magnification and strong refraction without scaling child UI', (tester) async {
      const defaultConfig = AppGlassConfigData(
        quality: AppGlassQuality.liquid,
        clarity: kDefaultOpticalClarity,
        refractionIntensity: kDefaultOpticalRefraction,
        dispersion: 1.32,
      );

      Future<LiquidGlassLens> pumpProfile(DropitOpticalPreset preset, Size size, {double depth = 0.38}) async {
        await tester.pumpWidget(
          _diagnosticHarness(
            config: defaultConfig,
            lensChild: AppLiquidGlass(
              preset: preset,
              refractionDepth: depth,
              smoothCorners: true,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: Center(
                  child: Text('LABEL_${preset.name}'),
                ),
              ),
            ),
          ),
        );
        return tester.widget<LiquidGlassLens>(find.byType(LiquidGlassLens));
      }

      // Profile A — Convex Button (1.12x)
      final buttonLens = await pumpProfile(DropitOpticalPreset.capsuleButton, const Size(120, 42), depth: 0.34);
      expect(buttonLens.style.magnification, closeTo(1.12, 0.01));
      expect(buttonLens.style.refractionIndex, greaterThan(1.60));
      expect(buttonLens.style.refractionWidth, closeTo(18.0, 0.5));
      expect(tester.getSize(find.text('LABEL_capsuleButton')).height, greaterThan(0));

      // Profile B — Deep Edge Lens (1.06x - 1.09x)
      final dropZoneLens = await pumpProfile(DropitOpticalPreset.dropZone, const Size(360, 180), depth: 0.48);
      expect(dropZoneLens.style.magnification, inInclusiveRange(1.07, 1.10));
      expect(dropZoneLens.style.refractionIndex, greaterThan(1.85));
      expect(dropZoneLens.style.refractionWidth, closeTo(50.0, 0.5));

      // Profile C — Thick Capsule Lens (1.18x - 1.20x)
      final toolbarLens = await pumpProfile(DropitOpticalPreset.toolbar, const Size(480, 56), depth: 0.48);
      expect(toolbarLens.style.magnification, inInclusiveRange(1.175, 1.21));
      expect(toolbarLens.style.refractionIndex, greaterThan(1.90));
      expect(toolbarLens.style.refractionWidth, closeTo(22.0, 0.5));

      // Verify foreground label stays crisp & unscaled (no ancestor Transform.scale distortion).
      final textBox = tester.renderObject<RenderBox>(find.text('LABEL_toolbar'));
      final rootBox = tester.renderObject<RenderBox>(find.byType(AppLiquidGlass));
      final transform = textBox.getTransformTo(rootBox);
      expect(transform.getMaxScaleOnAxis(), closeTo(1.0, 1e-6));
    });

    testGlassWidgets('supports high experimental refraction intensity up to 1.25x clamped ceiling', (tester) async {
      await tester.pumpWidget(
        _diagnosticHarness(
          config: const AppGlassConfigData(
            quality: AppGlassQuality.liquid,
            clarity: 0.90,
            refractionIntensity: 2.0,
            dispersion: 1.32,
          ),
          lensChild: const AppLiquidGlass(
            preset: DropitOpticalPreset.toolbar,
            refractionDepth: 0.56,
            smoothCorners: true,
            child: SizedBox(width: 480, height: 56),
          ),
        ),
      );
      final lens = tester.widget<LiquidGlassLens>(find.byType(LiquidGlassLens));
      expect(lens.style.magnification, inInclusiveRange(1.20, 1.25));
      expect(lens.style.refractionIndex, greaterThan(2.0));
    });

    testGlassWidgets('uses white secondary text colors on macOS dark mode', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final macDark = MornyeTheme.build(Brightness.dark);
        expect(macDark.colorScheme.onSurfaceVariant, Colors.white);
        expect(macDark.textTheme.bodySmall?.color, Colors.white);
        expect(macDark.textTheme.labelSmall?.color, Colors.white);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testGlassWidgets('clear glass buttons do not send opaque white tint to macOS native glass', (tester) async {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final setCalls = <Map<String, Object?>?>[];
      messenger.setMockMethodCallHandler(MacosNativeGlass.channel, (call) async {
        if (call.method == 'setSurface') {
          setCalls.add((call.arguments as Map?)?.cast<String, Object?>());
        }
        return true;
      });
      MacosNativeGlass.debugSupportedOverride = true;
      addTearDown(() {
        messenger.setMockMethodCallHandler(MacosNativeGlass.channel, null);
        MacosNativeGlass.debugSupportedOverride = false;
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: MornyeTheme.build(Brightness.dark),
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: AppGlassConfigScope(
              config: const AppGlassConfigData(quality: AppGlassQuality.liquid),
              child: Center(
                child: AppGlassButton(
                  variant: AppGlassButtonVariant.clear,
                  size: AppGlassButtonSize.sm,
                  icon: Icons.help_outline,
                  label: 'Need a hand?',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Need a hand?'), findsOneWidget);
      expect(setCalls, isNotEmpty);
      expect(setCalls.last?['clear'], isTrue);
      expect(setCalls.last?['tintArgb'], isNull);
    });
  });
}

// Run the retained optical behavior on its supported platform, resetting before
// Flutter verifies global invariants (ordinary tearDown runs after that check).
void testGlassWidgets(String description, WidgetTesterCallback callback) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await callback(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
