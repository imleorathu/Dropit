import 'dart:async';

import 'package:dropit_app/model/cross_file.dart';
import 'package:dropit_app/provider/network/server/server_provider.dart';
import 'package:dropit_app/provider/settings_provider.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('BrowserSharingService');

enum BrowserSharingMode {
  /// Mode A: Receive via Browser (Web browser uploads files to this device)
  receive,

  /// Mode B: Send via Browser (Web browser downloads files offered by this device)
  send,
}

class BrowserSharingState {
  final BrowserSharingMode activeMode;
  final List<CrossFile> stagedFiles;
  final bool isEncrypted;
  final String? customPin;
  final bool isApplying;

  const BrowserSharingState({
    required this.activeMode,
    required this.stagedFiles,
    required this.isEncrypted,
    required this.customPin,
    required this.isApplying,
  });

  BrowserSharingState copyWith({
    BrowserSharingMode? activeMode,
    List<CrossFile>? stagedFiles,
    bool? isEncrypted,
    String? customPin,
    bool? isApplying,
  }) {
    return BrowserSharingState(
      activeMode: activeMode ?? this.activeMode,
      stagedFiles: stagedFiles ?? this.stagedFiles,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      customPin: customPin ?? this.customPin,
      isApplying: isApplying ?? this.isApplying,
    );
  }
}

final browserSharingProvider = NotifierProvider<BrowserSharingService, BrowserSharingState>((ref) {
  return BrowserSharingService();
});

class BrowserSharingService extends Notifier<BrowserSharingState> {
  @override
  BrowserSharingState init() {
    return const BrowserSharingState(
      activeMode: BrowserSharingMode.receive,
      stagedFiles: [],
      isEncrypted: false,
      customPin: null,
      isApplying: false,
    );
  }

  /// Sets the initial mode and pre-staged files (e.g. when opened from SendTab).
  void setInitial({BrowserSharingMode? mode, List<CrossFile>? files}) {
    state = state.copyWith(
      activeMode: mode ?? (files != null && files.isNotEmpty ? BrowserSharingMode.send : BrowserSharingMode.receive),
      stagedFiles: files ?? state.stagedFiles,
    );
    if (state.activeMode == BrowserSharingMode.send && state.stagedFiles.isNotEmpty) {
      unawaited(applyWebSend());
    }
  }

  /// Switches between Mode A (Receive via browser) and Mode B (Send via browser).
  Future<void> switchMode(BrowserSharingMode mode) async {
    if (state.activeMode == mode) return;

    state = state.copyWith(activeMode: mode, isApplying: true);

    try {
      if (mode == BrowserSharingMode.receive) {
        // Switch server to receive (webUpload) mode
        await ref.notifier(serverProvider).switchToWebUploadMode(webPin: state.customPin, https: state.isEncrypted);
      } else {
        // Switch to send mode if files are already staged
        if (state.stagedFiles.isNotEmpty) {
          await applyWebSend();
        }
      }
    } catch (e) {
      _logger.warning('Failed to switch browser sharing mode to $mode', e);
    } finally {
      state = state.copyWith(isApplying: false);
    }
  }

  /// Adds files to the staged files list for Send via Browser.
  Future<void> addStagedFiles(List<CrossFile> newFiles) async {
    final updated = [...state.stagedFiles, ...newFiles];
    state = state.copyWith(stagedFiles: updated);
    if (state.activeMode == BrowserSharingMode.send && updated.isNotEmpty) {
      await applyWebSend();
    }
  }

  /// Removes a file by index from the staged files list.
  Future<void> removeStagedFile(int index) async {
    final updated = [...state.stagedFiles]..removeAt(index);
    state = state.copyWith(stagedFiles: updated);
    if (state.activeMode == BrowserSharingMode.send) {
      if (updated.isNotEmpty) {
        await applyWebSend();
      } else {
        // No more files; switch to webUpload mode so server remains active
        await ref.notifier(serverProvider).switchToWebUploadMode(webPin: state.customPin, https: state.isEncrypted);
      }
    }
  }

  /// Clears all staged files.
  Future<void> clearStagedFiles() async {
    state = state.copyWith(stagedFiles: []);
    if (state.activeMode == BrowserSharingMode.send) {
      await ref.notifier(serverProvider).switchToWebUploadMode(webPin: state.customPin, https: state.isEncrypted);
    }
  }

  /// Activates Web Send on the running server with the currently staged files.
  Future<void> applyWebSend() async {
    if (state.stagedFiles.isEmpty) return;
    state = state.copyWith(isApplying: true);

    try {
      final settings = ref.read(settingsProvider);
      await ref
          .notifier(serverProvider)
          .restartServerWithWebSend(
            alias: settings.alias,
            port: settings.port,
            https: state.isEncrypted,
            files: state.stagedFiles,
            webPin: state.customPin ?? settings.receivePin,
          );
    } catch (e) {
      _logger.warning('Failed to activate web send', e);
    } finally {
      state = state.copyWith(isApplying: false);
    }
  }

  /// Toggles TLS encryption for browser sharing.
  Future<void> toggleEncryption(bool enabled) async {
    state = state.copyWith(isEncrypted: enabled);
    if (state.activeMode == BrowserSharingMode.send && state.stagedFiles.isNotEmpty) {
      await applyWebSend();
    } else {
      final settings = ref.read(settingsProvider);
      await ref
          .notifier(serverProvider)
          .restartServer(
            alias: settings.alias,
            port: settings.port,
            https: enabled,
            webUpload: true,
            webPin: state.customPin ?? settings.receivePin,
          );
    }
  }

  /// Updates the PIN for the current browser sharing session.
  Future<void> setPin(String? pin) async {
    state = state.copyWith(customPin: pin);
    await ref.notifier(serverProvider).setWebPin(pin);
  }

  /// Builds the full local URL for a given IP and port.
  String buildUrl({
    required String ip,
    required int port,
    String? pin,
  }) {
    final protocol = state.isEncrypted ? 'https' : 'http';
    final base = '$protocol://$ip:$port';
    if (pin != null && pin.isNotEmpty) {
      return '$base/?pin=${Uri.encodeQueryComponent(pin)}';
    }
    return base;
  }
}
