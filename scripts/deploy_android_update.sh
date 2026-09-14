#!/usr/bin/env bash
# scripts/deploy_android_update.sh - Build, release APK, and bump OTA manifest
#
# Hosting (all free tier):
#   APK          -> GitHub Releases (binary)
#   version.json -> Vercel static file at /android/version.json
#
# Usage:
#   ./scripts/deploy_android_update.sh "Bug fixes and hourly tracker tweaks"
#   ./scripts/deploy_android_update.sh --skip-release "WIP manifest only"
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SKIP_RELEASE=false
CHANGELOG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-release)
      SKIP_RELEASE=true
      shift
      ;;
    -h|--help)
      echo "Usage: ./scripts/deploy_android_update.sh [--skip-release] [changelog]"
      exit 0
      ;;
    *)
      CHANGELOG="$1"
      shift
      ;;
  esac
done

if [ -z "$CHANGELOG" ]; then
  CHANGELOG="Pomo production Android update."
fi

VERSION_LINE="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
VERSION_NAME="${VERSION_LINE%%+*}"
VERSION_CODE="${VERSION_LINE##*+}"
TAG="v${VERSION_NAME}"
APK_NAME="pomo-production.apk"
MANIFEST_PATH="$ROOT/web/android/version.json"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "rawshn97/pomo")"
APK_URL="https://github.com/${REPO}/releases/download/${TAG}/${APK_NAME}"

echo "==> Building production release APK..."
"$ROOT/scripts/build_android_release_apk.sh"

APK_PATH="$ROOT/build/app/outputs/flutter-apk/app-production-release.apk"

echo "==> Writing OTA manifest ($MANIFEST_PATH)..."
mkdir -p "$(dirname "$MANIFEST_PATH")"
cat >"$MANIFEST_PATH" <<EOF
{
  "versionCode": ${VERSION_CODE},
  "versionName": "${VERSION_NAME}",
  "apkUrl": "${APK_URL}",
  "changelog": "${CHANGELOG//\"/\\\"}"
}
EOF

if [ "$SKIP_RELEASE" = true ]; then
  echo "==> Skipped GitHub release (--skip-release)."
  echo "Manifest updated locally. Deploy web to publish version.json:"
  echo "  vercel deploy --prod   # from repo root, if linked"
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found. Install GitHub CLI or pass --skip-release."
  exit 1
fi

echo "==> Creating GitHub release ${TAG}..."
# gh treats path#label as a display label only; the download URL uses the
# real filename. Copy to APK_NAME so browser_download_url matches version.json.
STAGED_APK="$(mktemp -d -t pomo-release-XXXXXX)/${APK_NAME}"
mkdir -p "$(dirname "$STAGED_APK")"
cp -f "$APK_PATH" "$STAGED_APK"
trap 'rm -rf "$(dirname "$STAGED_APK")"' EXIT

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "Release ${TAG} exists; uploading/replacing APK asset..."
  # Drop legacy Gradle filename if a prior broken upload left it behind.
  gh release delete-asset "$TAG" "app-production-release.apk" --yes 2>/dev/null || true
  gh release upload "$TAG" "$STAGED_APK" --clobber
else
  gh release create "$TAG" "$STAGED_APK" \
    --title "Pomo ${VERSION_NAME}" \
    --notes "$CHANGELOG"
fi

echo ""
echo "Done."
echo "  APK:      ${APK_URL}"
echo "  Manifest: web/android/version.json (versionCode=${VERSION_CODE})"
echo ""
echo "Next: deploy Vercel so phones see the new manifest:"
echo "  vercel deploy --prod"
