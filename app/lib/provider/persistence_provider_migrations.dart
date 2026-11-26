part of 'persistence_provider.dart';

const _latestVersion = 4;

Future<void> _runMigrations(int from) async {
  if (from < 2) {
    await _migrate2();
    await SharedPreferencesStorePlatform.instance.setValue('Int', 'flutter.$_version', 2);
  }
  if (from < 3) {
    await _migrate3();
    await SharedPreferencesStorePlatform.instance.setValue('Int', 'flutter.$_version', 3);
  }
  if (from < 4) {
    await _migrate4();
    await SharedPreferencesStorePlatform.instance.setValue('Int', 'flutter.$_version', 4);
  }
}

/// Adopt Dropit's network defaults once, retaining explicitly customized values.
Future<void> _migrate4() async {
  _logger.info('Migrating to version 4 (Dropit network defaults)');
  final store = SharedPreferencesStorePlatform.instance;
  final prefs = await store.getAll();
  if (prefs['flutter.$_portKey'] == 53317) {
    await store.setValue('Int', 'flutter.$_portKey', defaultPort);
  }
  if (prefs['flutter.$_multicastGroupKey'] == '224.0.0.167') {
    await store.setValue('String', 'flutter.$_multicastGroupKey', defaultMulticastGroup);
  }
}

Future<void> _migrate2() async {
  _logger.info('Migrating to version 2');
  if (SharedPreferencesStorePlatform.instance is! SharedPreferencesPortable) {
    await enableContextMenu();

    if (defaultTargetPlatform == TargetPlatform.windows) {
      final newFolder = File(_windowsFile).parent;
      if (!newFolder.existsSync()) {
        newFolder.createSync(recursive: true);
      }

      final legacyFile = File(_windowsLegacyFile);
      legacyFile.copySync(_windowsFile);
      try {
        legacyFile.parent.parent.deleteSync(recursive: true);
      } catch (e) {
        _logger.warning('Failed to delete legacy folder: $e');
      }
      SharedPreferencesStorePlatform.instance = SharedPreferencesFile(filePath: _windowsFile);
    }
  }
}

Future<void> _migrate3() async {
  _logger.info('Migrating to version 3');
  final prefs = await SharedPreferencesStorePlatform.instance.getAll();

  // ls_quick_save becomes a QuickSaveMode: keep "on" if it was enabled, otherwise apply the new default "paired"
  // (which is what ls_quick_save_from_favorites used to do)
  final quickSave = prefs['flutter.$_quickSave'] == true ? QuickSaveMode.on : QuickSaveMode.paired;
  await SharedPreferencesStorePlatform.instance.setValue('String', 'flutter.$_quickSave', quickSave.name);
  await SharedPreferencesStorePlatform.instance.remove('flutter.ls_quick_save_from_favorites');

  // some users disabled HTTPS for performance reasons which no longer apply since the Rust migration
  await SharedPreferencesStorePlatform.instance.setValue('Bool', 'flutter.$_https', true);
}
