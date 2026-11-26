//! Browser sharing sessions: presence, server-sent events, transfer offers and
//! browser-managed downloads.
//!
//! A browser that opens the local URL registers itself with a server-issued
//! session ID and an unpredictable session token. The token authenticates the
//! long-lived SSE connection, heartbeats, offer responses and downloads. The
//! session is independent of the LocalSend v2 upload session and of the legacy
//! web-send link flow, so it also works while the upload page is active.
//!
//! The application is informed about all lifecycle changes through
//! [`BrowserEvent`]s. File content is requested from the application per
//! download, mirroring [`crate::http::server::web::WebSendEvent::FileDownload`].

use crate::http::server::common::error::AppError;
use crate::http::server::common::response::{BoxedBody, JsonResponse, full_body};
use crate::http::server::{AppState, PeerIp, RequestClientInfo};
use crate::model::transfer::{FileContent, FileDto};
use bytes::Bytes;
use http_body_util::{BodyExt, Limited, StreamBody};
use hyper::body::{Frame, Incoming};
use hyper::{Method, Request, Response, StatusCode, http};
use lru::LruCache;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::fmt::Write as _;
use std::future::Future;
use std::net::IpAddr;
use std::num::NonZeroUsize;
use std::path::PathBuf;
use std::pin::Pin;
use std::sync::{Arc, Weak};
use std::task::{Context, Poll};
use std::time::{Duration, Instant};
use tokio::sync::{Mutex, OwnedSemaphorePermit, Semaphore, mpsc, oneshot};
use tokio_stream::Stream;
use tokio_stream::StreamExt;
use tokio_stream::wrappers::ReceiverStream;
use tokio_util::sync::{CancellationToken, WaitForCancellationFutureOwned};

/// Maximum accepted registration/heartbeat/offer-response body size.
const MAX_REQUEST_BODY: usize = 16 * 1024;

/// Interval between SSE keep-alive comments. Also bounds how quickly a closed
/// tab is noticed when its heartbeat requests stopped as well.
pub const SSE_PING_INTERVAL: Duration = Duration::from_secs(10);

/// How many failed PIN attempts are allowed per IP before returning 429.
const MAX_PIN_ATTEMPTS: u32 = 3;

/// Maximum number of simultaneous browser sessions. Browsers are cheap, but an
/// unbounded registry would be an easy memory leak.
const MAX_SESSIONS: usize = 64;

/// Maximum number of retained offers (pending and recently accepted).
const MAX_OFFERS: usize = 256;

/// Bounds open file handles and disk readers while still allowing parallel LAN
/// downloads. Additional browser requests wait without buffering file data.
const MAX_CONCURRENT_DOWNLOADS: usize = 8;

const DOWNLOAD_COOKIE: &str = "dropit_download_session";

/// Events emitted by the browser sharing endpoints that must be handled by the
/// application.
#[derive(Debug)]
pub enum BrowserEvent {
    /// A session was created, resumed, reconnected or lost its live SSE
    /// connection. Always carries the complete current session snapshot so the
    /// application can upsert without keeping its own diff logic.
    SessionChanged {
        session_id: String,
        client_id: String,
        ip: PeerIp,
        user_agent: Option<String>,
        browser_name: String,
        device_type: BrowserDeviceType,
        platform: String,
        connected: bool,
        ready: bool,
    },

    /// A session ended and must be removed from the UI.
    SessionClosed {
        session_id: String,
        reason: BrowserSessionEndReason,
    },

    /// The browser answered a transfer offer created by the application.
    OfferResponse {
        offer_id: String,
        session_id: String,
        accepted: bool,
    },

    /// The browser started downloading an accepted file. The application must
    /// answer on `content_tx` with the file content.
    DownloadRequested {
        session_id: String,
        offer_id: String,
        file_id: String,
        file: FileDto,
        content_tx: oneshot::Sender<FileContent>,
    },

    /// Number of bytes of a file already streamed to the browser.
    DownloadProgress {
        session_id: String,
        offer_id: String,
        file_id: String,
        downloaded_bytes: u64,
        total_bytes: u64,
    },

    /// The complete file was streamed to the browser.
    DownloadFinished {
        session_id: String,
        offer_id: String,
        file_id: String,
    },
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum BrowserDeviceType {
    Mobile,
    Tablet,
    Desktop,
    Unknown,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum BrowserSessionEndReason {
    /// The browser disconnected or stopped sending heartbeats.
    Disconnected,
    /// The session expired after the reconnect grace period.
    Expired,
    /// The application stopped the server or removed the session explicitly.
    Removed,
}

/// Configuration for browser sharing sessions.
pub struct BrowserConfig {
    /// Optional PIN that new sessions must provide. A valid session token
    /// authenticates reconnects without asking for the PIN again.
    pub pin: Option<String>,

    /// A session is considered disconnected after this long without a
    /// heartbeat or registration request.
    pub heartbeat_timeout: Duration,

    /// How long a disconnected session is retained so a page reload or a
    /// temporary network interruption can resume it without a duplicate card.
    pub reconnect_grace: Duration,

    /// Channel on which server events are emitted to the application.
    pub event_tx: mpsc::Sender<BrowserEvent>,

    /// PEM-encoded local CA that signs the TLS certificate for browser
    /// sharing. Served to browsers so users can trust it once and get rid of
    /// the security warning.
    pub ca_certificate: Option<String>,
}

impl BrowserConfig {
    pub fn new(pin: Option<String>, event_tx: mpsc::Sender<BrowserEvent>) -> Self {
        Self {
            pin,
            heartbeat_timeout: Duration::from_secs(20),
            reconnect_grace: Duration::from_secs(6),
            event_tx,
            ca_certificate: None,
        }
    }
}

/// Runtime state of the browser sharing endpoints.
pub(crate) struct BrowserState {
    config: BrowserConfig,
    sessions: Mutex<HashMap<String, BrowserSession>>,
    offers: Mutex<HashMap<String, BrowserOffer>>,
    pin_attempts: Mutex<LruCache<IpAddr, u32>>,
    download_slots: Arc<Semaphore>,
    active_downloads: Mutex<HashMap<String, ActiveBrowserDownload>>,
}

struct BrowserSession {
    session_id: String,
    client_id: String,
    token: String,
    ip: PeerIp,
    user_agent: Option<String>,
    browser_name: String,
    device_type: BrowserDeviceType,
    platform: String,
    created_at: Instant,
    last_seen: Instant,
    connected: bool,
    sse: Option<SseConnection>,
}

#[derive(Clone)]
struct SseConnection {
    generation: u64,
    tx: mpsc::Sender<Bytes>,
}

struct BrowserOffer {
    offer_id: String,
    session_id: String,
    files: HashMap<String, FileDto>,
    /// Cached filesystem paths resolved on first download so subsequent Range /
    /// resume requests avoid round-tripping through the application isolate.
    resolved_paths: HashMap<String, PathBuf>,
    accepted: bool,
    created_at_ms: u64,
}

struct ActiveBrowserDownload {
    session_id: String,
    offer_id: String,
    cancel: CancellationToken,
}

fn now_ms() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_millis() as u64)
        .unwrap_or(0)
}

impl BrowserState {
    pub(crate) fn new(config: BrowserConfig) -> Arc<Self> {
        let state = Arc::new(Self {
            config,
            sessions: Mutex::new(HashMap::new()),
            offers: Mutex::new(HashMap::new()),
            pin_attempts: Mutex::new(LruCache::new(NonZeroUsize::new(200).unwrap())),
            download_slots: Arc::new(Semaphore::new(MAX_CONCURRENT_DOWNLOADS)),
            active_downloads: Mutex::new(HashMap::new()),
        });

        // The cleanup loop holds only a weak reference, so it stops when the
        // server (and with it the browser state) is dropped.
        let weak = Arc::downgrade(&state);
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(Duration::from_secs(2)).await;
                let Some(state) = Weak::upgrade(&weak) else {
                    break;
                };
                state.cleanup().await;
            }
        });

        state
    }

    fn heartbeat_interval(&self) -> Duration {
        // Keep the client heartbeat clearly below the timeout, but never below
        // one second.
        (self.config.heartbeat_timeout / 4)
            .max(Duration::from_secs(1))
            .min(Duration::from_secs(5))
    }

    async fn cleanup(&self) {
        let now = Instant::now();
        let mut sessions = self.sessions.lock().await;
        let mut removed = Vec::new();

        for session in sessions.values_mut() {
            if session.connected
                && now.duration_since(session.last_seen) >= self.config.heartbeat_timeout
            {
                session.connected = false;
                session.sse = None;
                let _ = self.config.event_tx.try_send(BrowserEvent::SessionChanged {
                    session_id: session.session_id.clone(),
                    client_id: session.client_id.clone(),
                    ip: session.ip,
                    user_agent: session.user_agent.clone(),
                    browser_name: session.browser_name.clone(),
                    device_type: session.device_type,
                    platform: session.platform.clone(),
                    connected: false,
                    ready: false,
                });
            }

            if !session.connected
                && now.duration_since(session.last_seen)
                    >= self.config.heartbeat_timeout + self.config.reconnect_grace
            {
                removed.push(session.session_id.clone());
            }
        }

        for session_id in &removed {
            sessions.remove(session_id);
        }
        drop(sessions);

        if removed.is_empty() {
            return;
        }

        for session_id in &removed {
            self.offers
                .lock()
                .await
                .retain(|_, offer| &offer.session_id != session_id);
        }

        for session_id in removed {
            let _ = self.config.event_tx.try_send(BrowserEvent::SessionClosed {
                session_id,
                reason: BrowserSessionEndReason::Expired,
            });
        }
    }

    async fn emit_session_changed(&self, session: &BrowserSession) {
        let _ = self.config.event_tx.try_send(BrowserEvent::SessionChanged {
            session_id: session.session_id.clone(),
            client_id: session.client_id.clone(),
            ip: session.ip,
            user_agent: session.user_agent.clone(),
            browser_name: session.browser_name.clone(),
            device_type: session.device_type,
            platform: session.platform.clone(),
            connected: session.connected,
            ready: session.sse.is_some(),
        });
    }

    fn send_sse(
        &self,
        session: &BrowserSession,
        event: &str,
        data: &impl Serialize,
    ) -> Result<(), ()> {
        let Some(sse) = &session.sse else {
            return Err(());
        };

        let json = serde_json::to_string(data).map_err(|_| ())?;
        let frame = format!("event: {event}\ndata: {json}\n\n");
        sse.tx.try_send(Bytes::from(frame)).map_err(|_| ())
    }

    async fn session_by_token(&self, session_id: &str, token: &str) -> Option<BrowserSession> {
        let sessions = self.sessions.lock().await;
        sessions
            .get(session_id)
            .filter(|session| tokens_equal(&session.token, token))
            .cloned()
    }
}

// `BrowserSession` is cloned as a snapshot for request handling. The token is
// only ever compared server-side and never serialized.
impl Clone for BrowserSession {
    fn clone(&self) -> Self {
        Self {
            session_id: self.session_id.clone(),
            client_id: self.client_id.clone(),
            token: self.token.clone(),
            ip: self.ip,
            user_agent: self.user_agent.clone(),
            browser_name: self.browser_name.clone(),
            device_type: self.device_type,
            platform: self.platform.clone(),
            created_at: self.created_at,
            last_seen: self.last_seen,
            connected: self.connected,
            sse: self.sse.clone(),
        }
    }
}

fn tokens_equal(expected: &str, actual: &str) -> bool {
    // Constant-time comparison: tokens are secrets.
    if expected.len() != actual.len() {
        return false;
    }
    expected
        .as_bytes()
        .iter()
        .zip(actual.as_bytes())
        .fold(0u8, |acc, (a, b)| acc | (a ^ b))
        == 0
}

fn generate_token() -> String {
    use rand::Rng;
    let mut bytes = [0u8; 32];
    rand::rng().fill_bytes(&mut bytes);
    let mut token = String::with_capacity(64);
    for byte in bytes {
        let _ = write!(token, "{byte:02x}");
    }
    token
}

fn sanitize(value: Option<String>, max_len: usize) -> Option<String> {
    let value = value?;
    let cleaned: String = value
        .chars()
        .filter(|c| !c.is_control())
        .take(max_len)
        .collect();
    let cleaned = cleaned.trim().to_string();
    if cleaned.is_empty() {
        None
    } else {
        Some(cleaned)
    }
}

/// Extracts the browser name from a user agent. Order matters: Edge and Opera
/// also contain "Chrome", Chrome contains "Safari".
pub fn browser_name_from_user_agent(user_agent: &str) -> Option<&'static str> {
    if user_agent.contains("Edg/") || user_agent.contains("Edg ") || user_agent.contains("Edge") {
        Some("Edge")
    } else if user_agent.contains("OPR/") || user_agent.contains("Opera") {
        Some("Opera")
    } else if user_agent.contains("Firefox/") || user_agent.contains("FxiOS") {
        Some("Firefox")
    } else if user_agent.contains("SamsungBrowser") {
        Some("Samsung Internet")
    } else if user_agent.contains("Chrome/") || user_agent.contains("CriOS") {
        Some("Chrome")
    } else if user_agent.contains("Safari/") {
        Some("Safari")
    } else {
        None
    }
}

/// Best-effort device type derived from the user agent. The client-provided
/// value wins when it is valid; this is only a display hint and never used for
/// authorization.
pub fn device_type_from_user_agent(user_agent: &str) -> BrowserDeviceType {
    let ua = user_agent;
    if ua.contains("iPad")
        || ua.contains("Tablet")
        || (ua.contains("Android") && !ua.contains("Mobile"))
    {
        BrowserDeviceType::Tablet
    } else if ua.contains("iPhone")
        || ua.contains("iPod")
        || ua.contains("Android")
        || ua.contains("Mobile")
    {
        BrowserDeviceType::Mobile
    } else if ua.contains("Windows")
        || ua.contains("Macintosh")
        || ua.contains("Linux")
        || ua.contains("CrOS")
    {
        BrowserDeviceType::Desktop
    } else {
        BrowserDeviceType::Unknown
    }
}

fn platform_from_user_agent(user_agent: &str) -> &'static str {
    if user_agent.contains("iPhone") || user_agent.contains("iPad") || user_agent.contains("iPod") {
        "iOS"
    } else if user_agent.contains("Android") {
        "Android"
    } else if user_agent.contains("Windows") {
        "Windows"
    } else if user_agent.contains("Macintosh") || user_agent.contains("Mac OS") {
        "macOS"
    } else if user_agent.contains("CrOS") {
        "ChromeOS"
    } else if user_agent.contains("Linux") || user_agent.contains("X11") {
        "Linux"
    } else {
        "Unknown"
    }
}

fn parse_device_type(value: Option<&str>) -> Option<BrowserDeviceType> {
    match value?.to_ascii_lowercase().as_str() {
        "mobile" | "phone" => Some(BrowserDeviceType::Mobile),
        "tablet" | "ipad" => Some(BrowserDeviceType::Tablet),
        "desktop" | "laptop" | "pc" => Some(BrowserDeviceType::Desktop),
        _ => None,
    }
}

/// Rejects cross-origin state-changing requests. Same-origin browser requests
/// carry the `Origin` header in all current browsers; non-browser clients may
/// omit it but still need a valid session token.
fn validate_origin(req: &Request<Incoming>) -> Result<(), AppError> {
    let Some(origin) = req.headers().get(http::header::ORIGIN) else {
        return Ok(());
    };
    let origin = origin
        .to_str()
        .map_err(|_| AppError::Message(StatusCode::FORBIDDEN, "Invalid Origin".to_string()))?;

    if origin == "null" {
        return Err(AppError::Message(
            StatusCode::FORBIDDEN,
            "Cross-origin request rejected".to_string(),
        ));
    }

    let origin = origin.trim_end_matches('/');
    let Some(host) = req
        .headers()
        .get(http::header::HOST)
        .and_then(|value| value.to_str().ok())
    else {
        return Err(AppError::Message(
            StatusCode::FORBIDDEN,
            "Missing Host".to_string(),
        ));
    };

    let expected_http = format!("http://{host}");
    let expected_https = format!("https://{host}");
    if origin != expected_http && origin != expected_https {
        return Err(AppError::Message(
            StatusCode::FORBIDDEN,
            "Cross-origin request rejected".to_string(),
        ));
    }

    Ok(())
}

async fn collect_json<T: for<'de> Deserialize<'de>>(req: Request<Incoming>) -> Result<T, AppError> {
    let body = Limited::new(req.into_body(), MAX_REQUEST_BODY);
    let bytes = body
        .collect()
        .await
        .map_err(|_| AppError::BadRequest("Request body too large".to_string()))?
        .to_bytes();
    serde_json::from_slice(&bytes).map_err(|err| {
        tracing::warn!("Browser request had an invalid JSON body: {err:#}");
        AppError::BadRequest("Invalid JSON body".to_string())
    })
}

#[cfg(target_os = "macos")]
const DEFAULT_BROWSER_HTML: &str = include_str!("../../../assets/web/browser_macos.html");
#[cfg(not(target_os = "macos"))]
const DEFAULT_BROWSER_HTML: &str = include_str!("../../../assets/web/browser.html");

fn html_page(state: &AppState) -> Response<BoxedBody> {
    let pages = state.web_pages.as_ref();
    let page = pages
        .browser_html
        .as_deref()
        .unwrap_or(DEFAULT_BROWSER_HTML);
    let page = if state.browser_listener {
        page.replacen("<body", "<body data-browser-listener=\"true\"", 1)
    } else {
        page.to_owned()
    };

    let mut response = Response::new(full_body(page));
    let headers = response.headers_mut();
    headers.insert(
        http::header::CONTENT_TYPE,
        http::HeaderValue::from_static("text/html; charset=utf-8"),
    );
    headers.insert(
        http::header::CACHE_CONTROL,
        http::HeaderValue::from_static("no-store, max-age=0"),
    );
    headers.insert(
        http::header::HeaderName::from_static("x-content-type-options"),
        http::HeaderValue::from_static("nosniff"),
    );
    headers.insert(
        http::header::HeaderName::from_static("referrer-policy"),
        http::HeaderValue::from_static("no-referrer"),
    );
    headers.insert(
        http::header::CONTENT_SECURITY_POLICY,
        http::HeaderValue::from_static(
            "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src data:; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
        ),
    );
    response
}

pub(crate) fn index(state: &AppState) -> Response<BoxedBody> {
    html_page(state)
}

/// Serves the local CA certificate so users can install it once and remove the
/// browser security warning.
pub(crate) fn ca_certificate(state: &AppState) -> Result<Response<BoxedBody>, AppError> {
    let Some(ca) = state
        .browser
        .as_ref()
        .and_then(|browser| browser.config.ca_certificate.as_deref())
    else {
        return Err(AppError::Message(
            StatusCode::NOT_FOUND,
            "No certificate is available.".to_string(),
        ));
    };

    let mut response = Response::new(full_body(ca.to_owned()));
    let headers = response.headers_mut();
    headers.insert(
        http::header::CONTENT_TYPE,
        http::HeaderValue::from_static("application/x-x509-ca-cert"),
    );
    headers.insert(
        http::header::CONTENT_DISPOSITION,
        http::HeaderValue::from_static("attachment; filename=\"dropit-ca.crt\""),
    );
    headers.insert(
        http::header::CACHE_CONTROL,
        http::HeaderValue::from_static("no-store, max-age=0"),
    );
    Ok(response)
}

/// A lightweight endpoint the page uses to distinguish "server reachable but
/// page failed" from "server unreachable" and to show diagnostics.
pub(crate) fn health(state: &AppState) -> Response<BoxedBody> {
    let alias = state.info.try_lock().ok().map(|info| info.alias.clone());
    JsonResponse {
        status: StatusCode::OK,
        body: serde_json::json!({
            "status": "ok",
            "server": "Dropit",
            "alias": alias,
            "browserSharing": state.browser.is_some(),
            "timestamp": std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|duration| duration.as_millis())
                .unwrap_or(0),
        }),
    }
    .into_response()
}

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct RegisterRequest {
    token: Option<String>,
    session_id: Option<String>,
    client_id: Option<String>,
    user_agent: Option<String>,
    browser_name: Option<String>,
    device_type: Option<String>,
    platform: Option<String>,
    pin: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct RegisterResponse {
    session_id: String,
    session_token: String,
    client_id: String,
    alias: String,
    device_name: Option<String>,
    protocol: String,
    resumed: bool,
    browser_name: String,
    device_type: BrowserDeviceType,
    platform: String,
    heartbeat_interval_ms: u64,
    reconnect_grace_ms: u64,
    capabilities: Capabilities,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Capabilities {
    offers: bool,
    upload: bool,
    upload_via_browser: bool,
}

pub(crate) async fn register(
    req: Request<Incoming>,
    state: AppState,
    client_info: RequestClientInfo,
) -> Result<Response<BoxedBody>, AppError> {
    let Some(browser) = state.browser.clone() else {
        return Err(AppError::Message(
            StatusCode::NOT_FOUND,
            "Browser sharing is not enabled.".to_string(),
        ));
    };
    validate_origin(&req)?;

    let query = req.uri().query().map(str::to_string);
    let pin_from_query = query.as_deref().and_then(|query| {
        form_urlencoded::parse(query.as_bytes())
            .find(|(key, _)| key == "pin")
            .map(|(_, value)| value.into_owned())
    });

    let body: RegisterRequest = collect_json(req).await?;
    let register_pin = body.pin.clone().or(pin_from_query);
    let requested_token = body.token.clone();
    let requested_session = body.session_id.clone();

    let (session, resumed) = {
        let mut sessions = browser.sessions.lock().await;

        let current = requested_token.as_ref().and_then(|token| {
            sessions
                .values()
                .find(|session| {
                    requested_session
                        .as_ref()
                        .is_none_or(|session_id| &session.session_id == session_id)
                        && tokens_equal(&session.token, token)
                })
                .map(|session| session.session_id.clone())
        });

        if let Some(session_id) = current {
            let now = Instant::now();
            let session = sessions.get_mut(&session_id).expect("session listed above");

            if let Some(user_agent) = sanitize(body.user_agent.clone(), 512) {
                session.user_agent = Some(user_agent);
            }

            let user_agent = session.user_agent.clone().unwrap_or_default();
            let browser_name = sanitize(body.browser_name, 64)
                .or_else(|| browser_name_from_user_agent(&user_agent).map(str::to_string))
                .unwrap_or_else(|| session.browser_name.clone());
            let device_type = parse_device_type(body.device_type.as_deref()).unwrap_or_else(|| {
                let detected = device_type_from_user_agent(&user_agent);
                if detected == BrowserDeviceType::Unknown {
                    session.device_type
                } else {
                    detected
                }
            });
            let platform = sanitize(body.platform, 64)
                .unwrap_or_else(|| platform_from_user_agent(&user_agent).to_string());

            session.browser_name = browser_name;
            session.device_type = device_type;
            session.platform = if platform.is_empty() {
                session.platform.clone()
            } else {
                platform
            };
            session.ip = client_info.ip;
            session.last_seen = now;
            session.connected = true;
            let snapshot = session.clone();
            (snapshot, true)
        } else {
            browser
                .check_pin(register_pin.as_deref(), client_info.ip.ip)
                .await?;

            if sessions.len() >= MAX_SESSIONS {
                // Reclaim an already disconnected session before rejecting.
                if let Some(stale) = sessions
                    .values()
                    .filter(|session| !session.connected)
                    .min_by_key(|session| session.last_seen)
                    .map(|session| session.session_id.clone())
                {
                    sessions.remove(&stale);
                } else {
                    return Err(AppError::Message(
                        StatusCode::SERVICE_UNAVAILABLE,
                        "Too many browser sessions.".to_string(),
                    ));
                }
            }

            let now = Instant::now();
            let user_agent = sanitize(body.user_agent, 512);
            let ua = user_agent.clone().unwrap_or_default();
            let session = BrowserSession {
                session_id: uuid::Uuid::new_v4().to_string(),
                client_id: sanitize(body.client_id, 128)
                    .unwrap_or_else(|| uuid::Uuid::new_v4().to_string()),
                token: generate_token(),
                ip: client_info.ip,
                user_agent,
                browser_name: sanitize(body.browser_name, 64)
                    .or_else(|| browser_name_from_user_agent(&ua).map(str::to_string))
                    .unwrap_or_else(|| "Browser".to_string()),
                device_type: parse_device_type(body.device_type.as_deref())
                    .unwrap_or_else(|| device_type_from_user_agent(&ua)),
                platform: sanitize(body.platform, 64)
                    .unwrap_or_else(|| platform_from_user_agent(&ua).to_string()),
                created_at: now,
                last_seen: now,
                connected: true,
                sse: None,
            };
            sessions.insert(session.session_id.clone(), session.clone());
            (session, false)
        }
    };

    browser.emit_session_changed(&session).await;

    let info = state.info.lock().await.clone();

    let cookie_value = format!("{}.{}", session.session_id, session.token);
    let mut response = JsonResponse {
        status: StatusCode::OK,
        body: RegisterResponse {
            session_id: session.session_id,
            session_token: session.token,
            client_id: session.client_id,
            alias: info.alias.clone(),
            device_name: info.device_model.clone(),
            protocol: "http".to_string(),
            resumed,
            browser_name: session.browser_name,
            device_type: session.device_type,
            platform: session.platform,
            heartbeat_interval_ms: browser.heartbeat_interval().as_millis() as u64,
            reconnect_grace_ms: browser.config.reconnect_grace.as_millis() as u64,
            capabilities: Capabilities {
                offers: state.web.is_some(),
                upload: state.web_upload,
                upload_via_browser: state.web_upload,
            },
        },
    }
    .into_response();
    let secure = if state.browser_listener {
        "; Secure"
    } else {
        ""
    };
    response.headers_mut().insert(
        http::header::SET_COOKIE,
        http::HeaderValue::from_str(&format!(
            "{DOWNLOAD_COOKIE}={cookie_value}; Path=/api/dropit/browser/download; HttpOnly; SameSite=Strict; Max-Age=86400{secure}"
        ))
        .map_err(|_| AppError::Status(StatusCode::INTERNAL_SERVER_ERROR))?,
    );
    Ok(response)
}

impl BrowserState {
    async fn check_pin(&self, pin: Option<&str>, ip: IpAddr) -> Result<(), AppError> {
        let Some(required) = self.config.pin.as_deref() else {
            return Ok(());
        };

        let mut attempts = self.pin_attempts.lock().await;
        let count = attempts.get(&ip).copied().unwrap_or(0);
        if count >= MAX_PIN_ATTEMPTS {
            return Err(AppError::Message(
                StatusCode::TOO_MANY_REQUESTS,
                "Too many PIN attempts. Try again later.".to_string(),
            ));
        }

        match pin {
            Some(pin) if pin == required => {
                attempts.pop(&ip);
                Ok(())
            }
            Some(_) => {
                attempts.put(ip, count + 1);
                Err(AppError::Message(
                    StatusCode::UNAUTHORIZED,
                    "Invalid PIN".to_string(),
                ))
            }
            None => Err(AppError::Message(
                StatusCode::UNAUTHORIZED,
                "PIN required".to_string(),
            )),
        }
    }
}

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct SessionRequest {
    session_id: Option<String>,
    token: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct HeartbeatResponse {
    ok: bool,
    heartbeat_interval_ms: u64,
    offers: Vec<OfferView>,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
struct OfferView {
    offer_id: String,
    created_at_ms: u64,
    files: Vec<OfferViewFile>,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
struct OfferViewFile {
    id: String,
    file_name: String,
    size: u64,
    file_type: String,
}

pub(crate) async fn heartbeat(
    req: Request<Incoming>,
    state: AppState,
    _client_info: RequestClientInfo,
) -> Result<Response<BoxedBody>, AppError> {
    let Some(browser) = state.browser.clone() else {
        return Err(AppError::Message(
            StatusCode::NOT_FOUND,
            "Browser sharing is not enabled.".to_string(),
        ));
    };
    validate_origin(&req)?;
    let body: SessionRequest = collect_json(req).await?;
    let session_id = body
        .session_id
        .ok_or_else(|| AppError::BadRequest("Missing sessionId.".to_string()))?;
    let token = body
        .token
        .ok_or_else(|| AppError::BadRequest("Missing token.".to_string()))?;

    let (snapshot, was_connected, offers) = {
        let mut sessions = browser.sessions.lock().await;
        let Some(session) = sessions.get_mut(&session_id) else {
            return Err(AppError::Message(
                StatusCode::UNAUTHORIZED,
                "Unknown session.".to_string(),
            ));
        };
        if !tokens_equal(&session.token, &token) {
            // Count failed session auth as a PIN-like attempt to slow down
            // token guessing over the LAN.
            let mut attempts = browser.pin_attempts.lock().await;
            let count = attempts.get(&session.ip.ip).copied().unwrap_or(0);
            attempts.put(session.ip.ip, count + 1);
            return Err(AppError::Message(
                StatusCode::UNAUTHORIZED,
                "Invalid session token.".to_string(),
            ));
        }

        let was_connected = session.connected;
        session.last_seen = Instant::now();
        session.connected = true;
        let snapshot = session.clone();

        let offers = browser
            .offers
            .lock()
            .await
            .values()
            .filter(|offer| offer.session_id == session_id && offer.accepted)
            .map(|offer| OfferView {
                offer_id: offer.offer_id.clone(),
                created_at_ms: offer.created_at_ms,
                files: offer
                    .files
                    .values()
                    .map(|file| OfferViewFile {
                        id: file.id.clone(),
                        file_name: file.file_name.clone(),
                        size: file.size,
                        file_type: file.file_type.clone(),
                    })
                    .collect(),
            })
            .collect();

        (snapshot, was_connected, offers)
    };

    if !was_connected {
        browser.emit_session_changed(&snapshot).await;
    }

    Ok(JsonResponse {
        status: StatusCode::OK,
        body: HeartbeatResponse {
            ok: true,
            heartbeat_interval_ms: browser.heartbeat_interval().as_millis() as u64,
            offers,
        },
    }
    .into_response())
}

/// Establishes the server-sent event stream of a session.
pub(crate) async fn events(
    req: Request<Incoming>,
    state: AppState,
    _client_info: RequestClientInfo,
) -> Result<Response<BoxedBody>, AppError> {
    let Some(browser) = state.browser.clone() else {
        return Err(AppError::Message(
            StatusCode::NOT_FOUND,
            "Browser sharing is not enabled.".to_string(),
        ));
    };

    let query = req.uri().query().unwrap_or_default();
    let query: HashMap<String, String> = form_urlencoded::parse(query.as_bytes())
        .map(|(key, value)| (key.into_owned(), value.into_owned()))
        .collect();
    let session_id = query
        .get("sessionId")
        .ok_or_else(|| AppError::BadRequest("Missing sessionId.".to_string()))?
        .clone();
    let token = query
        .get("token")
        .ok_or_else(|| AppError::BadRequest("Missing token.".to_string()))?
        .clone();

    let (generation, snapshot, receiver) = {
        let mut sessions = browser.sessions.lock().await;
        let Some(session) = sessions.get_mut(&session_id) else {
            return Err(AppError::Message(
                StatusCode::UNAUTHORIZED,
                "Unknown session.".to_string(),
            ));
        };
        if !tokens_equal(&session.token, &token) {
            return Err(AppError::Message(
                StatusCode::UNAUTHORIZED,
                "Invalid session token.".to_string(),
            ));
        }

        let (tx, rx) = mpsc::channel::<Bytes>(64);
        let generation = session
            .sse
            .as_ref()
            .map(|sse| sse.generation + 1)
            .unwrap_or(1);
        session.sse = Some(SseConnection { generation, tx });
        session.connected = true;
        session.last_seen = Instant::now();
        (generation, session.clone(), rx)
    };

    browser.emit_session_changed(&snapshot).await;

    // Ping task. The body stream owns the receiver, so a send failure means the
    // browser went away (tab closed, network lost, page reload).
    {
        let browser = browser.clone();
        let session_id = session_id.clone();
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(SSE_PING_INTERVAL).await;
                let Some(sse) = browser.current_sse(&session_id, generation).await else {
                    break;
                };
                if sse
                    .tx
                    .send(Bytes::from_static(b": ping\n\n"))
                    .await
                    .is_err()
                {
                    browser.session_sse_closed(&session_id, generation).await;
                    break;
                }
                // Keep the session alive as long as the SSE stream is healthy;
                // the heartbeat endpoint is still the primary liveness signal.
                browser.touch(&session_id).await;
            }
        });
    }

    // Send the initial event so the page can consider itself connected without
    // waiting for the first ping.
    let alias = state.info.lock().await.alias.clone();
    let initial = serde_json::json!({
        "sessionId": snapshot.session_id,
        "alias": alias,
        "heartbeatIntervalMs": browser.heartbeat_interval().as_millis() as u64,
    });
    let initial = format!(
        "event: connected\ndata: {}\n\n",
        serde_json::to_string(&initial).unwrap_or_default()
    );

    let stream =
        ReceiverStream::new(receiver).map(move |chunk| Ok::<_, std::io::Error>(Frame::data(chunk)));
    let stream = tokio_stream::once(Ok::<_, std::io::Error>(Frame::data(Bytes::from(initial))))
        .chain(stream);
    let body = StreamBody::new(stream).boxed();

    let mut response = Response::new(body);
    let headers = response.headers_mut();
    headers.insert(
        http::header::CONTENT_TYPE,
        http::HeaderValue::from_static("text/event-stream; charset=utf-8"),
    );
    headers.insert(
        http::header::CACHE_CONTROL,
        http::HeaderValue::from_static("no-cache, no-transform"),
    );
    headers.insert(
        http::header::CONNECTION,
        http::HeaderValue::from_static("keep-alive"),
    );
    headers.insert(
        http::header::HeaderName::from_static("x-accel-buffering"),
        http::HeaderValue::from_static("no"),
    );

    Ok(response)
}

impl BrowserState {
    async fn current_sse(&self, session_id: &str, generation: u64) -> Option<SseConnection> {
        let sessions = self.sessions.lock().await;
        sessions.get(session_id).and_then(|session| {
            session.sse.as_ref().and_then(|sse| {
                if sse.generation == generation {
                    Some(SseConnection {
                        generation,
                        tx: sse.tx.clone(),
                    })
                } else {
                    None
                }
            })
        })
    }

    async fn session_sse_closed(&self, session_id: &str, generation: u64) {
        let snapshot = {
            let mut sessions = self.sessions.lock().await;
            let Some(session) = sessions.get_mut(session_id) else {
                return;
            };
            if session.sse.as_ref().map(|sse| sse.generation) != Some(generation) {
                return;
            }
            session.sse = None;
            session.clone()
        };
        self.emit_session_changed(&snapshot).await;
    }

    async fn touch(&self, session_id: &str) {
        let mut sessions = self.sessions.lock().await;
        if let Some(session) = sessions.get_mut(session_id) {
            session.last_seen = Instant::now();
            session.connected = true;
        }
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct OfferResponseRequest {
    session_id: String,
    token: String,
    offer_id: String,
    accept: bool,
}

pub(crate) async fn offer_response(
    req: Request<Incoming>,
    state: AppState,
    _client_info: RequestClientInfo,
) -> Result<Response<BoxedBody>, AppError> {
    let Some(browser) = state.browser.clone() else {
        return Err(AppError::Message(
            StatusCode::NOT_FOUND,
            "Browser sharing is not enabled.".to_string(),
        ));
    };
    validate_origin(&req)?;
    let body: OfferResponseRequest = collect_json(req).await?;

    let session = browser
        .session_by_token(&body.session_id, &body.token)
        .await
        .ok_or_else(|| {
            AppError::Message(StatusCode::UNAUTHORIZED, "Invalid session.".to_string())
        })?;

    {
        let mut offers = browser.offers.lock().await;
        let Some(offer) = offers.get_mut(&body.offer_id) else {
            return Err(AppError::Message(
                StatusCode::NOT_FOUND,
                "Unknown offer.".to_string(),
            ));
        };
        if offer.session_id != session.session_id {
            return Err(AppError::Message(
                StatusCode::FORBIDDEN,
                "Offer belongs to another session.".to_string(),
            ));
        }
        offer.accepted = body.accept;
    }

    if !body.accept {
        browser.offers.lock().await.remove(&body.offer_id);
    }

    let _ = browser
        .config
        .event_tx
        .send(BrowserEvent::OfferResponse {
            offer_id: body.offer_id,
            session_id: session.session_id,
            accepted: body.accept,
        })
        .await;

    Ok(JsonResponse {
        status: StatusCode::OK,
        body: serde_json::json!({ "ok": true, "accepted": body.accept }),
    }
    .into_response())
}

pub(crate) async fn download(
    req: Request<Incoming>,
    state: AppState,
    _client_info: RequestClientInfo,
) -> Result<Response<BoxedBody>, AppError> {
    let Some(browser) = state.browser.clone() else {
        return Err(AppError::Message(
            StatusCode::NOT_FOUND,
            "Browser sharing is not enabled.".to_string(),
        ));
    };

    let query: HashMap<String, String> =
        form_urlencoded::parse(req.uri().query().unwrap_or_default().as_bytes())
            .map(|(key, value)| (key.into_owned(), value.into_owned()))
            .collect();

    let session_id = query
        .get("sessionId")
        .ok_or_else(|| AppError::BadRequest("Missing sessionId.".to_string()))?
        .clone();
    let token = download_token(&req, &session_id, &query).ok_or_else(|| {
        AppError::Message(
            StatusCode::UNAUTHORIZED,
            "Missing download authorization.".to_string(),
        )
    })?;
    let offer_id = query
        .get("offerId")
        .ok_or_else(|| AppError::BadRequest("Missing offerId.".to_string()))?
        .clone();
    let file_id = query
        .get("fileId")
        .ok_or_else(|| AppError::BadRequest("Missing fileId.".to_string()))?
        .clone();

    let session = browser
        .session_by_token(&session_id, &token)
        .await
        .ok_or_else(|| {
            AppError::Message(StatusCode::UNAUTHORIZED, "Invalid session.".to_string())
        })?;

    let (file, cached_path) = {
        let offers = browser.offers.lock().await;
        let Some(offer) = offers.get(&offer_id) else {
            return Err(AppError::Message(
                StatusCode::NOT_FOUND,
                "Unknown offer.".to_string(),
            ));
        };
        if offer.session_id != session.session_id {
            return Err(AppError::Message(
                StatusCode::FORBIDDEN,
                "Offer belongs to another session.".to_string(),
            ));
        }
        if !offer.accepted {
            return Err(AppError::Message(
                StatusCode::FORBIDDEN,
                "The offer has not been accepted.".to_string(),
            ));
        }
        let file =
            offer.files.get(&file_id).cloned().ok_or_else(|| {
                AppError::Message(StatusCode::NOT_FOUND, "Unknown file.".to_string())
            })?;
        (file, offer.resolved_paths.get(&file_id).cloned())
    };

    let etag = file_etag(&file);
    let requested_range = if if_range_matches(&req, &etag) {
        match parse_range(req.headers().get(http::header::RANGE), file.size) {
            Ok(range) => range,
            Err(()) => return Ok(range_not_satisfiable(file.size, &etag)),
        }
    } else {
        None
    };
    let (offset, length) = requested_range
        .map(|range| (range.start, range.end - range.start + 1))
        .unwrap_or((0, file.size));

    if req.method() == Method::HEAD {
        return download_response(full_body(Bytes::new()), &file, requested_range, &etag);
    }

    let permit = browser
        .download_slots
        .clone()
        .acquire_owned()
        .await
        .map_err(|_| AppError::Status(StatusCode::SERVICE_UNAVAILABLE))?;

    let content = match cached_path {
        Some(path) => FileContent::Path(path),
        None => {
            let (content_tx, content_rx) = oneshot::channel::<FileContent>();
            let event = BrowserEvent::DownloadRequested {
                session_id: session.session_id.clone(),
                offer_id: offer_id.clone(),
                file_id: file_id.clone(),
                file: file.clone(),
                content_tx,
            };
            if browser.config.event_tx.send(event).await.is_err() {
                return Err(AppError::Status(StatusCode::INTERNAL_SERVER_ERROR));
            }

            let resolved = content_rx
                .await
                .map_err(|_| AppError::Status(StatusCode::INTERNAL_SERVER_ERROR))?;

            if let FileContent::Path(ref path) = resolved {
                let mut offers = browser.offers.lock().await;
                if let Some(offer) = offers.get_mut(&offer_id) {
                    offer.resolved_paths.insert(file_id.clone(), path.clone());
                }
            }
            resolved
        }
    };

    let download_id = uuid::Uuid::new_v4().to_string();
    let cancel = CancellationToken::new();
    browser.active_downloads.lock().await.insert(
        download_id.clone(),
        ActiveBrowserDownload {
            session_id: session.session_id.clone(),
            offer_id: offer_id.clone(),
            cancel: cancel.clone(),
        },
    );
    let body = browser_stream_body(
        content.into_range_receiver(offset, length),
        BrowserStreamConfig {
            browser: browser.clone(),
            session_id: session.session_id.clone(),
            offer_id,
            file_id,
            total: file.size,
            offset,
            expected: length,
            permit,
            download_id,
            cancel,
        },
    );

    download_response(body, &file, requested_range, &etag)
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) struct ByteRange {
    pub(crate) start: u64,
    pub(crate) end: u64,
}

pub(crate) fn parse_range(
    value: Option<&http::HeaderValue>,
    size: u64,
) -> Result<Option<ByteRange>, ()> {
    let Some(value) = value else {
        return Ok(None);
    };
    let value = value.to_str().map_err(|_| ())?;
    let spec = value.strip_prefix("bytes=").ok_or(())?;
    if spec.contains(',') || spec.is_empty() || size == 0 {
        return Err(());
    }
    let (start, end) = spec.split_once('-').ok_or(())?;
    let range = if start.is_empty() {
        let suffix = end.parse::<u64>().map_err(|_| ())?;
        if suffix == 0 {
            return Err(());
        }
        ByteRange {
            start: size.saturating_sub(suffix),
            end: size - 1,
        }
    } else {
        let start = start.parse::<u64>().map_err(|_| ())?;
        if start >= size {
            return Err(());
        }
        let end = if end.is_empty() {
            size - 1
        } else {
            end.parse::<u64>().map_err(|_| ())?.min(size - 1)
        };
        if end < start {
            return Err(());
        }
        ByteRange { start, end }
    };
    Ok(Some(range))
}

pub(crate) fn if_range_matches(req: &Request<Incoming>, etag: &str) -> bool {
    req.headers()
        .get(http::header::IF_RANGE)
        .and_then(|value| value.to_str().ok())
        .is_none_or(|value| value.trim() == etag)
}

pub(crate) fn file_etag(file: &FileDto) -> String {
    let mut digest = Sha256::new();
    digest.update(file.id.as_bytes());
    digest.update(file.size.to_be_bytes());
    if let Some(hash) = &file.sha256 {
        digest.update(hash.as_bytes());
    }
    if let Some(modified) = file
        .metadata
        .as_ref()
        .and_then(|metadata| metadata.modified.as_deref())
    {
        digest.update(modified.as_bytes());
    }
    let mut hex = String::with_capacity(64);
    for byte in digest.finalize() {
        write!(&mut hex, "{byte:02x}").expect("writing to a String cannot fail");
    }
    format!("\"{hex}\"")
}

fn download_token(
    req: &Request<Incoming>,
    session_id: &str,
    query: &HashMap<String, String>,
) -> Option<String> {
    if let Some(token) = query.get("token") {
        return Some(token.clone());
    }
    let cookies = req.headers().get(http::header::COOKIE)?.to_str().ok()?;
    let value = cookies.split(';').find_map(|cookie| {
        let (name, value) = cookie.trim().split_once('=')?;
        (name == DOWNLOAD_COOKIE).then_some(value)
    })?;
    let (cookie_session, token) = value.split_once('.')?;
    (cookie_session == session_id).then(|| token.to_string())
}

pub(crate) fn download_response(
    body: BoxedBody,
    file: &FileDto,
    range: Option<ByteRange>,
    etag: &str,
) -> Result<Response<BoxedBody>, AppError> {
    let file_name = sanitize_file_name(&file.file_name);
    let fallback: String = file_name
        .chars()
        .map(|character| {
            if character.is_ascii() && character != '"' && character != '\\' {
                character
            } else {
                '_'
            }
        })
        .collect();
    let encoded = percent_encoding::utf8_percent_encode(&file_name, FILE_NAME_ENCODE_SET);
    let length = range
        .map(|range| range.end - range.start + 1)
        .unwrap_or(file.size);

    let mut response = Response::new(body);
    if range.is_some() {
        *response.status_mut() = StatusCode::PARTIAL_CONTENT;
    }
    let headers = response.headers_mut();
    headers.insert(
        http::header::CONTENT_TYPE,
        http::HeaderValue::from_static("application/octet-stream"),
    );
    headers.insert(
        http::header::CONTENT_DISPOSITION,
        http::HeaderValue::from_str(&format!(
            "attachment; filename=\"{fallback}\"; filename*=UTF-8''{encoded}"
        ))
        .map_err(|_| AppError::Status(StatusCode::INTERNAL_SERVER_ERROR))?,
    );
    headers.insert(
        http::header::CONTENT_LENGTH,
        http::HeaderValue::from(length),
    );
    headers.insert(
        http::header::ACCEPT_RANGES,
        http::HeaderValue::from_static("bytes"),
    );
    headers.insert(
        http::header::ETAG,
        http::HeaderValue::from_str(etag)
            .map_err(|_| AppError::Status(StatusCode::INTERNAL_SERVER_ERROR))?,
    );
    headers.insert(
        http::header::CACHE_CONTROL,
        http::HeaderValue::from_static("private, no-store"),
    );
    headers.insert(
        http::header::HeaderName::from_static("x-content-type-options"),
        http::HeaderValue::from_static("nosniff"),
    );
    if let Some(range) = range {
        headers.insert(
            http::header::CONTENT_RANGE,
            http::HeaderValue::from_str(&format!(
                "bytes {}-{}/{}",
                range.start, range.end, file.size
            ))
            .map_err(|_| AppError::Status(StatusCode::INTERNAL_SERVER_ERROR))?,
        );
    }
    Ok(response)
}

pub(crate) fn range_not_satisfiable(size: u64, etag: &str) -> Response<BoxedBody> {
    let mut response = Response::new(full_body(Bytes::new()));
    *response.status_mut() = StatusCode::RANGE_NOT_SATISFIABLE;
    response.headers_mut().insert(
        http::header::ACCEPT_RANGES,
        http::HeaderValue::from_static("bytes"),
    );
    response.headers_mut().insert(
        http::header::CONTENT_RANGE,
        http::HeaderValue::from_str(&format!("bytes */{size}")).expect("valid content range"),
    );
    response.headers_mut().insert(
        http::header::ETAG,
        http::HeaderValue::from_str(etag).expect("valid etag"),
    );
    response
}

/// Characters that are percent-encoded in the content-disposition file name.
/// Matches the component encoding of RFC 2396 (letters, digits and marks are kept).
const FILE_NAME_ENCODE_SET: &percent_encoding::AsciiSet = &percent_encoding::NON_ALPHANUMERIC
    .remove(b'-')
    .remove(b'_')
    .remove(b'.')
    .remove(b'!')
    .remove(b'~')
    .remove(b'*')
    .remove(b'\'')
    .remove(b'(')
    .remove(b')');

/// Keeps the downloaded file name local to the download directory: no path
/// separators, no traversal, no control characters, bounded length.
pub fn sanitize_file_name(name: &str) -> String {
    let sanitized: Vec<String> = name
        .split(['/', '\\'])
        .filter_map(|segment| {
            let seg = segment.trim();
            if seg.is_empty() || seg == "." || seg == ".." {
                None
            } else {
                let cleaned: String = seg
                    .chars()
                    .map(|character| match character {
                        character if character.is_control() => '-',
                        character => character,
                    })
                    .collect();
                Some(cleaned)
            }
        })
        .collect();

    let mut cleaned = if sanitized.is_empty() {
        "download".to_string()
    } else {
        sanitized.join("-")
    };

    while cleaned.contains("..") {
        cleaned = cleaned.replace("..", ".");
    }

    cleaned = cleaned.trim().trim_matches(['.', '-', ' ']).to_string();
    if cleaned.is_empty() {
        cleaned = "download".to_string();
    }

    // Keep the extension visible while bounding the header size.
    if cleaned.chars().count() > 180 {
        cleaned = cleaned.chars().take(180).collect();
    }

    cleaned
}

struct BrowserProgressStream {
    inner: ReceiverStream<Bytes>,
    cancelled: Pin<Box<WaitForCancellationFutureOwned>>,
    browser: Arc<BrowserState>,
    session_id: String,
    offer_id: String,
    file_id: String,
    total: u64,
    offset: u64,
    expected: u64,
    sent: u64,
    last_progress: Option<Instant>,
    finished: bool,
    _permit: OwnedSemaphorePermit,
    download_id: String,
}

impl Stream for BrowserProgressStream {
    type Item = Result<Frame<Bytes>, std::io::Error>;

    fn poll_next(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        if self.cancelled.as_mut().poll(cx).is_ready() {
            return Poll::Ready(None);
        }
        match Pin::new(&mut self.inner).poll_next(cx) {
            Poll::Pending => Poll::Pending,
            Poll::Ready(Some(chunk)) => {
                self.sent += chunk.len() as u64;
                let downloaded = (self.offset + self.sent).min(self.total);
                let now = Instant::now();
                let should_emit = self
                    .last_progress
                    .is_none_or(|last| now.duration_since(last) >= Duration::from_millis(100));
                if should_emit || self.sent >= self.expected {
                    self.last_progress = Some(now);
                    let _ = self
                        .browser
                        .config
                        .event_tx
                        .try_send(BrowserEvent::DownloadProgress {
                            session_id: self.session_id.clone(),
                            offer_id: self.offer_id.clone(),
                            file_id: self.file_id.clone(),
                            downloaded_bytes: downloaded,
                            total_bytes: self.total,
                        });
                }
                if downloaded >= self.total && self.sent >= self.expected && !self.finished {
                    self.finished = true;
                    let _ = self
                        .browser
                        .config
                        .event_tx
                        .try_send(BrowserEvent::DownloadFinished {
                            session_id: self.session_id.clone(),
                            offer_id: self.offer_id.clone(),
                            file_id: self.file_id.clone(),
                        });
                }
                Poll::Ready(Some(Ok(Frame::data(chunk))))
            }
            Poll::Ready(None) => {
                if !self.finished
                    && self.sent >= self.expected
                    && self.offset + self.sent >= self.total
                {
                    self.finished = true;
                    let _ = self
                        .browser
                        .config
                        .event_tx
                        .try_send(BrowserEvent::DownloadProgress {
                            session_id: self.session_id.clone(),
                            offer_id: self.offer_id.clone(),
                            file_id: self.file_id.clone(),
                            downloaded_bytes: self.total,
                            total_bytes: self.total,
                        });
                    let _ = self
                        .browser
                        .config
                        .event_tx
                        .try_send(BrowserEvent::DownloadFinished {
                            session_id: self.session_id.clone(),
                            offer_id: self.offer_id.clone(),
                            file_id: self.file_id.clone(),
                        });
                }
                Poll::Ready(None)
            }
        }
    }
}

impl Drop for BrowserProgressStream {
    fn drop(&mut self) {
        let browser = self.browser.clone();
        let download_id = self.download_id.clone();
        tokio::spawn(async move {
            browser.active_downloads.lock().await.remove(&download_id);
        });
    }
}

struct BrowserStreamConfig {
    browser: Arc<BrowserState>,
    session_id: String,
    offer_id: String,
    file_id: String,
    total: u64,
    offset: u64,
    expected: u64,
    permit: OwnedSemaphorePermit,
    download_id: String,
    cancel: CancellationToken,
}

fn browser_stream_body(receiver: mpsc::Receiver<Bytes>, config: BrowserStreamConfig) -> BoxedBody {
    let stream = BrowserProgressStream {
        inner: ReceiverStream::new(receiver),
        cancelled: Box::pin(config.cancel.cancelled_owned()),
        browser: config.browser,
        session_id: config.session_id,
        offer_id: config.offer_id,
        file_id: config.file_id,
        total: config.total,
        offset: config.offset,
        expected: config.expected,
        sent: 0,
        last_progress: None,
        finished: false,
        _permit: config.permit,
        download_id: config.download_id,
    };
    StreamBody::new(stream).boxed()
}

impl BrowserState {
    /// Creates an offer and pushes it to the browser over SSE.
    pub(crate) async fn create_offer(
        &self,
        session_id: &str,
        offer_id: &str,
        files: HashMap<String, FileDto>,
    ) -> anyhow::Result<()> {
        if files.is_empty() {
            anyhow::bail!("Cannot create an offer without files");
        }

        let session = {
            let sessions = self.sessions.lock().await;
            let session = sessions
                .get(session_id)
                .ok_or_else(|| anyhow::anyhow!("Unknown browser session"))?;
            if !session.connected || session.sse.is_none() {
                anyhow::bail!("The browser is not connected");
            }
            session.clone()
        };

        {
            let mut offers = self.offers.lock().await;
            if offers.contains_key(offer_id) {
                anyhow::bail!("Offer already exists");
            }
            if offers.len() >= MAX_OFFERS {
                // Pending offers are the ones the application is waiting on.
                // Drop those of disconnected sessions first, then the oldest.
                let Some(oldest_pending) = offers
                    .values()
                    .filter(|offer| !offer.accepted)
                    .min_by_key(|offer| offer.created_at_ms)
                    .map(|offer| offer.offer_id.clone())
                else {
                    anyhow::bail!("Too many pending offers");
                };
                offers.remove(&oldest_pending);
            }
            offers.insert(
                offer_id.to_string(),
                BrowserOffer {
                    offer_id: offer_id.to_string(),
                    session_id: session_id.to_string(),
                    files: files.clone(),
                    resolved_paths: HashMap::new(),
                    accepted: false,
                    created_at_ms: now_ms(),
                },
            );
        }

        let view = OfferView {
            offer_id: offer_id.to_string(),
            created_at_ms: now_ms(),
            files: files
                .values()
                .map(|file| OfferViewFile {
                    id: file.id.clone(),
                    file_name: file.file_name.clone(),
                    size: file.size,
                    file_type: file.file_type.clone(),
                })
                .collect(),
        };

        if self.send_sse(&session, "offer", &view).is_err() {
            self.offers.lock().await.remove(offer_id);
            anyhow::bail!("The browser connection is not available");
        }

        Ok(())
    }

    pub(crate) async fn cancel_offer(&self, offer_id: &str) -> bool {
        let Some(offer) = self.offers.lock().await.remove(offer_id) else {
            return false;
        };
        for active in self.active_downloads.lock().await.values() {
            if active.offer_id == offer_id {
                active.cancel.cancel();
            }
        }
        let sessions = self.sessions.lock().await;
        if let Some(session) = sessions.get(&offer.session_id) {
            let _ = self.send_sse(
                session,
                "offer_cancelled",
                &serde_json::json!({ "offerId": offer_id }),
            );
        }
        true
    }

    pub(crate) async fn disconnect_session(&self, session_id: &str) -> bool {
        let existed = self.sessions.lock().await.remove(session_id).is_some();
        if existed {
            self.offers
                .lock()
                .await
                .retain(|_, offer| offer.session_id != session_id);
            for active in self.active_downloads.lock().await.values() {
                if active.session_id == session_id {
                    active.cancel.cancel();
                }
            }
            let _ = self.config.event_tx.try_send(BrowserEvent::SessionClosed {
                session_id: session_id.to_string(),
                reason: BrowserSessionEndReason::Removed,
            });
        }
        existed
    }

    pub(crate) async fn shutdown(&self) {
        for active in self.active_downloads.lock().await.values() {
            active.cancel.cancel();
        }
        let sessions = {
            let mut sessions = self.sessions.lock().await;
            let ids: Vec<String> = sessions.keys().cloned().collect();
            sessions.clear();
            ids
        };
        self.offers.lock().await.clear();
        for session_id in sessions {
            let _ = self.config.event_tx.try_send(BrowserEvent::SessionClosed {
                session_id,
                reason: BrowserSessionEndReason::Removed,
            });
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_browsers_in_the_right_order() {
        assert_eq!(
            browser_name_from_user_agent(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36 Edg/120.0"
            ),
            Some("Edge")
        );
        assert_eq!(
            browser_name_from_user_agent(
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
            ),
            Some("Chrome")
        );
        assert_eq!(
            browser_name_from_user_agent(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
            ),
            Some("Safari")
        );
        assert_eq!(
            browser_name_from_user_agent(
                "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0"
            ),
            Some("Firefox")
        );
    }

    #[test]
    fn detects_device_types() {
        assert_eq!(
            device_type_from_user_agent(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
            ),
            BrowserDeviceType::Mobile
        );
        assert_eq!(
            device_type_from_user_agent(
                "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
            ),
            BrowserDeviceType::Tablet
        );
        assert_eq!(
            device_type_from_user_agent(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            ),
            BrowserDeviceType::Desktop
        );
    }

    #[test]
    fn sanitizes_file_names() {
        assert_eq!(sanitize_file_name("../../etc/passwd"), "etc-passwd");
        assert_eq!(sanitize_file_name("folder\\file.txt"), "folder-file.txt");
        assert_eq!(sanitize_file_name("bad\u{0}name.txt"), "bad-name.txt");
        assert_eq!(sanitize_file_name("   "), "download");
        assert_eq!(sanitize_file_name(".bashrc"), "bashrc");
    }

    #[test]
    fn compares_tokens_in_constant_time() {
        assert!(tokens_equal("abcdef", "abcdef"));
        assert!(!tokens_equal("abcdef", "abcde"));
        assert!(!tokens_equal("abcdef", "abcdeg"));
    }

    #[test]
    fn parses_single_byte_ranges_with_64_bit_offsets() {
        let header = http::HeaderValue::from_static("bytes=4294967296-4294967395");
        assert_eq!(
            parse_range(Some(&header), 5_368_709_120),
            Ok(Some(ByteRange {
                start: 4_294_967_296,
                end: 4_294_967_395,
            }))
        );

        let open_ended = http::HeaderValue::from_static("bytes=1048576-");
        assert_eq!(
            parse_range(Some(&open_ended), 2_000_000),
            Ok(Some(ByteRange {
                start: 1_048_576,
                end: 1_999_999,
            }))
        );

        let suffix = http::HeaderValue::from_static("bytes=-512");
        assert_eq!(
            parse_range(Some(&suffix), 2_000),
            Ok(Some(ByteRange {
                start: 1_488,
                end: 1_999,
            }))
        );
    }

    #[test]
    fn rejects_invalid_or_unsatisfiable_ranges() {
        for value in [
            "bytes=2000-",
            "bytes=100-99",
            "bytes=0-1,4-5",
            "items=0-1",
            "bytes=-0",
        ] {
            let header = http::HeaderValue::from_str(value).unwrap();
            assert_eq!(parse_range(Some(&header), 1_000), Err(()), "{value}");
        }
    }
}
