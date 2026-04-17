#!/usr/bin/env python3
"""Generate a 1024x1024 opaque app icon for HydroLite: a water drop on a sky→aqua gradient."""
from PIL import Image, ImageDraw, ImageFilter
import os

SIZE = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "HydroLite", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png")


def lerp(a, b, t): return int(a + (b - a) * t)


def vgrad(size, top, bottom):
    img = Image.new("RGB", (size, size), top)
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        d.line([(0, y), (size, y)], fill=(lerp(top[0], bottom[0], t), lerp(top[1], bottom[1], t), lerp(top[2], bottom[2], t)))
    return img


def droplet(img):
    """Simple teardrop shape centered slightly high."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    cx = SIZE // 2
    top_y = int(SIZE * 0.22)
    bottom_y = int(SIZE * 0.78)
    w = int(SIZE * 0.28)
    # Bottom of drop = circle
    d.ellipse([cx - w, bottom_y - 2 * w, cx + w, bottom_y], fill=(255, 255, 255, 245))
    # Pointed top via polygon
    d.polygon([
        (cx, top_y),
        (cx + int(w * 0.9), bottom_y - int(w * 1.2)),
        (cx - int(w * 0.9), bottom_y - int(w * 1.2)),
    ], fill=(255, 255, 255, 245))
    # Soft highlight
    hx, hy = cx - int(w * 0.25), bottom_y - int(w * 1.2)
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.ellipse([hx - int(w * 0.25), hy - int(w * 0.3),
                hx + int(w * 0.25), hy + int(w * 0.15)], fill=(255, 255, 255, 90))
    hl = hl.filter(ImageFilter.GaussianBlur(radius=14))
    overlay.paste(hl, (0, 0), hl)
    img.paste(overlay, (0, 0), overlay)


def main():
    img = vgrad(SIZE, (52, 158, 245), (12, 92, 190)).convert("RGBA")
    droplet(img)
    final = Image.new("RGB", (SIZE, SIZE), (12, 92, 190))
    final.paste(img, (0, 0), img)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    final.save(OUT, "PNG", optimize=True)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
