import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dropit_app/model/chat_message.dart';
import 'package:dropit_app/pages/chat_page.dart';
import 'package:dropit_app/provider/chat_provider.dart';
import 'package:dropit_app/provider/device_info_provider.dart';
import 'package:dropit_app/provider/favorites_provider.dart';
import 'package:dropit_app/provider/network/nearby_devices_provider.dart';
import 'package:dropit_app/provider/network/scan_facade.dart';
import 'package:dropit_app/util/device_type_ext.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final myFingerprint = ChatService.normalizeId(context.watch(deviceFullInfoProvider).fingerprint);
    final messages = context.watch(chatProvider);
    final nearby = context.watch(nearbyDevicesProvider).devices;
    final favorites = context.watch(favoritesProvider);

    final peersByFingerprint = <String, Device>{
      for (final device in nearby.values)
        if (ChatService.normalizeId(device.fingerprint) != myFingerprint) ChatService.normalizeId(device.fingerprint): device,
    };

    for (final message in messages) {
      final senderId = ChatService.normalizeId(message.senderId);
      final receiverId = ChatService.normalizeId(message.receiverId);
      final peerId = senderId == myFingerprint ? receiverId : senderId;
      if (peerId.isEmpty || peerId == myFingerprint || peersByFingerprint.containsKey(peerId)) continue;
      final fav = favorites.firstWhereOrNull((f) => ChatService.normalizeId(f.fingerprint) == peerId);
      peersByFingerprint[peerId] = Device(
        signalingId: null,
        ip: null,
        version: '2.2',
        port: fav?.port ?? 53317,
        https: true,
        fingerprint: peerId,
        alias: fav?.alias ?? 'Device ${peerId.substring(0, peerId.length.clamp(0, 6))}',
        deviceModel: null,
        deviceType: DeviceType.desktop,
        download: false,
        channels: const [],
      );
    }

    int lastTimestampFor(String fingerprint) {
      final target = ChatService.normalizeId(fingerprint);
      var latest = 0;
      for (final m in messages) {
        if (ChatService.normalizeId(m.senderId) == target || ChatService.normalizeId(m.receiverId) == target) {
          final ts = m.timestamp.millisecondsSinceEpoch;
          if (ts > latest) latest = ts;
        }
      }
      return latest;
    }

    final normalizedQuery = query.trim().toLowerCase();
    final peers = peersByFingerprint.values.where((device) {
      if (normalizedQuery.isEmpty) return true;
      final favAlias = favorites.firstWhereOrNull((f) => f.fingerprint == device.fingerprint)?.alias;
      return device.alias.toLowerCase().contains(normalizedQuery) ||
          (favAlias?.toLowerCase().contains(normalizedQuery) ?? false) ||
          (device.deviceModel?.toLowerCase().contains(normalizedQuery) ?? false);
    }).toList()
      ..sort((a, b) {
        final aOnline = a.ip != null ? 1 : 0;
        final bOnline = b.ip != null ? 1 : 0;
        if (aOnline != bOnline) return bOnline.compareTo(aOnline);
        final aTs = lastTimestampFor(a.fingerprint);
        final bTs = lastTimestampFor(b.fingerprint);
        if (aTs != bTs) return bTs.compareTo(aTs);
        return a.alias.toLowerCase().compareTo(b.alias.toLowerCase());
      });

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 100),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Local Chat', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('Chat directly with nearby Dropit devices on your local network.', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Refresh nearby devices',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () {
                      unawaited(context.global.dispatchAsync(StartSmartScan()));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search nearby devices or conversations',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (peers.isEmpty)
                DropitPanel(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.forum_outlined, size: 44),
                      const SizedBox(height: 12),
                      const Text('No nearby devices found yet', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      const Text(
                        'Open Dropit on another phone, tablet, or laptop on the same Wi-Fi network to start chatting locally.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          unawaited(context.global.dispatchAsync(StartSmartScan()));
                        },
                        icon: const Icon(Icons.wifi_find_rounded),
                        label: const Text('Scan network'),
                      ),
                    ],
                  ),
                )
              else
                for (final peer in peers) ...[
                  _ConversationTile(
                    peer: peer,
                    displayName: favorites.firstWhereOrNull((f) => ChatService.normalizeId(f.fingerprint) == ChatService.normalizeId(peer.fingerprint))?.alias ?? peer.alias,
                    isFavorite: favorites.any((f) => ChatService.normalizeId(f.fingerprint) == ChatService.normalizeId(peer.fingerprint)),
                    messages: messages
                        .where(
                          (message) =>
                              ChatService.normalizeId(message.senderId) == ChatService.normalizeId(peer.fingerprint) ||
                              ChatService.normalizeId(message.receiverId) == ChatService.normalizeId(peer.fingerprint),
                        )
                        .toList(),
                    onTap: () async {
                      await context.push(() => ChatPage(peer: peer));
                    },
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.peer,
    required this.displayName,
    required this.isFavorite,
    required this.messages,
    required this.onTap,
  });

  final Device peer;
  final String displayName;
  final bool isFavorite;
  final List<ChatMessage> messages;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sorted = [...messages]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final last = sorted.firstOrNull;
    final unreadCount = messages.where((m) => m.senderId == peer.fingerprint && m.status != ChatDeliveryStatus.read).length;
    final online = peer.ip != null;
    final theme = Theme.of(context);

    return DropitPanel(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Icon(peer.deviceType.icon, size: 20),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (isFavorite) ...[
              const SizedBox(width: 6),
              Icon(Icons.verified_rounded, size: 15, color: theme.colorScheme.primary),
            ],
          ],
        ),
        subtitle: Text(
          last?.text ?? (online ? 'Tap to start a local conversation' : 'Offline · tap to view history'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 9, color: online ? Colors.green : theme.colorScheme.outline),
                const SizedBox(width: 5),
                Text(online ? 'Online' : 'Offline', style: const TextStyle(fontSize: 11)),
              ],
            ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$unreadCount',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.onPrimary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
