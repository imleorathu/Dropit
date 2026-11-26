import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:dropit_app/config/init.dart';
import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/model/chat_message.dart';
import 'package:dropit_app/pages/home_page_controller.dart';
import 'package:dropit_app/pages/tabs/chat_tab.dart';
import 'package:dropit_app/pages/tabs/receive_tab.dart';
import 'package:dropit_app/pages/tabs/send_tab.dart';
import 'package:dropit_app/pages/tabs/settings_tab.dart';
import 'package:dropit_app/pages/web_share_page.dart';
import 'package:dropit_app/provider/chat_provider.dart';
import 'package:dropit_app/provider/device_info_provider.dart';
import 'package:dropit_app/provider/network/server/server_provider.dart';
import 'package:dropit_app/provider/selection/selected_sending_files_provider.dart';
import 'package:dropit_app/provider/settings_provider.dart';
import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/theme/mornye_theme.dart';
import 'package:dropit_app/util/native/cross_file_converters.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/dropit/macos_liquid_glass.dart';
import 'package:dropit_app/widget/dropit_connection_help.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_navigation.dart';
import 'package:dropit_app/widget/mornye/app_glass_panel.dart';
import 'package:dropit_app/widget/mornye/app_glass_press.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/dropit_optical_glass.dart';
import 'package:dropit_app/widget/mornye/liquid_glass_motion.dart';
import 'package:dropit_app/widget/mornye/macos_native_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

enum HomeTab {
  receive(Icons.wifi),
  send(Icons.send),
  chat(Icons.forum),
  settings(Icons.settings)
  ;

  const HomeTab(this.icon);

  final IconData icon;

  String get label {
    switch (this) {
      case HomeTab.receive:
        return t.receiveTab.title;
      case HomeTab.send:
        return t.sendTab.title;
      case HomeTab.chat:
        return 'Chat';
      case HomeTab.settings:
        return t.settingsTab.title;
    }
  }
}

class HomePage extends StatefulWidget {
  final HomeTab initialTab;

  /// It is important for the initializing step
  /// because the first init clears the cache
  final bool appStart;

  const HomePage({
    required this.initialTab,
    required this.appStart,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with Refena {
  bool _dragAndDropIndicator = false;

  @override
  void initState() {
    super.initState();

    ensureRef((ref) async {
      ref.redux(homePageControllerProvider).dispatch(ChangeTabAction(widget.initialTab));
      await postInit(context, ref, widget.appStart);
    });
  }

  @override
  Widget build(BuildContext context) {
    Translations.of(context); // rebuild on locale change
    final vm = context.watch(homePageControllerProvider);

    return DropTarget(
      onDragEntered: (_) {
        setState(() {
          _dragAndDropIndicator = true;
        });
      },
      onDragExited: (_) {
        setState(() {
          _dragAndDropIndicator = false;
        });
      },
      onDragDone: (event) async {
        // the drop may contain a mix of files and directories
        final droppedDirectories = event.files.where((file) => Directory(file.path).existsSync()).toList();
        final droppedFiles = event.files.where((file) => !Directory(file.path).existsSync()).toList();

        for (final directory in droppedDirectories) {
          await ref.redux(selectedSendingFilesProvider).dispatchAsync(AddDirectoryAction(directory.path));
        }

        if (droppedFiles.isNotEmpty) {
          await ref
              .redux(selectedSendingFilesProvider)
              .dispatchAsync(
                AddFilesAction(
                  files: droppedFiles,
                  converter: CrossFileConverters.convertXFile,
                ),
              );
        }
        vm.changeTab(HomeTab.send);
      },
      child: DropitShell(
        vm: vm,
        alias: context.watch(settingsProvider.select((s) => s.alias)),
        online: context.watch(serverProvider) != null,
        dragActive: _dragAndDropIndicator,
        child: PageView(
          controller: vm.controller,
          physics: const NeverScrollableScrollPhysics(),
          children: const [ReceiveTab(), SendTab(), ChatTab(), SettingsTab()],
        ),
      ),
    );
  }
}

/// Adaptive Dropit shell layout; networking and initialization stay in HomePage.
class DropitShell extends StatelessWidget {
  final HomePageVm vm;
  final String alias;
  final bool online;
  final bool dragActive;
  final Widget child;
  const DropitShell({required this.vm, required this.alias, required this.online, required this.child, this.dragActive = false, super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 760;
      final isMacNative = defaultTargetPlatform == TargetPlatform.macOS;
      final theme = Theme.of(context);
      final textScale = MediaQuery.textScalerOf(context).scale(14);
      final tallSidebar = constraints.maxHeight >= 700 && textScale <= 18;

      final bodyContent = Row(
        children: [
          if (desktop)
            Container(
              width: 224,
              padding: EdgeInsets.fromLTRB(12, isMacNative ? 36 : 12, 4, 12),
              child: DropitGlassSidebar(
                alias: alias,
                online: online,
                tallSidebar: tallSidebar,
                vm: vm,
              ),
            ),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    desktop ? 28 : (constraints.maxWidth < 380 ? 14 : 22),
                    desktop ? 14 : 12,
                    desktop ? 28 : (constraints.maxWidth < 380 ? 14 : 22),
                    6,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Row(
                        children: [
                          if (!desktop) ...[
                            const DropitMark(size: 32),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Dropit',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: usesAndroidMornye
                                    ? theme.textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w700)
                                    : const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.7),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!usesAndroidMornye)
                              Semantics(
                                label: 'Liquid Glass controls',
                                button: true,
                                child: AppGlassButton(
                                  variant: AppGlassButtonVariant.glass,
                                  size: AppGlassButtonSize.sm,
                                  icon: CupertinoIcons.sparkles,
                                  onPressed: () => showGlassControlCenter(context),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Semantics(
                              label: 'Connection help',
                              button: true,
                              child: AppGlassButton(
                                variant: AppGlassButtonVariant.glass,
                                size: AppGlassButtonSize.sm,
                                icon: usesAndroidMornye ? Symbols.help_rounded : CupertinoIcons.question,
                                onPressed: () => showDropitConnectionHelp(context),
                              ),
                            ),
                          ] else
                            Expanded(
                              child: DropitGlassToolbar(vm: vm, online: online),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      child,
                      if (dragActive)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: usesAndroidMornye
                                ? Material(
                                    color: theme.colorScheme.surfaceContainerHigh,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      side: BorderSide(color: theme.colorScheme.primary, width: 2),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Symbols.move_to_inbox_rounded, size: 64, color: theme.colorScheme.primary),
                                          const SizedBox(height: 20),
                                          Text(t.sendTab.placeItems, style: theme.textTheme.titleLarge),
                                        ],
                                      ),
                                    ),
                                  )
                                : LiquidGlassBatch.exclude(
                                    child: AppLiquidGlass(
                                      radius: 38,
                                      nativeModalOverlay: true,
                                      strongTint: true,
                                      tintColor: const Color(0xFF086D92),
                                      highlightBorder: true,
                                      refractionDepth: 0.52,
                                      dispersion: 4.2,
                                      smoothCorners: true,
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(CupertinoIcons.tray_arrow_down, size: 64, color: theme.colorScheme.primary),
                                            const SizedBox(height: 20),
                                            Text(t.sendTab.placeItems, style: theme.textTheme.titleLarge),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );

      const navTabs = [HomeTab.send, HomeTab.receive, HomeTab.chat, HomeTab.settings];

      return Scaffold(
        // Reserve layout space for mobile navigation. The capsule remains
        // visually floating inside its padded SafeArea, but scrollable content
        // can no longer disappear underneath it.
        extendBody: false,
        body: SafeArea(
          top: !(desktop && isMacNative),
          bottom: false,
          child: desktop
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: bodyContent,
                )
              : bodyContent,
        ),
        bottomNavigationBar: desktop
            ? null
            : usesAndroidMornye
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: AppGlassNavigation(
                    items: [
                      AppGlassNavItem(
                        label: HomeTab.send.label,
                        icon: Symbols.send_rounded,
                      ),
                      AppGlassNavItem(
                        label: HomeTab.receive.label,
                        icon: Symbols.move_to_inbox_rounded,
                      ),
                      AppGlassNavItem(
                        label: HomeTab.chat.label,
                        icon: Symbols.chat_rounded,
                      ),
                      AppGlassNavItem(
                        label: HomeTab.settings.label,
                        icon: Symbols.tune_rounded,
                      ),
                      const AppGlassNavItem(
                        label: 'Browser sharing',
                        icon: Symbols.language_rounded,
                      ),
                    ],
                    activeIndex: navTabs.indexOf(vm.currentTab).clamp(0, 3),
                    onChanged: (idx) async {
                      if (idx == navTabs.length) {
                        await context.push(() => const WebSharePage());
                      } else {
                        vm.changeTab(navTabs[idx]);
                      }
                    },
                  ),
                ),
              )
            : SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth < 380 ? 10 : 18,
                    4,
                    constraints.maxWidth < 380 ? 10 : 18,
                    8,
                  ),
                  child: AppGlassNavigation(
                    items: [
                      AppGlassNavItem(
                        label: HomeTab.send.label,
                        icon: CupertinoIcons.paperplane,
                        activeIcon: CupertinoIcons.paperplane_fill,
                      ),
                      AppGlassNavItem(
                        label: HomeTab.receive.label,
                        icon: CupertinoIcons.tray_arrow_down,
                        activeIcon: CupertinoIcons.tray_arrow_down_fill,
                      ),
                      AppGlassNavItem(
                        label: HomeTab.chat.label,
                        icon: CupertinoIcons.chat_bubble,
                        activeIcon: CupertinoIcons.chat_bubble_fill,
                      ),
                      AppGlassNavItem(
                        label: HomeTab.settings.label,
                        icon: CupertinoIcons.slider_horizontal_3,
                      ),
                      const AppGlassNavItem(
                        label: 'Browser sharing',
                        icon: CupertinoIcons.globe,
                      ),
                    ],
                    activeIndex: navTabs.indexOf(vm.currentTab).clamp(0, 3),
                    onChanged: (idx) async {
                      if (idx == navTabs.length) {
                        await context.push(() => const WebSharePage());
                      } else {
                        vm.changeTab(navTabs[idx]);
                      }
                    },
                  ),
                ),
              ),
      );
    },
  );
}

/// Floating translucent desktop glass sidebar backed by AppKit material.
class DropitGlassSidebar extends StatelessWidget {
  final String alias;
  final bool online;
  final bool tallSidebar;
  final HomePageVm vm;

  const DropitGlassSidebar({
    required this.alias,
    required this.online,
    required this.tallSidebar,
    required this.vm,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glassConfig = AppGlassConfigScope.of(context);
    final clearSidebar = glassConfig.effectiveQuality == AppGlassQuality.liquid && glassConfig.glassFrost < 0.25 && glassConfig.clarity >= 0.98;
    return RepaintBoundary(
      child: MacosNativeGlassSurface(
        id: 'main-sidebar',
        material: MacosNativeGlassMaterial.sidebar,
        radius: 32,
        clear: clearSidebar,
        child: DropitSurface(
          chrome: true,
          preset: DropitOpticalPreset.sidebar,
          radius: 32,
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: 6, bottom: tallSidebar ? 24 : 14),
                child: Row(
                  children: [
                    const DropitMark(size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Dropit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _DropitNavigation(vm: vm),
              const Spacer(),
              if (tallSidebar) ...[
                DropitSurface(
                  radius: 20,
                  tonal: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: MornyeTheme.controlFill(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          usesAndroidMornye ? Symbols.devices_rounded : CupertinoIcons.device_laptop,
                          size: 17,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              alias,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            DropitStatus(online: online),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: AppGlassButton(
                  variant: AppGlassButtonVariant.clear,
                  size: AppGlassButtonSize.sm,
                  icon: usesAndroidMornye ? Symbols.help_rounded : CupertinoIcons.question_circle,
                  label: 'Connection help',
                  onPressed: () => showDropitConnectionHelp(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top desktop toolbar rendered inside a floating Liquid Glass capsule bar.
class DropitGlassToolbar extends StatelessWidget {
  final HomePageVm vm;
  final bool online;
  const DropitGlassToolbar({required this.vm, required this.online, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glassConfig = AppGlassConfigScope.of(context);
    return RepaintBoundary(
      child: MacosNativeGlassSurface(
        id: 'main-toolbar',
        material: MacosNativeGlassMaterial.hud,
        radius: 28,
        clear: glassConfig.effectiveQuality == AppGlassQuality.liquid && glassConfig.glassFrost < 0.25 && glassConfig.clarity >= 0.45,
        interactive: true,
        child: AppGlassPanel(
          chrome: false,
          preset: DropitOpticalPreset.toolbar,
          radius: 28,
          refractionDepth: 0.48,
          dispersion: 3.5,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                switch (vm.currentTab) {
                  HomeTab.send => usesAndroidMornye ? Symbols.send_rounded : CupertinoIcons.paperplane_fill,
                  HomeTab.receive => usesAndroidMornye ? Symbols.move_to_inbox_rounded : CupertinoIcons.tray_arrow_down_fill,
                  HomeTab.chat => usesAndroidMornye ? Symbols.chat_rounded : CupertinoIcons.chat_bubble_fill,
                  HomeTab.settings => usesAndroidMornye ? Symbols.tune_rounded : CupertinoIcons.slider_horizontal_3,
                },
                size: 18,
                fill: usesAndroidMornye ? 1 : null,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                vm.currentTab.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.35,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (usesAndroidMornye)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: theme.colorScheme.secondaryContainer,
                      shape: const StadiumBorder(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: DropitStatus(online: online),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      label: 'Connection help',
                      button: true,
                      child: AppGlassButton(
                        variant: AppGlassButtonVariant.glass,
                        size: AppGlassButtonSize.sm,
                        icon: Symbols.help_rounded,
                        onPressed: () => showDropitConnectionHelp(context),
                      ),
                    ),
                  ],
                )
              else
                LiquidGlassContainer(
                  spacing: 14.0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LiquidGlassMember(
                        id: 'toolbar-status',
                        groupId: 'toolbar-utility',
                        radius: 999,
                        child: AppLiquidGlass(
                          radius: 999,
                          blurEnabled: false,
                          refractionDepth: 0.14,
                          dispersion: 0.0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: DropitStatus(online: online),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      LiquidGlassMember(
                        id: 'toolbar-glass',
                        groupId: 'toolbar-utility',
                        radius: 999,
                        child: AppGlassButton(
                          variant: AppGlassButtonVariant.glass,
                          size: AppGlassButtonSize.sm,
                          icon: CupertinoIcons.sparkles,
                          label: 'Glass',
                          onPressed: () => showGlassControlCenter(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      LiquidGlassMember(
                        id: 'toolbar-help',
                        groupId: 'toolbar-utility',
                        radius: 999,
                        child: Semantics(
                          label: 'Connection help',
                          button: true,
                          child: AppGlassButton(
                            variant: AppGlassButtonVariant.glass,
                            size: AppGlassButtonSize.sm,
                            icon: CupertinoIcons.question,
                            onPressed: () => showDropitConnectionHelp(context),
                          ),
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
}

class _DropitNavigation extends StatefulWidget {
  final HomePageVm vm;
  const _DropitNavigation({required this.vm});

  @override
  State<_DropitNavigation> createState() => _DropitNavigationState();
}

class _DropitNavigationState extends State<_DropitNavigation> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const List<HomeTab> _orderedTabs = <HomeTab>[
    HomeTab.send,
    HomeTab.receive,
    HomeTab.chat,
    HomeTab.settings,
  ];

  final GlobalKey _stackKey = GlobalKey();
  final Map<HomeTab, GlobalKey> _itemKeys = <HomeTab, GlobalKey>{
    for (final tab in _orderedTabs) tab: GlobalKey(),
  };
  final List<Rect?> _measuredRects = List<Rect?>.filled(_orderedTabs.length, null);

  late final LiquidGlassMotionController _glide = LiquidGlassMotionController(
    vsync: this,
    spring: kDropitSelectionGlideSpring,
    initialValue: _indexForTab(widget.vm.currentTab).toDouble(),
  );

  bool _appResumed = true;
  bool _measureScheduled = false;

  static int _indexForTab(HomeTab tab) {
    final idx = _orderedTabs.indexOf(tab);
    return idx < 0 ? 0 : idx;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMeasure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTarget(snapIfDisabled: true);
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(_DropitNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vm.currentTab != widget.vm.currentTab) {
      _syncTarget();
    }
    _scheduleMeasure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (!_appResumed && _glide.isAnimating) {
      _glide.snapTo(_indexForTab(widget.vm.currentTab).toDouble());
    }
  }

  void _syncTarget({bool snapIfDisabled = false}) {
    final target = _indexForTab(widget.vm.currentTab).toDouble();
    final config = AppGlassConfigScope.of(context);
    final animate = _appResumed && config.animateMotion && !MediaQuery.disableAnimationsOf(context);
    if (animate) {
      _glide.animateTo(target, animate: true);
    } else if (snapIfDisabled || _glide.value != target) {
      _glide.snapTo(target);
    }
  }

  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      _measureSlots();
    });
  }

  void _measureSlots() {
    final stackBox = _stackKey.currentContext?.findRenderObject();
    if (stackBox is! RenderBox || !stackBox.attached || !stackBox.hasSize) return;
    var changed = false;
    for (var i = 0; i < _orderedTabs.length; i++) {
      final ro = _itemKeys[_orderedTabs[i]]?.currentContext?.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      final topLeft = ro.localToGlobal(Offset.zero, ancestor: stackBox);
      final rect = topLeft & ro.size;
      if (_measuredRects[i] != rect) {
        _measuredRects[i] = rect;
        changed = true;
      }
    }
    if (changed && mounted) {
      setState(() {});
    }
  }

  Rect _fallbackRectForIndex(int index, double width) {
    final top = switch (index) {
      0 => 28.0,
      1 => 74.0,
      _ => 136.0,
    };
    return Rect.fromLTWH(0, top, width, 40);
  }

  Rect _interpolatedSelectionRect(double p, double maxWidth) {
    final clamped = p.clamp(0.0, (_orderedTabs.length - 1).toDouble());
    final low = clamped.floor();
    final high = clamped.ceil();
    final a = _measuredRects[low] ?? _fallbackRectForIndex(low, maxWidth);
    if (low == high) return a;
    final b = _measuredRects[high] ?? _fallbackRectForIndex(high, maxWidth);
    final localT = (clamped - low).clamp(0.0, 1.0);
    final stretch = (_glide.velocity.abs() * 1.4).clamp(0.0, 9.0);
    return GlassGeometryInterpolator.lerpRect(a, b, localT, stretchStrength: stretch);
  }

  int _unreadChatCount(BuildContext context) {
    try {
      final myId = context.watch(deviceFullInfoProvider).fingerprint;
      return context
          .watch(chatProvider)
          .where((m) => m.senderId != myId && m.status != ChatDeliveryStatus.read)
          .length;
    } catch (_) {
      return 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _glide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    // Built once and positioned by the persistent spring controller so tab
    // switches morph/glide continuously without recreating the glass capsule.
    final persistentCapsule = IgnorePointer(
      child: usesAndroidMornye
          ? AppLiquidGlass(
              radius: 18,
              samplesBackdrop: false,
              highlightBorder: true,
              tintColor: theme.colorScheme.primary,
              tintOpacity: dark ? 0.22 : 0.16,
              child: const SizedBox.expand(),
            )
          : AppLiquidGlass(
              radius: 18,
              strongTint: true,
              tintColor: theme.colorScheme.primary,
              tintOpacity: dark ? 0.22 : 0.16,
              highlightBorder: true,
              refractionDepth: 0.30,
              dispersion: 1.8,
              smoothCorners: true,
              child: const SizedBox.expand(),
            ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = constraints.hasBoundedWidth && constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
        return Stack(
          key: _stackKey,
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: _glide.controller,
              child: persistentCapsule,
              builder: (context, child) {
                final rect = _interpolatedSelectionRect(_glide.value, fallbackWidth);
                return Positioned(
                  left: rect.left,
                  top: rect.top,
                  width: rect.width,
                  height: rect.height,
                  child: child!,
                );
              },
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 4, bottom: 8),
                  child: Text(
                    'TRANSFER',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                _DropitNav(
                  key: _itemKeys[HomeTab.send],
                  tab: HomeTab.send,
                  selected: widget.vm.currentTab == HomeTab.send,
                  onTap: () => widget.vm.changeTab(HomeTab.send),
                ),
                const SizedBox(height: 6),
                _DropitNav(
                  key: _itemKeys[HomeTab.receive],
                  tab: HomeTab.receive,
                  selected: widget.vm.currentTab == HomeTab.receive,
                  onTap: () => widget.vm.changeTab(HomeTab.receive),
                ),
                const SizedBox(height: 6),
                _DropitActionNav(
                  label: 'Browser sharing',
                  icon: usesAndroidMornye ? Symbols.language_rounded : CupertinoIcons.globe,
                  onTap: () async => context.push(() => const WebSharePage()),
                ),
                const SizedBox(height: 6),
                _DropitNav(
                  key: _itemKeys[HomeTab.chat],
                  tab: HomeTab.chat,
                  selected: widget.vm.currentTab == HomeTab.chat,
                  badgeCount: _unreadChatCount(context),
                  onTap: () => widget.vm.changeTab(HomeTab.chat),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 8),
                  child: Text(
                    'PREFERENCES',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                _DropitNav(
                  key: _itemKeys[HomeTab.settings],
                  tab: HomeTab.settings,
                  selected: widget.vm.currentTab == HomeTab.settings,
                  onTap: () => widget.vm.changeTab(HomeTab.settings),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DropitActionNav extends StatelessWidget {
  const _DropitActionNav({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AppGlassPress(
            radius: 18,
            child: _NavRowHoverTint(
              selected: false,
              hoverTint: theme.colorScheme.onSurface,
              dark: dark,
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
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

class _DropitNav extends StatelessWidget {
  final HomeTab tab;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;
  const _DropitNav({required this.tab, required this.selected, this.badgeCount = 0, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accentIcon = dark ? Color.lerp(theme.colorScheme.primary, Colors.white, 0.38)! : theme.colorScheme.primary;
    final fgColor = selected ? (dark ? Colors.white : theme.colorScheme.primary) : theme.colorScheme.onSurface;
    final iconColor = selected ? accentIcon : theme.colorScheme.onSurfaceVariant;
    final icon = switch (tab) {
      HomeTab.send => usesAndroidMornye ? Symbols.send_rounded : (selected ? CupertinoIcons.paperplane_fill : CupertinoIcons.paperplane),
      HomeTab.receive =>
        usesAndroidMornye ? Symbols.move_to_inbox_rounded : (selected ? CupertinoIcons.tray_arrow_down_fill : CupertinoIcons.tray_arrow_down),
      HomeTab.chat => usesAndroidMornye ? Symbols.chat_rounded : (selected ? CupertinoIcons.chat_bubble_fill : CupertinoIcons.chat_bubble),
      HomeTab.settings => usesAndroidMornye ? Symbols.tune_rounded : CupertinoIcons.slider_horizontal_3,
    };

    return Semantics(
      selected: selected,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AppGlassPress(
            radius: 18,
            child: _NavRowHoverTint(
              selected: selected,
              hoverTint: theme.colorScheme.onSurface,
              dark: dark,
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: iconColor),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          tab.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fgColor,
                            fontSize: 13.5,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (badgeCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$badgeCount',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        )
                      else if (selected)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: iconColor,
                          ),
                        ),
                    ],
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

class _NavRowHoverTint extends StatelessWidget {
  const _NavRowHoverTint({
    required this.selected,
    required this.hoverTint,
    required this.dark,
    required this.child,
  });

  final bool selected;
  final Color hoverTint;
  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final interaction = AppGlassPress.maybeOf(context);
    if (interaction == null) return child;
    return CustomPaint(
      painter: _NavRowHoverPainter(
        progress: interaction.progress,
        selected: selected,
        hoverTint: hoverTint,
        dark: dark,
      ),
      child: child,
    );
  }
}

class _NavRowHoverPainter extends CustomPainter {
  _NavRowHoverPainter({
    required this.progress,
    required this.selected,
    required this.hoverTint,
    required this.dark,
  }) : super(repaint: progress);

  final ValueListenable<double> progress;
  final bool selected;
  final Color hoverTint;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (selected || progress.value <= 0.01 || size.isEmpty) return;
    final t = (progress.value / AppGlassPressState.hoverLevel).clamp(0.0, 1.0);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    canvas.drawRRect(
      rrect,
      Paint()..color = hoverTint.withValues(alpha: (dark ? 0.055 : 0.045) * t),
    );
  }

  @override
  bool shouldRepaint(covariant _NavRowHoverPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.selected != selected || oldDelegate.hoverTint != hoverTint || oldDelegate.dark != dark;
}
