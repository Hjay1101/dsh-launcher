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

cat > "$APP_PATH/Contents/MacOS/launcher" <<'LAUNCHER'
#!/bin/bash
# DeepSeek Harness app launcher — boots dsh web in a Terminal window
# and opens the browser when ready. Ctrl+C in the Terminal stops it.
#
# Workspace: $DSH_WORKSPACE, falling back to the current directory.

WORKSPACE="${DSH_WORKSPACE:-$(pwd)}"
PORT=3080
URL="http://127.0.0.1:${PORT}"

# already running -> just open the browser
if lsof -nP -iTCP:${PORT} -sTCP:LISTEN >/dev/null 2>&1; then
  open "$URL"
  exit 0
fi

# find dsh: PATH first, then npx (downloads on first run)
if command -v dsh >/dev/null 2>&1; then
  DSH_CMD="$(command -v dsh) web"
else
  DSH_CMD="npx --yes @deepseek-ai/dsh web"
fi

TERM_CMD="echo '=============================================='; echo '  DeepSeek Harness Web'; echo '  地址: ${URL}  |  停止: Ctrl+C'; echo '=============================================='; echo ''; cd \"$WORKSPACE\" 2>/dev/null || cd ~; exec $DSH_CMD; "

osascript -e "tell application \"Terminal\"" \
          -e "activate" \
          -e "do script \"$TERM_CMD\"" \
          -e "end tell" 2>/dev/null

for i in $(seq 1 60); do
  if lsof -nP -iTCP:${PORT} -sTCP:LISTEN >/dev/null 2>&1; then
    sleep 1
    open "$URL"
    exit 0
  fi
  sleep 1
done
LAUNCHER

chmod +x "$APP_PATH/Contents/MacOS/launcher"
cp "$SCRIPT_DIR/assets/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"

echo "✅ Built: $APP_PATH"
echo "   Double-click it to launch. Set DSH_WORKSPACE to change the workspace."
echo "   Or run: DSH_WORKSPACE=/path/to/workspace open \"$APP_PATH\""
