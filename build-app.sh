#!/usr/bin/env bash
# ============================================================
#  build-app.sh — build the DeepSeek Harness.app bundle
#
#  Creates a native macOS app with the official whale icon.
#  Double-clicking the app opens a Terminal window, boots
#  `dsh web` in your workspace, and opens the browser when
#  the server is ready.
#
#  Usage: ./build-app.sh [output-dir]
#  (default output dir: ~/Desktop)
#
#  Requires: macOS, bash, and the dsh CLI (see README).
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${1:-$HOME/Desktop}"
APP_NAME="DeepSeek Harness"
APP_PATH="$OUT_DIR/$APP_NAME.app"

# ---------- build the app bundle ----------
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>launcher</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.hjay1101.dsh-launcher</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>DeepSeek Harness</string>
	<key>CFBundleDisplayName</key>
	<string>DeepSeek Harness</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>12.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>LSUIElement</key>
	<false/>
</dict>
</plist>
PLIST

# ---------- launcher: native binary (stable Dock icon) ----------
# A bare bash script as CFBundleExecutable has no NSApplication run loop,
# so the Dock icon bounces forever. Compile native-launcher.m instead.
clang -framework Cocoa "$SCRIPT_DIR/native-launcher.m" -o "$APP_PATH/Contents/MacOS/launcher" 2>&1

# ---------- start-dsh.sh: boots dsh web (forked by the launcher) ----------
cp "$SCRIPT_DIR/start-dsh.sh" "$APP_PATH/Contents/Resources/start-dsh.sh"
chmod +x "$APP_PATH/Contents/Resources/start-dsh.sh"

cp "$SCRIPT_DIR/assets/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"

# Sign the bundle (ad-hoc). macOS refuses to launch unsigned .app bundles,
# so this step is REQUIRED — without it double-clicking does nothing.
codesign --force --deep --sign - "$APP_PATH" >/dev/null 2>&1

echo "✅ Built: $APP_PATH"
echo "   Double-click it to launch. Set DSH_WORKSPACE to change the workspace."
echo "   Or run: DSH_WORKSPACE=/path/to/workspace open \"$APP_PATH\""
