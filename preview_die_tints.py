"""Render the held die under every dice-type accent, at the REAL on-screen size.

The die is ~38px wide in game (53px of ink x the sprite's 0.709 scale). Judging a tint on
the 337px source is how we keep shipping effects that vanish at play speed, so the top row
here is 1:1 and the bottom row is a 3x zoom for inspection only.

Left block  = modulate straight to DicePalette.accent(type)
Right block = accent lifted 15% toward white (candidate: keeps the die luminous against
              the navy cloak / dark act-2 backgrounds without losing identity)
"""

import numpy as np
from PIL import Image

ACCENT = [
    ("blue", "3D7BFF"), ("red", "FF2F3E"), ("green", "48D147"),
    ("magma", "FF5A14"), ("mech", "B9C1CB"), ("even", "E9B83D"),
    ("odd", "FF9526"), ("evil", "E14FE1"), ("giant", "A9D648"),
]
SPRITE_SCALE = 0.709091
BG = (26, 24, 38)          # roughly the dim combat backdrop behind the hero
LIFT = 0.15                 # toward white


def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def tinted(die_rgba, color):
    out = die_rgba.astype(float).copy()
    for c in range(3):
        out[..., c] *= color[c]
    return np.clip(out, 0, 255).astype(np.uint8)


def main():
    src = Image.open("main_character_die.png").convert("RGBA")
    bbox = src.getbbox()
    die = np.array(src.crop(bbox))
    h, w = die.shape[:2]
    on_screen_w = max(1, int(round(w * SPRITE_SCALE)))
    on_screen_h = max(1, int(round(h * SPRITE_SCALE)))

    pad = 10
    cell_w = on_screen_w * 3 + pad * 2          # widest cell is the 3x zoom
    cell_h = on_screen_h + pad + on_screen_h * 3 + pad
    sheet = Image.new("RGB", (cell_w * len(ACCENT), cell_h * 2 + pad), BG)

    for block, lift in enumerate((0.0, LIFT)):
        for i, (name, hx) in enumerate(ACCENT):
            rgb = hex_rgb(hx)
            rgb = tuple(c + (1.0 - c) * lift for c in rgb)
            tint = Image.fromarray(tinted(die, rgb), "RGBA")

            x0 = i * cell_w + pad
            y0 = block * (cell_h + pad) + pad
            small = tint.resize((on_screen_w, on_screen_h), Image.LANCZOS)
            sheet.paste(small, (x0, y0), small)
            big = tint.resize((on_screen_w * 3, on_screen_h * 3), Image.NEAREST)
            sheet.paste(big, (x0, y0 + on_screen_h + pad), big)

    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    sheet.save("die_tint_preview.png")
    print("die ink %dx%d -> on-screen %dx%d" % (w, h, on_screen_w, on_screen_h))
    print("wrote die_tint_preview.png (top block = raw accent, bottom = %.0f%% lift)"
          % (LIFT * 100))


if __name__ == "__main__":
    main()
