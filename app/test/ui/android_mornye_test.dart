import 'package:dropit_app/config/theme.dart';
import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/model/persistence/color_mode.dart';
import 'package:dropit_app/model/send_mode.dart';
import 'package:dropit_app/model/state/nearby_devices_state.dart';
import 'package:dropit_app/model/state/network_state.dart';
import 'package:dropit_app/model/state/server/browser_session_state.dart';
import 'package:dropit_app/pages/home_page.dart';
import 'package:dropit_app/pages/home_page_controller.dart';
import 'package:dropit_app/pages/tabs/receive_tab.dart';
import 'package:dropit_app/pages/tabs/send_tab.dart';
import 'package:dropit_app/pages/tabs/send_tab_vm.dart';
import 'package:dropit_app/pages/tabs/settings_tab.dart';
import 'package:dropit_app/pages/tabs/settings_tab_controller.dart';
import 'package:dropit_app/pages/verify_page.dart';
import 'package:dropit_app/provider/animation_provider.dart';
import 'package:dropit_app/provider/device_info_provider.dart';
import 'package:dropit_app/provider/favorites_provider.dart';
import 'package:dropit_app/provider/local_ip_provider.dart';
import 'package:dropit_app/provider/logging/discovery_logs_provider.dart';
import 'package:dropit_app/provider/network/nearby_devices_provider.dart';
import 'package:dropit_app/provider/network/server/server_provider.dart';
import 'package:dropit_app/provider/persistence_provider.dart';
import 'package:dropit_app/provider/settings_provider.dart';
import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/theme/mornye_theme.dart';
import 'package:dropit_app/widget/dropit/dropit_alert_dialog.dart';
import 'package:dropit_app/widget/dropit/dropit_controls.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/mornye/android_mornye_widgets.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_dialog.dart';
import 'package:dropit_app/widget/mornye/app_glass_navigation.dart';
import 'package:dropit_app/widget/mornye/app_glass_progress.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/macos_native_glass.dart';
import 'package:dropit_app/widget/mornye/mornye_selection_pill.dart';
import 'package:dropit_isolates/constants.dart';
import 'package:dropit_isolates/isolate.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:dropit_isolates/model/device_info_result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../mocks.mocks.dart';

class _UnusedIsolateController extends Fake implements IsolateController {}

class _FixedIpService extends LocalIpService {
  _FixedIpService(super.settingsService);
  @override
  get initialAction => null;
  @override
  NetworkState init() => const NetworkState(localIps: ['192.168.1.42'], initialized: true);
}

MockPersistenceService _buildAndroidPersistence() {
  final persistence = MockPersistenceService();
  when(persistence.getAlias()).thenReturn('Pixel 9 Pro');
  when(persistence.getGlassQuality()).thenReturn(AppGlassQuality.liquid);
  when(persistence.getColorMode()).thenReturn(ColorMode.dropit);
  when(persistence.getTheme()).thenReturn(ThemeMode.light);
  when(persistence.isHttps()).thenReturn(true);
  when(persistence.getPort()).thenReturn(defaultPort);
  when(persistence.getMulticastGroup()).thenReturn(defaultMulticastGroup);
  return persistence;
}

final _sampleDevice = Device.empty.copyWith(
  ip: '192.168.1.24',
  port: defaultPort,
  https: true,
  alias: 'Pixel Tablet',
  fingerprint: 'android-mornye-test-device',
  deviceModel: 'Pixel Tablet',
  deviceType: DeviceType.mobile,
);

void _expectAndroidGlass(WidgetTester tester) {
  expect(find.byType(AndroidMornyeSurface), findsWidgets);
  expect(find.byType(LiquidGlassView), findsNothing);
  expect(find.byType(MacosNativeGlassBackdropScope), findsNothing);
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Android ${brightness.name} respects saved glass tiers and keeps interactions', (tester) async {
      for (final quality in AppGlassQuality.values) {
        var presses = 0;
        var tab = -1;
        var toggled = false;
        var slider = 0.5;
        final theme = getTheme(ColorMode.dropit, Colors.blue, brightness, null);
        expect(theme.scaffoldBackgroundColor.a, 1);
        expect(theme.cardTheme.color!.a, lessThan(1));
        await tester.pumpWidget(
          AppGlassConfigScope(
            config: AppGlassConfigData(quality: quality, clarity: 1, dispersion: 10, allGlassTintEnabled: true),
            child: MaterialApp(
              theme: theme,
              home: DropitBackdrop(
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 300,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppLiquidGlass(child: SizedBox(height: 40, width: 300)),
                          AppGlassButton(label: 'Send files', onPressed: () => presses++),
                          StatefulBuilder(
                            builder: (context, setState) => DropitSwitch(value: toggled, onChanged: (value) => setState(() => toggled = value)),
                          ),
                          StatefulBuilder(
                            builder: (context, setState) => DropitSlider(value: slider, onChanged: (value) => setState(() => slider = value)),
                          ),
                          AppGlassNavigation(
                            items: const [
                              AppGlassNavItem(label: 'Send', icon: Icons.send),
                              AppGlassNavItem(label: 'Receive', icon: Icons.download),
                            ],
                            activeIndex: 0,
                            onChanged: (value) => tab = value,
                          ),
                          Builder(
                            builder: (context) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => showDialog<void>(
                                    context: context,
                                    builder: (_) => const DropitAlertDialog(title: Text('Ready to share'), content: Text('Dialog content')),
                                  ),
                                  child: const Text('Open dialog'),
                                ),
                                TextButton(
                                  onPressed: () => showAppGlassDialog<void>(
                                    context: context,
                                    builder: (_) => const AppGlassDialog(child: Text('Glass dialog replacement')),
                                  ),
                                  child: const Text('Open app dialog'),
                                ),
                                TextButton(
                                  onPressed: () => showAppGlassSheet<void>(
                                    context: context,
                                    builder: (_) => const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Text('Glass sheet'),
                                    ),
                                  ),
                                  child: const Text('Open sheet'),
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
            ),
          ),
        );
        await tester.tap(find.text('Send files'));
        await tester.tap(find.byType(DropitSwitch));
        await tester.tap(find.text('Receive'));
        await tester.tapAt(tester.getCenter(find.byType(DropitSlider)) + const Offset(65, 0));
        await tester.pumpAndSettle();
        expect(presses, 1);
        expect(toggled, isTrue);
        expect(tab, 1);
        expect(slider, greaterThan(0.5));
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(MornyeSelectionPill), findsWidgets);
        expect(find.ancestor(of: find.byType(DropitSwitch), matching: find.byType(FittedBox)), findsNothing);

        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();
        expect(find.text('Ready to share'), findsOneWidget);
        _expectAndroidGlass(tester);
        Navigator.of(tester.element(find.text('Ready to share'))).pop();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open app dialog'));
        await tester.pumpAndSettle();
        expect(find.text('Glass dialog replacement'), findsOneWidget);
        _expectAndroidGlass(tester);
        Navigator.of(tester.element(find.text('Glass dialog replacement'))).pop();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open sheet'));
        await tester.pumpAndSettle();
        expect(find.text('Glass sheet'), findsOneWidget);
        _expectAndroidGlass(tester);
        Navigator.of(tester.element(find.text('Glass sheet'))).pop();
        await tester.pumpAndSettle();

        final surface = tester.widget<DecoratedBox>(find.byKey(const ValueKey('android-liquid-glass-surface')).first);
        final fill = (surface.decoration as BoxDecoration).color!;
        expect(fill.a, quality == AppGlassQuality.flat ? 1 : lessThan(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  test('Android light, dark and OLED retain Mornye glass settings and type hierarchy', () {
    final lightTheme = getTheme(ColorMode.dropit, Colors.blue, Brightness.light, null);
    final darkTheme = getTheme(ColorMode.dropit, Colors.blue, Brightness.dark, null);
    final oledTheme = getTheme(ColorMode.oled, Colors.blue, Brightness.dark, null);

    for (final theme in [lightTheme, darkTheme, oledTheme]) {
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor.a, 1);
      expect(theme.textTheme.titleLarge?.fontFamily, AndroidMornyeTheme.fontFamily);
      expect(theme.textTheme.bodyMedium?.fontFamily, AndroidMornyeTheme.fontFamily);
      expect(theme.extension<MornyeTheme>(), isNotNull);
      expect(theme.appBarTheme.backgroundColor, Colors.transparent);
      expect(theme.cardTheme.color!.a, lessThan(1));
    }

    expect(oledTheme.scaffoldBackgroundColor, Colors.black);
  });

  testWidgets('Android SendTab, ReceiveTab, SettingsTab, VerifyPage, and DropitShell use Android glass across compact and wide layouts', (
    tester,
  ) async {
    final persistence = _buildAndroidPersistence();

    Future<void> pumpAndroidShell({required Size size, required HomeTab tab, required Widget child}) async {
      await tester.binding.setSurfaceSize(size);
      final vm = SendTabVm(
        sendMode: SendMode.single,
        selectedFiles: [],
        localIps: ['192.168.1.42'],
        nearbyDevices: [_sampleDevice],
        favoriteDevices: [],
        browserSessions: BrowserSessionsState.empty,
        serverPort: defaultPort,
        browserPort: null,
        serverHttps: true,
        onTapAddress: (_) async {},
        onTapFavorite: (_) async {},
        onTapSendMode: (_, _) async {},
        onTapDevice: (_, _) async {},
        onTapDeviceMultiSend: (_, _) async {},
        onTapBrowser: (_, _) async {},
        onDisconnectBrowser: (_, _) async {},
      );
      await tester.pumpWidget(
        RefenaScope(
          overrides: [
            persistenceProvider.overrideWithValue(persistence),
            animationProvider.overrideWithBuilder((_) => false),
            sendTabVmProvider.overrideWithBuilder((_) => vm),
            deviceRawInfoProvider.overrideWithValue(
              DeviceInfoResult(
                deviceType: DeviceType.mobile,
                deviceModel: 'Pixel 9',
                androidSdkInt: 36,
              ),
            ),
            localIpProvider.overrideWithNotifier((_) => _FixedIpService(SettingsService(persistence))),
            nearbyDevicesProvider.overrideWithInitialState(
              notifier: (_) => NearbyDevicesService(
                isolateController: _UnusedIsolateController(),
                favoriteService: FavoritesService(persistence),
                discoveryLogs: DiscoveryLogger(),
              ),
              initialState: NearbyDevicesState(
                runningFavoriteScan: false,
                runningIps: {},
                devices: {_sampleDevice.fingerprint: _sampleDevice},
                signalingDevices: {},
              ),
            ),
            settingsTabControllerProvider.overrideWithNotifier(
              (ref) => SettingsTabController(
                settingsService: ref.notifier(settingsProvider),
                serverNotifier: ref.notifier(serverProvider),
                isolateController: _UnusedIsolateController(),
                localIpService: ref.notifier(localIpProvider),
                initialDeviceInfo: DeviceInfoResult(
                  deviceType: DeviceType.mobile,
                  deviceModel: 'Pixel 9',
                  androidSdkInt: 36,
                ),
                supportsDynamicColors: true,
              ),
            ),
          ],
          child: MaterialApp(
            theme: getTheme(ColorMode.dropit, Colors.blue, Brightness.light, null),
            home: DropitShell(
              vm: HomePageVm(controller: PageController(), currentTab: tab, changeTab: (_) {}),
              alias: 'Pixel 9 Pro',
              online: true,
              child: child,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpAndroidShell(size: const Size(390, 844), tab: HomeTab.send, child: const SendTab());
    _expectAndroidGlass(tester);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(MornyeSelectionPill), findsWidgets);
    expect(find.byType(AppGlassSegmented), findsWidgets);
    expect(find.byType(AndroidMornyeSearchField), findsOneWidget);
    expect(find.text('Glass'), findsNothing);
    expect(find.text('Glass Controls'), findsNothing);

    await pumpAndroidShell(size: const Size(390, 844), tab: HomeTab.receive, child: const ReceiveTab());
    _expectAndroidGlass(tester);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(MornyeSelectionPill), findsWidgets);
    expect(find.text('Glass Controls'), findsNothing);

    await pumpAndroidShell(size: const Size(1024, 768), tab: HomeTab.settings, child: const SettingsTab());
    _expectAndroidGlass(tester);
    expect(find.byType(AndroidMornyeSectionHeader), findsWidgets);
    expect(find.text(t.settingsTab.general.brightness), findsOneWidget);
    expect(find.text(t.settingsTab.general.color), findsOneWidget);
    expect(find.text('Glass Style'), findsOneWidget);
    expect(find.text('Glass Controls'), findsNothing);

    await tester.pumpWidget(
      RefenaScope(
        overrides: [persistenceProvider.overrideWithValue(persistence)],
        child: MaterialApp(
          theme: getTheme(ColorMode.dropit, Colors.blue, Brightness.light, null),
          home: VerifyPage(
            fingerprint: CombinedFingerprint(
              combined: '0123456789abcdef',
              icons: const [Icons.star, Icons.check, Icons.lock, Icons.shield],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _expectAndroidGlass(tester);
    expect(find.byType(AppGlassSegmented), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: getTheme(ColorMode.dropit, Colors.blue, Brightness.light, null),
        home: const Scaffold(
          body: Center(
            child: SizedBox(width: 240, child: AppGlassProgress(progress: 0.4)),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    _expectAndroidGlass(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(AppLiquidGlass), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android nested glass takes one backdrop read and contrast removes it', (tester) async {
    Future<void> pump({required bool contrast}) => tester.pumpWidget(
      MaterialApp(
        theme: getTheme(ColorMode.dropit, Colors.blue, Brightness.light, null),
        home: MediaQuery(
          data: MediaQueryData(highContrast: contrast, disableAnimations: true),
          child: const AppGlassConfigScope(
            config: AppGlassConfigData(quality: AppGlassQuality.frosted),
            child: Scaffold(
              body: Center(
                child: AppLiquidGlass(
                  child: AppLiquidGlass(child: SizedBox(width: 180, height: 60)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await pump(contrast: false);
    expect(find.byType(BackdropFilter), findsOneWidget);
    await pump(contrast: true);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(AndroidMornyeSurface), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android determinate progress and reduced motion leave no idle tickers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getTheme(ColorMode.dropit, Colors.blue, Brightness.dark, null),
        home: const AppGlassConfigScope(
          config: AppGlassConfigData(reduceMotion: true),
          child: Scaffold(
            body: Center(child: SizedBox(width: 240, child: AppGlassProgress(progress: 0.4))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-Android platforms preserve Liquid Glass pipeline and widgets', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        expect(usesAndroidMornye, platform == TargetPlatform.android);
        final theme = getTheme(ColorMode.dropit, Colors.blue, Brightness.light, null);
        expect(theme.scaffoldBackgroundColor.a, platform == TargetPlatform.android ? 1 : 0);
      }

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await tester.pumpWidget(
        AppGlassConfigScope(
          config: const AppGlassConfigData(quality: AppGlassQuality.liquid),
          child: MaterialApp(
            theme: getTheme(ColorMode.dropit, Colors.blue, Brightness.light, null),
            home: Scaffold(
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLiquidGlass(child: SizedBox(width: 120, height: 40)),
                  AppGlassButton(label: 'macOS Glass', onPressed: () {}),
                  AppGlassNavigation(
                    items: const [
                      AppGlassNavItem(label: 'Send', icon: Icons.send),
                      AppGlassNavItem(label: 'Receive', icon: Icons.download),
                    ],
                    activeIndex: 0,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AndroidMornyeSurface), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
