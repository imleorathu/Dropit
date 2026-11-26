import 'package:dropit_app/model/chat_message.dart';
import 'package:dropit_app/provider/chat_provider.dart';
import 'package:dropit_app/provider/device_info_provider.dart';
import 'package:dropit_app/provider/favorites_provider.dart';
import 'package:dropit_app/provider/logging/discovery_logs_provider.dart';
import 'package:dropit_app/provider/network/nearby_devices_provider.dart';
import 'package:dropit_app/provider/persistence_provider.dart';
import 'package:dropit_isolates/isolate.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:dropit_isolates/rust/api/server.dart' show ChatEnvelope;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Device _device({
  required String fingerprint,
  String? ip,
  String alias = 'Peer',
}) => Device(
  signalingId: null,
  ip: ip,
  version: '2.2',
  port: 53317,
  https: true,
  fingerprint: fingerprint,
  alias: alias,
  deviceModel: 'Pixel 7',
  deviceType: DeviceType.mobile,
  download: false,
  channels: const [],
);

class _FakeIsolateController extends Fake implements IsolateController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('main-delegate-channel'),
      (call) async => call.method == 'isReduceMotionEnabled' ? false : null,
    );
  });

  test('ChatMessage preserves legacy JSON and advances status monotonically', () {
    final legacy = ChatMessage.fromJson({
      'id': 'm-1',
      'conversationId': 'A:B',
      'senderId': 'A',
      'receiverId': 'B',
      'timestamp': 1700000000000,
      'text': 'hello',
      'status': 'delivered',
    });

    expect(legacy.kind, 'chat.message');
    expect(legacy.timestamp.isUtc, isTrue);
    expect(legacy.isAttachment, isFalse);
    expect(ChatDeliveryStatus.delivered.canAdvanceTo(ChatDeliveryStatus.read), isTrue);
    expect(ChatDeliveryStatus.read.canAdvanceTo(ChatDeliveryStatus.delivered), isFalse);
    expect(ChatDeliveryStatus.sent.canAdvanceTo(ChatDeliveryStatus.pending), isFalse);
  });

  test('ChatService persists messages, recovers stuck sending state on restart, and deduplicates events', () async {
    const myFp = 'MYFP1234';
    const peerFp = 'PEER5678';
    SharedPreferences.setMockInitialValues({
      'ls_alias': 'Test Device',
      'ls_show_token': 'token',
      'ls_security_context': 'ctx',
      'ls_locale': 'en',
      'ls_color': 'dropit',
      'ls_version': 4,
      'dropit_chat_messages_v1':
          '[{"id":"stuck-1","conversationId":"MYFP1234:PEER5678","senderId":"MYFP1234","receiverId":"PEER5678","timestamp":1700000000000,"text":"queued","status":"sending"}]',
    });
    final persistence = await PersistenceService.initialize(supportsDynamicColors: false);

    final container = RefenaContainer(
      overrides: [
        persistenceProvider.overrideWithValue(persistence),
        deviceFullInfoProvider.overrideWithBuilder((_) => _device(fingerprint: myFp, ip: '192.168.1.10', alias: 'Me')),
        nearbyDevicesProvider.overrideWithNotifier(
          (ref) => NearbyDevicesService(
            isolateController: _FakeIsolateController(),
            favoriteService: FavoritesService(persistence),
            discoveryLogs: DiscoveryLogger(),
          ),
        ),
      ],
    );

    // Stuck "sending" message recovers to "pending" on startup.
    expect(container.read(chatProvider).single.status, ChatDeliveryStatus.pending);

    // Offline sendText immediately appears in state as pending and persists.
    final offlinePeer = _device(fingerprint: peerFp, ip: null);
    await container.notifier(chatProvider).sendText(offlinePeer, 'Hello offline');
    expect(container.read(chatProvider).length, 2);
    expect(container.read(chatProvider).last.text, 'Hello offline');
    expect(container.read(chatProvider).last.status, ChatDeliveryStatus.pending);
    expect(persistence.getChatMessages().length, 2);

    // Duplicate incoming events with same messageId and lowercase senderId are deduplicated.
    final incomingEvent = HttpServerChatEvent(
      senderFingerprint: peerFp.toLowerCase(),
      envelope: ChatEnvelope(
        protocolVersion: 1,
        kind: 'chat.message',
        messageId: 'in-1',
        conversationId: '$myFp:$peerFp',
        senderId: peerFp.toLowerCase(),
        receiverId: myFp.toLowerCase(),
        timestamp: 1700000001000,
        contentType: 'text',
        content: 'Hi back',
        relatedMessageId: null,
      ),
    );
    await container.notifier(chatProvider).receive(incomingEvent);
    await container.notifier(chatProvider).receive(incomingEvent);

    final incoming = container.read(chatProvider).where((m) => m.id == 'in-1').toList();
    expect(incoming.length, 1);
    expect(incoming.single.text, 'Hi back');
    expect(incoming.single.status, ChatDeliveryStatus.delivered);

    // Delayed "delivered" receipt after "read" must not downgrade status.
    await container.notifier(chatProvider).receive(
      HttpServerChatEvent(
        senderFingerprint: peerFp,
        envelope: const ChatEnvelope(
          protocolVersion: 1,
          kind: 'chat.read',
          messageId: 'rcpt-read',
          conversationId: 'MYFP1234:PEER5678',
          senderId: peerFp,
          receiverId: myFp,
          timestamp: 1700000002000,
          contentType: null,
          content: null,
          relatedMessageId: 'stuck-1',
        ),
      ),
    );
    await container.notifier(chatProvider).receive(
      HttpServerChatEvent(
        senderFingerprint: peerFp,
        envelope: const ChatEnvelope(
          protocolVersion: 1,
          kind: 'chat.delivered',
          messageId: 'rcpt-deliv',
          conversationId: 'MYFP1234:PEER5678',
          senderId: peerFp,
          receiverId: myFp,
          timestamp: 1700000003000,
          contentType: null,
          content: null,
          relatedMessageId: 'stuck-1',
        ),
      ),
    );
    expect(container.read(chatProvider).firstWhere((m) => m.id == 'stuck-1').status, ChatDeliveryStatus.read);
  });
}
