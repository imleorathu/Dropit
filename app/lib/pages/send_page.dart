import 'dart:async';

import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/model/state/send/send_session_state.dart';
import 'package:dropit_app/pages/verify_page.dart';
import 'package:dropit_app/provider/device_info_provider.dart';
import 'package:dropit_app/provider/favorites_provider.dart';
import 'package:dropit_app/provider/file_transfer_provider.dart';
import 'package:dropit_app/provider/network/send_provider.dart';
import 'package:dropit_app/util/favorites.dart';
import 'package:dropit_app/util/native/taskbar_helper.dart';
import 'package:dropit_app/widget/dialogs/error_dialog.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/list_tile/device_list_tile.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_glass_progress.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:dropit_isolates/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class SendPage extends StatefulWidget {
  final bool showAppBar;
  final bool closeSessionOnClose;
  final String sessionId;

  const SendPage({
    required this.showAppBar,
    required this.closeSessionOnClose,
    required this.sessionId,
  });

  @override
  State<SendPage> createState() => _SendPageState();
}

double _hashProgress(SendSessionState sendState, FileTransferNotifier transferNotifier) {
  final files = sendState.files.values;
  final totalBytes = files.fold<int>(0, (prev, curr) => prev + curr.file.size);
  if (totalBytes == 0) {
    return sendState.files.isEmpty ? 0 : sendState.hashedFileCount / sendState.files.length;
  }
  final hashedBytes = files.fold<double>(
    0,
    (prev, curr) => prev + transferNotifier.getProgress(sessionId: sendState.sessionId, fileId: curr.file.id) * curr.file.size,
  );
  return (hashedBytes / totalBytes).clamp(0, 1);
}

class _SendPageState extends State<SendPage> with Refena {
  Device? _myDevice;
  Device? _targetDevice;

  @override
  void dispose() {
    super.dispose();
    unawaited(TaskbarHelper.clearProgressBar());
  }

  void _cancel() {
    // the state will be lost so we store them temporarily (only for UI)
    final myDevice = ref.read(deviceFullInfoProvider);
    final sendState = ref.read(sendProvider)[widget.sessionId];
    if (sendState == null) {
      return;
    }

    setState(() {
      _myDevice = myDevice;
      _targetDevice = sendState.target;
    });
    ref.notifier(sendProvider).cancelSession(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final sendState = ref.watch(
      sendProvider.select((state) => state[widget.sessionId]),
      listener: (prev, next) {
        final prevStatus = prev[widget.sessionId]?.status;
        final nextStatus = next[widget.sessionId]?.status;
        if (prevStatus != nextStatus) {
          // ignore: discarded_futures
          TaskbarHelper.visualizeStatus(nextStatus);
        }
      },
    );
    if (sendState == null && _myDevice == null && _targetDevice == null) {
      return Scaffold(
        body: Container(),
      );
    }
    final myDevice = ref.watch(deviceFullInfoProvider);
    final targetDevice = sendState?.target ?? _targetDevice!;
    final targetFavoriteEntry = ref.watch(favoritesProvider.select((state) => state.findDevice(targetDevice)));
    final waiting = sendState?.status == SessionStatus.waiting;

    final theme = Theme.of(context);
    final hashing = sendState != null && sendState.hashedFileCount < sendState.files.length;
    final statusLabel = switch (sendState?.status) {
      SessionStatus.waiting =>
        hashing ? t.sendPage.calculatingChecksum(curr: sendState.hashedFileCount, n: sendState.files.length) : t.sendPage.waiting,
      SessionStatus.declined => t.sendPage.rejected,
      SessionStatus.tooManyAttempts => t.sendPage.tooManyAttempts,
      SessionStatus.recipientBusy => t.sendPage.busy,
      SessionStatus.finishedWithErrors => t.general.error,
      _ => t.general.finished,
    };
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && widget.closeSessionOnClose) _cancel();
      },
      child: Scaffold(
        appBar: const DropitAppBar(title: Text('Your drop')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    DropitHeading(
                      title: waiting ? 'Connecting...' : statusLabel,
                      description: waiting ? 'Waiting for recipient to accept...' : null,
                    ),
                    const SizedBox(height: 28),
                    DropitPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DeviceListTile(device: myDevice),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Icon(Icons.south_rounded, color: theme.colorScheme.primary, size: 28),
                          ),
                          DeviceListTile(device: targetDevice, nameOverride: targetFavoriteEntry?.alias),
                          const SizedBox(height: 20),
                          Text(statusLabel, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                          if (hashing) ...[
                            const SizedBox(height: 18),
                            AppGlassProgress(
                              progress: _hashProgress(sendState, ref.watch(fileTransferProvider)),
                              height: 10,
                            ),
                          ],
                          if (sendState?.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () async => showDialog(
                                context: context,
                                builder: (_) => ErrorDialog(error: sendState!.errorMessage!),
                              ),
                              icon: const Icon(Icons.info_outline),
                              label: const Text('View details'),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton.icon(
                              onPressed: !targetDevice.https
                                  ? null
                                  : () async =>
                                        context.push(() => VerifyPage(fingerprint: CombinedFingerprint.load(context, targetDevice.fingerprint))),
                              icon: const Icon(Icons.verified_user_outlined, size: 18),
                              label: Text(t.verifyPage.title),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppGlassButton(
                            variant: AppGlassButtonVariant.filled,
                            size: AppGlassButtonSize.lg,
                            icon: waiting ? Icons.close : Icons.check_circle_outline,
                            label: waiting ? t.general.cancel : t.general.close,
                            onPressed: () {
                              _cancel();
                              context.global.dispatch(NavigateAction.popUntilRoot());
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
