import 'dart:async';

import 'package:dropit_app/model/chat_message.dart';
import 'package:dropit_app/model/cross_file.dart';
import 'package:dropit_app/model/state/send/send_session_state.dart';
import 'package:dropit_app/provider/chat_provider.dart';
import 'package:dropit_app/provider/device_info_provider.dart';
import 'package:dropit_app/provider/file_transfer_provider.dart';
import 'package:dropit_app/provider/network/nearby_devices_provider.dart';
import 'package:dropit_app/provider/network/send_provider.dart';
import 'package:dropit_app/util/native/channel/android_channel.dart' as android_channel;
import 'package:dropit_app/util/native/cross_file_converters.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:dropit_isolates/model/session_status.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:uuid/uuid.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({required this.peer, super.key});
  final Device peer;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with Refena, WidgetsBindingObserver {
  final controller = TextEditingController();
  final scrollController = ScrollController();
  late final FocusNode inputFocusNode;
  final Map<String, List<CrossFile>> _attachmentFiles = <String, List<CrossFile>>{};
  final _uuid = const Uuid();

  int _lastMessageCount = -1;
  double _lastBottomInset = 0;
  bool _attaching = false;
  bool _markingRead = false;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    inputFocusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    ensureRef((ref) async {
      unawaited(ref.notifier(chatProvider).retryPendingFor(widget.peer));
      unawaited(_markPeerRead(widget.peer.fingerprint));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    inputFocusNode.dispose();
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    if (view == null) return;
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    if (bottomInset > _lastBottomInset && bottomInset > 0) {
      _scrollToBottom(jump: false);
    }
    _lastBottomInset = bottomInset;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isDesktop || event is! KeyDownEvent) return KeyEventResult.ignored;
    final isEnter = event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (isEnter && !HardwareKeyboard.instance.isShiftPressed) {
      unawaited(send());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Device _currentPeer(Map<String, Device> nearby) {
    final targetId = ChatService.normalizeId(widget.peer.fingerprint);
    for (final device in nearby.values) {
      if (ChatService.normalizeId(device.fingerprint) == targetId) {
        return device;
      }
    }
    return widget.peer;
  }

  Future<void> _markPeerRead(String peerFingerprint) async {
    if (_markingRead) return;
    _markingRead = true;
    try {
      await ref.notifier(chatProvider).markRead(peerFingerprint);
    } finally {
      _markingRead = false;
    }
  }

  Future<void> send() async {
    final text = controller.text;
    if (text.trim().isEmpty) return;
    controller.clear();
    inputFocusNode.requestFocus();
    final peer = _currentPeer(ref.read(nearbyDevicesProvider).devices);
    await ref.notifier(chatProvider).sendText(peer, text);
    _scrollToBottom(jump: false);
  }

  void _scrollToBottom({required bool jump}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      final target = scrollController.position.maxScrollExtent;
      if (jump) {
        scrollController.jumpTo(target);
      } else {
        unawaited(
          scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  Future<void> attach() async {
    if (_attaching) return;
    final peer = _currentPeer(ref.read(nearbyDevicesProvider).devices);
    if (peer.ip == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device is currently offline')),
      );
      return;
    }

    _attaching = true;
    try {
      final List<CrossFile> files;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final result = await android_channel.pickFilesAndroid();
        if (result == null || result.isEmpty) return;
        files = await Future.wait(result.map(CrossFileConverters.convertFileInfo));
      } else {
        final result = await openFiles();
        if (result.isEmpty) return;
        files = await Future.wait(result.map(CrossFileConverters.convertXFile));
      }
      if (files.isEmpty || !mounted) return;

      final sessionId = _uuid.v4();
      _attachmentFiles[sessionId] = files;
      final totalSize = files.fold<int>(0, (sum, file) => sum + file.size);
      await ref.notifier(chatProvider).recordAttachmentTransfer(
            peer,
            sessionId: sessionId,
            name: files.first.name,
            size: totalSize,
            count: files.length,
          );
      _scrollToBottom(jump: false);

      await ref.notifier(sendProvider).startSession(
            target: peer,
            files: files,
            background: true,
            sessionId: sessionId,
          );
    } on PlatformException catch (e) {
      if (e.code != 'CANCELED' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach files: ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach files: $e')),
        );
      }
    } finally {
      _attaching = false;
    }
  }

  Future<void> _retryAttachment(String sessionId, Device peer) async {
    final files = _attachmentFiles[sessionId];
    if (files == null || files.isEmpty || peer.ip == null) return;
    await ref.notifier(sendProvider).startSession(
          target: peer,
          files: files,
          background: true,
          sessionId: sessionId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final myId = ChatService.normalizeId(context.watch(deviceFullInfoProvider).fingerprint);
    final nearby = context.watch(nearbyDevicesProvider).devices;
    final peer = _currentPeer(nearby);
    final peerId = ChatService.normalizeId(peer.fingerprint);
    final online = peer.ip != null;
    final sendSessions = context.watch(sendProvider);
    final transferNotifier = context.watch(fileTransferProvider);

    final messages =
        context
            .watch(chatProvider)
            .where((message) => ChatService.normalizeId(message.senderId) == peerId || ChatService.normalizeId(message.receiverId) == peerId)
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final hasUnreadIncoming = messages.any((m) => ChatService.normalizeId(m.senderId) == peerId && m.status != ChatDeliveryStatus.read);
    if (hasUnreadIncoming && !_markingRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_markPeerRead(peer.fingerprint));
        }
      });
    }
    if (messages.length != _lastMessageCount) {
      final isInitial = _lastMessageCount == -1;
      _lastMessageCount = messages.length;
      _scrollToBottom(jump: isInitial);
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: DropitAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(peer.alias),
            Text(
              online ? 'Connected locally' : 'Offline · messages queue until online',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.forum_outlined, size: 44, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                const SizedBox(height: 12),
                                Text('Say hello to ${peer.alias}', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  'Messages stay on your local network and are saved on this device.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final mine = ChatService.normalizeId(message.senderId) == myId;
                            final session = message.attachmentSessionId != null ? sendSessions[message.attachmentSessionId] : null;
                            return KeyedSubtree(
                              key: ValueKey(message.id),
                              child: _MessageBubble(
                                message: message,
                                mine: mine,
                                session: session,
                                progress: session != null ? _sessionProgress(session, transferNotifier) : null,
                                canRetryMessage: mine && message.status == ChatDeliveryStatus.pending && online,
                                canRetryAttachment:
                                    mine &&
                                    message.attachmentSessionId != null &&
                                    _attachmentFiles.containsKey(message.attachmentSessionId) &&
                                    online &&
                                    (session == null ||
                                        session.status == SessionStatus.canceledBySender ||
                                        session.status == SessionStatus.canceledByReceiver ||
                                        session.status == SessionStatus.declined ||
                                        session.status == SessionStatus.finishedWithErrors),
                                onRetryMessage: () => unawaited(ref.notifier(chatProvider).retryMessage(peer, message.id)),
                                onCancelAttachment: session != null &&
                                        (session.status == SessionStatus.waiting || session.status == SessionStatus.sending)
                                    ? () => ref.notifier(sendProvider).cancelSession(session.sessionId)
                                    : null,
                                onRetryAttachment: message.attachmentSessionId != null
                                    ? () => unawaited(_retryAttachment(message.attachmentSessionId!, peer))
                                    : null,
                                statusIcon: _statusIcon(message.status),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(onPressed: attach, tooltip: 'Send attachments with Dropit', icon: const Icon(Icons.attach_file)),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: inputFocusNode,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: _isDesktop ? TextInputAction.newline : TextInputAction.send,
                          onSubmitted: _isDesktop ? null : (_) => unawaited(send()),
                          decoration: const InputDecoration(hintText: 'Message', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(onPressed: () => unawaited(send()), tooltip: 'Send', icon: const Icon(Icons.send_rounded)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double? _sessionProgress(SendSessionState session, FileTransferNotifier transferNotifier) {
    final files = session.files.values;
    if (files.isEmpty) return null;
    final totalBytes = files.fold<int>(0, (sum, f) => sum + f.file.size);
    if (totalBytes <= 0) return session.status == SessionStatus.finished ? 1.0 : 0.0;
    final sentBytes = files.fold<double>(
      0.0,
      (sum, f) => sum + (transferNotifier.getProgress(sessionId: session.sessionId, fileId: f.file.id) * f.file.size),
    );
    return (sentBytes / totalBytes).clamp(0.0, 1.0);
  }

  IconData _statusIcon(ChatDeliveryStatus status) => switch (status) {
    ChatDeliveryStatus.pending => Icons.schedule,
    ChatDeliveryStatus.sending => Icons.sync,
    ChatDeliveryStatus.sent => Icons.check,
    ChatDeliveryStatus.delivered => Icons.done_all,
    ChatDeliveryStatus.read => Icons.done_all,
    ChatDeliveryStatus.failed => Icons.error_outline,
  };
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.session,
    required this.progress,
    required this.canRetryMessage,
    required this.canRetryAttachment,
    required this.onRetryMessage,
    required this.onCancelAttachment,
    required this.onRetryAttachment,
    required this.statusIcon,
  });

  final ChatMessage message;
  final bool mine;
  final SendSessionState? session;
  final double? progress;
  final bool canRetryMessage;
  final bool canRetryAttachment;
  final VoidCallback onRetryMessage;
  final VoidCallback? onCancelAttachment;
  final VoidCallback? onRetryAttachment;
  final IconData statusIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 7),
        decoration: BoxDecoration(
          color: mine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.isAttachment)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file_rounded, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message.text,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (session != null) ...[
                    const SizedBox(height: 6),
                    if (session!.status == SessionStatus.sending && progress != null) ...[
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _sessionLabel(session!, progress),
                          style: theme.textTheme.labelSmall,
                        ),
                        if (onCancelAttachment != null) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: onCancelAttachment,
                            child: Text('Cancel', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
                          ),
                        ],
                        if (canRetryAttachment && onRetryAttachment != null) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: onRetryAttachment,
                            child: Text('Retry', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              )
            else
              SelectableText(message.text),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  TimeOfDay.fromDateTime(message.timestamp.toLocal()).format(context),
                  style: theme.textTheme.labelSmall,
                ),
                if (mine) ...[
                  const SizedBox(width: 5),
                  if (canRetryMessage)
                    InkWell(
                      onTap: onRetryMessage,
                      child: Icon(statusIcon, size: 14),
                    )
                  else
                    Icon(statusIcon, size: 14),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _sessionLabel(SendSessionState session, double? progress) => switch (session.status) {
    SessionStatus.waiting => 'Waiting for recipient...',
    SessionStatus.sending => progress != null ? 'Sending ${(progress * 100).round()}%' : 'Sending...',
    SessionStatus.finished => 'Sent',
    SessionStatus.finishedWithErrors => 'Completed with errors',
    SessionStatus.declined => 'Declined',
    SessionStatus.canceledBySender => 'Canceled',
    SessionStatus.canceledByReceiver => 'Canceled by recipient',
    SessionStatus.recipientBusy => 'Recipient busy',
    SessionStatus.tooManyAttempts => 'Too many attempts',
  };
}
