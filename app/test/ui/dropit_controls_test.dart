import 'package:dropit_app/config/theme.dart';
import 'package:dropit_app/model/persistence/color_mode.dart';
import 'package:dropit_app/widget/custom_dropdown_button.dart';
import 'package:dropit_app/widget/dropit/dropit_alert_dialog.dart';
import 'package:dropit_app/widget/dropit/dropit_controls.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/dropit/macos_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_chromatic_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() {
  testGlassWidgets('switch retains keyboard activation and toggled semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return DropitSwitch(value: value, label: 'Receive automatically', onChanged: (next) => setState(() => value = next));
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropitSwitch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(value, isFalse);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testGlassWidgets('toggle uses Mornye geometry, travel and system green track', (tester) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Center(
                child: DropitSwitch(value: value, onChanged: (next) => setState(() => value = next)),
              );
            },
          ),
        ),
      ),
    );
    final track = find.descendant(of: find.byType(DropitSwitch), matching: find.byType(AnimatedContainer));
    final thumb = find.descendant(
      of: find.byType(DropitSwitch),
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.decoration is BoxDecoration && (widget.decoration! as BoxDecoration).color == Colors.white,
      ),
    );
    expect(tester.getSize(track), const Size(63, 28));
    expect(tester.getSize(thumb), const Size(37, 24));
    final offThumb = tester.getTopLeft(thumb);
    await tester.tap(find.byType(DropitSwitch));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(thumb).dx - offThumb.dx, 22);
    expect((tester.widget<AnimatedContainer>(track).decoration as BoxDecoration).color, const Color(0xFF34C759));
  });

  testGlassWidgets('glass alert dialog keeps action and intrinsic layout on a narrow desktop window', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: getTheme(ColorMode.dropit, Colors.blue, Brightness.light, null),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => DropitAlertDialog(
                    title: const Text('Ready to share'),
                    content: const Text('A longer message that wraps inside this narrow dialog.'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          confirmed = true;
                          Navigator.pop(context);
                        },
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AppLiquidGlass), findsOneWidget);
    expect(find.byType(LiquidGlassLens), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  testGlassWidgets('desktop theme uses a transparent canvas and renders optical glass lenses and frosted fallback', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = getTheme(ColorMode.dropit, Colors.blue, brightness, null);
      expect(theme.scaffoldBackgroundColor, Colors.transparent);
      expect(theme.cardColor.a, closeTo(brightness == Brightness.light ? .44 : .32, .01));
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            appBar: DropitAppBar(title: Text('Dropit')),
            body: Center(
              child: DropitPanel(
                child: Text('Optical Panel'),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(LiquidGlassLens), findsNWidgets(2));
      expect(find.byType(DropitPanel), findsOneWidget);

      await tester.pumpWidget(
        AppGlassConfigScope(
          config: const AppGlassConfigData(quality: AppGlassQuality.frosted),
          child: MaterialApp(
            theme: theme,
            home: const Scaffold(
              appBar: DropitAppBar(title: Text('Dropit')),
              body: Center(
                child: DropitPanel(
                  child: Text('Frosted Panel'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNWidgets(2));
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testGlassWidgets('Android uses Mornye material surfaces with opaque scaffold', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final theme = getTheme(ColorMode.dropit, Colors.blue, Brightness.light, null);
    expect(theme.scaffoldBackgroundColor.a, 1);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: Center(
            child: DropitSurface(chrome: true, child: Text('Mobile surface')),
          ),
        ),
      ),
    );
    expect(find.byType(LiquidGlassLens), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testGlassWidgets('control thumb keeps its optical lens without a nested chromatic backdrop', (tester) async {
    var value = 0.5;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 234,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return DropitSlider(
                    value: value,
                    onChanged: (next) => setState(() => value = next),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.byType(DropitSlider)));
    await tester.pump(const Duration(milliseconds: 60));
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.descendant(of: find.byType(DropitSlider), matching: find.byType(LiquidGlassLens)), findsWidgets);
    expect(find.descendant(of: find.byType(DropitSlider), matching: find.byType(DropitChromaticGlass)), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testGlassWidgets('DropitSwitch supports hover without toggle, swipe drag once, and blocks disabled interaction', (tester) async {
    var value = false;
    var changeCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                return DropitSwitch(
                  value: value,
                  onChanged: (next) {
                    changeCount++;
                    setState(() => value = next);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(DropitSwitch)));
    await tester.pump(const Duration(milliseconds: 80));
    expect(value, isFalse);
    expect(changeCount, 0);

    await tester.drag(find.byType(DropitSwitch), const Offset(28, 0));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(changeCount, 1);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: DropitSwitch(value: true, onChanged: null),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropitSwitch));
    await tester.pumpAndSettle();
    expect(changeCount, 1);
  });

  testGlassWidgets('DropitSlider tracks hover, elastic drag stretch, divisions, keyboard steps, and disabled states', (tester) async {
    final semantics = tester.ensureSemantics();
    var value = 0.5;
    var starts = 0;
    var ends = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 234,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return DropitSlider(
                    value: value,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    label: '${(value * 100).round()}%',
                    onChangeStart: (_) => starts++,
                    onChanged: (next) => setState(() => value = next),
                    onChangeEnd: (_) => ends++,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    final sliderBox = find.byType(DropitSlider);
    await mouse.moveTo(tester.getCenter(sliderBox));
    await tester.pump(const Duration(milliseconds: 60));
    expect(value, 0.5);

    // Drag right to top end -> elastic stretch transforms thumb > 1.0 during active drag.
    final gesture = await tester.startGesture(tester.getCenter(sliderBox));
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 40));
    final stretches = tester.widgetList<Transform>(
      find.descendant(of: sliderBox, matching: find.byType(Transform)),
    );
    expect(stretches.any((t) => t.transform.storage[0] > 1.02), isTrue);
    await gesture.up();
    await tester.pumpAndSettle();
    final afterDrag = value;
    expect(afterDrag, greaterThan(0.75));
    expect(starts, 1);
    expect(ends, 1);

    // Tab focus + keyboard stepping
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    final afterLeft = value;
    expect(afterLeft, lessThan(afterDrag));
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(value, 0.0);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(value, 1.0);

    // Disabled blocks input
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 234,
              child: DropitSlider(value: 0.4, onChanged: null),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropitSlider));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testGlassWidgets('GlassSlider, AppGlassButton variants and CustomDropdownButton respond smoothly across interactions', (tester) async {
    var sliderVal = 25.0;
    var pressed = 0;
    var dropdownVal = 'one';
    await tester.pumpWidget(
      MaterialApp(
        theme: getTheme(ColorMode.dropit, Colors.blue, Brightness.dark, null),
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 240,
                      child: GlassSlider(
                        value: sliderVal,
                        onChange: (v) => setState(() => sliderVal = v),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppGlassButton(
                          variant: AppGlassButtonVariant.glass,
                          label: 'Glass',
                          onPressed: () => pressed++,
                        ),
                        const SizedBox(width: 8),
                        AppGlassButton(
                          variant: AppGlassButtonVariant.filled,
                          label: 'Filled',
                          onPressed: () => pressed++,
                        ),
                        const SizedBox(width: 8),
                        AppGlassButton(
                          variant: AppGlassButtonVariant.clear,
                          icon: Icons.add,
                          onPressed: () => pressed++,
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 180,
                      child: CustomDropdownButton<String>(
                        value: dropdownVal,
                        items: const [
                          DropdownMenuItem(value: 'one', child: Text('One')),
                          DropdownMenuItem(value: 'two', child: Text('Two')),
                        ],
                        onChanged: (v) => setState(() => dropdownVal = v),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(DropitSlider), findsOneWidget);
    await tester.tap(find.text('Glass'));
    await tester.tap(find.text('Filled'));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(pressed, 3);

    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Two').last);
    await tester.pumpAndSettle();
    expect(dropdownVal, 'two');
    expect(tester.takeException(), isNull);
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
