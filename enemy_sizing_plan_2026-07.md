# Enemy Size & Positioning — Systemic Plan (2026-07-24)

**STATUS: sections 1-8 are the plan; section 9 records what was IMPLEMENTED on 2026-07-24
(HUD shrink + HP ladder + feet band — verified by probe and render, NOT playtested). The
content-anchored intent and the act-2 reskin sizing are still outstanding.**

All numbers below are measured from a Python
re-implementation of `enemy.gd::update_enemy()` run against the real alpha-content (used-rect)
of every art asset, across all 40 `battles/*.tscn` (audit script + `audit_report.txt` in the
session scratchpad). "content height/width" = the alpha bounding box on screen in px, i.e. what
the player actually sees, NOT the nominal `width`/`height` box.

Reference frame: design canvas 1280×720. Player sprite = **224px tall on screen (31% of 720)**.
Top bar bottom ≈ y80. Card-fan top ≈ y561 (Hand container top y581 minus the 20px fan rise).
Dice panel / Power number pushes the left play limit to **x≈750**. End Turn button left edge =
**x1060** (`END_TURN_LEFT`).

---

## 1. Diagnosis — it's THREE problems, not "enemies are too big"

Julien's instinct ("make them smaller") is correct, but the measurements show the pain is really
three distinct issues that got conflated because they all surface as "overlap":

### 1a. The HP→size relationship is currently INVERTED in several places
This is the biggest surprise. Sorted by how big they actually render:

| enemy | HP | content H (screen px) | % of 720 |
|---|---|---|---|
| Temple Defender | 34–45 | **246–269** | 34–37% |
| Lich | 85 | 266 | 37% |
| Maelstrom | 54 | 253 | 35% |
| Leviathan (**BOSS**) | 140 | **253** | 35% |
| Dragon Priest | 90 | 252 | 35% |
| Medusa | 58 | 250 | 35% |
| Gargantua | 95 | 242 | 34% |
| Venom Bloom | 28–38 | 185–241 | 26–34% |
| **Satyr (squishy)** | **8** | **up to 202** | 28% |
| Lurker | 36–47 | 201–245 | 28–34% |
| Marauder | 27–36 | 187–226 | 26–31% |
| Goblin | 22 | 177–236 | 25–33% |
| Skeleton | 24–31 | 184–196 | 27% |

Look at the inversions: the **Leviathan boss (140 HP) is the same size as a 54-HP Maelstrom and
SMALLER than an 85-HP Lich**. An **8-HP Satyr (202px) renders nearly as big as a 31-HP Marauder
(226px)**. Temple Defender is the single largest normal enemy in the game despite being a
mid-HP bruiser, exactly matching Julien's "sometimes HUGE" note. The current box sizes were
hand-picked per `.tscn` with no consistent tie to HP, so "bigger = tankier" is only loosely true.

### 1b. Everything is a bit oversized vs the player and vs STS
Most solos render at **34–37%** of screen height. The player is 31%. In STS1/STS2 normal enemies
are ~20–28% and the player is a strong presence; only elites/bosses loom. Our enemies are
consistently larger than the player, which is backwards — it makes even solo fights feel crowded
and leaves no vertical headroom to place HP bars/status clear of the cards.

### 1c. Enemies sit too LOW, so status rows collide with the card fan
This is the actual cause of the "status hidden behind cards" problem, and **shrinking alone does
NOT fix it** — shrinking the sprite doesn't move the HP bar up unless the feet move too. The HP
bar sits at the feet line; the status row hangs ~24–54px below that. Current front-line feet are
at y510–545, and several multi-fight bodies sit as low as **y572** (big octopus). At feet=545 the
status row bottom is ~y599 — **38px into the card fan (top y561)**. Right now it's only "fine"
because most enemies start combat with no status icons; the moment an enemy gains Weak/Exposed/etc.
its icons render on top of the cards. The 07-19/07-20 feet_line refactor made the bar *derive*
from the feet correctly, but the per-fight `position.y` values were never brought onto a
consistent, high-enough ground line.

**So the plan has to do two independent things: shrink toward an HP ladder (fixes 1a + 1b +
horizontal crowding), and raise/tighten the ground line (fixes 1c). They're complementary — the
shrink is what makes raising the ground line safe (frees headroom above the head for the intent).**

---

## 2. Proposed system

### 2a. The HP → size ladder (the core rule)

Size is defined by **target on-screen content HEIGHT**, tied to HP bands. This makes "more HP =
bigger" true by construction and gives every fight a predictable vertical footprint.

| band | HP range | target content H | % of 720 | vs player (224) |
|---|---|---|---|---|
| **XS** — squishy fodder | ≤ 12 | 130–150 | 18–21% | ~⅔ |
| **S** — small | 13–20 | 155–180 | 22–25% | ~¾ |
| **M** — standard | 21–35 | 185–210 | 26–29% | ≤ player |
| **L** — tanky / elite | 36–60 | 215–245 | 30–34% | ≈ player |
| **XL** — big elite | 61–99 | 245–265 | 34–37% | > player |
| **BOSS** | 100+ | 275–305 | 38–42% | looms |

Applied to every pool enemy (representative current size → ladder midpoint):

| enemy | HP | now | band | target | change |
|---|---|---|---|---|---|
| Kraken (squishy) | 8–10 | 158 | XS | 140 | −18 |
| Satyr (squishy) | 8–10 | **202** | XS | 140 | **−62** |
| Kraken (big) | 16–21 | 195 | S–M | ~185 | −10 |
| Oculus | 20 | 179 | S | 167 | −12 |
| Satyr (big) | 16–21 | **232** | M | 197 | **−35** |
| Goblin | 22 | **236** | M | 197 | **−39** |
| Skeleton | 24–31 | 196 | M | 197 | ~0 |
| Marauder | 27–36 | 226 | L | 230 | +4 |
| Venom Bloom | 28–38 | 241 | L | 230 | −11 |
| Temple Defender | 34–45 | **269** | L | 230 | **−39** |
| Lurker | 36–47 | 245 | L | 230 | −15 |
| Sigil Slug | 37 | 234 | L | 230 | −4 |
| Lava Hound | 51 | 218 | L | 230 | +12 |
| Maelstrom | 54 | 253 | L | 230 | −23 |
| Medusa | 58 | 250 | L | 230 | −20 |
| Lich | 85 | 266 | XL | 255 | −11 |
| Dragon Priest | 90 | 252 | XL | 255 | +3 |
| Gargantua | 95 | 242 | XL | 255 | +13 |
| **Leviathan (boss)** | 140 | **253** | BOSS | **290** | **+37** |

Outcome: most enemies get **modestly smaller** (matching the "smaller like STS" goal), the worst
offenders in multi-fights (big Satyr, Goblin, Temple Defender) drop hard, and the inversions get
fixed — the boss becomes the biggest thing on screen and squishies clearly read as small. Because
the box scales uniformly, shrinking height also shrinks WIDTH proportionally, which directly eases
horizontal crowding (Defender's 272px-wide shield → ~232px, etc.).

Bands are a starting point — the exact target per enemy should be locked by render (see §5). A few
will want hand-nudging within their band for silhouette reasons (e.g. Lava Hound is drawn in a
leap, Skeleton carries a wide scythe).

### 2b. Vertical placement — tight ground band + content-anchored intent

**Ground band — REVISED after measuring the backgrounds (see §7).** My first draft proposed feet
y500–508. **That is too high and is withdrawn** — it puts feet at/above the painted floor's back
edge, and in the act-2 library it lands right-side enemies on the furniture band. Corrected:

- **Target feet ≈ y512–525** (final figure — derived in §8b once the HP bar + status row are also
  shrunk). This is a *narrowing* of today's range (482–572), pulling in BOTH ends: it lifts the
  ungrounded outliers (Plant 482, Marauder 486 — currently standing on the back rubble, verified by
  composite) and raises the too-low ones (big octopus 572) whose status rows sit deep in the cards.
  Most enemies move very little.
- The status-vs-cards conflict is **NOT** solvable by moving enemies (see §7c) — with today's UI
  sizes no valid feet value exists at all. It is fixed by shrinking the HP bar + status row (§8),
  which is orthogonal to body size: shrinking an enemy while keeping its feet fixed doesn't move the
  HP bar or status row at all.
- Stop using large downward `position.y` staggers for "depth." Today a lower neighbor reads as
  *both* "closer to camera" (the intended effect) *and* "floating / colliding with cards" (the bug),
  because the same lever does both. Depth should instead come from **size + the ground shadow**
  (already built, 07-19), not from dropping bodies 40–60px lower. Small deliberate staggers (≤10px)
  are fine as long as the lowest body stays inside the band.
- This *keeps* the existing `feet_line_y` architecture (it's the single source of truth and it's
  good) — we're only bringing the per-fight `position.y` inputs onto a consistent band. The
  `maxf(offset, 0)` clamp on the bar/status stays as the safety net.

Vertical budget check (worst case, a 265px XL enemy at feet=525):
```
head y = 525 − 265 = 260 → intent top ≈ 220   (top bar bottom y80 → clears by 140px)
bar top y = 525 → status top y549 → status bottom ≈ y579-591   (card fan top y561 → CONFLICT)
```
The head/intent end is comfortable *because* the ladder shrank the bodies. The status end still
conflicts — that's §7c, fixed in code, not by moving enemies.

**Content-anchored intent (the systemic fix for the intent-offset spaghetti).** Today:
```gdscript
# enemy.gd:266
intent_ui.position.y = -sprite_display_height / 2 - 30 - intent_ui_y_offset + sprite_y_offset
```
Intent hangs off the **BOX top** (`-sprite_display_height/2`), not the visible head. For art with
top padding the box top floats above the skull, so the intent floats too — this is exactly the
documented "Skeleton intent stabs through the head after a texture trim" bug, and it's why ~5
fights carry hand-tuned `intent_ui_y_offset` band-aids that break whenever art or box changes.

The 07-19 pass already made the **bottom** content-anchored (feet = alpha bbox bottom). **Propose
extending the same principle to the top:** anchor intent to the alpha bbox TOP:
```
intent_top = (feet_line_y − content_height) − INTENT_GAP
```
Then both ends of the sprite are content-anchored, box/size changes can't break either, and the
per-fight `intent_ui_y_offset` tweaks can nearly all be zeroed out. This is the change that makes
the whole ladder safe to apply without re-triggering the intent whack-a-mole.

### 2c. Horizontal placement — columns, gaps, stage limits

The playable stage is **x≈750 (left, past the Power number) → x≈1240 (right, before End Turn)** =
~490px for up to 4 bodies. Rules:

- **Front/leftmost enemy: content left edge ≥ x750** (already an established rule; the ladder makes
  it easier to honor since bodies are narrower).
- **Neighbor gap: ≥ ~20px between content bounding boxes**, and no HP bar over a neighbor's art
  (the audit flags several today: Satyr-bar-over-Kraken 27–31px, etc.).
- **4-body fights are the binding constraint.** Four bodies × ~180px avg = 720px > 490px available.
  The ladder self-enforces the fix: 4-body fights are all squishies (XS/S ≤ 180px), so 4 × ~150 =
  600px, which fits with mild scale staging. Anything that needs more than the stage width should
  lose a body or drop a size band, not overlap.
- **Status-row → End Turn clamp** (`enemy.gd:299-310`) stays as-is; smaller right-side bodies make
  it trip less often.

---

## 3. How this rides on the existing (spaghetti) code

The plan deliberately changes **inputs**, not the `enemy.gd` positioning architecture, except for
the one intent change in §2b.

- **Size lever = `width`/`height` (the box), at `scale = 1.0`, wherever possible.** Two levers
  currently produce size: the box (`@export width/height`, per-fight on each battle node) and
  `scale` on the Enemy root. They look identical but `scale` also shrinks the status handler (then
  counter-scaled, `enemy.gd:315`) and scales the intent offset — extra moving parts. Recommend
  driving all sizing through the box and **retiring `scale` to an optional depth-only nudge**. Most
  multi-fight nodes currently use `scale 0.65–0.75`; migrating them to an explicit box at scale 1.0
  removes a whole class of counter-scale interactions. (Not mandatory for v1 — could be phased —
  but it's the clean end state.)
- **Intent** auto-follows the box today; after the §2b change it follows the content instead —
  strictly more robust to both box changes and art-padding changes.
- **`feet_line_y` / bar / status / shadow** all already derive from one anchor (07-19). The ladder
  feeds them a smaller `sprite_display_height` and the ground band feeds them a consistent
  `position.y`; no formula changes needed there.
- **Act-2 reskin caveat** (`battle.gd::_reskin_enemy`): the reskin **reuses the act-1 box** and just
  swaps art. But several act-2 arts fill more of the box than their act-1 counterparts, so the SAME
  box renders them bigger: Skeleton→Gnawer **+30%** (196→240px), Lava Hound→Ember Fiend +27%,
  Maelstrom→Tempest +21%, Lich→Necromancer +7%, Sigil→Wisp +8%. So the ladder's targets are
  correct for act 1, and act 2 will drift oversized for those ~5 enemies. Fix later either by
  validating the ladder against both arts, or by giving `_reskin_enemy` a per-enemy box multiplier
  so act-2 content matches the act-1 target. Act 2 is explicitly placeholder, so this is secondary —
  just don't be surprised when Gnawer looks bigger than Skeleton.

---

## 4. Which fights actually change (severity-grouped)

**High impact (multi-fight domination / real overlaps flagged by the audit):**
- `tier_2_defender_machopeur`, `tier_2_defender_satyr`, `tier_1_defender` — Temple Defender 269→230.
- `tier_1_machopeur_satyr`, `tier_0_satyrs_*`, `tier_1_octopus_2_satyrs_2` — big Satyr 232→197.
- `tier_1_oculus_goblin`, `tier_1_plant_goblin` — Goblin 236→197.
- All `tier_0` octopus/satyr swarms — squishy Satyrs 202→140, big octopus feet raised off y572.
- `tier_2_machopeur_octopus`, `tier_0_octopus_2_satyr_1`, `tier_0_octopus_3` — bar-over-neighbor +
  62–107px feet spreads pulled onto the ground band.

**Medium (solo oversizing + ground-line raise):** every solo (Plant, Sigil Slug, Vortex/Maelstrom,
Medusa, Hound, Lich, Dragon Priest, Gargantua, Leviathan) gets its feet raised to the band and its
size trimmed/normalized to its HP tier. Leviathan actually grows (+37) to become the biggest body.

**Low / leave alone:** Skeleton (already ~197, W-bound by its scythe), Marauder (already ~226, ≈L),
Kraken big (≈195). These barely move.

---

## 5. Migration & validation approach

1. **Extend intent to content-anchored** (`enemy.gd:266`, add `INTENT_GAP` const) and zero the
   existing `intent_ui_y_offset` band-aids. Render-check the ~5 skeleton fights that carried them.
2. **Apply the ladder** by editing `width`/`height` per battle node (and, where chosen, resetting
   `scale`→1.0 with an equivalent box). One enemy identity at a time.
3. **Bring `position.y` onto the ground band** (feet ≈ 500–508) per node, using the same
   feet-target math the audit script already computes (it outputs `position.y` for any target feet).
4. **Validate by render, not by eye-in-editor**, with the existing `debug_bg_audit.gd/.tscn`
   harness (renders every reachable fight on its real background). This is the established, trusted
   loop — the whole audit above came from re-implementing its math. Re-run after each enemy so a
   size change that nudges a neighbor gets caught (that regression happened repeatedly before).
5. **Re-check width/crowding AND bar-over-neighbor after every fix** — CLAUDE.md's documented
   lesson: a ground-line change can drop one enemy's HP bar onto a neighbor's art.

The audit script (`enemy_size_audit.py`) can be dropped into the repo as a standing check — it
flags leftmost-rule breaks, art overlaps, bar-over-neighbor, feet spread, status-over-cards,
intent-into-top-bar, HP/size inversions, and stage-width overrun for all 40 fights in one run.
That gives a fast numeric pass/fail before spending render time.

---

## 6. Open questions for Julien (decide before implementing)

1. ~~Ground-line height — raise to y500–508?~~ **ANSWERED / WITHDRAWN.** Julien flagged the
   floating risk; measuring the backgrounds proved him right (§7). Revised band is **y515–535**,
   and the status-vs-cards problem moves to a code fix (§7c). Remaining sub-question: which §7c
   option do you want for the status row?
2. **Kill the `scale` lever?** Migrating all multi-fight nodes to box-at-scale-1.0 is the clean end
   state and removes the counter-scale complexity, but it's more editing. Do it now, or phase it
   (ladder-via-box for solos, leave scale on multis for v1)?
3. **Band boundaries / player relationship.** I set it so normals are ≤ player and only XL/boss
   exceed it. If you want the player to feel smaller/bigger relative to mobs, shifting one number
   (the M/L cutoff) re-tunes the whole roster.
4. **Act-2 oversized reskins** (Gnawer/Ember Fiend/Tempest +20–30%): fix now with a reskin box
   multiplier, or leave until act 2 gets its real pass?

---

## 7. Background grounding check (added after Julien's "won't they look like they float?")

Good catch — the concern is valid and it changed the plan. Measured directly against the art:
backgrounds are 1376×768 drawn `centered=false` at native scale with the camera at (639,361), so
**background pixel y ≈ screen y 1:1** — the painted floor line can be read straight off the image.

### 7a. Where the walkable floor actually starts (minimum safe feet, per background)

| background | used by | floor back edge in stage (x750–1240) | notes |
|---|---|---|---|
| act1 hallway (mountain ruins) | act1 tiers 0–2 | **~y490–500** | tightest act-1 bg; pillar base pushes it to ~y500 at x>1150 |
| act1 elite (throne hall) | act1 elite | ~y440–470 | permissive; brazier bases ~y480–490 at far right |
| act1 boss (coastal storm) | act1 boss | ~y440–460 | permissive; rocks/grass ~y460–480 on sides |
| act2 hallway (arcane library) | act2 tiers 0–2 | **~y495 (x<1000), ~y505 (x1000–1140), ~y510+ (x>1150)** | **binding constraint** — the documented "planter" band |
| act2 elite (lava chamber) | act2 elite | ~y450–470 | permissive |
| act2 boss (coastal mist) | act2 boss | ~y440–460 | ~y475 at right pedestal |

**Global minimum safe feet ≈ y510; with a comfortable margin, y515.** Above that an enemy stands on
the back rubble / steps / planters rather than the floor.

### 7b. Verified by composite (real sprites on real backgrounds, PIL mockups in session scratchpad)

- `mock_a1_raised505.png` — Defender at feet 505 sits on the seam where floor meets back rubble.
  Not comically floating, but visibly "backed against the wall," with the ground shadow half on stone.
- `mock_a2_raised505.png` — Marauder at feet 508, x1034 stands **on the stone step band**. This is
  literally the bug already fixed once in the repo (feet y495 → moved down to y517 on
  `tier_2_defender_machopeur`). A blanket raise re-breaks it.
- `mock_high_outliers.png` — **the failure already exists today**: `tier_0_machopeur` (feet 486) and
  `tier_2_plant_crab`'s Plant (feet 482) are *above* the act-1 floor edge and read as detached, with
  shadows on the rubble. So "some enemies look ungrounded" is a current bug the band fixes, not a
  risk the plan introduces.
- `mock_a1_keep522.png` — Defender shrunk 246→207px with feet kept at 522: **clearly grounded on the
  paving, and obviously smaller.** This is the target look.

**Conclusion: shrinking is completely safe for grounding (it doesn't move the feet at all); it was
only the RAISE that was dangerous.** The headline win — smaller, HP-consistent enemies — survives
100% intact. A useful bonus: shrinking + staying at the same depth is perspective-consistent, so
smaller enemies actually read as *better* grounded, not worse.

### 7c. The real conflict this exposed: status row vs card fan is unsolvable by placement

With `stats_ui` 32px tall, `enemy.gd:260-261` puts the status row at `feet + 24`, and counter-scaled
icons extend ~30–42px below that:
```
status bottom ≈ feet + 54 … + 66      card-fan top ≈ y561 (cards span x194–1094)
→ full clearance needs feet ≤ ~495–507
```
But §7a says the backgrounds need **feet ≥ ~510**. **The two constraints don't overlap** — there is
no ground line that satisfies both. That's why this has been whack-a-mole for months: it's been
treated as a placement problem when it's a layout problem. (Note the cards always win z-order:
Hand lives in the `BattleUI` CanvasLayer, statuses in the base canvas, and Julien already rejected
putting statuses over the cards in the 07-20 pass.)

**Ruling (Julien, 2026-07-24): the status row ALWAYS stays directly below the HP bar** — that's the
convention in every comparable game and moving it beside/above would look wrong. My earlier
"beside the bar" suggestion is withdrawn. The order stays `body → HP bar → status`.

**The fix is therefore to SHRINK the stack, not move it** (Julien's call): shrink the enemies *and*
their HP bar *and* their status icons. This is the only lever that satisfies both constraints at
once, and measurement confirms it works — see §8.

### 7d. Revised implementation order

The two halves are now independent and can ship separately, lowest-risk first:
1. **Shrink to the HP ladder** (§2a) — safe for grounding, no status implications, biggest visual win.
2. **Normalize feet into y515–535** — fixes today's ungrounded outliers *and* the too-low ones.
3. **Content-anchored intent** (§2b) — removes the `intent_ui_y_offset` band-aids.
4. **Status row relocation** (§7c) — the actual fix for statuses vs cards.

---

## 8. Shrinking the HP bar + status row — the numbers (Julien's call, validated)

### 8a. The card-fan top is not a flat line

`hand.gd` fans with `fan_radius = 20` across a 900px container (x190–1090), so only the middle
cards reach y561. Measured effective card top where enemies actually stand:

| x | 750 | 800 | 900 | 1000 | 1090 | >1090 |
|---|---|---|---|---|---|---|
| card top | y562 | y564 | y569 | y575 | y581 | none |

So the **leftmost enemy (x≈750) is the binding case**; right-side bodies already have 13–19px more
room, and anything past x1090 has no card conflict at all.

### 8b. Current stack, and what shrinking buys

Measured from `stats_ui.tscn` / `status_ui.tscn` / `enemy.gd:260-261`:
```
CURRENT:  bar container 32  →  status top = feet + (32−8) = feet+24
          status extent 42  (icon 30 + the Duration/Stacks labels reaching y39)
          TOTAL STACK = feet + 66
```

| option | bar h | gap | status extent | stack | max feet @x750 | max feet @x1000 |
|---|---|---|---|---|---|---|
| **CURRENT** | 32 | −8 | 42 | **66** | 496 ❌ | 509 ❌ |
| A gentle | 26 | −8 | 34 | 52 | 510 ❌ | 523 ✅ |
| **B medium** | 22 | −8 | 30 | **44** | **518 ✅** | 531 ✅ |
| C tight | 20 | −10 | 26 | 36 | 526 ✅ | 539 ✅ |

Background needs feet **≥ 510 (comfortable 512–515)**. So:
- **CURRENT: no valid feet exists** — mathematically confirms the §7c deadlock.
- **Option B opens a real window: feet 512–518** (leftmost), 512–531 (right side).
- Option C widens it to 512–526 with margin to spare.

**Recommend starting at B and tuning toward C at render time.** The one thing to watch is the
`HealthLabel` ("35/35") legibility once the bar drops from 20px to ~15px tall — its font may need a
step down, or the text can ride over a thinner bar (which is what STS does).

### 8c. Bar WIDTH is a second, independent win

The HP bar is a fixed **206px wide regardless of enemy size** — wider than several enemies:

| enemy | body width | bar width | ratio |
|---|---|---|---|
| Satyr (squishy) | 98px | 154px | **1.57×** |
| Kraken | 120px | 154px | 1.29× |
| Marauder | 160px | 206px | 1.29× |

That overhang is exactly what causes the audit's "X's HP bar over Y's art" flags. Narrowing it:

| bar width | bar-over-neighbour overlaps (pool) |
|---|---|
| 206 (current) | **9 across 9 fights** |
| 170 | 3 |
| 150 | 2 |
| 130 | **0** |

So shrinking the bar fixes a whole class of multi-enemy overlap **without moving anything**.

### 8d. ⚠️ Implementation constraint: `stats_ui.tscn` is SHARED with the player

`scenes/ui/stats_ui.tscn` is instanced by **both** `enemy.tscn` and `player.tscn`. Editing the
scene itself would shrink the player's HP readout too — undesirable (it's a key readout, sits
bottom-left, and has no card conflict). Two enemy-only routes:

- **(i) Scale from `enemy.gd` (recommended).** One line: `stats_ui.scale = Vector2(S, S)` with
  `S ≈ 0.7`, which shrinks height 32→22 **and** width 206→144 simultaneously — hitting the §8b
  *and* §8c targets with a single tunable constant. `enemy.gd:315` already scales the status
  handler (`1/scale` counter-scale); change that to `STATUS_UI_SCALE/scale` with `≈0.7` to take
  the icon 30→21 and extent 42→30. Caveat: `stats_ui` is positioned by its top-left, so the
  horizontal pivot needs handling (`pivot_offset`, or re-derive `offset_left`) or the bar will
  shrink left-aligned instead of centred on the body.
- **(ii) Override the child properties on `enemy.tscn`'s StatsUI instance.** More faithful (no
  Control scaling, crisper text) but a bigger, more brittle edit.

Either way it's a **1–2 file change applying uniformly to every enemy** — no per-fight edits, which
is exactly the systemic outcome we want.

### 8e. Consolidated final targets

1. **Enemy size** → HP ladder (§2a): most enemies −10 to −40px, boss +37.
2. **HP bar** → scale ≈0.7 (32→22 tall, 206→144 wide), enemy-only.
3. **Status icons** → scale ≈0.7 (extent 42→30), still directly below the bar.
4. **Feet band** → **y512–525**, satisfying backgrounds (≥510) and cards (≤518 at the worst x).
5. **Intent** → content-anchored (§2b), retiring the `intent_ui_y_offset` band-aids.

Everything above is now internally consistent: no constraint is violated at any x, and the three
levers (body size, UI size, ground line) each fix a distinct failure instead of fighting each other.

---

## 9. IMPLEMENTED 2026-07-24 (steps 1-2 of section 7d) — NOT YET PLAYTESTED

Verified by in-engine numeric probe (real fights, real statuses applied) + a full 57-render
sweep of `debug_bg_audit`. **Not played in Godot interactively.**

### What shipped
1. **`enemy.gd` HUD shrink at 0.7** — `STATS_UI_SCALE` / `STATUS_UI_SCALE` constants.
   HP bar **206x32 -> 144x22**, status icons 30 -> 21, `STATUS_ICON_EXTENT` derived. The bar is
   scaled around pivot `(w/2, 0)` so the top edge stays on the feet line and the centre stays on
   the body — with the default `(0,0)` pivot it would shrink left-aligned and slide ~31px off.
   `stats_ui.size.y` is the AUTHORED height and does not change under scale, so the drawn height
   is applied by hand when placing the status row / name label.
   **`stats_ui.tscn` itself was NOT touched — it is shared with `player.tscn`, whose HP readout
   stays full size deliberately.**
2. **HP ladder applied to all 67 enemy nodes in the 35 reachable fights** (`battles/*.tscn`):
   `width`/`height` set per the section-2a bands, **`scale` folded into the box and removed**
   (every enemy is now `scale = 1`), `position` rewritten to land feet in the band.

### Measured result
- Feet now **516-520.5** across every fight (was 482-572). No enemy sits above the painted floor
  edge, none sits low enough to bury its status row.
- HP bars are **uniformly 144x22 everywhere** — folding `scale` away fixed the side effect where
  a 0.75-scaled enemy got a 108x17 bar with near-illegible HP text.
- Status row clears the card fan in **every** fight (min margin ~2px on the worst leftmost slot,
  median ~9px).
- Boss is finally the largest body on screen (Leviathan 253 -> 290px); the HP/size inversions
  (8 HP Satyr rendering at 202px, Temple Defender at 269px) are gone.

### Two traps found while implementing
- **The HP bar hangs off the NODE x, not the body centre** (local x 17..223, centred on local
  x120), and its width is FIXED. Once `scale` was folded away, every enemy got a full-size bar,
  so narrow bodies parked far right pushed their bar off-screen (up to 1312 vs the 1280 canvas).
  Capping the *body centre* does not fix this — the layout has to be solved on `position.x`
  (`POS_X_MAX = 1080`). Four fights were clipped before this was caught.
- **Excess gaps must be closed by a backward sweep**, not by shifting the group: once the first
  body sits on the left bound there is no slack, so a whole-group pull-left silently does nothing.

### Still open (section 7d steps 3-4)
- **Content-anchored intent** (section 2b) — NOT done. The intent still hangs off the box top, so
  the per-fight `intent_ui_y_offset` band-aids remain. Bodies got smaller while the `-30` constant
  did not, so the intent-to-head gap is now proportionally *larger* (safer), but the underlying
  fragility is untouched.
- **Act-2 reskin oversizing** (section 3) — untouched; Gnawer/Ember Fiend/Tempest still render
  ~20-30% larger than their act-1 counterparts in the same box.
- The apparent empty space mid-left in the audit renders is a **harness artifact** — `debug_bg_audit`
  does not populate `BattleUI`, so the dice panel / Power number that really occupies x520-780 is
  missing from those images.


---

## 10. REVISION 2 (2026-07-24, on Julien's playtest screenshots) — NOT PLAYTESTED

Four pieces of feedback on the section-9 build, all addressed. One of them was a regression
I introduced.

### 10a. What was wrong

1. **"Intent is really big compared to them, overlaps their horns"** — a REGRESSION from
   folding `scale` into the box. `IntentUI` used to inherit the enemy root's `scale`, so a
   0.75-scaled Satyr got a 0.75 intent. At `scale = 1` every intent jumped to full size
   overnight (~33% bigger on multi-fight enemies).
2. **"Solos look really small / HP bar too"** — my card-fan model was wrong, so I over-shrank.
   I assumed cards spanned x190–1090. They don't: cards are 140 wide with **−35 separation**
   (105px step) centred on x640, so a normal 5-card hand only spans **x360–920**. Enemies at
   x>950 have little or no card conflict at all. I had been budgeting against a constraint
   that mostly wasn't there.
3. **"Status bar starts too much on the left"** — the row sat at a flat local x33 while the
   bar's left edge was elsewhere; on a narrow body it landed well left of both bar and enemy.
4. **"Status icon really small & hard to read"** — the flat 0.7 shrink took icons to 21px.

### 10b. What changed

- **Status icons back to FULL SIZE (30px)**, `STATUS_UI_SCALE = 1.0`. Budget bought back by
  trimming the Duration/Stacks label overhang in `status_ui.tscn` (it hung 9px below the icon,
  setting the row's footprint to 39px; now 32px) — pure profit, no icon shrink.
- **HP bar scales with the BODY, STS-style** (`BAR_SCALE_MIN/MAX`, derived from content width
  vs the authored 206). A big solo gets the full 206×32; a small Satyr gets 128×20. Replaces
  the flat 0.7, which made big enemies look weak and small ones bar-heavy.
- **Status row left-aligned to the bar's left edge** (verified `dx = +0`).
- **Intent anchored to the CONTENT top** (not the box top) **and scaled to the body**
  (`INTENT_SCALE_*`, 0.7–1.0). Small enemies get an 80×42 intent, big ones 114×60. This also
  retires the whole `intent_ui_y_offset` band-aid family — **stripped from 23 battle files**.
- **Bigger ladder + crowd factor**: bands raised, then `COMP_MULT` = ×1.25 solo, ×1.0 for two,
  ×0.90 for three, ×0.80 for four, capped at 320px so a boosted elite still clears the top bar.

### 10c. Resulting sizes (player = 224px)

| | before rev-2 | after |
|---|---|---|
| Venom Bloom (solo) | 196 | **258** |
| Temple Defender (solo) | 231 | **261** |
| Lurker / Medusa (solo) | 231 | **303 / 304** |
| Lava Hound | 222 | **277** |
| Lich / Dragon Priest / Gargantua | 255 | **319 / 322 / 321** |
| Leviathan (boss) | 290 | **320** |
| Satyr in a 3-pack | 140 | **133** |

Solos and elites now clearly out-scale the player; crowds stay readable.

### 10d. Traps found in rev 2

- **The HP bar's edges are `node_x + 120 ± 103·bar_scale`**, not `node_x ± half`: `StatsUI`
  sits at local x17 and shrinks about its own centre (local x120). Dropping that 17 put the
  status row and the off-screen check 17px out.
- **Feet must be re-solved AFTER the x-layout.** The first pass computed feet from the
  authored x; the layout then slid bodies sideways into a taller part of the card fan,
  silently invalidating the result.
- **The card fan is not a flat line and does not span the hand container.** Model it from
  card width / separation / count, not from the container's 900px min width.

### 10e. Still open
- Act-2 reskin oversizing (section 3) — untouched.
- `MAX_CONTENT_H = 320` is a guess at the comfortable ceiling; the three elites all sit on it.

---

## 11. REVISION 3 (2026-07-24, second playtest pass) — NOT PLAYTESTED

Julien on the rev-2 build: solo sizing/grounding "great, that's the vibe I want"; four fixes.

### 11a. Intent too high — on EVERY enemy

Root cause: rev-2 anchored the intent to the alpha bbox top, but that top is often a thin
prop, not the head. Measured spike height above the body mass:

| enemy | spike above body mass | as % of body |
|---|---|---|
| Temple Defender (crest) | 121px | 16% |
| Skeleton (scythe) | 76px | 11% |
| Lich | 53px | 9% |
| Marauder (mace) | 50px | 10% |
| Venom Bloom | 25px | 6% |
| **Satyr (horns)** | **14px** | **4%** |

So on a Marauder the intent was parked ~50px above the head, on a Defender ~120px — while
the Satyr (whose horns Julien wanted cleared) barely has a spike at all.

**Fix: anchor to the BODY-MASS line** — new `Enemy._get_head_line_fraction()`, the first row
(scanning down) at least `HEAD_MASS_FRACTION` (0.35) as wide as the widest row. Thin props
sit above it and are ignored; the Satyr's 4% barely moves, so horn clearance survives.
Returned as a **fraction of content height** so it is resolution- and box-independent, and
computed on a **downscaled copy** (`HEAD_SCAN_MAX` 96) because per-pixel `get_pixel()` from
GDScript over every enemy texture would hitch on load. Cached per texture.

### 11b. Status row "still too much on the left"

Rev-2 left-*aligned* it to the bar's left edge. Julien wants it "right below his hp bar" =
**centred**. Now centred on the bar's centre, which is a fixed local x regardless of
`bar_scale`. Because the row's width changes as statuses come and go, placement moved into
`_update_status_row_x()`, re-run from the `sort_children` signal — a one-shot placement in
`update_enemy()` is only ever correct for the icon count present at that moment. The End
Turn clamp moved into the same helper so both paths keep it. Verified centred at 1 icon
(30px row) and 3 icons (102px row): offset **+0.0** in both cases.

### 11c. Two-enemy fights had a hole in the middle

Preserving authored x left "left … gap … right". Multi-enemy fights are now laid out as a
**centred cluster** (`GROUP_CENTER` 1006, `GROUP_GAP` 52/30/20 by count) — Julien's
"centre-left / centre-right". **Solos keep their authored x** (he approved those framings);
they are only clamped to the left bound.

### 11d. Venom Bloom "a bit too big"

New `SIZE_TWEAK` dict (× 0.93 for Venom Bloom) — a fine trim inside a band without
disturbing the HP ladder, since Venom Bloom also appears at 28/38 HP in other fights.

### 11e. Verified
- 57-render sweep; intents sit just above the head on every enemy, Satyr horns clear.
- Status row centred under the bar at 1 and 3 icons, icons at full 30px.
- All geometry constraints (left bound, gaps, bar on-screen, card clearance) still clean.

Outstanding: act-2 reskin oversizing (section 3). `MAX_CONTENT_H = 320` still binds the
three elites. Temple Defender's intent now slightly overlaps its crest tip — deliberate,
the alternative is the old float.

---

## 12. REVISION 4 (2026-07-24) — fixes for the rev-3 playtest

### 12a. Overlapping HP bars (ss1, ss2, ss4) — the main miss

The layout enforced gaps between **bodies**, never between **HP bars**. The bar is a
fixed-geometry Control (local x17..223, shrunk about its centre) with a `BAR_SCALE_MIN`
floor, so it is **wider than the body on every small enemy** — section 8c of this very
document measured a Satyr's bar at 1.57x its body and I still spaced by body alone. Two
Satyrs 20px apart therefore had clear sprites and colliding bars.

**Fix: layout now spaces by FOOTPRINT = body ∪ HP bar.** Also:
- `BAR_SCALE_MIN` 0.62 → **0.55**, and `GROUP_GAP[4]` 20 → 14: four bars at the old floor
  needed 512px in a 508px stage, so a 4-enemy fight could never fit and overflowed.
- Group compression now **iterates** (up to 6 passes). Footprint width does *not* shrink
  linearly with the body, because the bar has a floor and a cap, so a single pass undershot.
- New `validate.py` explicitly checks bar-vs-bar overlap, body overlap, bar/body on-screen,
  left bound, and card clearance. That check should have existed from the start.

### 12b. Status row: NOT centred (ss3)

Rev-3 centred it. **Wrong** — no roguelike does that. Back to **left-aligned with the HP
bar's left edge** (verified `dx = +0` in engine on every enemy). Recorded here so it is not
re-litigated: *the status row starts at the bar's left edge and grows rightward. Never centre it.*

### 12c. Player's status label broken (ss3) — my regression

Rev-2 trimmed the Duration/Stacks label in `status_ui.tscn` from (15,7,48,39) to
(14,3,44,31) to save 7px of stack height. That label deliberately **hangs off the icon's
bottom-right corner onto the BACKGROUND**, which is what makes the number legible; pulling
it inside the icon killed the contrast. And `status_ui.tscn` is **shared with the player**,
so it broke the player's Ink counter too. **Reverted** (`git checkout`), and `enemy.gd` now
carries a comment warning not to reclaim stack height that way.

### 12d. Skeleton cut off at the right edge (ss5)

Body right edge was 1271 with a validator threshold of 1274 — no real margin. The footprint
layout now hard-clamps to `STAGE_R` 1262 with 12px of compression slack, and the left bound
always wins over the right.

### 12e. Medusa / Gargantua "giant" (ss6)

The flat ×1.25 solo boost was applied to already-large bands. Now `SOLO_BOOST_BY_BAND`
tapers: ×1.25 for XS/S/M, ×1.12 for L, ×1.05 for XL, ×1.02 for BOSS (`MAX_CONTENT_H` 310).

| solo | rev-3 | rev-4 |
|---|---|---|
| Venom Bloom / Lava Hound | 258 / 277 | **241 / 249** |
| Marauder / Temple Defender / Skeleton | 261 / 261 / 250 | **261 / 261 / 250** (unchanged, approved) |
| Lurker / Sigil Slug / Maelstrom / Medusa | 303 / 301 / 297 / 304 | **272 / 270 / 266 / 272** |
| Lich / Dragon Priest / Gargantua | 319 / 322 / 321 | **285 / 287 / 287** |
| Leviathan (boss) | 320 | **306** |

### 12f. Lesson

Three of these five were things the geometry model already contained the numbers for
(bar width > body width; the shared scene; the 9px margin). **Validate every constraint the
model knows about, not just the one currently being changed** — and when feedback is
ambiguous (rev-3's "starts too much on the left"), ask rather than guess the opposite.

---

## 13. REVISION 5 (2026-07-24) — status row, for real this time

**Root cause of "status still starts too far left", finally.** I had been aligning the row
to `StatsUI`'s left edge. But `StatsUI` is a **206px HBoxContainer** that *centres* a
**175px `HealthBar`** inside itself (plus a Block icon at −25 separation) — so the container's
left edge sits **~11-28px LEFT of the red bar the player actually sees**. Every "dx = +0"
I reported was true and irrelevant: it measured against the wrong node.

Now aligned to `Health/HealthBar`'s own global position (which already accounts for the
bar's scale), verified `dx_vs_bar = +0.0` while `containerL` is 16-28px further left:

| enemy | container L | visible bar L | status L |
|---|---|---|---|
| Lurker | 909 | 937 | **937** |
| Satyr ×3 | 797 / 958 / 1106 | 813 / 974 / 1122 | **813 / 974 / 1122** |
| Medusa | 857 | 885 | **885** |

`stats_ui.sort_children` is now also connected, since the HealthBar only reaches its final
x once its container has sorted.

**Status count legibility.** The label had **no `font` at all**, so it fell back to the
project theme's CinzelDecorative — a decorative display face whose digits read oddly at
15px ("the 1 reads a bit odd"). Now uses `fonts/luckiest_guy_numbers.tres`, the established
"number sitting next to an icon" font (top bar, shop prices, scoreboard), at 16px with a
4px black outline. The label also sat in a box centred a full icon-width right of the icon
(the "big space"); pulled in to hug the icon's bottom-right corner while still overhanging
onto the background — that overhang is what makes it readable and must not be removed.

`debug_bg_audit.gd` gained `BG_AUDIT_STATUSES=weak,exposed` so the status row can actually
be verified in a render instead of only numerically.

**Noticed, not fixed (pre-existing):** the hover name label sits at bar-bottom + 4 and the
status row at bar-bottom − 8, so they overlap while hovering an enemy that has statuses.
