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
# DeepSeek Harness — macOS 应用启动器（静默版）
# 双击 .app：无窗口后台启动 dsh web，就绪后自动开浏览器。
# 关闭：Dock 右键退出 / Cmd+Q → launcher 收到信号 →
#       先 kill dsh 再退出 → 服务随之停止。
# 日志：$WORKSPACE/.dsh/dsh.log（工作区不可写时回退 ~/.dsh/dsh.log）

# ---------- 配置（可用环境变量覆盖） ----------
WORKSPACE="${DSH_WORKSPACE:-$(pwd)}"
PORT="${DSH_PORT:-3080}"
URL="http://127.0.0.1:${PORT}"
if [[ -d "$WORKSPACE" && -w "$WORKSPACE" ]]; then
  LOG_DIR="$WORKSPACE/.dsh"
else
  LOG_DIR="$HOME/.dsh"
fi
LOG_FILE="$LOG_DIR/dsh.log"
# ---------------------------------------------

# GUI 启动的进程 PATH 很精简，把常见 node/dsh 位置补进 PATH。
# 构造顺序 = 优先级顺序（nvm 默认版本最高，/usr/local 最低），
# 最后统一放到 PATH 最前面，确保 dsh（Node 脚本）用对 node。
NODE_PATHS=()
NVM_DEF_BIN=""
if [[ -f "$HOME/.nvm/alias/default" ]]; then
  NVM_DEF="$(cat "$HOME/.nvm/alias/default")"
  [[ "$NVM_DEF" != v* ]] && NVM_DEF="v$NVM_DEF"
  for d in "$HOME"/.nvm/versions/node/"$NVM_DEF"*/bin; do
    [[ -d "$d" ]] && NVM_DEF_BIN="$d" && break
  done
fi
[[ -n "$NVM_DEF_BIN" ]] && NODE_PATHS+=("$NVM_DEF_BIN")
for d in "$HOME"/.nvm/versions/node/*/bin; do
  [[ -d "$d" && "$d" != "$NVM_DEF_BIN" ]] && NODE_PATHS+=("$d")
done
NODE_PATHS+=("$HOME/.volta/bin" "$HOME/.local/bin" "$HOME/bin" /opt/homebrew/bin /usr/local/bin)

EXTRA=""
for NODE_DIR in "${NODE_PATHS[@]}"; do
  if [[ -x "$NODE_DIR/node" || -x "$NODE_DIR/dsh" ]]; then
    case ":$EXTRA:" in
      *":$NODE_DIR:"*) ;;
      *) EXTRA="$EXTRA:$NODE_DIR" ;;
    esac
  fi
done
PATH="${EXTRA#:}:$PATH"
export PATH

# 已在运行 → 直接开浏览器并退出（不重复启动）
if lsof -nP -iTCP:${PORT} -sTCP:LISTEN >/dev/null 2>&1; then
  open "$URL"
  exit 0
fi

# 定位 dsh：PATH → npx 缓存最新版 → 回退 npx
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
mkdir -p "$LOG_DIR"
{
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') DeepSeek Harness 启动 ====="
  echo "  工作区: $WORKSPACE"
  echo "  dsh:    $DSH"
  echo "  地址:   $URL"
} >> "$LOG_FILE"

# 后台启动 dsh web（日志写文件），launcher 保持运行盯住它
if [[ "$DSH" == "npx" ]]; then
  npx --yes @deepseek-ai/dsh web --port "$PORT" >> "$LOG_FILE" 2>&1 &
else
  "$DSH" web --port "$PORT" >> "$LOG_FILE" 2>&1 &
fi
SERVER_PID=$!

# 关闭 app（Dock 右键退出 / Cmd+Q）→ 先杀 dsh 再退出，服务随之停止
cleanup() {
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') 服务停止（app 已退出）=====" >> "$LOG_FILE"
  kill "$SERVER_PID" 2>/dev/null || true
  exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP

# 等待端口就绪（最多 60s）后打开浏览器
for i in $(seq 1 60); do
  if lsof -nP -iTCP:${PORT} -sTCP:LISTEN >/dev/null 2>&1; then
    sleep 1
    open "$URL"
    echo "✅ 服务已启动，浏览器已打开（日志: $LOG_FILE）" >> "$LOG_FILE"
    break
  fi
  sleep 1
done

# 保持运行：dsh 存活期间 launcher 一直活着（Dock 图标亮着 = 服务在跑）
wait "$SERVER_PID"
LAUNCHER

chmod +x "$APP_PATH/Contents/MacOS/launcher"
cp "$SCRIPT_DIR/assets/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"

# Sign the bundle (ad-hoc). macOS refuses to launch unsigned .app bundles,
# so this step is REQUIRED — without it double-clicking does nothing.
codesign --force --deep --sign - "$APP_PATH" >/dev/null 2>&1

echo "✅ Built: $APP_PATH"
echo "   Double-click it to launch. Set DSH_WORKSPACE to change the workspace."
echo "   Or run: DSH_WORKSPACE=/path/to/workspace open \"$APP_PATH\""
