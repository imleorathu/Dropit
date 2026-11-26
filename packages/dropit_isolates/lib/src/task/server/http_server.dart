import 'package:dropit_isolates/rust/api/model.dart';
import 'package:dropit_isolates/rust/api/server.dart';
import 'package:refena_flutter/refena_flutter.dart';

final httpServerProvider = Provider((ref) => HttpServerService());

/// Wraps the Rust HTTP server.
/// Only one server can run at a time.
class HttpServerService {
  RsHttpServer? _server;

  bool get running => _server != null;

  /// Starts the server and returns the stream of server events.
  /// The stream ends when the server is stopped.
  Future<Stream<RsServerEvent>> start({
    required int port,
    required TlsConfig? tls,
    required TlsConfig? browserTls,
    required String alias,
    required String version,
    required String? deviceModel,
    required DeviceType? deviceType,
    required String fingerprint,
    required String? pin,
    required bool verifyChecksums,
    required WebParams? web,
    required String? showToken,
  }) async {
    if (_server != null) {
      throw StateError('Server already running');
    }

    final server = await startServer(
      port: port,
      tls: tls,
      browserTls: browserTls,
      alias: alias,
      version: version,
      deviceModel: deviceModel,
      deviceType: deviceType,
      fingerprint: fingerprint,
      pin: pin,
      verifyChecksums: verifyChecksums,
      web: web,
      showToken: showToken,
    );
    _server = server;
    return server.listen();
  }

  /// The port of the separate HTTPS listener that serves the browser pages.
  Future<int?> browserPort() async => await _requireServer().browserPort();

  /// Answers a pending prepare-upload request.
  /// [acceptedFileIds] is the subset of the offered files to accept; `null` declines the request.
  Future<void> respondPrepareUpload({required List<String>? acceptedFileIds}) async {
    await _requireServer().respondPrepareUpload(acceptedFileIds: acceptedFileIds);
  }

  /// Answers a pending file upload with the target the file should be saved to
  /// (either a [path] or a [fileDescriptor]).
  ///
  /// The returned stream emits the progress (fraction of [fileSize]) while the
  /// file is being received and closes once the file has been received
  /// completely (or errors when saving failed).
  ///
  /// Timestamps provided in the sender's file metadata are applied to the
  /// written file by the Rust server.
  Stream<double> respondFileUpload({
    required String sessionId,
    required String fileId,
    required String? path,
    required int? fileDescriptor,
    required int fileSize,
  }) {
    return _requireServer().respondFileUpload(
      sessionId: sessionId,
      fileId: fileId,
      path: path,
      fileDescriptor: fileDescriptor,
      fileSize: BigInt.from(fileSize),
    );
  }

  /// Fails a pending file upload, e.g. because no save target could be
  /// prepared. The upload request fails with an error response and the file is
  /// marked as failed; the session itself continues.
  /// Does nothing if the upload was already answered via [respondFileUpload].
  Future<void> failFileUpload({required String sessionId, required String fileId}) async {
    await _requireServer().failFileUpload(sessionId: sessionId, fileId: fileId);
  }

  /// Cancels the active upload session. Uploads that are already in progress
  /// still run to completion, but new upload requests fail and a new
  /// session can be created. No session-end event is emitted.
  Future<void> cancelSession({required String sessionId}) async {
    await _requireServer().cancelSession(sessionId: sessionId);
  }

  /// Answers a pending web prepare-download request.
  /// [accept] grants the download; `false` declines it.
  Future<void> respondPrepareDownload({required String sessionId, required bool accept}) async {
    await _requireServer().respondPrepareDownload(sessionId: sessionId, accept: accept);
  }

  /// Answers a pending web file download with the source the file content should be
  /// read from (either a [path] or a [fileDescriptor]). The server streams the content.
  Future<void> respondFileDownload({
    required String sessionId,
    required String fileId,
    required String? path,
    required int? fileDescriptor,
  }) async {
    await _requireServer().respondFileDownload(
      sessionId: sessionId,
      fileId: fileId,
      path: path,
      fileDescriptor: fileDescriptor,
    );
  }

  /// Fails a pending web file download, e.g. because no content source could
  /// be resolved. The download request fails with an error response.
  /// Does nothing if the download was already answered via [respondFileDownload].
  Future<void> failFileDownload({required String sessionId, required String fileId}) async {
    await _requireServer().failFileDownload(sessionId: sessionId, fileId: fileId);
  }

  /// Offers files to a connected browser session.
  Future<void> browserCreateOffer({
    required String sessionId,
    required String offerId,
    required Map<String, FileDto> files,
  }) async {
    await _requireServer().browserCreateOffer(
      sessionId: sessionId,
      offerId: offerId,
      files: files,
    );
  }

  /// Cancels a pending browser offer.
  Future<void> browserCancelOffer({required String offerId}) async {
    await _requireServer().browserCancelOffer(offerId: offerId);
  }

  /// Removes a browser session and closes its event stream.
  Future<void> browserDisconnectSession({required String sessionId}) async {
    await _requireServer().browserDisconnectSession(sessionId: sessionId);
  }

  /// Answers a pending browser download with the source the content should be
  /// read from (either a [path] or a [fileDescriptor]). The server streams it.
  Future<void> respondBrowserDownload({
    required String sessionId,
    required String offerId,
    required String fileId,
    required String? path,
    required int? fileDescriptor,
  }) async {
    await _requireServer().respondBrowserDownload(
      sessionId: sessionId,
      offerId: offerId,
      fileId: fileId,
      path: path,
      fileDescriptor: fileDescriptor,
    );
  }

  /// Fails a pending browser download, e.g. because no content source could be
  /// resolved. Does nothing if the download was already answered.
  Future<void> failBrowserDownload({
    required String sessionId,
    required String offerId,
    required String fileId,
  }) async {
    await _requireServer().failBrowserDownload(
      sessionId: sessionId,
      offerId: offerId,
      fileId: fileId,
    );
  }

  /// Stops the server. The event stream returned by [start] will end.
  /// Completes once the port is released and can be bound again.
  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.stop();
  }

  RsHttpServer _requireServer() {
    final server = _server;
    if (server == null) {
      throw StateError('Server is not running');
    }
    return server;
  }
}
