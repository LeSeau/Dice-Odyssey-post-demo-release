# Scout Summon Animation — Plan (2026-08-29)

**Status: IMPLEMENTED 2026-08-29 (options A/A/default). Verified by harness (`debug_scout_summon`, 17 checks 0 fail, negative control done) + Movie Maker strip. NOT PLAYTESTED.** Everything below is the design as planned; §7 at the bottom records what changed during the build. Julien's ask: *"a cool animation on the scout panel whenever you scout. The dice display animation is good already but I'd like something from the moment you play the card and the panel appears. The panel apparition itself should also be animated."*

Scope guard: the face flicker/lock reveal, the rising-pitch plucks, the die→panel motes and the pick-flight to the next-roll slot are the part he likes — **they stay byte-identical in choreography**, only their start time shifts.

---

## 1. What exists today (verified in code)

- `Events.scout_effect` is emitted **synchronously inside `Card.play()`** (same frame as `card_played`, which is line 1 of `play()`). Emitters: the 7 `oracle_scout*.gd` scripts + `calculations.gd` — all cards. `Global.last_played_card_position` (release point, screen space) is set just before, in `card_ui.gd:452`.
- `battle.gd::_on_scout_effect` (line 558): plays a pizzicato SFX, kills prior scout tweens, resizes the panel, assigns face textures (random or `tutorial_forced_scout_faces`), then **shows the panel immediately** with a modest pop — `scale 0.7→1` TRANS_BACK + fade over `SCOUT_OPEN_TIME = 0.18s`, pivot bottom-center (set in `_resize_scout_panel`).
- `_spawn_scout_open_motes` (line 779): one accent mote per face rises **from the ACTIVE DIE** (`ActiveDice/Panel/DiceDisplay` center) into each slot, timed to lead each face's flicker ("the die projects its futures"). Targets computed arithmetically, never read from the HBox (container layout settles end-of-frame).
- Faces flicker (2 tease cycles) → lock-in overbright pop + pluck, staggered `0.3s`, first at `0.08s`. Scout 3 fully revealed ≈ **0.95s** after play today.
- Meanwhile the card itself glides to `STAGE_HOLD_CENTER (470,405)` over 0.3s, holds 0.24s, then streaks to the discard pile (`card_ui.gd` STAGE_*/COMET_*).
- `ScoutPanel` is a direct child of the battle root (base canvas, flat `ui_plate` stylebox, y 88..192 top-center, title "Choose next roll"). FX nodes parent to the `ui_layer` group node (= `BattleUI` CanvasLayer), z 149/150 — the established refuel/All-In/pick-flight convention. Battle camera is identity (+shake), so base-canvas and ui_layer coords are already mixed freely by the shipped code.

**The gap, exactly as Julien read it:** nothing connects the CARD to the panel (the motes come from the die), and the panel apparition is a generic 0.18s fade-pop.

---

## 2. Proposed beats — "the card asks the question, the die answers"

### Beat 0 — Cast (t = 0)
On `scout_effect`, resolve the **origin**:
- same-frame `card_played` and not `Global.playing_red_card` → `Global.last_played_card_position` (the release point — the exact rule power orbs already use);
- red-socket play or no card this frame (relic/debug source) → active die center;
- no die node at all (bare harness) → **skip beats 0–2 entirely, open instantly** (degenerate path stays instant, mirrors charge-delivery's no-ui_layer fallback; keeps `debug_layout_probe.gd`'s direct `_on_scout_effect(6)` call working).

Small accent launch flare at the origin. The existing pizzicato SFX moves here (it *is* a cast sound) so t=0 keeps audio feedback.

### Beat 1 — Seeker comet (t = 0 → ~0.35s)
**ONE** bright comet (scout glow texture ~28–34px, `DicePalette.accent` lerped toward white-hot — burst language) flies origin → panel center on a deterministic bezier with a modest sideways bow (the pick-flight's "one clean hero arc, not drunk wobble" rule), **EASE_IN accelerating** — it's *pulled toward the future*, the same pull language as the pick flight, in reverse. Evenly-spaced trail motes along the path (reuse the eased-t `trail_state` recipe from `_scout_pick_bezier_step`). The trail is the causal thread "this card did this".

The card's own stage-glide runs in parallel from the same point — that's already how power orbs behave on power cards, established and readable.

### Beat 2 — Impact + unfurl (t ≈ 0.35 → 0.55s)
Comet arrival = small additive bloom at panel center, plus a thin **seam of light** (stretched glow, panel-width × ~6px, accent-tinted) flashing at the panel's vertical center. The panel then **unfurls from that seam**: shown at `scale = (1.0, 0.06)` with pivot at panel CENTER, `scale.y → 1.0` TRANS_BACK slight overshoot over ~0.2s, alpha in over 0.08s. Children (title, plate) stretch open with it — reads "a window into fate opens", not "UI scales in". The seam fades as the panel passes ~half height.

Pivot note: `_resize_scout_panel` authors pivot bottom-center (the close animation folds down on it). Set the center pivot explicitly at unfurl start and restore bottom-center once the open finishes — the two never run concurrently (`_kill_scout_tweens` at the top of `_on_scout_effect` guarantees it).

### Beat 3 — Futures pour in (existing, retimed)
The die→panel motes + flicker/lock stagger run **unchanged**, with all their start intervals offset by `SUMMON_FLIGHT + IMPACT_LEAD` so the first flicker starts as the unfurl lands (~0.5s). The panel unfurls mostly EMPTY (plate + title — faces are alpha-0 until their flicker anyway, which is lucky), then the die fills it. Card opens the window, die projects into it.

### Close — unchanged
(Optional polish, off by default: mirror the open — collapse to seam + fade instead of fold-down. `_finish_scout_close` already resets scale/alpha so it's a safe swap later.)

### Timing budget
| t | event |
|---|---|
| 0.00 | play → cast flare + pizzicato, comet launches |
| 0.35 | impact bloom + seam, unfurl starts |
| 0.55 | unfurl landed, first face flickering |
| ~0.90 | first face locked (earliest possible pick — today ~0.55) |
| ~1.35 | Scout 3 fully revealed (today ~0.95) |

Net cost ≈ +0.4s before interaction. If that feels slow in play, the compressors are `SUMMON_FLIGHT 0.35→0.28` and overlapping the first flicker into the unfurl (start at seam-flash instead of unfurl-end) → back to ~+0.2s. Scout is played a few times per fight, not 15×/turn — a 0.4s ceremony on it is in budget.

---

## 3. Technical notes / constraints (from the code read)

- **Everything lives in `battle.gd`'s scout section. Zero `.tscn` edits, zero `events.gd` edits, no new signals.** Comet/seam/bloom built in code, parented to the `ui_layer` group node at z 149–150, exactly like the shipped motes. (Editor restart still required before playing — external `.gd` edit rule.)
- **Origin stamp:** battle.gd doesn't currently listen to `card_played`; add a one-line `_last_card_played_frame` stamp in `_ready()` (same trick as `dice.gd`'s power-orb detection and `Global.last_attack_card_played_frame`).
- **Degenerate-distance clamp:** the release point is player-controlled and can be nearly ON the panel (released high). If `origin.distance_to(panel_center) < ~80px`, skip straight to impact — a 3-frame comet reads as a glitch.
- **⚠️ Pre-existing micro-leak, don't copy it:** `_kill_scout_tweens()` kills mote tweens but motes free themselves via `tween_callback(queue_free)` — a kill mid-flight (fast pick / double scout) strands the node onscreen forever. Never noticed because open-motes die within ~1s. The new comet/seam/bloom are bigger and MUST NOT inherit this: register every fx node in a `_scout_fx_nodes` array that `_kill_scout_tweens()` frees, and fold the existing motes into it while there (one-line hardening, in scope).
- **Double scout mid-flight:** already handled by construction — `_on_scout_effect` starts with `_kill_scout_tweens()`; with the fx-node registry above, the old comet vanishes and the new one flies.
- **Tutorial (T3.2→T3.3):** the director `_wait`s on `scout_effect` and advances instantly, so its "Three possible rolls…" text will show ~0.5s before the faces exist. Harmless (the face gate is applied via `tutorial_scout_allowed_index` before the clickable callbacks run, and the stuck-guard is 2.5s ≫ 0.55s), but worth watching. Fallback if it reads sloppy: `Global.tutorial_on` → skip beats 0–2 (instant open, today's behavior).
- **Foresight blessing** listens to `scout_effect` → Charge 1 → a charge-delivery flight fires toward the dice row (downward) while the comet flies up. Rare combo, opposite directions, acceptable — just don't be surprised in playtest.
- **Container trap already respected:** face slot targets stay arithmetic (`SCOUT_PANEL_CENTER_X` formula), never read from HBox children.
- **SFX:** pizzicato moves to launch; new `SCOUT_UNFURL_SOUND` placeholder on impact (candidates: `drawcardsound.wav` pitched ~0.8, or the pizzicato pitched up at −8dB). Clearly flagged placeholder, Julien picks later. Reveal plucks untouched.

## 4. New tunables (one `SCOUT_SUMMON_*` block atop the scout section)

`FLIGHT_TIME 0.35` · `ARC_LIFT ~70` · `COMET_SIZE 30` · `TRAIL_SPACING 0.16` (shared recipe) · `IMPACT_BLOOM_SIZE ~90` · `SEAM_HEIGHT 6` · `UNFURL_TIME 0.2` · `UNFURL_ALPHA_TIME 0.08` · `MIN_ORIGIN_DIST 80` · `REVEAL_DELAY_OFFSET` (derived) · sound consts.

## 5. Verification plan

- New root harness `debug_scout_summon.gd/.tscn` (named `debug_*` for export exclusion; not committed — feel work): boots the real `battle.tscn` (double_endturn recipe), plays a real Scout through the release path (stamp `last_played_card_position` + emit `card_played` then `scout_effect` same frame). Movie Maker strip (`--write-movie --fixed-fps 30 --resolution 1280x720`) of the full sequence. Checks, **sampled in game time, never frame counts**:
  - A. panel not visible before impact time; visible with `scale.y ≈ 1` after unfurl;
  - B. exactly one comet per scout — double-scout spam leaves 1 live fx set (negative control: remove the kill, expect 2);
  - C. origin fallbacks — no card frame → die center; no die → instant open (and `debug_layout_probe.gd` still passes);
  - D. zero stranded fx nodes after a fast pick (the leak hardening);
  - E. `tutorial_forced_scout_faces` still consumed on the delayed open.
- Regressions: `debug_tutorial_lock` (T3 gates + stuck-guard vs the 0.55s delay), quick eyeball of the tutorial finale in the strip.
- Known traps that apply: `--headless --import` first in this worktree; typed vars everywhere (`:=` on Global members = silent parse-death + infinite hang); mute music in the harness.

## 7. What the build changed (2026-08-29)

Three things only the rendered strip could have caught — all three shipped in the first pass and were fixed before this was called done:

1. **⚠️ The unfurl wasn't visible at all.** `TRANS_BACK/EASE_OUT` on `scale.y` put the panel at full height **two frames** after impact; what remained was a plain fade. Back-out front-loads nearly all of its travel — the same trap the charge wave hit with EXPO ("~90% of the trip in the first fifth"). **Now `TRANS_CUBIC/EASE_OUT` to a 1.07 overshoot over 0.22s, then a 0.09s SINE settle** — the travel is readable (~5 frames) and the snap moved into the settle step. **Rule: for motion that must be seen to travel, never BACK/EXPO on the travel itself; buy the overshoot with a second step.**
2. **⚠️ The impact bloom held its peak** — `EASE_IN` on a fade-out keeps alpha near 1 and drops late, so a 96px white ball sat over the panel for ~5 frames, covering the title and the first face. Exact repeat of the charge-delivery ghost's held-peak bug. **Now the alpha has its own shorter front-loaded curve (`EASE_OUT`, `duration * 0.6`) while the scale keeps expanding**, and the bloom is 80px (under the 104px panel height, so it can never be a lid).
3. **The comet was too thin and too white.** 30px with a sparse trail read as a pale dot over bright act-1 stone, and `accent.lerp(WHITE, 0.45) * 1.7` saturated additively into a generic white spark — throwing away the dice identity the effect exists to sell. **Now 42px, trail spacing 0.14 → 0.09, white lerp 0.45 → 0.32** (measured against the strip: the trail now reads clearly blue on a Blue die).

Also: the **cast SFX moved to launch** (t=0 must not be silent while the comet travels) and the **unfurl got the unused viola pizzicato** — the sibling of the violoncello pizzicato the cast already used, so the two beats rhyme with zero new assets. Still a placeholder.

`debug_layout_probe.gd` had to move off a **frame count** onto a game-time timer: it measures the panel's rect, and a frame count means wildly different amounts of time depending on render speed. It reports the panel unchanged at `(401,88) 408×104`, topGap 8 / rowGap 10 — same as the documented layout.

Measured final shape (added light in the panel band): flat 0 during the flight → sharp spike to peak at impact/unfurl → settle → three rising reveal bumps. First pickable face lands ~1.13s after the play (was ~0.55s).

## 6. Decisions for Julien

1. **Bridge shape** — A) one comet from the card, die-motes stay as "the die answers" (recommended); B) N orbs from the card, one per face, REPLACING the die-motes as reveal triggers (card does everything); C) both sources (probably too busy).
2. **Panel apparition** — A) seam-unfurl portal (recommended, distinctive); B) charge-style overbright bloom materialize (consistent but that language currently means "new dice slot"); C) just beef up today's pop (impact flash + bigger overshoot — cheapest, least distinctive).
3. **Latency** — default ~+0.4s before the first pickable face. OK, or pre-compress to ~+0.2s?
4. **Optional extras** (off by default, say the word): mirror-close (collapse to seam), post-reveal "choose one" breathing on the panel border, tutorial skips the ceremony.
