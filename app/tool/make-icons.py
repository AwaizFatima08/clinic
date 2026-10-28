"""Draws the app icon (calendar + medical cross on clinic teal) into assets/icon/.
Plain shapes in code, no AI images. Run from app/: python3 tool/make-icons.py
then: dart run flutter_launcher_icons"""
from pathlib import Path
from PIL import Image, ImageDraw

TEAL, TEAL_DARK, WHITE = (15, 118, 110, 255), (11, 92, 86, 255), (255, 255, 255, 255)
OUT = Path(__file__).resolve().parent.parent / "assets" / "icon"


def draw(size, pad=220, background=True):
    s = 1024  # draw large, then downscale for smooth edges
    img = Image.new("RGBA", (s, s), TEAL if background else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = pad, pad + 40 * (s - 2 * pad) / 584, s - pad, s - pad + 40 * (s - 2 * pad) / 584
    w = x1 - x0
    r = w // 9
    d.rounded_rectangle((x0, y0, x1, y1), r, fill=WHITE)
    band = y0 + (y1 - y0) * 0.24
    d.rectangle((x0, band - 14 * w / 584, x1, band), fill=TEAL_DARK)
    ring_w, ring_h = w / 14, (y1 - y0) / 6
    for cx in (x0 + w * 0.3, x0 + w * 0.7):
        d.rounded_rectangle((cx - ring_w / 2, y0 - ring_h / 2, cx + ring_w / 2, y0 + ring_h / 2), ring_w / 2, fill=TEAL_DARK)
    cx, cy = (x0 + x1) / 2, band + (y1 - band) / 2
    arm, thick = w * 0.22, w * 0.09
    d.rounded_rectangle((cx - thick, cy - arm, cx + thick, cy + arm), thick / 3, fill=TEAL)
    d.rounded_rectangle((cx - arm, cy - thick, cx + arm, cy + thick), thick / 3, fill=TEAL)
    return img.resize((size, size), Image.LANCZOS)


OUT.mkdir(parents=True, exist_ok=True)
draw(1024).convert("RGB").save(OUT / "icon.png", optimize=True)
# Adaptive icon foreground: transparent, artwork inside the central safe zone (~60%).
draw(1024, pad=330, background=False).save(OUT / "adaptive_foreground.png", optimize=True)
draw(512).convert("RGB").save(OUT / "play_store_512.png", optimize=True)
print("wrote", *sorted(p.name for p in OUT.iterdir()))
