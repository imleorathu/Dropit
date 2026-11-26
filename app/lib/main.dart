import 'dart:async';

import 'package:dropit_app/config/init.dart';
import 'package:dropit_app/config/theme.dart';
import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/model/persistence/color_mode.dart';
import 'package:dropit_app/pages/home_page.dart';
import 'package:dropit_app/provider/animation_provider.dart';
import 'package:dropit_app/provider/local_ip_provider.dart';
import 'package:dropit_app/provider/network/server/server_provider.dart';
import 'package:dropit_app/provider/settings_provider.dart';
import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/theme/mornye_theme.dart';
import 'package:dropit_app/util/native/platform_check.dart';
import 'package:dropit_app/util/ui/dynamic_colors.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/dropit_chromatic_glass.dart';
import 'package:dropit_app/widget/mornye/macos_native_glass.dart';
import 'package:dropit_app/widget/watcher/life_cycle_watcher.dart';
import 'package:dropit_app/widget/watcher/shortcut_watcher.dart';
import 'package:dropit_app/widget/watcher/tray_watcher.dart';
import 'package:dropit_app/widget/watcher/window_watcher.dart';
import 'package:dropit_isolates/isolate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (usesAndroidMornye) {
    // Blur, refraction and dispersion use the same bounded backdrop read.
    // Shaders load lazily after the bootstrap's first usable frame.
    LiquidGlassConfiguration.blurMethod = LiquidGlassBlurMethod.shader;
    LiquidGlassConfiguration.batchBlurMethod = LiquidGlassBlurMethod.shader;
    LiquidGlassConfiguration.batchMode = LiquidGlassBatchMode.singlePass;
  }
  if (!usesAndroidMornye) {
    LiquidGlassConfiguration.blurMethod = LiquidGlassBlurMethod.shader;
    LiquidGlassConfiguration.batchBlurMethod = LiquidGlassBlurMethod.shader;
    LiquidGlassConfiguration.batchMode = LiquidGlassBatchMode.singlePass;
    LiquidGlassConfiguration.shaderBlurDispersion = true;
    LiquidGlassConfiguration.batchShaderBlurDispersion = true;
    LiquidGlassConfiguration.dispersionOverride = null;
    try {
      await LiquidGlassShaders.ensureLoaded();
    } catch (_) {}
    try {
      await DropitChromaticGlassShaders.ensureLoaded();
    } catch (_) {}
  }
  runApp(DropitBootstrap(args: args));
}

typedef DropitInitializer = Future<RefenaContainer> Function(List<String> args);

/// Paints a usable first frame before native plugins, Rust, persistence and
/// child isolates initialize. A failed startup therefore becomes an actionable
/// error instead of leaving Android/iOS on their native launch screen forever.
class DropitBootstrap extends StatefulWidget {
  final List<String> args;
  final DropitInitializer initializer;
  final Duration timeout;

  const DropitBootstrap({
    required this.args,
    this.initializer = preInit,
    this.timeout = const Duration(seconds: 30),
    super.key,
  });

  @override
  State<DropitBootstrap> createState() => _DropitBootstrapState();
}

class _DropitBootstrapState extends State<DropitBootstrap> {
  RefenaContainer? _container;
  Future<RefenaContainer>? _initialization;
  Object? _error;
  StackTrace? _stackTrace;
  var _attempt = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final attempt = ++_attempt;
    setState(() {
      _error = null;
      _stackTrace = null;
    });
    try {
      final initialization = _initialization ??= widget.initializer(widget.args);
      final container = await initialization.timeout(
        widget.timeout,
        onTimeout: () => throw TimeoutException('Dropit could not finish starting within ${widget.timeout.inSeconds} seconds.'),
      );
      if (!mounted || attempt != _attempt) return;
      setState(() => _container = container);
    } catch (error, stackTrace) {
      if (!mounted || attempt != _attempt) return;
      _initialization = null;
      setState(() {
        _error = error;
        _stackTrace = stackTrace;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final container = _container;
    if (container != null) {
      return RefenaScope.withContainer(
        container: container,
        child: TranslationProvider(child: const DropitApp()),
      );
    }
    return _StartupApp(error: _error, stackTrace: _stackTrace, onRetry: _start);
  }
}

class _StartupApp extends StatelessWidget {
  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;

  const _StartupApp({required this.error, required this.stackTrace, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dropit',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(overscroll: false),
      themeMode: ThemeMode.system,
      theme: usesAndroidMornye
          ? getTheme(ColorMode.dropit, Colors.blue, Brightness.light, null)
          : MornyeTheme.build(Brightness.light).copyWith(scaffoldBackgroundColor: Colors.transparent),
      darkTheme: usesAndroidMornye
          ? getTheme(ColorMode.dropit, Colors.blue, Brightness.dark, null)
          : MornyeTheme.build(Brightness.dark).copyWith(scaffoldBackgroundColor: Colors.transparent),
      builder: (context, child) {
        if (usesAndroidMornye) return child!;
        final brightness = Theme.of(context).brightness;
        unawaited(MacosNativeGlass.setAppearance(brightness == Brightness.dark ? 'dark' : 'light'));
        return DropitBackdrop(child: child!);
      },
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: error == null ? const _StartupProgress() : _StartupFailure(error: error!, stackTrace: stackTrace, onRetry: onRetry),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupProgress extends StatelessWidget {
  const _StartupProgress();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Starting Dropit',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.near_me_rounded, size: 38, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 24),
          Text('Dropit', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1)),
          const SizedBox(height: 10),
          Text('Preparing private sharing…', style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 28),
          if (reduceMotion)
            Icon(Icons.hourglass_top_rounded, color: scheme.primary, semanticLabel: 'Loading')
          else
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ],
      ),
    );
  }
}

class _StartupFailure extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;

  const _StartupFailure({required this.error, required this.stackTrace, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = 'Error: $error\n\n${stackTrace ?? ''}';
    return Semantics(
      liveRegion: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, size: 34, color: scheme.error),
              const SizedBox(height: 16),
              Text('Dropit couldn’t start', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Your files are safe. Try again, or copy the details if the problem continues.',
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 18),
              SelectableText(error.toString(), maxLines: 5, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: details));
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DropitApp extends StatelessWidget {
  const DropitApp();

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    // Keep the global ticker timing in sync even when neither the Send tab scan
    // button nor a placeholder tile is mounted.
    ref.watch(animationProvider);
    final (
      themeMode,
      colorMode,
      customColor,
      glassQuality,
      glassClarity,
      glassFrost,
      refractionIntensity,
      glassDispersion,
      deepEdgeTintEnabled,
      allGlassTintEnabled,
      deepEdgeTintColor,
      glassOutlines,
      backgroundAnimation,
      enableAnimations,
    ) = ref.watch(
      settingsProvider.select(
        (settings) => (
          settings.theme,
          settings.colorMode,
          settings.customColor,
          settings.glassQuality,
          settings.glassClarity,
          settings.glassFrost,
          settings.refractionIntensity,
          settings.glassDispersion,
          settings.deepEdgeTintEnabled,
          settings.allGlassTintEnabled,
          settings.deepEdgeTintColor,
          settings.glassOutlines,
          settings.backgroundAnimation,
          settings.enableAnimations,
        ),
      ),
    );
    final dynamicColors = ref.watch(dynamicColorsProvider);
    return TrayWatcher(
      child: WindowWatcher(
        child: LifeCycleWatcher(
          onChangedState: (AppLifecycleState state) {
            switch (state) {
              case AppLifecycleState.resumed:
                ref.redux(localIpProvider).dispatch(InitLocalIpAction());
                if (checkPlatform([TargetPlatform.iOS, TargetPlatform.android])) {
                  // The OS may have invalidated the sockets of the suspended app without any error ever reaching the accept loop.
                  // ignore: discarded_futures
                  ref.notifier(serverProvider).ensureRunning();
                }
                if (checkPlatform([TargetPlatform.iOS])) {
                  // The multicast sockets die the same silent way but cannot be probed, so always rebind them.
                  ref.redux(parentIsolateProvider).dispatch(IsolateDiscoveryRestartAction());
                }
                break;
              case AppLifecycleState.detached:
                // The main isolate is only exited when all child isolates are exited.
                // https://github.com/localsend/localsend/issues/1568
                ref.redux(parentIsolateProvider).dispatch(IsolateDisposeAction());
                break;
              default:
                break;
            }
          },
          child: ShortcutWatcher(
            child: MaterialApp(
              title: 'Dropit',
              scrollBehavior: const MaterialScrollBehavior().copyWith(overscroll: false),
              builder: (context, child) {
                final disableAnimations = MediaQuery.disableAnimationsOf(context) || !enableAnimations;
                final highContrast = MediaQuery.highContrastOf(context);
                if (!usesAndroidMornye) {
                  final brightness = Theme.of(context).brightness;
                  unawaited(MacosNativeGlass.setAppearance(brightness == Brightness.dark ? 'dark' : 'light'));
                }
                final glassConfig = AppGlassConfigData(
                  quality: glassQuality,
                  clarity: glassClarity,
                  glassFrost: glassFrost,
                  refractionIntensity: refractionIntensity,
                  dispersion: glassDispersion,
                  deepEdgeTintEnabled: deepEdgeTintEnabled,
                  allGlassTintEnabled: allGlassTintEnabled,
                  deepEdgeTintColor: deepEdgeTintColor,
                  outlines: glassOutlines,
                  backgroundAnimation: backgroundAnimation,
                  reduceMotion: disableAnimations,
                  highContrast: highContrast,
                );
                final content = MediaQuery(
                  data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
                  child: child!,
                );
                return AppGlassConfigScope(
                  config: glassConfig,
                  child: DropitBackdrop(child: content),
                );
              },
              locale: TranslationProvider.of(context).flutterLocale,
              supportedLocales: AppLocaleUtils.supportedLocales,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              debugShowCheckedModeBanner: false,
              theme: getTheme(
                colorMode,
                customColor,
                Brightness.light,
                dynamicColors,
                glassClarity: glassClarity,
                glassOutlines: glassOutlines,
              ),
              darkTheme: getTheme(
                colorMode,
                customColor,
                Brightness.dark,
                dynamicColors,
                glassClarity: glassClarity,
                glassOutlines: glassOutlines,
              ),
              themeMode: colorMode == ColorMode.oled ? ThemeMode.dark : themeMode,
              navigatorKey: context.read(navigationProvider).key,
              home: RouterinoHome(
                builder: () => const HomePage(
                  initialTab: HomeTab.send,
                  appStart: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
