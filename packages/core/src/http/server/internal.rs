use crate::http::server::AppState;
use crate::http::server::common::error::AppError;
use crate::http::server::common::query::parse_query;
use crate::http::server::common::response::{BoxedBody, empty_body};
use http_body_util::BodyExt;
use hyper::body::Incoming;
use hyper::{Request, Response, StatusCode};
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc;

/// Configuration for application-internal endpoints.
pub struct InternalConfig {
    /// Token required by the show route.
    pub show_token: String,

    /// Channel on which the server emits internal events to the application.
    pub event_tx: mpsc::Sender<InternalEvent>,
}

/// Events emitted by application-internal endpoints.
#[derive(Debug)]
pub enum InternalEvent {
    /// Another application instance requested the running application to show itself.
    Show {
        /// Command-line arguments forwarded by the other application instance.
        args: Vec<String>,
    },
    /// An authenticated local peer submitted a chat protocol envelope.
    Chat {
        sender_fingerprint: String,
        envelope: ChatEnvelope,
    },
}

/// Versioned, bounded application-to-application chat message. File payloads
/// are never carried here; attachment messages contain transfer metadata only.
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ChatEnvelope {
    pub protocol_version: u8,
    pub kind: String,
    pub message_id: String,
    pub conversation_id: String,
    pub sender_id: String,
    pub receiver_id: String,
    pub timestamp: i64,
    #[serde(default)]
    pub content_type: Option<String>,
    #[serde(default)]
    pub content: Option<String>,
    #[serde(default)]
    pub related_message_id: Option<String>,
}

pub(crate) struct InternalState {
    show_token: String,
    event_tx: mpsc::Sender<InternalEvent>,
}

impl InternalState {
    pub(crate) fn new(config: InternalConfig) -> Self {
        Self {
            show_token: config.show_token,
            event_tx: config.event_tx,
        }
    }
}

#[derive(Default, Deserialize)]
struct ShowRequest {
    #[serde(default)]
    args: Vec<String>,
}

pub(crate) async fn show(
    req: Request<Incoming>,
    state: AppState,
) -> Result<Response<BoxedBody>, AppError> {
    let Some(internal) = &state.internal else {
        return Err(AppError::Status(StatusCode::NOT_FOUND));
    };

    let query = parse_query(req.uri().query());
    if query.get("token") != Some(&internal.show_token) {
        return Err(AppError::Message(
            StatusCode::FORBIDDEN,
            "Invalid token".to_string(),
        ));
    }

    let body = req.into_body().collect().await?.to_bytes();
    let payload = if body.is_empty() {
        ShowRequest::default()
    } else {
        serde_json::from_slice::<ShowRequest>(&body).map_err(|err| {
            tracing::warn!("Failed to parse show request body: {err:#}");
            AppError::BadRequest("Invalid JSON body".to_string())
        })?
    };

    let _ = internal
        .event_tx
        .send(InternalEvent::Show { args: payload.args })
        .await;

    let mut response = Response::new(empty_body());
    *response.status_mut() = StatusCode::OK;
    Ok(response)
}

pub(crate) async fn chat(
    req: Request<Incoming>,
    state: AppState,
    sender_fingerprint: Option<String>,
) -> Result<Response<BoxedBody>, AppError> {
    let Some(internal) = &state.internal else {
        return Err(AppError::Status(StatusCode::NOT_FOUND));
    };

    let body = req.into_body().collect().await?.to_bytes();
    if body.is_empty() || body.len() > 64 * 1024 {
        return Err(AppError::BadRequest(
            "Invalid chat envelope size".to_string(),
        ));
    }
    let envelope: ChatEnvelope = serde_json::from_slice(&body)
        .map_err(|_| AppError::BadRequest("Invalid chat envelope".to_string()))?;

    let sender_id_upper = envelope.sender_id.trim().to_ascii_uppercase();
    let sender_fingerprint = match sender_fingerprint {
        Some(cert_fp) => {
            if sender_id_upper != cert_fp {
                return Err(AppError::BadRequest(
                    "Invalid chat envelope fields".to_string(),
                ));
            }
            cert_fp
        }
        None => {
            if sender_id_upper.is_empty() || sender_id_upper.len() > 128 {
                return Err(AppError::BadRequest(
                    "Invalid chat envelope fields".to_string(),
                ));
            }
            sender_id_upper
        }
    };

    if envelope.protocol_version != 1
        || envelope.message_id.is_empty()
        || envelope.message_id.len() > 128
        || envelope.conversation_id.is_empty()
        || envelope.conversation_id.len() > 256
        || envelope.receiver_id.is_empty()
        || !matches!(
            envelope.kind.as_str(),
            "chat.message" | "chat.delivered" | "chat.read" | "chat.typing" | "chat.attachment"
        )
        || envelope
            .content
            .as_ref()
            .is_some_and(|value| value.len() > 32 * 1024)
    {
        return Err(AppError::BadRequest(
            "Invalid chat envelope fields".to_string(),
        ));
    }

    internal
        .event_tx
        .send(InternalEvent::Chat {
            sender_fingerprint,
            envelope,
        })
        .await
        .map_err(|_| AppError::Status(StatusCode::SERVICE_UNAVAILABLE))?;

    let mut response = Response::new(empty_body());
    *response.status_mut() = StatusCode::ACCEPTED;
    Ok(response)
}
