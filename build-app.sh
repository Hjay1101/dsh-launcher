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
# DeepSeek Harness app launcher
# - server already running -> just open the browser
# - otherwise -> `open -a Terminal` runs Resources/boot.command
#   (LaunchServices file-open, NOT Apple Events: no TCC automation
#   permission prompt, works reliably on first double-click)
PORT="${DSH_PORT:-3080}"
URL="http://127.0.0.1:${PORT}"
APP_ROOT="$(cd "$(dirname "$0")" && cd .. && pwd)"   # -> Contents/
BOOT_CMD="$APP_ROOT/Resources/boot.command"

if lsof -nP -iTCP:${PORT} -sTCP:LISTEN >/dev/null 2>&1; then
  open "$URL"
  exit 0
fi

if [[ -f "$BOOT_CMD" ]]; then
  chmod +x "$BOOT_CMD"
  open -a Terminal "$BOOT_CMD"
else
  osascript -e "display dialog \"Cannot find $BOOT_CMD\" buttons {\"OK\"} with icon caution" 2>/dev/null || true
  exit 1
fi
exit 0
LAUNCHER

cat > "$APP_PATH/Contents/Resources/boot.command" <<'BOOTCMD'
#!/bin/bash
# DeepSeek Harness boot.command — run by `open -a Terminal`
# Boots dsh web in a Terminal window and opens the browser when ready.
# Ctrl+C stops. Workspace: $DSH_WORKSPACE or current dir.

WORKSPACE="${DSH_WORKSPACE:-$(pwd)}"
PORT="${DSH_PORT:-3080}"
URL="http://127.0.0.1:${PORT}"

cd "$WORKSPACE" 2>/dev/null || cd ~

echo "=============================================="
echo "  DeepSeek Harness Web"
echo "  地址: ${URL}  |  停止: Ctrl+C"
echo "=============================================="
echo ""

if lsof -nP -iTCP:${PORT} -sTCP:LISTEN >/dev/null 2>&1; then
  open "$URL"
  echo "✅ 服务已在运行，已打开浏览器。"
  exit 0
fi

# GUI-launched processes have a minimal PATH: make sure node & dsh are
# reachable (nvm first, /usr/local last to avoid an old node shadowing).
for NODE_DIR in \
  "$HOME/.nvm/versions/node/"*/bin \
  "$HOME/.volta/bin" "$HOME/.local/bin" "$HOME/bin" \
  /opt/homebrew/bin /usr/local/bin; do
  if [[ -x "$NODE_DIR/node" || -x "$NODE_DIR/dsh" ]]; then
    case ":$PATH:" in
      *":$NODE_DIR:"*) ;;
      *) PATH="$NODE_DIR:$PATH" ;;
    esac
  fi
done
export PATH

find_dsh() {
  if command -v dsh >/dev/null 2>&1; then
    command -v dsh; return 0
  fi
  local latest=""
  local d
  for d in "$HOME"/.npm/_npx/*/node_modules/.bin/dsh; do
    [[ -x "$d" ]] && latest="$d"
  done
  if [[ -n "$latest" ]]; then
    echo "$latest"; return 0
  fi
  echo "npx"
}

DSH="$(find_dsh)"
echo "🚀 启动 dsh: $DSH"

if [[ "$DSH" == "npx" ]]; then
  npx --yes @deepseek-ai/dsh web &
else
  "$DSH" web &
fi
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' INT TERM

for i in $(seq 1 60); do
  if lsof -nP -iTCP:${PORT} -sTCP:LISTEN >/dev/null 2>&1; then
    sleep 1
    open "$URL"
    echo "🌐 已在浏览器打开: $URL"
    break
  fi
  sleep 1
done

wait "$SERVER_PID"
echo ""
echo "⏹ 服务已停止，窗口可关闭。"
BOOTCMD

chmod +x "$APP_PATH/Contents/MacOS/launcher" "$APP_PATH/Contents/Resources/boot.command"
cp "$SCRIPT_DIR/assets/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"

# Sign the bundle (ad-hoc). macOS refuses to launch unsigned .app bundles,
# so this step is REQUIRED — without it double-clicking does nothing.
codesign --force --deep --sign - "$APP_PATH" >/dev/null 2>&1

echo "✅ Built: $APP_PATH"
echo "   Double-click it to launch. Set DSH_WORKSPACE to change the workspace."
echo "   Or run: DSH_WORKSPACE=/path/to/workspace open \"$APP_PATH\""
