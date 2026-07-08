#!/usr/bin/env python3
"""Generate a retina DMG background image for the Uninstally installer.

Produces `scripts/assets/dmg-background.png` (1x) and `dmg-background@2x.png`
(2x/retina). The layout is a clean, System-Settings-style panel with an arrow
guiding the user to drag the app onto the Applications shortcut.

Run: python3 scripts/make_dmg_background.py
"""

import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "assets")

# Logical DMG window content size (points). Icons are placed by create_dmg.sh.
W, H = 640, 400
SCALE = 2  # retina master

TOP = (245, 245, 248)
BOTTOM = (228, 229, 236)
ARROW = (150, 150, 158)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def render(scale: int) -> Image.Image:
    w, h = W * scale, H * scale
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        row = lerp(TOP, BOTTOM, y / (h - 1))
        for x in range(w):
            px[x, y] = row

    d = ImageDraw.Draw(img)
    # Subtle title.
    # A dashed arrow pointing from the app icon (left) to Applications (right).
    cy = int(h * 0.52)
    x0, x1 = int(w * 0.40), int(w * 0.60)
    lw = max(2, 3 * scale)
    dash = 14 * scale
    gap = 10 * scale
    x = x0
    while x < x1 - 8 * scale:
        d.line([(x, cy), (min(x + dash, x1 - 8 * scale), cy)], fill=ARROW, width=lw)
        x += dash + gap
    # Arrow head.
    hx = x1
    d.polygon(
        [(hx, cy - 9 * scale), (hx + 14 * scale, cy), (hx, cy + 9 * scale)],
        fill=ARROW,
    )
    return img


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    render(1).save(os.path.join(OUT_DIR, "dmg-background.png"))
    render(SCALE).save(os.path.join(OUT_DIR, "dmg-background@2x.png"))
    print("Wrote dmg-background.png and dmg-background@2x.png")


if __name__ == "__main__":
    main()
