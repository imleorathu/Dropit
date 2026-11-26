# Dropit product changes

This application derives from LocalSend. The original Apache 2.0 license, author notices, and engine implementation are retained.

- New adaptive application shell, send/receive workspace, sender approval and waiting screens, device cards, settings presentation, and shared transfer styling.
- New Dropit icon master and launcher exports, plus updated tray, share-extension, and launch artwork.
- Independent installed application identifiers and product names, desktop executable names, preferences paths, startup integration, and Windows installer identity.
- Dropit branding in localized application strings, regenerated with Slang.
- About and privacy views distinguish Dropit from its LocalSend engine and preserve upstream credits.
- Original donation entry and purchase initialization are inactive in Dropit.
- Added Cupertino icon font dependency and Flutter widget-test dependency.
- Added responsive layout/action tests. The LocalSend Rust core, isolate layer, discovery protocol, TLS verification, and file-transfer algorithms are unchanged.

See the development kit's `docs/DROPIT.md`, `docs/BUILD_STATUS.md`, and `docs/TEST_PLAN.md` for build instructions, completed verification, and remaining platform checks. Internal Dart package names and native method-channel namespaces remain for compatibility; they are not the installed application identifiers.
