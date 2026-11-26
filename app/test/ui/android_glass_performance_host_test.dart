import 'dart:ui';

import 'package:dropit_app/widget/mornye/android_glass_performance_host.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FrameTiming _frame(int rasterUs) => FrameTiming(
  vsyncStart: 0,
  buildStart: 0,
  buildFinish: 1000,
  rasterStart: 1000,
  rasterFinish: 1000 + rasterUs,
  rasterFinishWallTime: 1000 + rasterUs,
);

class _Counter extends StatefulWidget {
  const _Counter({required this.onConfig});
  final ValueChanged<AppGlassConfigData> onConfig;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) {
    widget.onConfig(AppGlassConfigScope.of(context));
    return TextButton(onPressed: () => setState(() => count++), child: Text('Count $count'));
  }
}

void main() {
  testWidgets('sustained expensive raster falls back to frost without resetting content or preferences', (tester) async {
    AppGlassConfigData? resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: AppGlassConfigScope(
          config: const AppGlassConfigData(clarity: 0.75, reduceMotion: true, dispersion: 0.4),
          child: AndroidGlassPerformanceHost(
            child: _Counter(onConfig: (config) => resolved = config),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Count 0'));
    await tester.pump();
    final state = tester.state<AndroidGlassPerformanceHostState>(find.byType(AndroidGlassPerformanceHost));
    state.observeTimings(List.generate(35, (_) => _frame(100000)));
    await tester.pump();
    expect(resolved!.quality, AppGlassQuality.liquid);
    state.observeTimings([_frame(100000)]);
    await tester.pump();
    expect(resolved!.quality, AppGlassQuality.frosted);
    expect(resolved!.clarity, 0.75);
    expect(resolved!.reduceMotion, isTrue);
    expect(resolved!.dispersion, 0.4);
    expect(find.text('Count 1'), findsOneWidget);
    await tester.tap(find.text('Count 1'));
    await tester.pump();
    expect(find.text('Count 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('isolated raster spikes do not downgrade glass', (tester) async {
    AppGlassConfigData? resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: AndroidGlassPerformanceHost(
          child: Builder(
            builder: (context) {
              resolved = AppGlassConfigScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final state = tester.state<AndroidGlassPerformanceHostState>(find.byType(AndroidGlassPerformanceHost));
    state.observeTimings(List.generate(60, (index) => _frame(index % 10 == 0 ? 100000 : 2000)));
    await tester.pump();
    expect(resolved!.quality, AppGlassQuality.liquid);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
