# Dropit

Dropit is a fast, secure, peer-to-peer local file-sharing application designed for mobile, tablet, and desktop platforms. Share files, folders, photos, videos, and text across your local Wi-Fi network without requiring an internet connection or third-party servers.

## Features

- **Cross-Platform:** Available for Android, iOS, macOS, Windows, and Linux.
- **Peer-to-Peer:** Direct high-speed local device-to-device transfers.
- **Secure by Default:** End-to-end TLS encryption with self-signed certificate verification.
- **Adaptive UI:** Apple-inspired modern interface tailored for phones (320–430px), tablets (768–1024px), and desktop displays (1280px+).
- **Zero-Effect High-Speed Mobile Mode:** Maximum frame-rate performance on mobile devices with instant touch response and 0ms transition delay.
- **Web Browser Sharing:** Share with any browser on the local network without requiring installation on the receiver device.
- **No Internet Required:** Fully autonomous local network discovery via IPv4 and IPv6 multicast.

## Building from Source

With Flutter 3.41.9 and Rust 1.97.1:

```bash
# Clone the repository
git clone https://github.com/imleorathu/Dropit.git
cd Dropit/app

# Fetch dependencies
flutter pub get

# Run tests
flutter test

# Run the app
flutter run
```

### Platform Release Builds

- **Android:** `flutter build apk --release --split-per-abi`
- **iOS:** `flutter build ipa --release` (or `flutter build ios --simulator --debug`)
- **macOS:** `flutter build macos --release`
- **Windows:** `flutter build windows --release`
- **Linux:** `flutter build linux --release`

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.
