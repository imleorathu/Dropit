import 'package:dart_mappable/dart_mappable.dart';
import 'package:dropit_app/model/state/send/web/web_send_state.dart';
import 'package:dropit_app/model/state/server/receive_session_state.dart';

part 'server_state.mapper.dart';

@MappableClass()
class ServerState with ServerStateMappable {
  final String alias;
  final int port;

  /// The port of the separate HTTPS listener that serves the browser pages.
  ///
  /// `null` when browser sharing is disabled, in which case browser links use
  /// [port] and [https].
  final int? browserPort;
  final bool https;
  final ReceiveSessionState? session;
  final WebSendState? webSendState;

  /// Whether the upload page is served so web browsers can upload files.
  final bool webUpload;

  /// Optional session-scoped PIN of the active web share mode (download or upload page).
  /// The PIN is enforced by the Rust server; changing it requires a server restart.
  final String? webPin;

  const ServerState({
    required this.alias,
    required this.port,
    required this.browserPort,
    required this.https,
    required this.session,
    required this.webSendState,
    required this.webUpload,
    required this.webPin,
  });

  @override
  String toString() {
    return 'ServerState(alias: $alias, port: $port, browserPort: $browserPort, https: $https, session: $session, webSendState: $webSendState, webUpload: $webUpload, webPin: $webPin)';
  }
}
