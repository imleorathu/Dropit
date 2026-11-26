#![cfg(feature = "http")]

use localsend::crypto::cert::generate_self_signed;
use localsend::http::server::browser::{BrowserConfig, BrowserEvent};
use localsend::http::server::common::save::FileUploadTarget;
use localsend::http::server::v2::{PrepareUploadDecisionV2, ServerEventV2};
use localsend::http::server::web::{WebConfig, WebI18n, WebPages, WebSendConfig, WebSendEvent};
use localsend::http::server::{start_with_port_and_browser, ServerConfigV2, TlsConfig};
use localsend::http::state::ClientInfo;
use localsend::model::discovery::DeviceType;
use localsend::model::transfer::{FileContent, FileDto};
use serde_json::json;
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::{mpsc, oneshot, Mutex};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let mut args = std::env::args().skip(1);
    let mut shared_dir: Option<PathBuf> = None;
    let mut receive_dir: Option<PathBuf> = None;
    let mut port: u16 = 0;
    let mut use_tls = false;
    let mut browser_tls_enabled = false;
    let mut verify_checksums = true;

    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--shared-dir" => shared_dir = args.next().map(PathBuf::from),
            "--receive-dir" => receive_dir = args.next().map(PathBuf::from),
            "--port" => {
                port = args
                    .next()
                    .ok_or_else(|| anyhow::anyhow!("Missing value for --port"))?
                    .parse()?;
            }
            "--tls" => use_tls = true,
            "--browser-tls" => browser_tls_enabled = true,
            "--no-verify-checksums" => verify_checksums = false,
            other => anyhow::bail!("Unknown argument: {other}"),
        }
    }

    let shared_dir = shared_dir.ok_or_else(|| anyhow::anyhow!("Missing --shared-dir"))?;
    let receive_dir = receive_dir.ok_or_else(|| anyhow::anyhow!("Missing --receive-dir"))?;
    std::fs::create_dir_all(&shared_dir)?;
    std::fs::create_dir_all(&receive_dir)?;

    let mut files = HashMap::<String, FileDto>::new();
    let mut file_paths = HashMap::<String, PathBuf>::new();
    let mut entries: Vec<_> = std::fs::read_dir(&shared_dir)?
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().map(|t| t.is_file()).unwrap_or(false))
        .collect();
    entries.sort_by_key(|e| e.file_name());

    for (idx, entry) in entries.into_iter().enumerate() {
        let path = entry.path();
        let meta = entry.metadata()?;
        let name = entry.file_name().to_string_lossy().into_owned();
        let id = format!("file-{idx}");
        files.insert(
            id.clone(),
            FileDto {
                id: id.clone(),
                file_name: name,
                size: meta.len(),
                file_type: "application/octet-stream".to_string(),
                sha256: None,
                preview: None,
                metadata: None,
            },
        );
        file_paths.insert(id, path);
    }

    let file_paths = Arc::new(file_paths);
    let upload_names = Arc::new(Mutex::new(HashMap::<String, String>::new()));

    let tls = if use_tls || browser_tls_enabled {
        let cert = generate_self_signed()?;
        Some((
            TlsConfig {
                cert: cert.certificate_pem,
                private_key: cert.private_key_pem,
            },
            cert.fingerprint,
        ))
    } else {
        None
    };

    let fingerprint = tls
        .as_ref()
        .map(|(_, fp)| fp.clone())
        .unwrap_or_else(|| "BENCH-SERVER-FP".to_string());

    let main_tls = if use_tls {
        tls.as_ref().map(|(c, _)| c.clone())
    } else {
        None
    };
    let browser_tls = if browser_tls_enabled {
        tls.as_ref().map(|(c, _)| c.clone())
    } else {
        None
    };

    let (v2_tx, mut v2_rx) = mpsc::channel::<ServerEventV2>(64);
    let (web_tx, mut web_rx) = mpsc::channel::<WebSendEvent>(64);
    let (browser_tx, mut browser_rx) = mpsc::channel::<BrowserEvent>(64);
    let (stop_tx, stop_rx) = oneshot::channel::<()>();

    let handle = start_with_port_and_browser(
        port,
        main_tls,
        browser_tls,
        ClientInfo {
            alias: "Dropit-Bench-Mac".to_string(),
            version: "2.2".to_string(),
            device_model: Some("Mac".to_string()),
            device_type: Some(DeviceType::Desktop),
            token: fingerprint,
        },
        None,
        Some(ServerConfigV2 {
            pin: None,
            verify_checksums,
            event_tx: v2_tx,
        }),
        Some(WebConfig {
            send: Some(WebSendConfig {
                files: files.clone(),
                pin: None,
                event_tx: web_tx,
            }),
            upload: true,
            i18n: WebI18n::default(),
            pages: WebPages::default(),
            browser: Some(BrowserConfig::new(None, browser_tx)),
        }),
        stop_rx,
    )
    .await?;

    let bound_port = handle.port();
    let bound_browser_port = handle.browser_port();

    // v2 upload event handler
    {
        let receive_dir = receive_dir.clone();
        let upload_names = upload_names.clone();
        tokio::spawn(async move {
            while let Some(event) = v2_rx.recv().await {
                match event {
                    ServerEventV2::PrepareUpload {
                        files, decision_tx, ..
                    } => {
                        let mut map = upload_names.lock().await;
                        for (id, dto) in &files {
                            map.insert(id.clone(), dto.file_name.clone());
                        }
                        let _ = decision_tx.send(PrepareUploadDecisionV2::Accept(
                            files.keys().cloned().collect(),
                        ));
                    }
                    ServerEventV2::FileUpload {
                        file_id, target_tx, ..
                    } => {
                        let name = upload_names
                            .lock()
                            .await
                            .get(&file_id)
                            .cloned()
                            .unwrap_or_else(|| format!("{file_id}.bin"));
                        let safe_name = localsend::http::server::browser::sanitize_file_name(&name);
                        let dest_path = receive_dir.join(format!("{file_id}_{safe_name}"));
                        let (result_tx, result_rx) = oneshot::channel();
                        let (progress_tx, mut progress_rx) = mpsc::channel::<u64>(64);
                        tokio::spawn(async move { while progress_rx.recv().await.is_some() {} });
                        tokio::spawn(async move {
                            let _ = result_rx.await;
                        });
                        let _ = target_tx.send(FileUploadTarget::Path {
                            path: dest_path,
                            result_tx,
                            progress_tx: Some(progress_tx),
                        });
                    }
                    _ => {}
                }
            }
        });
    }

    // web-send v2 download event handler
    {
        let file_paths = file_paths.clone();
        tokio::spawn(async move {
            while let Some(event) = web_rx.recv().await {
                match event {
                    WebSendEvent::PrepareDownload { decision_tx, .. } => {
                        let _ = decision_tx.send(true);
                    }
                    WebSendEvent::FileDownload {
                        file_id,
                        content_tx,
                        ..
                    } => {
                        if let Some(path) = file_paths.get(&file_id) {
                            let _ = content_tx.send(FileContent::Path(path.clone()));
                        }
                    }
                }
            }
        });
    }

    // browser sharing event handler (auto-offers shared files when session is ready)
    let offered_sessions = Arc::new(Mutex::new(HashSet::<String>::new()));
    let handle = Arc::new(handle);
    {
        let handle = handle.clone();
        let files = files.clone();
        let file_paths = file_paths.clone();
        let offered_sessions = offered_sessions.clone();
        tokio::spawn(async move {
            while let Some(event) = browser_rx.recv().await {
                match event {
                    BrowserEvent::SessionChanged {
                        session_id,
                        connected,
                        ready,
                        ..
                    } => {
                        if connected && ready && !files.is_empty() {
                            let mut seen = offered_sessions.lock().await;
                            if seen.insert(session_id.clone()) {
                                let handle = handle.clone();
                                let files = files.clone();
                                tokio::spawn(async move {
                                    let offer_id = format!("bench-offer-{session_id}");
                                    let _ = handle
                                        .browser_create_offer(&session_id, &offer_id, files)
                                        .await;
                                });
                            }
                        }
                    }
                    BrowserEvent::SessionClosed { session_id, .. } => {
                        offered_sessions.lock().await.remove(&session_id);
                    }
                    BrowserEvent::DownloadRequested {
                        file_id,
                        content_tx,
                        ..
                    } => {
                        if let Some(path) = file_paths.get(&file_id) {
                            let _ = content_tx.send(FileContent::Path(path.clone()));
                        }
                    }
                    _ => {}
                }
            }
        });
    }

    println!(
        "{}",
        json!({
            "ready": true,
            "port": bound_port,
            "browserPort": bound_browser_port,
            "pid": std::process::id(),
            "files": files.values().map(|f| json!({
                "id": f.id,
                "fileName": f.file_name,
                "size": f.size,
            })).collect::<Vec<_>>(),
        })
    );

    tokio::signal::ctrl_c().await?;
    let _ = stop_tx.send(());
    handle.wait_stopped().await;
    Ok(())
}
