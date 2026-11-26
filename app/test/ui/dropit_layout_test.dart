import 'dart:io';

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
import 'package:dropit_app/provider/animation_provider.dart';
import 'package:dropit_app/provider/favorites_provider.dart';
import 'package:dropit_app/provider/local_ip_provider.dart';
import 'package:dropit_app/provider/logging/discovery_logs_provider.dart';
import 'package:dropit_app/provider/network/nearby_devices_provider.dart';
import 'package:dropit_app/provider/persistence_provider.dart';
import 'package:dropit_app/provider/settings_provider.dart';
import 'package:dropit_app/widget/list_tile/device_list_tile.dart';
import 'package:dropit_isolates/constants.dart';
import 'package:dropit_isolates/isolate.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

final _device = Device.empty.copyWith(
  ip: '192.168.1.12',
  port: defaultPort,
  https: true,
  alias: 'Alex’s MacBook',
  fingerprint: 'preview-device',
  deviceModel: 'MacBook Pro',
  deviceType: DeviceType.desktop,
);

void main() {
  const capture = bool.fromEnvironment('DROPIT_CAPTURE');
  setUpAll(() async {
    if (capture) {
      final loader = FontLoader('DropitPreview')..addFont(File('/System/Library/Fonts/SFNS.ttf').readAsBytes().then((b) => ByteData.sublistView(b)));
      await loader.load();
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader(
        'packages/cupertino_icons/CupertinoIcons',
      )..addFont(rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'))).load();
    }
  });
  for (final size in [const Size(320, 740), const Size(390, 844), const Size(834, 1112), const Size(900, 500), const Size(1200, 800)]) {
    for (final dark in [false, true]) {
      testWidgets('send layout ${size.width} ${dark ? 'dark' : 'light'} preserves device action', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final persistence = MockPersistenceService();
        var selected = 0;
        final vm = SendTabVm(
          sendMode: SendMode.single,
          selectedFiles: [],
          localIps: [],
          nearbyDevices: [_device],
          favoriteDevices: [],
          browserSessions: BrowserSessionsState.empty,
          serverPort: null,
          browserPort: null,
          serverHttps: false,
          onTapAddress: (_) async {},
          onTapFavorite: (_) async {},
          onTapSendMode: (_, _) async {},
          onTapDevice: (_, device) async {
            expect(device.fingerprint, _device.fingerprint);
            selected++;
          },
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
              nearbyDevicesProvider.overrideWithInitialState(
                notifier: (_) => NearbyDevicesService(
                  isolateController: _UnusedIsolateController(),
                  favoriteService: FavoritesService(persistence),
                  discoveryLogs: DiscoveryLogger(),
                ),
                initialState: NearbyDevicesState(
                  runningFavoriteScan: false,
                  runningIps: {},
                  devices: {_device.fingerprint: _device},
                  signalingDevices: {},
                ),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: getTheme(ColorMode.dropit, Colors.blue, dark ? Brightness.dark : Brightness.light, null).copyWith(
                textTheme: capture
                    ? getTheme(
                        ColorMode.dropit,
                        Colors.blue,
                        dark ? Brightness.dark : Brightness.light,
                        null,
                      ).textTheme.apply(fontFamily: 'DropitPreview')
                    : null,
              ),
              home: DropitShell(
                vm: HomePageVm(controller: PageController(), currentTab: HomeTab.send, changeTab: (_) {}),
                alias: 'This Mac',
                online: true,
                child: const SendTab(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(t.sendTab.title), findsWidgets);
        expect(find.byType(LiquidGlassLens), findsNothing);
        if (capture && (size.width == 390 || size.width == 1200)) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('../../../../docs/previews/dropit-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png'),
          );
        }
        await tester.ensureVisible(find.byType(DeviceListTile));
        await tester.tap(find.text('Alex’s MacBook'));
        await tester.pump();
        expect(selected, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('long receiver names and large text remain scrollable on a narrow phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final persistence = MockPersistenceService();
    when(persistence.getAlias()).thenReturn('A very long device name with 日本語 and emoji 📱 that must wrap');
    when(persistence.isHttps()).thenReturn(true);
    when(persistence.getPort()).thenReturn(defaultPort);
    when(persistence.getMulticastGroup()).thenReturn(defaultMulticastGroup);
    await tester.pumpWidget(
      RefenaScope(
        overrides: [
          persistenceProvider.overrideWithValue(persistence),
          localIpProvider.overrideWithNotifier((_) => _FixedIpService(SettingsService(persistence))),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: getTheme(ColorMode.dropit, Colors.blue, Brightness.light, null),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const Scaffold(body: ReceiveTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Receiver offline'), findsOneWidget);
    await tester.ensureVisible(find.text('Connection details'));
    await tester.tap(find.text('Connection details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('192.168.1.42'), findsOneWidget);
    expect(find.textContaining('Multicast 224.0.0.168'), findsOneWidget);
    expect(find.textContaining('LocalSend compatible'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long device names keep send and details actions distinct', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var sent = 0;
    var inspected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DeviceListTile(
              device: _device.copyWith(alias: '📱日本語 very long receiver name ' * 8),
              onTap: () => sent++,
              onDetailsTap: () => inspected++,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Device details'));
    await tester.pump();
    expect(inspected, 1);
    expect(sent, 0);
  });
}
