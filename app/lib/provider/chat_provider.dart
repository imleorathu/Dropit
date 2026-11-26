import 'dart:async';

import 'package:dropit_app/model/chat_message.dart';
import 'package:dropit_app/provider/device_info_provider.dart';
import 'package:dropit_app/provider/http_provider.dart';
import 'package:dropit_app/provider/network/nearby_devices_provider.dart';
import 'package:dropit_app/provider/persistence_provider.dart';
import 'package:dropit_isolates/isolate.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:dropit_isolates/rust/api/model.dart' show ProtocolType;
import 'package:dropit_isolates/rust/api/server.dart' show ChatEnvelope;
import 'package:refena_flutter/refena_flutter.dart';
import 'package:uuid/uuid.dart';

final chatProvider = NotifierProvider<ChatService, List<ChatMessage>>((ref) => ChatService());

class ChatService extends Notifier<List<ChatMessage>> {
  ChatService();
  final _uuid = const Uuid();
  final Set<String> _inFlightIds = <String>{};
  Future<void> _persistChain = Future<void>.value();

  static const int _chatTimeoutMs = 8000;

  static String normalizeId(String id) => id.trim().toUpperCase();

  @override
  List<ChatMessage> init() {
    final restored = ref.read(persistenceProvider).getChatMessages().map(ChatMessage.fromJson).toList();
    // Recover messages left in-flight when the app last terminated.
    return [
      for (final message in restored)
        message.status == ChatDeliveryStatus.sending ? message.copyWith(status: ChatDeliveryStatus.pending) : message,
    ];
  }

  Future<void> _persist() {
    final snapshot = state.map((message) => message.toJson()).toList();
    _persistChain = _persistChain.catchError((_) {}).then((_) => ref.read(persistenceProvider).setChatMessages(snapshot));
    return _persistChain;
  }

  String conversationId(String peerFingerprint) {
    final ids = [normalizeId(ref.read(deviceFullInfoProvider).fingerprint), normalizeId(peerFingerprint)]..sort();
    return ids.join(':');
  }

  List<ChatMessage> messagesForPeer(String peerFingerprint) {
    final target = normalizeId(peerFingerprint);
    final convId = conversationId(peerFingerprint);
    return state.where((m) => normalizeId(m.senderId) == target || normalizeId(m.receiverId) == target || m.conversationId == convId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> sendText(Device peer, String value) async {
    final text = value.trim();
    if (text.isEmpty || text.length > 32000) return;
    final me = normalizeId(ref.read(deviceFullInfoProvider).fingerprint);
    final peerId = normalizeId(peer.fingerprint);
    final message = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId(peerId),
      senderId: me,
      receiverId: peerId,
      timestamp: DateTime.now().toUtc(),
      text: text,
      status: ChatDeliveryStatus.pending,
    );
    state = [...state, message];
    await _persist();
    await _transmit(peer, message);
  }

  Future<ChatMessage> recordAttachmentTransfer(
    Device peer, {
    required String sessionId,
    required String name,
    required int size,
    required int count,
  }) async {
    final me = normalizeId(ref.read(deviceFullInfoProvider).fingerprint);
    final peerId = normalizeId(peer.fingerprint);
    final label = count > 1 ? '$name (+${count - 1} more)' : name;
    final message = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId(peerId),
      senderId: me,
      receiverId: peerId,
      timestamp: DateTime.now().toUtc(),
      text: label,
      status: ChatDeliveryStatus.pending,
      kind: 'chat.attachment',
      attachmentSessionId: sessionId,
      attachmentName: name,
      attachmentSize: size,
      attachmentCount: count,
    );
    state = [...state, message];
    await _persist();
    unawaited(_transmit(peer, message));
    return message;
  }

  Future<void> retryPendingFor(Device peer) async {
    if (peer.ip == null) return;
    final peerId = normalizeId(peer.fingerprint);
    final pending = state
        .where((item) => normalizeId(item.receiverId) == peerId && (item.status == ChatDeliveryStatus.pending || item.status == ChatDeliveryStatus.failed))
        .toList();
    for (final message in pending) {
      await _transmit(peer, message);
    }
  }

  Future<void> retryAllPendingForOnlinePeers(Map<String, Device> nearby) async {
    final normalizedNearby = <String, Device>{
      for (final device in nearby.values)
        if (device.ip != null) normalizeId(device.fingerprint): device,
    };
    if (normalizedNearby.isEmpty) return;

    final pending = state.where((item) => item.status == ChatDeliveryStatus.pending).toList();
    for (final message in pending) {
      final peer = normalizedNearby[normalizeId(message.receiverId)];
      if (peer != null) {
        await _transmit(peer, message);
      }
    }
  }

  Future<void> retryMessage(Device peer, String messageId) async {
    final index = state.indexWhere((m) => m.id == messageId);
    if (index < 0) return;
    await _transmit(peer, state[index]);
  }

  Future<void> _transmit(Device peer, ChatMessage message) async {
    final ip = peer.ip;
    if (ip == null) {
      _advanceStatus(message.id, ChatDeliveryStatus.pending);
      await _persist();
      return;
    }
    if (!_inFlightIds.add(message.id)) return;
    try {
      _advanceStatus(message.id, ChatDeliveryStatus.sending);
      await ref
          .read(httpProvider)
          .pinnedTo(peer.fingerprint, timeoutMs: _chatTimeoutMs)
          .sendChat(
            protocol: peer.https ? ProtocolType.https : ProtocolType.http,
            ip: ip,
            port: peer.port,
            envelope: _envelope(message, message.kind),
          );
      _advanceStatus(message.id, ChatDeliveryStatus.sent);
    } catch (_) {
      _advanceStatus(message.id, ChatDeliveryStatus.pending);
    } finally {
      _inFlightIds.remove(message.id);
    }
    await _persist();
  }

  Future<void> receive(HttpServerChatEvent event) async {
    final envelope = event.envelope;
    final myFingerprint = normalizeId(ref.read(deviceFullInfoProvider).fingerprint);
    if (normalizeId(envelope.receiverId) != myFingerprint) return;
    final senderId = normalizeId(event.senderFingerprint.isNotEmpty ? event.senderFingerprint : envelope.senderId);
    if (senderId == myFingerprint) return;

    if (envelope.kind == 'chat.message' || envelope.kind == 'chat.attachment') {
      if (state.any((message) => message.id == envelope.messageId)) {
        // Re-acknowledge duplicate delivery so the sender stops retrying.
        unawaited(_sendReceipt(senderId, envelope.messageId, 'chat.delivered'));
        return;
      }
      state = [
        ...state,
        ChatMessage(
          id: envelope.messageId,
          conversationId: conversationId(senderId),
          senderId: senderId,
          receiverId: myFingerprint,
          timestamp: DateTime.fromMillisecondsSinceEpoch(envelope.timestamp, isUtc: true),
          text: envelope.content ?? (envelope.kind == 'chat.attachment' ? 'Attachment' : ''),
          status: ChatDeliveryStatus.delivered,
          kind: envelope.kind,
          attachmentName: envelope.kind == 'chat.attachment' ? envelope.content : null,
        ),
      ];
      await _persist();
      unawaited(_sendReceipt(senderId, envelope.messageId, 'chat.delivered'));
    } else if (envelope.kind == 'chat.delivered' || envelope.kind == 'chat.read') {
      final relatedId = envelope.relatedMessageId;
      if (relatedId == null) return;
      final status = envelope.kind == 'chat.read' ? ChatDeliveryStatus.read : ChatDeliveryStatus.delivered;
      if (_advanceStatus(relatedId, status)) {
        await _persist();
      }
    }
  }

  Future<void> markRead(String peerFingerprint) async {
    final target = normalizeId(peerFingerprint);
    final incoming = state.where((message) => normalizeId(message.senderId) == target && message.status != ChatDeliveryStatus.read).toList();
    if (incoming.isEmpty) return;

    for (final message in incoming) {
      _advanceStatus(message.id, ChatDeliveryStatus.read);
    }
    await _persist();
    for (final message in incoming) {
      unawaited(_sendReceipt(target, message.id, 'chat.read'));
    }
  }

  Future<void> _sendReceipt(String peerFingerprint, String relatedId, String kind) async {
    final target = normalizeId(peerFingerprint);
    final devices = ref.read(nearbyDevicesProvider).devices;
    Device? peer;
    for (final d in devices.values) {
      if (normalizeId(d.fingerprint) == target) {
        peer = d;
        break;
      }
    }
    if (peer?.ip == null) return;

    final me = normalizeId(ref.read(deviceFullInfoProvider).fingerprint);
    final receipt = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId(target),
      senderId: me,
      receiverId: target,
      timestamp: DateTime.now().toUtc(),
      text: '',
      status: ChatDeliveryStatus.sending,
    );
    try {
      await ref
          .read(httpProvider)
          .pinnedTo(peer!.fingerprint, timeoutMs: _chatTimeoutMs)
          .sendChat(
            protocol: peer.https ? ProtocolType.https : ProtocolType.http,
            ip: peer.ip!,
            port: peer.port,
            envelope: _envelope(receipt, kind, relatedId: relatedId),
          );
    } catch (_) {}
  }

  ChatEnvelope _envelope(ChatMessage message, String kind, {String? relatedId}) => ChatEnvelope(
    protocolVersion: 1,
    kind: kind,
    messageId: message.id,
    conversationId: message.conversationId,
    senderId: message.senderId,
    receiverId: message.receiverId,
    timestamp: message.timestamp.toUtc().millisecondsSinceEpoch,
    contentType: (kind == 'chat.message' || kind == 'chat.attachment') ? 'text' : null,
    content: (kind == 'chat.message' || kind == 'chat.attachment') ? message.text : null,
    relatedMessageId: relatedId,
  );

  bool _advanceStatus(String messageId, ChatDeliveryStatus nextStatus) {
    final index = state.indexWhere((m) => m.id == messageId);
    if (index < 0) return false;
    final current = state[index];
    if (!current.status.canAdvanceTo(nextStatus)) return false;
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) current.copyWith(status: nextStatus) else state[i],
    ];
    return true;
  }
}
