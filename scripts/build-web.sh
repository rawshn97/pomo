#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CLEAN_BUILD=false

show_help() {
  echo "Usage: ./scripts/build-web.sh [OPTIONS]"
  echo ""
  echo "Builds the Pomo web application (CanvasKit / PWA) and packages it into deploy/focus/."
  echo ""
  echo "Options:"
  echo "  -h, --help    Show this help message and exit"
  echo "  -c, --clean   Remove stale compilation artifacts before rebuilding"
  echo ""
  echo "Examples:"
  echo "  ./scripts/build-web.sh"
  echo "  ./scripts/build-web.sh --clean"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -c|--clean)
      CLEAN_BUILD=true
      shift 1
      ;;
    *)
      echo "Error: Unknown argument '$1'. Run with --help for usage."
      exit 1
      ;;
  esac
done

# Install Flutter on Vercel when not present locally in CI
if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
  flutter config --enable-web
  flutter precache --web
fi

if [ "$CLEAN_BUILD" = true ]; then
  echo "Cleaning stale compilation artifacts..."
  flutter clean >/dev/null 2>&1 || true
  rm -rf build/web deploy/focus
fi

flutter pub get
flutter gen-l10n

# Do not bake secrets into the Flutter web bundle.
# Browser sessions prompt for FOCUS_ACCESS_TOKEN; the Vercel proxy validates it
# against process.env.FOCUS_ACCESS_TOKEN and swaps in NOTION_TOKEN server-side.
DART_DEFINE_FLAGS=()

set +u
flutter build web \
  --release \
  --no-web-resources-cdn \
  --no-wasm-dry-run \
  --base-href=/focus/ \
  --target lib/main_production.dart \
  "${DART_DEFINE_FLAGS[@]}"
set -u

rm -rf deploy
mkdir -p deploy/focus
cp -R build/web/. deploy/focus/
cp -R build/web/. deploy/

# Root path copy (base href "/")
sed -i.bak 's|<base href="/focus/">|<base href="/">|g' deploy/index.html && rm -f deploy/index.html.bak

# Flutter 3.44+ ships a stub flutter_service_worker.js that unregisters itself and
# reloads the page. Load the app directly via flutter_bootstrap instead.
perl -i -0pe 's/_flutter\.loader\.load\(\{\s*serviceWorkerSettings:\s*\{[^}]+\}\s*\}\);/_flutter.loader.load();/s' deploy/focus/flutter_bootstrap.js
perl -i -0pe 's/_flutter\.loader\.load\(\{\s*serviceWorkerSettings:\s*\{[^}]+\}\s*\}\);/_flutter.loader.load();/s' deploy/flutter_bootstrap.js

VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)"
sed "s/focus-pwa-v1/focus-pwa-${VERSION}/" web/pwa_service_worker.js > deploy/focus/pwa_service_worker.js
sed "s/focus-pwa-v1/focus-pwa-${VERSION}/" web/pwa_service_worker.js > deploy/pwa_service_worker.js

mkdir -p deploy/android
cp web/android/version.json deploy/android/version.json

echo "Web build ready at deploy/ and deploy/focus/"
