import 'dart:io';

import 'package:dropit_app/util/native/platform_check.dart';
import 'package:dropit_isolates/rust/api/server.dart' show WebPages;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final _logger = Logger('WebPagesLoader');

/// Loads custom web pages from the `web` folder next to the executable
/// (e.g. `web/download.html`), so the served pages can be customized without
/// recompiling the app. Pages that are not provided fall back to the assets
/// embedded in the Rust server.
///
/// Returns `null` when no custom page exists (or on mobile platforms where
/// there is no folder next to the executable).
Future<WebPages?> loadCustomWebPages() async {
  if (!checkPlatformIsDesktop()) {
    return null;
  }

  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final candidateDirs = [
    path.join(exeDir, 'web'),
    path.join(exeDir, '..', 'Resources', 'web'),
    path.join(Directory.current.path, 'packages', 'core', 'assets', 'web'),
    path.join(Directory.current.path, '..', 'packages', 'core', 'assets', 'web'),
  ];

  for (final dir in candidateDirs) {
    final downloadHtml = Platform.isMacOS
        ? (await _readOptionalFile(path.join(dir, 'download_macos.html')) ?? await _readOptionalFile(path.join(dir, 'download.html')))
        : await _readOptionalFile(path.join(dir, 'download.html'));
    final uploadHtml = Platform.isMacOS
        ? (await _readOptionalFile(path.join(dir, 'upload_macos.html')) ?? await _readOptionalFile(path.join(dir, 'upload.html')))
        : await _readOptionalFile(path.join(dir, 'upload.html'));
    final browserHtml = Platform.isMacOS
        ? (await _readOptionalFile(path.join(dir, 'browser_macos.html')) ?? await _readOptionalFile(path.join(dir, 'browser.html')))
        : await _readOptionalFile(path.join(dir, 'browser.html'));
    final error403Html = await _readOptionalFile(path.join(dir, 'error-403.html'));

    if (downloadHtml != null || uploadHtml != null || error403Html != null || browserHtml != null) {
      _logger.info('Loaded custom web pages from: $dir');
      return WebPages(
        downloadHtml: downloadHtml,
        uploadHtml: uploadHtml,
        error403Html: error403Html,
        browserHtml: browserHtml,
      );
    }
  }

  return null;
}

Future<String?> _readOptionalFile(String filePath) async {
  final file = File(filePath);
  try {
    if (!await file.exists()) {
      return null;
    }
    return await file.readAsString();
  } catch (e) {
    _logger.warning('Failed to read custom web page: $filePath', e);
    return null;
  }
}
