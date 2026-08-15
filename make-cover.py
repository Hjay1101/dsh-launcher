#!/usr/bin/env python3
"""make-cover.py — generate the minimal social cover (Xiaohongshu 3:4, 1080x1440)

Design goal: hook on the whale icon, keep copy minimal so readers click in.
  - deep blue-black gradient background
  - large rounded whale icon as the visual hero
  - one-line title (DeepSeek Harness · 轻量启动器)
  - one-line subtle hook + GitHub handle at the bottom

Usage:
  python3 make-cover.py [output.png]
  (default output: assets/xiaohongshu-cover.png)

Requires: python3 + Pillow, macOS PingFang/Heiti fonts (adjust if not present).
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1440
FONT_MEDIUM = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_LIGHT = "/System/Library/Fonts/STHeiti Light.ttc"

ICON_PATHS = [
    os.path.join(os.path.dirname(__file__), "assets", "AppIcon-rounded-1024.png"),
    "/Users/doudou/Desktop/dsh-launcher/assets/AppIcon-rounded-1024.png",
]

TITLE_MAIN = "DeepSeek Harness"
TITLE_SUB = "轻量启动器"
HOOK = "原生 · 开箱即用"
GITHUB = "github.com/Hjay1101/dsh-launcher"


def vertical_gradient(w, h, top, bottom):
    base = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(base)
    for y in range(h):
        r = top[0] + (bottom[0] - top[0]) * y // h
        g = top[1] + (bottom[1] - top[1]) * y // h
        b = top[2] + (bottom[2] - top[2]) * y // h
        d.line([(0, y), (w, y)], fill=(r, g, b))
    return base


def center_text(d, text, y, size, fill, path=FONT_MEDIUM):
    f = ImageFont.truetype(path, size)
    b = d.textbbox((0, 0), text, font=f)
    d.text(((W - (b[2] - b[0])) // 2, y), text, font=f, fill=fill)
    return y + size + 8


def find_icon():
    for p in ICON_PATHS:
        if os.path.exists(p):
            return p
    raise SystemExit("whale icon not found — run from repo root or pass assets/")


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(__file__), "assets", "xiaohongshu-cover.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)

    img = vertical_gradient(W, H, (16, 20, 28), (30, 42, 60))
    d = ImageDraw.Draw(img)

    # large whale icon as visual hero
    icon = Image.open(find_icon()).convert("RGBA")
    iw = 560
    icon = icon.resize((iw, iw), Image.LANCZOS)
    img.paste(icon, ((W - iw) // 2, 170), icon)

    # minimal title
    y = center_text(d, TITLE_MAIN, 820, 74, (255, 255, 255))
    y = center_text(d, TITLE_SUB, y, 60, (102, 194, 255))
    y += 20
    y = center_text(d, HOOK, y, 34, (170, 185, 210), FONT_LIGHT)

    # footer
    d.line([(W // 2 - 220, H - 190), (W // 2 + 220, H - 190)], fill=(60, 75, 100), width=2)
    center_text(d, GITHUB, H - 160, 32, (140, 160, 190), FONT_LIGHT)

    img.save(out)
    print(f"✅ {out} ({img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    main()
