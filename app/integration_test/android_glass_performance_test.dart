import 'dart:ui' as ui;

import 'package:dropit_app/main.dart' as app;
import 'package:dropit_app/pages/home_page.dart';
import 'package:dropit_app/pages/tabs/settings_tab.dart';
import 'package:dropit_app/widget/dropit/dropit_controls.dart';
import 'package:dropit_app/widget/mornye/android_glass_performance_host.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Android glass navigation, settings and continuous input profile', (tester) async {
    final startup = Stopwatch()..start();
    await app.main([]);
    for (var i = 0; i < 180 && find.byType(HomePage).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byType(HomePage), findsOneWidget);
    final startupMs = startup.elapsedMilliseconds;
    await tester.pump(const Duration(milliseconds: 500));

    Future<void> selectTab(int index) async {
      final nav = tester.widget<AppGlassNavigation>(find.byType(AppGlassNavigation));
      await tester.tap(find.descendant(of: find.byType(AppGlassNavigation), matching: find.text(nav.items[index].label)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.widget<AppGlassNavigation>(find.byType(AppGlassNavigation)).activeIndex, index);
    }

    // Warm each destination once before collecting steady-state frame timings.
    for (var warmup = 0; warmup < 6; warmup++) {
      for (var i = 0; i < 3; i++) {
        await selectTab(i);
      }
    }
    await tester.pump(const Duration(seconds: 1));
    final effectiveQuality = AppGlassConfigScope.of(tester.element(find.byType(HomePage))).effectiveQuality;
    await measureFrames(binding, () async {
      for (var round = 0; round < 5; round++) {
        for (var i = 0; i < 3; i++) {
          await selectTab(i);
        }
      }
      final scrollable = find.descendant(of: find.byType(SettingsTab), matching: find.byType(Scrollable)).first;
      for (var i = 0; i < 4; i++) {
        await tester.fling(scrollable, const Offset(0, -350), 900);
        await tester.pump(const Duration(milliseconds: 500));
      }
      for (var i = 0; i < 4; i++) {
        await tester.fling(scrollable, const Offset(0, 350), 900);
        await tester.pump(const Duration(milliseconds: 500));
      }
    }, reportKey: 'navigation_and_settings');

    // Exercise production controls without mutating network/security preferences.
    // Same widgets, compositor and callbacks as settings; isolated harness values.
    var value = 0.5;
    var enabled = false;
    var changes = 0;
    final theme = Theme.of(tester.element(find.byType(HomePage)));
    final runtimeConfig = AppGlassConfigScope.of(tester.element(find.byType(HomePage)));
    await tester.pumpWidget(
      AppGlassConfigScope(
        config: runtimeConfig,
        child: MaterialApp(
          theme: theme,
          home: AndroidGlassPerformanceHost(
            child: Scaffold(
              body: Center(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return SizedBox(
                      width: 300,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropitSwitch(value: enabled, onChanged: (next) => setState(() => enabled = next)),
                          DropitSlider(
                            value: value,
                            onChanged: (next) => setState(() {
                              value = next;
                              changes++;
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await measureFrames(binding, () async {
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byType(DropitSwitch));
        await tester.pump(const Duration(milliseconds: 70));
      }
      for (var i = 0; i < 8; i++) {
        await tester.timedDrag(find.byType(DropitSlider), Offset(i.isEven ? 210 : -210, 0), const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 80));
      }
      await tester.pump(const Duration(milliseconds: 500));
    }, reportKey: 'continuous_controls');
    expect(changes, greaterThan(8));
    expect(tester.takeException(), isNull);
    binding.reportData!['environment'] = {
      'startup_to_home_ms': startupMs,
      'effective_quality_after_warmup': effectiveQuality.name,
      'effective_quality_for_controls': runtimeConfig.effectiveQuality.name,
      'shader_filters_supported': ui.ImageFilter.isShaderFilterSupported,
      'display_refresh_hz': ui.PlatformDispatcher.instance.views.first.display.refreshRate,
      'device_pixel_ratio': ui.PlatformDispatcher.instance.views.first.devicePixelRatio,
      'note': 'Profile-mode emulator observations; physical-device acceptance remains required.',
    };
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

// Collect the engine's actual UI/raster timings without a second VM-service
// connection from inside Android (DDS/localhost routing varies by test host).
Future<void> measureFrames(
  IntegrationTestWidgetsFlutterBinding binding,
  Future<void> Function() action, {
  required String reportKey,
}) async {
  final frames = <ui.FrameTiming>[];
  void collect(List<ui.FrameTiming> batch) => frames.addAll(batch);
  binding.addTimingsCallback(collect);
  try {
    debugPrint('Profiling $reportKey');
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
  } finally {
    binding.removeTimingsCallback(collect);
  }
  expect(frames, isNotEmpty, reason: 'The profile must contain real engine frame timings.');
  final refresh = ui.PlatformDispatcher.instance.views.first.display.refreshRate;
  final budget = 1000 / (refresh > 0 ? refresh : 60);
  Map<String, num> summarize(List<double> values) {
    values.sort();
    double percentile(double p) => values[((values.length - 1) * p).round()];
    return {
      'mean_ms': values.reduce((a, b) => a + b) / values.length,
      'p50_ms': percentile(0.5),
      'p90_ms': percentile(0.9),
      'p95_ms': percentile(0.95),
      'p99_ms': percentile(0.99),
      'max_ms': values.last,
      'over_frame_budget': values.where((value) => value > budget).length,
    };
  }

  binding.reportData ??= <String, dynamic>{};
  binding.reportData![reportKey] = {
    'frame_count': frames.length,
    'frame_budget_ms': budget,
    'ui_build': summarize([for (final frame in frames) frame.buildDuration.inMicroseconds / 1000]),
    'raster': summarize([for (final frame in frames) frame.rasterDuration.inMicroseconds / 1000]),
    'raw_ui_raster_ms': [
      for (final frame in frames) [frame.buildDuration.inMicroseconds / 1000, frame.rasterDuration.inMicroseconds / 1000],
    ],
  };
  debugPrint('Recorded ${frames.length} frames for $reportKey');
}
