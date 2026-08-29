# Charge pulse re-timing — fire on DELIVERY, not on launch (plan, 2026-08-28)

Implementation plan agreed with Julien on 2026-08-28. Execute exactly this; the design
debate is settled, do not reopen it.

## The decision (and why)

**Move the big die's ENTIRE charge response — gust, aura flash, converge ring, absorb
ceremony — from the moment `Events.dice_charged` is emitted to the moment the volley's
LAST delivered die lands in the dice-interface slot.** The pulse still fires FROM the big
central die (Julien's explicit call — the die is the screen's center of gravity; the rail
must NOT get a new pulse of its own). The rail's existing arrival beats (ghost, shock
ring, counter punch, kick, clack, hit-stop) stay exactly as they are; the die's pulse now
lands on the SAME beat as the rail's final clack/kick/hit-stop, so the two sites read as
one event.

Why this is the fix we've been circling:

1. Every beat in this game that works follows "projectile lands → receiver reacts"
   (power orbs' arrival reaction, the thrown-die bash). The charge pulse was the only
   impact-sized effect firing at LAUNCH — an announcement with no payoff, over before the
   eye finished following the flying icons to the rail.
2. Phrase shape: today's charge is climax-first, then a decrescendo of plinks. After the
   change it's a crescendo — launch flare → flight → rising plinks → **clack + kick +
   hit-stop + GUST on one beat**. Same logic as the FLURRY finisher carrying the cone.
3. The last arrival already carries the count-scaled hit-stop. Today the gust is dead by
   then, so the freeze frame shows plinks — the exact slash-misses-its-own-freeze-frame
   trap from the CRESCENT work. After the change the gust's bright rise happens INSIDE
   the freeze. That is intended, not a bug.
4. Keying on the arrival callback (not a timer) keeps the sync structural — it cannot
   drift when flight distance varies.

## Hard scope limits — do NOT

- Do NOT retune any gust/pulse values (`CHARGE_GUST_*`, mode 2 ships as-is), do NOT
  revive the sprite band or any screen-crossing wave, do NOT grow the gust's travel.
- Do NOT add any new light/VFX at the dice-interface rail. It already has its full
  arrival language.
- Do NOT touch `relics/runic_bones.gd` (mechanical `dice_charged` listener) or the
  deprecated `charge_dice_animation` signal.
- Do NOT restructure the internal choreography of the moved code (the two separate gust
  tweens, the `converge_time = 0.30` absorb sequencing, the flash/power tweens). Only the
  TRIGGER moves; the beats inside are approved and stay byte-for-byte where possible.
- Do NOT change the delivery flight/arrival visuals in `dice_interface.gd` beyond adding
  the emission plumbing described below.

## Current anchors (verified 2026-08-28 in this worktree)

- `global/events.gd:132` — `signal dice_charged(dice_type: String, count: int)`.
- `scenes/dices/dice.gd:790` — `Events.dice_charged.connect(_on_dice_charged)`.
- `scenes/dices/dice.gd:3058-3182` — `_on_dice_charged(charged_type, count)`: the whole
  presentational response. Universal half (charge anim kick, `_spawn_charge_pulse`,
  converge particles restart, `_charge_flash_tween` aura flash, `_emanation_surge_tween`)
  then the ownership half gated on `charged_type != dice_type` (squash → punch ladder →
  flash → power-label pulse, keyed to `converge_time := 0.30`).
- `scenes/dices/dice.gd:3189` — `_spawn_charge_pulse` (gust). Internals untouched.
- `scenes/dices/dice_interface.gd:542` — `_on_dice_charged` (delivery entry).
- `scenes/dices/dice_interface.gd:801` — `_spawn_charge_volley(charged_type, count,
  origin, base_delay, reveal_slot)`. Note: `n := mini(count, CHARGE_MAX_ICONS)`; the
  no-flight fallback at 810-814 (`parent_layer == null`) returns without any arrivals;
  the reveal failsafe timer at 820-825 is the idempotence pattern to mirror.
- `scenes/dices/dice_interface.gd:914-956` — `_on_charge_die_arrived(...)`; `final_die :=
  index == total - 1` at line 921 is THE hook: clack (923), panel kick (946), hit-stop
  (947-956) already live there.
- `debug_charge_pulse.gd` / `.tscn` (repo root, committed) — the harness. It emits
  `Events.dice_charged` directly, instantiates a real `dice_interface.tscn` (adds it to
  group `"dice_interface"`), but has **no node in group `"ui_layer"`** — so today every
  volley would take the no-flight fallback. See step 4.

## Step 1 — `global/events.gd`: declare the delivery signal

Immediately after `dice_charged` (line ~132):

```gdscript
# Presentation-only companion to dice_charged: emitted by the DiceInterface exactly ONCE
# per volley, at the moment the volley's LAST delivered die lands in its slot (or right
# away when no flight is possible - no ui_layer - and via a failsafe timer if an arrival
# callback is ever lost; see dice_interface.gd). dice.gd keys the big die's entire charge
# response (gust + aura flash + absorb ceremony) on THIS signal, never on dice_charged:
# the pulse is a landing receipt, not a launch announcement (Julien, 2026-08-28). Carries
# the volley's FULL count, not the icon-capped visual count.
signal dice_charge_delivered(dice_type: String, count: int)
```

## Step 2 — `scenes/dices/dice_interface.gd`: emit it (single owner of timing)

The interface owns delivery timing, so it also owns the guarantee that the signal fires
exactly once per volley. Three emission paths, one idempotence guard:

1. **Pending-token guard.** Add:
   ```gdscript
   var _charge_volley_seq := 0        # per-volley token for the delivered-signal guard
   var _pending_charge_volleys := {}  # token -> true while a volley owes its emission
   ```
   and a helper:
   ```gdscript
   # Exactly-once per volley: arrival callback and failsafe timer both funnel through
   # here; whichever runs first wins, the other is a no-op (mirrors the slot-materialize
   # failsafe pattern above).
   func _emit_charge_delivered(charged_type: String, count: int, token: int) -> void:
       if not _pending_charge_volleys.has(token):
           return
       _pending_charge_volleys.erase(token)
       Events.dice_charge_delivered.emit(charged_type, count)
   ```
2. **Wire the token through.** In `_on_dice_charged` (line ~567), create the token and
   register it, then pass it to `_spawn_charge_volley` (new trailing parameter):
   ```gdscript
   _charge_volley_seq += 1
   _pending_charge_volleys[_charge_volley_seq] = true
   _spawn_charge_volley(charged_type, count, _charge_origin(),
           _next_volley_delay(count), newly_visible, _charge_volley_seq)
   ```
3. **No-flight fallback** (`parent_layer == null` branch, line ~810-814): call
   `_emit_charge_delivered(charged_type, count, token)` just before the `return` (after
   the reveal handling). This keeps harness/boot contexts pulsing.
4. **Last arrival.** Thread `count` (the FULL count — the existing `total` param is the
   icon-capped `n`) and `token` into `_animate_charge_die` and on into the
   `_on_charge_die_arrived` bind. Inside the `final_die` block, right after the
   `CHARGE_FINAL_SOUND` clack (line ~923), add:
   ```gdscript
   _emit_charge_delivered(charged_type, full_count, token)
   ```
   Emit BEFORE the hit-stop lines so the die's handler builds its tweens in the same
   frame the freeze starts (listeners run synchronously; the freeze then holds the
   gust's bright rise — that's the intended money shot).
5. **Failsafe timer** in `_spawn_charge_volley`: the existing `total` flight-time sum at
   line ~823 is currently computed only inside the `reveal_slot` branch — compute it
   unconditionally and always arm:
   ```gdscript
   get_tree().create_timer(total + 1.0, false).timeout.connect(
           _emit_charge_delivered.bind(charged_type, count, token))
   ```
   (Same shape as the materialize failsafe right next to it.) The `if not
   is_inside_tree(): return` after the top `await` means a dying interface never emits —
   acceptable, the die cluster is dying with it.

## Step 3 — `scenes/dices/dice.gd`: consume it

1. Line 790: replace the connection —
   `Events.dice_charge_delivered.connect(_on_charge_delivered)`. dice.gd no longer
   listens to `dice_charged` at all.
2. Rename `_on_dice_charged` → `_on_charge_delivered`. The body (3058-3182) moves
   WHOLESALE — universal half AND ownership half. No internal edits.
3. Update the doc comment at the top of the handler: keep the two-claims explanation,
   add: this now runs at LANDING (per-volley, via `dice_charge_delivered`), launch-time
   responsiveness is carried by the delivery's launch flare + sound in dice_interface.gd,
   and the gust intentionally rides the same frame as the volley's hit-stop.
4. Also update the stale reference to `_on_dice_charged` in the comment at line ~3042.
5. Deliberate behavior note (add as a comment on the ownership gate): `charged_type !=
   dice_type` now evaluates at landing time, so switching the active die mid-flight
   changes which claim fires. That is MORE honest, not a bug — do not snapshot the
   active type at emit time.
6. The 110ms `CHARGE_PULSE_COOLDOWN_MS` stays: sequenced volleys land ≥ `CHARGE_STAGGER`
   (0.16s) apart so each volley now gets its own tinted front by design (the "bam-bam in
   distinct colors" Julien wants); the cooldown remains only as a guard against
   degenerate same-instant delivered events (e.g. two no-flight fallbacks in one frame).

## Step 4 — `debug_charge_pulse.gd`: make the harness test the NEW path

The stage builds a real DiceInterface but no `ui_layer` node, so without changes every
volley takes the fallback and the arrival-timed path goes untested.

1. In `_build_stage`, add a full-rect plain `Control` to group `"ui_layer"`
   (`mouse_filter = MOUSE_FILTER_IGNORE`) so real flights run.
2. Extend every polling window: the gust now starts ≈ `base_delay + CHARGE_STAGGER×(n−1)
   + CHARGE_BIRTH_TIME (0.16) + CHARGE_FLIGHT_TIME (0.46)` after the emit (≈0.6-0.95s
   for 1-3 dice). The poll loop around line 184 and the B-block absorb polling both need
   generous frame budgets (~3s worth). A0 stays the loud "sample never captured" guard.
3. **Rewrite C1** — its premise inverts. Old C1 asserted the 110ms cooldown swallowed the
   second of two same-frame emits. Under volley sequencing the two volleys land ~0.16s
   apart and BOTH fire a front by design. New C1: emit two types same-frame, assert TWO
   distinct gust firings (amplitude `gust` rises, decays, rises again — or radius resets
   toward `CHARGE_GUST_START` for the second).
4. **New checks:**
   - **D1 "no pulse before landing"** (the core of this change): emit
     `dice_charged("magma", 3)`, sample `shader_parameter/gust` every frame; assert it
     stays < 0.05 for the first 0.5s after emit, then rises > 0.5 within 3s.
   - **D2 "exactly once per volley"**: connect a counter to
     `Events.dice_charge_delivered`, emit one volley, wait ~3s (past the failsafe's
     `total + 1.0`), assert the counter is exactly 1 (failsafe must NOT double-fire).
   - **D3 "fallback still pulses"**: remove the ui_layer node from its group, emit,
     assert `dice_charge_delivered` fires within a few frames, re-add the node. This
     protects harness/boot contexts.
5. Movie pass (`_run_movie_pass`): lengthen the fixed waits between emits by ~1.2s each
   so strips capture the arrival beat. Assert truth remains the run WITHOUT
   `--write-movie` (documented capture trap).

## Step 5 — verification protocol (in order)

1. `--headless --import` FIRST (fresh-worktree cache rule; a stale cache hangs harnesses
   or spams "Failed loading resource").
2. Run the harness, redirect to a FILE (never `| tail` — a hang is invisible through a
   pipe): `Godot_v4.3-stable_win64_console.exe --path . res://debug_charge_pulse.tscn
   --rendering-driver opengl3 --position 2000,2000`. All checks PASS including D1-D3.
   Grep the log for `SCRIPT ERROR` — gdtoolkit does NOT catch Variant/`:=` inference
   failures, and one parse error silently kills a whole file (and hangs a harness).
3. Regression: `res://debug_golem_carryover.tscn` → expect 12/12. (`debug_ricochet_reroll`
   is known to fail on some checkouts from a stale import cache with resource-load spam —
   verify against HEAD before attributing anything to this change.)
4. Optional: one movie strip (`CHARGE_PULSE_MOVIE=1` + `--write-movie`) for Julien to
   eyeball the new sequence: launch flare → flight → rising plinks → clack + kick +
   freeze + gust on one beat.

## Known traps for the implementer (all previously paid for in this repo)

- `var x := dict_or_array[k]` = Variant = parse error that kills the ENTIRE file while
  gdtoolkit reports it clean. Type every such declaration explicitly. If an effect
  "disappears", grep `SCRIPT ERROR` before touching any tuning value.
- `set_parallel(true)` after a `tween_interval()` adds into the interval's own step (the
  wound-fade bug). The moved code uses `tween_interval` + `.parallel()` correctly — do
  not "clean it up".
- The two gust tweens (radius / amplitude) are separate ON PURPOSE — chaining them gates
  the decay behind the travel and produces a pop. Keep them separate.
- The gust's `.from(0.0)` / `.from(CHARGE_GUST_START)` pins are load-bearing (tween
  sampling + unseeded-uniform traps). Do not remove them.
- Gust rise inside the hit-stop freeze is INTENDED. If the strip shows the early travel
  stretching oddly through the timescale ramp, report it to Julien — do not tune around
  it.
- Emit the FULL `count` in the signal, never the icon-capped `n` (both current consumers
  clamp at 4, but the signal must tell the truth).
- After implementation, remind Julien to FULLY RESTART the editor before playing (3 .gd
  files edited externally, one of them an autoload).

## Done means

- The pulse/gust/absorb fire once per volley, from the big die, on the same frame as the
  rail's final clack/kick/hit-stop; nothing pulses at emit time anymore.
- Harness all-pass (old checks retimed + new D1-D3), golem regression 12/12, no SCRIPT
  ERROR in logs.
- Add a short TL;DR bullet to CLAUDE.md recording the retiming (trigger moved to
  `dice_charge_delivered`, emitted by dice_interface at last arrival, exactly-once via
  pending-token + failsafe; internal choreography untouched).
