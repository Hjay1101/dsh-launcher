#!/usr/bin/env bash
# ============================================================
#  set-icon.sh — set a custom icon on any file/folder (macOS)
#
#  Uses the system AppKit API via JXA (JavaScript for
#  Automation) — no third-party tools required.
#
#  Usage:
#    ./set-icon.sh <icon.png|icon.icns|icon.svg> <target>
#
#  Examples:
#    ./set-icon.sh assets/favicon.svg ~/Desktop/MyFolder
#    ./set-icon.sh assets/AppIcon.icns ~/Desktop/launcher.command
#
#  Tip: after setting, refresh Finder with:
#    killall Finder   (or just wait a moment)
# ============================================================
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <icon-image> <target-file-or-folder>" >&2
  exit 1
fi

ICON="$1"
TARGET="$2"

if [[ ! -f "$ICON" ]]; then
  echo "❌ Icon not found: $ICON" >&2
  exit 1
fi
if [[ ! -e "$TARGET" ]]; then
  echo "❌ Target not found: $TARGET" >&2
  exit 1
fi

# If the icon is an SVG, render it to a temp PNG. Try several backends:
#   1. svglib (Python, pip-installable)
#   2. rsvg-convert (brew install librsvg)
#   3. qlmanage (built into macOS)
ICON_PATH="$ICON"
if [[ "$ICON" == *.svg ]]; then
  TMP_PNG="$(mktemp -t dsh-icon.XXXXXX).png"
  RENDERED=0

  if python3 -c "import svglib, reportlab" 2>/dev/null; then
    python3 - "$ICON" "$TMP_PNG" <<'EOF'
import sys
from svglib.svglib import svg2rlg
from reportlab.graphics import renderPDF
svg, out = sys.argv[1], sys.argv[2]
d = svg2rlg(svg)
scale = 1024.0 / max(d.width, d.height)
d.width *= scale; d.height *= scale; d.scale(scale, scale)
pdf = out + ".pdf"
renderPDF.drawToFile(d, pdf)
EOF
    # convert the PDF to PNG with macOS's built-in sips
    sips -s format png "$TMP_PNG.pdf" --out "$TMP_PNG" >/dev/null 2>&1
    RENDERED=1
  elif command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 1024 -h 1024 -o "$TMP_PNG" "$ICON"
    RENDERED=1
  elif command -v qlmanage >/dev/null 2>&1; then
    qlmanage -t -s 1024 -o "$(dirname "$TMP_PNG")" "$ICON" >/dev/null 2>&1
    mv "$(dirname "$TMP_PNG")/$(basename "$ICON").png" "$TMP_PNG"
    RENDERED=1
  fi

  if [[ "$RENDERED" != "1" ]]; then
    echo "❌ Cannot render SVG. Install one of:" >&2
    echo "   python3 -m pip install --user svglib reportlab pillow" >&2
    echo "   brew install librsvg" >&2
    rm -f "$TMP_PNG"
    exit 1
  fi
  ICON_PATH="$TMP_PNG"
fi

osascript -l JavaScript - "$ICON_PATH" "$TARGET" <<'EOF'
ObjC.import('AppKit')
ObjC.import('Foundation')
function run(argv) {
  const img = $.NSImage.alloc.initWithContentsOfFile(argv[0])
  if (img.isNil()) return 'FAIL: cannot load ' + argv[0]
  const ok = $.NSWorkspace.sharedWorkspace.setIconForFileOptions(img, argv[1], 0)
  return ok ? 'OK: icon set on ' + argv[1] : 'FAIL: setIcon returned false'
}
EOF

[[ -n "${TMP_PNG:-}" ]] && rm -f "$TMP_PNG" "$TMP_PNG.pdf"
echo "✅ Icon set. If Finder hasn't refreshed, run: killall Finder"
