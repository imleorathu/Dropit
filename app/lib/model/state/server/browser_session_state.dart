import 'package:dropit_app/model/state/send/web/web_send_file.dart';
import 'package:dropit_isolates/rust/api/server.dart' show BrowserDeviceType;

/// UI-facing connection state of a browser session.
enum BrowserConnectionStatus {
  /// The browser registered, but its event stream is not established yet.
  connecting,

  /// The browser is reachable and can receive offers.
  connected,

  /// Heartbeats stopped; the session may still resume within the grace period.
  disconnected,
}

/// A browser that opened the Dropit sharing page.
class BrowserSession {
  final String sessionId;
  final String clientId;
  final String ip;
  final String? userAgent;
  final String browserName;
  final BrowserDeviceType deviceType;
  final String platform;
  final bool connected;
  final bool ready;

  const BrowserSession({
    required this.sessionId,
    required this.clientId,
    required this.ip,
    required this.userAgent,
    required this.browserName,
    required this.deviceType,
    required this.platform,
    required this.connected,
    required this.ready,
  });

  BrowserConnectionStatus get status {
    if (connected && ready) {
      return BrowserConnectionStatus.connected;
    }
    if (connected) {
      return BrowserConnectionStatus.connecting;
    }
    return BrowserConnectionStatus.disconnected;
  }

  /// Whether offers can currently be delivered to the browser.
  bool get canReceive => connected && ready;

  String get deviceLabel {
    switch (deviceType) {
      case BrowserDeviceType.mobile:
        return 'Mobile';
      case BrowserDeviceType.tablet:
        return 'Tablet';
      case BrowserDeviceType.desktop:
        return 'Desktop';
      case BrowserDeviceType.unknown:
        return 'Browser';
    }
  }

  String get description {
    final parts = <String>[
      if (platform.isNotEmpty && platform != 'Unknown') platform else deviceLabel,
      ip,
    ];
    return parts.join(' · ');
  }
}

/// State of a transfer offer sent to a browser.
enum BrowserOfferStatus {
  /// The browser has not answered yet.
  pending,

  /// The browser accepted and can download the files.
  accepted,

  /// At least one file is being streamed to the browser.
  downloading,

  /// The browser declined the offer.
  declined,

  /// All files were streamed to the browser.
  completed,

  /// The offer was cancelled by the application or the session ended.
  cancelled,

  /// Streaming a file failed.
  failed,
}

/// A transfer offer created by this device for a browser session.
class BrowserOffer {
  final String offerId;
  final String sessionId;
  final Map<String, WebSendFile> files;
  final BrowserOfferStatus status;
  final Map<String, double> fileProgress;
  final Set<String> completedFileIds;
  final String? error;

  const BrowserOffer({
    required this.offerId,
    required this.sessionId,
    required this.files,
    required this.status,
    required this.fileProgress,
    required this.completedFileIds,
    required this.error,
  });

  factory BrowserOffer.pending({
    required String offerId,
    required String sessionId,
    required Map<String, WebSendFile> files,
  }) {
    return BrowserOffer(
      offerId: offerId,
      sessionId: sessionId,
      files: files,
      status: BrowserOfferStatus.pending,
      fileProgress: const {},
      completedFileIds: const {},
      error: null,
    );
  }

  bool get isActive => status == BrowserOfferStatus.pending || status == BrowserOfferStatus.accepted || status == BrowserOfferStatus.downloading;

  bool get isTerminal => !isActive;

  double get progress {
    final total = files.values.fold<int>(0, (sum, file) => sum + file.file.size);
    if (total == 0) {
      return completedFileIds.length == files.length ? 1 : 0;
    }
    final transferred = files.entries.fold<double>(
      0,
      (sum, entry) => sum + entry.value.file.size * (fileProgress[entry.key] ?? (completedFileIds.contains(entry.key) ? 1 : 0)),
    );
    return (transferred / total).clamp(0, 1);
  }

  BrowserOffer copyWith({
    BrowserOfferStatus? status,
    Map<String, double>? fileProgress,
    Set<String>? completedFileIds,
    String? error,
    bool clearError = false,
  }) {
    return BrowserOffer(
      offerId: offerId,
      sessionId: sessionId,
      files: files,
      status: status ?? this.status,
      fileProgress: fileProgress ?? this.fileProgress,
      completedFileIds: completedFileIds ?? this.completedFileIds,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// All browser sessions and offers known to the application.
class BrowserSessionsState {
  final Map<String, BrowserSession> sessions;
  final Map<String, BrowserOffer> offers;

  const BrowserSessionsState({
    required this.sessions,
    required this.offers,
  });

  static const empty = BrowserSessionsState(sessions: {}, offers: {});

  /// The most recent non-terminal offer of a session, if any.
  BrowserOffer? activeOfferForSession(String sessionId) {
    BrowserOffer? result;
    for (final offer in offers.values) {
      if (offer.sessionId == sessionId && offer.isActive) {
        result = offer;
      }
    }
    return result;
  }

  /// The most recent offer of a session, including terminal offers so the UI
  /// can keep showing the outcome until the next offer replaces it.
  BrowserOffer? latestOfferForSession(String sessionId) {
    BrowserOffer? result;
    for (final offer in offers.values) {
      if (offer.sessionId == sessionId) {
        result = offer;
      }
    }
    return result;
  }

  BrowserSessionsState copyWith({
    Map<String, BrowserSession>? sessions,
    Map<String, BrowserOffer>? offers,
  }) {
    return BrowserSessionsState(
      sessions: sessions ?? this.sessions,
      offers: offers ?? this.offers,
    );
  }
}
