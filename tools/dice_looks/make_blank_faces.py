# Builds <type>_blank.png (a die face with no pips) for the 9 dice types, by cloning a
# matching patch of each face's own body over every pip. Source faces are the ones with the
# fewest pips. Output lands next to the faces in assets/images.
# Rerun it whenever the dice art changes (H-001), then let Godot reimport the 9 blanks.
# A before/after contact sheet goes to the system temp folder for a visual check.
import os
import tempfile
import numpy as np
from PIL import Image
from scipy import ndimage
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "images") + os.sep
SCR = tempfile.gettempdir() + os.sep
SOURCES = {"blue": "blue1", "red": "red1", "evil": "evil6", "giant": "giant1", "magma": "magma1",
           "even": "even2", "odd": "odd1", "green": "green1", "mech": "mech1"}

def disk(h, w, cy, cx, r):
    yy, xx = np.ogrid[:h, :w]
    return (yy - cy) ** 2 + (xx - cx) ** 2 <= r * r

def find_pips(rgb, alpha):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    cream = (r > 205) & (g > 200) & (b > 185) & (alpha > 200)
    lab, n = ndimage.label(cream)
    pips = []
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        area = len(ys)
        if area < 400:        # specks, highlights
            continue
        cy, cx = ys.mean(), xs.mean()
        rad = np.sqrt(area / np.pi)
        # roundness check: the bbox should be about 2r square
        hgt, wid = ys.max() - ys.min() + 1, xs.max() - xs.min() + 1
        if abs(hgt - wid) > 0.35 * max(hgt, wid) or area < 0.6 * np.pi * (max(hgt, wid) / 2) ** 2:
            continue
        pips.append((cy, cx, rad))
    return pips

def outline_extent(rgb, cy, cx, rad):
    # walk outward along 16 rays until the pixel stops being dark (the pip's outline)
    h, w, _ = rgb.shape
    ext = []
    lum = rgb.max(axis=2)   # the pip outline is near-black; dark bodies (blue, evil) still have one bright channel
    for k in range(16):
        a = 2 * np.pi * k / 16
        d = rad
        while d < rad * 1.8:
            y, x = int(cy + np.sin(a) * d), int(cx + np.cos(a) * d)
            if not (0 <= y < h and 0 <= x < w):
                break
            if lum[y, x] > 70 and d > rad + 2:
                break
            d += 1
        ext.append(d)
    return float(np.median(ext))

def build(type_name, src_name):
    im = Image.open(ROOT + src_name + ".png").convert("RGBA")
    arr = np.asarray(im).astype(np.float32)
    rgb, alpha = arr[..., :3], arr[..., 3]
    h, w = alpha.shape
    pips = find_pips(rgb, alpha)
    masks = []
    for cy, cx, rad in pips:
        ext = outline_extent(rgb, cy, cx, rad)
        # On a near-black body (magma, green, evil) the outline can't be told from the body by
        # darkness, and the walk runs to its cap. Fall back to the outline ratio measured on
        # the faces where it CAN be seen (blue/red/odd/mech/even: outline ~= 0.17 x radius).
        if ext >= rad * 1.5:
            ext = rad * 1.18 + 3
        print(f"    pip rad {rad:.1f} outline_ext {ext:.1f}")
        masks.append((cy, cx, ext + 16))   # +16 swallows the soft halo magma paints round its pips
    union = np.zeros((h, w), bool)
    for cy, cx, mr in masks:
        union |= disk(h, w, cy, cx, mr + 14)
    # the die's interior: well inside the opaque area, away from the rim and outline band
    interior = ndimage.binary_erosion(alpha > 250, iterations=90)
    out = rgb.copy()
    for cy, cx, mr in masks:
        feather = 12
        R = mr + feather
        tgt = disk(h, w, cy, cx, R)
        ring = disk(h, w, cy, cx, R + 26) & ~disk(h, w, cy, cx, R + 2)
        best = None
        for dy in range(-396, 397, 12):
            for dx in range(-396, 397, 12):
                if dx * dx + dy * dy < (2.2 * R) ** 2:
                    continue
                sy, sx = cy + dy, cx + dx
                # the whole source disk must lie inside the canvas: disk() silently clips, so a
                # centre off the edge produced an EMPTY disk that passed every test below and
                # np.roll wrapped the paste around from the opposite corner
                if sy - R - 26 < 0 or sx - R - 26 < 0 or sy + R + 26 >= h or sx + R + 26 >= w:
                    continue
                src_disk = disk(h, w, sy, sx, R + 26)
                if (src_disk & ~interior).any() or (src_disk & union).any():
                    continue
                ring_src = np.roll(np.roll(ring, dy, 0), dx, 1)
                score = np.abs(rgb[ring] - rgb[ring_src]).mean()
                if best is None or score < best[0]:
                    best = (score, dy, dx)
        if best is None:
            # No clean body patch big enough on this face (evil's 6 pips leave no gap wide
            # enough to clone from). Harmonic fill instead: the hole is solved as a smooth
            # continuation of its own border, which on a flat cel body is invisible.
            hole = disk(h, w, cy, cx, mr + 3)
            y0, y1 = int(cy - R - 4), int(cy + R + 5)
            x0, x1 = int(cx - R - 4), int(cx + R + 5)
            sub = out[y0:y1, x0:x1].copy()
            hm = hole[y0:y1, x0:x1]
            ring_px = sub[disk(y1 - y0, x1 - x0, cy - y0, cx - x0, mr + 12) & ~hm]
            sub[hm] = np.median(ring_px, axis=0)
            for _ in range(900):
                sm = ndimage.uniform_filter(sub, size=(3, 3, 1))
                sub[hm] = sm[hm]
            # a little grain back, matched to the ring's own fine variation
            # robust spread (MAD), capped: a crack running through the ring must not turn the
            # fill into static
            mad = np.median(np.abs(ring_px - np.median(ring_px, axis=0)), axis=0).mean() * 1.4826
            grain = min(mad * 0.6, 1.2)
            rng = np.random.default_rng(7)
            noise = ndimage.gaussian_filter(rng.normal(0, 1, sub.shape[:2]), 1.2)
            noise = noise / (noise.std() + 1e-6) * grain
            sub[hm] += noise[hm][:, None]
            out[y0:y1, x0:x1] = sub
            print(f"  {type_name}: pip at ({cx:.0f},{cy:.0f}) r={mr:.0f} <- harmonic fill (grain {grain:.1f})")
            continue
        _, dy, dx = best
        yy, xx = np.ogrid[:h, :w]
        dist = np.sqrt((yy - cy) ** 2 + (xx - cx) ** 2)
        a = np.clip((R - dist) / feather, 0, 1)[..., None]
        shifted = np.roll(np.roll(rgb, -dy, 0), -dx, 1)
        out = out * (1 - a) + shifted * a
        print(f"  {type_name}: pip at ({cx:.0f},{cy:.0f}) r={mr:.0f} <- offset ({dx},{dy}) score {best[0]:.1f}")
    res = np.dstack([out, alpha]).clip(0, 255).astype(np.uint8)
    Image.fromarray(res, "RGBA").save(ROOT + type_name + "_blank.png")
    return len(pips)

for t, s in SOURCES.items():
    n = build(t, s)
    print(t, "pips removed:", n)

# contact sheet: source face vs blank, full res downscaled + at game size (140px, LANCZOS)
tiles = []
for t, s in SOURCES.items():
    a = Image.open(ROOT + s + ".png").convert("RGBA").resize((200, 200), Image.LANCZOS)
    b = Image.open(ROOT + t + "_blank.png").convert("RGBA").resize((200, 200), Image.LANCZOS)
    tile = Image.new("RGBA", (410, 210), (40, 40, 48, 255))
    tile.alpha_composite(a, (0, 5)); tile.alpha_composite(b, (205, 5))
    tiles.append(tile)
sheet = Image.new("RGBA", (410 * 3, 210 * 3), (20, 20, 20, 255))
for i, tile in enumerate(tiles):
    sheet.alpha_composite(tile, ((i % 3) * 410, (i // 3) * 210))
sheet.save(SCR + "blank_faces_sheet.png")
print("contact sheet: " + SCR + "blank_faces_sheet.png")
