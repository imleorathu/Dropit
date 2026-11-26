# Changelog

## 1.18.2 (2026-11-06)

- feat: Display actual hardware device name by default on all platforms with custom rename support
- feat(mobile): Ultra-fast, zero-overhead high-speed rendering pipeline for Android and iOS
- feat(mobile): Streamlined Settings page with adaptive mobile layout
- perf(core): Concurrent child isolate initialization (`discovery`, `httpUpload`, `httpServer`) cutting cold-start latency by ~60%
- fix(startup): Non-blocking network permissions and fail-safe timeouts eliminating infinite loading loops
- fix(reliability): Idempotent startup retry mechanism for robust offline recovery
- feat(web): Modern Dropit web portal for cross-device browser sharing and uploads
- feat(design): Apple-inspired modern UI and fluid multi-breakpoint design across mobile, tablet, and desktop

## 1.18.0 (2026-08-10)

- feat: Dropit peer-to-peer local file, folder, and text transfer
- feat: End-to-end TLS encryption on local network without cloud dependencies
- feat: Automatic local network device discovery via IPv4 and IPv6 multicast
- feat: Cross-platform support for Android, iOS, macOS, Windows, and Linux
- feat: High-speed streaming uploads and downloads via direct HTTP transport
- feat: Favorites, quick save, and PIN authentication for secure sharing
