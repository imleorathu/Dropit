import 'package:dropit_app/model/persistence/glass_quality.dart';
import 'package:dropit_app/provider/persistence_provider.dart';
import 'package:dropit_app/provider/settings_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('main-delegate-channel'),
      (call) async => call.method == 'isReduceMotionEnabled' ? false : null,
    );
  });

  test('SettingsService persists Liquid Glass preferences and clamps bounds', () async {
    SharedPreferences.setMockInitialValues({
      'ls_alias': 'Dropit test device',
      'ls_show_token': 'test-token',
      'ls_security_context': 'test-identity',
      'ls_locale': 'en',
      'ls_color': 'dropit',
      'ls_version': 4,
    });

    final persistence = await PersistenceService.initialize(supportsDynamicColors: false);
    final service = SettingsService(persistence);
    final initial = service.init();

    expect(initial.glassQuality, AppGlassQuality.liquid);
    expect(initial.glassClarity, 0.90);
    expect(initial.glassFrost, 0.0);
    expect(initial.refractionIntensity, 1.50);
    expect(initial.glassDispersion, 1.32);
    expect(initial.deepEdgeTintEnabled, isFalse);
    expect(initial.allGlassTintEnabled, isFalse);
    expect(initial.deepEdgeTintColor, const Color(0xFF0A84FF));
    expect(initial.glassOutlines, isTrue);
    expect(initial.backgroundAnimation, isTrue);

    await persistence.setGlassQuality(AppGlassQuality.frosted);
    await persistence.setGlassClarity(2.5);
    await persistence.setGlassFrost(1.8);
    await persistence.setRefractionIntensity(3.0);
    await persistence.setGlassDispersion(15.0);
    await persistence.setDeepEdgeTintEnabled(true);
    await persistence.setAllGlassTintEnabled(true);
    await persistence.setDeepEdgeTintColor(const Color(0xFFAF52DE));
    await persistence.setGlassOutlines(false);
    await persistence.setBackgroundAnimation(false);

    final reloaded = await PersistenceService.initialize(supportsDynamicColors: false);
    final reloadedState = SettingsService(reloaded).init();

    expect(reloadedState.glassQuality, AppGlassQuality.frosted);
    expect(reloadedState.glassClarity, 1.0);
    expect(reloadedState.glassFrost, 1.0);
    expect(reloadedState.refractionIntensity, 2.0);
    expect(reloadedState.glassDispersion, 12.0);
    expect(reloadedState.deepEdgeTintEnabled, isTrue);
    expect(reloadedState.allGlassTintEnabled, isTrue);
    expect(reloadedState.deepEdgeTintColor, const Color(0xFFAF52DE));
    expect(reloadedState.glassOutlines, isFalse);
    expect(reloadedState.backgroundAnimation, isFalse);

    await persistence.setGlassClarity(-1.0);
    await persistence.setGlassFrost(-0.4);
    await persistence.setRefractionIntensity(-0.5);
    await persistence.setGlassDispersion(-0.5);
    expect(persistence.getGlassClarity(), 0.0);
    expect(persistence.getGlassFrost(), 0.0);
    expect(persistence.getRefractionIntensity(), 0.0);
    expect(persistence.getGlassDispersion(), 0.0);
  });
}
