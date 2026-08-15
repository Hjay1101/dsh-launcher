#!/usr/bin/env python3
"""generate-icon.py — build the DeepSeek Harness app icon (macOS HIG)

Produces:
  assets/AppIcon-1024.png           square white background (for reference)
  assets/AppIcon-rounded-1024.png   white rounded-square background (file
                                    icons via set-icon.sh)
  assets/AppIcon.icns               multi-size .icns from the ROUNDED variant

Why rounded in the .icns: macOS only applies the automatic rounded-corner
mask to properly distributed/signed apps. Ad-hoc-signed custom .app bundles
(like the one build-app.sh produces) show icons as-is — so the rounded
background must be baked into the icon itself.

Spec (macOS Big Sur icon grid):
  canvas 1024x1024, content area 824x824 centered, corner radius 185.4px,
  whale scaled to 75% of the content width.

Usage:
  python3 generate-icon.py <favicon.svg> [output-dir]

Requires: python3 + Pillow, and a way to rasterize SVG → PNG (macOS sips
can convert PDF; or use svglib/reportlab). The script rasterizes the SVG
through PDF via svglib if available, else expects an existing whale PNG.
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

SIZE = 1024
CONTENT = 824
RADIUS = 185.4
MARGIN = (SIZE - CONTENT) // 2
WHALE_PCT = 0.75


def rasterize_svg(svg_path, out_png):
    """Rasterize SVG -> PNG (1024) via svglib->PDF->sips, or a pre-rendered PNG."""
    if svg_path.lower().endswith(".png"):
        Image.open(svg_path).convert("RGBA").save(out_png)
        return
    try:
        from svglib.svglib import svg2rlg
        from reportlab.graphics import renderPDF

        d = svg2rlg(svg_path)
        scale = SIZE / max(d.width, d.height)
        d.width *= scale
        d.height *= scale
        d.scale(scale, scale)
        pdf = out_png + ".pdf"
        renderPDF.drawToFile(d, pdf)
        subprocess.run(
            ["sips", "-s", "format", "png", pdf, "--out", out_png],
            check=True, capture_output=True,
        )
        os.remove(pdf)
    except ImportError:
        raise SystemExit(
            "Need svglib+reportlab to rasterize SVG: "
            "python3 -m pip install --user svglib reportlab"
        )


def compose(whale_png, rounded):
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0) if rounded else (255, 255, 255, 255))
    if rounded:
        ImageDraw.Draw(canvas).rounded_rectangle(
            [MARGIN, MARGIN, MARGIN + CONTENT, MARGIN + CONTENT],
            radius=RADIUS, fill=(255, 255, 255, 255),
        )
    whale = Image.open(whale_png).convert("RGBA").crop(Image.open(whale_png).convert("RGBA").getbbox())
    target_w = int(CONTENT * WHALE_PCT)
    ratio = target_w / whale.width
    whale = whale.resize((target_w, int(whale.height * ratio)), Image.LANCZOS)
    canvas.alpha_composite(whale, ((SIZE - whale.width) // 2, (SIZE - whale.height) // 2))
    return canvas


def build_icns(src_png, out_icns):
    with tempfile.TemporaryDirectory() as td:
        iconset = os.path.join(td, "AppIcon.iconset")
        os.makedirs(iconset)
        for s in (16, 32, 128, 256, 512):
            subprocess.run(["sips", "-z", str(s), str(s), src_png,
                            "--out", os.path.join(iconset, f"icon_{s}x{s}.png")],
                           check=True, capture_output=True)
            d = s * 2
            subprocess.run(["sips", "-z", str(d), str(d), src_png,
                            "--out", os.path.join(iconset, f"icon_{s}x{s}@2x.png")],
                           check=True, capture_output=True)
        subprocess.run(["iconutil", "-c", "icns", iconset, "-o", out_icns],
                       check=True, capture_output=True)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    svg = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "assets")
    os.makedirs(out_dir, exist_ok=True)

    with tempfile.TemporaryDirectory() as td:
        whale_png = os.path.join(td, "whale.png")
        rasterize_svg(svg, whale_png)

        rounded = compose(whale_png, rounded=True)
        rounded.save(os.path.join(out_dir, "AppIcon-rounded-1024.png"))
        square = compose(whale_png, rounded=False)
        square.save(os.path.join(out_dir, "AppIcon-1024.png"))

        # .icns uses the ROUNDED variant: ad-hoc-signed custom .app bundles
        # do NOT get the automatic macOS rounded-corner mask, so the rounded
        # background must be baked into the icon itself (same as file icons).
        icns = os.path.join(out_dir, "AppIcon.icns")
        build_icns(os.path.join(out_dir, "AppIcon-rounded-1024.png"), icns)

    print("✅ assets/AppIcon-1024.png")
    print("✅ assets/AppIcon-rounded-1024.png")
    print("✅ assets/AppIcon.icns")


if __name__ == "__main__":
    main()
