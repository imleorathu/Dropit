import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_press.dart';
import 'package:dropit_app/widget/mornye/app_glass_progress.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Refractive Liquid Glass file drop zone with optical edge glow and drag-over
/// highlight response.
class AppGlassDropZone extends StatefulWidget {
  const AppGlassDropZone({
    required this.child,
    this.highlighted = false,
    this.onTap,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });

  final Widget child;
  final bool highlighted;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  State<AppGlassDropZone> createState() => _AppGlassDropZoneState();
}

class _AppGlassDropZoneState extends State<AppGlassDropZone> with WidgetsBindingObserver {
  bool _hovered = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.onTap == null || !(ModalRoute.of(context)?.isCurrent ?? true)) {
      _hovered = false;
    }
  }

  @override
  void didUpdateWidget(AppGlassDropZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null && _hovered) {
      _hovered = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _hovered && mounted) {
      setState(() => _hovered = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final interactive = widget.onTap != null;
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final active = widget.highlighted || (interactive && routeCurrent && _hovered);
    final config = AppGlassConfigScope.of(context);

    return Semantics(
      button: interactive,
      enabled: interactive,
      child: FocusableActionDetector(
        enabled: interactive,
        onShowFocusHighlight: (focused) {
          if (_focused != focused) setState(() => _focused = focused);
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(usesAndroidMornye ? 20 : 32),
            border: _focused && interactive ? Border.all(color: scheme.primary, width: 2) : null,
          ),
          child: MouseRegion(
            cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
            onEnter: (_) {
              if (interactive && (ModalRoute.of(context)?.isCurrent ?? true)) {
                setState(() => _hovered = true);
              }
            },
            onExit: (_) {
              if (_hovered) setState(() => _hovered = false);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onTap,
              child: AppGlassPress(
                radius: usesAndroidMornye ? 20 : 38,
                enabled: interactive && config.animateMotion,
                child: AppLiquidGlass(
                  radius: usesAndroidMornye ? 20 : 38,
                  preset: DropitOpticalPreset.dropZone,
                  samplesBackdrop: !usesAndroidMornye,
                  strongTint: active,
                  tintColor: active ? const Color(0xFF086D92) : null,
                  highlightBorder: active,
                  refractionDepth: active ? 0.56 : 0.48,
                  dispersion: active ? 4.4 : 3.4,
                  smoothCorners: true,
                  nativeClear: true,
                  nativeInteractive: widget.onTap != null,
                  child: Padding(
                    padding: widget.padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        widget.child,
                        if (active) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Drop ready',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Interactive Liquid Glass device / browser card with optical depth, status
/// indicator, and optional live transfer progress.
class AppGlassDeviceCard extends StatelessWidget {
  const AppGlassDeviceCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.badge,
    this.statusColor,
    this.favorite = false,
    this.progress,
    this.trailing,
    this.onTap,
    super.key,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? statusColor;
  final bool favorite;
  final double? progress;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final cardContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              leading,
              if (statusColor != null)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.surface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (favorite) ...[
                      const SizedBox(width: 6),
                      Icon(
                        usesAndroidMornye ? Symbols.star_rounded : CupertinoIcons.star_fill,
                        fill: usesAndroidMornye ? 1 : null,
                        size: 15,
                        color: scheme.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: usesAndroidMornye ? scheme.secondaryContainer : (statusColor ?? scheme.primary).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: usesAndroidMornye && statusColor == null ? scheme.onSecondaryContainer : (statusColor ?? scheme.primary),
                      ),
                    ),
                  ),
                ],
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  AppGlassProgress(progress: progress!.clamp(0, 1), height: 8),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );

    if (usesAndroidMornye) {
      return AppGlassPress(
        radius: 20,
        enabled: onTap != null,
        child: AppLiquidGlass(
          radius: 20,
          preset: DropitOpticalPreset.deviceCard,
          samplesBackdrop: false,
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: onTap, child: cardContent),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: AppGlassPress(
        radius: 30,
        enabled: onTap != null,
        child: AppLiquidGlass(
          radius: 30,
          preset: DropitOpticalPreset.deviceCard,
          smoothCorners: true,
          refractionDepth: 0.44,
          dispersion: 3.0,
          nativeClear: true,
          nativeInteractive: onTap != null,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: cardContent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass file item card for staged selections, transfers, and history.
class AppGlassFileCard extends StatelessWidget {
  const AppGlassFileCard({
    required this.thumbnail,
    required this.title,
    required this.subtitle,
    this.progress,
    this.trailing,
    this.onTap,
    super.key,
  });

  final Widget thumbnail;
  final String title;
  final String subtitle;
  final double? progress;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          thumbnail,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  AppGlassProgress(progress: progress, height: 7),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );

    if (usesAndroidMornye) {
      return AppGlassPress(
        radius: 20,
        enabled: onTap != null,
        child: AppLiquidGlass(
          radius: 20,
          preset: DropitOpticalPreset.deviceCard,
          samplesBackdrop: false,
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: onTap, child: content),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: AppGlassPress(
        radius: 26,
        enabled: onTap != null,
        child: AppLiquidGlass(
          radius: 26,
          preset: DropitOpticalPreset.deviceCard,
          refractionDepth: 0.34,
          dispersion: 2.2,
          smoothCorners: true,
          nativeClear: true,
          nativeInteractive: onTap != null,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
