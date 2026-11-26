import 'dart:async';

import 'package:dropit_app/provider/local_ip_provider.dart';
import 'package:dropit_app/provider/network/server/server_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('LocalWebServerManager');

class LocalWebServerStatus {
  final bool starting;
  final String? lastError;

  const LocalWebServerStatus({
    required this.starting,
    required this.lastError,
  });
}

final localWebServerStatusProvider = NotifierProvider<LocalWebServerStatusService, LocalWebServerStatus>(
  (ref) => LocalWebServerStatusService(),
);

class LocalWebServerStatusService extends Notifier<LocalWebServerStatus> {
  @override
  LocalWebServerStatus init() {
    return const LocalWebServerStatus(starting: false, lastError: null);
  }

  void setStarting() {
    state = const LocalWebServerStatus(starting: true, lastError: null);
  }

  void setRunning() {
    state = const LocalWebServerStatus(starting: false, lastError: null);
  }

  void setError(Object error) {
    state = LocalWebServerStatus(starting: false, lastError: error.toString());
  }
}

final localWebServerManagerProvider = Provider<LocalWebServerManager>((ref) {
  return LocalWebServerManager(ref);
});

/// Central manager for the automatic web server lifecycle.
///
/// Ensures the Dropit HTTP server starts automatically upon application launch,
/// stays running continuously during navigation and minimization, restores itself
/// across network changes and app resumes, and stops gracefully only upon exit.
class LocalWebServerManager with WidgetsBindingObserver {
  final Ref _ref;
  bool _initialized = false;
  bool _starting = false;
  StreamSubscription? _networkSubscription;
  Timer? _healthTimer;

  LocalWebServerManager(this._ref);

  /// Initializes the server lifecycle observer and automatically starts the local web server.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);

    // Start the local HTTP server with browser sharing automatically
    await startAutomaticServer();

    // Listen to network changes (Wi-Fi, hotspot, IP switching) to restore if needed
    _networkSubscription = _ref.stream(localIpProvider).listen((event) {
      final networkState = event.next;
      if (networkState.initialized && networkState.localIps.isNotEmpty) {
        unawaited(restoreServerIfNeeded());
      }
    });

    // A loopback probe catches sockets that were silently invalidated while the
    // app was suspended, even if no lifecycle or network event is delivered.
    _healthTimer = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(restoreServerIfNeeded()));
  }

  /// Starts the server automatically from user settings with Web Upload enabled.
  Future<void> startAutomaticServer() async {
    if (_starting) {
      return;
    }

    final serverState = _ref.read(serverProvider);
    if (serverState != null) {
      _logger.info('Server is already running on port ${serverState.port}.');
      _ref.notifier(localWebServerStatusProvider).setRunning();
      return;
    }

    _starting = true;
    _ref.notifier(localWebServerStatusProvider).setStarting();
    try {
      _logger.info('Starting automatic local web server on launch...');
      await _ref.notifier(serverProvider).startServerFromSettings();
      _ref.notifier(localWebServerStatusProvider).setRunning();
      _logger.info('Local web server running successfully.');
    } catch (e) {
      _logger.warning('Failed to start automatic local web server on launch', e);
      _ref.notifier(localWebServerStatusProvider).setError(e);
    } finally {
      _starting = false;
    }
  }

  /// Checks if the server is running and restores it if it stopped unexpectedly.
  Future<void> restoreServerIfNeeded() async {
    final serverState = _ref.read(serverProvider);
    if (serverState == null) {
      _logger.info('Server was inactive. Automatically restoring local web server...');
      await startAutomaticServer();
    } else {
      await _ref.notifier(serverProvider).ensureRunning();
    }
  }

  /// Gracefully stops the local server.
  Future<void> stopServer() async {
    try {
      _logger.info('Stopping local web server gracefully...');
      await _ref.notifier(serverProvider).stopServer();
    } catch (e) {
      _logger.warning('Error while stopping local web server', e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // When app is brought back to foreground, verify the server is still running
        unawaited(restoreServerIfNeeded());
        break;
      case AppLifecycleState.detached:
        // App is actually terminating; gracefully release sockets
        unawaited(stopServer());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Keep running in background as allowed by the platform
        break;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_networkSubscription?.cancel());
    _networkSubscription = null;
    _healthTimer?.cancel();
    _healthTimer = null;
    _initialized = false;
  }

  bool get isServerRunning => _ref.read(serverProvider) != null;
  int? get activePort => _ref.read(serverProvider)?.port;
  bool get isWebUploadActive => _ref.read(serverProvider)?.webUpload == true;
  bool get isWebSendActive => _ref.read(serverProvider)?.webSendState != null;
}
