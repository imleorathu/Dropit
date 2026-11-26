import 'dart:async';

import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_navigation.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:dropit_app/widget/mornye/macos_native_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    MacosNativeGlass.resetForTest();
    MacosNativeGlass.debugSupportedOverride = true;
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(MacosNativeGlass.channel, null);
    MacosNativeGlass.resetForTest();
  });

  testGlassWidgets('MacosNativeGlassSurface reports setSurface, appearance sync, and removeSurface', (tester) async {
    final calls = <(String, Map<String, Object?>?)>[];
    messenger.setMockMethodCallHandler(MacosNativeGlass.channel, (call) async {
      calls.add((call.method, (call.arguments as Map?)?.cast<String, Object?>()));
      return true;
    });

    await MacosNativeGlass.setAppearance('dark');
    await MacosNativeGlass.setAppearance('dark'); // Deduplicated

    await tester.pumpWidget(
      const MaterialApp(
        home: AppGlassConfigScope(
          config: AppGlassConfigData(quality: AppGlassQuality.liquid),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Padding(
              padding: EdgeInsets.all(20),
              child: AppLiquidGlass(
                nativeId: 'test-dropzone',
                nativeMaterial: MacosNativeGlassMaterial.hud,
                nativeClear: true,
                nativeInteractive: true,
                radius: 32,
                child: SizedBox(width: 240, height: 120, child: Text('Drop')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(calls.where((c) => c.$1 == 'setAppearance'), hasLength(1));
    final setCalls = calls.where((c) => c.$1 == 'setSurface').toList();
    expect(setCalls, isNotEmpty);
    final args = setCalls.last.$2!;
    expect(args['id'], 'test-dropzone');
    expect(args['x'], 20.0);
    expect(args['y'], 20.0);
    expect(args['width'], 240.0);
    expect(args['height'], 120.0);
    expect(args['clear'], isTrue);
    expect(args['interactive'], isTrue);
    expect(args['visible'], isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(calls.any((c) => c.$1 == 'removeSurface' && c.$2?['id'] == 'test-dropzone'), isTrue);
  });

  testGlassWidgets('MacosNativeGlassSurface clips inside scrollable viewport and hides in flat/highContrast', (tester) async {
    final setEvents = <Map<String, Object?>?>[];
    messenger.setMockMethodCallHandler(MacosNativeGlass.channel, (call) async {
      if (call.method == 'setSurface') {
        setEvents.add((call.arguments as Map?)?.cast<String, Object?>());
      }
      return true;
    });

    final controller = ScrollController();
    addTearDown(controller.dispose);

    Widget buildScrollable(AppGlassConfigData config) => MaterialApp(
      home: AppGlassConfigScope(
        config: config,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SizedBox(
            height: 200,
            child: SingleChildScrollView(
              controller: controller,
              child: const Column(
                children: [
                  MacosNativeGlassSurface(
                    id: 'scroll-card',
                    radius: 24,
                    child: SizedBox(width: 300, height: 120),
                  ),
                  SizedBox(height: 500),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildScrollable(const AppGlassConfigData(quality: AppGlassQuality.liquid)));
    await tester.pump();
    expect(setEvents.last?['visible'], isTrue);
    expect(setEvents.last?['clipHeight'], 120.0);

    controller.jumpTo(70);
    await tester.pump();
    expect(setEvents.last?['y'], -70.0);
    expect(setEvents.last?['clipY'], 0.0);
    expect(setEvents.last?['clipHeight'], 50.0);

    controller.jumpTo(200);
    await tester.pump();
    expect(setEvents.last?['visible'], isFalse);

    controller.jumpTo(0);
    await tester.pump();
    await tester.pumpWidget(buildScrollable(const AppGlassConfigData(quality: AppGlassQuality.flat)));
    await tester.pump();
    expect(setEvents.last?['visible'], isFalse);
  });

  testGlassWidgets('MacosNativeGlassSurface clips to ClipRRect ancestors, tracks scaled transforms, and hides at zero opacity', (tester) async {
    final setEvents = <Map<String, Object?>?>[];
    messenger.setMockMethodCallHandler(MacosNativeGlass.channel, (call) async {
      if (call.method == 'setSurface') {
        setEvents.add((call.arguments as Map?)?.cast<String, Object?>());
      }
      return true;
    });

    Widget buildHarness({double scale = 1.0, double opacity = 1.0, double clipWidth = 240.0}) => MaterialApp(
      home: AppGlassConfigScope(
        config: const AppGlassConfigData(quality: AppGlassQuality.liquid),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Align(
            alignment: Alignment.topLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: clipWidth,
                height: 150,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: 0,
                  minHeight: 0,
                  maxWidth: 400,
                  maxHeight: 200,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topLeft,
                      child: const MacosNativeGlassSurface(
                        id: 'clipped-scaled',
                        radius: 20,
                        child: SizedBox(width: 200, height: 100),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildHarness(scale: 1.5, clipWidth: 180));
    await tester.pump();
    expect(setEvents.last?['visible'], isTrue);
    expect(setEvents.last?['width'], closeTo(300.0, 0.5));
    expect(setEvents.last?['height'], closeTo(150.0, 0.5));
    expect(setEvents.last?['clipWidth'], closeTo(180.0, 0.5));

    await tester.pumpWidget(buildHarness(scale: 1.0, opacity: 0.0));
    await tester.pump();
    expect(setEvents.last?['visible'], isFalse);

    await tester.pumpWidget(buildHarness(scale: 1.0, opacity: 1.0, clipWidth: 240));
    await tester.pump();
    expect(setEvents.last?['visible'], isTrue);
    final countBeforeInvalidate = setEvents.length;
    await messenger.handlePlatformMessage(
      MacosNativeGlass.channel.name,
      MacosNativeGlass.channel.codec.encodeMethodCall(const MethodCall('invalidateSurfaces')),
      (_) {},
    );
    await tester.pump();
    expect(setEvents.length, greaterThan(countBeforeInvalidate));
  });

  testGlassWidgets('MacosNativeGlassSurface hides while another route owns the Flutter layer and restores after pop', (tester) async {
    final setEvents = <Map<String, Object?>?>[];
    messenger.setMockMethodCallHandler(MacosNativeGlass.channel, (call) async {
      if (call.method == 'setSurface') {
        setEvents.add((call.arguments as Map?)?.cast<String, Object?>());
      }
      return true;
    });

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const AppGlassConfigScope(
          config: AppGlassConfigData(quality: AppGlassQuality.liquid),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: MacosNativeGlassSurface(
              id: 'covered-route',
              child: SizedBox(width: 240, height: 120),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(setEvents.last?['visible'], isTrue);

    unawaited(
      navigatorKey.currentState!.push<void>(
        PageRouteBuilder<void>(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 120),
          pageBuilder: (_, _, _) => const Scaffold(backgroundColor: Colors.transparent),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(setEvents.last?['id'], 'covered-route');
    expect(setEvents.last?['visible'], isFalse);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(setEvents.last?['id'], 'covered-route');
    expect(setEvents.last?['visible'], isTrue);
  });

  testGlassWidgets('AppGlassSegmented keeps active selection pill visible during press on macOS', (tester) async {
    messenger.setMockMethodCallHandler(MacosNativeGlass.channel, (_) async => true);
    AppLiquidGlass.debugShaderFilterSupport = true;
    addTearDown(() => AppLiquidGlass.debugShaderFilterSupport = null);

    await tester.pumpWidget(
      MaterialApp(
        home: AppGlassConfigScope(
          config: const AppGlassConfigData(quality: AppGlassQuality.liquid),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: AppGlassSegmented(
                value: 0,
                onChanged: (_) {},
                options: const [
                  AppGlassSegmentOption(label: 'Single'),
                  AppGlassSegmentOption(label: 'Multiple'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(tester.getCenter(find.text('Single')));
    var released = false;
    addTearDown(() async {
      if (!released) await gesture.up();
    });
    await tester.pump(const Duration(milliseconds: 120));

    final pillBoxes = tester.widgetList<DecoratedBox>(
      find.descendant(of: find.byType(FractionallySizedBox), matching: find.byType(DecoratedBox)),
    );
    expect(pillBoxes, isNotEmpty);
    expect(((pillBoxes.first.decoration as BoxDecoration).color?.a ?? 0), closeTo(0.78, 0.05));

    released = true;
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testGlassWidgets('AppLiquidGlass forwards glassFrost and switches native clear style when frosted', (tester) async {
    final calls = <Map<String, Object?>?>[];
    messenger.setMockMethodCallHandler(MacosNativeGlass.channel, (call) async {
      if (call.method == 'setSurface') {
        calls.add((call.arguments as Map?)?.cast<String, Object?>());
      }
      return true;
    });

    Widget buildWithFrost(double frost) => MaterialApp(
      home: AppGlassConfigScope(
        config: AppGlassConfigData(quality: AppGlassQuality.liquid, glassFrost: frost),
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: AppLiquidGlass(
            nativeId: 'frost-surface',
            nativeClear: true,
            radius: 28,
            child: SizedBox(width: 240, height: 120),
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildWithFrost(0.0));
    await tester.pump();
    expect(calls.last?['frost'], 0.0);
    expect(calls.last?['clear'], isTrue);

    await tester.pumpWidget(buildWithFrost(0.65));
    await tester.pump();
    expect(calls.last?['frost'], closeTo(0.65, 0.001));
    expect(calls.last?['clear'], isFalse);
  });

  testGlassWidgets('PageView tab switches and scrolled cards stay clipped below toolbar without overlap', (tester) async {
    final activeSurfaces = <String, Map<String, Object?>>{};
    messenger.setMockMethodCallHandler(MacosNativeGlass.channel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, Object?>() ?? <String, Object?>{};
      if (call.method == 'setSurface') {
        activeSurfaces[args['id'] as String] = args;
      } else if (call.method == 'removeSurface') {
        activeSurfaces.remove(args['id']);
      }
      return true;
    });

    final pageController = PageController(initialPage: 0);
    final scrollController = ScrollController();
    addTearDown(pageController.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppGlassConfigScope(
          config: const AppGlassConfigData(quality: AppGlassQuality.liquid),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: MacosNativeGlassSurface(
                    id: 'toolbar-surface',
                    radius: 28,
                    clear: true,
                    child: SizedBox(width: double.infinity, height: 52),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      const MacosNativeGlassSurface(
                        id: 'tab-0-panel',
                        radius: 24,
                        clear: true,
                        child: SizedBox(width: 400, height: 260),
                      ),
                      SingleChildScrollView(
                        controller: scrollController,
                        child: const Column(
                          children: [
                            MacosNativeGlassSurface(
                              id: 'settings-section-1',
                              radius: 24,
                              clear: true,
                              child: SizedBox(width: 400, height: 420),
                            ),
                            SizedBox(height: 15),
                            MacosNativeGlassSurface(
                              id: 'settings-section-2',
                              radius: 24,
                              clear: true,
                              child: SizedBox(width: 400, height: 320),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(activeSurfaces['tab-0-panel']?['visible'], isTrue);
    expect(activeSurfaces.containsKey('settings-section-1'), isFalse);

    pageController.jumpToPage(1);
    await tester.pumpAndSettle();

    expect(activeSurfaces['tab-0-panel']?['visible'] ?? false, isFalse);
    final toolbar = activeSurfaces['toolbar-surface']!;
    final toolbarBottom = (toolbar['clipY']! as double) + (toolbar['clipHeight']! as double);

    final section1Initial = activeSurfaces['settings-section-1']!;
    expect(section1Initial['visible'], isTrue);
    expect(section1Initial['clipY']! as double, greaterThanOrEqualTo(toolbarBottom));

    scrollController.jumpTo(140);
    await tester.pumpAndSettle();

    final section1Scrolled = activeSurfaces['settings-section-1']!;
    expect(section1Scrolled['visible'], isTrue);
    expect(section1Scrolled['y']! as double, lessThan(toolbarBottom));
    expect(section1Scrolled['clipY']! as double, greaterThanOrEqualTo(toolbarBottom));
  });

  testGlassWidgets('100% clarity renders full transparency with zero veil and switches sidebar to clear', (tester) async {
    final activeSurfaces = <String, Map<String, Object?>>{};
    messenger.setMockMethodCallHandler(MacosNativeGlass.channel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, Object?>() ?? <String, Object?>{};
      if (call.method == 'setSurface') {
        activeSurfaces[args['id'] as String] = args;
      } else if (call.method == 'removeSurface') {
        activeSurfaces.remove(args['id']);
      }
      return true;
    });

    Widget buildPanels(AppGlassConfigData config, {Brightness brightness = Brightness.dark}) => MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      home: AppGlassConfigScope(
        config: config,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: const [
              AppLiquidGlass(
                nativeId: 'sidebar-clarity',
                nativeMaterial: MacosNativeGlassMaterial.sidebar,
                preset: DropitOpticalPreset.sidebar,
                strongTint: true,
                radius: 28,
                child: SizedBox(key: ValueKey('sidebar-box'), width: 200, height: 80),
              ),
              AppLiquidGlass(
                nativeId: 'panel-clarity',
                nativeClear: true,
                preset: DropitOpticalPreset.panel,
                radius: 24,
                child: SizedBox(key: ValueKey('panel-box'), width: 200, height: 80),
              ),
              AppLiquidGlass(
                nativeId: 'dropzone-clarity',
                nativeClear: true,
                preset: DropitOpticalPreset.dropZone,
                radius: 32,
                child: SizedBox(key: ValueKey('dropzone-box'), width: 200, height: 80),
              ),
            ],
          ),
        ),
      ),
    );

    double surfaceAlphaAt(int index) {
      final surface = tester.widgetList<DecoratedBox>(find.byKey(const ValueKey('app-liquid-glass-surface'))).elementAt(index);
      return (surface.decoration as BoxDecoration).color!.a;
    }

    // At 100% Clarity and 0% Liquid Frost (Dark + Light), panels have zero overlay veil
    // and even sidebar switches AppKit NSGlassEffectView to `.clear`.
    for (final brightness in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        buildPanels(
          const AppGlassConfigData(quality: AppGlassQuality.liquid, clarity: 1.0, glassFrost: 0.0),
          brightness: brightness,
        ),
      );
      await tester.pump();
      expect(surfaceAlphaAt(0), 0.0);
      expect(surfaceAlphaAt(1), 0.0);
      expect(surfaceAlphaAt(2), 0.0);
      expect(activeSurfaces['sidebar-clarity']?['clear'], isTrue);
      expect(activeSurfaces['panel-clarity']?['clear'], isTrue);
    }

    // At default 90% Clarity, subtle adaptive veil returns and sidebar uses regular material.
    await tester.pumpWidget(
      buildPanels(const AppGlassConfigData(quality: AppGlassQuality.liquid, clarity: 0.90, glassFrost: 0.0)),
    );
    await tester.pump();
    expect(surfaceAlphaAt(0), greaterThan(0.0));
    expect(surfaceAlphaAt(1), greaterThan(0.0));
    expect(activeSurfaces['sidebar-clarity']?['clear'], isFalse);

    // At 100% Clarity + Liquid Frost > 0, frost veil remains active.
    await tester.pumpWidget(
      buildPanels(const AppGlassConfigData(quality: AppGlassQuality.liquid, clarity: 1.0, glassFrost: 0.5)),
    );
    await tester.pump();
    expect(surfaceAlphaAt(1), greaterThan(0.0));

    // At 100% Clarity + explicit All Glass Tint, tint remains visible.
    await tester.pumpWidget(
      buildPanels(const AppGlassConfigData(quality: AppGlassQuality.liquid, clarity: 1.0, glassFrost: 0.0, allGlassTintEnabled: true)),
    );
    await tester.pump();
    expect(surfaceAlphaAt(1), greaterThan(0.0));
  });
}

// Run the retained optical behavior on its supported platform, resetting before
// Flutter verifies global invariants (ordinary tearDown runs after that check).
void testGlassWidgets(String description, WidgetTesterCallback callback) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await callback(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
