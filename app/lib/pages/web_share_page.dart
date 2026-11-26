import 'dart:async';

import 'package:dropit_app/model/cross_file.dart';
import 'package:dropit_app/model/state/send/web/web_send_state.dart';
import 'package:dropit_app/model/state/server/browser_session_state.dart';
import 'package:dropit_app/provider/local_ip_provider.dart';
import 'package:dropit_app/provider/network/server/server_provider.dart';
import 'package:dropit_app/provider/network/web/browser_sessions_provider.dart';
import 'package:dropit_app/provider/network/web/browser_sharing_service.dart';
import 'package:dropit_app/provider/network/web/local_web_server_manager.dart';
import 'package:dropit_app/provider/network/web/receive_storage_manager.dart';
import 'package:dropit_app/provider/receive_history_provider.dart';
import 'package:dropit_app/provider/selection/selected_sending_files_provider.dart';
import 'package:dropit_app/provider/settings_provider.dart';
import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/util/native/file_picker.dart';
import 'package:dropit_app/util/native/open_file.dart';
import 'package:dropit_app/util/native/platform_check.dart';
import 'package:dropit_app/util/ui/snackbar.dart';
import 'package:dropit_app/widget/dialogs/pin_dialog.dart';
import 'package:dropit_app/widget/dialogs/qr_dialog.dart';
import 'package:dropit_app/widget/dialogs/zoom_dialog.dart';
import 'package:dropit_app/widget/dropit/dropit_alert_dialog.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/dropit/macos_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_glass_cards.dart';
import 'package:dropit_app/widget/mornye/app_glass_navigation.dart';
import 'package:dropit_app/widget/responsive_list_view.dart';
import 'package:dropit_isolates/rust/api/server.dart' show BrowserDeviceType;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final _logger = Logger('WebSharePage');

/// Browser Sharing Screen supporting two distinct transfer modes:
/// - Mode A: Receive Via Browser (Local HTTP server accepts uploads from browsers on the LAN).
/// - Mode B: Send Via Browser (Offers staged files for browsers on the LAN to download).
///
/// Navigating away or closing this screen maintains continuous background operation.
class WebSharePage extends StatefulWidget {
  final List<CrossFile>? files;

  const WebSharePage({super.key, this.files});

  @override
  State<WebSharePage> createState() => _WebSharePageState();
}

class _WebSharePageState extends State<WebSharePage> with Refena {
  BrowserSharingMode _currentMode = BrowserSharingMode.receive;
  List<CrossFile> _stagedFiles = [];
  bool _isSwitching = false;
  bool _useHttpsLink = false;
  final Set<String> _offeringSessions = {};

  @override
  void initState() {
    super.initState();
    _currentMode = (widget.files != null && widget.files!.isNotEmpty) ? BrowserSharingMode.send : BrowserSharingMode.receive;
    _stagedFiles = widget.files != null ? List.from(widget.files!) : [];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_applyModeState());
    });
  }

  bool get _encrypted => ref.read(serverProvider)?.https ?? ref.read(settingsProvider).https;

  Future<void> _applyModeState() async {
    var serverState = ref.read(serverProvider);
    final settings = ref.read(settingsProvider);

    // If server is not yet running, start it
    if (serverState == null) {
      try {
        await ref.notifier(serverProvider).startServerFromSettings();
        serverState = ref.read(serverProvider);
      } catch (e) {
        _logger.warning('Failed to start the server for browser sharing', e);
        return;
      }
    }

    if (_currentMode == BrowserSharingMode.send && _stagedFiles.isNotEmpty) {
      setState(() => _isSwitching = true);
      try {
        await ref
            .notifier(serverProvider)
            .restartServerWithWebSend(
              alias: settings.alias,
              port: settings.port,
              https: _encrypted,
              files: _stagedFiles,
              webPin: serverState?.webPin ?? settings.receivePin,
            );
      } catch (e) {
        _logger.warning('Failed to start web send with staged files', e);
      } finally {
        if (mounted) setState(() => _isSwitching = false);
      }
    } else if (_currentMode == BrowserSharingMode.receive) {
      if (serverState?.webSendState != null || serverState?.webUpload != true) {
        setState(() => _isSwitching = true);
        try {
          await ref.notifier(serverProvider).switchToWebUploadMode(https: _encrypted);
        } catch (e) {
          _logger.warning('Failed to switch to web upload mode', e);
        } finally {
          if (mounted) setState(() => _isSwitching = false);
        }
      }
    }
  }

  /// Offers the staged files to every browser that is ready to receive them.
  ///
  /// This is called after builds because a browser may connect at any time.
  /// Offers are only created when the browser does not already have an offer
  /// for the same file selection, so rebuilds (and download progress events)
  /// do not spam the browser with duplicate prompts.
  Future<void> _syncBrowserOffers() async {
    if (!mounted || _currentMode != BrowserSharingMode.send || _stagedFiles.isEmpty || _isSwitching) {
      return;
    }

    final sessions = ref.read(browserSessionsProvider);
    for (final session in sessions.sessions.values) {
      if (!session.canReceive || _offeringSessions.contains(session.sessionId)) {
        continue;
      }
      final latest = sessions.latestOfferForSession(session.sessionId);
      if (latest != null && _offerMatchesFiles(latest, _stagedFiles)) {
        continue;
      }
      await _offerToSession(session.sessionId);
    }
  }

  Future<void> _offerToSession(String sessionId, {bool notifyOnError = false}) async {
    if (_offeringSessions.contains(sessionId) || _stagedFiles.isEmpty) {
      return;
    }
    _offeringSessions.add(sessionId);
    try {
      await ref
          .notifier(browserSessionsProvider)
          .offerFiles(
            sessionId: sessionId,
            files: List.of(_stagedFiles),
          );
    } catch (e) {
      _logger.fine('Could not offer files to browser $sessionId', e);
      if (notifyOnError && mounted) {
        context.showSnackBar('Could not send files to this browser');
      }
    } finally {
      _offeringSessions.remove(sessionId);
    }
  }

  bool _offerMatchesFiles(BrowserOffer offer, List<CrossFile> files) {
    if (offer.files.length != files.length) {
      return false;
    }
    final offered = offer.files.values.map((file) => '${file.file.fileName}\u0000${file.file.size}').toList()..sort();
    final staged = files.map((file) => '${file.name}\u0000${file.size}').toList()..sort();
    for (var i = 0; i < offered.length; i++) {
      if (offered[i] != staged[i]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _onSelectMode(BrowserSharingMode mode) async {
    if (_currentMode == mode) return;
    setState(() {
      _currentMode = mode;
    });
    await _applyModeState();
  }

  Future<void> _pickMoreFiles() async {
    final prevCount = ref.read(selectedSendingFilesProvider).length;
    await ref.global.dispatchAsync(PickFileAction(option: FilePickerOption.file, context: context));
    final newFiles = ref.read(selectedSendingFilesProvider);
    if (newFiles.length > prevCount) {
      final added = newFiles.sublist(prevCount);
      setState(() {
        _stagedFiles.addAll(added);
      });
      await _applyModeState();
    }
  }

  Future<void> _pickMoreFolder() async {
    final prevCount = ref.read(selectedSendingFilesProvider).length;
    await ref.global.dispatchAsync(PickFileAction(option: FilePickerOption.folder, context: context));
    final newFiles = ref.read(selectedSendingFilesProvider);
    if (newFiles.length > prevCount) {
      final added = newFiles.sublist(prevCount);
      setState(() {
        _stagedFiles.addAll(added);
      });
      await _applyModeState();
    }
  }

  Future<void> _removeStagedFile(int index) async {
    setState(() {
      _stagedFiles.removeAt(index);
    });
    if (_stagedFiles.isEmpty) {
      await ref.notifier(serverProvider).switchToWebUploadMode(https: _encrypted);
    } else {
      await _applyModeState();
    }
  }

  Future<void> _clearStagedFiles() async {
    setState(() {
      _stagedFiles.clear();
    });
    await ref.notifier(serverProvider).switchToWebUploadMode(https: _encrypted);
  }

  @override
  Widget build(BuildContext context) {
    final serverState = context.watch(serverProvider);
    final networkState = context.watch(localIpProvider);
    final settings = context.watch(settingsProvider);
    final webServerStatus = context.watch(localWebServerStatusProvider);
    final browserSessions = context.watch(browserSessionsProvider);
    final encrypted = serverState?.https ?? _encrypted;
    final theme = Theme.of(context);
    final pin = serverState?.webPin;
    final port = serverState?.port ?? settings.port;
    final browserPort = serverState?.browserPort;
    final linkPort = (_useHttpsLink && browserPort != null) ? browserPort : port;
    final linkEncrypted = _useHttpsLink && (browserPort != null || encrypted);

    if (_currentMode == BrowserSharingMode.send && _stagedFiles.isNotEmpty && !_isSwitching) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncBrowserOffers());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: DropitAppBar(
        title: const Text('Browser sharing'),
      ),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Segmented Pill Mode Selector
          AppGlassSegmented(
            options: [
              AppGlassSegmentOption(
                label: 'Receive via browser',
                icon: usesAndroidMornye ? Symbols.download_rounded : CupertinoIcons.arrow_down_circle_fill,
              ),
              AppGlassSegmentOption(
                label: 'Send via browser',
                icon: usesAndroidMornye ? Symbols.upload_rounded : CupertinoIcons.arrow_up_circle_fill,
              ),
            ],
            value: _currentMode == BrowserSharingMode.receive ? 0 : 1,
            onChanged: (idx) {
              unawaited(_onSelectMode(idx == 0 ? BrowserSharingMode.receive : BrowserSharingMode.send));
            },
          ),
          const SizedBox(height: 16),

          // Server Live Status Card
          DropitPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: serverState != null
                            ? (theme.brightness == Brightness.dark ? const Color(0xFF34D058) : const Color(0xFF0A662A))
                            : (theme.brightness == Brightness.dark ? const Color(0xFFFF9F0A) : const Color(0xFF9A5B00)),
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (serverState != null && !usesAndroidMornye)
                            BoxShadow(
                              color: (theme.brightness == Brightness.dark ? const Color(0xFF34D058) : const Color(0xFF0A662A)).withValues(
                                alpha: 0.45,
                              ),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        serverState != null
                            ? 'Server active • Ready on local Wi-Fi'
                            : (webServerStatus.lastError != null ? 'Server failed to start' : 'Server initializing…'),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Port $port',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _currentMode == BrowserSharingMode.receive
                      ? 'Any device on this Wi-Fi can open the link below in Safari or Chrome to send files to this device.'
                      : 'Any device on this Wi-Fi can open the link below in Safari or Chrome to download the staged files.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (serverState == null && webServerStatus.lastError != null) ...[
            DropitPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(usesAndroidMornye ? Symbols.wifi_off_rounded : CupertinoIcons.wifi_exclamationmark, color: Colors.orange, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'The sharing server could not start',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    webServerStatus.lastError!,
                    style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async => ref.read(localWebServerManagerProvider).startAutomaticServer(),
                      icon: Icon(usesAndroidMornye ? Symbols.refresh_rounded : CupertinoIcons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_isSwitching) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: usesAndroidMornye ? const CircularProgressIndicator() : const CupertinoActivityIndicator(radius: 14),
              ),
            ),
          ] else if (_currentMode == BrowserSharingMode.receive) ...[
            // MODE A: RECEIVE VIA BROWSER
            _buildLinkList(
              context: context,
              ips: networkState.localIps,
              port: linkPort,
              pin: pin,
              encrypted: linkEncrypted,
              theme: theme,
            ),
            if (_useHttpsLink && browserPort != null && networkState.localIps.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildCertificateTrustSection(
                context: context,
                theme: theme,
                ip: networkState.localIps.first,
                port: port,
                scheme: 'http',
              ),
            ],
            const SizedBox(height: 16),
            _buildReceiverStorageSection(context, theme),
            const SizedBox(height: 16),
            _buildPreferencesSection(
              context: context,
              theme: theme,
              webSendState: serverState?.webSendState,
              pin: pin,
              autoAccept: settings.receiveViaLinkAutoAccept,
            ),
          ] else ...[
            // MODE B: SEND VIA BROWSER (NEW)
            _buildSendStagingSection(context, theme),
            const SizedBox(height: 16),
            if (_stagedFiles.isNotEmpty) ...[
              _buildLinkList(
                context: context,
                ips: networkState.localIps,
                port: linkPort,
                pin: pin,
                encrypted: linkEncrypted,
                theme: theme,
              ),
              if (browserPort != null && networkState.localIps.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildCertificateTrustSection(
                  context: context,
                  theme: theme,
                  ip: networkState.localIps.first,
                  port: encrypted ? browserPort : port,
                  scheme: encrypted ? 'https' : 'http',
                ),
              ],
              const SizedBox(height: 16),
              _buildBrowserSessionsSection(
                sessions: browserSessions,
                theme: theme,
              ),
              const SizedBox(height: 16),
            ],
            _buildPreferencesSection(
              context: context,
              theme: theme,
              webSendState: serverState?.webSendState,
              pin: pin,
              autoAccept: serverState?.webSendState?.autoAccept ?? false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkList({
    required BuildContext context,
    required List<String> ips,
    required int port,
    required String? pin,
    required bool encrypted,
    required ThemeData theme,
  }) {
    if (ips.isEmpty) {
      return DropitPanel(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(usesAndroidMornye ? Symbols.wifi_off_rounded : CupertinoIcons.wifi_exclamationmark, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No local Wi-Fi or hotspot connection detected. Connect to Wi-Fi to share via browser.',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    return DropitPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(usesAndroidMornye ? Symbols.link_rounded : CupertinoIcons.link, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Open in web browser (${ips.length} ${ips.length == 1 ? 'address' : 'addresses'})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...ips.map((ip) {
            final url = '${encrypted ? 'https' : 'http'}://$ip:$port';
            final urlWithPin = pin != null ? '$url/?pin=${Uri.encodeQueryComponent(pin)}' : url;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      url,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: Icon(usesAndroidMornye ? Symbols.content_copy_rounded : CupertinoIcons.doc_on_doc, size: 18),
                    tooltip: 'Copy link',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: urlWithPin));
                      if (context.mounted) {
                        context.showSnackBar('Link copied to clipboard');
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(usesAndroidMornye ? Symbols.qr_code_rounded : CupertinoIcons.qrcode, size: 20),
                    tooltip: 'Show QR Code',
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (_) => QrDialog(
                          data: urlWithPin,
                          label: url,
                          listenIncomingWebSendRequests: _currentMode == BrowserSharingMode.send,
                          pin: pin,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(usesAndroidMornye ? Symbols.fullscreen_rounded : CupertinoIcons.tv, size: 19),
                    tooltip: 'Full Screen View',
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (_) => ZoomDialog(
                          label: url,
                          listenIncomingWebSendRequests: _currentMode == BrowserSharingMode.send,
                          pin: pin,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCertificateTrustSection({
    required BuildContext context,
    required ThemeData theme,
    required String ip,
    required int port,
    required String scheme,
  }) {
    return DropitPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(usesAndroidMornye ? Symbols.verified_user_rounded : CupertinoIcons.checkmark_shield, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Browser security warning',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The connection is encrypted with a certificate created by this device. '
            'Browsers warn until that certificate is trusted once.',
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              AppGlassButton(
                variant: AppGlassButtonVariant.tinted,
                size: AppGlassButtonSize.sm,
                icon: usesAndroidMornye ? Symbols.download_rounded : CupertinoIcons.arrow_down_doc,
                label: 'Download certificate',
                onPressed: () => _downloadCertificate(context, ip: ip, port: port, scheme: scheme),
              ),
              AppGlassButton(
                variant: AppGlassButtonVariant.clear,
                size: AppGlassButtonSize.sm,
                label: 'How to install',
                onPressed: () => _showCertificateInstructions(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadCertificate(BuildContext context, {required String ip, required int port, required String scheme}) async {
    final url = Uri.parse('$scheme://$ip:$port/dropit-ca.crt');
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      context.showSnackBar('Could not open the certificate link');
    }
  }

  void _showCertificateInstructions(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => DropitAlertDialog(
          title: const Text('Trust the certificate'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. Download the certificate on the device where the browser runs.'),
                Text('If the browser shows the security warning instead, choose "Advanced" and proceed once to reach the download.'),
                SizedBox(height: 10),
                Text('2. Install it as a trusted root:'),
                SizedBox(height: 6),
                Text(
                  '• macOS: open it in Keychain Access, add it to the login or System keychain, then set "When using this certificate" to "Always Trust".',
                ),
                Text('• Windows: open it and choose "Install Certificate" > "Local Machine" > "Trusted Root Certification Authorities".'),
                Text('• iPhone/iPad: install the profile in Settings, then enable it under General > About > Certificate Trust Settings.'),
                Text('• Android: install it as a "CA certificate" under Security > Encryption & credentials.'),
                SizedBox(height: 10),
                Text('3. Reload the browser page. The warning disappears and the lock icon appears.'),
                SizedBox(height: 10),
                Text('Only install this certificate if you trust this device on your local network.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendStagingSection(BuildContext context, ThemeData theme) {
    return DropitPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Files to share (${_stagedFiles.length})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ),
              if (_stagedFiles.isNotEmpty)
                TextButton(
                  onPressed: _clearStagedFiles,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Clear all', style: TextStyle(fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_stagedFiles.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3), width: 1.5),
                borderRadius: BorderRadius.circular(18),
                color: theme.colorScheme.primary.withValues(alpha: 0.04),
              ),
              child: Column(
                children: [
                  Icon(usesAndroidMornye ? Symbols.cloud_upload_rounded : CupertinoIcons.cloud_upload, size: 44, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'Select files or folders to share',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Browsers on this network can download them directly.',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      AppGlassButton(
                        variant: AppGlassButtonVariant.filled,
                        size: AppGlassButtonSize.md,
                        icon: usesAndroidMornye ? Symbols.description_rounded : CupertinoIcons.doc,
                        label: 'Add files',
                        onPressed: _pickMoreFiles,
                      ),
                      if (checkPlatform([TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux]))
                        AppGlassButton(
                          variant: AppGlassButtonVariant.glass,
                          size: AppGlassButtonSize.md,
                          icon: CupertinoIcons.folder,
                          label: 'Add folder',
                          onPressed: _pickMoreFolder,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                AppGlassButton(
                  variant: AppGlassButtonVariant.glass,
                  size: AppGlassButtonSize.sm,
                  icon: usesAndroidMornye ? Symbols.add_rounded : CupertinoIcons.plus,
                  label: 'Add more files',
                  onPressed: _pickMoreFiles,
                ),
                if (checkPlatform([TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux]))
                  AppGlassButton(
                    variant: AppGlassButtonVariant.glass,
                    size: AppGlassButtonSize.sm,
                    icon: CupertinoIcons.folder_badge_plus,
                    label: 'Add folder',
                    onPressed: _pickMoreFolder,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _stagedFiles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final file = _stagedFiles[index];
                  return AppGlassFileCard(
                    thumbnail: DropitTile(
                      size: 42,
                      radius: 12,
                      child: Icon(usesAndroidMornye ? Symbols.description_rounded : CupertinoIcons.doc_fill, size: 20),
                    ),
                    title: file.name,
                    subtitle: formatBytes(file.size),
                    trailing: IconButton(
                      icon: Icon(usesAndroidMornye ? Symbols.close_rounded : CupertinoIcons.xmark_circle, size: 18),
                      onPressed: () => _removeStagedFile(index),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBrowserSessionsSection({
    required BrowserSessionsState sessions,
    required ThemeData theme,
  }) {
    final browsers = sessions.sessions.values.toList()
      ..sort((a, b) {
        if (a.canReceive != b.canReceive) {
          return a.canReceive ? -1 : 1;
        }
        return a.browserName.toLowerCase().compareTo(b.browserName.toLowerCase());
      });

    return DropitPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(usesAndroidMornye ? Symbols.sensors_rounded : CupertinoIcons.waveform_path, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Browsers on this network (${browsers.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (browsers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Waiting for a browser to connect… Files are offered automatically when one is ready.',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            ...browsers.map((session) => _buildBrowserSessionTile(session, sessions, theme)),
        ],
      ),
    );
  }

  Widget _buildBrowserSessionTile(BrowserSession session, BrowserSessionsState sessions, ThemeData theme) {
    final offer = sessions.latestOfferForSession(session.sessionId);
    final (statusLabel, statusColor) = _browserStatus(session, offer);
    final canRetry = session.canReceive && (offer == null || offer.isTerminal);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            session.deviceType == BrowserDeviceType.desktop
                ? (usesAndroidMornye ? Symbols.laptop_mac_rounded : CupertinoIcons.device_laptop)
                : (usesAndroidMornye ? Symbols.smartphone_rounded : CupertinoIcons.device_phone_portrait),
            size: 22,
            color: statusColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.browserName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                Text(
                  session.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
              if (canRetry)
                TextButton(
                  onPressed: () => _offerToSession(session.sessionId, notifyOnError: true),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    offer == null ? 'Send' : 'Send again',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  (String, Color) _browserStatus(BrowserSession session, BrowserOffer? offer) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final green = dark ? const Color(0xFF34D058) : const Color(0xFF0A662A);
    final orange = dark ? const Color(0xFFFF9F0A) : const Color(0xFF9A5B00);
    final red = dark ? const Color(0xFFFF453A) : const Color(0xFFB3261E);
    final isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
    final muted = dark ? (isMacOS ? Colors.white : const Color(0xFF98989F)) : const Color(0xFF4C4C52);

    if (!session.connected) {
      return ('Offline', muted);
    }
    if (!session.ready) {
      return ('Connecting…', orange);
    }
    if (offer == null) {
      return ('Ready', Theme.of(context).colorScheme.primary);
    }
    return switch (offer.status) {
      BrowserOfferStatus.pending => ('Awaiting accept', orange),
      BrowserOfferStatus.accepted => ('Accepted', green),
      BrowserOfferStatus.downloading => ('${(offer.progress * 100).round()}%', green),
      BrowserOfferStatus.completed => ('Done', green),
      BrowserOfferStatus.declined => ('Declined', red),
      BrowserOfferStatus.cancelled => ('Cancelled', muted),
      BrowserOfferStatus.failed => ('Failed', red),
    };
  }

  Widget _buildReceiverStorageSection(BuildContext context, ThemeData theme) {
    final storageManager = ref.read(receiveStorageProvider);
    final history = context.watch(receiveHistoryProvider);

    return DropitPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(usesAndroidMornye ? Symbols.folder_rounded : CupertinoIcons.folder, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Incoming files destination',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async => storageManager.openDestinationFolder(),
                child: const Text('Open folder', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FutureBuilder<String>(
            future: storageManager.getDestinationDirectory(),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? 'Downloads/Dropit',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              );
            },
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent downloads (${history.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            ...history.take(3).map((item) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(usesAndroidMornye ? Symbols.description_rounded : CupertinoIcons.doc, size: 20),
                title: Text(item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(formatBytes(item.fileSize)),
                onTap: item.path != null ? () => openFile(context, item.fileType, item.path!) : null,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferencesSection({
    required BuildContext context,
    required ThemeData theme,
    required WebSendState? webSendState,
    required String? pin,
    required bool autoAccept,
  }) {
    Future<void> toggleAutoAccept(bool val) async {
      if (webSendState != null) {
        ref.notifier(serverProvider).setWebSendAutoAccept(val);
      } else {
        await ref.notifier(settingsProvider).setReceiveViaLinkAutoAccept(val);
      }
    }

    Future<void> togglePin(bool val) async {
      if (pin != null) {
        await ref.notifier(serverProvider).setWebPin(null);
      } else {
        final String? newPin = await showDialog<String>(
          context: context,
          builder: (_) => const PinDialog(
            obscureText: false,
            generateRandom: true,
          ),
        );
        if (newPin != null && newPin.isNotEmpty) {
          await ref.notifier(serverProvider).setWebPin(newPin);
        }
      }
    }

    return DropitPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Security & preferences', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          _GlassPreferenceRow(
            title: 'Auto-accept files',
            subtitle: 'Automatically save authorized incoming files',
            checked: autoAccept,
            onChange: toggleAutoAccept,
          ),
          const SizedBox(height: 10),
          _GlassPreferenceRow(
            title: 'Require PIN',
            subtitle: pin != null ? 'Active PIN: $pin' : 'Protect browser access with a passcode',
            subtitleColor: pin != null ? theme.colorScheme.primary : null,
            checked: pin != null,
            onChange: togglePin,
          ),
          const SizedBox(height: 10),
          _GlassPreferenceRow(
            title: 'HTTPS encrypted link',
            subtitle: 'Requires trusting the local certificate in your browser',
            checked: _useHttpsLink,
            onChange: (val) => setState(() => _useHttpsLink = val),
          ),
        ],
      ),
    );
  }
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  double size = bytes.toDouble();
  while (size >= 1024 && i < suffixes.length - 1) {
    size /= 1024;
    i++;
  }
  return '${size.toStringAsFixed(1)} ${suffixes[i]}';
}

class _GlassPreferenceRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final bool checked;
  final ValueChanged<bool> onChange;

  const _GlassPreferenceRow({
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    required this.checked,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GlassSwitch(
            checked: checked,
            onChange: onChange,
            label: title,
          ),
        ],
      ),
    );
  }
}
