import 'package:dropit_app/pages/home_page.dart';
import 'package:dropit_app/pages/home_page_controller.dart';
import 'package:dropit_app/widget/mornye/app_atmospheric_backdrop.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_progress.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/liquid_glass_motion.dart';
import 'package:dropit_app/widget/mornye/macos_native_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GlassGeometryInterpolator & LiquidGlassContainer', () {
    test('bridges adjacent same-group controls when active and separates to zero when idle', () {
      const a = Rect.fromLTWH(0, 0, 80, 36);
      const b = Rect.fromLTWH(88, 0, 72, 36); // 8px gap
      const far = Rect.fromLTWH(130, 0, 72, 36); // 50px gap > 14
      const nextRow = Rect.fromLTWH(0, 48, 80, 36); // stacked below

      // Both idle -> zero bridge work.
      expect(GlassGeometryInterpolator.bridgeFactor(a, b, 14, 0.0, 0.0), 0.0);
      expect(
        GlassGeometryInterpolator.buildLiquidBridgePath(
          a: a,
          b: b,
          radiusA: 999,
          radiusB: 999,
          strength: 0.0,
        ),
        isNull,
      );

      // Adjacent hover -> smooth bridge path.
      final hoverStrength = GlassGeometryInterpolator.bridgeFactor(a, b, 14, 0.3, 0.0);
      expect(hoverStrength, greaterThan(0.15));
      expect(hoverStrength, lessThanOrEqualTo(1.0));
      final bridgePath = GlassGeometryInterpolator.buildLiquidBridgePath(
        a: a,
        b: b,
        radiusA: 999,
        radiusB: 999,
        strength: hoverStrength,
      );
      expect(bridgePath, isNotNull);
      expect(bridgePath!.getBounds().left, greaterThan(60));
      expect(bridgePath.getBounds().right, lessThan(105));

      // Too far or separated row -> zero bridge.
      expect(GlassGeometryInterpolator.bridgeFactor(a, far, 14, 1.0, 1.0), 0.0);
      expect(GlassGeometryInterpolator.bridgeFactor(a, nextRow, 10, 1.0, 1.0), 0.0);
    });

    testWidgets('LiquidGlassContainer energizes on child hover and idles with zero tickers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppGlassConfigScope(
            config: const AppGlassConfigData(quality: AppGlassQuality.liquid),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: LiquidGlassContainer(
                  spacing: 14,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LiquidGlassMember(
                        id: 'pill-1',
                        groupId: 'bar',
                        child: AppLiquidGlass(
                          radius: 999,
                          child: SizedBox(width: 72, height: 36, child: Center(child: Text('Online'))),
                        ),
                      ),
                      const SizedBox(width: 8),
                      LiquidGlassMember(
                        id: 'pill-2',
                        groupId: 'bar',
                        child: AppGlassButton(
                          variant: AppGlassButtonVariant.glass,
                          size: AppGlassButtonSize.sm,
                          label: 'Glass',
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(SchedulerBinding.instance.transientCallbackCount, 0);

      final glassButton = find.text('Glass');
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(glassButton));
      await tester.pump(const Duration(milliseconds: 80));

      // Coordinator is active while hovered.
      await tester.pumpAndSettle();
      expect(SchedulerBinding.instance.transientCallbackCount, 0);

      await gesture.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });
  });

  group('Zero-rebuild hover & MacosNativeGlassSurface fast-path', () {
    testWidgets('AppGlassButton hover triggers zero widget rebuilds and settles with zero tickers', (tester) async {
      var childBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AppGlassConfigScope(
            config: const AppGlassConfigData(quality: AppGlassQuality.liquid),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: AppGlassButton(
                  variant: AppGlassButtonVariant.glass,
                  onPressed: () {},
                  child: Builder(
                    builder: (_) {
                      childBuilds++;
                      return const Text('Hover Me');
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(childBuilds, 1);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.text('Hover Me')));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      await gesture.moveTo(const Offset(2, 2));
      await tester.pumpAndSettle();

      // Zero rebuilds across pointer enter, settle, and exit.
      expect(childBuilds, 1);
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });

    testWidgets('MacosNativeGlassSurface skips redundant setSurface updates during child button animations', (tester) async {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var setSurfaceCount = 0;
      MacosNativeGlass.resetForTest();
      MacosNativeGlass.debugSupportedOverride = true;
      addTearDown(() {
        messenger.setMockMethodCallHandler(MacosNativeGlass.channel, null);
        MacosNativeGlass.resetForTest();
      });
      messenger.setMockMethodCallHandler(MacosNativeGlass.channel, (call) async {
        if (call.method == 'setSurface') setSurfaceCount++;
        return true;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AppGlassConfigScope(
            config: const AppGlassConfigData(quality: AppGlassQuality.liquid),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: MacosNativeGlassSurface(
                  id: 'host-panel',
                  radius: 24,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: AppGlassButton(
                      variant: AppGlassButtonVariant.glass,
                      label: 'Animate Child',
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final countAfterLayout = setSurfaceCount;
      expect(countAfterLayout, greaterThanOrEqualTo(1));

      // Press and drag slightly on child button inside the native surface.
      final gesture = await tester.startGesture(tester.getCenter(find.text('Animate Child')));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(2, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Native panel did not move, resize, scroll, or change clip -> zero extra setSurface calls.
      expect(setSurfaceCount, countAfterLayout);
    });
  });

  group('Floating sidebar persistent gliding capsule & lifecycle safety', () {
    testWidgets('DropitGlassSidebar reuses one selection AppLiquidGlass and reverses smoothly when interrupted', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final pageController = PageController(initialPage: 1);
        addTearDown(pageController.dispose);
        var currentTab = HomeTab.send;
        late StateSetter outerSetState;

        await tester.pumpWidget(
          MaterialApp(
            home: AppGlassConfigScope(
              config: const AppGlassConfigData(quality: AppGlassQuality.liquid),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: SizedBox(
                  width: 240,
                  height: 520,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      outerSetState = setState;
                      return DropitGlassSidebar(
                        alias: 'Dropit Mac',
                        online: true,
                        tallSidebar: true,
                        vm: HomePageVm(
                          controller: pageController,
                          currentTab: currentTab,
                          changeTab: (tab) => outerSetState(() => currentTab = tab),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final capsuleFinder = find.descendant(
          of: find.byType(DropitGlassSidebar),
          matching: find.byWidgetPredicate((w) => w is AppLiquidGlass && w.strongTint && w.radius == 18 && w.highlightBorder),
        );
        expect(capsuleFinder, findsOneWidget);
        final sendTop = tester.getTopLeft(capsuleFinder).dy;

        // Tap Settings -> capture mid-glide position -> interrupt toward Receive.
        await tester.tap(find.text(HomeTab.settings.label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 32));
        expect(capsuleFinder, findsOneWidget);
        final midTop = tester.getTopLeft(capsuleFinder).dy;
        expect(midTop, greaterThan(sendTop));

        // Interrupt mid-flight back to Receive.
        await tester.tap(find.text(HomeTab.receive.label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 32));
        expect(capsuleFinder, findsOneWidget);

        await tester.pumpAndSettle();
        final receiveTop = tester.getTopLeft(capsuleFinder).dy;
        expect(receiveTop, greaterThan(sendTop));
        expect(SchedulerBinding.instance.transientCallbackCount, 0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Reduce motion snaps cleanly and AppLifecycleState.paused stops repeating tickers', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: AppGlassConfigScope(
                config: AppGlassConfigData(
                  quality: AppGlassQuality.liquid,
                  backgroundAnimation: true,
                ),
                child: AppAtmosphericBackdrop(
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: Center(
                      child: SizedBox(
                        width: 200,
                        child: AppGlassProgress(progress: null),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(SchedulerBinding.instance.transientCallbackCount, 0);

        // Now mount with motion enabled and verify pause -> resume lifecycle behavior.
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: false),
            child: MaterialApp(
              home: AppGlassConfigScope(
                config: AppGlassConfigData(
                  quality: AppGlassQuality.liquid,
                  backgroundAnimation: true,
                ),
                child: AppAtmosphericBackdrop(
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: Center(
                      child: SizedBox(
                        width: 200,
                        child: AppGlassProgress(progress: null),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(SchedulerBinding.instance.transientCallbackCount, 0);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 16));
        expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
