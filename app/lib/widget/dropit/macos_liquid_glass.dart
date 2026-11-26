import 'package:dropit_app/provider/settings_provider.dart';
import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/widget/dialogs/custom_color_dialog.dart';
import 'package:dropit_app/widget/dropit/dropit_controls.dart';
import 'package:dropit_app/widget/mornye/android_mornye_widgets.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_dialog.dart';
import 'package:dropit_app/widget/mornye/app_glass_navigation.dart';
import 'package:dropit_app/widget/mornye/app_glass_panel.dart';
import 'package:dropit_app/widget/mornye/app_glass_press.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Liquid Glass is enabled on desktop/Apple targets and replaced by Mornye
/// Material 3 Expressive surfaces exclusively on Android.
bool isMacOSLiquidGlass(BuildContext context) => !usesAndroidMornye;

/// Compatibility wrapper — the root [AppAtmosphericBackdrop] now hosts the
/// single `LiquidGlassView` + atmospheric canvas at `MaterialApp.builder`.
class MacosLiquidGlassBackdrop extends StatelessWidget {
  final Widget child;

  const MacosLiquidGlassBackdrop({required this.child, super.key});

  @override
  Widget build(BuildContext context) => child;
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? intensity;
  final Color? tint;
  final EdgeInsetsGeometry padding;
  final double radius;
  final String variant; // 'regular' | 'clear'

  const GlassCard({
    required this.child,
    this.intensity,
    this.tint,
    this.padding = const EdgeInsets.all(22),
    this.radius = 28,
    this.variant = 'regular',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassPanel(
      radius: radius,
      chrome: variant != 'clear',
      tintColor: tint,
      padding: padding,
      child: child,
    );
  }
}

enum GlassButtonVariant { glass, clear, tinted, tintedFilled, filled }

enum GlassButtonSize { sm, md, lg }

class GlassButton extends StatelessWidget {
  final GlassButtonVariant variant;
  final GlassButtonSize size;
  final bool destructive;
  final Color? tint;
  final IconData? icon;
  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final double? intensity;

  const GlassButton({
    this.variant = GlassButtonVariant.glass,
    this.size = GlassButtonSize.md,
    this.destructive = false,
    this.tint,
    this.icon,
    this.label,
    this.child,
    this.onPressed,
    this.intensity,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final mappedVariant = switch (variant) {
      GlassButtonVariant.glass => AppGlassButtonVariant.glass,
      GlassButtonVariant.clear => AppGlassButtonVariant.clear,
      GlassButtonVariant.tinted => AppGlassButtonVariant.tinted,
      GlassButtonVariant.tintedFilled => AppGlassButtonVariant.tintedFilled,
      GlassButtonVariant.filled => AppGlassButtonVariant.filled,
    };
    final mappedSize = switch (size) {
      GlassButtonSize.sm => AppGlassButtonSize.sm,
      GlassButtonSize.md => AppGlassButtonSize.md,
      GlassButtonSize.lg => AppGlassButtonSize.lg,
    };
    return AppGlassButton(
      variant: mappedVariant,
      size: mappedSize,
      destructive: destructive,
      tint: tint,
      icon: icon,
      label: label,
      onPressed: onPressed,
      child: child,
    );
  }
}

class GlassSwitch extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool>? onChange;
  final Color? tint;
  final String? label;

  const GlassSwitch({
    required this.checked,
    required this.onChange,
    this.tint,
    this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) => DropitSwitch(value: checked, onChanged: onChange, label: label);
}

class GlassNavItem {
  final String label;
  final IconData icon;

  const GlassNavItem({required this.label, required this.icon});
}

class GlassNav extends StatelessWidget {
  final List<GlassNavItem> items;
  final int activeIndex;
  final ValueChanged<int> onChange;
  final double? intensity;

  const GlassNav({
    required this.items,
    required this.activeIndex,
    required this.onChange,
    this.intensity,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassNavigation(
      items: [for (final item in items) AppGlassNavItem(label: item.label, icon: item.icon)],
      activeIndex: activeIndex,
      onChanged: onChange,
    );
  }
}

class GlassSegmentOption {
  final String label;
  final IconData? icon;

  const GlassSegmentOption({required this.label, this.icon});
}

class GlassSegmented extends StatelessWidget {
  final List<GlassSegmentOption> options;
  final int value;
  final ValueChanged<int> onChange;
  final GlassButtonSize size;
  final double? intensity;

  const GlassSegmented({
    required this.options,
    required this.value,
    required this.onChange,
    this.size = GlassButtonSize.md,
    this.intensity,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSegmented(
      options: [for (final option in options) AppGlassSegmentOption(label: option.label, icon: option.icon)],
      value: value,
      onChanged: onChange,
      size: switch (size) {
        GlassButtonSize.sm => AppGlassButtonSize.sm,
        GlassButtonSize.md => AppGlassButtonSize.md,
        GlassButtonSize.lg => AppGlassButtonSize.lg,
      },
    );
  }
}

class GlassSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChange;
  final bool showThumb;
  final IconData? icon;
  final String? label;
  final Color? tint;

  const GlassSlider({
    required this.value,
    required this.onChange,
    this.min = 0,
    this.max = 100,
    this.showThumb = true,
    this.icon,
    this.label,
    this.tint,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final progress = max > min ? ((value - min) / (max - min)).clamp(0.0, 1.0) : 0.0;
    final accent = tint ?? theme.colorScheme.primary;

    if (!showThumb) {
      void updateFromDx(double dx) {
        final box = context.findRenderObject();
        if (box is! RenderBox || !box.attached || !box.hasSize || box.size.width <= 0) return;
        final clamped = dx.clamp(0.0, box.size.width);
        onChange((min + (clamped / box.size.width) * (max - min)).roundToDouble());
      }

      if (usesAndroidMornye) {
        final scheme = theme.colorScheme;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => updateFromDx(details.localPosition.dx),
          onTapDown: (details) => updateFromDx(details.localPosition.dx),
          child: AppLiquidGlass(
            radius: 20,
            samplesBackdrop: false,
            child: SizedBox(
              height: 50,
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: progress,
                    heightFactor: 1.0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: scheme.primaryContainer),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon,
                            size: 19,
                            color: progress > 0.14 ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            label ?? '',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: progress > 0.25 ? scheme.onPrimaryContainer : scheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          '${value.round()}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => updateFromDx(details.localPosition.dx),
        onTapDown: (details) => updateFromDx(details.localPosition.dx),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AppGlassPress(
            radius: 20,
            child: AppLiquidGlass(
              radius: 20,
              refractionDepth: 0.24,
              dispersion: 1.4,
              smoothCorners: true,
              child: SizedBox(
                height: 50,
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: progress,
                      heightFactor: 1.0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: (dark ? Colors.white : accent).withValues(alpha: dark ? 0.88 : 0.26),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          if (icon != null) ...[
                            Icon(
                              icon,
                              size: 19,
                              color: (dark && progress > 0.14) ? const Color(0xFF0F172A) : theme.colorScheme.onSurface,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              label ?? '',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: (dark && progress > 0.25) ? const Color(0xFF0F172A) : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '${value.round()}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
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
        ),
      );
    }

    return DropitSlider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      activeColor: accent,
      onChanged: onChange,
    );
  }
}

typedef DropitGlassSearch = GlassInput;

class GlassInput extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String placeholder;
  final String type;

  const GlassInput({
    required this.controller,
    this.onChanged,
    this.onClear,
    this.placeholder = 'Search…',
    this.type = 'search',
    super.key,
  });

  @override
  State<GlassInput> createState() => _GlassInputState();
}

class _GlassInputState extends State<GlassInput> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted && _focusNode.hasFocus != _focused) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (usesAndroidMornye) {
      return AndroidMornyeSearchField(
        controller: widget.controller,
        focusNode: _focusNode,
        focused: _focused,
        placeholder: widget.placeholder,
        isSearch: widget.type == 'search',
        onChanged: widget.onChanged,
        onClear: widget.onClear,
      );
    }
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final isMacOS = theme.platform == TargetPlatform.macOS;
    final hintColor = dark ? (isMacOS ? Colors.white : Colors.white.withValues(alpha: 0.72)) : const Color(0xFF0F172A).withValues(alpha: 0.68);
    return AppLiquidGlass(
      radius: 999,
      preset: DropitOpticalPreset.searchField,
      refractionDepth: _focused ? 0.44 : 0.36,
      dispersion: _focused ? 3.2 : 2.5,
      highlightBorder: _focused,
      smoothCorners: true,
      nativeClear: true,
      nativeInteractive: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              Icon(
                widget.type == 'search' ? CupertinoIcons.search : CupertinoIcons.pencil,
                size: 16,
                color: _focused ? theme.colorScheme.primary : hintColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  focusNode: _focusNode,
                  controller: widget.controller,
                  onChanged: widget.onChanged,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.25,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    filled: false,
                    fillColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    contentPadding: EdgeInsets.zero,
                    hintText: widget.placeholder,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: hintColor,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(
                      CupertinoIcons.clear_circled_solid,
                      size: 17,
                      color: hintColor,
                    ),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged?.call('');
                      widget.onClear?.call();
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

Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? ariaLabel,
}) {
  return showAppGlassSheet<T>(
    context: context,
    builder: builder,
    ariaLabel: ariaLabel,
  );
}

Future<void> showMacosLiquidGlassControlCenter(BuildContext context) {
  return showGlassControlCenter(context);
}

/// Interactive cross-platform Liquid Glass Control Center persisted via [settingsProvider].
Future<void> showGlassControlCenter(BuildContext context) {
  return showAppGlassSheet<void>(
    context: context,
    ariaLabel: 'Liquid Glass Controls',
    builder: (ctx) {
      return Consumer(
        builder: (context, ref) {
          final settings = ref.watch(settingsProvider);
          final notifier = ref.notifier(settingsProvider);
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final scopeConfig = AppGlassConfigScope.of(context);

          return Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Liquid Glass Controls', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              scopeConfig.highContrast
                                  ? 'High contrast active — Flat rendering enforced'
                                  : 'Real-time optical refraction, dispersion & specular rims',
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      AppGlassButton(
                        variant: AppGlassButtonVariant.tinted,
                        size: AppGlassButtonSize.sm,
                        label: 'Reset',
                        onPressed: () async {
                          await notifier.setGlassQuality(AppGlassQuality.liquid);
                          await notifier.setGlassClarity(0.90);
                          await notifier.setGlassFrost(0.0);
                          await notifier.setRefractionIntensity(1.50);
                          await notifier.setGlassDispersion(1.32);
                          await notifier.setDeepEdgeTintColor(const Color(0xFF0A84FF));
                          await notifier.setDeepEdgeTintEnabled(false);
                          await notifier.setAllGlassTintEnabled(false);
                          await notifier.setGlassOutlines(true);
                          await notifier.setBackgroundAnimation(true);
                          await notifier.setEnableAnimations(true);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppGlassSegmented(
                    options: const [
                      AppGlassSegmentOption(label: 'Liquid'),
                      AppGlassSegmentOption(label: 'Frosted'),
                      AppGlassSegmentOption(label: 'Flat'),
                    ],
                    value: switch (settings.glassQuality) {
                      AppGlassQuality.liquid => 0,
                      AppGlassQuality.frosted => 1,
                      AppGlassQuality.flat => 2,
                    },
                    onChanged: (idx) => notifier.setGlassQuality(switch (idx) {
                      0 => AppGlassQuality.liquid,
                      1 => AppGlassQuality.frosted,
                      _ => AppGlassQuality.flat,
                    }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Text('Clarity', style: theme.textTheme.bodyMedium)),
                      Text('${(settings.glassClarity * 100).round()}%', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  DropitSlider(
                    value: settings.glassClarity,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label: '${(settings.glassClarity * 100).round()}%',
                    onChanged: notifier.setGlassClarity,
                  ),
                  if (settings.glassQuality == AppGlassQuality.liquid) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: Text('Liquid Frost', style: theme.textTheme.bodyMedium)),
                        Text(
                          '${(settings.glassFrost * 100).round()}%',
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    DropitSlider(
                      value: settings.glassFrost.clamp(0.0, 1.0),
                      min: 0,
                      max: 1,
                      divisions: 20,
                      label: '${(settings.glassFrost * 100).round()}%',
                      onChanged: notifier.setGlassFrost,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text('Refraction Intensity', style: theme.textTheme.bodyMedium)),
                      Text(
                        '${(settings.refractionIntensity * 100).round()}%',
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  DropitSlider(
                    value: settings.refractionIntensity.clamp(0.0, 2.0),
                    min: 0,
                    max: 2.0,
                    divisions: 20,
                    label: '${(settings.refractionIntensity * 100).round()}%',
                    onChanged: notifier.setRefractionIntensity,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text('Chromatic Dispersion', style: theme.textTheme.bodyMedium)),
                      Text(
                        '${settings.glassDispersion.toStringAsFixed(2)} px',
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  DropitSlider(
                    value: settings.glassDispersion.clamp(0.0, 10.0),
                    min: 0,
                    max: 10.0,
                    divisions: 100,
                    label: '${settings.glassDispersion.toStringAsFixed(2)} px',
                    onChanged: notifier.setGlassDispersion,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tint Deep Edge Glass', style: theme.textTheme.bodyMedium),
                            Text(
                              'Applies color to sidebars, drop zones, panels, sheets, and device cards',
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      DropitSwitch(value: settings.deepEdgeTintEnabled, onChanged: notifier.setDeepEdgeTintEnabled),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tint All Glass Cards', style: theme.textTheme.bodyMedium),
                            Text(
                              'Applies tint color to every glass card, button, toolbar & bar',
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      DropitSwitch(value: settings.allGlassTintEnabled, onChanged: notifier.setAllGlassTintEnabled),
                    ],
                  ),
                  if (settings.deepEdgeTintEnabled || settings.allGlassTintEnabled) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AppGlassButton(
                        variant: AppGlassButtonVariant.tinted,
                        tint: settings.deepEdgeTintColor,
                        size: AppGlassButtonSize.sm,
                        icon: CupertinoIcons.paintbrush,
                        label: '#${(settings.deepEdgeTintColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                        onPressed: () async {
                          final color = await showDialog<Color>(
                            context: context,
                            builder: (_) => CustomColorDialog(initialColor: settings.deepEdgeTintColor),
                          );
                          if (color != null) {
                            await notifier.setDeepEdgeTintColor(color);
                          }
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Glass Outlines', style: theme.textTheme.bodyMedium),
                            Text(
                              'Dynamic specular highlight and opposing glow rim',
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      DropitSwitch(value: settings.glassOutlines, onChanged: notifier.setGlassOutlines),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Background Motion', style: theme.textTheme.bodyMedium),
                            Text(
                              'Gentle atmospheric light drift behind optical lenses',
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      DropitSwitch(value: settings.backgroundAnimation, onChanged: notifier.setBackgroundAnimation),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Spring & UI Motion', style: theme.textTheme.bodyMedium),
                            Text(
                              'Physics-driven press response and smooth transitions',
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      DropitSwitch(value: settings.enableAnimations, onChanged: notifier.setEnableAnimations),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
