#!/usr/bin/env python3
"""make-feature-card.py — feature list info-card (Xiaohongshu 3:4, 1080x1440)

Second image in a post: turns the project's selling points into a clean
card grid so readers can quickly absorb value. Consistent style with
make-cover.py (deep blue-dark gradient, heiti fonts).
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1440
FONT_MEDIUM = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_LIGHT = "/System/Library/Fonts/STHeiti Light.ttc"

BG_TOP = (16, 20, 28)
BG_BOT = (30, 42, 60)
CARD_BG = (34, 42, 58)
CARD_BORDER = (60, 75, 100)
ACCENT = (102, 194, 255)
TEXT = (235, 240, 247)
MUTED = (150, 170, 200)

HEADER = "为什么值得试？"
FEATURES = [
    ("🐋", "鲸鱼图标", "颜值在线，Dock 上架得好看"),
    ("⚡", "原生轻量", "仅 200KB，秒杀 Electron"),
    ("🚀", "双击启动", "自动进工作区 + 开浏览器"),
    ("⏹", "关闭即停", "Dock 退出，服务干净停止"),
    ("🔌", "随机端口", "永不跟别的软件抢端口"),
    ("📖", "开源免费", "MIT 协议，代码随便用"),
]


def vertical_gradient(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        r = top[0] + (bottom[0] - top[0]) * y // h
        g = top[1] + (bottom[1] - top[1]) * y // h
        b = top[2] + (bottom[2] - top[2]) * y // h
        d.line([(0, y), (w, y)], fill=(r, g, b))
    return img


def center_text(d, text, y, size, fill, path=FONT_MEDIUM):
    f = ImageFont.truetype(path, size)
    bb = d.textbbox((0, 0), text, font=f)
    d.text(((W - (bb[2] - bb[0])) // 2, y), text, font=f, fill=fill)
    return y + size + 8


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/feature-card.png"
    img = vertical_gradient(W, H, BG_TOP, BG_BOT)
    d = ImageDraw.Draw(img)

    # header
    y = center_text(d, HEADER, 90, 76, (255, 255, 255))
    y += 12
    # thin accent line under header
    d.line([(W // 2 - 160, y - 10), (W // 2 + 160, y - 10)], fill=ACCENT, width=3)
    y += 30

    # feature cards: 2 columns x 3 rows
    col_w = (W - 3 * 70) // 2       # left/right margin 60, gap 40
    card_h = 330
    gap = 34
    x0 = 60
    for i, (emoji, title, desc) in enumerate(FEATURES):
        col = i % 2
        row = i // 2
        cx = x0 + col * (col_w + 40)
        cy = y + row * (card_h + gap)
        # rounded card
        d.rounded_rectangle([cx, cy, cx + col_w, cy + card_h], radius=26,
                            fill=CARD_BG, outline=CARD_BORDER, width=2)

        # emoji at top-left of card
        f_emoji = ImageFont.truetype(FONT_MEDIUM, 72)
        d.text((cx + 34, cy + 30), emoji, font=f_emoji, fill=(255, 255, 255))

        # title
        f_title = ImageFont.truetype(FONT_MEDIUM, 46)
        tb = d.textbbox((0, 0), title, font=f_title)
        d.text((cx + 34, cy + 130), title, font=f_title, fill=TEXT)

        # desc (small)
        f_desc = ImageFont.truetype(FONT_LIGHT, 30)
        # wrap? keep short, draw on one/two lines
        d.text((cx + 34, cy + 205), desc, font=f_desc, fill=MUTED)

    # footer
    d.text((60, H - 120), "dsh-launcher · 开源", font=ImageFont.truetype(FONT_LIGHT, 32),
           fill=(120, 140, 170))

    img.save(out)
    print(f"✅ {out} ({img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    main()
