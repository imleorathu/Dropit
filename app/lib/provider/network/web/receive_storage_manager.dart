import 'dart:io';

import 'package:dropit_app/provider/settings_provider.dart';
import 'package:dropit_app/util/native/directories.dart';
import 'package:dropit_app/util/native/open_folder.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('ReceiveStorageManager');

final receiveStorageProvider = Provider<ReceiveStorageManager>((ref) {
  return ReceiveStorageManager(ref);
});

/// Manages the receiver storage destination, ensures the directory exists,
/// and handles opening/accessing downloaded files across platforms.
class ReceiveStorageManager {
  final Ref _ref;

  ReceiveStorageManager(this._ref);

  /// Returns the configured destination directory, defaulting to Downloads/Dropit.
  Future<String> getDestinationDirectory() async {
    final customDest = _ref.read(settingsProvider).destination;
    if (customDest != null && customDest.trim().isNotEmpty) {
      return customDest;
    }
    return await getDefaultDestinationDirectory();
  }

  /// Sets a custom destination directory in persistent settings.
  Future<void> setDestinationDirectory(String? path) async {
    await _ref.notifier(settingsProvider).setDestination(path);
  }

  /// Ensures that the destination directory exists on disk.
  Future<Directory> ensureDestinationDirectoryExists() async {
    final dirPath = await getDestinationDirectory();
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (e) {
        _logger.warning('Failed to create destination directory: $dirPath', e);
      }
    }
    return dir;
  }

  /// Opens the destination directory in the native file explorer (Finder, Explorer, Files).
  Future<void> openDestinationFolder() async {
    final dirPath = await getDestinationDirectory();
    await openFolder(folderPath: dirPath);
  }
}
