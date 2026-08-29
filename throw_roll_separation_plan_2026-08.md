# Throw ≠ Roll — full separation (2026-08-29)

**Status: ✅ IMPLEMENTED 2026-08-29.** Verified by harness (`debug_throw_connections` 62 checks, 0 fail, TWO negative controls) + regressions (relic_batch 228, golem 12, ricochet 26, attack_anim 30). **NOT PLAYTESTED.**

Everything below is the original handoff spec, kept as the design record, with two corrections marked inline:

1. **§6 headline claim was WRONG and is struck through below.** Red rolls DO count as rolls. Measured, not reasoned — see §6.
2. The open questions in §9 that gated execution were answered per the recommendations already written there; they are listed as decisions in §10. **Q1, Q2 and Q4 are still Julien's to overturn.**

**The contract, in one line:** a thrown die is *not* a die you rolled. It deals its raw face value (plus Trebuchet, plus the target's own Exposed) and touches nothing else — no roll counters, no roll-triggered relics, no roll-triggered statuses, no Strength.

---

## 1. What is already done (do not redo)

**Strength / player DMG_DEALT is already excluded from thrown-die damage** — shipped 2026-08-20. `Card._on_thrown_die_landed()` sets `die_hit.amount = damage + Global.thrown_dice_bonus_fight` and every throw card passes a raw face value. `Global.thrown_dice_bonus_fight` (Trebuchet) is the only scaler. Verified on meteor(+), dice_avalanche(+), pixie_volley, cursed_toss(+), fastball(+), rampart(+), windfall(+), artillery.

So **half of the ask is already live**. Two loose ends only:

- `characters/warrior/cards/fastball.gd:22-23` still carries the *old, contradictory* comment ("Strength applies to thrown-die damage (Julien, 2026-07-21)") directly above the new one. Delete the stale two lines. Fastball is out of the draftable pool, but the comment will mislead the next reader.
- `characters/warrior/cards/dice_avalanche.gd:32-33` has the same stale pair. Same fix.

**Deliberately NOT in scope — leave alone:** `all_in.gd`'s lump hit *does* take Strength. That is the **card's** damage (Power + the sum of spent faces landing as one hit), not a die's damage, and All In already refuses to call `report_thrown_die_landed`. It is correct as-is.

**Also already separate (nothing to do):** thrown dice never join the Power chain (`roll_value` / `roll_history` / `last_roll` / `next_roll_modifier` untouched), never consume a Scout or Lucky guarantee, never fire infusion roll effects (Gnome / Bulwark / Octet / Arcane), never trigger Magma AoE, never get the Surge flat bonus, and never decrement your dice pool (the sole exception being Fastball, which spends a real pool die *before* throwing it).

---

## 2. The architecture: one funnel

Everything that makes a throw "count as a roll" today flows through **one function**:

`global.gd::report_thrown_die_landed(dice_type, value)` (line ~128)

It is called once per landing from six sites:
- `custom_resources/card.gd::_on_thrown_die_landed()` — the shared path used by meteor(+), pixie_volley(+), cursed_toss(+), dice_avalanche(+), fastball(+), artillery
- `windfall.gd::_on_windfall_landed()` and `windfall_plus.gd`
- `rampart.gd::_on_rampart_landed()` and `rampart_plus.gd`

It does two things: **bumps six counters**, then **emits `Events.dice_thrown_landed`**.

That means the whole separation is: strip the counters, and unsubscribe the 18 explicit opt-ins from the signal. There is no scattered logic to hunt down.

---

## 3. Consumer inventory — every single thing that changes

### 3a. Counters bumped inside `report_thrown_die_landed`

| Counter | Who reads it | What dropping throws means |
|---|---|---|
| `fight_dice_rolled` | **Tsunami** (+1 dmg per die this combat), **Tsunami+** (+2), **Crown** (10th die → Charge 1), **Metronome** (20th die → 20 AoE), **Sixth Gear** (every 8th → 6 Power), **Greedy** (Gargantua: every 6 dice → +2 Str to him), `status_lucky_sevens.gd` (out of pool), `effigy.gd` / `ruptured.gd` dedupe token | Throws stop filling all counters and stop feeding Gargantua |
| `dice_amount_rolled_this_turn` | **Assault(+)** ("first roll of the turn" bonus), **Stampede(+)** (≥5 dice this turn), Turbo Mode achievement (8 in one turn) | See the two real bugs in §5 |
| `dice_types_rolled_this_turn` | **Spectrum(+)** (dmg per distinct type this turn), **Prismatic Lens** (4 types in a turn → charge an unrolled type) | Dice Avalanche stops auto-completing the rainbow |
| `sixes_rolled_this_fight` | **Jackpot** / **Jackpot+** (dmg per natural 6 this fight) | Thrown 6s stop counting |
| `run_stat_dice_rolled` | End-run scoreboard row "Dice Rolled" | **Open question — see §9 Q1** |
| `AchievementManager.report_dice_rolled_this_turn()` | Turbo Mode achievement | **Open question — see §9 Q2** |

**Note: Dice Slap is already unaffected.** It reads `Global.roll_history.size()`, which throws have never touched. Its text ("plus 3 for each consecutive Dice roll") is already honest today. No change needed — but it is worth knowing, because it is the model the rest should match.

### 3b. `Events.dice_thrown_landed` listeners — 13 relics, 4 statuses, 1 UI

Each was an explicit opt-in added on 2026-07-23. All of them should be removed under the new contract.

| File | Effect | Notes |
|---|---|---|
| `relics/crown.gd` | 10th die each fight → Charge 1 | delegates to `_on_dice_rolled` |
| `relics/metronome.gd` | 20 dice in a fight → 20 dmg AoE | delegates |
| `relics/sixth_gear.gd` | every 8th die → 6 Power | delegates |
| `relics/hunting_bow.gd` | roll a 6 → 3 dmg | face-value |
| `relics/needle_die.gd` | roll a 1 → 3 dmg | face-value |
| `relics/snake_eyes_charm.gd` | roll a 1 → 1 Strength | face-value |
| `relics/underdog_ring.gd` | roll 1-2 → 2 Block | face-value |
| `relics/the_one.gd` | first 1 each fight → Charge 1 | face-value |
| `relics/giants_signet.gd` | Giant 10+ → 6 Block | type + face |
| `relics/house_money.gd` | Red 5-6 → 5 dmg AoE | red-only |
| `relics/jackpot_pin.gd` | Red 6 → 2 Strength | red-only |
| `relics/consolation_chip.gd` | Red ≤2 → Charge 1 Red | red-only |
| `relics/prismatic_lens.gd` | 4 types in a turn → charge an unrolled type | rainbow |
| `statuses/effigy.gd` | natural 6 → dmg to the cursed enemy | player card |
| `statuses/ruptured.gd` | every die rolled this turn → 3 dmg | player card |
| `statuses/status_hardened_grip.gd` | 1 Block per die rolled | Blessing |
| `statuses/greedy.gd` | Gargantua: every 6 dice → +2 Str to him | enemy |
| `scenes/card_ui/card_ui.gd:430` | refresh dynamic descriptions on landing | becomes dead once no counter moves |

---

## 4. Execution batches

### Batch 1 — gut the funnel *(the whole gameplay change lives here)*

In `global.gd::report_thrown_die_landed()`: delete every counter bump, keep only the emit. Rewrite the header comment to state the new contract (the current one explicitly documents the *opposite* rule and cites Julien 2026-07-23 — it must not survive).

Consider renaming to `report_thrown_die_resolved()` — the word "rolled" in the name is now actively wrong. Six call sites. **See §9 Q5.**

At this point the mechanic is already correct for the counter-based consumers (Tsunami, Stampede, Spectrum, Jackpot, Assault). Batch 2 is what stops the per-die triggers.

### Batch 2 — unsubscribe the 18 listeners

Mechanical, one shape repeated: remove the `Events.dice_thrown_landed.connect(...)` line, the `_on_dice_thrown_landed(...)` handler, and the matching `is_connected/disconnect` in `deactivate_relic()`. For the ten relics that delegate (`_on_dice_thrown_landed` just calls `_on_dice_rolled`), the handler disappears entirely; nothing else in those files changes.

`card_ui.gd:430` is a one-line removal (the refresh has nothing left to refresh).

**Do not forget the `deactivate_relic()` half.** A leftover `disconnect` on a signal you never connected is harmless, but a leftover *connect* with no disconnect leaks across fights — that is the standing relic pattern in this project.

### Batch 3 — text and tooltip honesty

- **`scenes/ui/tooltip.gd:74` — the "Throw" keyword tooltip currently reads "Rolls a bonus Dice without using any of your own."** That sentence teaches exactly the rule we are deleting and is the single most important text fix in the batch. Needs new copy from Julien; something in the shape of *"Sends out an extra Dice that resolves on its own. It is not one of your rolls."*
- `windfall.gd` header comment: "it DOES count as a rolled die via report_thrown_die_landed" → false, rewrite. Same for `windfall_plus.gd`, `rampart.gd`, `rampart_plus.gd`.
- `statuses/artillery.gd` header: "and the 'a thrown die counts as rolled' reporting for free" → false, rewrite.
- The stale Strength comment pairs in `fastball.gd` and `dice_avalanche.gd` (§1).
- **No card description needs to change.** Tsunami ("for each Dice rolled this combat"), Stampede ("at least 5 Dice"), Spectrum ("different Dice types"), Jackpot ("per 6 rolled") all become *strictly more* true. That is the tell that the rule is the right one.
- `global/events.gd:33-38` — the `dice_thrown_landed` doc comment states the old ruling in full. Rewrite it as the new contract; it is the canonical place a future reader will look.

### Batch 4 — invert the regression harness

**`debug_throw_connections.gd` / `.tscn` exist at repo root and are COMMITTED** (122 lines, 33 checks). They currently assert the *opposite* of the new rule — "a throw increments the three counters", "Crown and Metronome fire end-to-end from a landing". They will fail loudly, which is correct.

Do not delete and rewrite: **invert in place**. The file already has the boot recipe, the real relic instances and the counter probes. For each entry in the §3 tables, flip the assertion to "a landing does NOT move this". Then add the positive half, which today has no coverage at all:

- a thrown die still deals its raw face value
- Trebuchet's `thrown_dice_bonus_fight` still applies on top
- the target's Exposed (`DMG_TAKEN`) still applies
- `roll_value` / `roll_history` / `last_roll` are still untouched (regression guard on what was already correct)

**Negative control (house rule, mandatory):** re-run once with the counter bumps restored in `global.gd` and confirm the new checks fail. A separation test that cannot fail proves nothing.

### Batch 5 — regressions to re-run

`debug_relic_batch` (228), `debug_relic_rework` (67), `debug_card_review_batch`, `debug_golem_carryover` (12), `debug_ricochet_reroll` (26), `debug_attack_anim` (30 — it counts `dice_thrown_landed` to assert the die-strike is not a throw; that check stays valid and must still pass).

---

## 5. Two real bugs this fixes for free

Both are worth citing in the commit message; neither is cosmetic.

**Bug 1 — Artillery silently kills Assault's bonus and pre-seeds the rainbow.**
`statuses/artillery.tres` is a START_OF_TURN Blessing that throws one die of *any* of the nine types at the start of every turn. Its landing calls `report_thrown_die_landed`, which increments `dice_amount_rolled_this_turn` and writes into `dice_types_rolled_this_turn`. The counters are reset in `player_handler.start_turn()` at line 109, and the status fires later in that same chain (`activate_relics_by_type` → `relics_activated` → `apply_statuses_by_type`), with the die landing a further ~0.95s after that. So with Artillery in play:
- **Assault(+)** checks `dice_amount_rolled_this_turn == 1` for its first-roll bonus. Artillery's die is usually die #1, so your actual first roll is #2 and the bonus never pays.
- **Spectrum / Prismatic Lens** start each turn with a free random type already ticked.

Worse, it is a **race**: whether the throw lands before or after your first roll depends on real time, so the bug is nondeterministic. Cutting throws out of the counters removes it entirely.

**Bug 2 — Dice Avalanche hands Spectrum and Prismatic Lens a free win.**
Avalanche conjures one die of *every type you own* (`dice_avalanche.gd`, loop over `DICE_FACE_VALUES`). Every landing writes into `dice_types_rolled_this_turn`, so a single Avalanche instantly maxes Spectrum's damage and satisfies Prismatic Lens's "4 different types this turn" — without rolling a single die. After the change, both go back to meaning what they say.

---

## 6. The Red-roll question — my claim was WRONG, but there IS a bug next to it

### ~~Red rolls skip count-based relics~~ — FALSE, measured 2026-08-29

The original claim here was that a Red roll never emits `dice_rolled`, so Metronome/Sixth Gear could silently skip it. **That is not true**, and it was written from reading half the path.

`dice.gd::_apply_roll_result` really does emit `red_dice_rolled` *instead of* `dice_rolled` for Red. But the `dice_rolled` that every per-roll relic listens to is re-emitted a moment later, by whichever consumer resolves the roll:

- socketed card → `card_ui.gd::_on_red_dice_rolled` emits it (both the SINGLE_ENEMY/AIMING branch and the immediate-play branch reach it)
- empty socket + Armageddon → `dice.gd::_fire_socketless_red` emits it
- and `roll_dice()` refuses a Red roll unless one of those two is true, so there is no third path

Measured with a harness that boots a real battle and counts emissions (`debug_red_roll_counts.gd`/`.tscn`, at repo root): a Red roll bumps `fight_dice_rolled` by 1 and emits exactly one `dice_rolled`, identical to a Blue roll. **Red already counts like every other type. Nothing to fix there.**

### ✅ The real bug the harness found: two sockets = every per-roll relic fires TWICE

Every `CardUI` in hand connects `_on_red_dice_rolled`, and each one whose id is in `Global.charged_card_instance_ids` emits `dice_rolled`. With **Dual Cannon** played (`red_socket_capacity = 2`, and it IS in the draftable pool), two cards are socketed, both pass that gate, and one Red roll emits `dice_rolled` **twice** while `fight_dice_rolled` moves by **one**.

Measured: `[["red", 2], ["red", 2]]` for a single roll. Live consequences — Hunting Bow 6 damage instead of 3, Snake Eyes 2 Strength instead of 1, Needle Die 6 instead of 3, Underdog Ring 4 Block instead of 2, Sixth Gear +12 Power instead of +6, and Metronome firing its 20-damage AoE twice.

Not everything was exposed: `effigy.gd` and `ruptured.gd` survived because their `_last_roll_token` dedupe keys on `fight_dice_rolled`, which does not move on the second emit — and that token exists precisely because Julien reported *"it triggers twice after I roll red"* on 2026-08-16. **This was the same bug, patched locally in two files instead of at the source.** Greedy is immune for the same reason.

**Fixed at the source:** new one-shot `Global.red_roll_pending_report`, armed by `dice.gd` immediately before it emits `red_dice_rolled`, consumed by whichever emitter runs first (`card_ui.gd` or `_fire_socketless_red`). Reset per fight in `battle.gd::start_battle()`. Deliberately does NOT change *when* the emit happens — the deferral is load-bearing (`dice_interface` decrements the Red die on `dice_rolled`, and that has to stay after the card resolves). Verified 13/13.

**Not fixed, flagged:** if a socketed card's `CardUI` were freed before the roll resolved, nothing would emit and the Red roll would not count. No reachable path to it was found, and speculative code does not belong in the most bug-prone system in the game.

**`status_lucky_sevens.gd`** (out of pool) reads `fight_dice_rolled` but listens only to `dice_rolled`, so a throw used to push the counter past a multiple of 7 and skip the payout. This pass fixes that incidentally.

---

## 7. Traps — read before writing code

1. **`effigy.gd` and `ruptured.gd` use `Global.fight_dice_rolled` as a dedupe *token*, not as a count** (`_last_roll_token`). It exists because `dice_rolled` and `red_dice_rolled` can both describe one roll. Removing throws from both the counter *and* the signal keeps that coherent. **Removing only one of the two breaks it**: leave the connection while stripping the counter and a landing arrives with a token equal to the previous real roll's, so the strike is silently swallowed. Do batches 1 and 2 together or not at all.

2. **`greedy.gd`, `sixth_gear.gd`, `metronome.gd` and `status_lucky_sevens.gd` use step math** (`total/N > (total-1)/N`, or `% N == 0`, or `!= N`) that assumes the counter moves by exactly one per handled event. Any state where a throw bumps the counter but does not fire the handler *silently skips a threshold*. That is precisely the shape of the pre-existing Red bug in §6 — do not re-create it by half-doing this change.

3. **`Card._on_thrown_die_landed()` reports before its retarget/fizzle checks**, on purpose: a die that lands after its target died still counted. Under the new contract the report does nothing but emit, so the ordering no longer matters mechanically — **but do not "tidy" it below the early returns**, because Trebuchet's bonus and the damage still live under it and the retarget logic is load-bearing.

4. **`Global.thrown_dice_bonus_fight` (Trebuchet) must survive untouched.** It is applied in `card.gd::_on_thrown_die_landed`, not through any signal, so it is unaffected by batch 2 — but after this change it becomes the **only** thing in the game that scales a thrown die. Deleting it by accident would leave throws with zero interaction surface.

5. **The target's `DMG_TAKEN` (Exposed) must keep applying.** It lives inside `take_damage`, on the enemy, not on the player's scaling. "Throw ≠ roll" is about *your* dice systems, not about the enemy's vulnerability. Do not strip it.

6. **`all_in.gd` deliberately does not report** and its lump hit deliberately takes Strength. Leave both. Its inline comment already explains why — keep that comment.

7. **Do not touch `roll_history`.** It is the one thing throws have always stayed out of, and Dice Slap / Recombobulate / the whole Power chain depend on it. It is the reference behaviour, not a target.

8. **Watch the `deactivate_relic()` half of every relic edit** (§ batch 2). Standing project rule: a connect without a matching disconnect leaks across fights.

9. **Restart the editor before playtesting.** ~20 `.gd` files edited outside the editor, including the `global.gd` autoload.

---

## 8. Balance watchlist — what gets weaker, and what it means

This is the part to think about before executing, because the change is a **real nerf to the Throw archetype** and a real buff in one enemy fight.

**Throw cards lose their entire synergy surface.** Today a Dice Avalanche is exciting partly because nine landings feed Crown, Metronome, Sixth Gear, Hunting Bow, Hardened Grip, Prismatic Lens and Jackpot at once. After this change a throw is flat raw damage scaled by exactly one thing — Trebuchet. Recheck the numbers on:
- **Dice Avalanche(+)** (Rare, Celestial, up to 9 dice) — the biggest loser by far
- **Meteor(+)**, **Pixie Volley(+)**, **Rampart(+)**, **Windfall(+)**
- **Artillery** — its whole pitch is "something flies every turn"; that free per-turn value drops sharply

**Trebuchet becomes load-bearing.** It goes from "one of several throw scalers" to *the* throw scaler, and it is a single Uncommon Blessing (+3, +4 on Trebuchet+, per die). If Throw is to stay an archetype rather than a dead end, it probably needs 1-2 more throw-specific payoffs — a relic, or a card that scales off dice *thrown* this fight the way Tsunami scales off dice rolled. **See §9 Q4.** The alternative reading is that this is exactly the point: throws become a clean, un-buildable-around damage floor. Julien's call.

**Gargantua gets easier for throw decks.** `greedy.gd` stops eating throws, so a flooding deck no longer speeds up his ramp. Arguably correct (a throw is not greed on your dice bank), but it is a straight nerf to that fight's counterplay.

**Hardened Grip + throws is gone.** 1 Block per landing was a quiet combo; it goes away.

**Crown / Metronome / Sixth Gear fill slower.** Their thresholds (10 / 20 / every 8) were tuned in a world where throws counted. Metronome's 20 in particular may now be out of reach in short fights.

**The three Red-throw relics (House Money, Jackpot Pin, Consolation Chip) lose a niche trigger** — only Dice Avalanche and Fastball ever threw a Red die. Small.

---

## 9. Open questions for Julien — answer before executing

1. **End-run scoreboard.** The "Dice Rolled" row reads `run_stat_dice_rolled`. Exclude throws (consistent, recommended), keep them (flavour), or add a separate **"Dice Thrown"** row? A separate row is cheap — `run_stats_panel.gd` is a table of `{label, icon, stat}` — and it would make the new distinction legible to the player at the end of a run.
2. **Turbo Mode achievement** (8 dice in one turn). Dice Avalanche was effectively a free unlock. Leave the target at 8, or lower it?
3. **`dice_types_rolled_this_turn`** — confirm throws should stop writing to it. This is the one that changes Spectrum and Prismatic Lens most visibly (§5 bug 2).
4. **Does Throw get new payoffs?** If yes, this plan should ship alongside 1-2 of them so the archetype does not go quiet. If no, confirm that "throws are deliberately un-scalable" is the intent.
5. **Rename `report_thrown_die_landed` → `report_thrown_die_resolved`, and/or `Events.dice_thrown_landed` → `die_thrown_resolved`?** The signal name is already honest ("thrown", not "rolled"); the function name is not. Six call sites for the function, ~20 files for the signal. Recommend renaming the function only, and rewriting the signal's doc comment.
6. **Fastball** (currently out of the pool) spends a **real die from your active pool** and throws it. If it ever comes back: does spending a pool die to throw it count as rolling it? Recommend no, for consistency — but it is the one genuinely ambiguous case.
7. **Fix the Red-roll relic bug in §6 in the same batch, or separately?**


---

## 10. As-built — decisions taken during execution

Answers to §9, taken per the recommendations already written there. **The first three are Julien's to overturn.**

| Q | Decision | Reversible by |
|---|---|---|
| Q1 scoreboard | Throws excluded from `run_stat_dice_rolled`; **no "Dice Thrown" row added**. The end-screen row now means what it says. | one row in `run_stats_panel.gd` if the throw count should be shown |
| Q2 Turbo Mode | Left at 8 dice in one turn. Dice Avalanche no longer auto-unlocks it, so it is a real achievement now — and genuinely harder. | one const in `achievement_manager.gd` |
| Q3 rainbow | Throws stop writing `dice_types_rolled_this_turn`. Spectrum and Prismatic Lens mean what they say again. | — (this was the point) |
| Q4 new throw payoffs | **None added.** Trebuchet is now the only thing in the game that scales a throw. | see §8 — this is the balance call to make at playtest |
| Q5 renames | No rename. `report_thrown_die_landed` and `dice_thrown_landed` both already say "thrown", never "rolled"; only their doc comments lied, and those were rewritten. | — |
| Q6 Fastball | Out of pool; under the new rule its thrown die reports nothing, like every other throw. Its stale "Strength applies" comment was deleted. | — |
| Q7 Red bug | Claim was false (see §6). The double-emit found in its place WAS fixed. | — |

### Files changed

**Contract:** `global.gd` (funnel gutted + the new `red_roll_pending_report` token), `global/events.gd` (signal contract rewritten).

**Unsubscribed (18):** `relics/` consolation_chip, crown, giants_signet, house_money, hunting_bow, jackpot_pin, metronome, needle_die, prismatic_lens, sixth_gear, snake_eyes_charm, the_one, underdog_ring · `statuses/` effigy, greedy, ruptured, status_hardened_grip · `scenes/card_ui/card_ui.gd`.

**Red fix:** `scenes/dices/dice.gd`, `scenes/card_ui/card_ui.gd`, `scenes/battle/battle.gd`, `global.gd`.

**Text:** `scenes/ui/tooltip.gd` (the "Throw" keyword — the one line of player-facing copy that taught the deleted rule), plus stale comments in artillery, windfall, hunting_bow, effigy, ruptured, fastball, dice_avalanche, all_in.

**Harnesses:** `debug_throw_connections.gd` inverted in place (committed; 62 checks) and `debug_red_roll_counts.gd`/`.tscn` added (new, uncommitted by convention).

### Verification

- `debug_throw_connections` **62/62**, with two negative controls that both go red: restoring the counter bumps breaks 6 checks; re-adding one listener to Hunting Bow breaks the source check **and** the behavioural "no enemy damage" check (40 → 32 HP).
- `debug_red_roll_counts` **13/13**, up from 12/13 before the fix.
- Regressions: `debug_relic_batch` 228/228, `debug_golem_carryover` 12/12, `debug_ricochet_reroll` 26/26, `debug_attack_anim` 30/30. Zero `SCRIPT ERROR` / `Parse Error` in every run.
- `debug_card_review_batch` fails 14 checks — **pre-existing and unrelated**: it expects an 87-card pool and five card `.tres` files (hoard, weighted_dice, second_socket, red_edge_plus, socketless_red_plus) that do not exist in this branch's git HEAD. This pass changed zero `.tres` files.
- ⚠️ `debug_relic_rework.tscn` does not exist in this worktree, so that suite could not be run.

### Before playtesting

⚠️ **Restart the editor completely** — ~25 `.gd` files were edited outside it, including the `global.gd` autoload (which gained a variable).

⚠️ This worktree needed a `--headless --import`, which churned `.import` files and `.godot/`. **Those are local build artefacts — do not commit them.** The `.gdshader` files showing as `M` in `git status` are mtime-only; `git diff` on them is empty.
