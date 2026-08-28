"""Split the hero art into (body-without-die) + (die-only) on an IDENTICAL canvas.

Why this exists
---------------
The hero levitates a white die above his open palm. To recolour that die to the active
dice type and punch it forward on attacks, it has to be its own node - and once it MOVES
it can no longer just be drawn on top of the baked one (the original would peek out from
underneath). So the die must genuinely be removed from the body art.

Both outputs keep the SOURCE CANVAS SIZE and the die's original pixel position. That is
load-bearing, not tidiness:
  * player.tscn gives both sprites the same transform, so at rest the die drops exactly
    into the hole it left behind;
  * the idle sway shader deforms in UV space weighted by height-within-the-texture, so an
    identical canvas means the die deforms exactly as it did while baked in - no drift
    between the hand and the die;
  * Enemy._get_content_rect (ground shadow + the debug A/B normalisation) reads the body
    art's alpha bbox, and the die sits strictly INSIDE the body's bbox, so removing it
    leaves every derived measurement untouched.

Re-run this whenever the hero art changes:
    python split_hero_die.py <combined.png> --body main_character_chibi.png \
                             --die main_character_die.png
then run a --headless --import before launching, or Godot renders the stale .ctex.

If the new art has no isolated die, the script refuses rather than guessing - player.gd
hides the overlay when the die texture is missing, so the game still runs.
"""

import argparse
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ALPHA_FLOOR = 16          # below this an "opaque" pixel is really antialias fringe
MIN_DIE_PX = 200          # smaller than this is a speck, not a die
MAX_DIE_FRACTION = 0.25   # a die is never a quarter of the character
ASPECT_TOLERANCE = (0.55, 1.8)


def find_die_component(alpha):
    """Return (mask, bbox) for the floating die, or raise if it can't be identified."""
    ink = alpha > ALPHA_FLOOR
    labels, count = ndimage.label(ink)
    if count < 2:
        raise SystemExit(
            "No detached component found - the die is either touching the body or absent.\n"
            "The split needs the die to float clear of the hand (it does in the 2026-08 art)."
        )

    sizes = ndimage.sum(ink, labels, range(1, count + 1))
    body_index = int(np.argmax(sizes)) + 1
    total_ink = ink.sum()

    candidates = []
    for i in range(1, count + 1):
        if i == body_index:
            continue
        mask = labels == i
        px = int(mask.sum())
        if px < MIN_DIE_PX or px > total_ink * MAX_DIE_FRACTION:
            continue
        ys, xs = np.nonzero(mask)
        w = xs.max() - xs.min() + 1
        h = ys.max() - ys.min() + 1
        aspect = w / float(h)
        if not (ASPECT_TOLERANCE[0] <= aspect <= ASPECT_TOLERANCE[1]):
            continue
        # A die is a solid square-ish blob: high fill of its own bbox.
        fill = px / float(w * h)
        candidates.append((abs(aspect - 1.0) - fill, i, mask, (xs.min(), ys.min(), xs.max(), ys.max())))

    if not candidates:
        raise SystemExit(
            "Found detached components but none look like a die (size / squareness / fill).\n"
            "Inspect the art and widen the thresholds at the top of this script if needed."
        )

    candidates.sort(key=lambda c: c[0])
    _, _, mask, bbox = candidates[0]
    return mask, bbox


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("--body", required=True)
    ap.add_argument("--die", required=True)
    args = ap.parse_args()

    im = Image.open(args.source).convert("RGBA")
    arr = np.array(im)
    die_mask, bbox = find_die_component(arr[..., 3])

    body = arr.copy()
    body[die_mask] = (0, 0, 0, 0)

    die = arr.copy()
    die[~die_mask] = (0, 0, 0, 0)

    Image.fromarray(body, "RGBA").save(args.body)
    Image.fromarray(die, "RGBA").save(args.die)

    lum = arr[..., :3][die_mask].astype(float).mean(axis=1)
    print("source        : %s  %dx%d" % (args.source, im.width, im.height))
    print("die bbox      : x %d-%d  y %d-%d  (%d px)"
          % (bbox[0], bbox[2], bbox[1], bbox[3], int(die_mask.sum())))
    print("die brightness: %.0f%% near-white faces, %.0f%% dark outline/pips"
          % (100 * (lum >= 210).mean(), 100 * (lum < 60).mean()))
    print("wrote         : %s (body) / %s (die)" % (args.body, args.die))
    if (lum >= 210).mean() < 0.15:
        print("WARNING: very little white surface - modulate tinting will read weakly.",
              file=sys.stderr)


if __name__ == "__main__":
    main()
