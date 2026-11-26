import 'dart:ui' as ui;

import 'package:dropit_app/config/theme.dart';
import 'package:dropit_app/main.dart' as app;
import 'package:dropit_app/model/persistence/color_mode.dart';
import 'package:dropit_app/model/persistence/glass_quality.dart';
import 'package:dropit_app/pages/home_page.dart';
import 'package:dropit_app/provider/settings_provider.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_glass_config.dart';
import 'package:dropit_app/widget/mornye/app_glass_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:refena_flutter/refena_flutter.dart';

const icons = <String, IconData>{
  'add_rounded': Symbols.add_rounded,
  'arrow_back_rounded': Symbols.arrow_back_rounded,
  'close_rounded': Symbols.close_rounded,
  'cloud_upload_rounded': Symbols.cloud_upload_rounded,
  'content_copy_rounded': Symbols.content_copy_rounded,
  'description_rounded': Symbols.description_rounded,
  'devices_rounded': Symbols.devices_rounded,
  'download_rounded': Symbols.download_rounded,
  'edit_rounded': Symbols.edit_rounded,
  'explore_rounded': Symbols.explore_rounded,
  'file_copy_rounded': Symbols.file_copy_rounded,
  'folder_rounded': Symbols.folder_rounded,
  'fullscreen_rounded': Symbols.fullscreen_rounded,
  'gpp_maybe_rounded': Symbols.gpp_maybe_rounded,
  'help_rounded': Symbols.help_rounded,
  'history_rounded': Symbols.history_rounded,
  'image_rounded': Symbols.image_rounded,
  'info_rounded': Symbols.info_rounded,
  'language_rounded': Symbols.language_rounded,
  'laptop_mac_rounded': Symbols.laptop_mac_rounded,
  'link_rounded': Symbols.link_rounded,
  'move_to_inbox_rounded': Symbols.move_to_inbox_rounded,
  'qr_code_rounded': Symbols.qr_code_rounded,
  'refresh_rounded': Symbols.refresh_rounded,
  'search_rounded': Symbols.search_rounded,
  'send_rounded': Symbols.send_rounded,
  'sensors_rounded': Symbols.sensors_rounded,
  'smartphone_rounded': Symbols.smartphone_rounded,
  'star_rounded': Symbols.star_rounded,
  'tune_rounded': Symbols.tune_rounded,
  'upload_rounded': Symbols.upload_rounded,
  'verified_user_rounded': Symbols.verified_user_rounded,
  'wifi_off_rounded': Symbols.wifi_off_rounded,
  'wifi_tethering_rounded': Symbols.wifi_tethering_rounded,
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> capture(WidgetTester tester, String name, [Map<String, Object?>? args]) async {
    // Capture the engine layer directly. Android PixelCopy has a fixed 500ms
    // timeout that the software-rendered emulator can exceed even for valid UI.
    // ignore: invalid_use_of_protected_member
    final layer = tester.binding.renderViews.first.layer! as OffsetLayer;
    final image = await layer.toImage(Offset.zero & tester.view.physicalSize);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    image.dispose();
    binding.reportData ??= {};
    final screenshots = binding.reportData!.putIfAbsent('screenshots', () => <Object>[]) as List;
    screenshots.add({'screenshotName': name, 'bytes': bytes.buffer.asUint8List()});
    if (args?['navIcons'] != null) {
      final specs = binding.reportData!.putIfAbsent('navigation_specs', () => <String, Object>{}) as Map;
      specs[name] = args!['navIcons'];
    }
  }

  testWidgets('Android production pages retain visible chrome in both themes', (tester) async {
    await app.main([]);
    for (var i = 0; i < 120 && find.byType(HomePage).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byType(HomePage), findsOneWidget);
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final context = tester.element(find.byType(HomePage));
      await context.ref.notifier(settingsProvider).setTheme(brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark);
      await settle(tester);
      expect(Theme.of(tester.element(find.byType(HomePage))).brightness, brightness);
      for (var index = 0; index < 3; index++) {
        final nav = tester.widget<AppGlassNavigation>(find.byType(AppGlassNavigation));
        await tester.tap(find.descendant(of: find.byType(AppGlassNavigation), matching: find.text(nav.items[index].label)));
        await settle(tester);
        expect(tester.widget<AppGlassNavigation>(find.byType(AppGlassNavigation)).activeIndex, index);
        final iconRects = <String, Object>{};
        final ratio = tester.view.devicePixelRatio;
        for (final item in nav.items) {
          final icon = find.descendant(of: find.byType(AppGlassNavigation), matching: find.byIcon(item.icon));
          final rect = tester.getRect(icon);
          final color = IconTheme.of(tester.element(icon)).color!;
          iconRects[item.label] = {
            'rect': [rect.left * ratio, rect.top * ratio, rect.right * ratio, rect.bottom * ratio],
            'color': [color.r * 255, color.g * 255, color.b * 255],
          };
        }
        await capture(tester, 'page-${brightness.name}-$index', {'navIcons': iconRects});
      }
      await tester.tap(find.byIcon(Symbols.help_rounded).first);
      await settle(tester);
      expect(find.text('Connect your devices'), findsOneWidget);
      await capture(tester, 'dialog-${brightness.name}');
      await tester.tap(find.text('Got it'));
      await settle(tester);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('Android icons paint in both themes, inside and outside glass', (tester) async {
    final counts = <String, int>{};
    for (final brightness in Brightness.values) {
      final keys = {for (final name in icons.keys) name: GlobalKey()};
      await tester.pumpWidget(
        MaterialApp(
          theme: getTheme(ColorMode.dropit, Colors.blue, brightness, null),
          home: AppGlassConfigScope(
            config: const AppGlassConfigData(quality: AppGlassQuality.frosted, reduceMotion: true),
            child: Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    Wrap(
                      children: [
                        for (final entry in icons.entries)
                          SizedBox(
                            width: 62,
                            height: 58,
                            child: Column(
                              children: [
                                RepaintBoundary(key: keys[entry.key], child: Icon(entry.value, size: 32)),
                                Text(entry.key.replaceAll('_rounded', ''), maxLines: 1, style: const TextStyle(fontSize: 7)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        AppGlassButton(icon: Symbols.refresh_rounded, onPressed: () {}),
                        AppGlassButton(icon: Symbols.help_rounded, onPressed: () {}),
                        AppGlassButton(icon: Symbols.explore_rounded, onPressed: () {}),
                      ],
                    ),
                    AppGlassNavigation(
                      items: const [
                        AppGlassNavItem(label: 'Send', icon: Symbols.send_rounded),
                        AppGlassNavItem(label: 'Receive', icon: Symbols.move_to_inbox_rounded),
                        AppGlassNavItem(label: 'Settings', icon: Symbols.tune_rounded),
                      ],
                      activeIndex: 0,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      // Capture the exact engine raster output rather than just finding Icon widgets.
      for (final entry in keys.entries) {
        final boundary = entry.value.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        var painted = 0;
        for (var i = 3; i < bytes.lengthInBytes; i += 4) {
          if (bytes.getUint8(i) > 64) painted++;
        }
        counts['${brightness.name}/${entry.key}'] = painted;
        image.dispose();
      }
      await capture(tester, 'icons-${brightness.name}');
    }
    binding.reportData ??= {};
    binding.reportData!['icon_pixels'] = counts;
    final missing = counts.entries.where((entry) => entry.value < 16).map((entry) => entry.key).toList();
    expect(missing, isEmpty, reason: 'Every production symbol must paint visible pixels. Counts: $counts');
    expect(tester.takeException(), isNull);
  });
}
