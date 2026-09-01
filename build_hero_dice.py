"""Build the hero body + the nine per-type held dice from Jenya's single artwork.

Why this exists
---------------
The hero levitates a die that must recolour to the ACTIVE dice type. The old approach
tinted one greyscale die with modulate, which multiplies - so the pips could only ever
be a lighter shade of the body, never the cream-on-colour the real dice use. Instead we
bake nine textures here and swap the texture at runtime (player.gd::_update_die_tint).

Three things in the source art make this delicate:
  * the background is flat WHITE and the pips are also pure white, so a naive key punches
    the pips out as holes. We fill enclosed regions - but only small ones, because the
    staff crook is a genuine see-through hole (6938 px, vs 808 px for the largest pip).
  * transparent pixels keep their white RGB unless bled, and Godot's filtering then drags
    that white into the silhouette as a fringe at the 7x downscale the game renders at.
  * the die must sit on the SAME canvas as the body at its original relative position, or
    it will not drop back into the hole it left (see split_hero_die.py for the full why).

Re-run after any new delivery from Jenya, then --headless --import.
"""
import colorsys
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = "C:/Users/julie/Downloads/Telegram Desktop/MAinCharacter_blue.png"
BODY_OUT = "main_character_chibi.png"
DIE_OUT = "main_character_die.png"

TARGET_INK_H = 704.0        # 2x the shipped art, so the 250px combat render is oversampled
CANVAS_RATIO = (337 / 308, 376 / 352)   # canvas:ink ratio of the art this replaces
INK_OFFSET = (6.5 * 2, 1.0 * 2)          # ink centre vs canvas centre, from the shipped art
HOLE_FILL_MAX = 2000        # pips ~<810 px; the staff crook is 6938 px and must stay open
OUTLINE_LUM = 70            # her black linework; the grey drop shadow sits well above this

# DicePalette.ACCENT lerped 15% toward white == exactly what the live modulate tint produced,
# so the colours stay continuous with what has already been playtested.
ACCENT = {
    "blue": "3D7BFF", "red": "FF2F3E", "green": "48D147", "giant": "A9D648",
    "magma": "FF5A14", "mech": "B9C1CB", "even": "E9B83D", "odd": "FF9526",
    "evil": "E14FE1",
}

# Act-2 dice infusions override a type's accent, and the die the hero holds recoloured
# with them for free while this was a modulate tint. Baking them keeps that true - the
# key is the infusion id, which is what player.gd looks up.
INFUSED = {
    "arcane": "9A66FF", "berserker": "FF5C33", "repented": "FFDE7A", "bulky": "47D65A",
    "gnome": "6CE05C", "clockwork": "E0B24A", "inferno": "FF8A2A", "bulwark": "5FB6E8",
    "octet": "FF6B4A",
}


def lifted(hexs, t=0.15):
    r, g, b = (int(hexs[i:i + 2], 16) for i in (0, 2, 4))
    return np.array([(c + (255 - c) * t) for c in (r, g, b)], dtype=float)


def key_and_bleed(path):
    """Key by the LINE ART, keep the enclosed pips, then bleed colour outward."""
    rgb = np.array(Image.open(path).convert("RGB")).astype(float)
    dist = np.sqrt(((255.0 - rgb) ** 2).sum(axis=2))
    lum = rgb.mean(axis=2)

    # The source carries a painted grey drop shadow. Near the body it is solid enough
    # (measured rgb ~167) to survive ANY distance-from-white threshold, and it composites
    # as a glowing halo over anything that is not her white background. It cannot be
    # separated by colour - but it always sits OUTSIDE her linework. So: flood the image
    # inward from the border through everything that is not black line, and whatever the
    # flood cannot reach is the character. Drops ~144k px a white key would have kept.
    free = ~(lum < OUTLINE_LUM)
    lab, n = ndimage.label(free)
    edge_ids = set(lab[0, :]) | set(lab[-1, :]) | set(lab[:, 0]) | set(lab[:, -1])
    edge_ids.discard(0)
    inside = ~np.isin(lab, list(edge_ids))

    # Enclosed pure-white regions are pips and belt-plate dots - real art, keep them.
    # The one exception is the staff crook, a genuine see-through hole, separated by
    # area with a wide margin (6938 px vs 810 px for the largest pip).
    white = inside & (dist < 25.0)
    wl, wn = ndimage.label(white)
    if wn:
        sizes = ndimage.sum(white, wl, range(1, wn + 1))
        crook = np.isin(wl, [i + 1 for i, sz in enumerate(sizes) if sz >= HOLE_FILL_MAX])
        inside &= ~crook

    # Hard silhouette on purpose: the linework key cuts inside the outline core, so less
    # than a pixel of edge is lost, and the 2.7x downscale below does the antialiasing
    # cleanly. A soft rim here would just re-admit the shadow it exists to remove.
    alpha = inside.astype(float)

    # Bleed: every transparent/partial pixel takes the colour of its nearest opaque
    # neighbour, so no white survives to be dragged in by downscale filtering.
    core = alpha > 0.85
    _, (iy, ix) = ndimage.distance_transform_edt(~core, return_indices=True)
    bled = rgb[iy, ix]
    soft = alpha < 0.999
    rgb[soft] = bled[soft]
    return rgb, alpha


def largest_components(alpha):
    solid = ndimage.binary_fill_holes(alpha > 0.5)
    lab, n = ndimage.label(solid)
    sizes = ndimage.sum(solid, lab, range(1, n + 1))
    order = np.argsort(sizes)[::-1]
    return lab == order[0] + 1, lab == order[1] + 1   # body, die


def bbox(mask):
    ys, xs = np.nonzero(mask)
    return xs.min(), xs.max() + 1, ys.min(), ys.max() + 1


def place(rgb, alpha, mask, scale, canvas, ink_centre):
    """Scale in premultiplied space and paste so ink_centre lands on the canvas anchor."""
    a = np.where(mask, alpha, 0.0)
    pre = rgb * a[..., None]
    h, w = a.shape
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    pre_s = np.array(Image.fromarray(pre.astype(np.uint8), "RGB").resize((nw, nh), Image.LANCZOS)).astype(float)
    a_s = np.array(Image.fromarray((a * 255).astype(np.uint8), "L").resize((nw, nh), Image.LANCZOS)).astype(float) / 255.0
    with np.errstate(divide="ignore", invalid="ignore"):
        out = np.where(a_s[..., None] > 0.004, pre_s / np.maximum(a_s[..., None], 1e-6), 0.0)
    out = np.clip(out, 0, 255)

    layer = Image.fromarray(np.dstack([out.astype(np.uint8), (a_s * 255).astype(np.uint8)]), "RGBA")
    dst = Image.new("RGBA", canvas, (0, 0, 0, 0))
    ox = round(ink_centre[0] - 0)      # anchor handled by caller via ink_centre offsets
    dst.alpha_composite(layer, (round(ink_centre[0]), round(ink_centre[1])))
    return dst


def recolour_die(die_img, target):
    """Swap only the body fill; her white pips and near-black outline pass through."""
    arr = np.array(die_img).astype(float)
    rgb, a = arr[..., :3], arr[..., 3] / 255.0
    mx = rgb.max(axis=2) / 255.0
    mn = rgb.min(axis=2) / 255.0
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    solid = a > 0.02
    pips = solid & (sat < 0.20) & (mx > 0.80)
    outline = solid & (mx < 0.32)
    body = solid & ~pips & ~outline
    v0 = mx[body].mean()
    out = rgb.copy()
    ratio = np.clip(mx[body] / v0, 0.0, 1.6)[:, None]
    out[body] = np.clip(target[None, :] * ratio, 0, 255)
    return Image.fromarray(np.dstack([out.astype(np.uint8), arr[..., 3].astype(np.uint8)]), "RGBA")


def main():
    rgb, alpha = key_and_bleed(SRC)
    body_m, die_m = largest_components(alpha)
    bx0, bx1, by0, by1 = bbox(body_m)
    scale = TARGET_INK_H / (by1 - by0)

    ink_w, ink_h = (bx1 - bx0) * scale, (by1 - by0) * scale
    canvas = (round(ink_w * CANVAS_RATIO[0]), round(ink_h * CANVAS_RATIO[1]))
    anchor = (canvas[0] / 2 + INK_OFFSET[0], canvas[1] / 2 + INK_OFFSET[1])
    # top-left of the scaled full image so the body ink centre lands on the anchor
    off = (anchor[0] - (bx0 + bx1) / 2 * scale, anchor[1] - (by0 + by1) / 2 * scale)

    body = place(rgb, alpha, body_m, scale, canvas, off)
    die = place(rgb, alpha, die_m, scale, canvas, off)
    body.save(BODY_OUT)
    die.save(DIE_OUT)

    baked = dict(ACCENT)
    baked.update(INFUSED)
    for t, hx in baked.items():
        recolour_die(die, lifted(hx)).save(f"hero_die_{t}.png")

    def ink(im):
        ys, xs = np.nonzero(np.array(im)[..., 3] > 16)
        return xs.min(), xs.max() + 1, ys.min(), ys.max() + 1

    b, d = ink(body), ink(die)
    print(f"scale            {scale:.5f}   canvas {canvas[0]}x{canvas[1]}")
    print(f"body ink         {b[1]-b[0]}x{b[3]-b[2]}  at x{b[0]}-{b[1]} y{b[2]}-{b[3]}  feet y={b[3]}")
    print(f"die  ink         {d[1]-d[0]}x{d[3]-d[2]}  at x{d[0]}-{d[1]} y{d[2]}-{d[3]}")
    fits = d[0] >= 0 and d[2] >= 0 and d[1] <= canvas[0] and d[3] <= canvas[1]
    print(f"die inside canvas: {fits}")
    print(f"baked {len(ACCENT) + len(INFUSED)} die textures")
    print(f"player.tscn Sprite2D scale should be {0.709091 * (352.0 / TARGET_INK_H):.7f}")


if __name__ == "__main__":
    main()
