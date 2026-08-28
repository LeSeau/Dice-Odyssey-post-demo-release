# Attack Animations — Hero Body & Held Die (execution plan, 2026-08-28)

**Status: designs approved by Julien in discussion ("I really like your ideas"). NOTHING implemented.** This doc is the handoff spec for the executing session. It is self-contained: current state was verified in code on 2026-08-28, and every known trap is listed in §7 — read §7 BEFORE writing any code.

**Context in one line:** the hero now has final(ish) art, split into a body + a levitated white die overlay (`main_character_chibi.png` + `main_character_die.png`, see the "held die" section of CLAUDE.md). Attacks should feel alive: the body should move, the die's existing punch should scale with the hit, and on big/lethal single-target hits the die should physically fly out and strike the enemy.

---

## Verdict defaults

Julien left four calls open. Defaults below were chosen by Claude with rationale; **Julien may override any of them in the executing session's prompt** — each is a localized branch, not a structural fork.

| # | Question | Default | Rationale |
|---|----------|---------|-----------|
| (a) | Damage timing on the die strike | **Deferred to die impact** (strike-qualifying hits only; all other hits unchanged) | Mirrors the thrown-dice pipeline exactly, which already defers damage to the slam and has been playtest-validated as feeling great. The alternative (instant damage + cosmetic flight) fights the hit-stop freeze: the strike fires precisely on big hits, i.e. precisely when a 0.1× freeze would strand the clone mid-flight — the same failure mode the slash rework diagnosed ("le slash RATE sa propre freeze frame"). Deferring puts flight *before* the freeze, so the freeze punctuates the landing. |
| (b) | Strike trigger | **Impact tier ≥ STRONG, OR lethal hit — single-target attacks only, once per card play** | Earned, not random: players learn "big hit = the die itself goes". EXACT-requirement and Overcharge-tier triggers are listed as v2 extensions (§5), not in v1. |
| (c) | Die return style | **Blink-back rematerialize** (die dissolves through the enemy at impact; re-forms in the palm with the existing retune-flash language) | A boomerang return flight (~0.25s) drags after the beat has already resolved. Blink-back keeps the beat clean and reuses the shipped white-flash→settle vocabulary. |
| (d) | Does the body lunge ship in this pass? | **Yes, and FIRST (Batch 1)** | It's the cheapest change with the biggest payoff and the foundation the rest sits on. |

---

## §0 Current state (verified in `player.gd` on 2026-08-28)

- **The hero's body does not move at all when attacking.** Only the die punches. Meanwhile the file's own header comment notes "enemies lunge, thrown dice fly, the big die hops" — the player is the only combatant in the game whose body never moves. The hero *does* have a hit-reaction when damaged: root-position knockback + `sprite_2d.scale` squash (`_play_hit_reaction`, `_hit_squash_tween`, rest scale captured in `_hit_rest_sprite_scale`).
- **The die punch is flat.** `punch_held_die(strength := 1.0)` — `DIE_PUNCH_OFFSET (15, -11)`, `DIE_PUNCH_SCALE 1.16`, `DIE_PUNCH_ROTATION 0.22`, out `0.07s`, back `0.34s`. Trigger: a `card_played`-family listener around line 291: `if card != null and card.type == Card.Type.ATTACK: punch_held_die()`. Every attack gets the identical punch — a 2-damage poke and a 40-damage Doomsday — while the slash length, hit-stop, shake, and camera punch all already scale with damage. It is the last un-laddered feel element.
- **The die lives on `HeldDiePivot`**, a Node2D parked at runtime on the die's *ink* centre (derived from `Enemy._get_content_rect`), child of the player, built 100% in code. The die sprite has **NO material** (deliberate — see trap §7.1). Tint = `DicePalette.accent(type).lerp(WHITE, 0.15)`, driven by the signal argument (never `Global.dice_type`, trap §7.6). `DIE_RETUNE_PUNCH = 0.45` is the fractional punch on type switch.
- **The slash (CRESCENT, shipped)** spawns from `Enemy.take_damage`, ~0.055s after the die punch per the punch's own comment, laddered by damage (`CRESCENT_HOLD/LENGTH/THICKNESS` in `enemy.gd`). `HIT_SMEAR_MIN_DAMAGE = 1`.
- **The thrown-dice bash pipeline is the reusable launcher** (`dice.gd::_spawn_thrown_dice` + `card.gd::_land_thrown_die` / `_on_thrown_die_landed`): windup → ascent → hang above-left of the enemy's sprite AABB → diagonal slam → flare/squash/shake, **damage deferred to impact** via pause-safe timers, retarget to a random living enemy if the target dies mid-flight, `Card.thrown_impact_pos(target)` (static) = the canonical impact point (sprite centre — NOT `enemy.global_position`, which lies by ~124px, trap §7.8). `Global.DICE_THROW_FLIGHT_TIME = 0.95` total with windup `0.32` carved out of it.
- **The impact ladder exists**: `Shaker.Impact {VERY_WEAK..HUGE}` + `impact_for_damage()` / `impact_for_fraction()` drive shake + hit-stop tables. Hit-stop is ref-counted, longest-wins, with a real-time ramp in `_process` (because `Tween.set_ignore_time_scale()` does not exist in Godot 4.3 — trap §7.4).
- **Enemy death** already explodes into ~60 rising dice shards tinted by the active dice accent, with the corpse leaving the `enemies` group immediately (load-bearing: ~20 sites query that group).
- **`DamageEffect.execute`** is the single damage hot path (player attacks, enemy attacks, magma, statuses, thorns). It computes the modified amount, calls `take_damage` (which spawns the slash), then hit-stop/shake; the Overkill achievement already captures `target.stats.health` BEFORE `take_damage` (precedent for a pre-hit lethal read). `DamageEffect.popup_origin` exists (popup at an arbitrary point). Berserker ×1.5 is snapshotted/pre-multiplied at play time for deferred hits (trap §7.3).
- **Overcharge tiers** (18/30/46 power) live in `dice.gd` (`OVERCHARGE_*`) — only relevant to the v2 garnish.
- **Hero art may change again** (final design in progress with Jenya). All work in this plan is transform-level on the pivot/root, so it survives an art swap as long as `split_hero_die.py` is re-run — never hardcode pixel positions measured off the current PNG.

---

## §1 Batch 1 — hero body lunge (do this first)

**Goal:** every attack, the hero's body lunges toward the enemies and settles back. This alone makes the character read as alive.

- **File:** `player.gd` only.
- **Mechanism:** tween the player **root position** toward enemies (+x, slight −y is optional; enemies are to the right at x≈750–1150, hero at x≈207): out ~`0.06–0.08s` EASE_OUT, settle back ~`0.28–0.35s` EASE_OUT. Excursion `LUNGE_OFFSET ≈ Vector2(14, -4)` — must clear the ~4px/10% perceptibility floor (§7.11) with margin; 14px does.
- **Trigger:** same place as the existing die punch (the `card.type == Card.Type.ATTACK` listener). Accept a `strength` param now so Batch 2 can ladder it later; default 1.0.
- **Root-position arbitration (required):** the hit-reaction knockback ALSO tweens root position. Two owners on one property = the punch-interrupt bug family. Rule: capture a canonical `_body_rest_position` once; starting a lunge kills any live knockback tween and vice versa, snapping to rest first — exactly the pattern `punch_held_die` already uses for the pivot ("A punch interrupted mid-flight leaves the pivot away from rest; snap the canonical rest"). The sway shader is UV-based and does not care about root position (the hit knockback already proves this).
- **The die rides along for free** (pivot is a child of the player), and the die punch composes on top since its offsets are relative to `_die_rest_position`. Punch + lunge on the same beat = the intended composite.
- **No windup on the body** in v1 — latency on the game's most common verb matters; the die's anticipation (Batch 2) carries the wind-up read.

## §2 Batch 2 — die punch upgrades

**Goal:** the punch scales with the hit, telegraphs with a pull-back, and the die reads as levitated at rest.

### 2a. Ladder the punch (and the lunge) by damage
- Keep the existing `card_played` punch as the **baseline floor** (strength 1.0, unchanged behavior — this matters for cards whose damage is entirely timer-deferred, e.g. Flurry/Stampede, which would otherwise lose their punch).
- Add a **damage-time upgrade hook** in `damage_effect.gd::execute`: when (target is in the `enemies` group) AND (this execute runs **in the same frame as an attack-card play**), compute `impact_for_damage(amount)` and re-punch at laddered strength (re-punching kills/restarts the tween — `punch_held_die` already handles interruption). Suggested map: WEAK→1.0, MEDIUM→1.15, STRONG→1.4, HUGE→1.7 (`DIE_PUNCH_TIER_STRENGTH`).
- **The same-frame check is the whole filter** and there is shipped precedent: `dice.gd::_last_card_played_frame` (power-orb source detection) compares `Engine.get_process_frames()` against the frame `card_played` was emitted. Add `Global.last_attack_card_played_frame`, set in `Card.play()` (which emits `card_played` as its literal first line, so synchronous effects share the frame). This one check automatically excludes: enemy attacks (target is the player), magma roll AoE, status payouts (Earthquake), thorns, and thrown-die landings (~0.95s later) — none of which should move the held die. Multi-target AoE hits in the same frame: guard with a per-frame "already upgraded this frame" flag, take the **max** amount.
- Wire the Batch 1 lunge strength to the same tier.

### 2b. Anticipation frame
- Prepend to the punch tween: pull-back to `−0.35 × DIE_PUNCH_OFFSET` with scale ~0.96 over `0.04–0.05s`, THEN the push. This is what makes a punch read as *thrown* rather than *twitched*. ⚠️ `.parallel()` applies to the NEXT tweener, never the one just created (§7.5) — the pull-back is a sequential step before the parallel push block.

### 2c. Ghost smear on STRONG+ punches
- 2 afterimage ghosts along the push axis: `Sprite2D` copies of the die texture (no material — modulate-safe), current tint, additive-ish brightness, spawned at launch, fast fade (~0.12–0.18s), each on its own tween. Same visual word as the max-roll 3-ghost smear in `dice.gd` (grep `smear`). Skip below STRONG — at small sizes it's noise.

### 2d. Idle levitation bob
- The die currently sits perfectly still while the body sways — the only static element on the character, which is exactly what reads as dead. Add a slow vertical sine bob, **position-only** (never scale on small sprites, §7.12): amplitude `~4px`, period `~2.8–3.2s`, driven in `_process` (house pattern — looped Tweens restart at leg boundaries and phase-cluster).
- **⚠️ Two-writers trap (§7.2):** the punch tween owns `_die_pivot.position`. The bob must live on a **separate node**: insert a `HeldDieBob` Node2D between the player and `HeldDiePivot` at build time (the whole rig is built in code, so this is one `add_child` reparent in `_build_held_die`). Bob writes the bob node, punch writes the pivot, lunge writes the root — three channels, zero collisions, and the strike (Batch 3) can hide/restore the rig without touching any of them.

## §3 Batch 3 — the die strike (the star)

**Goal:** on big or lethal single-target hits, the held die launches from the palm, slams into the enemy, the damage lands ON the impact, and the die blinks back into the palm.

### Trigger (default (b))
- In the Batch 2a damage-time hook, before applying damage: qualify when ALL of —
  - same-frame-as-attack-card-play (the §2a filter),
  - target is an Enemy and the card resolved as **single-target** (`Card.Target.SINGLE_ENEMY`; AoE keeps today's presentation — v1 scope cut, see §5),
  - `impact_for_damage(amount) ≥ STRONG` **OR** lethal — lethal = `amount ≥ target health + target block`, read BEFORE `take_damage` (the Overkill achievement in this same file already does the pre-hit health read; use the same fields it uses, and the block field the "Blocked" popup test uses — don't invent a new lethality formula),
  - once per card play (per-frame/per-play guard; multi-hit cards' later hits are timer-deferred to other frames so they're excluded automatically — the strike naturally fires on the qualifying same-frame hit only).

### Choreography
1. **Launch (t=0):** the anticipation pull-back from §2b plays, then instead of the punch, the die LAUNCHES: real die hides (`visible = false` on the pivot's sprite — never free it), a **clone flight** spawns (§7.9): a `Sprite2D` with the die texture + current tint, no material, at the die's global transform, parented/z-ordered exactly like thrown dice are (mirror `_spawn_thrown_dice`'s parenting — do not invent a new layer). Launch whoosh: reuse the throw whoosh (`whipsound.mp3`, pitch-jittered) as placeholder.
2. **Flight (~0.22–0.30s, `STRIKE_FLIGHT_TIME`):** fast, slightly rising-then-falling arc to `Card.thrown_impact_pos(target)` with a small scatter (±10px). Mid-flight tumble is fine (thrown dice already tumble; the dizziness ban was for the big CENTRAL die rolled 15×/turn, not small flying dice). Accent-tinted mote trail, throttled in real time (reuse the trail helper pattern from card flight / charge delivery). This is deliberately much shorter than the 0.95s thrown-dice ceremony — the strike punctuates a resolved decision; it should feel like a gunshot, not a mortar.
3. **Impact:** the deferred damage bundle fires (below). Visually: the clone drives ~10px INTO the sprite, impact flare (mirror `_spawn_thrown_die_flare`), enemy white flash + squash arrive via the normal `take_damage` path, **the crescent slash spawns here naturally** because it lives in `take_damage` — die is the cause, crescent is the effect, in that order for free. Hit-stop/shake fire at impact and now punctuate the landing instead of stranding the flight.
4. **Blink-back (default (c)):** the clone dissolves through the enemy over ~0.1s (scale-down + fade INTO the impact flash — never a lingering bright shape, §7.10). After `STRIKE_REMATERIALIZE_DELAY ≈ 0.2s`, the real die reappears in the palm with the retune language: flash toward white → settle into current tint + `punch_held_die(DIE_RETUNE_PUNCH)`. The palm is never empty longer than ~0.5s total.

### Damage deferral (default (a)) — the one careful refactor
- When the strike qualifies, `DamageEffect.execute` must NOT apply the hit immediately. Instead: **snapshot the fully-modified amount NOW** (Berserker lesson, §7.3 — flags are cleared by `card.gd` before deferred hits land; the amount must be final by value), spawn the flight, and schedule the impact bundle on a pause-safe `SceneTreeTimer` (`get_tree().create_timer(STRIKE_FLIGHT_TIME, false)` — game-time, matching thrown dice; the flight tween is also game-time so they stay in sync, and no freeze can occur mid-flight because the freeze is IN the deferred bundle).
- **The impact bundle = everything execute normally does for an enemy target** — `take_damage` (slash, flash, squash), popup (use `popup_origin` = the impact point), hit-stop, shake, Overkill/biggest-hit/achievement reporting. **Extract the existing tail of `execute` into a helper and call the SAME helper from both the immediate path and the deferred path** — never hand-copy a subset, that's how the two paths drift.
- **Revalidation at impact** (§7.7): `is_instance_valid(target)` and still in the `enemies` group; if dead (rare — another source killed it mid-flight), retarget to a random living enemy exactly like `_on_thrown_die_landed` does, else fizzle in the air. A deferred LETHAL hit keeps the enemy alive ~0.3s longer — this is already true of every thrown-dice kill and the victory-panel flow tolerates it; no special handling.
- **The strike must NOT call `Global.report_thrown_die_landed()` or emit `dice_thrown`/`dice_thrown_landed`** (§7.13) — it is not a die roll; it must not trigger Hunting Bow/Snake Eyes Charm/Metronome/Greedy or increment roll counters. It's pure delivery of card damage.

### Ownership sketch
- `player.gd` owns the die and therefore the whole flight: add `Player.strike_with_die(target: Node, on_impact: Callable) -> bool` (returns false and no-ops if the die overlay is absent — art-swap guard). It hides the real die, spawns/flies the clone, calls `on_impact` at landing, and handles the blink-back + rematerialize (with an idempotent failsafe timer so the palm can never stay empty if something dies mid-flight — same family as the slot-materialize failsafe). `damage_effect.gd` calls it with the deferred bundle as the callable, via `Global.player` (existing reference, used by Bulwark).

## §4 Batch 4 — kill-finisher composition (mostly free)

When the strike's deferred hit is lethal, the existing death animation (corpse leaves groups instantly → ghost fade → 60 rising accent-tinted dice shards) already delivers the fantasy: **his die hit them so hard they shattered into dice.** Batch 4 is composition, not construction:

- On a lethal strike impact, the clone **embeds and holds ~0.1s** (`STRIKE_KILL_EMBED_HOLD`) before dissolving, so there's a readable "die in the body" frame right as the shards start rising.
- Render the sequence in Movie Maker and check the shard burst reads as *caused by* the die (timing/overlap), not as two unrelated events. Adjust only the embed hold and the death pre-delay if needed — do not restructure the death anim.
- This is the trailer shot. If any beat gets extra tuning time, it's this one.

## §5 Batch 5 — optional garnishes (each independently skippable)

1. **Multi-hit drumming:** Flurry/Stampede-type cards — small `punch_held_die(0.4)` taps synced to each deferred hit (hook their per-hit timers or a damage-time hook without the same-frame requirement but WITH a card-window flag), full strike reserved for the final hit if it qualifies. Turns multi-hits into drum roll + cymbal.
2. **Die flinch when the player is hit:** in `_play_hit_reaction`, a small pivot dip/wobble (position-only, via the punch-tween slot with the kill+snap pattern). The die already flashes with the body; this makes it feel like a creature.
3. **Overcharge heat on the strike:** when the strike fires at Overcharge T2+, warm the trail/flare using the existing ember/burst warmth language. Needs the overcharge level exposed from `dice.gd` (a Global or a group lookup) — do it only if trivial.
4. **v2 trigger extensions (design-approved directions, not v1):** EXACT-requirement success as a strike trigger (it already carries a bonus hit-stop — "you nailed it"), and an AoE variant (die flies THROUGH multiple bodies). Do not build these without a fresh verdict.

---

## §6 Verification protocol

1. **Fresh worktree first steps:** `--headless --import` and COUNT the errors before anything else (stale cache = harness hangs and phantom failures; `| tail` hides hangs — redirect to a file). Do not commit `.godot/` churn.
2. **Harness availability:** the harnesses named in CLAUDE.md (`debug_held_die`, `debug_slash_variants`, …) are mostly **uncommitted root files** — they may not exist in a fresh worktree. `ls debug_*` first; if absent, rebuild the minimum: boot the REAL `battle.tscn` via `start_battle()` (recipe of `debug_double_endturn` / `tier_1_crab_satyr`), Camera2D added to the `"camera"` group WITH its script (else shake/punch_zoom silently no-op and you judge a calmer scene than the game), mute the Music bus in `_ready` (`MusicPlayer.stop()` is NOT enough).
3. **Judge choreography on Movie Maker renders, never realtime capture:** `--write-movie <dir>/f.png --fixed-fps 30 --resolution 1280x720`. Realtime capture compresses the animation. Frame numbers are not comparable across runs (boot varies).
4. **Checks to build (with at least one negative control each):**
   - Body lunge: root position deviates ≥ 12px on an attack play, returns to rest ±0.5px; NO deviation on a skill/blessing play (negative control); lunge + incoming hit in the same window ends at rest (arbitration).
   - Punch ladder: measured pivot excursion strictly increases across a 3-dmg vs 15-dmg vs 40-dmg hit; a thrown-die landing and an enemy attack cause ZERO pivot motion (the same-frame filter's negative controls).
   - Strike: fires on a STRONG single-target hit and on a lethal weak hit; does NOT fire on AoE, on a sub-STRONG non-lethal hit, or twice in one Flurry; damage numbers/HP after a strike are IDENTICAL to the same play with the strike disabled (deferral must not change math); no `dice_thrown_landed` emission (assert a listener counter stays 0); die sprite visible again ≤ 0.6s after launch on every path including a mid-flight target death.
   - Kill loop: lethal strike → enemy leaves `enemies` group at impact time (not launch time), shards spawn, victory panel still appears on a wipe.
5. **Regressions to re-run:** `debug_held_die` (dim mode, 10 checks — pins the tint race fix), `debug_golem_carryover` (12), `debug_single_target_hitbox` (33 — the targets/damage path is being touched), and `debug_slash_variants` if slash timing shifted (⚠️ it hardcodes the OLD dice-row position `Vector2(514, 214)`; row is now 202 — fix the harness, not the game).
6. **Static checks:** gdtoolkit parse on every touched `.gd` AND a real `load()` of each in a booted scene (type-degradation class of bug is invisible to gdtoolkit, §7.14). Perceptibility floor: every new motion ≥ ~4px / ≥ ~10% luminosity or it does not exist (§7.11).
7. **Wrap-up:** mark everything **NON PLAYTESTÉ** in the CLAUDE.md TL;DR, note "restart the editor completely before playing" (external `.gd` edits), and remind that Julien playtests the MAIN CHECKOUT — a fix living only in a worktree reads as "still broken"; merge before he tests.

## §7 Traps (read before coding — every one of these has already cost a session)

1. **Never give the held die (or any clone of it) a material.** `enemy.gdshader` (the shared sway) ends on `COLOR = tex_color;` which destroys `modulate` — a sprite carrying it is untintable. The die's flash restores to **`null`**, the body's to `_sway_material`. Clones: no material, tint via modulate.
2. **Two writers on one property = silent fights.** Bob vs punch vs lunge vs knockback vs strike-hide: give each its own node/channel (§2d, §1) or kill+snap before takeover (the `punch_held_die` interrupt pattern).
3. **Snapshot modifiers BEFORE deferring damage.** `card.gd` clears flags (Berserker ×1.5) before deferred hits land — All In pre-multiplies for exactly this reason. The strike's deferred amount must be final by value at schedule time.
4. **`Tween.set_ignore_time_scale()` does not exist in Godot 4.3** — the call throws mid-coroutine and skips the restore (this once left the whole game at 0.1× speed forever). Real-time behavior = manual `_process` against `Time.get_ticks_msec()`. (The strike avoids the need entirely by putting the freeze inside the deferred bundle.)
5. **`.parallel()` applies to the NEXT tweener**, never the one just created; and `set_parallel(true)` after a `tween_interval` runs the fade in parallel WITH its own delay. Sequential step first, then the parallel block.
6. **Never read `Global.dice_type` in a signal listener for the active type** — take it from the signal argument (`_update_die_tint` was rebuilt around this; the connection-order race is real and was a reported bug).
7. **`area_exited`/group membership never fire for freed nodes** — every deferred callback revalidates `is_instance_valid` + group membership; arrays like `card_ui.targets` are pruned, not trusted.
8. **`enemy.global_position` lies about where the body is** (sprite baked at x=124 in the template). Impact point = `Card.thrown_impact_pos(target)` / sprite-derived, always.
9. **Clone-flight pattern** (duplicate visuals, hide original, fly the clone on its OWN tweens, restore/failsafe): the established way to fly something out of a container/rig (card flight, scout pick, refuel). Bind arrival callbacks to nodes that outlive the flight, never to the thing being freed.
10. **Additive flashes: two separate tweens** (alpha snaps then falls immediately on its own tween; scale continues on another). A held peak reads as a wash — this was measured at 1.63s of saturated white once. And a bright shape "blooming toward accent×N" can get DARKER than its white birth — use the `_hot_accent` approach if tinting hot shapes.
11. **Perceptibility floor:** below ~4px or ~10% luminosity at game speed, an effect does not exist. Three shipped effects have already died to this. Also: judge at real display size, on Movie Maker frames, not zoomed stills.
12. **Animate position, not scale, on small sprites** (scale resampling shimmers). Mass beats shape for particles (counts high enough to read).
13. **The strike is not a roll and not a throw**: no `report_thrown_die_landed`, no `dice_thrown` emission, no counters — otherwise throw-relics (Hunting Bow, Snake Eyes Charm, Metronome, Greedy…) and achievements silently fire.
14. **A single Variant-typed assignment can kill a whole file's parse** (`:=` from an untyped Global, Array literal element, `Dictionary` subscript) and **gdtoolkit reports it clean**; a parse error in a harness = infinite hang (`_ready` never runs, `quit()` never called). After edits: `--headless --import`, count errors, grep `SCRIPT ERROR` before tuning any values.
15. **Editor discipline:** Julien's editor may be open — never run a concurrent CLI import while it is; any external script edits require a FULL editor restart before he plays (the live-editor re-save has destroyed data 3 times).

## §8 Tuning levers (all new constants, grouped at the top of their sections)

- `player.gd`: `LUNGE_OFFSET / LUNGE_OUT / LUNGE_BACK`, `DIE_PUNCH_TIER_STRENGTH` (map), `DIE_ANTICIPATION_FRAC / _TIME`, `DIE_SMEAR_*`, `DIE_BOB_AMPLITUDE / _PERIOD`, `STRIKE_FLIGHT_TIME / STRIKE_SCATTER / STRIKE_REMATERIALIZE_DELAY / STRIKE_KILL_EMBED_HOLD`.
- `damage_effect.gd`: `STRIKE_MIN_TIER` (default STRONG), the lethal-OR toggle.
- Existing levers that interact: `DIE_PUNCH_*`, `DIE_RETUNE_PUNCH`, `CRESCENT_*` (untouched), `Shaker` tables (untouched).

## §9 Out of scope / do-not-do

- **No screen-crossing shockwaves** (rejected twice, "contained at the die" is the doctrine) and **no rotation on the big central die** (motion-sickness ban; small flying dice may tumble).
- **No random triggers** — every strike must be explainable by the hit that caused it.
- **No changes to the CRESCENT slash itself**, its ladder, or the death animation's structure — this pass composes with them.
- **AoE strikes, EXACT trigger, overcharge trigger** — parked as v2 (§5.4), need fresh verdicts.
- **Don't re-propose**: aura-scale pulses, boomerang return as the default, persistent tints on the power number, or anything the CLAUDE.md TL;DR marks as rejected.
