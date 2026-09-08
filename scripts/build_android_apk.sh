#!/usr/bin/env bash
# scripts/build_android_apk.sh - Build production debug APK (local install / QA)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Locate Java 21/17 dynamically if JAVA_HOME is unset or invalid
if [ -z "${JAVA_HOME:-}" ] || [ ! -d "$JAVA_HOME" ]; then
  if command -v /usr/libexec/java_home >/dev/null 2>&1 && /usr/libexec/java_home >/dev/null 2>&1; then
    export JAVA_HOME="$(/usr/libexec/java_home -v 21 2>/dev/null || /usr/libexec/java_home 2>/dev/null)"
  elif [ -d "$HOME/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" ]; then
    export JAVA_HOME="$HOME/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  elif [ -d "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" ]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  elif [ -d "/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" ]; then
    export JAVA_HOME="/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  fi
fi
if [ -n "${JAVA_HOME:-}" ] && [ -d "$JAVA_HOME" ]; then
  export PATH="$JAVA_HOME/bin:$PATH"
fi

echo "=========================================="
echo "Building Pomo Android production debug APK..."
echo "=========================================="

echo "1. Getting dependencies and localizations..."
flutter pub get >/dev/null
flutter gen-l10n --arb-dir="lib/l10n/arb" >/dev/null

echo "2. Building APK (production flavor, debug build)..."
flutter build apk --debug --flavor production --target lib/main_production.dart

OUTPUT_APK="$ROOT/build/app/outputs/flutter-apk/app-production-debug.apk"
if [ -f "$OUTPUT_APK" ]; then
  echo "=========================================="
  echo "Successfully built production debug APK!"
  echo "APK Path: $OUTPUT_APK"
  echo "Package:  com.recoskyler.pomo"
  echo "=========================================="
else
  echo "Error: Output APK not found after build."
  exit 1
fi
