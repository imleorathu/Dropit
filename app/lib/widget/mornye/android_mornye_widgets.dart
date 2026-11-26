import 'dart:ui' as ui;

import 'package:dropit_app/model/persistence/glass_quality.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_liquid_backdrop.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Android-only glass compositor. Nested controls retain their optical paint
/// without filtering the same backdrop again. Non-overlapping surfaces share
/// a page batch; modal overlays get an independent backdrop group.
class AndroidMornyeSurface extends StatelessWidget {
  const AndroidMornyeSurface({
    required this.child,
    this.radius = 20,
    this.tintColor,
    this.tintOpacity,
    this.firstInGroup = true,
    this.lastInGroup = true,
    this.focused = false,
    this.focusColor,
    this.modal = false,
    this.control = false,
    this.navigation = false,
    this.samplesBackdrop = true,
    this.blurEnabled = true,
    this.clarity,
    this.quality,
    this.preset = DropitOpticalPreset.panel,
    this.refractionDepth = 0.42,
    this.dispersion,
    this.outlines,
    super.key,
  });

  final Widget child;
  final double radius;
  final Color? tintColor;
  final double? tintOpacity;
  final bool firstInGroup;
  final bool lastInGroup;
  final bool focused;
  final Color? focusColor;
  final bool modal;
  final bool control;
  final bool navigation;
  final bool samplesBackdrop;
  final bool blurEnabled;
  final double? clarity;
  final AppGlassQuality? quality;
  final DropitOpticalPreset preset;
  final double refractionDepth;
  final double? dispersion;
  final bool? outlines;

  static final _clearBlur = ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2);
  static final _frostedBlur = ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3);
  static final _modalBlur = ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final config = AppGlassConfigScope.of(context);
    final dark = theme.brightness == Brightness.dark;
    final level = config.highContrast ? AppGlassQuality.flat : (quality ?? config.effectiveQuality);
    final clear = (clarity ?? config.clarity).clamp(0.0, 1.0);
    final flat = level == AppGlassQuality.flat || clear == 0;
    final insideGlass = context.dependOnInheritedWidgetOfExactType<_AndroidGlassSurfaceScope>() != null;
    final sample = !flat && blurEnabled && samplesBackdrop && !insideGlass && clear > 0.2;
    final useLens = sample && level == AppGlassQuality.liquid && ui.ImageFilter.isShaderFilterSupported && firstInGroup && lastInGroup;
    final borderRadius = BorderRadius.vertical(
      top: Radius.circular(firstInGroup ? radius : 4),
      bottom: Radius.circular(lastInGroup ? radius : 4),
    );
    final tint =
        tintColor ??
        (config.allGlassTintEnabled || (config.deepEdgeTintEnabled && !control && !navigation)
            ? config.deepEdgeTintColor
            : (dark ? scheme.surfaceContainerHigh : Colors.white));
    final opacity = flat ? 1.0 : (tintOpacity ?? (modal ? (dark ? 0.82 : 0.88) : (dark ? 0.40 : 0.56)));
    final fill = flat
        ? scheme.surfaceContainerHigh
        : Color.alphaBlend(
            scheme.surfaceContainerHigh.withValues(alpha: (1 - clear) * (1 - clear)),
            tint.withValues(alpha: opacity.clamp(0.0, 1.0)),
          );
    final surface = DecoratedBox(
      key: const ValueKey('android-liquid-glass-surface'),
      decoration: BoxDecoration(color: fill, borderRadius: borderRadius),
      child: Material(
        type: MaterialType.transparency,
        child: _AndroidGlassSurfaceScope(child: child),
      ),
    );
    final sigma = modal
        ? 6.0
        : level == AppGlassQuality.frosted
        ? 3.0
        : 2.0;
    Widget glass = surface;
    if (useLens) {
      glass = AppLiquidBackdrop(
        borderRadius: borderRadius,
        clarity: clear,
        blurSigma: sigma + config.glassFrost * 4,
        refractionDepth: refractionDepth,
        // Small dispersion keeps reflections neutral rather than rainbow-like.
        dispersion: (dispersion ?? config.dispersion).clamp(0.0, 0.65),
        outlines: outlines ?? config.outlines,
        preset: preset,
        child: surface,
      );
      if (modal || LiquidGlassBatch.backdropIdOf(context) == null) {
        glass = LiquidGlassBatch(child: glass);
      }
    } else if (sample) {
      final filter = modal ? _modalBlur : (level == AppGlassQuality.frosted ? _frostedBlur : _clearBlur);
      glass = modal ? BackdropFilter(filter: filter, child: surface) : BackdropFilter.grouped(filter: filter, child: surface);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: insideGlass || radius == 0
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.14 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: CustomPaint(
          foregroundPainter: ((!useLens && (outlines ?? config.outlines)) || focused)
              ? DropitGlassHighlight(
                  radius: radius,
                  brightness: theme.brightness,
                  refractionIntensity: config.refractionIntensity,
                  clarity: clear,
                  emphasis: flat ? 0.35 : 1,
                  focused: focused,
                  focusColor: focusColor ?? scheme.primary,
                )
              : null,
          child: glass,
        ),
      ),
    );
  }
}

class _AndroidGlassSurfaceScope extends InheritedWidget {
  const _AndroidGlassSurfaceScope({required super.child});

  @override
  bool updateShouldNotify(_AndroidGlassSurfaceScope oldWidget) => false;
}

/// Glass search field preserving the Android input geometry and semantics.
class AndroidMornyeSearchField extends StatelessWidget {
  const AndroidMornyeSearchField({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.placeholder,
    required this.isSearch,
    this.onChanged,
    this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final String placeholder;
  final bool isSearch;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AndroidMornyeSurface(
      radius: 999,
      preset: DropitOpticalPreset.searchField,
      control: true,
      focused: focused,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Icon(
                isSearch ? Symbols.search_rounded : Symbols.edit_rounded,
                size: 20,
                color: focused ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  focusNode: focusNode,
                  controller: controller,
                  onChanged: onChanged,
                  textAlignVertical: TextAlignVertical.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14.5,
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    filled: false,
                    fillColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    contentPadding: EdgeInsets.zero,
                    hintText: placeholder,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14.5,
                      color: scheme.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(
                      Symbols.close_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                      onClear?.call();
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section header matching Mornye's `SettingsSectionHeader`.
class AndroidMornyeSectionHeader extends StatelessWidget {
  const AndroidMornyeSectionHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
