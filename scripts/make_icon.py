#!/usr/bin/env python3
"""Generate the Uninstally app icon.

Renders a macOS style "floating squircle" with an indigo to violet gradient and
a clean white broom sweeping glyph (with a few sparkle accents), then exports
every size required by the asset catalog. Run:

    python3 scripts/make_icon.py
"""

import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

SS = 4096  # supersampled master canvas
OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Uninstally", "Assets.xcassets", "AppIcon.appiconset",
)

# Brand palette (indigo / violet), matching AccentColor.colorset.
TOP = (128, 116, 248)
BOTTOM = (74, 52, 190)
WHITE = (255, 255, 255, 255)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def squircle_box():
    # Apple template: content rect ~824/1024 of the canvas, centered.
    side = int(SS * 824 / 1024)
    margin = (SS - side) // 2
    return [margin, margin, margin + side, margin + side], int(side * 0.2237)


def vertical_gradient(size, top, bottom):
    grad = Image.new("RGB", (1, size), 0)
    for y in range(size):
        grad.putpixel((0, y), lerp(top, bottom, y / (size - 1)))
    return grad.resize((size, size))


def rounded_mask(box, radius):
    mask = Image.new("L", (SS, SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def make_broom_layer():
    """Draw an upright broom on a transparent layer (rotated later)."""
    layer = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    cx = SS // 2
    # Handle (capsule).
    hw = 78
    d.rounded_rectangle([cx - hw, 980, cx + hw, 2140], radius=hw, fill=WHITE)

    # Binding band that gathers the bristles.
    d.rounded_rectangle([cx - 300, 2110, cx + 300, 2300], radius=48, fill=WHITE)

    # Bristles: fan of tapering teeth with small gaps between them.
    teeth = 6
    top_y, bot_y = 2300, 3080
    top_half, bot_half = 300, 470       # half-widths of the fan
    gap_top, gap_bot = 16, 30           # gaps between teeth
    for i in range(teeth):
        t0 = i / teeth
        t1 = (i + 1) / teeth
        xt0 = cx - top_half + top_half * 2 * t0 + gap_top / 2
        xt1 = cx - top_half + top_half * 2 * t1 - gap_top / 2
        xb0 = cx - bot_half + bot_half * 2 * t0 + gap_bot / 2
        xb1 = cx - bot_half + bot_half * 2 * t1 - gap_bot / 2
        d.polygon(
            [(xt0, top_y), (xt1, top_y), (xb1, bot_y), (xb0, bot_y)],
            fill=WHITE,
        )
        # Round the bristle tips slightly.
        r = (xb1 - xb0) / 2
        d.ellipse([xb0, bot_y - r, xb1, bot_y + r], fill=WHITE)

    # Rotate so the handle tilts to the upper right, bristles sweep lower left.
    return layer.rotate(-33, resample=Image.BICUBIC, center=(cx, SS // 2 + 40))


def sparkle(draw, cx, cy, R, color=WHITE):
    r = R * 0.32
    pts = [
        (cx, cy - R), (cx + r, cy - r), (cx + R, cy), (cx + r, cy + r),
        (cx, cy + R), (cx - r, cy + r), (cx - R, cy), (cx - r, cy - r),
    ]
    draw.polygon(pts, fill=color)


def build_master():
    canvas = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    box, radius = squircle_box()
    mask = rounded_mask(box, radius)

    # Soft drop shadow beneath the squircle.
    shadow = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    soff = [box[0], box[1] + 70, box[2], box[3] + 70]
    sdraw.rounded_rectangle(soff, radius=radius, fill=(20, 14, 60, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(70))
    canvas = Image.alpha_composite(canvas, shadow)

    # Gradient fill clipped to the squircle.
    grad = vertical_gradient(SS, TOP, BOTTOM).convert("RGBA")
    canvas.paste(grad, (0, 0), mask)

    # Top sheen: a soft white glow near the top, kept inside the squircle.
    sheen = Image.new("L", (SS, SS), 0)
    ImageDraw.Draw(sheen).ellipse(
        [box[0] - 200, box[1] - SS * 0.36, box[2] + 200, box[1] + SS * 0.30],
        fill=70,
    )
    sheen = sheen.filter(ImageFilter.GaussianBlur(120))
    sheen = ImageChops.darker(sheen, mask)  # clip to squircle
    white = Image.new("RGBA", (SS, SS), (255, 255, 255, 255))
    canvas.paste(white, (0, 0), sheen)

    # Broom glyph.
    broom = make_broom_layer()
    canvas = Image.alpha_composite(canvas, broom)

    # Sparkle accents suggesting freshly cleaned space.
    fx = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(fx)
    sparkle(fdraw, int(SS * 0.34), int(SS * 0.30), int(SS * 0.055))
    sparkle(fdraw, int(SS * 0.28), int(SS * 0.44), int(SS * 0.032))
    sparkle(fdraw, int(SS * 0.40), int(SS * 0.46), int(SS * 0.022))
    canvas = Image.alpha_composite(canvas, fx)

    return canvas.resize((1024, 1024), Image.LANCZOS)


SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    master = build_master()
    for name, px in SIZES:
        master.resize((px, px), Image.LANCZOS).save(os.path.join(OUT_DIR, name))
        print(f"wrote {name} ({px}px)")


if __name__ == "__main__":
    main()
