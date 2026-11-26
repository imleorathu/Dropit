import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Exports the supplied Dropit PNG across all launcher, tray, share-extension, and web targets.
final app = File(Platform.script.toFilePath()).parent.parent;

img.Image resized(img.Image image, int size) => img.copyResize(image, width: size, height: size, interpolation: img.Interpolation.cubic);

/// Crops to the glass squircle bounds in the master artwork and masks out the outer studio canvas corners.
img.Image extractGlassTile(img.Image source, {bool maskCorners = true}) {
  final cropX = (source.width * 18 / 1024).round();
  final cropY = (source.height * 21 / 1024).round();
  final cropSize = (source.width * 974 / 1024).round();
  final cropped = img.copyCrop(source, x: cropX, y: cropY, width: cropSize, height: cropSize);
  final rgba = resized(cropped, 1024).convert(numChannels: 4);
  if (!maskCorners) {
    return rgba;
  }
  const size = 1024.0;
  const radius = 266.0;
  const left = radius;
  const right = size - 1 - radius;
  const top = radius;
  const bottom = size - 1 - radius;
  for (final pixel in rgba) {
    final x = pixel.x.toDouble();
    final y = pixel.y.toDouble();
    final dx = x < left ? left - x : (x > right ? x - right : 0.0);
    final dy = y < top ? top - y : (y > bottom ? y - bottom : 0.0);
    if (dx > 0 && dy > 0) {
      final dist = math.sqrt(dx * dx + dy * dy);
      final alpha = (radius + 1.0 - dist).clamp(0.0, 1.0);
      pixel.a = (pixel.a * alpha).round();
    }
  }
  return rgba;
}

void png(img.Image image, String relative, int size, {bool opaque = false}) {
  final target = File('${app.path}/$relative')..parent.createSync(recursive: true);
  final result = resized(image, size);
  target.writeAsBytesSync(img.encodePng(opaque ? result.convert(numChannels: 3) : result));
}

img.Image padded(img.Image image, int size, double fraction) {
  final result = img.Image(width: size, height: size, numChannels: 4);
  final content = resized(image, (size * fraction).round());
  img.compositeImage(result, content, dstX: (size - content.width) ~/ 2, dstY: (size - content.height) ~/ 2);
  return result;
}

img.Image silhouette(img.Image source, {bool white = true}) {
  final mask = img.Image(width: source.width, height: source.height, numChannels: 4);
  for (final pixel in source) {
    final x = pixel.x / source.width;
    final y = pixel.y / source.height;
    final dx = x - .5;
    final dy = y - .515;
    if (x < .12 || x > .88 || y < .26 || y > .90 || dx * dx + dy * dy > .37 * .37) continue;
    final channels = [pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble()]..sort();
    final alpha = ((110 - channels.last) / 35).clamp(0.0, 1.0) * pixel.a / 255;
    if (channels.last - channels.first > 48) continue;
    final value = white ? 255 : 0;
    mask.setPixelRgba(pixel.x, pixel.y, value, value, value, (alpha * 255).round());
  }
  final cropped = img.copyCrop(
    mask,
    x: (source.width * .12).round(),
    y: (source.height * .26).round(),
    width: (source.width * .76).round(),
    height: (source.height * .64).round(),
  );
  final symbol = img.copyResize(cropped, width: 512, height: 431, interpolation: img.Interpolation.cubic);
  final result = img.Image(width: 512, height: 512, numChannels: 4);
  img.compositeImage(result, symbol, dstY: 40);
  return result;
}

/// The macOS canvas contains its own rounded tile and transparent outer margin.
/// Fit that entire canvas into Android's 72dp viewport on a 108dp adaptive layer,
/// so circular/squircle launcher masks retain the same artwork and proportions.
void exportAndroidIcons(img.Image macIcon, img.Image mono) {
  for (final entry in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.entries) {
    final folder = 'android/app/src/main/res/mipmap-${entry.key}';
    png(macIcon, '$folder/ic_launcher.png', entry.value);
    png(macIcon, '$folder/ic_launcher_round.png', entry.value);
    final adaptiveSize = (entry.value * 108 / 48).round();
    png(padded(macIcon, 648, 2 / 3), '$folder/ic_launcher_foreground.png', adaptiveSize);
    png(padded(mono, 512, .62), '$folder/ic_launcher_monochrome.png', adaptiveSize);
    png(padded(mono, 512, .72), '$folder/ic_launcher_quicktile_foreground.png', adaptiveSize);
  }
  png(macIcon, 'android/app/src/main/ic_launcher-playstore.png', 512);
}

void main(List<String> args) {
  if (args.contains('--android-only')) {
    final icon = img.decodePng(File('${app.path}/macos/Runner/Assets.xcassets/AppIcon.appiconset/logo-1024-mac-1024.png').readAsBytesSync());
    if (icon == null || icon.width != icon.height) throw StateError('A square macOS icon is required.');
    exportAndroidIcons(icon, silhouette(icon));
    stdout.writeln('Exported Android launcher icons from the current macOS icon.');
    return;
  }
  final master = File('${app.path}/assets/img/dropit-icon.png');
  final source = img.decodePng(master.readAsBytesSync());
  if (source == null || source.width != source.height) throw StateError('A square Dropit master PNG is required.');
  // Keep the original full-resolution asset byte-for-byte.
  master.copySync('${app.path}/assets/img/dropit-1024.png');

  final tile = extractGlassTile(source, maskCorners: true);
  final iosTile = extractGlassTile(source, maskCorners: false);
  final macIcon = padded(tile, 1024, .824);

  for (final n in [32, 128, 256, 512]) {
    png(tile, 'assets/img/logo-$n.png', n);
  }
  final mono = silhouette(source);
  final black = silhouette(source, white: false);
  png(mono, 'assets/img/logo-32-white.png', 32);
  png(black, 'assets/img/logo-32-black.png', 32);
  png(mono, 'assets/img/logo-512-white.png', 512);

  for (final platform in ['ios', 'macos']) {
    final folder = '$platform/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents = jsonDecode(File('${app.path}/$folder/Contents.json').readAsStringSync()) as Map<String, dynamic>;
    final baseImage = platform == 'ios' ? iosTile : macIcon;
    for (final entry in contents['images'] as List) {
      if (entry['filename'] == null) continue;
      final size = (double.parse((entry['size'] as String).split('x').first) * double.parse((entry['scale'] as String).replaceAll('x', ''))).round();
      png(baseImage, '$folder/${entry['filename']}', size, opaque: platform == 'ios');
    }
  }
  final res = '${app.path}/android/app/src/main/res';
  exportAndroidIcons(macIcon, silhouette(macIcon));
  for (final scale in [1, 2, 3]) {
    png(tile, 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage${scale == 1 ? '' : '@${scale}x'}.png', 168 * scale);
  }
  png(black, 'macos/Runner/Assets.xcassets/StatusBarItemIcon.imageset/logo-32-black.png', 32);
  for (final success in [true, false]) {
    final badge = resized(macIcon, 256).convert(numChannels: 4);
    img.fillCircle(badge, x: 206, y: 206, radius: 40, color: img.ColorRgba8(255, 255, 255, 255), antialias: true);
    img.fillCircle(
      badge,
      x: 206,
      y: 206,
      radius: 34,
      color: success ? img.ColorRgba8(36, 132, 86, 255) : img.ColorRgba8(205, 55, 68, 255),
      antialias: true,
    );
    final white = img.ColorRgba8(255, 255, 255, 255);
    if (success) {
      img.drawLine(badge, x1: 185, y1: 206, x2: 201, y2: 221, thickness: 6, color: white, antialias: true);
      img.drawLine(badge, x1: 201, y1: 221, x2: 227, y2: 191, thickness: 6, color: white, antialias: true);
    } else {
      img.drawLine(badge, x1: 194, y1: 193, x2: 219, y2: 218, thickness: 6, color: white, antialias: true);
      img.drawLine(badge, x1: 219, y1: 193, x2: 194, y2: 218, thickness: 6, color: white, antialias: true);
    }
    png(badge, 'macos/Runner/Assets.xcassets/AppIconWith${success ? 'Success' : 'Error'}Mark.imageset/logo-1024-mac-256.png', 256);
  }
  final banner = img.Image(width: 640, height: 360, numChannels: 4);
  img.fill(banner, color: img.ColorRgba8(243, 246, 252, 255));
  img.compositeImage(banner, resized(tile, 170), dstX: 235, dstY: 35);
  img.drawString(banner, 'Dropit', font: img.arial48, y: 237, color: img.ColorRgba8(23, 31, 48, 255));
  File('$res/drawable/banner.png').writeAsBytesSync(img.encodePng(banner.convert(numChannels: 3)));
  final ico = img.IcoEncoder().encodeImages([
    for (final size in [16, 24, 32, 48, 64, 128, 256]) resized(tile, size),
  ]);
  for (final file in ['assets/img/logo.ico', 'assets/packaging/logo.ico', 'windows/runner/resources/app_icon.ico']) {
    File('${app.path}/$file').writeAsBytesSync(ico);
  }
  for (final file in Directory('${app.path}/web/icons').listSync().whereType<File>()) {
    if (file.path.endsWith('.png')) png(tile, 'web/icons/${file.uri.pathSegments.last}', file.path.contains('512') ? 512 : 192);
  }
  png(tile, 'web/favicon.png', 32);

  // iconutil writes the standard multi-resolution macOS share-extension icon.
  if (Platform.isMacOS) {
    final temp = Directory.systemTemp.createTempSync('dropit-icon-');
    final iconset = Directory('${temp.path}/Dropit.iconset')..createSync();
    for (final size in [16, 32, 128, 256, 512]) {
      for (final scale in [1, 2]) {
        File('${iconset.path}/icon_${size}x$size${scale == 2 ? '@2x' : ''}.png').writeAsBytesSync(img.encodePng(resized(macIcon, size * scale)));
      }
    }
    final result = Process.runSync('iconutil', ['-c', 'icns', '-o', '${app.path}/macos/ShareExtension/icon.icns', iconset.path]);
    if (result.exitCode != 0) throw StateError(result.stderr.toString());
    temp.deleteSync(recursive: true);
  }
  stdout.writeln('Exported supplied Dropit artwork for all launchers, tray, share extensions, and launch screens.');
}
