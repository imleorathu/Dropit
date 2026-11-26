import 'package:dropit_app/model/cross_file.dart';
import 'package:dropit_app/model/state/send/web/web_send_state.dart';
import 'package:dropit_app/model/state/server/server_state.dart';
import 'package:dropit_app/provider/network/server/server_provider.dart';
import 'package:dropit_app/provider/network/web/browser_sharing_service.dart';
import 'package:dropit_isolates/model/file_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refena_flutter/refena_flutter.dart';

class _MockServerService extends ServerService {
  bool switchedToReceive = false;

  @override
  ServerState? init() => null;

  @override
  Future<void> switchToWebUploadMode({String? webPin, bool? https}) async {
    switchedToReceive = true;
  }

  @override
  Future<void> restartServerWithWebSend({
    required String alias,
    required int port,
    required bool https,
    required List<CrossFile> files,
    String? webPin,
  }) async {
    // No-op for mock
  }

  @override
  Future<ServerState?> restartServer({
    required String alias,
    required int port,
    required bool https,
    WebSendState? webSendState,
    bool webUpload = true,
    String? webPin,
  }) async {
    return null;
  }

  @override
  Future<void> setWebPin(String? pin) async {
    // No-op for mock
  }
}

void main() {
  group('BrowserSharingService', () {
    test('initial state defaults to receive mode with empty files', () {
      final ref = RefenaContainer();
      final state = ref.read(browserSharingProvider);

      expect(state.activeMode, BrowserSharingMode.receive);
      expect(state.stagedFiles, isEmpty);
      expect(state.isApplying, isFalse);
    });

    test('switchMode updates activeMode and triggers server transition', () async {
      final mockServer = _MockServerService();
      final ref = RefenaContainer(
        overrides: [
          serverProvider.overrideWithNotifier((_) => mockServer),
        ],
      );

      final service = ref.notifier(browserSharingProvider);

      await service.switchMode(BrowserSharingMode.send);
      expect(ref.read(browserSharingProvider).activeMode, BrowserSharingMode.send);

      await service.switchMode(BrowserSharingMode.receive);
      expect(ref.read(browserSharingProvider).activeMode, BrowserSharingMode.receive);
      expect(mockServer.switchedToReceive, isTrue);
    });

    test('addStagedFiles and removeStagedFile manage staged list', () async {
      final mockServer = _MockServerService();
      final ref = RefenaContainer(
        overrides: [
          serverProvider.overrideWithNotifier((_) => mockServer),
        ],
      );

      final service = ref.notifier(browserSharingProvider);

      const fileA = CrossFile(
        name: 'test_photo.jpg',
        fileType: FileType.image,
        size: 1024,
        thumbnail: null,
        asset: null,
        path: '/tmp/test_photo.jpg',
        bytes: null,
        lastModified: '2026-11-07T12:00:00Z',
        lastAccessed: '2026-11-07T12:00:00Z',
      );

      const fileB = CrossFile(
        name: 'document.pdf',
        fileType: FileType.pdf,
        size: 2048,
        thumbnail: null,
        asset: null,
        path: '/tmp/document.pdf',
        bytes: null,
        lastModified: '2026-11-07T12:00:00Z',
        lastAccessed: '2026-11-07T12:00:00Z',
      );

      await service.addStagedFiles([fileA, fileB]);
      expect(ref.read(browserSharingProvider).stagedFiles.length, 2);

      await service.removeStagedFile(0);
      expect(ref.read(browserSharingProvider).stagedFiles.length, 1);
      expect(ref.read(browserSharingProvider).stagedFiles.first.name, 'document.pdf');

      await service.clearStagedFiles();
      expect(ref.read(browserSharingProvider).stagedFiles, isEmpty);
    });

    test('buildUrl formats URLs correctly with and without pin', () {
      final ref = RefenaContainer();
      final service = ref.notifier(browserSharingProvider);

      final url = service.buildUrl(ip: '192.168.1.100', port: 53317);
      expect(url, 'http://192.168.1.100:53317');

      final urlWithPin = service.buildUrl(ip: '192.168.1.100', port: 53317, pin: '1234');
      expect(urlWithPin, 'http://192.168.1.100:53317/?pin=1234');
    });
  });
}
