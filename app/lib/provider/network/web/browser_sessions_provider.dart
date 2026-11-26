import 'package:dropit_app/model/cross_file.dart';
import 'package:dropit_app/model/state/server/browser_session_state.dart';
import 'package:dropit_app/provider/network/server/controller/send_controller.dart';
import 'package:dropit_isolates/isolate.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:uuid/uuid.dart';

final _logger = Logger('BrowserSessions');

const _uuid = Uuid();

final browserSessionsProvider = NotifierProvider<BrowserSessionsService, BrowserSessionsState>(
  (ref) => BrowserSessionsService(),
);

/// Tracks the browsers that opened the Dropit sharing page and the offers sent
/// to them. The Rust server owns the actual sessions; this service mirrors the
/// events into UI state and resolves the file content for downloads.
class BrowserSessionsService extends Notifier<BrowserSessionsState> {
  @override
  BrowserSessionsState init() {
    return BrowserSessionsState.empty;
  }

  void onSessionChanged(HttpServerBrowserSessionChangedEvent event) {
    final session = BrowserSession(
      sessionId: event.sessionId,
      clientId: event.clientId,
      ip: event.ip,
      userAgent: event.userAgent,
      browserName: event.browserName,
      deviceType: event.deviceType,
      platform: event.platform,
      connected: event.connected,
      ready: event.ready,
    );

    state = state.copyWith(
      sessions: {
        ...state.sessions,
        event.sessionId: session,
      },
    );
  }

  void onSessionClosed(HttpServerBrowserSessionClosedEvent event) {
    final sessions = {...state.sessions}..remove(event.sessionId);
    final offers = {...state.offers};
    for (final entry in offers.entries.toList()) {
      final offer = entry.value;
      if (offer.sessionId == event.sessionId && offer.isActive) {
        offers[entry.key] = offer.copyWith(status: BrowserOfferStatus.cancelled);
      }
    }

    state = state.copyWith(sessions: sessions, offers: offers);
  }

  void onOfferResponse(HttpServerBrowserOfferResponseEvent event) {
    final offer = state.offers[event.offerId];
    if (offer == null) {
      return;
    }

    _updateOffer(
      offer.offerId,
      (offer) => offer.copyWith(
        status: event.accepted ? BrowserOfferStatus.accepted : BrowserOfferStatus.declined,
      ),
    );
  }

  void onDownloadProgress(HttpServerBrowserDownloadProgressEvent event) {
    final offer = state.offers[event.offerId];
    if (offer == null) {
      return;
    }

    final progress = event.totalBytes <= 0 ? 1.0 : (event.downloadedBytes / event.totalBytes).clamp(0.0, 1.0);
    _updateOffer(
      offer.offerId,
      (offer) => offer.copyWith(
        status: BrowserOfferStatus.downloading,
        fileProgress: {
          ...offer.fileProgress,
          event.fileId: progress,
        },
      ),
    );
  }

  void onDownloadFinished(HttpServerBrowserDownloadFinishedEvent event) {
    final offer = state.offers[event.offerId];
    if (offer == null) {
      return;
    }

    final completed = {...offer.completedFileIds, event.fileId};
    final allCompleted = offer.files.keys.every(completed.contains);
    _updateOffer(
      offer.offerId,
      (offer) => offer.copyWith(
        status: allCompleted ? BrowserOfferStatus.completed : BrowserOfferStatus.downloading,
        completedFileIds: completed,
        fileProgress: {
          ...offer.fileProgress,
          event.fileId: 1,
        },
      ),
    );
  }

  /// Resolves the content source of a download and answers the pending request.
  Future<void> onDownloadRequested(HttpServerBrowserDownloadRequestedEvent event) async {
    final offer = state.offers[event.offerId];
    final file = offer?.files[event.fileId];
    final source = await resolveWebSendFileSourceOrNull(file, fileId: event.fileId);

    if (source == null) {
      _failOffer(event, 'The file content could not be resolved.');
      await _failDownload(event);
      return;
    }

    _updateOffer(event.offerId, (offer) => offer.copyWith(status: BrowserOfferStatus.downloading));

    try {
      await ref
          .redux(parentIsolateProvider)
          .dispatchAsync(
            IsolateHttpServerBrowserDownloadTargetAction(
              sessionId: event.sessionId,
              offerId: event.offerId,
              fileId: event.fileId,
              path: source.path,
              fileDescriptor: source.fileDescriptor,
            ),
          );
    } catch (e) {
      _logger.warning('Failed to answer browser download request', e);
      _failOffer(event, 'The transfer could not be started.');
      await _failDownload(event);
    }
  }

  /// Offers the given files to a connected browser.
  Future<void> offerFiles({
    required String sessionId,
    required List<CrossFile> files,
  }) async {
    final session = state.sessions[sessionId];
    if (session == null) {
      throw StateError('This browser is no longer connected.');
    }
    if (!session.canReceive) {
      throw StateError('This browser is not ready to receive files yet.');
    }
    if (files.isEmpty) {
      throw ArgumentError('No files selected.');
    }

    // Replace offers the browser has not started downloading yet, so the page
    // does not accumulate stale prompts.
    final replaceable = state.offers.values
        .where(
          (offer) => offer.sessionId == sessionId && (offer.status == BrowserOfferStatus.pending || offer.status == BrowserOfferStatus.accepted),
        )
        .toList();
    for (final offer in replaceable) {
      await cancelOffer(offer.offerId);
    }

    final materialized = await materializeWebSendFiles(files);
    final offerId = _uuid.v4();
    final offers = {...state.offers}..removeWhere((_, offer) => offer.sessionId == sessionId && offer.isTerminal);
    state = state.copyWith(
      offers: {
        ...offers,
        offerId: BrowserOffer.pending(
          offerId: offerId,
          sessionId: sessionId,
          files: materialized,
        ),
      },
    );

    try {
      await ref
          .redux(parentIsolateProvider)
          .dispatchAsync(
            IsolateHttpServerBrowserOfferAction(
              sessionId: sessionId,
              offerId: offerId,
              files: {
                for (final entry in materialized.entries) entry.key: entry.value.file,
              },
            ),
          );
    } catch (e) {
      final offers = {...state.offers}..remove(offerId);
      state = state.copyWith(offers: offers);
      rethrow;
    }
  }

  /// Cancels a pending offer and informs the browser.
  Future<void> cancelOffer(String offerId) async {
    final offer = state.offers[offerId];
    if (offer == null || offer.isTerminal) {
      return;
    }

    _updateOffer(offerId, (offer) => offer.copyWith(status: BrowserOfferStatus.cancelled));

    try {
      await ref.redux(parentIsolateProvider).dispatchAsync(IsolateHttpServerBrowserCancelOfferAction(offerId: offerId));
    } catch (e) {
      _logger.warning('Failed to cancel browser offer $offerId', e);
    }
  }

  /// Ends a browser session. The server closes its event stream.
  Future<void> disconnectSession(String sessionId) async {
    await ref.redux(parentIsolateProvider).dispatchAsync(IsolateHttpServerBrowserDisconnectAction(sessionId: sessionId));
  }

  /// Forgets all sessions and offers, e.g. when the server is stopped.
  void clear() {
    state = BrowserSessionsState.empty;
  }

  void _updateOffer(String offerId, BrowserOffer Function(BrowserOffer offer) update) {
    final offer = state.offers[offerId];
    if (offer == null) {
      return;
    }

    state = state.copyWith(
      offers: {
        ...state.offers,
        offerId: update(offer),
      },
    );
  }

  void _failOffer(HttpServerBrowserDownloadRequestedEvent event, String error) {
    _updateOffer(
      event.offerId,
      (offer) => offer.copyWith(
        status: BrowserOfferStatus.failed,
        error: error,
      ),
    );
  }

  Future<void> _failDownload(HttpServerBrowserDownloadRequestedEvent event) async {
    try {
      await ref
          .redux(parentIsolateProvider)
          .dispatchAsync(
            IsolateHttpServerBrowserFailDownloadAction(
              sessionId: event.sessionId,
              offerId: event.offerId,
              fileId: event.fileId,
            ),
          );
    } catch (e) {
      _logger.warning('Failed to fail browser download request', e);
    }
  }
}
