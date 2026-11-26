import 'package:dropit_app/config/theme.dart';
import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/model/cross_file.dart';
import 'package:dropit_app/model/persistence/color_mode.dart';
import 'package:dropit_app/model/state/network_state.dart';
import 'package:dropit_app/pages/tabs/settings_tab.dart';
import 'package:dropit_app/pages/tabs/settings_tab_controller.dart';
import 'package:dropit_app/pages/verify_page.dart';
import 'package:dropit_app/pages/web_share_page.dart';
import 'package:dropit_app/provider/device_info_provider.dart';
import 'package:dropit_app/provider/local_ip_provider.dart';
import 'package:dropit_app/provider/network/server/server_provider.dart';
import 'package:dropit_app/provider/persistence_provider.dart';
import 'package:dropit_app/provider/settings_provider.dart';
import 'package:dropit_app/theme/mornye_theme.dart';
import 'package:dropit_app/widget/dropit/dropit_controls.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_glass_cards.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_navigation.dart';
import 'package:dropit_app/widget/mornye/app_glass_panel.dart';
import 'package:dropit_app/widget/mornye/app_glass_press.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/macos_native_glass.dart';
import 'package:dropit_isolates/isolate.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:dropit_isolates/model/device_info_result.dart';
import 'package:dropit_isolates/model/file_type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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

MockPersistenceService _buildMockPersistence() {
  final persistence = MockPersistenceService();
  when(persistence.getAlias()).thenReturn('Studio Mac');
  when(persistence.getGlassQuality()).thenReturn(AppGlassQuality.liquid);
  when(persistence.getColorMode()).thenReturn(ColorMode.dropit);
  when(persistence.getTheme()).thenReturn(ThemeMode.light);
  return persistence;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    MacosNativeGlass.resetForTest();
  });

  testWidgets('SettingsTab renders with zero overflow at 320x700 and 393x852, keeps switches inline at 393px and stacks Glass style', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final persistence = _buildMockPersistence();

      Future<void> pumpSettings(Size size) async {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          RefenaScope(
            overrides: [
              persistenceProvider.overrideWithValue(persistence),
              deviceRawInfoProvider.overrideWithValue(
                DeviceInfoResult(
                  deviceType: DeviceType.desktop,
                  deviceModel: 'MacBook Pro',
                  androidSdkInt: null,
                ),
              ),
              localIpProvider.overrideWithNotifier((_) => _FixedIpService(SettingsService(persistence))),
              settingsTabControllerProvider.overrideWithNotifier(
                (ref) => SettingsTabController(
                  settingsService: ref.notifier(settingsProvider),
                  serverNotifier: ref.notifier(serverProvider),
                  isolateController: _UnusedIsolateController(),
                  localIpService: ref.notifier(localIpProvider),
                  initialDeviceInfo: DeviceInfoResult(
                    deviceType: DeviceType.desktop,
                    deviceModel: 'MacBook Pro',
                    androidSdkInt: null,
                  ),
                  supportsDynamicColors: false,
                ),
              ),
            ],
            child: MaterialApp(
              theme: getTheme(ColorMode.dropit, Colors.blue, Brightness.light, null),
              home: const Scaffold(
                body: DropitBackdrop(
                  child: SettingsTab(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull);
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpSettings(const Size(393, 852));

      // Switches must stay inline beside their label on a 393px phone
      final quickSaveLabel = find.text(t.settingsTab.receive.quickSave);
      expect(quickSaveLabel, findsOneWidget);
      final quickSaveRow = find.ancestor(of: quickSaveLabel, matching: find.byType(Row)).first;
      final quickSaveSwitch = find.descendant(of: quickSaveRow, matching: find.byType(DropitSwitch));
      expect(quickSaveSwitch, findsOneWidget);
      final switchCenterY = tester.getCenter(quickSaveSwitch).dy;
      final labelCenterY = tester.getCenter(quickSaveLabel).dy;
      expect((switchCenterY - labelCenterY).abs(), lessThan(24.0));

      // Wide trailing control (trailingWidth: 300, AppGlassSegmented) must stack below its label on 393px phone
      final glassSeg = find.byType(AppGlassSegmented).first;
      await tester.scrollUntilVisible(
        glassSeg,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      final glassLabel = find.text('Glass Style');
      expect(glassLabel, findsOneWidget);
      expect(glassSeg, findsOneWidget);
      expect(tester.getTopLeft(glassSeg).dy, greaterThan(tester.getBottomLeft(glassLabel).dy - 1));

      await pumpSettings(const Size(320, 700));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('WebSharePage renders without horizontal overflow at 320x700', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final persistence = _buildMockPersistence();

    await tester.pumpWidget(
      RefenaScope(
        overrides: [
          persistenceProvider.overrideWithValue(persistence),
          localIpProvider.overrideWithNotifier((_) => _FixedIpService(SettingsService(persistence))),
        ],
        child: MaterialApp(
          theme: getTheme(ColorMode.dropit, Colors.blue, Brightness.light, null),
          home: WebSharePage(
            files: [
              CrossFile(
                name: 'Very_Long_Transfer_Archive_Name_For_Narrow_Layout_Verification_2026.zip',
                fileType: FileType.values.first,
                size: 1024 * 1024,
                thumbnail: null,
                asset: null,
                path: null,
                bytes: Uint8List(4),
                lastModified: null,
                lastAccessed: null,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppGlassButton and AppGlassDropZone support pointer tap plus Tab + Enter/Space activation', (tester) async {
    var buttonHits = 0;
    var dropZoneHits = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppGlassConfigScope(
            config: const AppGlassConfigData(quality: AppGlassQuality.liquid),
            child: Column(
              children: [
                AppGlassButton(
                  label: 'Continue',
                  onPressed: () => buttonHits++,
                ),
                const SizedBox(height: 16),
                AppGlassDropZone(
                  onTap: () => dropZoneHits++,
                  child: const SizedBox(height: 60, child: Center(child: Text('Pick files'))),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Pointer taps
    await tester.tap(find.text('Continue'));
    await tester.tap(find.text('Pick files'));
    await tester.pump();
    expect(buttonHits, 1);
    expect(dropZoneHits, 1);

    // Keyboard navigation & Enter/Space activation
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(buttonHits, 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(dropZoneHits, 2);
  });

  testWidgets('DropitAppBar matches preferredSize and respects PopScope via maybePop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      const appBar = DropitAppBar(title: Text('Details'));
      var blockedPopAttempts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PopScope(
                      canPop: false,
                      onPopInvokedWithResult: (didPop, _) {
                        if (!didPop) blockedPopAttempts++;
                      },
                      child: const Scaffold(
                        appBar: appBar,
                        body: SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                child: const Text('Push'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Push'));
      await tester.pumpAndSettle();

      final renderedSize = tester.getSize(find.byType(DropitAppBar));
      expect(renderedSize.height, appBar.preferredSize.height);

      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(blockedPopAttempts, 1);
      expect(find.text('Details'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('VerifyPage renders AppGlassSegmented instead of Material SegmentedButton', (tester) async {
    final persistence = _buildMockPersistence();
    await tester.pumpWidget(
      RefenaScope(
        overrides: [
          persistenceProvider.overrideWithValue(persistence),
        ],
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
    expect(find.byType(AppGlassSegmented), findsOneWidget);
    expect(find.byType(SegmentedButton<VerifyMode>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testDesktopWidgets('Light theme divider and contrast tokens and macOS DropitBackdrop veil behave properly', (tester) async {
    final lightTheme = MornyeTheme.build(Brightness.light);
    expect(lightTheme.dividerTheme.color, isNot(const Color(0xff38383a)));
    expect(lightTheme.colorScheme.onSurfaceVariant.computeLuminance(), lessThan(0.15));

    MacosNativeGlass.debugSupportedOverride = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: const DropitBackdrop(
          child: SizedBox(width: 200, height: 200),
        ),
      ),
    );
    final veilFinder = find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == const Color(0x3AF4F7FF),
    );
    expect(veilFinder, findsOneWidget);
  });

  testWidgets('AppGlassPress skips transform under animateMotion: false and AppLiquidGlass handles flat quality', (tester) async {
    const childKey = ValueKey('motion-off');
    await tester.pumpWidget(
      MaterialApp(
        home: AppGlassConfigScope(
          config: const AppGlassConfigData(quality: AppGlassQuality.flat, reduceMotion: true),
          child: Scaffold(
            body: Center(
              child: AppGlassPress(
                radius: 16,
                child: AppLiquidGlass(
                  key: childKey,
                  radius: 16,
                  child: const SizedBox(width: 80, height: 40),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final press = await tester.startGesture(tester.getCenter(find.byKey(childKey)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final transforms = find.ancestor(
      of: find.byKey(childKey),
      matching: find.byWidgetPredicate((w) => w is Transform && !w.transformHitTests),
    );
    expect(transforms, findsNothing);
    await press.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('DropitHeading floats without an enclosing DecoratedBox panel on macOS Send and Receive', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      MacosNativeGlass.debugSupportedOverride = true;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                DropitHeading(
                  title: 'Send',
                  description: 'Select files and choose a nearby device to share.',
                ),
                DropitHeading(
                  title: 'Receive',
                  description: 'Visible to devices on the same Wi-Fi network.',
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(DropitHeading),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
      final sendTitle = tester.widget<Text>(find.text('Send'));
      expect(sendTitle.style?.shadows, isNotNull);
      expect(sendTitle.style!.shadows!.length, greaterThanOrEqualTo(2));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testDesktopWidgets('Floating optical lenses use clear native style in liquid mode and stronger shader IOR', (tester) async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final setCalls = <Map<String, Object?>?>[];
    messenger.setMockMethodCallHandler(MacosNativeGlass.channel, (call) async {
      if (call.method == 'setSurface') {
        setCalls.add((call.arguments as Map?)?.cast<String, Object?>());
      }
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(MacosNativeGlass.channel, null));

    MacosNativeGlass.debugSupportedOverride = true;
    Widget buildPanel(AppGlassQuality quality) => MaterialApp(
      home: AppGlassConfigScope(
        config: AppGlassConfigData(quality: quality, clarity: 0.75, refractionIntensity: 1.0),
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: EdgeInsets.all(20),
            child: AppGlassPanel(
              child: SizedBox(width: 240, height: 120),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildPanel(AppGlassQuality.liquid));
    await tester.pump();
    expect(setCalls.last?['clear'], isTrue);

    await tester.pumpWidget(buildPanel(AppGlassQuality.frosted));
    await tester.pump();
    expect(setCalls.last?['clear'], isFalse);

    MacosNativeGlass.debugSupportedOverride = false;
    AppLiquidGlass.debugShaderFilterSupport = true;
    addTearDown(() => AppLiquidGlass.debugShaderFilterSupport = null);

    await tester.pumpWidget(buildPanel(AppGlassQuality.liquid));
    await tester.pump();
    final lens = tester.widget<LiquidGlassLens>(find.byType(LiquidGlassLens));
    expect(lens.style.refractionIndex, greaterThan(1.08));
    expect(lens.style.refractionWidth, 44.0);
    expect(lens.style.blur, lessThanOrEqualTo(1.5));
  });

  testDesktopWidgets('Hover resets on focus loss, disabled transitions, and non-interactive DropZone', (tester) async {
    Widget buildControls({required bool buttonEnabled, VoidCallback? dropTap}) => MaterialApp(
      home: AppGlassConfigScope(
        config: const AppGlassConfigData(quality: AppGlassQuality.liquid),
        child: Scaffold(
          body: Column(
            children: [
              AppGlassDropZone(
                onTap: dropTap,
                child: const Text('Drop Zone Content'),
              ),
              AppGlassButton(
                variant: AppGlassButtonVariant.glass,
                label: 'Send',
                onPressed: buttonEnabled ? () {} : null,
              ),
            ],
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    // 1. Non-interactive DropZone (onTap == null) must NOT show 'Drop ready' on hover.
    await tester.pumpWidget(buildControls(buttonEnabled: false, dropTap: null));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.text('Drop Zone Content')));
    await tester.pumpAndSettle();
    expect(find.text('Drop ready'), findsNothing);

    // Disabled button must NOT enter hover press level > 0.
    await mouse.moveTo(tester.getCenter(find.text('Send')));
    await tester.pumpAndSettle();
    final pressStateDisabled = tester.state<AppGlassPressState>(
      find.ancestor(of: find.text('Send'), matching: find.byType(AppGlassPress)),
    );
    expect(pressStateDisabled.hovered, isFalse);

    // 2. Interactive DropZone + enabled button respond to hover, then clear on focus loss & disable.
    await tester.pumpWidget(buildControls(buttonEnabled: true, dropTap: () {}));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.text('Drop Zone Content')));
    await tester.pumpAndSettle();
    expect(find.text('Drop ready'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('Drop ready'), findsNothing);

    await mouse.moveTo(tester.getCenter(find.text('Send')));
    await tester.pumpAndSettle();
    final pressStateEnabled = tester.state<AppGlassPressState>(
      find.ancestor(of: find.text('Send'), matching: find.byType(AppGlassPress)),
    );
    expect(pressStateEnabled.hovered, isTrue);

    await tester.pumpWidget(buildControls(buttonEnabled: false, dropTap: null));
    await tester.pumpAndSettle();
    expect(pressStateEnabled.hovered, isFalse);
  });
}

// These assertions cover desktop-native surfaces and pointer hover, not the
// Android renderer that is Flutter tests' default platform.
void testDesktopWidgets(String name, WidgetTesterCallback callback) {
  testWidgets(name, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await callback(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
