#![cfg(feature = "http")]

use bytes::Bytes;
use futures_util::StreamExt;
use localsend::http::server::browser::{
    BrowserConfig, BrowserDeviceType, BrowserEvent, BrowserSessionEndReason,
};
use localsend::http::server::web::{WebConfig, WebI18n, WebPages};
use localsend::http::server::{start_with_port, ServerHandle};
use localsend::http::state::ClientInfo;
use localsend::model::transfer::{FileContent, FileDto};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::time::Duration;
use tokio::sync::{mpsc, oneshot};

const TIMEOUT: Duration = Duration::from_secs(5);

struct TestServer {
    port: u16,
    handle: ServerHandle,
    events: mpsc::Receiver<BrowserEvent>,
    _stop_tx: oneshot::Sender<()>,
}

impl TestServer {
    fn url(&self, path: &str) -> String {
        format!("http://127.0.0.1:{}{path}", self.port)
    }

    fn client(&self) -> reqwest::Client {
        reqwest::Client::builder()
            .timeout(TIMEOUT)
            .build()
            .expect("Failed to build HTTP client")
    }

    async fn next_event(&mut self) -> BrowserEvent {
        tokio::time::timeout(TIMEOUT, self.events.recv())
            .await
            .expect("Timed out waiting for a browser event")
            .expect("Browser event channel closed")
    }
}

async fn start_test_server(pin: Option<&str>, upload: bool) -> TestServer {
    let _ = tracing_subscriber::fmt().with_test_writer().try_init();

    let (event_tx, events) = mpsc::channel::<BrowserEvent>(64);
    let web_config = WebConfig {
        send: None,
        upload,
        i18n: WebI18n::default(),
        pages: WebPages::default(),
        browser: Some(BrowserConfig::new(pin.map(str::to_string), event_tx)),
    };

    let (stop_tx, stop_rx) = oneshot::channel::<()>();
    let handle = start_with_port(
        0,
        None,
        ClientInfo {
            alias: "Test Server".to_string(),
            version: "2.2".to_string(),
            device_model: Some("Rust".to_string()),
            device_type: None,
            token: "server-fingerprint".to_string(),
        },
        None,
        None,
        Some(web_config),
        stop_rx,
    )
    .await
    .expect("Failed to start server");

    TestServer {
        port: handle.port(),
        handle,
        events,
        _stop_tx: stop_tx,
    }
}

async fn register(
    server: &TestServer,
    pin: Option<&str>,
    browser_name: &str,
    device_type: &str,
    platform: &str,
) -> reqwest::Response {
    server
        .client()
        .post(server.url("/api/dropit/browser/register"))
        .json(&json!({
            "clientId": "test-client",
            "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
            "browserName": browser_name,
            "deviceType": device_type,
            "platform": platform,
            "pin": pin,
        }))
        .send()
        .await
        .expect("Register request failed")
}

fn session_credentials(response: &Value) -> (String, String) {
    (
        response["sessionId"]
            .as_str()
            .expect("Missing sessionId")
            .to_string(),
        response["sessionToken"]
            .as_str()
            .expect("Missing sessionToken")
            .to_string(),
    )
}

async fn open_events(server: &TestServer, session_id: &str, token: &str) -> reqwest::Response {
    let response = server
        .client()
        .get(server.url(&format!(
            "/api/dropit/browser/events?sessionId={session_id}&token={token}"
        )))
        .send()
        .await
        .expect("Failed to open the event stream");
    assert_eq!(response.status(), 200);
    assert!(response
        .headers()
        .get("content-type")
        .and_then(|value| value.to_str().ok())
        .is_some_and(|value| value.starts_with("text/event-stream")));
    response
}

/// Reads the next complete SSE frame and returns its event name and data.
async fn next_sse_event(
    stream: &mut (impl futures_util::Stream<Item = Result<Bytes, reqwest::Error>> + Unpin),
) -> (String, String) {
    let mut buffer = Vec::new();
    loop {
        let chunk = tokio::time::timeout(TIMEOUT, stream.next())
            .await
            .expect("Timed out waiting for an SSE frame")
            .expect("The event stream ended")
            .expect("Failed to read the event stream");
        buffer.extend_from_slice(&chunk);

        if let Some(position) = buffer.windows(2).position(|window| window == b"\n\n") {
            let frame = String::from_utf8_lossy(&buffer[..position]).to_string();
            buffer.drain(..position + 2);

            let mut event = "message".to_string();
            let mut data = String::new();
            for line in frame.lines() {
                if let Some(value) = line.strip_prefix("event: ") {
                    event = value.to_string();
                } else if let Some(value) = line.strip_prefix("data: ") {
                    data.push_str(value);
                }
            }
            if !event.is_empty() && !data.is_empty() {
                return (event, data);
            }
        }
    }
}

fn file_dto() -> FileDto {
    FileDto {
        id: "file-1".to_string(),
        file_name: "hello.txt".to_string(),
        size: 13,
        file_type: "text/plain".to_string(),
        sha256: None,
        preview: None,
        metadata: None,
    }
}

#[tokio::test]
async fn browser_register_requires_the_pin_and_opens_the_event_stream() {
    let mut server = start_test_server(Some("1234"), true).await;

    let wrong = register(&server, Some("0000"), "Firefox", "desktop", "Linux").await;
    assert_eq!(wrong.status(), 401);

    let response = register(&server, Some("1234"), "Firefox", "desktop", "Linux").await;
    assert_eq!(response.status(), 200);
    let body: Value = response.json().await.expect("Invalid register response");
    let (session_id, token) = session_credentials(&body);

    assert_eq!(body["browserName"], "Firefox");
    assert_eq!(body["deviceType"], "desktop");
    assert_eq!(body["platform"], "Linux");
    assert_eq!(body["capabilities"]["offers"], false);
    assert_eq!(body["capabilities"]["upload"], true);
    assert_eq!(body["capabilities"]["uploadViaBrowser"], true);

    match server.next_event().await {
        BrowserEvent::SessionChanged {
            session_id: event_session,
            browser_name,
            device_type,
            connected,
            ready,
            ..
        } => {
            assert_eq!(event_session, session_id);
            assert_eq!(browser_name, "Firefox");
            assert_eq!(device_type, BrowserDeviceType::Desktop);
            assert!(connected);
            assert!(!ready, "the event stream is not open yet");
        }
        other => panic!("Expected SessionChanged, got {other:?}"),
    }

    let mut stream = Box::pin(
        open_events(&server, &session_id, &token)
            .await
            .bytes_stream(),
    );
    let (event, data) = next_sse_event(&mut stream).await;
    assert_eq!(event, "connected");
    let initial: Value = serde_json::from_str(&data).expect("Invalid connected event");
    assert_eq!(initial["alias"], "Test Server");
    assert_eq!(initial["sessionId"], session_id);

    match server.next_event().await {
        BrowserEvent::SessionChanged {
            ready, connected, ..
        } => {
            assert!(connected);
            assert!(ready, "the event stream is open");
        }
        other => panic!("Expected SessionChanged, got {other:?}"),
    }

    let heartbeat = server
        .client()
        .post(server.url("/api/dropit/browser/heartbeat"))
        .json(&json!({ "sessionId": session_id, "token": token }))
        .send()
        .await
        .expect("Heartbeat request failed");
    assert_eq!(heartbeat.status(), 200);
    let heartbeat: Value = heartbeat.json().await.expect("Invalid heartbeat response");
    assert_eq!(heartbeat["ok"], true);
    assert!(heartbeat["offers"]
        .as_array()
        .is_some_and(|offers| offers.is_empty()));
}

#[tokio::test]
async fn browser_portal_exposes_both_transfer_directions() {
    let server = start_test_server(None, true).await;

    let response = server
        .client()
        .get(server.url("/"))
        .send()
        .await
        .expect("Failed to load the browser portal");
    assert_eq!(response.status(), 200);
    let html = response.text().await.expect("Invalid portal body");

    assert!(
        html.contains(r#"id="modeSwitch""#),
        "missing direction switch"
    );
    assert!(
        html.contains(r#"id="modeSend""#),
        "missing browser-to-device tab"
    );
    assert!(
        html.contains(r#"id="modeReceive""#),
        "missing device-to-browser tab"
    );
    assert!(
        html.contains("Send via browser"),
        "the receive direction should tell users how to enable it"
    );
}

#[tokio::test]
async fn browser_offer_is_delivered_answered_and_downloaded() {
    let mut server = start_test_server(None, true).await;

    let response = register(&server, None, "Safari", "desktop", "macOS").await;
    assert_eq!(response.status(), 200);
    let download_cookie = response
        .headers()
        .get("set-cookie")
        .and_then(|value| value.to_str().ok())
        .expect("Missing download cookie")
        .split(';')
        .next()
        .unwrap()
        .to_string();
    let body: Value = response.json().await.expect("Invalid register response");
    let (session_id, token) = session_credentials(&body);

    // Register emits a not-ready snapshot before the stream is open.
    let first_event = server.next_event().await;
    println!("FIRST EVENT: {first_event:?}");
    let mut stream = Box::pin(
        open_events(&server, &session_id, &token)
            .await
            .bytes_stream(),
    );
    assert_eq!(next_sse_event(&mut stream).await.0, "connected");
    let debug_event = server.next_event().await;
    println!("SECOND EVENT: {debug_event:?}");
    match debug_event {
        BrowserEvent::SessionChanged {
            ready, connected, ..
        } => {
            assert!(connected, "the session should be connected");
            assert!(
                ready,
                "the event stream should be open before an offer is created"
            );
        }
        other => panic!("Expected SessionChanged, got {other:?}"),
    }

    let files = HashMap::from([("file-1".to_string(), file_dto())]);
    server
        .handle
        .browser_create_offer(&session_id, "offer-1", files)
        .await
        .expect("Failed to create the offer");

    let (event, data) = next_sse_event(&mut stream).await;
    assert_eq!(event, "offer");
    let offer: Value = serde_json::from_str(&data).expect("Invalid offer event");
    assert_eq!(offer["offerId"], "offer-1");
    assert_eq!(offer["files"][0]["id"], "file-1");
    assert_eq!(offer["files"][0]["fileName"], "hello.txt");
    assert_eq!(offer["files"][0]["size"], 13);

    let response = server
        .client()
        .post(server.url("/api/dropit/browser/offer-response"))
        .json(&json!({
            "sessionId": session_id,
            "token": token,
            "offerId": "offer-1",
            "accept": true,
        }))
        .send()
        .await
        .expect("Offer response request failed");
    assert_eq!(response.status(), 200);

    match server.next_event().await {
        BrowserEvent::OfferResponse {
            offer_id,
            session_id: event_session,
            accepted,
        } => {
            assert_eq!(offer_id, "offer-1");
            assert_eq!(event_session, session_id);
            assert!(accepted);
        }
        other => panic!("Expected OfferResponse, got {other:?}"),
    }

    let download = {
        let client = server.client();
        let url = server.url(&format!(
            "/api/dropit/browser/download?sessionId={session_id}&offerId=offer-1&fileId=file-1"
        ));
        let cookie = download_cookie.clone();
        tokio::spawn(async move {
            client
                .get(url)
                .header("cookie", cookie)
                .send()
                .await
                .expect("Download request failed")
        })
    };

    match server.next_event().await {
        BrowserEvent::DownloadRequested {
            session_id: event_session,
            offer_id,
            file_id,
            file,
            content_tx,
        } => {
            assert_eq!(event_session, session_id);
            assert_eq!(offer_id, "offer-1");
            assert_eq!(file_id, "file-1");
            assert_eq!(file.file_name, "hello.txt");

            let (bytes_tx, bytes_rx) = mpsc::channel::<Bytes>(4);
            content_tx
                .send(FileContent::Stream(bytes_rx))
                .expect("The download request was cancelled");
            tokio::spawn(async move {
                bytes_tx
                    .send(Bytes::from_static(b"hello browser"))
                    .await
                    .expect("The download reader disappeared");
            });
        }
        other => panic!("Expected DownloadRequested, got {other:?}"),
    }

    let response = download.await.expect("Download task panicked");
    assert_eq!(response.status(), 200);
    assert_eq!(
        response
            .headers()
            .get("content-disposition")
            .and_then(|value| value.to_str().ok()),
        Some("attachment; filename=\"hello.txt\"; filename*=UTF-8''hello.txt")
    );
    assert_eq!(
        response
            .headers()
            .get("accept-ranges")
            .and_then(|value| value.to_str().ok()),
        Some("bytes")
    );
    assert!(response.headers().get("etag").is_some());
    let body = response.bytes().await.expect("Failed to read the download");
    assert_eq!(body.as_ref(), b"hello browser");

    loop {
        match server.next_event().await {
            BrowserEvent::DownloadProgress {
                downloaded_bytes,
                total_bytes,
                ..
            } => {
                assert!(downloaded_bytes <= total_bytes);
            }
            BrowserEvent::DownloadFinished {
                session_id: event_session,
                offer_id,
                file_id,
            } => {
                assert_eq!(event_session, session_id);
                assert_eq!(offer_id, "offer-1");
                assert_eq!(file_id, "file-1");
                break;
            }
            other => panic!("Expected download progress, got {other:?}"),
        }
    }

    let download_url = server.url(&format!(
        "/api/dropit/browser/download?sessionId={session_id}&offerId=offer-1&fileId=file-1"
    ));
    let head = server
        .client()
        .head(&download_url)
        .header("cookie", &download_cookie)
        .send()
        .await
        .expect("HEAD request failed");
    assert_eq!(head.status(), 200);
    assert_eq!(
        head.headers()
            .get("content-length")
            .and_then(|value| value.to_str().ok()),
        Some("13")
    );
    assert_eq!(
        head.headers()
            .get("accept-ranges")
            .and_then(|value| value.to_str().ok()),
        Some("bytes")
    );

    let ranged = {
        let client = server.client();
        tokio::spawn(async move {
            client
                .get(download_url)
                .header("cookie", download_cookie)
                .header("range", "bytes=6-")
                .send()
                .await
                .expect("Range request failed")
        })
    };
    match server.next_event().await {
        BrowserEvent::DownloadRequested { content_tx, .. } => {
            let (bytes_tx, bytes_rx) = mpsc::channel::<Bytes>(4);
            content_tx
                .send(FileContent::Stream(bytes_rx))
                .expect("Range request was cancelled");
            bytes_tx
                .send(Bytes::from_static(b"hello browser"))
                .await
                .unwrap();
        }
        other => panic!("Expected ranged DownloadRequested, got {other:?}"),
    }
    let ranged = ranged.await.expect("Range task panicked");
    assert_eq!(ranged.status(), 206);
    assert_eq!(
        ranged
            .headers()
            .get("content-range")
            .and_then(|value| value.to_str().ok()),
        Some("bytes 6-12/13")
    );
    assert_eq!(
        ranged
            .headers()
            .get("content-length")
            .and_then(|value| value.to_str().ok()),
        Some("7")
    );
    assert_eq!(ranged.bytes().await.unwrap().as_ref(), b"browser");
    loop {
        if matches!(
            server.next_event().await,
            BrowserEvent::DownloadFinished { .. }
        ) {
            break;
        }
    }

    assert!(server
        .handle
        .browser_cancel_offer("offer-1")
        .await
        .expect("Cancel failed"));
    assert!(!server
        .handle
        .browser_cancel_offer("missing-offer")
        .await
        .expect("Cancel failed"));

    assert!(server
        .handle
        .browser_disconnect_session(&session_id)
        .await
        .expect("Disconnect failed"));
    match server.next_event().await {
        BrowserEvent::SessionClosed {
            session_id: event_session,
            reason,
        } => {
            assert_eq!(event_session, session_id);
            assert_eq!(reason, BrowserSessionEndReason::Removed);
        }
        other => panic!("Expected SessionClosed, got {other:?}"),
    }

    let heartbeat = server
        .client()
        .post(server.url("/api/dropit/browser/heartbeat"))
        .json(&json!({ "sessionId": session_id, "token": token }))
        .send()
        .await
        .expect("Heartbeat request failed");
    assert_eq!(heartbeat.status(), 401);
}

#[tokio::test]
async fn browser_port_serves_a_ca_signed_certificate() {
    use localsend::http::server::start_with_port_and_browser;
    use localsend::http::server::TlsConfig;
    use rustls::pki_types::pem::PemObject;
    use x509_parser::asn1_rs::FromDer;
    use x509_parser::certificate::X509Certificate;
    use x509_parser::extensions::GeneralName;

    let _ = tracing_subscriber::fmt().with_test_writer().try_init();

    let identity =
        localsend::crypto::cert::generate_self_signed().expect("Failed to generate identity");
    let identity_tls = TlsConfig {
        cert: identity.certificate_pem.clone(),
        private_key: identity.private_key_pem.clone(),
    };

    let (browser_event_tx, _browser_events) = mpsc::channel::<BrowserEvent>(64);
    let web_config = WebConfig {
        send: None,
        upload: true,
        i18n: WebI18n::default(),
        pages: WebPages::default(),
        browser: Some(BrowserConfig::new(None, browser_event_tx)),
    };

    let (stop_tx, stop_rx) = oneshot::channel::<()>();
    let handle = start_with_port_and_browser(
        0,
        Some(identity_tls.clone()),
        Some(identity_tls),
        ClientInfo {
            alias: "Test Server".to_string(),
            version: "2.2".to_string(),
            device_model: Some("Rust".to_string()),
            device_type: None,
            token: identity.fingerprint.clone(),
        },
        None,
        None,
        Some(web_config),
        stop_rx,
    )
    .await
    .expect("Failed to start server");

    let browser_port = handle.browser_port().expect("Browser listener missing");
    assert_ne!(browser_port, handle.port());

    let client = reqwest::Client::builder()
        .danger_accept_invalid_certs(true)
        .tls_info(true)
        .timeout(TIMEOUT)
        .build()
        .expect("Failed to build HTTPS client");

    let ca_response = client
        .get(format!("https://127.0.0.1:{browser_port}/dropit-ca.crt"))
        .send()
        .await
        .expect("CA request failed");
    assert_eq!(ca_response.status(), 200);
    assert_eq!(
        ca_response
            .headers()
            .get(reqwest::header::CONTENT_TYPE)
            .and_then(|value| value.to_str().ok()),
        Some("application/x-x509-ca-cert")
    );
    let ca_pem = ca_response
        .text()
        .await
        .expect("Failed to read the CA certificate");
    assert!(ca_pem.contains("-----BEGIN CERTIFICATE-----"));

    // With the CA installed, the browser accepts the IP-based HTTPS URL.
    let trusted_client = reqwest::Client::builder()
        .add_root_certificate(
            reqwest::Certificate::from_pem(ca_pem.as_bytes()).expect("Invalid CA certificate"),
        )
        .timeout(TIMEOUT)
        .build()
        .expect("Failed to build trusted HTTPS client");
    let trusted_health = trusted_client
        .get(format!("https://127.0.0.1:{browser_port}/health"))
        .send()
        .await
        .expect("Trusted CA request failed");
    assert_eq!(trusted_health.status(), 200);

    let health = client
        .get(format!("https://127.0.0.1:{browser_port}/health"))
        .send()
        .await
        .expect("Health request failed");
    let health: Value = health.json().await.expect("Invalid health response");
    assert_eq!(health["browserSharing"], true);

    let page = client
        .get(format!("https://127.0.0.1:{browser_port}/"))
        .send()
        .await
        .expect("Portal request failed");
    let tls_info = page
        .extensions()
        .get::<reqwest::tls::TlsInfo>()
        .expect("TLS info missing")
        .clone();
    let server_cert = tls_info
        .peer_certificate()
        .expect("Server certificate missing");
    let page = page.text().await.expect("Failed to read the portal");
    assert!(page.contains("modeSwitch"));
    assert!(page.contains("trustLink"));
    assert!(page.contains("data-browser-listener=\"true\""));

    let main_response = client
        .get(format!("https://127.0.0.1:{}/", handle.port()))
        .send()
        .await
        .expect("Main listener request failed");
    let main_tls_info = main_response
        .extensions()
        .get::<reqwest::tls::TlsInfo>()
        .expect("Main TLS info missing")
        .clone();
    let main_cert = main_tls_info
        .peer_certificate()
        .expect("Main server certificate missing");
    let identity_der =
        rustls::pki_types::CertificateDer::from_pem_slice(identity.certificate_pem.as_bytes())
            .expect("Invalid identity PEM");
    assert_eq!(main_cert, identity_der.as_ref());

    let main_page = main_response
        .text()
        .await
        .expect("Failed to read the main portal");
    assert!(!main_page.contains("data-browser-listener"));

    let ca_der = rustls::pki_types::CertificateDer::from_pem_slice(ca_pem.as_bytes())
        .expect("Invalid CA PEM");
    assert_ne!(server_cert, ca_der.as_ref());

    let (_, ca) = X509Certificate::from_der(ca_der.as_ref()).expect("Invalid CA certificate");
    let (_, server) = X509Certificate::from_der(server_cert).expect("Invalid server certificate");
    server
        .verify_signature(Some(ca.public_key()))
        .expect("Server certificate is not signed by the CA");

    let san = server
        .subject_alternative_name()
        .expect("Invalid SAN")
        .expect("Missing SAN");
    assert!(san
        .value
        .general_names
        .iter()
        .any(|name| { matches!(name, GeneralName::IPAddress(bytes) if *bytes == [127, 0, 0, 1]) }));

    drop(stop_tx);
}
