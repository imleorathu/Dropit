import 'package:dropit_app/widget/dropit/dropit_controls.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder get _switch => find.byType(DropitSwitch);
Finder get _thumb => find.descendant(
  of: _switch,
  matching: find.byWidgetPredicate((widget) => widget is Container && widget.constraints?.maxWidth == 37),
);

Widget _host({required Widget child, TextDirection direction = TextDirection.ltr, bool reduceMotion = false, bool contrast = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion, highContrast: contrast),
      child: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  testWidgets('Android reversal retains the current position and commits each tap once', (tester) async {
    var value = false;
    var changes = 0;
    await tester.pumpWidget(
      _host(
        child: StatefulBuilder(
          builder: (context, setState) {
            return DropitSwitch(
              value: value,
              onChanged: (next) => setState(() {
                value = next;
                changes++;
              }),
            );
          },
        ),
      ),
    );
    final origin = tester.getTopLeft(_thumb).dx;
    await tester.tap(_switch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final inFlight = tester.getTopLeft(_thumb).dx;
    expect(inFlight, greaterThan(origin));
    expect(inFlight, lessThan(origin + 22));
    await tester.tap(_switch);
    await tester.pump();
    expect(tester.getTopLeft(_thumb).dx, closeTo(inFlight, 0.01));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_thumb).dx, closeTo(origin, 0.01));
    expect(value, isFalse);
    expect(changes, 2);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('Android cancelled drag restores the controlled value without committing', (tester) async {
    var changes = 0;
    await tester.pumpWidget(_host(child: DropitSwitch(value: false, onChanged: (_) => changes++)));
    final origin = tester.getTopLeft(_thumb).dx;
    final gesture = await tester.startGesture(tester.getCenter(_switch));
    await gesture.moveBy(const Offset(25, 0));
    await tester.pump(const Duration(milliseconds: 70));
    expect(tester.getTopLeft(_thumb).dx, greaterThan(origin));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(changes, 0);
    expect(tester.getTopLeft(_thumb).dx, closeTo(origin, 0.01));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('Android RTL drag follows the visual on direction', (tester) async {
    var value = false;
    await tester.pumpWidget(
      _host(
        direction: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setState) {
            return DropitSwitch(value: value, onChanged: (next) => setState(() => value = next));
          },
        ),
      ),
    );
    final off = tester.getTopLeft(_thumb).dx;
    await tester.drag(_switch, const Offset(-30, 0));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(tester.getTopLeft(_thumb).dx, closeTo(off - 22, 0.01));
  });

  testWidgets('Android enlarged touch target and reduced motion keep immediate solid feedback', (tester) async {
    var value = false;
    await tester.pumpWidget(
      _host(
        reduceMotion: true,
        child: StatefulBuilder(
          builder: (context, setState) {
            return DropitSwitch(value: value, onChanged: (next) => setState(() => value = next));
          },
        ),
      ),
    );
    expect(tester.getSize(_switch), const Size(71, 48));
    // Tap above the 28px visual track, inside the accessible touch target.
    await tester.tapAt(tester.getTopLeft(_switch) + const Offset(35, 3));
    await tester.pump();
    expect(value, isTrue);
    expect((tester.widget<Container>(_thumb).decoration as BoxDecoration).color, Colors.white);
    expect(find.descendant(of: _switch, matching: find.byType(Transform)), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('Android enabling reduced motion during a flight settles immediately', (tester) async {
    var value = false;
    var reduceMotion = false;
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return _host(
            reduceMotion: reduceMotion,
            child: DropitSwitch(value: value, onChanged: (next) => setState(() => value = next)),
          );
        },
      ),
    );
    final origin = tester.getTopLeft(_thumb).dx;
    await tester.tap(_switch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    update(() => reduceMotion = true);
    await tester.pump();
    expect(tester.getTopLeft(_thumb).dx, closeTo(origin + 22, 0.01));
    expect((tester.widget<Container>(_thumb).decoration as BoxDecoration).color, Colors.white);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('Android high contrast keeps an opaque thumb during a press', (tester) async {
    await tester.pumpWidget(_host(contrast: true, child: DropitSwitch(value: false, onChanged: (_) {})));
    final gesture = await tester.startGesture(tester.getCenter(_switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final decoration = tester.widget<Container>(_thumb).decoration as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(decoration.gradient, isNull);
    expect(find.descendant(of: _switch, matching: find.byType(BackdropFilter)), findsNothing);
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('Android frosted fallback shows reflections during drag and settles opaque', (tester) async {
    AppLiquidGlass.debugShaderFilterSupport = false;
    addTearDown(() => AppLiquidGlass.debugShaderFilterSupport = true);
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        AppGlassConfigScope(
          config: const AppGlassConfigData(quality: AppGlassQuality.frosted),
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: Center(child: DropitSwitch(value: false, onChanged: (_) {})),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(_switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 60));
      expect((tester.widget<Container>(_thumb).decoration as BoxDecoration).gradient, isA<LinearGradient>());
      expect(find.descendant(of: _switch, matching: find.byType(BackdropFilter)), findsNothing);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect((tester.widget<Container>(_thumb).decoration as BoxDecoration).color, Colors.white);
    }
  });
}
