# Weak on the die — plan v2 (2026-09-06) — IMPLEMENTED, NOT PLAYTESTED
#
# As-built notes, the harness and the traps found while building live in CLAUDE.md's
# TL;DR entry. This file is the design record: read it for WHY, not for current state.

Julien: "show weak on dice (like boost?)" → then, after the first draft:
1. **No tag in the Boost panel.** "I don't wanna have boost & weak fighting each other, if you
   have boost 5 it should show +5 even if you're weakened." → `NextRollBonusPanel` is left
   exactly as it is. Weak gets a cue **on the die**, the way Surge does.
2. **Ricochet dodging Weak stays.** "ricochet works great on weak yeah that's okay" — no refund
   on rewind, unlike Boost. Documented as intended, not a bug.
3. **The eaten roll shows the effective number.** "let's show final result like the effective
   amount of power you are getting" → one number, the real gain.

So the feature is two pieces: an ambient die cue, and an honest roll popup.

## 0. What Weak is in code (everything below stands on this)

- Enemies apply it during THEIR turn (satyr screech, bigger satyr, medusa hiss, famished gnaw,
  leviathan, kraken, maelstrom), INTENSITY stacks, typically 1-4. **One card also self-applies
  it: Blaze / Blaze+** (`target = 0`, "Add 7 to your Power. Gain Weak 1").
- **It is NOT `next_roll_modifier` until the roll itself.** `_apply_roll_result()` emits
  `weak_effect_consumed` → `WeakStatus.consume_stack()` does `next_roll_modifier -= stacks;
  stacks = 0` → the same function applies the modifier and clamps Power at 0.
  `StatusHandler._on_status_applied` special-cases `id != "weak"`, so **Weak never expires on
  its own: only a roll eats it, of any type, and it eats exactly one roll.**
- Therefore the cue must read the **live player status**, not the modifier. New
  `Global.player_weak_stacks()` beside `total_surge()`: `_player_status_handler()` already
  exists, `_get_status("weak")`, `maxi(0, …)` since a consumed status sits at 0 for a frame
  before `queue_free`. Same "scan live, never cache" rule as `in_hand()` / `total_surge()`.
- Weak is **player-only** in practice: the only two appliers target the player. (`sabotage.gd`
  preloads `weak.tres` and never uses it — dead const, worth deleting in passing.)
- The Weak icon is dark rust: mean RGB (106, 62, 50), hue 13°, sat .53, **val .42**.

### ⚠️ The constraint that decides the whole design

Weak's visible life has two windows, and the dominant one is starved of light:

| window | when | Power | die state |
|---|---|---|---|
| **enemy-applied (~all of it)** | enemy turn → your first roll | **0** | aura/emanation at their idle floor, cluster dimmed to 0.5 by `battle.gd` for part of it |
| Blaze | mid-turn, after the card | 7+ | fully lit |

So **any cue built on modulating the existing light — draining the aura, the emanation, the
glow reach — has nearly nothing to drain in the case that matters.** That kills the "drained
light" candidate from draft 1. The cue has to ADD something the idle die does not already have,
which is exactly what the Surge motes do.

Second constraint: **the window is short.** The player may roll within a second of their turn
starting. At Surge's 0.55s spacing a stream alone would show 2-3 sparks before the roll — too
thin to be the whole tell. Hence the announce beat below.

## 1. The die cue — falling pale motes, Surge's mirror on every axis

| | Surge (shipped) | Weak (proposed) |
|---|---|---|
| meaning | every roll pays extra | your next roll is taxed |
| born | bottom band of the die | top of the die art |
| motion | **rise**, EASE_OUT (buoyant) | **fall**, EASE_IN (weight) |
| drift | ±14px, lively | ~±4px, no life in them |
| colour | accent → **warm gold** (warmth .78) | accent → **bleached pale**, ~.85 toward a neutral off-white |
| blend | additive | additive (same doctrine: light, never dark bodies) |
| density | scales with `total_surge()` | scales with `player_weak_stacks()` |
| clamp | rise clamped 18px above the art (slot row, z 5) | fall clamped to `_mote_spawn_base_y` (the ROLL button top, z 12) — same cached geometry, mirrored use |

**Why pale-colourless rather than a colour.** Surge uses warm gold because a spark in the die's
own accent is invisible inside that die's light field (measured, 2026-08-25). Gold is taken, and
it reads as *good*. Cold blue dies on the Blue die; sick green collides with Green/Giant; the
icon's rust is value .42 — as additive light, dark brown is just dim orange, i.e. nothing.
**Desaturated near-white contrasts by being the only colourless thing in a field of saturated
colour**, still obeys "additive light, never dark bodies", and reads as bleached/ash — which is
the meaning. Direction and easing carry the negative, not the hue.

**Turn-start announce.** In `_on_player_turn_started()`, if `player_weak_stacks() > 0`, fire a
one-shot burst (~6-10 motes, staggered over ~0.3s). This is the moment the cluster un-dims and
the player looks at the die, and it is the only reliable moment — the arrival itself happens
mid-enemy-lunge at 0.5 modulate with the player's eyes elsewhere. It also covers the "rolls
immediately" case that the ambient stream cannot.

**Ambient stream.** Its own `Timer` (not the Surge one — different density curve, independent
tuning), polling like Surge's so it picks up the signal-less path: `add_status()` on an existing
Weak just does `stacks += n` and emits nothing. Denser than Surge at equal stacks, because the
window is much shorter. Stops on its own when the poll reads 0 stacks.

**Nothing held, nothing tinted.** No `dice_display.modulate`, no shader params → it cannot
collide with the roll flashes, the dud dim, the type-switch pop or the charge absorption flash,
and it needs none of the `_die_resting_modulate()` plumbing draft 1 required. Same reason Surge
shipped clean. `z_index` matches `SURGE_MOTE_Z_INDEX` (8): in front of the face, under an inked
die, under the socket panels and ROLL button. No ink gate — Weak reveals nothing about Power,
and the ink overlay hides the motes over the face for free.

**If motes alone don't read at playtest**, the documented next lever is a held bleach on the die
face — but it costs the rest-tint plumbing AND risks reading as the "you can't play this"
language (`UNPLAYABLE_MODULATE_*`). Not in this plan.

## 2. The roll popup — show the effective gain

`_spawn_roll_popup(Global.last_roll)` fires at line 2405, and **everything that modifies the
roll happens after it**: Weak consume (2521), `next_roll_modifier` (2526), Surge (2542), held
Blood Oath bonus (2551). So today the popup prints the raw face and ignores four sources.

⚠️ **Scope: this fixes four lies, not one.** Boost, Surge and Blood Oath currently under-report
(bank grows more than the popup says); Weak is the only one that lies against the player. Making
it honest changes the Boost/Surge popups too — a Boost 3 on a face of 4 starts reading "+7".
That is more honest and probably better, but it is a visible change to shipped behaviour on
rolls that have nothing to do with Weak.

**Implementation, diff-based:** capture `power_before := Global.roll_value` at the top of
`_apply_roll_result` (before the face is banked), move the `_spawn_roll_popup` call down past
the held-bonus line, and pass `Global.roll_value - power_before`. Every current and future
modifier is covered for free, and the clamp at 0 falls out naturally. Everything in that span is
synchronous, so the popup still spawns on the same frame. The `power_punch` computation stays
where it is on `Global.last_roll` — the die's punch is about the FACE, the popup is about the
GAIN.

- Font size (`clampi(28 + value, …)`) now scales on the effective number, so an eaten roll
  visibly shrinks. Good.
- **Fully-eaten roll (delta 0)**: recommend still showing "+0" rather than nothing — a silent
  popup on the one roll that got eaten is the worst outcome. Small call, listed below.
- Optional and cheap: tint the popup pale (the mote colour) when the effective gain is less than
  the face, so the taxed roll is colour-coded to the cue that predicted it.
- Already skipped under Ink — unchanged, no leak either way.

## 3. Files touched

- `global.gd` — `player_weak_stacks()` next to `total_surge()`.
- `scenes/dices/dice.gd` — `WEAK_MOTE_*` constants beside `SURGE_MOTE_*`; the mote spawner and
  its timer; the announce in `_on_player_turn_started()`; `power_before` + the moved popup call
  in `_apply_roll_result`.
- `characters/warrior/cards/sabotage.gd` — delete the unused `WEAK_STATUS` const (drive-by).
- **No `.tscn` edit, no new `class_name`, no new `@export`, no new signal** → no live-editor
  strip risk. Full editor restart before playing anyway (dice.gd + global.gd edited outside it).

## 4. Harness `debug_weak_on_dice.gd`/`.tscn` (root, `debug_` prefix, committed)

Boot the real `battle.tscn` (recipe from `debug_surge_motes` / `debug_double_endturn`) and apply
`weak.tres` through the real `StatusHandler.add_status()`.

- **A. Stacks helper** — 0 at start; N after applying N; 0 after a roll consumes it; a second
  `add_status` (the signal-less `stacks +=` path) is reflected.
- **B. Density** — sample by SECONDS, not frames (the harness runs far above 60fps and a
  frame-window collapses to ~1.3s, passing a "denser?" check on noise alone). Assert a real
  RATIO between Weak 1 and Weak 4, not just `>`. Negative control: force the interval constant →
  the ratio collapses to ~1.0.
- **C. Geometry** — no mote ever falls past `_mote_spawn_base_y` (the ROLL button top), and that
  line really is above the button. Both halves, like the Surge ceiling check.
- **D. Popup** — Weak 2 + forced face 4 → text "+2", stacks 0, aura back to un-drained.
  Clamp case: Weak 3 + face 1 → "+0" and the bank does not go negative. **And the regression
  half: Boost 3 + face 4 → "+7", Surge 2 + face 4 → "+6"** — the popup change is what makes
  those honest, so they belong in the same harness.
- **E. Announce** — turn start with Weak pending fires the burst exactly once; turn start with
  no Weak fires nothing.
- **F. Leak** — apply, consume, settle on a path with **no manual cleanup call**, assert zero
  live nodes in the weak-mote group (the scout-comet lesson: a cleanup test that only runs the
  cleanup path cannot see a node that never frees itself).
- `WEAK_MOVIE=1` renders the strip for colour/size tuning.
- Traps to carry: `var x := Global.<untyped member>` is a parse error that HANGS the harness and
  gdtoolkit calls the file clean; the status id is `"weak"`; never compare Movie Maker frame
  numbers across runs; start mote size at the Surge values (14-26px) rather than the shop's
  (11-22px) — the shop values measured as "rendered and did not exist" inside this die's light.

## 5. Open questions

1. **Fully-eaten roll**: show "+0", or no popup at all?
2. **Popup tint** when the roll was taxed: pale, or keep the die accent?
3. The popup change makes **Boost/Surge/Blood Oath** rolls report higher than they do today.
   Confirm that is wanted, since it is a visible change outside Weak.

## 6. Cost

Motes + announce: small, self-contained, no shared surface. Popup: small but touches a hot path
and changes shipped behaviour for three other systems. Harness: medium. Order — build motes and
render the strip for colour/size first (that is the only part needing your eye), then the popup.
Roughly one session.
