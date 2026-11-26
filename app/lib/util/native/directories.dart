import 'dart:io' show Directory, Platform;

import 'package:dropit_app/util/native/channel/android_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path;

Future<String> getDefaultDestinationDirectory() async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return await getDownloadsDirectoryAndroid() ?? '/storage/emulated/0/Download';
    case TargetPlatform.iOS:
      return (await path.getApplicationDocumentsDirectory()).path;
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.fuchsia:
      var downloadDir = await path.getDownloadsDirectory();
      if (downloadDir == null) {
        if (defaultTargetPlatform == TargetPlatform.windows) {
          downloadDir = Directory('${Platform.environment['HOMEPATH']}/Downloads');
          if (!downloadDir.existsSync()) {
            downloadDir = Directory(Platform.environment['HOMEPATH']!);
          }
        } else {
          downloadDir = Directory('${Platform.environment['HOME']}/Downloads');
          if (!downloadDir.existsSync()) {
            downloadDir = Directory(Platform.environment['HOME']!);
          }
        }
      }
      final rawPath = downloadDir.path.replaceAll('\\', '/');
      final dropitDir = Directory('$rawPath/Dropit');
      if (!dropitDir.existsSync()) {
        try {
          dropitDir.createSync(recursive: true);
        } catch (_) {}
      }
      return dropitDir.existsSync() ? dropitDir.path.replaceAll('\\', '/') : rawPath;
  }
}

Future<String> getCacheDirectory() async {
  final dir = await path.getTemporaryDirectory();
  await dir.create(recursive: true);
  return dir.path;
}
