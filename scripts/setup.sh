#!/usr/bin/env bash
# scripts/setup.sh - Automated onboarding and prerequisite setup script
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RUN_VERIFY=false

show_help() {
  echo "Usage: ./scripts/setup.sh [OPTIONS]"
  echo ""
  echo "Sets up the Pomo development environment: checks prerequisites,"
  echo "initializes local .env, fetches pub dependencies, and generates localizations."
  echo ""
  echo "Options:"
  echo "  -h, --help       Show this help message and exit"
  echo "  -v, --verify     Run ./scripts/verify.sh immediately after setup"
  echo ""
  echo "Examples:"
  echo "  ./scripts/setup.sh"
  echo "  ./scripts/setup.sh --verify"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -v|--verify)
      RUN_VERIFY=true
      shift 1
      ;;
    *)
      echo "Error: Unknown argument '$1'. Run with --help for usage."
      exit 1
      ;;
  esac
done

echo "=========================================="
echo "Starting Pomo Environment Setup..."
echo "=========================================="

# 1. Flutter SDK prerequisite check
if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: 'flutter' command not found in PATH."
  echo ""
  echo "Please install Flutter SDK (>= 3.27.0 with Dart SDK >= 3.6.0):"
  echo "  macOS (Homebrew): brew install --cask flutter"
  echo "  Direct install:   https://docs.flutter.dev/get-started/install"
  exit 1
fi

FLUTTER_VER="$(flutter --version 2>/dev/null | head -n 1 || echo 'Flutter installed')"
echo "Detected Flutter: ${FLUTTER_VER}"

# 2. Environment file initialization (.env)
if [ ! -f ".env" ] && [ -f "sample.env" ]; then
  echo "Initializing .env from sample.env template..."
  cp sample.env .env
  echo "Created .env (custom credentials can be configured there)."
elif [ -f ".env" ]; then
  echo "Found existing .env file."
fi

# 3. Platform-specific prerequisites
OS_TYPE="$(uname -s)"
if [ "$OS_TYPE" = "Darwin" ]; then
  echo "Checking macOS development prerequisites..."
  if ! command -v pod >/dev/null 2>&1; then
    echo "Notice: 'pod' (CocoaPods) not found in PATH. Required for macOS and iOS native builds."
    echo "Install via Homebrew: brew install cocoapods"
  else
    POD_VER="$(pod --version 2>/dev/null || echo 'installed')"
    echo "Detected CocoaPods: ${POD_VER}"
  fi
fi

# 4. Android prerequisites (advisory)
JAVA_DETECTED=false
if java -version >/dev/null 2>&1; then
  JAVA_VER="$(java -version 2>&1 | head -n 1 || echo 'installed')"
  echo "Detected Java: ${JAVA_VER}"
  JAVA_DETECTED=true
else
  for candidate in \
    "${JAVA_HOME:-}" \
    "$HOME/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" \
    "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" \
    "/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"; do
    if [ -n "$candidate" ] && [ -d "$candidate" ]; then
      echo "Detected JDK at: $candidate"
      JAVA_DETECTED=true
      break
    fi
  done
fi

if [ "$JAVA_DETECTED" = false ]; then
  echo "Notice: Java (JDK 17 or 21) not detected. Required if building Android APKs."
  echo "Install via Homebrew: brew install openjdk@21"
fi

# 5. Fetch dependencies
echo "1. Fetching Flutter dependencies..."
flutter pub get

# 6. Generate localizations (uses l10n.yaml)
echo "2. Generating localization files (AppLocalizations)..."
flutter gen-l10n

echo "=========================================="
echo "Setup complete! Target launch commands:"
echo "  macOS Desktop: flutter run --flavor development -d macos --target lib/main_development.dart"
echo "  Web (Chrome):  flutter run --flavor development -d chrome --target lib/main_development.dart"
echo "  Android APK:   ./scripts/build_android_apk.sh"
echo "  Verify Suite:  ./scripts/verify.sh"
echo "=========================================="

if [ "$RUN_VERIFY" = true ]; then
  echo ""
  echo "Running verification suite as requested..."
  ./scripts/verify.sh
fi
