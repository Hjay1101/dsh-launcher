#!/usr/bin/env bash
# ============================================================
#  dsh-launcher — one-click launcher for DeepSeek Harness Web
#  https://github.com/Hjay1101/dsh-launcher
#
#  Boots the DeepSeek Harness web UI in your workspace and
#  opens the browser automatically. Works on macOS & Linux.
#
#  License: MIT
# ============================================================
set -euo pipefail

# ---------- defaults (override via env or CLI args) ----------
PORT="${DSH_PORT:-3080}"
WORKSPACE="${DSH_WORKSPACE:-$(pwd)}"
NO_BROWSER="${DSH_NO_BROWSER:-0}"
DSH_BIN="${DSH_BIN:-}"
# --------------------------------------------------------------

print_usage() {
  cat <<'EOF'
Usage: dsh-launcher [options]

One-click launcher for DeepSeek Harness Web.
Runs `dsh web` in the given workspace and opens the browser
once the server is ready.

Options:
  -w, --workspace <dir>   Workspace root (default: $DSH_WORKSPACE or current dir)
  -p, --port <port>       Web port (default: $DSH_PORT or 3080)
  -b, --dsh-bin <path>    Explicit dsh binary path (default: auto-detect)
  -n, --no-browser        Do not auto-open the browser
  -h, --help              Show this help

Environment variables:
  DSH_WORKSPACE, DSH_PORT, DSH_BIN, DSH_NO_BROWSER
EOF
}

# ---------- helpers ----------
port_in_use() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
  elif command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | grep -q ":$port "
  elif command -v nc >/dev/null 2>&1; then
    nc -z 127.0.0.1 "$port" >/dev/null 2>&1
  else
    (exec 3<>"/dev/tcp/127.0.0.1/$port") >/dev/null 2>&1
  fi
}

open_browser() {
  local url="$1"
  if [[ "$NO_BROWSER" == "1" ]]; then return 0; fi
  if command -v open >/dev/null 2>&1; then          # macOS
    open "$url"
  elif command -v xdg-open >/dev/null 2>&1; then     # Linux
    xdg-open "$url" >/dev/null 2>&1 || true
  else
    echo "👉 Open $url in your browser manually."
  fi
}

find_dsh() {
  # 1) explicit path
  if [[ -n "$DSH_BIN" && -x "$DSH_BIN" ]]; then
    echo "$DSH_BIN"; return 0
  fi
  # 2) on PATH
  if command -v dsh >/dev/null 2>&1; then
    command -v dsh; return 0
  fi
  # 3) newest cached copy under ~/.npm/_npx (installed via `npx`)
  local latest=""
  local d
  for d in "$HOME"/.npm/_npx/*/node_modules/.bin/dsh; do
    [[ -x "$d" ]] && latest="$d"
  done
  if [[ -n "$latest" ]]; then
    echo "$latest"; return 0
  fi
  # 4) fall back to npx (may download on first run)
  echo "npx"
}

# ---------- parse args ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--workspace)  WORKSPACE="$2"; shift 2 ;;
    -p|--port)       PORT="$2"; shift 2 ;;
    -b|--dsh-bin)    DSH_BIN="$2"; shift 2 ;;
    -n|--no-browser) NO_BROWSER=1; shift ;;
    -h|--help)       print_usage; exit 0 ;;
    *) echo "❌ Unknown option: $1" >&2; print_usage >&2; exit 1 ;;
  esac
done

URL="http://127.0.0.1:${PORT}"

if [[ ! -d "$WORKSPACE" ]]; then
  echo "❌ Workspace not found: $WORKSPACE" >&2
  exit 1
fi

cd "$WORKSPACE"

echo "=============================================="
echo "  DeepSeek Harness Web Launcher"
echo "=============================================="

# already running → just open the browser
if port_in_use "$PORT"; then
  echo "✅ Server already running on port ${PORT}. Opening browser..."
  open_browser "$URL"
  exit 0
fi

DSH="$(find_dsh)"
echo "🚀 Starting DeepSeek Harness Web ..."
echo "   workspace : $WORKSPACE"
echo "   dsh       : $DSH"
echo "   url       : $URL"
echo "   (stop: press Ctrl+C in this window)"
echo ""

if [[ "$DSH" == "npx" ]]; then
  npx --yes @deepseek-ai/dsh web &
else
  "$DSH" web &
fi
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' INT TERM

# wait until the port is ready (max 60s), then open the browser
for i in $(seq 1 60); do
  if port_in_use "$PORT"; then
    sleep 1
    open_browser "$URL"
    echo "🌐 Browser opened: $URL"
    break
  fi
  sleep 1
done

wait "$SERVER_PID"
echo ""
echo "⏹ Server stopped. You can close this window."
