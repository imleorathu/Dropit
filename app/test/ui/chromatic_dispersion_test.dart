import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dropit_app/model/persistence/glass_quality.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_liquid_backdrop.dart';
import 'package:dropit_app/widget/mornye/chromatic_dispersion_diagnostic.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dropit Chromatic Dispersion Optical Engine', () {
    test('DropitOpticalGlassSpec resolves calibrated dispersion at 1.32 px default', () {
      const configDefault = AppGlassConfigData(
        quality: AppGlassQuality.liquid,
        clarity: 0.90,
        refractionIntensity: 1.50,
        dispersion: 1.32,
      );

      final spec = DropitOpticalGlassSpec.resolve(
        config: configDefault,
        preset: DropitOpticalPreset.panel,
      );

      // Calibrated dispersion should be close to 1.32 px
      expect(spec.dispersion, greaterThan(1.10));
      expect(spec.dispersion, lessThan(1.50));

      final style = spec.toShaderStyle(
        brightness: Brightness.light,
        radius: 24.0,
        tintColor: Colors.transparent,
        outlines: true,
      );

      expect(style.dispersion, greaterThan(1.10));
      expect(style.dispersion, lessThan(1.50));
    });

    test('dispersion: 0.0 completely disables chromatic separation', () {
      const configZero = AppGlassConfigData(
        quality: AppGlassQuality.liquid,
        clarity: 0.90,
        refractionIntensity: 1.50,
        dispersion: 0.0,
      );

      final spec = DropitOpticalGlassSpec.resolve(
        config: configZero,
        preset: DropitOpticalPreset.panel,
      );

      expect(spec.dispersion, 0.0);

      final style = spec.toShaderStyle(
        brightness: Brightness.light,
        radius: 24.0,
        tintColor: Colors.transparent,
        outlines: true,
      );

      expect(style.dispersion, 0.0);
    });

    test('dispersion: 2.0 produces stronger chromatic separation', () {
      const configHigh = AppGlassConfigData(
        quality: AppGlassQuality.liquid,
        clarity: 0.90,
        refractionIntensity: 1.50,
        dispersion: 2.0,
      );

      final spec = DropitOpticalGlassSpec.resolve(
        config: configHigh,
        preset: DropitOpticalPreset.panel,
      );

      expect(spec.dispersion, greaterThan(1.70));
      expect(spec.dispersion, lessThanOrEqualTo(2.20));

      final style = spec.toShaderStyle(
        brightness: Brightness.light,
        radius: 24.0,
        tintColor: Colors.transparent,
        outlines: true,
      );

      expect(style.dispersion, greaterThan(1.70));
    });

    test('dispersion: 6.6 and 10.0 produce high visual chromatic separation', () {
      const configStrong = AppGlassConfigData(
        quality: AppGlassQuality.liquid,
        clarity: 0.90,
        refractionIntensity: 1.50,
        dispersion: 6.6,
      );

      final specStrong = DropitOpticalGlassSpec.resolve(
        config: configStrong,
        preset: DropitOpticalPreset.panel,
      );

      expect(specStrong.dispersion, greaterThan(6.0));
      expect(specStrong.dispersion, lessThanOrEqualTo(8.0));

      const configMax = AppGlassConfigData(
        quality: AppGlassQuality.liquid,
        clarity: 0.90,
        refractionIntensity: 1.50,
        dispersion: 10.0,
      );

      final specMax = DropitOpticalGlassSpec.resolve(
        config: configMax,
        preset: DropitOpticalPreset.panel,
      );

      expect(specMax.dispersion, greaterThan(9.0));
      expect(specMax.dispersion, lessThanOrEqualTo(12.0));
    });

    test('Flat quality or zero refraction zeros out dispersion', () {
      const configFlat = AppGlassConfigData(
        quality: AppGlassQuality.flat,
        dispersion: 1.32,
      );

      final specFlat = DropitOpticalGlassSpec.resolve(
        config: configFlat,
        preset: DropitOpticalPreset.capsuleButton,
      );

      expect(specFlat.dispersion, 0.0);

      const configZeroRefraction = AppGlassConfigData(
        quality: AppGlassQuality.liquid,
        refractionIntensity: 0.0,
        dispersion: 1.32,
      );

      final specZeroRefraction = DropitOpticalGlassSpec.resolve(
        config: configZeroRefraction,
        preset: DropitOpticalPreset.toolbar,
      );

      expect(specZeroRefraction.dispersion, 0.0);
    });

    testGlassWidgets('AppLiquidBackdrop passes resolved dispersion to LiquidGlassLens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppGlassConfigScope(
              config: const AppGlassConfigData(
                quality: AppGlassQuality.liquid,
                dispersion: 1.32,
              ),
              child: AppLiquidBackdrop(
                borderRadius: BorderRadius.circular(16),
                child: const SizedBox(width: 200, height: 100),
              ),
            ),
          ),
        ),
      );

      final lensFinder = find.byType(LiquidGlassLens);
      expect(lensFinder, findsOneWidget);

      final lens = tester.widget<LiquidGlassLens>(lensFinder);
      expect(lens.style.dispersion, greaterThan(1.0));
      expect(lens.style.dispersion, lessThan(2.0));
    });

    testGlassWidgets('AppLiquidBackdrop passes high visual dispersion (6.6 and 10.0) to LiquidGlassLens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppGlassConfigScope(
              config: const AppGlassConfigData(
                quality: AppGlassQuality.liquid,
                dispersion: 6.6,
              ),
              child: AppLiquidBackdrop(
                borderRadius: BorderRadius.circular(16),
                child: const SizedBox(width: 200, height: 100),
              ),
            ),
          ),
        ),
      );

      final lensFinder = find.byType(LiquidGlassLens);
      expect(lensFinder, findsOneWidget);

      final lens = tester.widget<LiquidGlassLens>(lensFinder);
      expect(lens.style.dispersion, greaterThan(6.0));
      expect(lens.style.dispersion, lessThan(8.0));
    });

    test('Per-component presets resolve distinct chromatic dispersion baselines', () {
      const config = AppGlassConfigData(
        quality: AppGlassQuality.liquid,
        refractionIntensity: 1.50,
        dispersion: 1.32,
      );

      double resolveFor(DropitOpticalPreset preset) => DropitOpticalGlassSpec.resolve(
        config: config,
        preset: preset,
      ).dispersion;

      expect(resolveFor(DropitOpticalPreset.dropZone), closeTo(3.0, 0.25));
      expect(resolveFor(DropitOpticalPreset.sidebar), closeTo(2.5, 0.25));
      expect(resolveFor(DropitOpticalPreset.toolbar), closeTo(3.5, 0.25));
      expect(resolveFor(DropitOpticalPreset.capsuleButton), closeTo(4.0, 0.25));
      expect(resolveFor(DropitOpticalPreset.searchField), closeTo(2.5, 0.25));
      expect(resolveFor(DropitOpticalPreset.segmented), closeTo(4.0, 0.25));
      expect(
        DropitOpticalGlassSpec.resolve(
          config: const AppGlassConfigData(dispersion: 0.0),
          preset: DropitOpticalPreset.capsuleButton,
        ).dispersion,
        0.0,
      );
    });

    test('dropit_chromatic_glass.frag produces measurable normal-aligned RGB edge separation that scales across 0, 1.32, 3.0, and 4.0 px', () async {
      final program = await ui.FragmentProgram.fromAsset('assets/shaders/dropit_chromatic_glass.frag');

      Future<(int centerMaxDelta, int rimChromaticPixels, double totalRimDelta)> measureAt(double dispersionPx) async {
        final image = await renderChromaticDiagnosticImage(
          program: program,
          dispersionPx: dispersionPx,
          size: const Size(320, 180),
        );
        final artifactDir = Platform.environment['DROPIT_CHROMATIC_ARTIFACT_DIR'];
        if (artifactDir != null && artifactDir.isNotEmpty) {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          if (png != null) {
            final label = dispersionPx.toStringAsFixed(2).replaceAll('.', '_');
            await File('$artifactDir/diag_dispersion_$label.png').writeAsBytes(png.buffer.asUint8List());
          }
        }
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        image.dispose();

        int maxChannelDeltaAt(int x, int y) {
          final idx = (y * 320 + x) * 4;
          final r = bytes.getUint8(idx);
          final g = bytes.getUint8(idx + 1);
          final b = bytes.getUint8(idx + 2);
          return math.max((r - g).abs(), math.max((g - b).abs(), (r - b).abs()));
        }

        // Measure lens center (160, 90) — over monochrome bars/checkerboard, center stays clear.
        var centerMax = 0;
        for (var y = 84; y <= 96; y++) {
          for (var x = 152; x <= 168; x++) {
            centerMax = math.max(centerMax, maxChannelDeltaAt(x, y));
          }
        }

        // Measure upper curved rim & checkerboard corner band (non-aliased 14px cells)
        // where only monochrome black/white geometry sits behind the lens.
        var rimChromaticCount = 0;
        var totalRimDelta = 0.0;
        for (var y = 32; y < 68; y++) {
          for (var x = 38; x < 160; x++) {
            final d = maxChannelDeltaAt(x, y);
            if (d >= 12) rimChromaticCount++;
            totalRimDelta += d;
          }
        }
        return (centerMax, rimChromaticCount, totalRimDelta);
      }

      final (center0, count0, total0) = await measureAt(0.0);
      final (center132, count132, total132) = await measureAt(1.32);
      final (center30, count30, total30) = await measureAt(3.0);
      final (center40, count40, total40) = await measureAt(4.0);

      // Center remains clear with zero chromatic fringe.
      expect(center0, 0);
      expect(center132, 0);
      expect(center30, 0);
      expect(center40, 0);

      // Zero dispersion yields zero color splitting on monochrome checkerboard/bars.
      expect(count0, 0);
      expect(total0, 0.0);

      // Real RGB separation appears cleanly and strengthens monotonically 1.32 -> 3.0 -> 4.0 px.
      expect(count132, greaterThan(15));
      expect(count30, greaterThan(count132));
      expect(total30, greaterThan(total132 * 1.35));
      expect(total40, greaterThan(total30 * 1.05));
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
