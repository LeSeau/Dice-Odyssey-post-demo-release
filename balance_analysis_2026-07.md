# Dice Odyssey — Combat Balance Analysis & Rebalance Plan (2026-07-04)

**Status: ALL 5 IMPLEMENTATION STEPS DONE (2026-07-04, same day as the analysis).** This doc remains the single source of truth for the balance work — §1–§3 are the original code-verified analysis, §4–§8 record what was approved/rejected/implemented, and §9 has the playtest findings + fixes from testing the changes. Next step is further playtesting (tier 2 / elites / boss numbers haven't been played yet) — read §9 and the implementation checkmarks in §6 before assuming anything still needs doing.

Companion doc: `card_pool_analysis.md` (card pool audit, 2026-06-24).

---

## 1. Verified game data (code ground truth as of 2026-07-04)

### Player
- **66 max HP** (`characters/warrior/warrior.tres` — NOT the 70 that older CLAUDE.md versions claimed).
- Dice: **2 Blue + 1 Red**; starting relic **Dice Bag** (`relics/coupons.tres`): +1 Blue on first turn of each fight → turn 1 has 4 dice, turns 2+ have 3.
- **5-card hand, discarded at end of each turn** (STS-style). Block resets to 0 each turn (`player_handler.gd::start_turn`). Power resets between turns (barring explicit card effects like `starting_power_next_turn`).
- **TRUE starter deck (11 cards): 4× Strike (Deal X), 4× Block (Block X), Low Blow (MAX 3: Deal X3), Reinforce (MAX 12: +1 Power), Recombobulate (Refuel).**
  - ⚠️ `warrior_starting_deck.tres` currently ALSO contains **Dice Slap and Calculations — these are Julien's TEST inserts, not real starter cards**. The .tres has 11 entries but with 2 Strikes swapped out for the test cards. Restore to 4S/4B/LB/Reinforce/Recombobulate when touching it.
- ⚠️ `global.gd: gold = 7575` — **testing-mode leftover. Real starting gold = 75.**

### Run structure (`scenes/map/map_generator.gd`, `scenes/run/run.gd`)
- **15 floors × 7 columns.** Floor 1 (row 0): forced tier-0 monster. **Floor 8 (row 7): guaranteed treasure (relic).** **Floor 14 (row 13): guaranteed campfire.** Floor 15: boss.
- Random room weights: Monster 5.5, Event 3.0, Campfire 1.5, Elite 1.0, Shop 0.8 (total 11.8). Constraints: no elite/campfire before floor 6 (row 5), no campfire on row 12, no consecutive same-type shop/elite/campfire.
- **Events: 10% chance to be a fight** (`EVENT_FIGHT_CHANCE`). Notable events: relic for 50g or 8 HP, heal fountain (~16), card add/remove, gold gambles, Dice Bag→Dice Chip trade.
- Typical path: ~2 tier-0 fights, ~5 hallway fights, ~0.9 elite (steerable), ~3 events, ~1–2 random campfires + guaranteed one, ~0.75 shop, 1 treasure, boss.
- **Battle tier selection: `run.gd::_get_tier_for_room()` is authoritative** (it overwrites whatever map_generator pre-assigned): BOSS→4, ELITE→3, row>2→**1**, else 0. **There is currently NO tier 2 at runtime** (see bugs). map_generator separately requests tier 2 for rows>8 and for the boss room — dead code paths, papered over by run.gd.
- Battle pool: `battles/battle_stats_pool.tres` (25 entries). No-repeat logic per tier exists and works.

### Economy
- Fight gold: T0 20–30, T1 30–40, elite 45–60, boss 80–100. Pre-boss total income ≈ 75 + 200–260.
- Shop: cards 30–80g, relics 120–170g, dice 150 (Green) → 270 (Magma), ×1.35 per repeat purchase of same type. **No card removal in shop** (events only). Player buys ~1–2 dice OR ~1 relic + cards per run.
- Campfire: **+22 HP flat** (`campfire.gd`), heal-only (no upgrade option yet — Julien wants card upgrades eventually, big work, later).
- Rewards: every fight = gold + 1 card pick (of 3, normal/support weighted); **elite = +1 relic** (`run.gd::_on_battle_won`); treasure floor = relic from `treasure_relic_pool.tres` (16 relics).

### Enemy roster (all code-verified: HP from .tres, patterns from AI .tscn + action .gd)

**AI picker logic** (`enemy_action_picker.gd`): CONDITIONAL actions checked first in tree order (first performable wins); else weighted random among CHANCE_BASED (each also checks `is_performable`); else fallback = first performable chance-based; else `get_child(0)`. Enemy block resets at the start of its own turn.

| Enemy | HP | Verified behavior | Native mechanic |
|---|---|---|---|
| Satyr | 6 | 50/50: 3 dmg / 2 dmg + Weak 1 | — |
| Bigger Satyr | 17 | Turn 0: 4 dmg + Weak 2 (opener). Then 67%: 4+Weak 2 (max 2×) / 33%: 6 | Weak spam |
| Octopus | 7 | 50/50: 3 dmg / 2 dmg + Ink 1 | Ink (hides power display) |
| Bigger Octopus | 16 | 50/50: 7 dmg / 4 dmg + Ink 2 | |
| Crab ("Skeleton") | 25 | 45%: 6 / 18%: 6 ("big", not 2× in a row) / 36%: block 6 + Muscle 1 | Block wall. **Unused 12-dmg attack exists** (`attack_action_2.gd`, not wired in AI) |
| Plant | 35 | Strict cycle: 4 → +5 Muscle → 9 → 9 → +5 → 14… | Ramp (~+5 per 3 turns) |
| Machopeur | 31 | Turn 0: True Strength 2 (=+2 Muscle EVERY turn) → 4, 6, 8, 10… | Hard ramp. **Unused block-4+Muscle-2 action in folder, not in AI** |
| Chimera | 40 | Crab-copy AI (attack 6 / block 6). **Not in any pooled fight** | dead content |
| Minotaur | 10 | flat 7. Only in out-of-pool fight | dead content |
| Goblin | 25 | **BUG: flat 7/turn forever.** Always-true CONDITIONAL attack is first child → attack2 (6, after attack) and Unlucky-debuff action (5 dmg + Unlucky 1) unreachable | intended: Unlucky harasser |
| Oculus | 22 | Cycle (works by accident, see bugs): 6 → +3 Muscle → 9 → 9 → +3 → 12… + **Parasite** (native aura: player generating >15 power in one turn → +3 Muscle, once/turn) | Parasite = anti-overbank |
| Temple Defender | 38 | Strict cycle: 10 → 5 → block 5 + Muscle 1 → repeat | Readable spike cycle |
| Lurker | 40 | **Flux aura (initial status): player cannot bank two consecutive rolls** (each roll must be spent before re-rolling). Cycle: 9 → block+Muscle 2 → 9 → … | Flux = anti-bank |
| Sigil Slug | 42 | Cycle: 10 → 10 → block 5 + Muscle 2. **Sigil (native, on itself): number 1–6, re-randomized on its attacks; if player's banked power == number → player GAINS +1 Blue die** | positive gimmick |
| Medusa | 50 | Weighted: 12 + Weak 2 (5/15, max 2×) / **15** (6/15, max 2×) / block 9 + Muscle 3 (4/15, not turn 0, not 2×) → ~10.4 DPT | Highest hallway DPT in game |
| Hound | 42 | Turn 0: 6. Then thirds: 11 (max 1× consec) / 6 (misnamed "double", single hit) / **Exposed 3 once per fight** (**BUG: once per app session**, flag never resets) | Exposed window |
| Vortex | 45 | Turn 0: **Chaos** (whole fight: every player roll → discard 1 random card, draw 1). Then strict alternation 12 / block 5 + Muscle 3 (works via fallback — weights are 0, see bugs) | Chaos = hand churn |
| Dragonpriest (elite) | 60 | Turn 0: Canalize (if player ever banks >9 power → +3 Muscle, ONCE). Then **13/turn flat**. The "attacks only if you blocked" condition is spaghetti (reads `Global.has_blocked_last_turn`, which only Crab's block sets) — **Julien: never a real feature, delete the concept** | Canalize = anti-bank (weak as once-only) |
| Lich (elite) | 60 | Turn 0: **Absorb** → every enemy turn, gains Muscle = player's LAST ROLL (except turn 1). Then 11/turn | **Best design in the roster** — punishes ending turn on a high roll, counterplay = end low/spent |
| Gargantua (elite) | 60 | **Greedy aura (initial status): every 6th die the player rolls in the fight → +1 Muscle.** Pattern: 11 → 11 → Exposed 3 (once, **same session-flag bug as Hound**) → 11/turn | Greedy = anti-roll-spam |
| Leviathan (BOSS) | 85 | Weighted 5/5/4 (each max 2×/1×): **18 + Ink 2** / **15 + Weak 2** / block 8 + **Muscle 4** → ~11.8 DPT ramping to 20+ by turn 5–6 | Info denial + roll tax + ramp |

### Status semantics (verified in `statuses/*.gd`)
- **Weak N**: next roll −N (consumed on roll). Directly shrinks P — strongest common debuff under the allocation model.
- **Ink N**: hides the power number for N card plays. Info denial only.
- **Exposed N**: +50% damage taken, N turns.
- **Unlucky N**: next roll forced to minimum face.
- **Chaos**: on every roll, discard 1 random card + draw 1. Currently never expires (can_expire=false) → whole fight.
- **Muscle N** = Strength (flat +N damage). **True Strength N** = gain N Muscle every turn.
- **Canalize / Absorb / Greedy / Parasite / Flux / Sigil**: unique per-enemy mechanics, see table above.

### Fight compositions — active pool (`battle_stats_pool.tres`)
- **Tier 0 (9):** Crab solo • Plant solo • Machopeur solo • Octopus×3 (7/7/16) • Satyrs×3 (6/6/17) • Oct+2Satyrs • 2Oct+Satyr • Satyr+2Oct(B) • 2Satyrs+Oct(B). All ~25–35 total HP; 3-packs burst ~9–11 dmg on turn 1 then decay.
- **"Tier 1" (12, actually floors 4–13):** Goblin+Oculus • Defender • Sigil Slug • Lurker • Plant+Octopus(B) • Machopeur+Satyr(B) • Plant+Goblin • 2Oct+2Satyrs (4 bodies, 46 HP total, ~14 turn-1 burst + Weak + Ink) • **Medusa • Hound • Vortex • Plant+Crab** (these four are named tier_2_* but labeled battle_tier=1).
- **Elites (3):** Dragonpriest, Lich, Gargantua. **Boss:** Leviathan.
- **Built but UNREACHABLE (exist on disk, not in pool or mislabeled):** tier_2_defender_machopeur (battle_tier=2, not selectable), tier_2_machopeur_octopus×2 (same), tier_2_defender_satyr (in no pool), tier_0_chimera, tier_0 bigger-pair variants (bigger_satyrs_2, bigger_octopus_2, bigger_satyr_octopus, machopeur_satyr, crab_satyr), tier_1_crab_satyr, tier_1_lurker_crab, tier_1_machopeur_octopus, tier_1_bat_crab, tier_1_bats3. Several carry leftover weight=10 values.

---

## 2. Bug list (priority-ordered; fix BEFORE tuning — several silently flatten intended design)

1. **`global.gd: gold = 7575`** — testing leftover, ship-blocker. → 75.
2. **Goblin kit dead** (`enemies/goblin/goblin_enemy_ai.tscn` + actions): always-performable CONDITIONAL attack is first child → picker returns it every turn. Fix: make the basic attack CHANCE_BASED (or make its is_performable exclude last_action=="goblin_attack") so attack2 + Unlucky debuff can fire.
3. **Starter deck .tres contains test cards** (Dice Slap, Calculations) — restore 4 Strikes before any balance testing, results are skewed otherwise.
4. **Tier-2 data mess**: `run.gd::_get_tier_for_room` maps rows>2 all to tier 1; tier_2_medusa/hound/vortex/plant_crab/defender_satyr have battle_tier=1; real tier-2 files unreachable; map_generator's tier-2 & boss-room requests are dead code. (Becomes the tier-restructure work item, §6.)
5. **Hound & Gargantua Exposed once per SESSION** (`Global.hound_debuff_attack_done` / `gargantua_debuff_attack_done` never reset — not on battle start, not on run start). Reset both in `_on_battle_won`/run start. (Julien: known, lower priority since sessions currently restart often.)
6. **Dragonpriest spaghetti**: the "or has_blocked_last_turn" condition + `Global.has_blocked_last_turn` (only set by Crab's block action!) — Julien confirms never a designed feature. Simplify to plain attack. ~~Canalize rework~~ — **rejected by Julien (2026-07-04), Canalize mechanic itself stays untouched.**
7. **Vortex chance weights = 0** — alternation only works via fallback ordering; set real weights or make the cycle explicitly conditional so a scene edit can't silently break it.
8. **Oculus buff condition** copied from Plant (`last_action != "plant_attack"` — always true). Current cycle is fine in practice; make the condition its own ids for robustness.
9. Cosmetic/dead: satyr/octopus/vortex debuff scripts declare `exposed_duration` never applied (delete vars, check intent icons don't over-promise); Hound "double attack" is a single 6 (rename or make it actually 2×); `machopeur_attack_action_2.gd`, crab `attack_action_2.gd` (12 dmg), octopus chaos attack ("NOT USED" node) are unwired content worth rescuing (§6).
10. Docs drift: CLAUDE.md says 70 HP / "4 Strike 4 Defend + Diceslap" starter — code says 66 HP, and the .tres is currently the test variant.

**Found and fixed during step-3 playtesting (2026-07-04, not in the original code-audit pass):**
11. **Enemy intent could silently desync from what actually executed.** `Enemy.set_enemy_stats()` wired `stats.stats_changed` to `update_action()`, which can override the already-decided `current_action` with a freshly-qualifying CONDITIONAL. `do_turn()`'s block reset (`stats.block = 0`) fires that signal right before the cached action executes — by which point `Global.fight_turn` has already been bumped by `end_turn()` (fires the instant the player clicks End Turn, before the enemy turn runs). Caught live via the new Crab spike firing a round earlier than its own intent showed. Fixed: rewired `stats_changed` to `update_intent` (safe, display-only) instead; simplified `update_action()` since its override branch is now unreachable. No currently-active AI relied on the old wiring (only the unwired `crab_mega_block_action.gd` reads its own HP/block in a condition).
12. **Enemy attacks didn't apply their own Strength/Muscle to actual damage, only to the displayed intent number.** Systemic — 19 of ~39 enemy attack scripts computed `modifiers.get_modified_value(base_damage, DMG_DEALT)` in `update_intent_text()` but set `damage_effect.amount = damage` (raw) in `perform_action()`. Affected: all of Satyr/Bigger Satyr, all of Octopus/Bigger Octopus, all of Crab (including the new spike), all of Vortex, Minotaur, and one of Medusa's three attacks (her 15-dmg hit). Fixed all 19 to match the already-correct pattern used elsewhere (Dragonpriest, Gargantua, Goblin, Hound, Leviathan, Lich, Lurker, Machopeur, Oculus, Plant, Sigil Slug, Temple Defender). Confirmed no double-application risk: the player's own `DMG_TAKEN` modifier (Exposed etc.) is applied separately inside `Player.take_damage()`.

---

## 3. The player-power model (calibrated against Julien's felt experience)

### Allocation framework
Each turn the player converts dice rolls into a power budget **P** and splits it between damage and block via X-converter cards. Enemy intents are visible → block allocation can be exact. Block costs damage 1:1 (Julien: "blocking usually reduces your damage output" — this IS the core tradeoff).

**Key ratio: D/P** (enemy damage per turn ÷ player power per turn):
- **D/P < 0.4** → bloodless: block fully AND still race. HP loss 0–3. Fight is a time tax.
- **0.4–0.7** → **the fun zone**: real allocation decisions, partial blocks, calculated chip.
- **> 0.7** → race-or-die: blocking starves the kill. Good as a momentary spike or swarm opener, bad as steady state.

Calibration: Crab (D 4.7, P 11 → 0.43, EHP ~28) predicts 3–4 turns and 0–3 HP lost — **matches Julien's reported experience exactly.**

### P by run stage (with TRUE starter deck)
| Stage | P (effective, damage-side) | Notes |
|---|---|---|
| Floors 1–3 | **~11** (turn 1 ~14 via Dice Bag) | Low Blow = skill card: a rolled 1–3 becomes 3–9 dmg. Reinforce +1 smoothing. |
| Floors 4–8 | **~16–19** | 3–5 drafts; first multiplier (Flurry/Smash/etc.) makes damage-side power count ~1.5–2× |
| Floors 9–13 | **~22–26** | treasure relic + maybe +1 die; Scout/Focus consistency online |
| Pre-boss | **~25–30, burst 40–60** | Geomancy/Boost/Eclipse setup turns into Doomsday/Smash/Bullseye payoffs |

### Hand-composition constraint (Julien's correction — do not drop this from the model)
Deck 11, hand 5: **P(≤1 Strike in hand) ≈ 35%** (P(0)=4.5%, P(1)=30.3%); symmetric for Blocks. So ~⅓ of starter turns, converters don't match dice packets — power gets dumped into off-converters or wasted. Adds variance to effective P, raises the real value of Recombobulate/draw, and creates decisions beyond the pure ratio. (P(≥1 Block in hand) ≈ 95% → spike-response is almost always *possible*, the question is affordability.)

### Where HP loss actually comes from (not average DPT!)
1. **Swarm turn-1 bursts** (3–4 bodies, ~10–14 dmg before the player can thin them) — D/P ~0.9 momentarily, then decays. Good pattern (STS louse-pack), keep.
2. **Ramps** that outpace a blocking player (Machopeur, Plant) — block too long and you lose the race.
3. **Spike turns** above ~0.7×P (Medusa 15, Defender 10, Leviathan 18).
4. **Taxes**: Weak directly shrinks P; Chaos/Ink corrupt allocation; Greedy/Absorb/Parasite/Canalize punish greed.
5. Elites/boss (sustained 0.5–0.65 ratios + taxes).

Everything else is bloodless for a competent blocker. **Corollary: enemies whose turn-0 is a buff (Machopeur, Lich, Dragonpriest, Vortex) hand the player a free race turn** — deliberate fight-shortener, keep in mind when adding HP.

### The core problem, sharpened
Ratios are mostly healthy through floor ~8. After that, the single hallway pool means D stays 5–10.4 while P doubles → **floors 9–13 are bloodless AND 2-turn kills** — no block equity, no attrition, no clutch "reach the campfire" moments. Elites die in ~3 turns (60 HP vs 20-26 P), so the relic reward makes them strictly correct. **Boss ratio is actually fine — its only problem is 85 EHP vs 40–60 burst** (dies in 2–4 turns; guaranteed floor-14 campfire tops the player off first).

### STS anchors (Julien's gold standard)
STS act-1: hallway fights 4–8 player turns, ~12% HP cost avg; elites 25–30%; boss 30–40%; two hallway pools per act (easy floors 1–3, hard 4–16). Note StS gets away with ONE hard pool because player power grows only ~+50% per act and Act 2 resets the curve — Dice Odyssey's player roughly doubles within the single act, hence the dead zone. **If/when an Act 2 exists, collapsing back toward fewer pools per act becomes right again.**

---

## 4. Design principles AGREED with Julien (2026-07-04 discussion)

1. **Fight-length targets** (approved): tier 0 **3–4 turns (unchanged!)**, tier 1 (fl. 4–8) **3–5**, tier 2 (fl. 9–13) **4–6**, elites **5–7**, boss **6–9**.
2. **HP increases must be back-loaded** — Julien's top concern is early fights dragging under bad dice RNG (roll-before-act variance, no Scout/refuel/extra dice yet). Tier 0 +0–10% max; the real increases go to floors 9+, elites, boss, where consistency tools exist.
3. **Difficulty via spikes and taxes, not average-DPT inflation.** Spikes = telegraphed 2× turns worth blocking (gives Block cards draft equity). Taxes = mechanics that scale WITH the player (Absorb charges the player's own roll — self-balancing: strong turns pay more, weak-RNG turns pay less; this family sidesteps the drag concern entirely).
4. **Spike counterplay is same-turn allocation** (hands discard each turn — no holding Block cards). The intent telegraphs; the player answers with this turn's power. Consequence: spikes should be survivable-if-unblocked (~35–45% current HP), not lethal, since a bad roll on the spike turn must not be a death sentence — at least below elite level.
5. **NO copy-pasting signature statuses across enemies** (Julien explicitly: redundant/lazy). Parasite/Greedy/Canalize/Absorb/Flux/Sigil/Chaos stay native to their owners. Common debuffs (Weak/Exposed/Ink/Unlucky) ARE shared vocabulary and fine. Tier-2 fight identity comes from **composition dynamics** (pairing native kits that interact) or **new native mechanics**, not borrowed auras.
6. **Ramps as soft-enrage**: any fight receiving +HP should carry an implicit timer (most already do) so longer fights accelerate rather than flatten.
7. Keep tier-0 patterns simple/flat — teaching tier (Julien confirmed).
8. Campfire upgrade option: wanted long-term (card upgrades), explicitly deferred — big work.

---

## 5. AGREED: tier restructure

**Three buckets, cut at the floor-8 treasure** ("the relic marks the deeper dungeon"):
- **Tier 0 = floors 1–3** (rows 0–2) — unchanged rows.
- **Tier 1 = floors 4–8** (rows 3–7).
- **Tier 2 = floors 9–13** (rows 8–12).

Implementation: adjust thresholds in `run.gd::_get_tier_for_room()` (currently `row > 2 → 1` twice; make `row > 7 → 2`, `row > 2 → 1`), relabel `battle_tier` in the .tres files per the pools below, add missing fights to `battle_stats_pool.tres`, clean leftover weight=10 values. map_generator's own tier requests could be aligned too (or left, since run.gd overrides — but cleaner to fix).

**STATUS: DONE 2026-07-04.** Every fight named in the pool assignments below already had a working `.tres`/`.tscn` — nothing had to be built from scratch, only relabeled/added. Left map_generator's own (dead/overridden) tier requests untouched, out of scope. Final pool: 34 entries (was 25) — tier 0: 11, tier 1: 11, tier 2: 8, elites: 3, boss: 1.
- `run.gd::_get_tier_for_room()`: `row > 7 → 2`, `row > 2 → 1`, else 0 (done).
- Relabeled `battle_tier`: `tier_0_machopeur` 0→1 (also bumped its gold_reward 20-30→30-40 to match its new tier-1 siblings, since that field doesn't auto-follow the tier label), `tier_1_octopus_2_satyrs_2` 1→2, `tier_2_hound`/`tier_2_medusa`/`tier_2_plant_crab`/`tier_2_vortex` 1→2, `tier_2_defender_satyr` 1→2.
- Added to pool (already correctly tiered, just never referenced): `tier_0_bigger_octopus_2`, `tier_0_bigger_satyrs_2`, `tier_0_bigger_satyrs_octopus`, `tier_1_crab_satyr`, `tier_1_lurker_crab`, `tier_1_machopeur_octopus`, `tier_2_defender_machopeur`, `tier_2_machopeur_octopus`, `tier_2_defender_satyr`.
- Left dead/unused on disk (not part of the agreed plan): `tier_0_chimera` (Julien: no art, don't add), `tier_0_machopeur_satyr` (regular-satyr variant, redundant with the bigger-satyr one already in tier 1), `tier_0_crab_satyr.tscn` (no `.tres`, exact duplicate of `tier_1_crab_satyr`), `tier_1_bat_crab`/`tier_1_bats3` (misnamed leftovers using Crab/Minotaur, not Bat).

### Agreed pool assignments — IMPLEMENTED 2026-07-04 (see status note below)
**Tier 0 (fl. 1–3):** Crab solo (spike wired in, see §6) • Satyrs×3 • Octopus×3 • the 4 mixed 3-packs • bigger-pair fights (`tier_0_bigger_octopus_2`, `tier_0_bigger_satyrs_2`, `tier_0_bigger_satyrs_octopus`, added to pool) • ~~Chimera solo~~ **excluded — Julien: no art yet, old/unfinished enemy, do not add** • Plant solo (ramp softened to +3/cycle, not yet applied — step 3).

**Tier 1 (fl. 4–8):** Goblin+Oculus (goblin FIXED) • Defender solo • Sigil Slug • Lurker (Flux) • Plant+Octopus • Machopeur+B.Satyr • Plant+Goblin • rescue Crab+Satyr / Lurker+Crab / Machopeur+Octopus from unused files. (~10 entries)

~~Machopeur solo promoted from tier 0~~ — **REVERTED 2026-07-04.** Julien's counter-argument: Machopeur's kit (turn-0 buff → every-turn Muscle ramp) is structurally the same as STS's Cultist, which stays an early/cheap enemy specifically to teach "kill ramps fast" while stakes are low and the player still has their full starter deck — moving it later doesn't teach anything new once Plant has already taught the lesson, and it thins tier 0 down to a single ramp archetype right when the lesson matters most. Machopeur solo stays in **tier 0** at its original 31 HP / 20-30g reward (not softened like Plant — no HP change agreed for it).

**Tier 2 (fl. 9–13):** Medusa • Hound (flag fixed) • Vortex • Plant+Crab • **Defender+Satyr** (unused → add) • **Defender+Machopeur** (unreachable → add; "race the ramp while respecting the spike cycle" — composition dynamics, no new mechanics needed) • **Machopeur+2×Octopus** (unreachable → add) • 2Oct+2Satyrs promoted from tier 1 (turn-1 burst plays better vs a 22-P player). (~8 entries)

---

## 6. AGREED: numeric retune (starting values for playtesting, not gospel)

### Tier 0 — nearly untouched (protect early pacing) — DONE 2026-07-04
| Enemy | HP now → proposed | Other |
|---|---|---|
| Satyr / Octopus | 6–7 → **8** | dmg unchanged |
| Bigger variants | 16–17 → **18** | |
| Crab | 25 → **26** | **wire the unused 12-dmg attack as a telegraphed every-4th-turn spike** — tier 0's "learn to block" teacher |
| Plant | 35 → **32**, ramp +5 → **+3**/cycle | tier-0 teacher version |
| Chimera | 40 → **~30** | enters pool as flat solo — **excluded for now, no art (see §5 status note)** |
| Machopeur | 31 (unchanged) | **stays in tier 0** — reverted from the tier-1 promotion, see §5 |

Expected: same 3–4 turn fights; solos 0–6 HP lost, swarms 6–12.

Implementation notes: Crab's spike uses `Global.fight_turn % 4 == 3` (fires on the enemy's 4th physical turn, then every 4th after) as a plain CONDITIONAL action — no separate telegraph mechanism needed since intents are already shown one turn ahead by the existing UI, so a deterministic trigger is automatically "telegraphed" for free. Wired via `enemies/crab/attack_action_2.gd` (was dead code) + a new `SpikeAttackAction` node in `crab_enemy_ai.tscn`. Reinforce +1→+2 also done (`reinforce.gd` + `.tres` description).

### Tier 1 (fl. 4–8): solos **44–52 EHP**, pairs **55–65 total**; base D 6–9 + one **13–15 telegraphed spike** per cycle each. **NOT YET APPLIED — see status note.**

**STATUS 2026-07-04: only the aggregate band above exists, no concrete per-enemy numbers were ever agreed for tier 1, unlike tier 0/tier 2 which both got real tables.** Held off implementing rather than inventing numbers.

**The shared-resource blocker described here is now FIXED (2026-07-04, same day).** A full audit found the cross-tier sharing was wider than first flagged — not just Plant/Defender/Machopeur/Bigger-Satyr/Bigger-Octopus, but also plain Satyr and plain Octopus (both got dragged into tier 2 via the promoted 4-body `tier_1_octopus_2_satyrs_2` pack). Full map of every affected enemy and every fight it touched:
- **Crab**: tier0 (`tier_0_crab`), tier1 (`tier_1_crab_satyr`, `tier_1_lurker_crab`), tier2 (`tier_2_plant_crab`)
- **Machopeur**: tier0 (`tier_0_machopeur`), tier1 (`tier_1_machopeur_octopus`, `tier_1_machopeur_satyr`), tier2 (`tier_2_defender_machopeur`, `tier_2_machopeur_octopus`)
- **Plant**: tier0 (`tier_0_plant`), tier1 (`tier_1_plant_goblin`, `tier_1_plant_octopus`), tier2 (`tier_2_plant_crab`)
- **Bigger Satyr**: tier0 (multiple packs), tier1 (`tier_1_machopeur_satyr`), tier2 (`tier_1_octopus_2_satyrs_2` [relabeled 2], `tier_2_defender_satyr`)
- **Bigger Octopus**: tier0 (multiple packs), tier1 (`tier_1_machopeur_octopus`, `tier_1_plant_octopus`), tier2 (`tier_1_octopus_2_satyrs_2`, `tier_2_machopeur_octopus`)
- **Satyr (small)**: tier0 (multiple packs), tier1 (`tier_1_crab_satyr`), tier2 (`tier_1_octopus_2_satyrs_2`)
- **Octopus (small)**: tier0 (multiple packs), tier2 (`tier_1_octopus_2_satyrs_2`) — skips tier 1
- **Defender**: tier1 (`tier_1_defender`), tier2 (`tier_2_defender_machopeur`, `tier_2_defender_satyr`)

For each, kept the enemy's lowest-appearing tier as the original `.tres` (unchanged path/uid, nothing else breaks), and added a `_tier1`/`_tier2` duplicate (same `ai` PackedScene, same `art`, same `enemy_name`, only `max_health` can now diverge) for every higher tier it also appears in — e.g. `plant_enemy.tres` (tier 0, home) + new `plant_enemy_tier1.tres` + `plant_enemy_tier2.tres`. 14 new `.tres` files total, 11 battle `.tscn` files repointed to the correct variant. Verified after the fact: every enemy resource in the active pool now maps to exactly one tier, zero cross-tier sharing left. **All new duplicates currently hold the SAME HP as their source — this was a pure decoupling refactor, no numbers changed.** Tier-1 (and any tier-2 revision) numeric tuning is now safe to do per-enemy without side effects elsewhere, whenever Julien wants to lock in real values.

### Tier 2 (fl. 9–13) — DONE 2026-07-04
| Enemy | HP → proposed | Notes |
|---|---|---|
| Medusa | 50 → **62** ✅ | keep 12/15 — real spikes at this depth |
| Hound | 42 → **55** ✅ | Exposed once per FIGHT (flag fix); Exposed-3 window is the identity |
| Vortex | 45 → **58** ✅ | Chaos + alternation unchanged |
| comps | **+30% totals ✅** (Julien picked the low end) | identity via native-kit interactions (see §4.5) |

**Comp totals applied (uniform 1.3× per-member scaling, so any enemy shared across multiple tier-2 fights gets one consistent number everywhere — verified no conflicts since every tier-2 enemy is already decoupled per-tier)**:
| Fight | Old total | New total | Per-member HP |
|---|---|---|---|
| Plant + Crab | 58 | **76** | Plant 42, Crab 34 |
| Octopus×2+Satyr×2 (4-body, `tier_1_octopus_2_satyrs_2`) | 52 | **66** | small Octopus 10, big Octopus 23, big Satyr 23, small Satyr 10 |
| Machopeur + 2×Octopus | 67 | **86** | Machopeur 40, Octopus 23 each |
| Defender + Machopeur | 69 | **89** | Defender 49, Machopeur 40 |
| Defender + 2×Satyr | 74 | **95** | Defender 49, Satyr 23 each |
| Lurker + Crab | 66 | **86** | Lurker 52, Crab 34 |

Target: 4–6 turns, 12–22 HP lost per fight — where "please let me reach a campfire" lives.

### Elites: **85–95 HP — DONE 2026-07-04**
- **Dragonpriest 60 → 90 ✅**. Canalize mechanic stays exactly as-is (guaranteed turn-0 trigger, once-ever +3 Muscle, not a standing rule) — **Julien rejected the "standing rule" rework on 2026-07-04, keep current behavior.** Confirmed in code the same day: `consume_stack()` re-arms (`threshold_triggered = false`) whenever power drops back to ≤9, so Canalize genuinely CAN fire more than once per fight (even multiple times in one turn) if power dips and climbs back above 9 — but never re-fires while continuously sitting above 9 in one unbroken streak. Matches Julien's expectation exactly, no fix needed.
- **Lich 60 → 85 ✅**. Absorb unchanged (best design in the game), no per-turn cap — Julien rejected the Giant-dice cap on 2026-07-04, keep current uncapped behavior.
- **Gargantua 60 → 95 ✅**. Greedy untouched, flag fix already done in step 1.
- Target: 25–35% HP cost → elite-vs-relic becomes a real decision.

### Boss: **Leviathan 85 → 140 ✅ — DONE 2026-07-04**
Kit unchanged + anti-burst valve chosen: **Ink duration 2→3** on his Ink-inflicting attack (`enemies/leviathan/1.gd::ink_duration`), not the Absorb-flavored Muscle option (kept clear of "his own kit only" per the no-copying preference) or the flat passive block option. Target: 6–9 turns, 30–45% HP cost, so the guaranteed campfire reads as necessary.

### Player-side (light touch)
- **Reinforce +1 → +2: AGREED to try, Julien enthusiastic.** Rationale: a rolled 1 becomes a guaranteed max Low Blow (1→3 → 9 dmg) — floor-raiser for exactly the early-RNG-nightmare concern; general smoothing doubles. Documented trade-offs: the 2→3 Low Blow line dies (2+2=4 > MAX 3; play LB directly at 2 for 6 instead), and **+2 preserves parity** — +1 could step to ANY number (universal EXACT/EVEN/ODD fixer, e.g. 12→13 Doomsday), +2 skips every other value (11→13 yes, 12→13 no). Julien originally chose +1 for parity-fixing but has since cut most parity requirements → +2 likely right now.
- Do NOT nerf the jackpots (Doomsday/Duo/Unity/Bullseye EXACT lines) — the EHP retune already taxes them (two payoff turns needed instead of one).
- Watch-list, no action: Slash (6 free dmg, celestial, no requirement) strong in tier 0; Emergency (10 block + end turn) gets better as fights lengthen — fine, block should get better.

---

## 7. Ideas discussed, NOT agreed — future material only

- **New native mechanics for variety (sketches only, unvetted):** "gains Block equal to player's unspent power at end of turn" (anti-waste tax — new hook reading `Global.roll_value` at turn end) • "retaliates 3–4 when player plays their 3rd card in a turn" (anti-spam, hook: `cards_played_this_turn`) • "heals 3 if not attacked this turn" (anti-turtle). Each would be ONE new enemy's identity, per the no-copying principle.
- **Satyr Shaman** (new action on existing art: buffs ALLIES +2 Muscle/turn instead of attacking) — would create the missing **target-priority** archetype. Roster currently has no kill-the-support-first fight.
- **Countdown/timer enemy** (e.g., Dragonpriest-flavored "channels a 25-dmg ritual resolving turn 4 unless killed") — the missing pure-aggression check (STS Lagavulin role). Pacing archetype coverage after retune: race ✓ (ramps), attrition ✓ (cycles), block-efficiency ✓ (spikes), setup-denial ✓ (Ink/Chaos), anti-bank ✓ (tax family), target-priority ✗ (needs Shaman), timer ✗ (needs countdown).
- **Campfire second option** (upgrade/remove) — wanted, deferred.
- Tier-1-vs-tier-2 alternative rejected for now: staying single-pool StS-style would require compressing pool variance (Medusa down, weakest up) and accepting bloodless floors 9–13 until an Act 2 exists.

## 8. Implementation order for next session (agreed shape)

1. **Bug pass**: gold 75, starter deck .tres restore, goblin picker, vortex weights, oculus condition ids, dragonpriest condition removal, hound/gargantua flag resets, dead exposed vars. (Small, zero design risk.)
2. **Tier restructure**: run.gd thresholds + .tres relabels + pool additions (§5).
3. **Tier 0/1 micro-bumps + Crab spike wiring + Reinforce +2** (§6).
4. **Playtest checkpoint — IN PROGRESS 2026-07-04.** Julien ran a full test run through tier 1 + first elites. See §9 below for findings (bugs fixed same day + open balance questions still needing a call before step 5).
5. **DONE 2026-07-04.** Tier-2 numbers, elite HP bumps (Canalize/Absorb mechanics untouched per Julien), boss EHP + valve. See §9 addendum below for exact numbers applied.
6. Later: new archetypes (§7), campfire option, Act-2-era pool rethink.

---

## 9. Playtest findings (2026-07-04, first full run through tier 1 + Lich/Dragonpriest)

### Bugs found and fixed same day
- **Ink stuck active across fights, sometimes for the rest of the run.** `Global.ink_active` (read by `Card.is_inked()` for the "?" power display, and by `hand.gd::_get_glow_state()` to force every card to the unplayable dim) was never reset between battles. Fixed: `battle.gd::start_battle()` now resets it to `false` alongside the other per-fight flags.
- **Lurker overlapped the player's hand / obscured its own status icons in the Lurker+Crab fight.** Its node in `tier_1_lurker_crab.tscn` had no `scale`/`width`/`height` override (copy-pasted straight from its solo fight, unlike Crab in the same scene which was properly sized down). Set to `scale=0.75`, `width/height=280` to match how every other paired enemy in the pool is set up. **Not visually re-verified (no Godot runtime access) — please confirm it actually looks right.**
- **Relic tooltips inconsistently cased vs. cards.** Cards always write keywords capitalized ("Charge 1", "Gain 2 Strength"); 6 relic tooltips didn't: Blood Sword ("red Dice"→"Red Dice"), Fuel-o-meter ("refuel"/"strength"), Runic Bones ("charge"/"block"), Sledgehammer ("strength"), Volcanic Rock ("charge"), Crown ("charges"). All fixed. Scoped to relics only per what was asked — cards weren't swept (spot-checked a couple, they're already fine).
- **Status icon spacing was inconsistent row-to-row.** `status_ui.gd` reported a different `custom_minimum_size` depending on whether a status shows a Duration/Stacks number badge (48×39) or not (30×30, icon only) — `GridContainer` sized cells off that, so mixed rows got uneven gaps. Fixed: always report the icon's own 30×30 footprint; the number badge overlays the icon corner rather than inflating the cell.

### Balance signal — needs a decision before tier-1 numbers get locked in
- **Lurker+Crab (tier 1, gateway fight) felt like a wall relative to tier 0**: ~66 combined EHP, Flux (anti-bank) from turn 1, ~15 dmg turn-1 burst. Julien: "much much harder than tier 0 fights... I can tell right away I'm gonna lose a ton of HP." He won but called it lucky/close (~15 HP lost). This is exactly the kind of data the deferred tier-1 numeric pass needs — current pool has no "soft landing" fight between tier 0 and this. **Machopeur+Octopus (tier 1) right after, by contrast, felt "MUCH more manageable" / "Good outcome & balance."** So the tier-1 pool likely needs internal difficulty ordering/smoothing, not just a flat retune.
  - **RESOLVED 2026-07-04**: root issue was worse than "hard fight" — tier 1 had both `tier_1_lurker` (solo Flux) and `tier_1_lurker_crab` (the SAME Lurker/Flux plus a Crab bolted on) in the same tier. Julien: *"the main problem is that the same tier had a fight that's literally the same, but harder! This is not good balance."* A strict "same enemy, same tier, just add a body" pairing isn't real variety, it's a padded reskin of the solo fight — no new identity, just more numbers. **Moved `tier_1_lurker_crab` → tier 2** (`battle_tier` 1→2). Since Lurker now spans tier 1 (solo) and tier 2 (this pair), gave it the same per-tier decoupling treatment as the other cross-tier enemies: new `enemies/lurker/lurker_enemy_tier2.tres`, and repointed the Crab in that scene from `crab_enemy_tier1.tres` to the already-existing `crab_enemy_tier2.tres`. Pool is now tier0:12, tier1:9, tier2:9, elites:3, boss:1 — every enemy resource still maps to exactly one tier. **General principle for future pool composition: don't put a solo enemy and "that same enemy + a partner" in the same tier — the pairing needs its own reason to exist (composition dynamics, per §4.5), not just be the harder mode of the solo.**
- **Machopeur is showing up very often** — solo (tier 0), two tier-1 pairs, two tier-2 pairs, PLUS he's eligible via random combat events too (Julien hit a 3-enemy event fight with him mid-run). Julien: "that's starting to be a lot of Machopeur... you can get him 3+ times in a run?" A real variety/identity concern, not paranoia — worth capping his effective pool weight or reconsidering how many of his 5 fight slots stay active.
- **Economy pacing note**: reached 222-228 gold multiple times by mid-run, enough to consider a 2nd escalated dice purchase. Julien flagged this himself as "probably too early, that'd make me insanely strong."
- **Positive signals worth preserving**: real HP attrition finally showing up post-tier-0 (37/66, 50/66 mid-run) and influencing real deck choices (drafted a Block card for the first time all run); Lich and Dragonpriest elites read as genuinely dangerous but fair with good play (lost 4 HP vs Lich with "pretty good luck", said Dragonpriest "was definitely getting dangerous" if not killed on time).

### Design question — RESOLVED 2026-07-04
- **Ink's forced full-dim on every card** was flagged as misleading (cards look unplayable while inked, even though they're mechanically still playable — just power is hidden). Julien's call: while inked, card visuals should be **as neutral as possible** — no signal either way, not even a fake "available" glow. Added a new `CardUI.PlayableGlow.NEUTRAL` state (full brightness, no glow border, distinct from both `NONE`'s dim and `HOT`/`AVAILABLE`'s glow) and wired it into `hand.gd::_get_glow_state()`'s ink branch.

---

*Method note: all enemy numbers extracted from `enemies/*/`.gd/.tscn and battles/*.tscn on 2026-07-04; player math assumes competent intent-reading play; DPT/ratio bands calibrated against Julien's reported table feel (Crab ≈ 0–3 HP lost ✓). The D/P allocation model and hand-constraint hypergeometrics are in §3 — reuse them when evaluating any new enemy or card instead of re-deriving.*
