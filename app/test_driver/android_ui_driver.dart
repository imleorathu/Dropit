import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test_driver_extended.dart';

final navigationPixels = <String, Map<String, int>>{};

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final file = File('../../docs/dropit-verification/android-ui/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
  responseDataCallback: (data) async {
    final file = File('../../docs/dropit-verification/android-ui/icon-report.json');
    await file.parent.create(recursive: true);
    final report = {...?data};
    for (final entry in (data?['navigation_specs'] as Map? ?? {}).entries) {
      final image = img.decodePng(await File('../../docs/dropit-verification/android-ui/${entry.key}.png').readAsBytes())!;
      final counts = <String, int>{};
      for (final icon in (entry.value as Map).entries) {
        final spec = icon.value as Map;
        final rect = spec['rect'] as List;
        final color = spec['color'] as List;
        var count = 0;
        for (var y = (rect[1] as num).floor(); y < (rect[3] as num).ceil(); y++) {
          for (var x = (rect[0] as num).floor(); x < (rect[2] as num).ceil(); x++) {
            final pixel = image.getPixel(x, y);
            if ((pixel.r - (color[0] as num)).abs() < 45 && (pixel.g - (color[1] as num)).abs() < 45 && (pixel.b - (color[2] as num)).abs() < 45) {
              count++;
            }
          }
        }
        counts[icon.key as String] = count;
      }
      navigationPixels[entry.key as String] = counts;
    }
    report['navigation_pixels'] = navigationPixels;
    report['screenshots'] = [for (final screenshot in (data?['screenshots'] as List? ?? [])) screenshot['screenshotName']];
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    if (navigationPixels.values.any((counts) => counts.values.any((count) => count < 16))) {
      throw StateError('Blank navigation icon: $navigationPixels');
    }
  },
  writeResponseOnFailure: true,
);
