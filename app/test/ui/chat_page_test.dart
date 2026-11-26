import 'package:dropit_app/pages/chat_page.dart';
import 'package:dropit_app/provider/device_info_provider.dart';
import 'package:dropit_app/provider/favorites_provider.dart';
import 'package:dropit_app/provider/file_transfer_provider.dart';
import 'package:dropit_app/provider/logging/discovery_logs_provider.dart';
import 'package:dropit_app/provider/network/nearby_devices_provider.dart';
import 'package:dropit_app/provider/network/send_provider.dart';
import 'package:dropit_app/provider/persistence_provider.dart';
import 'package:dropit_isolates/isolate.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeIsolateController extends Fake implements IsolateController {}

Device _device(String fp, {String? ip, String alias = 'Device'}) => Device(
  signalingId: null,
  ip: ip,
  version: '2.2',
  port: 53317,
  https: true,
  fingerprint: fp,
  alias: alias,
  deviceModel: 'Pixel 7',
  deviceType: DeviceType.mobile,
  download: false,
  channels: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('main-delegate-channel'),
      (call) async => call.method == 'isReduceMotionEnabled' ? false : null,
    );
  });

  testWidgets('ChatPage handles Android keyboard insets without overflow and renders sent messages immediately', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final persistence = await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({
        'ls_alias': 'Android Test',
        'ls_show_token': 'token',
        'ls_security_context': 'ctx',
        'ls_locale': 'en',
        'ls_color': 'dropit',
        'ls_version': 4,
      });
      return PersistenceService.initialize(supportsDynamicColors: false);
    });
    if (persistence == null) throw StateError('Failed to init persistence');
    final peer = _device('PEER9999', ip: null, alias: 'MacBook Pro');

    await tester.pumpWidget(
      RefenaScope(
        overrides: [
          persistenceProvider.overrideWithValue(persistence),
          deviceFullInfoProvider.overrideWithBuilder((_) => _device('ME1111', ip: '192.168.1.20', alias: 'Pixel 7')),
          nearbyDevicesProvider.overrideWithNotifier(
            (ref) => NearbyDevicesService(
              isolateController: _FakeIsolateController(),
              favoriteService: FavoritesService(persistence),
              discoveryLogs: DiscoveryLogger(),
            ),
          ),
          sendProvider.overrideWithNotifier((_) => SendNotifier()),
          fileTransferProvider.overrideWithNotifier((ref) => FileTransferNotifier()),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(412, 915), viewInsets: EdgeInsets.only(bottom: 320)),
            child: ChatPage(peer: peer),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('MacBook Pro'), findsOneWidget);
    expect(find.text('Say hello to MacBook Pro'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hello from Android');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Hello from Android'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
