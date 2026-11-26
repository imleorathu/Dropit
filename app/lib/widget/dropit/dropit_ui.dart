import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/widget/mornye/android_glass_performance_host.dart';
import 'package:dropit_app/widget/mornye/app_atmospheric_backdrop.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_glass_cards.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_navigation.dart';
import 'package:dropit_app/widget/mornye/app_glass_panel.dart';
import 'package:dropit_app/widget/mornye/app_glass_press.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:dropit_app/widget/mornye/macos_native_glass.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Centralized material tokens for Dropit glass surfaces and micro-interactions.
abstract final class DropitGlassTokens {
  static const double chromeBlur = 20;
  static const double chromeOpacityLight = .24;
  static const double chromeOpacityDark = .28;
  static const double panelOpacityLight = .46;
  static const double panelOpacityDark = .42;
  static const Duration interactionDuration = Duration(milliseconds: 180);
  static const Curve interactionCurve = Cubic(.2, .8, .2, 1);
}

/// Root atmospheric canvas and optical `LiquidGlassView` pipeline host.
class DropitBackdrop extends StatelessWidget {
  final Widget child;

  const DropitBackdrop({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    if (usesAndroidMornye) {
      return AndroidGlassPerformanceHost(
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: BackdropGroup(child: LiquidGlassBatch(child: child)),
        ),
      );
    }
    if (MacosNativeGlass.isSupported) {
      final config = AppGlassConfigScope.of(context);
      if (config.effectiveQuality == AppGlassQuality.flat) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: child,
        );
      }
      // macOS owns the background: clear Flutter pixels reveal the actual
      // desktop and windows underneath. In Light mode, add a subtle atmospheric
      // veil so dark desktop windows underneath cannot wash out dark typography
      // inside translucent .regular glass, tapering cleanly to transparent at
      // 100% clarity in clear Liquid mode.
      if (Theme.of(context).brightness == Brightness.light) {
        final crystalScale = config.effectiveQuality == AppGlassQuality.liquid && config.glassFrost < 0.25
            ? DropitGlassQualityController.crystalClarityScale(config.clarity)
            : 1.0;
        if (crystalScale <= 0.0) {
          return child;
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: crystalScale >= 1.0 ? const Color(0x3AF4F7FF) : const Color(0x3AF4F7FF).withValues(alpha: (0x3A / 255.0) * crystalScale),
          ),
          child: child,
        );
      }
      return child;
    }
    return AppAtmosphericBackdrop(child: child);
  }
}

/// Renders the Dropit application mark.
class DropitMark extends StatelessWidget {
  final double size;
  final bool tile;
  const DropitMark({this.size = 48, this.tile = true, super.key});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(tile ? size * .26 : 0);
    return Semantics(
      label: 'Dropit',
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: (tile && !usesAndroidMornye)
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .28 : .14),
                    blurRadius: size * .24,
                    offset: Offset(0, size * .06),
                  ),
                ]
              : const [],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Image.asset(
            'assets/img/logo-512.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

/// Reusable Liquid Glass surface. Floating chrome receives a single backdrop
/// blur; dense cards use a translucent material without another expensive blur.
class DropitSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final bool selected;
  final bool chrome;
  final bool tonal;
  final Color? color;
  final Color? borderColor;
  final double? width;
  final double? height;
  final DropitOpticalPreset? preset;

  const DropitSurface({
    required this.child,
    this.radius = 28,
    this.padding,
    this.selected = false,
    this.chrome = false,
    this.tonal = false,
    this.color,
    this.borderColor,
    this.width,
    this.height,
    this.preset,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = padding != null ? Padding(padding: padding!, child: child) : child;
    if (width != null || height != null) {
      content = SizedBox(width: width, height: height, child: content);
    }

    final scheme = Theme.of(context).colorScheme;
    return AppLiquidGlass(
      radius: radius,
      preset: preset ?? (chrome ? DropitOpticalPreset.toolbar : DropitOpticalPreset.panel),
      strongTint: chrome || selected,
      tintColor: selected ? scheme.primary : color,
      samplesBackdrop: !usesAndroidMornye || chrome || preset == DropitOpticalPreset.modalSheet,
      highlightBorder: selected,
      refractionDepth: chrome ? 0.42 : 0.34,
      smoothCorners: radius >= 14,
      child: content,
    );
  }
}

/// Solid square rounded icon tile used in cards and list items.
class DropitTile extends StatelessWidget {
  final Widget child;
  final double size;
  final double radius;
  final bool selected;
  final Color? color;

  const DropitTile({
    required this.child,
    this.size = 56,
    this.radius = 18,
    this.selected = false,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (usesAndroidMornye) {
      final scheme = Theme.of(context).colorScheme;
      final bg = color ?? (selected ? scheme.primaryContainer : scheme.secondaryContainer);
      return SizedBox(
        width: size,
        height: size,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius >= 16 ? 16 : radius)),
          clipBehavior: Clip.antiAlias,
          child: Center(child: child),
        ),
      );
    }
    return DropitSurface(
      width: size,
      height: size,
      radius: radius,
      tonal: color == null && !selected,
      selected: selected,
      color: color,
      child: Center(child: child),
    );
  }
}

/// Spring-physics optical pointer illumination and tactile response.
class DropitPress extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final double pressedScale;

  const DropitPress({required this.child, this.enabled = true, this.pressedScale = 0.98, super.key});

  @override
  Widget build(BuildContext context) {
    final config = AppGlassConfigScope.of(context);
    if (!enabled || !config.animateMotion) {
      return child;
    }
    return AppGlassPress(
      radius: 24,
      enabled: true,
      child: child,
    );
  }
}

/// Optical stadium pill button for picker actions (File, Media, Paste, Text, Folder, App).
class DropitPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  const DropitPillButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassButton(
      variant: selected ? AppGlassButtonVariant.tinted : AppGlassButtonVariant.glass,
      size: AppGlassButtonSize.md,
      icon: icon,
      label: label,
      onPressed: onPressed,
    );
  }
}

class DropitPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const DropitPanel({required this.child, this.padding = const EdgeInsets.all(22), this.radius = 24, super.key});

  @override
  Widget build(BuildContext context) {
    return AppGlassPanel(
      radius: radius,
      padding: padding,
      child: child,
    );
  }
}

/// Translucent Liquid Glass app bar for secondary routes.
class DropitAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  const DropitAppBar({required this.title, this.actions, super.key});

  @override
  Size get preferredSize => Size.fromHeight(usesAndroidMornye ? kToolbarHeight : kToolbarHeight + 16);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

    if (usesAndroidMornye) {
      return AppLiquidGlass(
        radius: 0,
        preset: DropitOpticalPreset.toolbar,
        child: AppBar(
          automaticallyImplyLeading: false,
          leading: canPop ? Center(child: AndroidMornyeTheme.backButton(context)) : null,
          title: title,
          actions: actions == null || actions!.isEmpty ? null : [...actions!, const SizedBox(width: 8)],
        ),
      );
    }

    final isMacNative = !kIsWeb && theme.platform == TargetPlatform.macOS;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isMacNative ? 76 : 14, 10, 14, 6),
        child: SizedBox(
          height: kToolbarHeight,
          child: AppLiquidGlass(
            radius: 26,
            strongTint: true,
            refractionDepth: 0.22,
            dispersion: 0.9,
            smoothCorners: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  if (canPop) ...[
                    Semantics(
                      label: MaterialLocalizations.of(context).backButtonTooltip,
                      button: true,
                      child: AppGlassButton(
                        variant: AppGlassButtonVariant.glass,
                        size: AppGlassButtonSize.sm,
                        icon: Icons.chevron_left_rounded,
                        onPressed: () => Navigator.maybePop(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else
                    const SizedBox(width: 8),
                  Expanded(
                    child: DefaultTextStyle.merge(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      child: title,
                    ),
                  ),
                  if (actions != null && actions!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DropitHeading extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? description;
  const DropitHeading({this.eyebrow, required this.title, this.description, super.key});

  /// Localized text shadow halo so floating headers stay crisp over arbitrary
  /// desktop wallpapers without painting a block container behind them.
  static List<Shadow>? floatingShadows(BuildContext context) {
    if (usesAndroidMornye || !MacosNativeGlass.isSupported) return null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      Shadow(
        color: dark ? const Color(0xDC000000) : const Color(0xF2FFFFFF),
        blurRadius: 10,
        offset: const Offset(0, 1),
      ),
      Shadow(
        color: dark ? const Color(0x90000000) : const Color(0xBAFFFFFF),
        blurRadius: 22,
        offset: const Offset(0, 2),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 380 ? 24.0 : (width < 600 ? 28.0 : 34.0);
    final descSize = width < 380 ? 13.0 : 14.5;
    final shadows = floatingShadows(context);

    final hasEyebrow = eyebrow != null && eyebrow!.trim().isNotEmpty;
    final hasDesc = description != null && description!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasEyebrow) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: TextStyle(
              fontSize: width < 380 ? 10.0 : 11.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: theme.colorScheme.primary,
              shadows: shadows,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          title,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            letterSpacing: width < 380 ? -0.6 : -0.9,
            height: 1.15,
            color: theme.colorScheme.onSurface,
            shadows: shadows,
          ),
        ),
        if (hasDesc) ...[
          const SizedBox(height: 6),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: descSize,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
              shadows: shadows,
            ),
          ),
        ],
      ],
    );
  }
}

class DropitStatus extends StatelessWidget {
  final bool online;
  const DropitStatus({required this.online, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final onlineColor = dark ? const Color(0xFF34D058) : const Color(0xFF0A662A);
    final color = online ? onlineColor : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7.5,
          height: 7.5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            online ? 'Ready to receive' : 'Receiver offline',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Reusable Dropit Glass system aliases backed by the shared optical +
/// AppKit native material engine.
typedef DropitLiquidGlass = AppLiquidGlass;
typedef DropitGlassBackdrop = DropitBackdrop;
typedef DropitGlassPress = AppGlassPress;
typedef DropitGlassPanel = AppGlassPanel;
typedef DropitGlassButton = AppGlassButton;
typedef DropitGlassSegmentedControl = AppGlassSegmented;
typedef DropitGlassDeviceCard = AppGlassDeviceCard;
typedef DropitGlassDropZone = AppGlassDropZone;
