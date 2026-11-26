#!/usr/bin/env bash
set -euo pipefail
# Run from complete LanBridge fork repository, after prepare.py.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if command -v fvm >/dev/null 2>&1; then FLUTTER=(fvm flutter); else FLUTTER=(flutter); fi
cd "$ROOT"
"${FLUTTER[@]}" pub get
cd app
"${FLUTTER[@]}" test
"${FLUTTER[@]}" analyze --no-fatal-infos
TARGET="${1:-help}"
case "$TARGET" in
 android) "${FLUTTER[@]}" build apk ;;
 ios) "${FLUTTER[@]}" build ipa ;;
 ios-simulator) "${FLUTTER[@]}" build ios --debug --simulator --no-codesign ;;
 macos) "${FLUTTER[@]}" build macos ;;
 windows) "${FLUTTER[@]}" build windows ;;
 help) echo 'Usage: ./scripts/build.sh {android|ios|ios-simulator|macos|windows}' ;;
 *) echo "Unknown target: $TARGET" >&2; exit 2 ;;
esac
