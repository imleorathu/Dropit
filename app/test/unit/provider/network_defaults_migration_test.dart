import 'package:dropit_app/provider/persistence_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const identity = <String, Object>{
    'ls_alias': 'Dropit test device',
    'ls_show_token': 'test-token',
    'ls_security_context': 'unchanged-test-identity',
    'ls_locale': 'en',
    'ls_color': 'localsend',
  };

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('main-delegate-channel'),
      (call) async => call.method == 'isReduceMotionEnabled' ? false : null,
    );
  });

  Future<PersistenceService> initialize(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues({...identity, ...values});
    return PersistenceService.initialize(supportsDynamicColors: false);
  }

  test('fresh installs use the Dropit network and retain the existing device identity', () async {
    final persistence = await initialize({});
    expect(persistence.isFirstAppStart, isTrue);
    expect(persistence.getPort(), 53318);
    expect(persistence.getMulticastGroup(), '224.0.0.168');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('ls_version'), 4);
    expect(prefs.getString('ls_security_context'), identity['ls_security_context']);
  });

  test('upgrading legacy defaults migrates both HTTP and discovery settings', () async {
    final persistence = await initialize({'ls_version': 3, 'ls_port': 53317, 'ls_multicast_group': '224.0.0.167'});
    expect(persistence.isFirstAppStart, isFalse);
    expect(persistence.getPort(), 53318);
    expect(persistence.getMulticastGroup(), '224.0.0.168');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('ls_version'), 4);
    expect(prefs.getInt('ls_port'), 53318);
    expect(prefs.getString('ls_multicast_group'), '224.0.0.168');
  });

  test('custom network values remain intact while upgrading', () async {
    final persistence = await initialize({'ls_version': 3, 'ls_port': 55000, 'ls_multicast_group': '239.22.33.44'});
    expect(persistence.getPort(), 55000);
    expect(persistence.getMulticastGroup(), '239.22.33.44');
  });

  test('a custom port does not prevent the old multicast default from migrating', () async {
    final persistence = await initialize({'ls_version': 3, 'ls_port': 55000, 'ls_multicast_group': '224.0.0.167'});
    expect(persistence.getPort(), 55000);
    expect(persistence.getMulticastGroup(), '224.0.0.168');
  });

  test('unversioned legacy defaults also migrate', () async {
    final persistence = await initialize({'ls_port': 53317, 'ls_multicast_group': '224.0.0.167'});
    expect(persistence.getPort(), 53318);
    expect(persistence.getMulticastGroup(), '224.0.0.168');
  });

  test('migration is one-time and does not overwrite later manual settings', () async {
    final persistence = await initialize({'ls_version': 3, 'ls_port': 53317, 'ls_multicast_group': '224.0.0.167'});
    await persistence.setPort(53317);
    await persistence.setMulticastGroup('239.1.2.3');
    final restarted = await PersistenceService.initialize(supportsDynamicColors: false);
    expect(restarted.getPort(), 53317);
    expect(restarted.getMulticastGroup(), '239.1.2.3');
  });
}
