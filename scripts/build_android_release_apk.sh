#!/usr/bin/env bash
# scripts/build_android_release_apk.sh - Build signed production release APK
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -d "/Users/rawshn/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" ]; then
  export JAVA_HOME="/Users/rawshn/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

if [ ! -f "$ROOT/android/key.properties" ] && [ -z "${ANDROID_KEYSTORE_PATH:-}" ]; then
  echo "WARNING: No release keystore configured."
  echo "Create android/key.properties (see specs/android.md) before shipping OTA updates."
  echo "Without a stable keystore, Android will treat each build as a different app."
fi

echo "=========================================="
echo "Building Pomo Android production release APK..."
echo "=========================================="

echo "1. Getting dependencies and localizations..."
flutter pub get >/dev/null
flutter gen-l10n --arb-dir="lib/l10n/arb" >/dev/null

echo "2. Building APK (production flavor, release build)..."
flutter build apk --release --flavor production --target lib/main_production.dart

OUTPUT_APK="$ROOT/build/app/outputs/flutter-apk/app-production-release.apk"
if [ -f "$OUTPUT_APK" ]; then
  echo "=========================================="
  echo "Successfully built production release APK!"
  echo "APK Path: $OUTPUT_APK"
  echo "Package:  com.recoskyler.pomo"
  echo "=========================================="
else
  echo "Error: Output APK not found after build."
  exit 1
fi
