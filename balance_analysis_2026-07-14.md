# Dice Odyssey — Combat Balance Re-Analysis (2026-07-14)

**Status: APPLIED same day.** Companion/successor to `balance_analysis_2026-07.md` (2026-07-04); that doc's D/P allocation model and design principles (§3–§4 there) are reused here, not re-derived. Everything below is code-verified against the working tree on 2026-07-14.

**Corrections after Julien's review (same day, before implementation):**
- **Breach's removal from the draft pool was intentional** ("too situational"), not the Godot-resave regression I flagged in §5.1 — do not re-add it. That whole finding is void.
- **The event_test/event_deonassius/event_more_money_for_hp "text/number mismatch" I reported in §5.2 was my own misreading during static analysis, not a real bug.** Julien clarified the actual wiring: `event_test.tscn` (displayed content: Deonassius, "gain 60g/lose 10hp or leave") was correctly linked to `event_deonassius.gd` (which does exactly +60g/-10hp) — I had mistakenly cross-checked it against the unrelated `event_test.gd`. `event_test.gd` (accept 40g / greedy 100g-16hp / leave) was in turn correctly linked to `event_more_money_for_hp.tscn` (the "dark chest" event) — again matches its own text exactly. **The only real problem was the confusing filenames** (a scene named "test" hosting live Deonassius content; a script named "test" backing the live dark-chest event) — fixed by renaming, see §7.

Trigger: Julien's pre-release playtest read — (a) hallway fights can drag when the early drafts don't include damage, wants them slightly less HP-heavy and slightly more dangerous; (b) Lich scales too hard, wants lower base damage while keeping the Absorb mechanic. Both reads are **confirmed by the numbers below** — plus a few smaller findings (§5), all resolved.

---

## 1. What changed since the July 4 model (player-side power audit)

The enemy side is byte-identical to the July 4 retune (all HP and damage exports verified unchanged). The **player side grew on five fronts**, which is why fights that were tuned to feel dangerous in July now feel "safe but long":

1. **Scout 3 is in the starter deck** (deck 11 → 12 cards). It's Celestial (playable with 0 dice/power), Support (doesn't reset power), **no Exhaust**. Once per ~2.4-turn deck cycle the player picks their next roll from 3 faces. Consequences:
   - Low Blow becomes a **reliable 9 damage** (scout a ≤3 → X3) instead of a gamble.
   - Every requirement card (EXACT/MIN/MAX/EVEN/ODD) is castable-on-demand once per cycle — Bullseye, Duo, Doomsday etc. are dramatically more draftable.
   - **Lich counterplay is now teachable from the starter deck**: end your turn on a scouted low face (see §4c).
   - Variance shrinks: the "bad-tail" turn (nothing lines up) is much rarer than the July model assumed.
2. **Reinforce is +2** (July 4 change, was +1 in the old model's tables).
3. **Draft pool is 71 cards** (was ~50 at the July analysis). 27 are Attacks (38%); ~11 are multipliers/near-multipliers (X2–X5, ~15% of pool). New archetypes that matter for balance:
   - **Block-payoff**: Bulwark (damage = block), Juggernaut (X dmg + X block, Min 12), Dominance (Exposed 2 all + X block). *These only have equity if enemy damage is worth blocking — supports the "slightly more dangerous" direction.*
   - **Power-independent damage**: Momentum (3 + 3/card), Crescendo (= power generated this turn), Tsunami (X + 1/die rolled this combat) — long-fight scalers.
   - Spend-all burst (All In), pair/triple payoffs (Resonance, Jackpot), sustain (Second Wind: heal half power).
4. **Card upgrades exist and are free** (campfire choice heal-vs-upgrade, plus Whetstone/Twin Shrines/Golden Die events). A typical map deals ~4 campfires; by floors 9–13 a run carries **2–4 upgraded cards (+30–50% each)**. This is a mid-run power source the July model didn't have at all.
5. **Relic pool 15 → 25**, and the 10 new ones are mostly free combat power/consistency: House Money (5 AoE on Red 5–6), Obsidian Scale (+1 Evil die turn 2 — Evil avgs 4.5), Trick Scale (+1 Mech turn 3), Metronome (+2 power per 3rd roll), **Overflow Valve (end of turn: unspent power → damage to a random enemy — eliminates conversion waste entirely)**, Echo Chamber (+1 Blue on consecutive pair), Cartographer's Quill (+1 Scout face), Snake Eyes Charm (+1 Str per rolled 1), Prayer Beads, Flywheel. At ~2.5–3.5 relics/run these add up.
6. **Events pool 12 → 22 live entries** with a much richer sustain economy: fountain (~16), Healing Spring (10–25), Wayside Shrine (15), Golden Die Shrine (15), Patient Monk (+8 max or heal 20), relic-or-heal — plus free removes/upgrades. Campfire heal is now 33% of max HP (scales with Hollow Idol/Patient Monk max-HP gains).

### Updated P bands (effective per-turn power, damage-side assumes competent play)

| Stage | July 4 model | Now | Why |
|---|---|---|---|
| Floors 1–3 | ~11 | **~11–12, far less variance** | Scout 3 + Reinforce +2 raise the floor, not the ceiling |
| Floors 4–8 | ~16–19 | **~17–21** | bigger pool, first upgrade, first new-relic pickups |
| Floors 9–13 | ~22–26 | **~25–32**, burst 45–70 | 2–4 upgrades, 2–3 relics, dice #2, consistency tools all online |

**Key structural point: the attrition budget got cheaper for the player** (more heals, % campfire, Second Wind) **while per-turn danger stayed flat**. Long safe fights are now doubly wrong: they cost the player nothing except real-world time. Julien's instinct (less EHP, more D) is exactly what the model prescribes.

---

## 2. Current fight tables (code ground truth, 2026-07-14)

Pool: 34 entries — tier 0: 12, tier 1: 9, tier 2: 9, elites: 3, boss: 1. Tiers: run.gd rows 0–2 / 3–7 / 8–12. All per-tier `.tres` HP decoupling from July 4 intact.

### Tier 0 (floors 1–3) — healthy, DO NOT TOUCH
Julien: "fair amount of challenge, much better than before." 8/8/18 critters, Crab 26 (12-spike every 4th), Plant 32 (+3 ramp), Machopeur 31. Kill times 3–4 turns, matches targets. The `slimes` group prevents critter-pack repeats. Leave as-is.

### Tier 1 (floors 4–8) — 9 fights

EHP★ = HP + expected block over a median-length fight (block actions ≈ 5–6/cycle). D columns vs. current P ≈ 17–21. "Kill turns" = median draft (one multiplier by floor ~5) / bad-tail draft (starter damage only, P damage-side ~6–9 after block tax).

| Fight | HP total | EHP★ | Turn-1 D | Steady D | Spike | Kill turns med/bad |
|---|---|---|---|---|---|---|
| Goblin (25) + Oculus (22) | 47 | 47 | 12 | 11–13 (Oculus ramps +3/cycle) + Parasite | 15 by t4 | 3–4 / **6–8** |
| Temple Defender | 38 | ~48 | 10 | 5.0 avg, +1/cycle | 10 every 3rd | 3 / 5–6 |
| Sigil Slug | 42 | ~52 | 10 | 6.7 avg, +2/cycle | 10 | 3–4 / 6 |
| Lurker (Flux) | 40 | ~48 | 9 | 6 avg, +2/cycle | 9 | 3–4 / 6 |
| Plant (32) + B.Octopus (18) | 50 | 50 | ~9.5 | 10–12 rising, Ink tax | 14 late | 3–4 / **6–8** |
| Machopeur (31) + B.Satyr (18) | 49 | 49 | 4 + Weak 2 | 9–13 rising fast (TS2), Weak tax | ramp is the spike | 3–4 / **6–8** |
| Plant (32) + Goblin (25) | **57** | 57 | 10 | 11–13 rising | 14 late | 4 / **7–9** |
| Crab (26) + 2×Satyr (8,8) | 42 | ~48 | ~11 | decays as satyrs die | Crab 12 every 4th | 3 / 5–6 |
| Machopeur (31) + B.Octopus (18) | 49 | 49 | 5.5 | 9–13 rising, Ink tax | ramp | 3–4 / **6–8** |

**Read:** median D/P ≈ 0.35–0.55 — lower half of the fun zone, trending safe. EHP 47–57 on the five pair fights is what produces the 6–9-turn bad-tail slogs Julien felt. **It's an EHP problem plus a soft floor on D, not a spike problem** — spikes (10–12) vs 55–66 current HP are only 16–20%, well under the 35–45% survivability ceiling, so there's headroom to raise the floor without lethality risk.

### Tier 2 (floors 9–13) — 9 fights

vs. current P ≈ 25–32:

| Fight | HP total | Turn-1 D | Steady D | Spike | Kill turns med/bad |
|---|---|---|---|---|---|
| Medusa | 62 | 12–15 | ~10.4 | 15, 12+Weak 2 | 2–3 / 5 |
| Lava Hound | 55 | 6 | ~7.7 | 11 + Exposed-3 window | 2–3 / 5 |
| Maelstrom (Vortex) | 58 | Chaos | ~6 rising | 12 alternating | 2–3 / 5 |
| Plant (42) + Crab (34) | 76 | ~10 | 10–12 rising | 12/14 | 3 / 6–7 |
| 2×Kraken + 2×Satyr (10,23,23,10) | 66 | **~14 + Weak 2 + Ink** | decays | turn-1 burst | 3 / 5–6 |
| Machopeur (40) + 2×Kraken (23,23) | 86 | ~11 | 12–15 rising | ramp | 3–4 / **7+** |
| Defender (49) + Machopeur (40) | 89 | ~10 | 12–16 rising | 10-spike + ramp | 3–4 / **7+** |
| Defender (49) + 2×B.Satyr (23,23) | **95** | **18 + Weak 4** | 12–14 | turn-1 burst | 4 / **7–8** |
| Lurker (52) + Crab (34) | 86 | ~15, Flux | 10–12 | Crab 12 | 3–4 / **7+** |

**Read:** the four 86–95-EHP comps are the act's longest fights for mid decks. Their danger is fine (Defender+2Satyr's 18-burst ≈ 35–45% of typical current HP at that depth — at the ceiling, don't raise); their length is not. Solos (55–62) melt for good decks — that's acceptable, they carry spike identity.

### Elites & boss

| Enemy | HP | Pattern | Total unblocked over a median fight |
|---|---|---|---|
| Dragon Priest | 90 | Canalize; 13 flat (+3M on >9 bank, re-arms) | ~55–70 |
| **Lich** | 85 | Absorb; 11 + Muscle(=last roll, cumulative) | **~68–95** (see §4c) |
| Gargantua | 95 | 11 / 11 / Exposed 3; Greedy (+1M per 6 dice) | ~55–70 (Exposed-amplified) |
| Leviathan (boss) | 140 | 18+Ink 3 / 15+Weak 2 / block 8+M4 | ~11.8 DPT ramping past 20 |

Lich is the outlier — see §4c. Others: leave. (With P up since July, good decks kill elites in 3–4 turns; reports still say they "feel right", so watch, don't touch.)

---

## 3. Diagnosis

1. **Hallway drag confirmed and localized.** Five tier-1 pairs (47–57 EHP) and four tier-2 comps (86–95) are the offenders. A bad-tail deck (no damage draft by floor 5 — roughly a 1-in-4 outcome given 38% attack share × 3-card picks, less with reward pity) grinds 6–9 turns while never being threatened (D/P ~0.4).
2. **The safe part and the long part have the same root**: EHP tuned in July against a weaker, swingier player. Player floor rose (Scout, Reinforce +2, upgrades, relics, heals); enemy numbers stood still.
3. **Direction: shrink EHP ~10%, raise the D floor (not the spikes).** Spikes are already at the survivability ceiling in tier 2, but tier-1/2 *base* beats (4–7) have headroom. Raising the floor also gives the new block-payoff cards (Bulwark/Juggernaut/Dominance) and Block drafts real equity — the richer heal economy has made chip damage too ignorable.

---

## 4. Retune — APPLIED 2026-07-14

### 4a. HP trims — safe everywhere (per-tier `.tres` decoupling means zero cross-tier side effects; act 2 inherits automatically via multipliers)

**Tier 1 (−10–12%):**

| Resource | HP now → proposed |
|---|---|
| `temple_defender/defender_enemy.tres` | 38 → **34** |
| `sigil_slug/sigil_enemy.tres` | 42 → **37** |
| `lurker/lurker_enemy.tres` | 40 → **36** |
| `goblin/goblin_enemy.tres` | 25 → **22** |
| `oculus/oculus_enemy.tres` | 22 → **20** |
| `plant/plant_enemy_tier1.tres` | 32 → **28** |
| `machopeur/machopeur_enemy_tier1.tres` | 31 → **27** |
| `octopus/bigger_octopus_enemy_tier1.tres` | 18 → **16** |
| `satyr/bigger_satyr_enemy_tier1.tres` | 18 → **16** |
| `crab/crab_enemy_tier1.tres` | 26 → **24** |
| `satyr/satyr_enemy_tier1.tres` | 8 (keep) |

Resulting fights: Goblin+Oculus 42 • Defender 34 • Slug 37 • Lurker 36 • Plant+Oct 44 • Macho+Satyr 43 • **Plant+Goblin 50** • Crab+2Sat 40 • Macho+Oct 43. Bad-tail worst case drops from 7–9 to ~5–7 turns; median stays 3–4.

**Tier 2 (−8–9%):**

| Resource | HP now → proposed |
|---|---|
| `medusa/medusa_enemy.tres` | 62 → **58** |
| `hound/hound_enemy.tres` | 55 → **51** |
| `vortex/vortex_enemy.tres` | 58 → **54** |
| `plant/plant_enemy_tier2.tres` | 42 → **38** |
| `crab/crab_enemy_tier2.tres` | 34 → **31** |
| `machopeur/machopeur_enemy_tier2.tres` | 40 → **36** |
| `octopus/bigger_octopus_enemy_tier2.tres` | 23 → **21** |
| `satyr/bigger_satyr_enemy_tier2.tres` | 23 → **21** |
| `temple_defender/defender_enemy_tier2.tres` | 49 → **45** |
| `lurker/lurker_enemy_tier2.tres` | 52 → **47** |
| small `satyr_enemy_tier2` / `octopus_enemy_tier2` | 10 (keep) |

Resulting fights: Medusa 58 • Hound 51 • Vortex 54 • Plant+Crab 69 • 4-body 62 • Macho+2Kraken 78 • Def+Macho 81 • Def+2Satyr 87 • Lurker+Crab 78.

**Tier 0, elite HP, boss: no changes.**

### 4b. Damage bumps — ⚠️ constraint discovered: AI scenes are SHARED across tiers

The July decoupling was **stats-only**. Every per-tier `.tres` points at the *same* AI `PackedScene`, so a damage export change propagates to **every tier that enemy appears in, including act 2**. Satyr/Octopus/Crab/Plant/Machopeur all appear in tier 0 → bumping them would touch the tier Julien says is right. **Only bump tier-exclusive enemies:**

| Enemy (tiers) | Change | Effect |
|---|---|---|
| Goblin (t1 only) | `goblin_attack_action.gd` & `_2.gd`: → **7** (Unlucky hit stays 5) | steady ~5.7 → 6.3 |
| Oculus (t1 only) | `oculus_attack_action.gd` & `_2.gd`: 6 → **7** | cycle 7/10/10/13 |
| Lurker (t1+t2) | `lurker_attack_action.gd` & `_2.gd`: 9 → **10** | both tiers want it |
| Temple Defender (t1+t2) | `defender_attack_action_2.gd`: 5 → **6** (double-hit, so 10→12 total; 10-spike unchanged) | cycle 10 / 12 / block |
| Lava Hound (t2 only) | **skipped, not applied** — see note below | |
| Sigil Slug, Medusa, Vortex | **no change** | already the high end / spikes at ceiling |

**⚠️ Discovered mid-edit: `goblin_attack_action.gd` had a latent copy-paste bug** — `@export var damage := 6` was pure decoy, `perform_action()`/`update_intent_text()` both actually read a separate hardcoded `var base_damage = 7` that ignored the export entirely. Goblin's basic attack was **already dealing 7**, not the 6 shown in the inspector. Fixed the export to `7` to match reality (no behavior change) rather than leave a misleading field. Same shape existed on `goblin_attack_action_2.gd`/`lurker_attack_action.gd`/`lurker_attack_action_2.gd`/`defender_attack_action_2.gd` (export unused, a separate `base_damage` literal is what actually runs) — edited `base_damage` directly on all of them and kept the export aligned for future readability. `oculus_attack_action.gd`/`_2.gd` and `lich_attack_action.gd` don't have this bug (`base_damage = damage`, genuinely linked), so editing the export alone was correct there. No scene-level property overrides found on any of these nodes in their `.tscn` files, confirmed by grep before editing.

**Lava Hound bump skipped**: both of its soft-beat scripts (`hound_attack_action_fight_start.gd`, `hound_attack_action_2.gd`) turned out to be **double-hit actions** (2 separate `damage_effect.execute` calls per activation, intent literally labeled "2x%s") — a naive +1 to the export is actually +2 total damage per activation (12→14), a bigger jump than intended for a "floor" bump. Left Hound untouched this pass; revisit with a deliberate total-damage target if he still reads too safe after the HP trim alone.

This lands tier-1 steady D roughly in the high-single-digits to low-teens range (D/P ≈ 0.45–0.6) — the middle of the fun zone. If playtest still reads safe, the next lever is duplicating AI scenes per tier for the shared critters (heavier work; only if needed), or revisiting Hound with a proper double-hit-aware number.

### 4c. Lich — reduce base damage 11 → 8 (keep Absorb untouched)

Mechanics verified: turn 0 casts Absorb; the status is END_OF_TURN on the Lich, so **Muscle += player's `last_roll` after each of his turns from turn 2 on** — and `Global.last_roll` is the *face of the last die you rolled*, spent or not, only reset between fights. Uncapped, cumulative. (Also: `lich_attack_action_2.gd` (4×3 hits) and `lich_block_action.gd` exist but are **not wired** into `lich_enemy_ai.tscn` — dead content, listed for completeness.)

Damage curves at average last-roll ≈ 4 (d6 mix; higher with Giant/Evil online):

| Enemy turn | 2 | 3 | 4 | 5 | 6 | cumulative |
|---|---|---|---|---|---|---|
| **Base 11 (now)** | 11 | 15 | 19 | 23 | 27 | 68 by t5, **95 by t6** |
| **Base 8 (proposed)** | 8 | 12 | 16 | 20 | 24 | 56 by t5, 80 by t6 |
| Base 9 (fallback) | 9 | 13 | 17 | 21 | 25 | 60 / 85 |
| Dragon Priest (ref) | 13 | 13–16 | 13–16 | 13–16 | 13–16 | ~55–70 |

At base 8 the Lich matches his elite peers through turn ~4 and *still* out-damages everything from turn 5 on — the truck arrives, just with breathing room, and killing him fast stays the correct play. Why 8 and not 9: the 85-HP bump from July already lengthened the fight and therefore silently buffed Absorb's endpoint; −3 base compensates for roughly one extra turn of absorption.

**Act 2 makes this more urgent**: elites take ×1.75 HP (Lich → 149) + 5 starting Muscle, so his act-2 opener is currently 16 ramping past 40 over a 7–9-turn fight — almost certainly the deadliest fight in the game right now. Base 8 opens at 13 there.

Do **not** touch Absorb itself (cap was explicitly rejected 2026-07-04, mechanic is the roster's best). Note the counterplay is now *teachable*: starter Scout 3 lets any player deliberately end their turn on a low scouted face — worth a tooltip/intent hint someday, not a balance change.

---

## 5. New findings (beyond the two reported issues) — RESOLVED 2026-07-14

1. ~~Breach draft-pool regression~~ — **void, Julien confirms he cut it deliberately** ("too situational"). Not re-added.
2. **Event naming spaghetti — FIXED.** The actual wiring was always correct (`event_test.tscn`'s Deonassius content ↔ `event_deonassius.gd`, both +60g/-10hp; `event_test.gd`'s dark-chest logic ↔ `event_more_money_for_hp.tscn`, both 40g/100g-16hp) — my original "text/number mismatch" claim was a misread on my part, there was no numeric bug. The real problem was just the filenames not matching their content, which is genuinely confusing to navigate. Renamed on disk (`git mv`) and updated every `ext_resource path=` that pointed at the old names:
   - `scenes/events/event_test.tscn` → `event_deonassius.tscn`
   - `scenes/events/event_test.tres` → `event_deonassius.tres` (also referenced from `events_stats_pool.tres`)
   - `scenes/events/event_test.gd` → `event_dark_chest.gd` (referenced from `event_more_money_for_hp.tscn`)
   - Left the pre-existing dead orphan `scenes/events/event_more_money_for_hp.gd` alone (confirmed unreferenced by any `.tscn`/`.tres` in the project, a duplicate of `event_deonassius.gd`'s logic that was never wired to anything) — same "leave dead content on disk" convention as everywhere else in this codebase.
3. **Marauder (Machopeur) frequency — FIXED.** Added `group = "marauder"` to all 5 fights that contain him (`tier_0_machopeur`, `tier_1_machopeur_satyr`, `tier_1_machopeur_octopus`, `tier_2_defender_machopeur`, `tier_2_machopeur_octopus`) — same mechanism already proven on the tier-0 `"slimes"` group. Picking any one of these now marks the other four as used for the rest of the run, capping Marauder to exactly one appearance per run (down from up to 5). Tier 1 and tier 2 both still have 7 non-Marauder fights left in their pools, so no starvation risk.
4. **`global.gd: gold = 7575`** — fixed to `75` for hygiene (was already harmless at runtime via `reset_run_state()`, but misleading to read).
5. **Watch-list after the trims** (no action now): Overflow Valve (waste-elimination relic) plus Crescendo/Tsunami/Momentum are *long-fight* scalers — shorter fights auto-nerf them slightly, which is fine. Second Wind is the main in-combat sustain; if the D bumps make it feel mandatory, that's the card to look at, not the enemies. Elites dying in 3–4 turns for good decks: acceptable while reports stay positive. Lava Hound's damage bump (skipped, see §4b) is the one open item if he still reads soft after his HP trim.
6. **Act-2 propagation is a feature here**: all trims flow through `ACT2_HP_MULT` (act-2 tier 0 = act-1 tier-1 pool ×1.55, etc.), so act 2 gets the same relief without touching its tables. The Lich base-damage cut is the single biggest act-2 improvement in this plan.

---

## 6. Post-change playtest checklist

- [ ] Tier-1 pair fight with a damage-poor deck: ≤5–6 turns now? Still loses 8–15 HP?
- [ ] Plant+Goblin (the 50-EHP outlier) and Lurker+Crab: no longer read as walls?
- [ ] Goblin+Oculus turn-1 (14 dmg) survivable-if-unblocked at floor-4 HP? (should be ~25% of HP — fine, but verify feel)
- [ ] Lich at floors 6–10, mid deck: 20–30% HP cost, kill by turn 5–6? Does he still *threaten* the truck?
- [ ] Act-2 Lich: hard but no longer a near-certain death?
- [ ] Tier-2 comps post-trim: still 12–22 HP lost (the "reach the campfire" feeling), not bloodless?
- [ ] Deonassius/dark-chest events still trigger correctly under their new filenames?
- [ ] Marauder capped to one appearance per run in practice?
- [ ] Lava Hound: does he need his damage bump after all, now that HP is trimmed?

*Method note: enemy data from `enemies/**/*.tres`/`.gd` + `battles/*.tscn` node counts + `battle_stats_pool.tres`; player model = July 4 D/P framework with P bands re-estimated for Scout-starter/upgrades/relics/events. Fight-length predictions calibrated against Julien's 2026-07-14 felt report (safe-but-long hallways ✓, Lich truck ✓).*
