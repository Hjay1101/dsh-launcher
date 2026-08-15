#!/usr/bin/env python3
"""make-cover.py — generate the social cover image (Xiaohongshu 3:4, 1080x1440)

Renders a promo cover for the dsh-launcher project using the whale icon:
  - top: rounded whale icon
  - title area
  - feature bullet list
  - bottom: GitHub handle

Usage:
  python3 make-cover.py [output.png]
  (default output: assets/xiaohongshu-cover.png)

Requires: python3 + Pillow, macOS PingFang/Heiti fonts (adjust if not present).
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1440
BG = (20, 22, 26)
ICON_PATHS = [
    os.path.join(os.path.dirname(__file__), "assets", "AppIcon-rounded-1024.png"),
    "/Users/doudou/Desktop/dsh-launcher/assets/AppIcon-rounded-1024.png",
]
FONT_MEDIUM = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_LIGHT = "/System/Library/Fonts/STHeiti Light.ttc"
GITHUB_HANDLE = "Hjay1101/dsh-launcher"

TITLE_MAIN = "DeepSeek Harness"
TITLE_SUB = "一键启动器"
LABEL = "MAC · 开源 · 效率工具"
BULLETS = [
    "🐋 鲸鱼图标 · 颜值在线",
    "🚀 双击启动 · 自动开浏览器",
    "⏹ 关闭即停 · 不用记命令",
    "⚡ 原生轻量 · 仅 200KB",
    "🔌 随机端口 · 永不冲突",
    "📖 已开源 · MIT 协议",
]


def find_icon():
    for p in ICON_PATHS:
        if os.path.exists(p):
            return p
    raise SystemExit("whale icon not found — run from repo root or pass assets/")


def text_center(d, text, y, size, fill):
    font = ImageFont.truetype(FONT_MEDIUM, size)
    bbox = d.textbbox((0, 0), text, font=font)
    x = (W - (bbox[2] - bbox[0])) // 2
    d.text((x, y), text, font=font, fill=fill)
    return y + size + 12


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(__file__), "assets", "xiaohongshu-cover.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    # icon
    icon = Image.open(find_icon()).convert("RGBA")
    iw = 360
    icon = icon.resize((iw, iw), Image.LANCZOS)
    img.paste(icon, ((W - iw) // 2, 110), icon)

    # label
    y = 560
    font = ImageFont.truetype(FONT_LIGHT, 36)
    b = d.textbbox((0, 0), LABEL, font=font)
    d.text(((W - (b[2] - b[0])) // 2, y), LABEL, font=font, fill=(150, 170, 200))
    y += 70

    # title
    y = text_center(d, TITLE_MAIN, y, 72, (255, 255, 255))
    y = text_center(d, TITLE_SUB, y, 96, (102, 194, 255))
    y += 40

    # bullets
    d.text((80, y), "特点", font=ImageFont.truetype(FONT_LIGHT, 34), fill=(150, 170, 200))
    y += 62
    for bt in BULLETS:
        d.text((80, y), bt, font=ImageFont.truetype(FONT_MEDIUM, 42), fill=(235, 240, 247))
        y += 68

    # footer
    d.text((80, H - 150), f"GitHub: {GITHUB_HANDLE}",
           font=ImageFont.truetype(FONT_LIGHT, 34), fill=(120, 140, 170))

    img.save(out)
    print(f"✅ {out} ({img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    main()
