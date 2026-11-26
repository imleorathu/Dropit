import 'dart:ui';

import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:flutter/material.dart';

/// Watches sustained raster cost, not device names. Slow shader backends retain
/// frosted glass, edge reflections and interaction rather than dropping to flat.
class AndroidGlassPerformanceHost extends StatefulWidget {
  const AndroidGlassPerformanceHost({required this.child, super.key});

  final Widget child;

  @override
  State<AndroidGlassPerformanceHost> createState() => AndroidGlassPerformanceHostState();
}

class AndroidGlassPerformanceHostState extends State<AndroidGlassPerformanceHost> {
  bool _frosted = false;
  late final bool _registered = usesAndroidMornye;
  int _warmFrames = 0;
  int _samples = 0;
  int _slowFrames = 0;
  double _budgetMs = 1000 / 60;
  AppGlassQuality? _requestedQuality;

  @override
  void initState() {
    super.initState();
    if (_registered) WidgetsBinding.instance.addTimingsCallback(observeTimings);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final quality = AppGlassConfigScope.of(context).effectiveQuality;
    if (_requestedQuality != quality) {
      _requestedQuality = quality;
      _frosted = false;
      _warmFrames = _samples = _slowFrames = 0;
    }
    final refresh = View.of(context).display.refreshRate;
    _budgetMs = 1000 / (refresh > 0 ? refresh : 60);
  }

  /// Public only to inject real-shaped engine timings in deterministic tests.
  @visibleForTesting
  void observeTimings(List<FrameTiming> frames) {
    if (!mounted || _frosted || _requestedQuality != AppGlassQuality.liquid) return;
    for (final frame in frames) {
      // Ignore initial shader/font preparation. A single long frame must not
      // change the material; require a majority of a steady-state window.
      if (_warmFrames++ < 12) continue;
      _samples++;
      if (frame.rasterDuration.inMicroseconds / 1000 > _budgetMs * 1.5) _slowFrames++;
      if (_samples == 24) {
        if (_slowFrames >= 16) {
          setState(() => _frosted = true);
          return;
        }
        _samples = _slowFrames = 0;
      }
    }
  }

  @override
  void dispose() {
    if (_registered) WidgetsBinding.instance.removeTimingsCallback(observeTimings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requested = AppGlassConfigScope.of(context);
    return AppGlassConfigScope(
      config: _frosted ? requested.withQuality(AppGlassQuality.frosted) : requested,
      child: widget.child,
    );
  }
}
