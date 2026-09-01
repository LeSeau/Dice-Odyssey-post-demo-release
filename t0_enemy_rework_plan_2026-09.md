# Tier-0 enemy rework — implementation plan (2026-09-01)

**Status: SHIPPED 2026-09-01 — see the as-built section below for where the build differs from the plan.**

Design verdicts are Julien's and are FROZEN — do not re-litigate them, do not "improve" the
numbers. Where this doc adds something Julien did not specify it is marked **[claude-add]**
with its revert cost.

Every fact below was verified against the code on 2026-09-01 (file paths + line numbers
given). If something here contradicts the code you find, the code wins — say so, don't
silently adapt.

---

## 0. The shape of the batch

Redistribute determinism across tier 0 so each fight asks a different question:

| Fight | Question it asks after this batch |
|---|---|
| Skeleton | "A 3-beat clock you can read perfectly — race it or block it?" |
| Satyr pack | "Weak is coming, bounded but not scheduled" |
| Kraken pack | "Your Power number goes dark on an unknown beat" |
| Venom Bloom | "Pure race: kill it before the ramp outruns you" |
| Marauder | (untouched) |
| **Dice Mimic** | "Fight at 2/3 throughput, or pay it down to get your die back" |

---

## 0b. AS-BUILT (2026-09-01) — read this before the plan below

**Everything in this plan was implemented the same day.** Verified by `debug_t0_patterns.gd`
(38 checks, 0 fail, 4 negative controls), a layout render, and 7 re-run regressions. NOT
playtested. The plan text below is preserved as written; this section records where the
build differs from it.

**Deltas from the plan:**

1. **Mimic gold stays 20-30.** The richer 30-40 was a [claude-add]; Julien rejected it
   ("nah mimic wont give more money").
2. **The kraken ink-icon migration was NOT done.** `dice_debuff_intent.png` does not exist
   yet, so the krakens keep their skull. Only the Mimic's steal carries a rider, and it is
   the PLACEHOLDER `debuff_intent.png`. Both tooltip cases are already wired, so dropping
   the real PNG in is the only remaining step.
3. **`Global.dice_hostage_type` (single slot) became `dice_hostage_types` (Array).** Julien:
   "mimic will also probably appear in 1-2 other fight". Each entry withholds one die; the
   status erases its own entry on return. Costs nothing and removes the one-mimic-per-fight
   constraint the plan documented as an assumption.
4. **Kraken B's openers reuse their weighted twin's script** via a new
   `@export var opener_turn` (the pattern `tutorial_skeleton_action.gd` already uses),
   instead of the duplicated opener script the plan implied by following the Bigger Satyr
   precedent. One file holds the ink numbers rather than two that can drift apart.
5. **`enemies/crab/tutorial_attack.gd` was DELETED, not left on disk.** House convention is
   to leave cut content in place, but this orphan referenced the removed
   `Global.tutorial_enemy_attack` and would no longer have compiled. Git has it.
6. **The §2.5 child-order rule was actually applied**, not just documented: Bigger Satyr's
   conditional opener moved from child 0 to last so the picker's blind `get_child(0)`
   fallback can only ever return a legal beat.
7. **`debug_bg_audit.gd`'s hardcoded fight list was updated** — the Mimic added, the three
   cut comps removed. The plan did not mention it.
8. **Encounter positions differ from §5.4's provisional numbers**: Mimic (829, 390), Satyr
   (1044, 436). The plan's first guess put the Satyr's ink at x=1293, 13px off-screen — the
   `Sprite2D` inside `enemy.tscn` is baked at x=124, so a node's `position` is not where its
   body draws. Final spans measured 827..1079 and 1099..1237, feet 523/518, bar bottom 547
   — all inside the envelope every other tier-0 fight already established.

**One extra fix, not in the plan and found by the harness:**

**`battle.gd::start_battle()` called `reset_enemy_actions()` BEFORE zeroing
`Global.fight_turn`**, so every enemy's opening beat was picked against whatever the previous
fight left behind. It only ever worked because `run.gd` zeroes `fight_turn` when a battle
ends. Harmless while just the crab spike read that value — load-bearing now that the Skeleton
cycle, both kraken openers and the Mimic's steal are all fight_turn-gated. The two lines are
swapped, and section I of the harness deliberately dirties `fight_turn` to 99 before booting
so the regression is pinned.

**Still open / for Julien:**

- Four art assets (§10) — prompts are in [t0_art_prompts_2026-09.md](t0_art_prompts_2026-09.md).
  Three placeholders are live until they land: mimic body = the treasure chest, hostage status
  icon = `charge_dice_icon.png`, steal rider = `debuff_intent.png`.
- Re-run the layout harness on the Mimic encounter once the real body art exists — the current
  positions are tuned around a chest that is not the final silhouette.
- The playtest watch-list in §11 is unchanged.

---

## 1. Frozen verdicts

1. **Ink caps at 1 in a row** on both krakens (attacks cap at 2). Reason: reapplying Ink
   extends its DURATION, so a cap of 2 would allow ~4 consecutive turns of a hidden Power
   number on floors 1-3. Today's strict alternation was accidentally preventing this.
2. **Forced-opener override gets built**, but is applied ONLY to the Mimic encounter's satyr.
   `tier_2_defender_satyr` is NOT touched (Julien may cut that fight).
3. **All existing Strength ramps stay**: Muscle rider on Bigger Satyr's gore, on Bigger
   Kraken's crush, and on Skeleton's guard.
4. **Mimic steal is pure random among owned dice types.** Balance reference is the
   **Disciple** loadout (2 Blue + 1 Red); the other loadout sets are prototypes and are not
   a balance constraint.
5. **Mimic keeps Julien's numbers** (28 HP, 3 / 6 / 5-block+2-Str). Tune only after playtest.
6. **Marauder untouched. Tutorial Skeleton must keep working exactly as it does today.**

### Correction to carry forward
Small Kraken today does **not** allow repeats at all — both beats hard-check
`enemy.last_action != <self>` (`enemies/octopus/octopus_attack_action.gd:8`,
`octopus_attack_debuff.gd:13`), producing a forced A-B-A-B metronome. Julien's
"max twice in a row" is therefore a **real loosening**, not a formalisation of current
behaviour. (Bigger Kraken's turn-1 ink / turn-2 crush *is* current behaviour.)

---

## 2. Shared plumbing — build this FIRST

### 2.1 Consecutive-repeat cap helper
`scenes/enemy/enemy_action.gd` — add a **method**, not an `@export`:

```gdscript
# True when this action has already run `limit` times in a row, so is_performable()
# should refuse it. Centralises the last_action/last_action_count idiom that was
# hand-rolled in 4 scripts (bigger_satyr_attack_debuff, medusa x2, leviathan).
# Requires action_id to be set - an empty id can never be tracked.
func hit_consecutive_cap(limit: int) -> bool:
    return enemy.last_action == action_id and enemy.last_action_count >= limit
```

Used as `if hit_consecutive_cap(2): return false`.

A method rather than a new `@export` deliberately: zero `.tscn` churn, and no exposure to
the live-editor property-strip incident (documented 3x in CLAUDE.md).

Bookkeeping already exists and is correct — `scenes/enemy/enemy.gd:822-826`, at the end of
`do_turn()`.

### 2.2 Forced opener (per-instance)
`scenes/enemy/enemy.gd` — new `@export var forced_opener_action_id: String = ""`, honoured
in `update_action()` (line 432):

```gdscript
func update_action() -> void:
    ...
    if Global.fight_turn == 0 and forced_opener_action_id != "":
        for child in enemy_action_picker.get_children():
            if child is EnemyAction and child.action_id == forced_opener_action_id:
                current_action = child
                return
    current_action = enemy_action_picker.get_action()
```

Put it in `Enemy.update_action()`, **not** in the picker — it must sit ahead of the whole
conditional/chance/fallback chain without perturbing it.

Set per-instance in a battle `.tscn` (only the Mimic encounter's satyr uses it for now).
Empty default = every existing enemy behaves identically.

⚠️ This is a **new `@export`** → **full editor restart before playing**, and do not let an
editor with a stale `enemy.gd` re-save any `battles/*.tscn` (it would strip the field).

### 2.3 Every action needs an `action_id`
Missing today, and caps cannot track an empty id:
- `enemies/satyr/bigger_satyr_attack.gd` node (`BiggerSatyrAttack`) → `bigger_satyr_attack`
- both Marauder nodes → `machopeur_attack`, `machopeur_buff` (no behaviour change, hygiene)
- every new node created in this batch

### 2.4 Two hard rules for all numbers
- **Integer `chance_weight` only.** `enemy_action_picker.total_weight` is declared
  `@onready var total_weight := 0` — an **int**. Bigger Satyr's current 6.7/3.3 truncates.
  Use 5/5.
- **All damage/block values live in script defaults, never in `.tscn` inspector overrides.**
  Every action uses the `var base_damage = damage` snapshot pattern, which captures the
  script default *before* a scene override applies. `goblin_attack_action_2.gd:5-7` documents
  this as a live shipped footgun. No tier-0 numbers are wrong today because no tier-0 scene
  overrides them — keep it that way.

### 2.5 Fallback safety
`enemy_action_picker.gd` ends with `return get_child(0)` **without checking type or
`is_performable()`**. Rule for every AI touched here: **child 0 must be an unconditionally
legal beat.** For the krakens/satyrs that means the plain attack node sits at index 0 and the
conditional openers come after it (the conditional pass filters by `type`, not by position,
so opener priority is unaffected). For Skeleton the beat set is a total partition, so the
fallback is unreachable either way.

---

## 3. Per-enemy specs

### 3.1 Skeleton — `enemies/crab/crab_enemy_ai.tscn` (non-tutorial only)

Fixed 3-beat cycle, all CONDITIONAL, keyed on `Global.fight_turn % 3`:

| Beat | Gate | Effect | action_id |
|---|---|---|---|
| Strike | `fight_turn % 3 == 0` | 6 damage | `crab_attack` |
| Bone Guard | `fight_turn % 3 == 1` | 6 block + Muscle 1 (self) | `crab_block` |
| Bone Spike | `fight_turn % 3 == 2` | 12 damage | `crab_spike_attack` |

`fight_turn == 0` during **player turn 1** (`player_handler.gd:139` is the only increment;
`turn_banner.gd:16-18` documents this). So the cycle reads strike / guard / spike on player
turns 1 / 2 / 3, repeating. Total partition → `get_child(0)` fallback unreachable.

Also in this file:
- **Delete the `TutorialAttack` node** (child 1) from `crab_enemy_ai.tscn`. It forces a
  6-damage opener on the first crab fight of the entire run and is obsolete under a fixed
  cycle. Leave `enemies/crab/tutorial_attack.gd` on disk (house convention).
- **Retire `Global.tutorial_enemy_attack`**: `global.gd:557` (declaration), `global.gd:945`
  (run reset), and the key in `run.gd:1115`'s `SAVED_TUTORIAL_FLAGS`.
  ⚠️ Verify the save loader reads that list with `.get(key, default)` before removing the
  key — an old save still containing it must not break loading.
  Verified: those 3 sites plus `tutorial_attack.gd` are the ONLY references repo-wide.
- **Fix the block intent.** `crab_block_action.gd` has no `update_intent_text()` override
  and its Intent carries `base_text = "6"` as a literal, so the number is hardcoded and
  ignores the exported block value. Give it `base_text = "%s"` plus an override that prints
  the real (modifier-aware) block.
- Dead files `crab_big_attack_action.gd` / `crab_mega_block_action.gd` are referenced by
  nothing — leave them.

**DPT impact (say this in the summary, do not silently ship it):** roughly 5.5-5.8 → 6.3
in cycle 1, 7.0 in cycle 2, 7.7 in cycle 3 — a ~10-15% raise plus a faster ramp, and the
big hit moves from player turn 4 to turn 3. This is intended (a fully telegraphed spike is
far less punishing than a random one), but it propagates to 3 higher-tier fights — see §7.

Note the emergent combo, it is a feature: the turn-2 guard absorbs a hit and slows the
player's kill, pushing them into the turn-3 spike. Race it or block it.

### 3.2 Satyr S — `enemies/satyr/satyr_enemy_ai.tscn`
Numbers unchanged (3 damage; 2 damage + Weak 1). Both stay CHANCE_BASED at weight 5/5.
Add caps only:
- `satyr_attack_debuff.gd`: `if hit_consecutive_cap(1): return false` (never twice in a row)
- `satyr_attack_action.gd`: `if hit_consecutive_cap(2): return false` (never 3x in a row)

Deadlock check (verified): after A-A the attack is capped but the debuff is free; after B
the debuff is capped but the attack is free. Both can never be blocked simultaneously.

### 3.3 Satyr B — `enemies/satyr/bigger_satyr_enemy_ai.tscn`
- Keep the guaranteed turn-1 screech (`bigger_satyr_attack_debuff_opener.gd`, CONDITIONAL on
  `Global.fight_turn == 0`, 4 damage + Weak 2). **Keep the opener sharing `action_id` with
  the chance-based screech** — that is load-bearing: it makes the opener count toward the cap.
- Weights 6.7/3.3 → **5/5** (int truncation, §2.4).
- Both beats cap at 2 (`hit_consecutive_cap(2)`).
- Gore keeps 6 damage + Muscle 1 rider, and gains `action_id = "bigger_satyr_attack"`.

Result: T1 screech; if T2 also screeches, T3 must gore.

### 3.4 Kraken S — `enemies/octopus/octopus_enemy_ai.tscn`
Numbers unchanged (3 damage; 2 damage + Ink duration 1 + `Events.put_ink_on_dice`).
- **Replace** the `enemy.last_action != <self>` locks (which force strict alternation) with:
  - `octopus_attack_debuff.gd`: `hit_consecutive_cap(1)` — ink never twice in a row
  - `octopus_attack_action.gd`: `hit_consecutive_cap(2)`
- Weights stay 5/5.
- Delete the dead `NOT USED` node (`octopus_attack_debuff_chaos.gd`) — it can never fire
  (no `is_performable()` override, and the base returns `false`).
- `octopus_attack_debuff.gd` preloads `WEAK_STATUS` and never uses it — drop the preload.

### 3.5 Kraken B — `enemies/octopus/bigger_octopus_enemy_ai.tscn`
- Two CONDITIONAL openers (new node for crush; rewrite the existing debuff gate):
  - ink at `Global.fight_turn == 0` (4 damage + Ink duration 2 + `put_ink_on_dice`)
  - crush at `Global.fight_turn == 1` (7 damage + Muscle 1 rider)
  Same `action_id`s as their chance-based twins, mirroring the Bigger Satyr pattern.
- Then CHANCE_BASED 5/5, ink cap 1, crush cap 2.
- Delete the dead `OctopusAttackDebuff2` chaos node.
- Child order: plain crush at index 0 (§2.5), then the openers, then the chance ink.

Trace check (verified): T1 ink (count 1), T2 crush, T3 ink is legal again. No lockout.

### 3.6 Venom Bloom — `enemies/plant/plant_attack_buff_action.gd`
**One-line change:** `muscle.stacks = 3` → `4`. Nothing else.
Explicitly **do not** add Weak — this rejects the pending §8 audit proposal; the plant has
no Weak today, so "don't add it" is zero code.

⚠️ The +1 compounds every 2 turns and this AI is shared by 4 fights across 3 tiers plus act
2 (see §7). In a 6-turn tier-2 fight the buff track becomes 4/8/12 instead of 3/6/9.

`enemies/plant/machopeur_block_action.gd` and `machopeur_buff_action.gd` sit in the plant
folder unused — leave them.

---

## 4. Pool changes — `battles/battle_stats_pool.tres`

Remove these 3 entries (files stay on disk, house convention):
- `tier_0_bigger_octopus_2.tres`
- `tier_0_bigger_satyrs_2.tres`
- `tier_0_bigger_satyrs_octopus.tres`

Add `tier_0_dice_mimic.tres` (§5). Tier 0 goes 12 → 10 entries.

Two things worth knowing:
- Every *remaining* slimes fight still contains exactly one bigger body, so both bigger kits
  stay visible in tier 0. Only the redundant double-big comps are cut. Good cut.
- The `group = "slimes"` mechanic marks all 6 slimes fights used as soon as one is picked, so
  a run's 3 tier-0 fights draw at most 1 slimes fight. Computed against the new pool, the
  **Mimic appears in ~54% of runs** — it is a common fight, not a rare treat. Its numbers
  must be honest.
- Tier 0 is never recycled into act 2 (`ACT2_SOURCE_TIER` maps act-2 tier 0 to the act-1
  tier-**1** pool), so pool edits here have no act-2 effect.

---

## 5. Dice Mimic

### 5.1 Enemy
`enemies/dice_mimic/` — `dice_mimic_enemy.tres` (`max_health = 28`,
`enemy_name = "Dice Mimic"`, art from Julien, `content_center_x` measured), plus
`dice_mimic_enemy_ai.tscn`. No tier variants needed (tier-0 only for now).

### 5.2 Beats — all CONDITIONAL, total partition

| Player turn | Gate | Effect | action_id |
|---|---|---|---|
| 1 | `fight_turn == 0` | 3 damage + steal a die | `mimic_steal` |
| 2, 4, 6… | `fight_turn >= 1 and fight_turn % 2 == 1` | 6 damage | `mimic_attack` |
| 3, 5, 7… | `fight_turn >= 2 and fight_turn % 2 == 0` | 5 block + Muscle 2 (self) | `mimic_guard` |

Every node gets an explicit `is_performable()`. Child 0 = `mimic_attack` (§2.5).

### 5.3 The hostage — plumbing, and the traps

**Do not use `<type>_dice_bonus_amount`.** `dice_interface.gd::_on_player_turn_started()`
recomputes every `current_amount` from `max + bonus` and then **zeroes every bonus field in
the same function** (lines ~353-405). Any status hooking the same signal to re-apply a
deduction is in a connection-order race with that function.

Use the Golem-carryover pattern instead — handled **inline inside that same function**, which
is deterministic:

- `Global.dice_hostage_type: String = ""` — fight-scoped. Reset in `Global.reset_run_state()`
  **and** in `battle.gd::start_battle()` (the ink-reset precedent: a hostage must never
  survive into another fight, whatever happens).
- In `dice_interface._on_player_turn_started()`, immediately after the refill block and
  before/alongside the bonus zeroing:
  ```gdscript
  if Global.dice_hostage_type != "":
      var prop := "%s_dice_current_amount" % Global.dice_hostage_type
      Global.set(prop, maxi(0, int(Global.get(prop)) - 1))
  ```
  Clamped at 0 — note only Golem's line is clamped today; the other eight types can go
  negative if a negative bonus stacks.
- **Steal**: pick uniformly among types with `<type>_dice_max_amount > 0`, set
  `Global.dice_hostage_type`, and deduct 1 from `current_amount` immediately (it should
  bite the turn it happens, not next turn).
- **Return**: clear `Global.dice_hostage_type` and `current_amount += 1` immediately — the
  die is usable that same turn. That immediacy is the reward beat.

**Return trigger:** connect to the mimic's `stats.stats_changed` (it already fires on every
health write — `custom_resources/stats.gd:19`) and return when
`stats.health <= stats.max_health * 0.5` (≤ 14 of 28; reaching exactly half counts).
This also covers overkill and the killing blow, because `Stats.take_damage()` writes
`health` once before any death handling. Add `Events.enemy_died` as a belt-and-braces path,
and make the return idempotent.

**Skip the steal** if the mimic is already at ≤50% when its turn-1 action resolves (the
player acts first, so this is reachable) — otherwise you steal with the return threshold
already behind you.

**Status:** a display status on the **mimic** (so the icon sits where the player is looking
to see who holds their die), non-expiring, `stack_type = NONE`. Tooltip must name the stolen
type and the real threshold, e.g. *"Holding your Red Dice. It gives it back when it drops
below 14 HP."*

**Documented assumption:** one mimic per fight (`Global.dice_hostage_type` is a single
slot). If a second hostage-holder ever ships, this becomes a dictionary.

### 5.4 Encounter — `battles/tier_0_dice_mimic.tscn` + `.tres`
- Mimic + one small Satyr (`satyr_enemy.tres`, 8 HP).
- Satyr node gets `forced_opener_action_id = "satyr_attack"` (§2.2) — guaranteed non-debuff
  opener.
- `group = ""`, `weight = 1.0`.
- Gold **30-40** instead of the tier-0 standard 20-30 **[claude-add]** — mimics eat treasure,
  free flavour. Revert = 2 numbers.
- Run the layout harness on the new scene (feet on the ground line, no HUD overlap, status
  row clear of the hand).

### 5.5 Expected difficulty
~36 total HP, a Strength ramp, a Weak applier, and a throughput tax. Rough estimate
12-18 HP cost played average, vs ~8-12 for the rest of tier 0 — the hardest tier-0 fight,
by design. The ransom sits 14 damage away, so the hostage window self-regulates: dawdle and
it hurts, focus and it is short.

Playtest levers in order: mimic 28 → 25 HP, then Muscle 2 → 1, then satyr damage.

**Watch item:** on the Disciple reference loadout (2 Blue + 1 Red), stealing the **Red**
removes the entire gamble socket for the duration (1 of 1), while stealing Blue costs 1 of 2.
That asymmetry is accepted for now — flag it if it feels bad rather than re-rolling the pick.

---

## 6. Intent icons

`intent_ui.gd::_tooltip_text_for_texture()` and `_rider_tooltip_text_for_texture()` (lines
125-170) match on the icon's **filename basename**. A new icon with no `match` case falls
through to "This enemy is preparing something." — silently.

### 6.1 New: "will tamper with your Dice"
File `dice_debuff_intent.png`. Cases in **both** match blocks:
- primary: *"This enemy will tamper with your Dice."*
- rider: *"It will also tamper with your Dice."*

Uses:
- **Mimic steal** — attack icon + `icon2 = dice_debuff_intent` → "This enemy will attack you.
  It will also tamper with your Dice."
- **[claude-add, recommended] Migrate both krakens' ink beats** from `debuff_icon.png` (a
  skull) to attack icon + this rider. Ink is a dice debuff, not a generic "bad thing", and
  the skull currently carries the damage number. This is the same intent-honesty fix the
  August pass applied elsewhere. 2 lines per AI; skip it if you want the batch smaller.

Keeps a clean distinction: **skull = debuffs YOU (Weak), new icon = messes with your DICE.**

### 6.2 Later: "will give you bad cards"
File `junk_card_intent.png`, for the act-2 junk-card plan. Add the two tooltip cases now
(harmless while no icon points at them) so the plumbing is ready.

### 6.3 Art brief for Julien
The intent family was regenerated in one batch on 2026-07-25 and **swaps as a block, never
mixed**. Match it: 500x500, cel-shaded, thick near-black outline, flat 2-tone, ~86% canvas
fill, no fine detail (renders at 60px). Generate on a **chroma-key background that does not
collide with the subject colour** (green bg for a dark/purple subject; magenta only for
light subjects — a purple subject on magenta keys out at 38% opacity, a documented failure).
Then `--headless --import`.

Subject suggestions: a die with a hand/tentacle closing on it, or a die with a crack/lock.
Must read at 60px and must not be confusable with the existing dice-face art.

---

## 7. Blast radius — these AIs are shared

Every tier variant of an enemy points at the **same AI scene**; only `max_health` differs.
So each change below propagates, and tiers 1-2 are recycled into act 2 via `ACT2_SOURCE_TIER`.

| Change | Also affects |
|---|---|
| Skeleton cycle | `tier_1_crab_satyr`, `tier_1_lurker_crab`, `tier_2_plant_crab` (+ act 2) |
| Satyr S caps | `tier_1_crab_satyr`, `tier_1_octopus_2_satyrs_2` |
| Satyr B caps/weights | `tier_1_machopeur_satyr`, `tier_1_octopus_2_satyrs_2`, `tier_2_defender_satyr` |
| Kraken S caps | `tier_1_octopus_2_satyrs_2` |
| Kraken B openers/caps | `tier_1_machopeur_octopus`, `tier_1_plant_octopus`, `tier_1_octopus_2_satyrs_2`, `tier_2_machopeur_octopus` |
| Venom Bloom +4 Str | `tier_1_plant_goblin`, `tier_1_plant_octopus`, `tier_2_plant_crab` (+ act 2) |

Two to call out explicitly in the summary:
- `tier_1_lurker_crab` is already documented as a wall; the Skeleton now hits harder and
  ramps faster there.
- Venom Bloom's +1 compounds hardest in the longest fights, i.e. tier 2 and act 2.

Produce a before/after DPT line for each affected fight.

---

## 8. Verification

House method: every harness needs a **negative control** — revert the fix, prove the check
goes red — otherwise it proves nothing.

1. **`debug_t0_patterns.gd`/`.tscn`** (repo root, **commit it** — it pins gameplay
   invariants, not feel). Drive `enemy.update_action()` over N simulated turns per AI,
   replicating exactly the `last_action` / `last_action_count` bookkeeping from
   `enemy.gd:822-826` without running the tweens. Assert:
   - Skeleton: strike/guard/spike in that order, 6+ cycles, no other beat ever picked
   - Satyr B / Kraken B: turn-1 (and Kraken B turn-2) openers are 100% over many runs
   - every cap holds over ~500 simulated turns per AI (max run-length of each `action_id`)
   - ink never appears twice in a row on either kraken
   - the `get_child(0)` fallback is never reached
   - forced opener: the Mimic's satyr opens `satyr_attack` 100% of the time
2. **Mimic scenario in a real battle** (not simulated): steal fires turn 1 → the type's
   `current_amount` drops → it is **still** down after a turn boundary (this is the trap in
   §5.3; the refill must not silently give it back) → damage to ≤50% → returns immediately
   and is usable that turn → next fight starts whole. Plus: overkill from above 50% still
   returns; a mimic already ≤50% on turn 1 skips the steal.
3. **Tutorial regression** — run the tutorial fight end to end. `crab_tutorial_ai.tscn` and
   `tutorial_skeleton_action.gd` must be untouched and behave identically, including the
   35-damage beat and its skip-guard.
4. **Save regression** — load a save written before `tutorial_enemy_attack` was removed.
5. Re-run the existing harnesses that touch these fights, plus the layout harness on the new
   encounter.
6. `--headless --import` and count errors after any `.tres`/art change (the only reliable
   net against a parse error that gdtoolkit misses).

**Full editor restart before playing** — new scripts, a new `@export` on `Enemy`, a new
`Global` var, a removed `Global` var, new `class_name`s, new art.

---

## 9. Landmines — do not do these

- **Do not touch** `crab_tutorial_ai.tscn`, `tutorial_skeleton_action.gd`,
  `battles/tutorial_fight.tscn`.
- **Do not set damage/block from the `.tscn` inspector** (§2.4).
- **Do not use `Global.player_hp` for anything.** Verified: `EnemyStats extends Stats` and
  does not override `set_health`, so **every enemy taking damage overwrites
  `Global.player_hp` with the enemy's HP**. It is inert today (nothing reads it —
  `run.gd:840` reads `character.health` directly), but it is a live landmine.
- **Do not use `float` `chance_weight`** (§2.4).
- **Do not put the hostage on `bonus_amount`** (§5.3).
- Statuses connected to a global `Events` signal must check their owner's side — a status on
  an enemy that listens globally will fire for the player too (documented incident).

---

## 10. Asset asks for Julien

1. Dice Mimic body art (§5.1) — a chest/mimic with dice motifs; must read at tier-0 size.
2. Hostage status icon (30px render — dark-on-dark is the failure mode).
3. `dice_debuff_intent.png` (§6.3).
4. `junk_card_intent.png` — later, for act-2 junk cards.

---

## 11. Playtest watch-list

- Skeleton's turn-3 spike on floors 1-3, and the same fight at tiers 1-2 / act 2.
- Mimic overall cost (it appears in ~54% of runs).
- Red-steal on the Disciple loadout (loses the whole socket).
- Venom Bloom's +4 in long fights.
- Whether the krakens now feel *too* random with ink capped at 1 (if so the lever is the
  weights, not the caps).
