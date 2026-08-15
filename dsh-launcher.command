#!/bin/bash
# ============================================================
#  dsh-launcher (macOS) — double-click launcher
#
#  Double-click this file to boot DeepSeek Harness Web in
#  your workspace and open the browser automatically.
#
#  Configure your default workspace either here or via the
#  DSH_WORKSPACE environment variable (e.g. in ~/.zshrc):
#     export DSH_WORKSPACE="/path/to/your/workspace"
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Optional: set a default workspace for double-click use
# DEFAULT_WORKSPACE="/path/to/your/workspace"

if [[ -n "${DEFAULT_WORKSPACE:-}" ]]; then
  exec "$SCRIPT_DIR/dsh-launcher.sh" --workspace "$DEFAULT_WORKSPACE" "$@"
else
  exec "$SCRIPT_DIR/dsh-launcher.sh" "$@"
fi
