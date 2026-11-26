# LanBridge modifications to LocalSend

Based on LocalSend v1.18.2; original copyright and Apache-2.0 license retained.

This fork adds a cross-platform connection-help dialog and its Flutter test,
updates the displayed brand, and changes the default color/accent and corner radius.
All LocalSend file-transfer protocol, REST/HTTPS, discovery and permissions code
are intentionally left unchanged. See the original LICENSE and README.md.

Files modified or added:
- `app/lib/main.dart`
- `app/lib/pages/home_page.dart`
- `app/lib/config/theme.dart`
- `app/android/app/src/main/AndroidManifest.xml`
- `app/ios/Runner/Info.plist`
- `app/macos/Runner/Info.plist`
- `app/windows/runner/Runner.rc`
- `.github/workflows/lanbridge-multiplatform.yml`
- `app/test/lanbridge_connection_help_test.dart`
- `app/lib/widget/lanbridge_connection_help.dart`
- `scripts/build.sh`
- `scripts/build.ps1`
- `scripts/doctor.py`
