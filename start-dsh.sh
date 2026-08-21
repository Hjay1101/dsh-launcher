#!/bin/bash
# ============================================================
#  DeepSeek Harness — start-dsh.sh（由原生 launcher fork 执行）
#  开源: https://github.com/Hjay1101/dsh-launcher (MIT)
#
#  职责：
#    - 用随机空闲端口（或 DSH_PORT 指定的固定端口）启动 dsh web
#    - 用应用专属 DSH_HOME（与系统 ~/.dsh 隔离；CLI 用 ~/.dsh）
#    - HTTP 探活确认 Harness 真就绪，失败给出可操作提示
#    - wait 保持 dsh 子进程存活（原生 launcher 管 Dock + 生命周期）
# ============================================================

# ---------- 配置（可用环境变量覆盖） ----------
WORKSPACE="${DSH_WORKSPACE:-/Users/doudou/Desktop/SellerFocus Agent}"
HOST="127.0.0.1"
# ---------- 结束 ----------

# ---------- 日志位置 ----------
if [[ -d "$WORKSPACE" && -w "$WORKSPACE" ]]; then
  LOG_DIR="$WORKSPACE/.dsh"
else
  LOG_DIR="$HOME/.dsh"
fi
LOG_FILE="$LOG_DIR/dsh.log"
# ---------- 结束 ----------

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }
mkdir -p "$LOG_DIR" 2>/dev/null

# ---------- 应用专属 DSH_HOME（② 隔离，仅 .app 场景触发）----------
if [[ -z "$DSH_HOME" && "$(basename "$(dirname "$(dirname "$0")")")" == "DeepSeek Harness.app" ]]; then
  APP_SUPPORT="$HOME/Library/Application Support/DeepSeek Harness"
  DSH_HOME="$APP_SUPPORT/dsh"
  mkdir -p "$DSH_HOME" 2>/dev/null
  # 首次使用：专属目录为空但系统 ~/.dsh 有内容时，迁移核心配置（profiles/plugins）
  if [[ -z "$(ls -A "$DSH_HOME" 2>/dev/null)" && -d "$HOME/.dsh" ]]; then
    for d in profiles plugins; do
      if [[ -d "$HOME/.dsh/$d" ]]; then
        mkdir -p "$DSH_HOME"
        cp -R "$HOME/.dsh/$d" "$DSH_HOME/" 2>/dev/null
        log "已从系统 ~/.dsh 迁移 $d/ 到专属 DSH_HOME"
      fi
    done
  fi
  export DSH_HOME
  log "应用专属 DSH_HOME: $DSH_HOME"
fi
# ---------- 结束 ----------

# ---------- 随机空闲端口（① 默认随机，DSH_PORT 指定则固定）----------
if [[ -n "${DSH_PORT:-}" ]]; then
  PORT="$DSH_PORT"
  log "使用指定固定端口: $PORT"
else
  PORT="$(python3 - <<'PY' 2>/dev/null
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind(('127.0.0.1', 0))
print(s.getsockname()[1])
s.close()
PY
)"
  [[ -z "$PORT" ]] && PORT=3080   # 兜底
  log "随机分配空闲端口: $PORT"
fi
URL="http://${HOST}:${PORT}"
# ---------- 结束 ----------

log "start-dsh.sh 启动 | 工作区=$WORKSPACE | 端口=$PORT | DSH_HOME=${DSH_HOME:-<系统默认>}"

# ---------- GUI 精简 PATH 补全（nvm 默认优先）----------
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
# ---------- 结束 ----------

# ---------- 系统代理注入（DSH 的 Node 客户端默认不走系统代理）----------
# 用途: 让 dsh web 的 LLM 请求走系统 HTTP/HTTPS 代理，解决地区限制类 403
#      （如 gpt-5.6-luna 的 "This model is not available in your region"）。
# 覆盖: DSH_PROXY_URL 显式指定代理；DSH_PROXY_DISABLE=1 完全禁用本段。
# 默认: 自动读取 macOS 系统代理设置（scutil --proxy）。
# 注意: Node 需支持 --use-env-proxy（Node ≥ 22）；不支持时退化为不注入。
if [[ "${DSH_PROXY_DISABLE:-0}" != "1" ]]; then
  if [[ -n "${DSH_PROXY_URL:-}" ]]; then
    PROXY_URL="$DSH_PROXY_URL"
    log "使用显式 DSH_PROXY_URL: $PROXY_URL"
  else
    PROXY_URL="$(python3 - <<'PY' 2>/dev/null
import subprocess, re
try:
    out = subprocess.run(['scutil', '--proxy'], capture_output=True, text=True, timeout=5).stdout
    m = re.search(r'HTTPSProxy\s*:\s*(\S+)', out)
    p = re.search(r'HTTPSPort\s*:\s*(\d+)', out)
    if m and p:
        print(f'http://{m.group(1)}:{p.group(1)}')
except Exception:
    pass
PY
)"
    [[ -n "$PROXY_URL" ]] && log "自动检测系统代理: $PROXY_URL"
  fi
  if [[ -n "$PROXY_URL" ]]; then
    export HTTPS_PROXY="$PROXY_URL"
    export HTTP_PROXY="$PROXY_URL"
    export https_proxy="$PROXY_URL"
    export http_proxy="$PROXY_URL"
    # Node ≥ 22 的全局 fetch 通过 --use-env-proxy 读取代理环境变量
    if node -e "process.exit(process.versions.node.split('.')[0] >= 22 ? 0 : 1)" 2>/dev/null; then
      export NODE_OPTIONS="${NODE_OPTIONS:-} --use-env-proxy"
      log "已注入代理 $PROXY_URL + NODE_OPTIONS=--use-env-proxy"
    else
      log "⚠ Node 版本过低，无法启用 --use-env-proxy，代理注入不生效"
    fi
  else
    log "未检测到系统 HTTPS 代理，跳过代理注入"
  fi
fi
# ---------- 结束 ----------

# ---------- 已在运行？(HTTP 探活) ----------
if command -v curl >/dev/null 2>&1 && curl -s -o /dev/null --max-time 1 "$URL" 2>/dev/null; then
  log "Harness 已在运行（$URL）→ 直接 open 浏览器"
  open "$URL"
  log "open 已执行 exit=$?"
  while true; do sleep 3600; done   # 保持脚本，让 Dock 稳定
fi
log "端口 $URL 空闲 → 进入启动流程"

# ---------- 定位 dsh ----------
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
  echo "  DSH_HOME: ${DSH_HOME:-<系统 ~/.dsh>}"
} >> "$LOG_FILE"

# ---------- 启动 dsh web ----------
# --no-open: dsh web 自身默认会弹一次浏览器，launcher 却在探活成功后
#           又 open 一次 → 双击 app 会开两个网页。这里关掉内建 open，
#           只保留本脚本探活后的那一次（否则会重复）。
if [[ "$DSH" == "npx" ]]; then
  npx --yes @deepseek-ai/dsh web --host "$HOST" --port "$PORT" --no-open >> "$LOG_FILE" 2>&1 &
else
  "$DSH" web --host "$HOST" --port "$PORT" --no-open >> "$LOG_FILE" 2>&1 &
fi
SERVER_PID=$!
# ---------- 结束 ----------

# ---------- 关闭信号 → 先 kill dsh 再退出 ----------
cleanup() {
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') 服务停止（app 已退出）=====" >> "$LOG_FILE"
  kill "$SERVER_PID" 2>/dev/null || true
  exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP
# ---------- 结束 ----------

# ---------- HTTP 就绪探测（③ 替代 lsof）----------
STARTUP_TIMEOUT=45
ready=0
for i in $(seq 1 $STARTUP_TIMEOUT); do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    log "❌ dsh 进程提前退出，启动失败"
    echo "❌ DeepSeek Harness 启动失败（详见日志）" >> "$LOG_FILE"
    osascript -e "display dialog \"DeepSeek Harness 启动失败。\n请查看日志: $LOG_FILE\" buttons {\"好\"} with icon stop" 2>/dev/null || true
    exit 1
  fi
  if command -v curl >/dev/null 2>&1; then
    if curl -s -o /dev/null --max-time 1 "$URL" 2>/dev/null; then
      ready=1
      break
    fi
  else
    if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
      ready=1
      break
    fi
  fi
  sleep 1
done
# ---------- 结束 ----------

if [[ "$ready" == "1" ]]; then
  sleep 1
  open "$URL"
  log "✅ Harness 就绪 → open 浏览器 exit=$?"
  echo "✅ 服务已启动: $URL （日志: $LOG_FILE）" >> "$LOG_FILE"
else
  log "⏱ $STARTUP_TIMEOUT 秒内未就绪，启动失败"
  echo "❌ DeepSeek Harness 未能在 ${STARTUP_TIMEOUT}s 内就绪。" >> "$LOG_FILE"
  osascript -e "display dialog \"DeepSeek Harness 启动超时。\n请查看日志: $LOG_FILE\" buttons {\"好\"} with icon stop" 2>/dev/null || true
fi

log "启动流程结束，进入 wait（保持 dsh 存活）"

# 保持运行：dsh 存活期间本脚本一直活着
wait "$SERVER_PID"
