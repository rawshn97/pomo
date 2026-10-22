#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DMG_PATH="$PROJECT_ROOT/Pomo.dmg"
APP_PATH_FLAVOR="$PROJECT_ROOT/build/macos/Build/Products/Release-production/Pomo.app"
APP_PATH_DEFAULT="$PROJECT_ROOT/build/macos/Build/Products/Release/Pomo.app"

export PATH="$HOME/homebrew/bin:$PATH"

echo "--> Checking Xcode developer directory and license status..."
if [ -z "$DEVELOPER_DIR" ]; then
  for xcode_path in /Applications/Xcode*.app/Contents/Developer; do
    if [ -d "$xcode_path" ]; then
      export DEVELOPER_DIR="$xcode_path"
      echo "--> Automatically using detected Xcode path: $DEVELOPER_DIR"
      break
    fi
  done
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "ERROR: Xcode ('xcodebuild') is not available in the current developer path."
  echo "Please switch your active developer tool directory to Xcode:"
  echo "   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

if xcodebuild -sdk macosx -version 2>&1 | grep -i -q "license agreements"; then
  echo "ERROR: You have not agreed to the Xcode license agreements."
  echo "Please run the following commands in terminal to accept the license and set the default Xcode path:"
  echo "   sudo xcodebuild -license accept"
  echo "   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

if ! [ -e "/Library/Developer/PrivateFrameworks/CoreSimulator.framework" ] || xcodebuild -sdk macosx -version 2>&1 | grep -i -q -E "runFirstLaunch|CoreSimulator"; then
  echo "ERROR: Xcode first-launch system frameworks (CoreSimulator) are not installed yet."
  echo "Please run the following command in terminal to install Apple's required system frameworks:"
  echo "   sudo xcodebuild -runFirstLaunch"
  exit 1
fi

flutter config --no-enable-swift-package-manager >/dev/null 2>&1 || true
flutter build macos --release --flavor production -t lib/main_production.dart

if [ -d "$APP_PATH_FLAVOR" ]; then
  APP_PATH="$APP_PATH_FLAVOR"
elif [ -d "$APP_PATH_DEFAULT" ]; then
  APP_PATH="$APP_PATH_DEFAULT"
else
  echo "ERROR: Build finished but Pomo.app was not found in Release-production or Release."
  exit 1
fi
echo "--> Found compiled app at: $APP_PATH"

# Re-sign with a stable local identity. Ad-hoc signed apps are refused by
# UNUserNotificationCenter ("Notifications are not allowed for this
# application"), so banners never appear. Create the identity once with:
#   ./scripts/setup-macos-signing.sh
SIGN_IDENTITY="${POMO_SIGN_IDENTITY:-Pomo Dev Signing}"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
  echo "--> Signing app with identity: $SIGN_IDENTITY"
  find "$APP_PATH/Contents/Frameworks" -maxdepth 1 \
    \( -name "*.framework" -o -name "*.dylib" \) -print0 2>/dev/null \
    | while IFS= read -r -d '' nested; do
        codesign --force -s "$SIGN_IDENTITY" --timestamp=none "$nested"
      done
  codesign --force -s "$SIGN_IDENTITY" --timestamp=none \
    --entitlements "$PROJECT_ROOT/macos/Runner/Release.entitlements" \
    "$APP_PATH"
  codesign --verify --deep --strict "$APP_PATH"
  echo "--> Signature OK ($SIGN_IDENTITY)"
else
  echo "WARNING: signing identity '$SIGN_IDENTITY' not found; app stays ad-hoc signed."
  echo "         macOS will refuse notification banners for ad-hoc signed apps."
  echo "         Run ./scripts/setup-macos-signing.sh once to fix this."
fi

echo "--> Removing old .dmg if present..."
rm -f "$DMG_PATH"

echo "--> Generating Pomo.dmg in project folder..."
if command -v create-dmg >/dev/null 2>&1; then
  if create-dmg --help 2>&1 | grep -q -- "--no-code-sign"; then
    echo "--> Detected sindresorhus/create-dmg (Node.js version)..."
    create-dmg --overwrite --no-version-in-filename --no-code-sign "$APP_PATH" "$PROJECT_ROOT" || {
      echo "--> Node create-dmg errored; falling back to hdiutil..."
      rm -f "$DMG_PATH"
      hdiutil create -volname "Pomo" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"
    }
  else
    echo "--> Detected bash create-dmg..."
    create-dmg \
      --volname "Pomo" \
      --window-pos 200 120 \
      --window-size 600 400 \
      --icon-size 100 \
      --icon "Pomo.app" 175 190 \
      --hide-extension "Pomo.app" \
      --app-drop-link 425 190 \
      "$DMG_PATH" \
      "$APP_PATH" || {
        echo "--> create-dmg UI styling skipped or errored; falling back to hdiutil..."
        rm -f "$DMG_PATH"
        hdiutil create -volname "Pomo" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"
      }
  fi
else
  hdiutil create -volname "Pomo" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"
fi

echo ""
echo "=========================================================================="
echo " SUCCESS! .dmg generated at:"
echo "   $DMG_PATH"
echo "=========================================================================="
echo "Double-click Pomo.dmg in Finder or install it directly via:"
echo "   open \"$DMG_PATH\""
