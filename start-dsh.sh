#!/bin/bash
# ============================================================
#  DeepSeek Harness — start-dsh.sh（由原生 launcher fork 执行）
#  开源: https://github.com/Hjay1101/dsh-launcher (MIT)
#
#  职责：启动 dsh web，等端口就绪后开浏览器，然后 wait 保持
#  dsh 子进程存活。原生 launcher 负责 Dock 图标稳定 + 生命周期
#  （退出时 SIGTERM 本脚本 → kill dsh → 服务停）。
# ============================================================

# ---------- 配置（可用环境变量覆盖） ----------
WORKSPACE="${DSH_WORKSPACE:-/Users/doudou/Desktop/SellerFocus Agent}"
PORT="${DSH_PORT:-3080}"
URL="http://127.0.0.1:${PORT}"
if [[ -d "$WORKSPACE" && -w "$WORKSPACE" ]]; then
  LOG_DIR="$WORKSPACE/.dsh"
else
  LOG_DIR="$HOME/.dsh"
fi
LOG_FILE="$LOG_DIR/dsh.log"
# ---------------------------------------------

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }
mkdir -p "$LOG_DIR" 2>/dev/null
log "start-dsh.sh 启动 | 工作区=$WORKSPACE | 端口=$PORT"

# GUI 启动的进程 PATH 很精简，补进常见 node/dsh 位置（nvm 默认优先）
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

# 已在运行 → 直接开浏览器并退出（服务不是本实例启动的）
if lsof -nP -iTCP:${PORT} -sTCP:LISTEN >/dev/null 2>&1; then
  log "端口 $PORT 已有服务 → 直接 open 浏览器"
  open "$URL"
  log "open 已执行 exit=$?"
  # 服务已由他人启动，本脚本退出即可（原生 launcher 仍保持 Dock 稳定）
  while true; do sleep 3600; done
fi
log "端口 $PORT 空闲 → 进入启动流程"

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
log "定位 dsh: $DSH"
{
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') DeepSeek Harness 启动 ====="
  echo "  工作区: $WORKSPACE"
  echo "  dsh:    $DSH"
  echo "  地址:   $URL"
} >> "$LOG_FILE"

# 后台启动 dsh web
if [[ "$DSH" == "npx" ]]; then
  npx --yes @deepseek-ai/dsh web --port "$PORT" >> "$LOG_FILE" 2>&1 &
else
  "$DSH" web --port "$PORT" >> "$LOG_FILE" 2>&1 &
fi
SERVER_PID=$!

# 收到退出信号（原生 launcher 转发）→ 先 kill dsh 再退出
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
    log "端口就绪 → open 浏览器 exit=$?"
    echo "✅ 服务已启动，浏览器已打开（日志: $LOG_FILE）" >> "$LOG_FILE"
    break
  fi
  sleep 1
done
log "启动流程结束，进入 wait（保持 dsh 存活）"

# 保持运行：dsh 存活期间本脚本一直活着
wait "$SERVER_PID"
