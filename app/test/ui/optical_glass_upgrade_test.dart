import 'package:dropit_app/pages/home_page.dart';
import 'package:dropit_app/pages/home_page_controller.dart';
import 'package:dropit_app/provider/persistence_provider.dart';
import 'package:dropit_app/provider/settings_provider.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_dialog.dart';
import 'package:dropit_app/widget/mornye/app_glass_press.dart';
import 'package:dropit_app/widget/mornye/app_glass_progress.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:dropit_app/widget/mornye/macos_native_glass.dart';
import 'package:dropit_app/widget/mornye/mornye_selection_pill.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    MacosNativeGlass.resetForTest();
  });

  testGlassWidgets('DropitGlassToolbar switches native clear flag between liquid and frosted quality', (tester) async {
    MacosNativeGlass.debugSupportedOverride = true;
    final setCalls = <Map<String, Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(MacosNativeGlass.channel, (call) async {
      if (call.method == 'setSurface' && call.arguments is Map) {
        setCalls.add((call.arguments as Map).cast<String, Object?>());
      }
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(MacosNativeGlass.channel, null));

    final controller = PageController();
    addTearDown(controller.dispose);
    final vm = HomePageVm(controller: controller, currentTab: HomeTab.send, changeTab: (_) {});

    Widget buildToolbar(AppGlassQuality quality) => MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppGlassConfigScope(
          config: AppGlassConfigData(quality: quality),
          child: SizedBox(
            width: 560,
            child: DropitGlassToolbar(vm: vm, online: true),
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildToolbar(AppGlassQuality.liquid));
    await tester.pump();
    final liquidToolbar = setCalls.lastWhere((e) => e['id'] == 'main-toolbar');
    expect(liquidToolbar['clear'], isTrue);

    setCalls.clear();
    await tester.pumpWidget(buildToolbar(AppGlassQuality.frosted));
    await tester.pump();
    final frostedToolbar = setCalls.lastWhere((e) => e['id'] == 'main-toolbar');
    expect(frostedToolbar['clear'], isFalse);
  });

  testGlassWidgets('DropitBackdrop paints opaque surface in flat and highContrast modes on macOS', (tester) async {
    MacosNativeGlass.debugSupportedOverride = true;
    const testSurface = Color(0xFF1E222A);

    Widget buildBackdrop(AppGlassConfigData config) => MaterialApp(
      theme: ThemeData.dark().copyWith(
        colorScheme: ThemeData.dark().colorScheme.copyWith(surface: testSurface),
      ),
      home: AppGlassConfigScope(
        config: config,
        child: const DropitBackdrop(child: SizedBox.expand()),
      ),
    );

    await tester.pumpWidget(buildBackdrop(const AppGlassConfigData(quality: AppGlassQuality.liquid)));
    expect(find.byWidgetPredicate((w) => w is ColoredBox && w.color == testSurface), findsNothing);

    await tester.pumpWidget(buildBackdrop(const AppGlassConfigData(quality: AppGlassQuality.flat)));
    expect(find.byWidgetPredicate((w) => w is ColoredBox && w.color == testSurface), findsOneWidget);

    await tester.pumpWidget(buildBackdrop(const AppGlassConfigData(quality: AppGlassQuality.liquid, highContrast: true)));
    expect(find.byWidgetPredicate((w) => w is ColoredBox && w.color == testSurface), findsOneWidget);
  });

  testGlassWidgets('AppGlassProgress indeterminate renders centered static bar when reduceMotion is true', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppGlassConfigScope(
          config: AppGlassConfigData(reduceMotion: true),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: AppGlassProgress(progress: null),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    final positioned = tester.widget<Positioned>(
      find.descendant(of: find.byType(AppGlassProgress), matching: find.byType(Positioned)).last,
    );
    expect(positioned.left, closeTo((240 - 240 * 0.38) * 0.5, 0.01));
  });

  test('SettingsService sanitizes non-finite persisted glass values and clamps bounds', () async {
    SharedPreferences.setMockInitialValues({
      'ls_alias': 'Dropit test device',
      'ls_show_token': 'test-token',
      'ls_security_context': 'test-identity',
      'ls_locale': 'en',
      'ls_color': 'dropit',
      'ls_enable_animations': true,
      'ls_version': 4,
      'ls_glass_clarity': double.nan,
      'ls_refraction_intensity': double.infinity,
    });
    final persistence = await PersistenceService.initialize(supportsDynamicColors: false);
    final state = SettingsService(persistence).init();
    expect(state.glassClarity, kDefaultOpticalClarity);
    expect(state.refractionIntensity, kDefaultOpticalRefraction);

    SharedPreferences.setMockInitialValues({
      'ls_alias': 'Dropit test device',
      'ls_show_token': 'test-token',
      'ls_security_context': 'test-identity',
      'ls_locale': 'en',
      'ls_color': 'dropit',
      'ls_enable_animations': true,
      'ls_version': 4,
      'ls_glass_clarity': 9.0,
      'ls_refraction_intensity': -3.0,
    });
    final boundedPersistence = await PersistenceService.initialize(supportsDynamicColors: false);
    final boundedState = SettingsService(boundedPersistence).init();
    expect(boundedState.glassClarity, 1.0);
    expect(boundedState.refractionIntensity, 0.0);
  });

  testGlassWidgets('showAppGlassDialog opens and dismisses without leaked tickers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppGlassConfigScope(
          config: const AppGlassConfigData(quality: AppGlassQuality.liquid),
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAppGlassDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Optical Dialog'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Optical Dialog'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Optical Dialog'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testGlassWidgets('AppGlassPress tracks hover pointer dynamically for spotlight and clears on exit', (tester) async {
    const targetKey = ValueKey('hover-box');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppGlassPress(
              radius: 18,
              child: SizedBox(
                key: targetKey,
                width: 160,
                height: 48,
                child: ColoredBox(color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
    );

    final state = tester.state<AppGlassPressState>(find.byType(AppGlassPress));
    final boxRect = tester.getRect(find.byKey(targetKey));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);

    await mouse.moveTo(boxRect.centerLeft + const Offset(16, 0));
    await tester.pumpAndSettle();
    final firstPointer = state.pointer;
    expect(firstPointer, isNotNull);

    await mouse.moveTo(boxRect.centerRight - const Offset(16, 0));
    await tester.pump();
    final secondPointer = state.pointer;
    expect(secondPointer, isNotNull);
    expect(secondPointer!.dx, greaterThan(firstPointer!.dx));
    expect(tester.renderObject<RenderBox>(find.byKey(targetKey)).size, const Size(160, 48));

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(state.hovered, isFalse);
    expect(state.press.value, 0.0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testGlassWidgets('MornyeSelectionPill keeps resting pill borderless and AppLiquidGlass respects outlines', (tester) async {
    Widget buildHarness({required bool outlines, required bool reduceMotion}) => MaterialApp(
      home: AppGlassConfigScope(
        config: AppGlassConfigData(
          outlines: outlines,
          reduceMotion: reduceMotion,
          refractionIntensity: 1.5,
        ),
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 240,
                  height: 44,
                  child: MornyeSelectionPill(
                    labels: const ['Send', 'Receive'],
                    selectedIndex: 0,
                    onChanged: (_) {},
                    itemBuilder: (_, index, selected) => Center(child: Text(index == 0 ? 'Send' : 'Receive')),
                  ),
                ),
                const SizedBox(height: 12),
                const AppLiquidGlass(
                  radius: 16,
                  highlightBorder: true,
                  child: SizedBox(width: 120, height: 40),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildHarness(outlines: false, reduceMotion: true));
    expect(
      find.descendant(
        of: find.byType(MornyeSelectionPill),
        matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter is DropitGlassHighlight),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppLiquidGlass),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter?.runtimeType.toString() == '_AppGlassRimPainter',
        ),
      ),
      findsNothing,
    );

    await tester.pumpWidget(buildHarness(outlines: true, reduceMotion: false));
    expect(
      find.descendant(
        of: find.byType(MornyeSelectionPill),
        matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter is DropitGlassHighlight),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppLiquidGlass),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter?.runtimeType.toString() == '_AppGlassRimPainter',
        ),
      ),
      findsOneWidget,
    );
  });

  test('DropitOpticalGlassSpec provides strong optical refraction and wider edge curvature length', () {
    const config = AppGlassConfigData(
      clarity: kDefaultOpticalClarity,
      refractionIntensity: kDefaultOpticalRefraction,
    );
    final dropZoneSpec = DropitOpticalGlassSpec.resolve(
      config: config,
      preset: DropitOpticalPreset.dropZone,
    );
    final dropZoneStyle = dropZoneSpec.toShaderStyle(
      brightness: Brightness.dark,
      radius: 38,
      tintColor: Colors.transparent,
      outlines: true,
      smoothCorners: true,
      depthOverride: 0.48,
    );
    expect(dropZoneSpec.refractionWidth, greaterThanOrEqualTo(40.0));
    expect(dropZoneStyle.refractionWidth, greaterThanOrEqualTo(40.0));
    expect(dropZoneStyle.refractionIndex, greaterThan(1.45));
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
