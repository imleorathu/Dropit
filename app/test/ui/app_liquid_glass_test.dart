import 'package:dropit_app/config/theme.dart';
import 'package:dropit_app/model/persistence/color_mode.dart';
import 'package:dropit_app/widget/mornye/app_atmospheric_backdrop.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_navigation.dart';
import 'package:dropit_app/widget/mornye/app_glass_progress.dart';
import 'package:dropit_app/widget/mornye/app_liquid_backdrop.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_chromatic_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() {
  setUp(() => AppLiquidGlass.debugShaderFilterSupport = true);
  tearDown(() => AppLiquidGlass.debugShaderFilterSupport = null);

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testGlassWidgets('liquid quality renders AppLiquidBackdrop and LiquidGlassLens (${brightness.name})', (tester) async {
      await tester.pumpWidget(
        _glassHarness(
          brightness: brightness,
          config: const AppGlassConfigData(
            quality: AppGlassQuality.liquid,
            clarity: 1.0,
            refractionIntensity: 1.0,
          ),
          child: const AppLiquidGlass(
            child: SizedBox(width: 200, height: 100),
          ),
        ),
      );
      final surface = tester.widget<DecoratedBox>(find.byKey(const ValueKey('app-liquid-glass-surface')));
      final decoration = surface.decoration as BoxDecoration;
      expect(decoration.color!.a, greaterThan(0));
      expect(find.byType(AppLiquidBackdrop), findsOneWidget);
      expect(find.byType(LiquidGlassLens), findsOneWidget);
      expect(find.byType(DropitChromaticGlass), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  }

  testGlassWidgets('Android glass preserves translucent optics on the host renderer', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AppLiquidGlass.debugShaderFilterSupport = true;

    await tester.pumpWidget(
      _glassHarness(
        config: const AppGlassConfigData(quality: AppGlassQuality.liquid, clarity: 1.0),
        child: const AppLiquidGlass(child: SizedBox(width: 300, height: 180)),
      ),
    );

    expect(find.byType(LiquidGlassLens), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byKey(const ValueKey('android-liquid-glass-surface')), findsOneWidget);
  });

  testGlassWidgets('Android without shader filters retains translucent frost', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AppLiquidGlass.debugShaderFilterSupport = false;

    await tester.pumpWidget(
      _glassHarness(
        config: const AppGlassConfigData(quality: AppGlassQuality.liquid, clarity: 1.0),
        child: const AppLiquidGlass(child: SizedBox(width: 300, height: 180)),
      ),
    );

    expect(find.byType(LiquidGlassLens), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byKey(const ValueKey('android-liquid-glass-surface')), findsOneWidget);
  });

  testGlassWidgets('root atmospheric backdrop batches its lenses', (tester) async {
    await tester.pumpWidget(
      AppGlassConfigScope(
        config: const AppGlassConfigData(),
        child: MaterialApp(
          home: AppAtmosphericBackdrop(child: const SizedBox.expand()),
        ),
      ),
    );

    expect(tester.widget<LiquidGlassView>(find.byType(LiquidGlassView)).batch, isTrue);
  });

  testGlassWidgets('frosted quality renders BackdropFilter fallback without LiquidGlassLens', (tester) async {
    await tester.pumpWidget(
      _glassHarness(
        config: const AppGlassConfigData(quality: AppGlassQuality.frosted, clarity: 0.75),
        child: const AppLiquidGlass(
          child: SizedBox(width: 200, height: 100),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(LiquidGlassLens), findsNothing);
  });

  testGlassWidgets('optional tint applies only to Deep Edge glass roles', (tester) async {
    const config = AppGlassConfigData(
      quality: AppGlassQuality.liquid,
      clarity: 0.55,
      deepEdgeTintEnabled: true,
      deepEdgeTintColor: Color(0xFFFF2D55),
    );

    Future<Color> pumpSurface(DropitOpticalPreset preset) async {
      await tester.pumpWidget(
        _glassHarness(
          config: config,
          child: AppLiquidGlass(
            preset: preset,
            child: const SizedBox(width: 200, height: 100),
          ),
        ),
      );
      final surface = tester.widget<DecoratedBox>(find.byKey(const ValueKey('app-liquid-glass-surface')));
      return (surface.decoration as BoxDecoration).color!;
    }

    final panelColor = await pumpSurface(DropitOpticalPreset.panel);
    final buttonColor = await pumpSurface(DropitOpticalPreset.capsuleButton);
    expect(panelColor.r, greaterThan(panelColor.b));
    expect(buttonColor.b, greaterThan(buttonColor.r));
  });

  testGlassWidgets('allGlassTintEnabled tints all glass cards including capsules and toolbars', (tester) async {
    const config = AppGlassConfigData(
      quality: AppGlassQuality.liquid,
      clarity: 0.55,
      deepEdgeTintEnabled: false,
      allGlassTintEnabled: true,
      deepEdgeTintColor: Color(0xFFFF2D55),
    );

    Future<Color> pumpSurface(DropitOpticalPreset preset) async {
      await tester.pumpWidget(
        _glassHarness(
          config: config,
          child: AppLiquidGlass(
            preset: preset,
            child: const SizedBox(width: 200, height: 100),
          ),
        ),
      );
      final surface = tester.widget<DecoratedBox>(find.byKey(const ValueKey('app-liquid-glass-surface')));
      return (surface.decoration as BoxDecoration).color!;
    }

    final panelColor = await pumpSurface(DropitOpticalPreset.panel);
    final capsuleColor = await pumpSurface(DropitOpticalPreset.capsuleButton);
    final toolbarColor = await pumpSurface(DropitOpticalPreset.toolbar);
    expect(panelColor.r, greaterThan(panelColor.b));
    expect(capsuleColor.r, greaterThan(capsuleColor.b));
    expect(toolbarColor.r, greaterThan(toolbarColor.b));
  });

  testGlassWidgets('glassFrost adjusts blur in Liquid Glass mode without leaving liquid mode', (tester) async {
    Future<double> pumpBlur(double frost) async {
      await tester.pumpWidget(
        _glassHarness(
          config: AppGlassConfigData(
            quality: AppGlassQuality.liquid,
            clarity: 0.90,
            glassFrost: frost,
          ),
          child: const AppLiquidGlass(
            child: SizedBox(width: 200, height: 100),
          ),
        ),
      );
      final lens = tester.widget<LiquidGlassLens>(find.byType(LiquidGlassLens));
      return lens.style.blur;
    }

    final clearBlur = await pumpBlur(0.0);
    final frostedBlur = await pumpBlur(0.75);
    expect(frostedBlur, greaterThan(clearBlur));
    expect(find.byType(LiquidGlassLens), findsOneWidget);
  });

  testGlassWidgets('nested glass controls reuse their parent backdrop sample', (tester) async {
    await tester.pumpWidget(
      _glassHarness(
        child: const AppLiquidGlass(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: AppLiquidGlass(
              child: SizedBox(width: 120, height: 44),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(AppLiquidBackdrop), findsOneWidget);
    expect(find.byType(LiquidGlassLens), findsOneWidget);
  });

  testGlassWidgets('flat quality omits optical lens and blur passes', (tester) async {
    await tester.pumpWidget(
      _glassHarness(
        config: const AppGlassConfigData(quality: AppGlassQuality.flat),
        child: const AppLiquidGlass(
          child: SizedBox(width: 200, height: 100),
        ),
      ),
    );
    expect(find.byType(LiquidGlassLens), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    final surface = tester.widget<DecoratedBox>(find.byKey(const ValueKey('app-liquid-glass-surface')));
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.color!.a, closeTo(0.92, 0.01));
  });

  testGlassWidgets('highContrast accessibility forces flat opaque glass even in liquid mode', (tester) async {
    await tester.pumpWidget(
      _glassHarness(
        highContrast: true,
        config: const AppGlassConfigData(
          quality: AppGlassQuality.liquid,
          clarity: 1.0,
          highContrast: true,
        ),
        child: const AppLiquidGlass(
          child: SizedBox(width: 200, height: 100),
        ),
      ),
    );
    expect(find.byType(LiquidGlassLens), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    final surface = tester.widget<DecoratedBox>(find.byKey(const ValueKey('app-liquid-glass-surface')));
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.color!.a, closeTo(0.96, 0.01));
  });

  testGlassWidgets('AppAtmosphericBackdrop mounts LiquidGlassView in liquid mode and disables in flat mode', (tester) async {
    await tester.pumpWidget(
      _glassHarness(
        config: const AppGlassConfigData(quality: AppGlassQuality.liquid, backgroundAnimation: false),
        child: const AppAtmosphericBackdrop(
          child: Scaffold(body: Center(child: Text('Canvas'))),
        ),
      ),
    );
    expect(find.byType(LiquidGlassView), findsOneWidget);
    expect(find.byType(BackdropGroup), findsOneWidget);

    await tester.pumpWidget(
      _glassHarness(
        config: const AppGlassConfigData(quality: AppGlassQuality.flat, backgroundAnimation: false),
        child: const AppAtmosphericBackdrop(
          child: Scaffold(body: Center(child: Text('Canvas'))),
        ),
      ),
    );
    expect(find.byType(LiquidGlassView), findsNothing);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testGlassWidgets('AppAtmosphericBackdrop uses the exact ${brightness.name} product background', (tester) async {
      await tester.pumpWidget(
        _glassHarness(
          brightness: brightness,
          config: const AppGlassConfigData(quality: AppGlassQuality.liquid),
          child: const AppAtmosphericBackdrop(child: SizedBox.expand()),
        ),
      );
      final colors = tester.widgetList<ColoredBox>(find.byType(ColoredBox)).map((box) => box.color);
      expect(colors, contains(brightness == Brightness.light ? const Color(0xFFFFFFFF) : const Color(0xFF080D1B)));
    });
  }

  testGlassWidgets('AppGlassProgress displays determinate progress and respects reduceMotion', (tester) async {
    await tester.pumpWidget(
      _glassHarness(
        reduceMotion: true,
        config: const AppGlassConfigData(reduceMotion: true),
        child: const SizedBox(
          width: 240,
          child: AppGlassProgress(progress: 0.45),
        ),
      ),
    );
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(AppLiquidGlass), findsOneWidget);
  });

  testGlassWidgets('AppGlassNavigation switches active index and respects reduceMotion', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      _glassHarness(
        reduceMotion: true,
        config: const AppGlassConfigData(reduceMotion: true),
        child: StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              width: 340,
              child: AppGlassNavigation(
                items: const [
                  AppGlassNavItem(label: 'Receive', icon: Icons.wifi_tethering),
                  AppGlassNavItem(label: 'Send', icon: Icons.send),
                  AppGlassNavItem(label: 'Settings', icon: Icons.settings),
                ],
                activeIndex: selected,
                onChanged: (idx) => setState(() => selected = idx),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(selected, 1);
  });

  testGlassWidgets('optical engine defaults and 0%-200% refraction scaling visibly drive shader uniforms', (tester) async {
    const defaultConfig = AppGlassConfigData();
    expect(defaultConfig.clarity, 0.90);
    expect(defaultConfig.refractionIntensity, 1.50);

    Future<LiquidGlassLens> pumpLens(double intensity) async {
      await tester.pumpWidget(
        _glassHarness(
          config: AppGlassConfigData(
            quality: AppGlassQuality.liquid,
            clarity: 0.90,
            refractionIntensity: intensity,
          ),
          child: const AppLiquidGlass(
            preset: DropitOpticalPreset.dropZone,
            child: SizedBox(width: 240, height: 140),
          ),
        ),
      );
      return tester.widget<LiquidGlassLens>(find.byType(LiquidGlassLens));
    }

    final lensOff = await pumpLens(0.0);
    final lensMid = await pumpLens(1.0);
    final lensMax = await pumpLens(2.0);

    expect(lensOff.style.refractionIndex, 1.0);
    expect(lensMid.style.refractionIndex, greaterThan(lensOff.style.refractionIndex));
    expect(lensMax.style.refractionIndex, greaterThan(lensMid.style.refractionIndex));
    expect(lensMax.style.dispersion, greaterThan(lensMid.style.dispersion));
    expect(lensMax.style.magnification, greaterThan(lensOff.style.magnification));
  });

  testGlassWidgets('AppGlassSegmented glides with spring physics and settles with zero idle tickers', (tester) async {
    var active = 0;
    await tester.pumpWidget(
      _glassHarness(
        config: const AppGlassConfigData(quality: AppGlassQuality.liquid),
        child: StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              width: 320,
              child: AppGlassSegmented(
                value: active,
                onChanged: (idx) => setState(() => active = idx),
                options: const [
                  AppGlassSegmentOption(label: 'Single'),
                  AppGlassSegmentOption(label: 'Multiple'),
                  AppGlassSegmentOption(label: 'Link'),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Link'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(active, 2);
    expect(tester.binding.transientCallbackCount, 0);
  });
}

Widget _glassHarness({
  required Widget child,
  AppGlassConfigData config = const AppGlassConfigData(),
  Brightness brightness = Brightness.light,
  bool highContrast = false,
  bool reduceMotion = false,
}) {
  return AppGlassConfigScope(
    config: config,
    child: MaterialApp(
      theme: getTheme(ColorMode.dropit, Colors.blue, brightness, null),
      home: MediaQuery(
        data: MediaQueryData(
          highContrast: highContrast,
          disableAnimations: reduceMotion,
        ),
        child: Scaffold(
          body: Center(child: child),
        ),
      ),
    ),
  );
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
