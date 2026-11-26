import 'dart:async';
import 'package:dropit_app/theme/android_mornye_theme.dart';

import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:flutter/material.dart';

/// Optical Liquid Glass progress bar with luminous fluid fill and
/// smooth interpolated state transitions.
class AppGlassProgress extends StatefulWidget {
  const AppGlassProgress({
    required this.progress,
    this.height = 12,
    this.borderRadius = 999,
    this.color,
    super.key,
  });

  final double? progress;
  final double height;
  final double borderRadius;
  final Color? color;

  @override
  State<AppGlassProgress> createState() => _AppGlassProgressState();
}

class _AppGlassProgressState extends State<AppGlassProgress> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool _animate = false;
  bool _appResumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _syncAnimation() {
    if (!mounted) return;
    final config = AppGlassConfigScope.of(context);
    final isTransferring = widget.progress == null || (!usesAndroidMornye && widget.progress! > 0.0 && widget.progress! < 1.0);
    final shouldRun = _appResumed && !MediaQuery.disableAnimationsOf(context) && config.animateMotion && isTransferring;
    if (shouldRun != _animate) {
      _animate = shouldRun;
      if (_animate) {
        unawaited(_shimmer.repeat());
      } else {
        _shimmer.stop();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(AppGlassProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed != _appResumed) {
      _appResumed = resumed;
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = widget.color ?? scheme.primary;
    final secondaryAccent = Color.lerp(accent, const Color(0xFF086D92), 0.45)!;
    final radius = BorderRadius.circular(widget.borderRadius);

    return RepaintBoundary(
      child: AppLiquidGlass(
        radius: widget.borderRadius,
        blurEnabled: false,
        refractionDepth: 0.14,
        dispersion: 0.0,
        tintOpacity: dark ? 0.24 : 0.34,
        child: SizedBox(
          height: widget.height,
          child: ClipRRect(
            borderRadius: radius,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final fraction = widget.progress?.clamp(0.0, 1.0);
                return AnimatedBuilder(
                  animation: _shimmer,
                  builder: (context, _) {
                    final sweep = _shimmer.value;
                    if (fraction == null) {
                      // Indeterminate flowing optical capsule; stays centered and still when motion is reduced.
                      final barW = width * 0.38;
                      final reduceMotion = !AppGlassConfigScope.of(context).animateMotion;
                      final offsetX = reduceMotion ? (width - barW) * 0.5 : (width + barW) * sweep - barW;
                      return Stack(
                        children: [
                          Positioned(
                            left: offsetX,
                            top: 1.5,
                            bottom: 1.5,
                            width: barW,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: radius,
                                gradient: LinearGradient(
                                  colors: [
                                    accent.withValues(alpha: 0.25),
                                    accent,
                                    secondaryAccent,
                                    accent.withValues(alpha: 0.25),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    final fillW = width * fraction;
                    return Stack(
                      children: [
                        AnimatedContainer(
                          duration: AppGlassConfigScope.of(context).animateMotion ? const Duration(milliseconds: 180) : Duration.zero,
                          curve: Curves.easeOutCubic,
                          width: fillW,
                          height: widget.height,
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                accent,
                                Color.lerp(accent, secondaryAccent, 0.65)!,
                              ],
                            ),
                            boxShadow: fillW > 4
                                ? [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.40),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : const [],
                          ),
                          child: Stack(
                            children: [
                              // Top optical highlight along fluid ridge.
                              Positioned(
                                left: 4,
                                right: 4,
                                top: 1.5,
                                height: (widget.height * 0.34).clamp(2.0, 5.0),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: radius,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.48),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (_animate && fillW > 24)
                                Positioned(
                                  left: (fillW * 1.4) * sweep - fillW * 0.4,
                                  top: 0,
                                  bottom: 0,
                                  width: fillW * 0.45,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0.0),
                                          Colors.white.withValues(alpha: 0.32),
                                          Colors.white.withValues(alpha: 0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
