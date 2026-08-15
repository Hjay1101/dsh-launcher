#!/usr/bin/env bash
# ============================================================
#  dsh-launcher — installer
#
#  Installs dsh-launcher to ~/.local/bin (or a custom dir)
#  so you can run it from anywhere as `dsh-launcher`.
#
#  Usage: ./install.sh [install-dir]
# ============================================================
set -euo pipefail

INSTALL_DIR="${1:-$HOME/.local/bin}"
SCRIPT_SRC="$(cd "$(dirname "$0")" && pwd)/dsh-launcher.sh"

if [[ ! -f "$SCRIPT_SRC" ]]; then
  echo "❌ dsh-launcher.sh not found next to install.sh" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
install -m 0755 "$SCRIPT_SRC" "$INSTALL_DIR/dsh-launcher"

echo "✅ Installed to $INSTALL_DIR/dsh-launcher"
echo ""
echo "Next steps:"
echo "  1. Add to your PATH (if not already):"
echo "       export PATH=\"$INSTALL_DIR:\$PATH\""
echo "  2. Optional: set your default workspace:"
echo "       export DSH_WORKSPACE=\"/path/to/your/workspace\""
echo ""
echo "Then run: dsh-launcher"
