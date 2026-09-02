# Enemy Balance Baseline — Global Audit (2026-08-16)

**Status: ANALYSIS ONLY — nothing implemented.** This is the global enemy-stats audit Julien asked
for: current state of every reachable fight, the STS2 A0 benchmark read from the actual decompile
(`Desktop\sts2_ref`, full extraction preserved in
[sts2_enemy_dataset_2026-08.md](sts2_enemy_dataset_2026-08.md)), the energy→Power translation
model that connects the two, and per-enemy prescriptions to land the game at an "A0 feel":
pressured enough that block cards, good play, and campfire rests matter — winnable most of the
time when played well.

It builds on (and where noted, **revises**) the active plans in
[enemy_design_analysis_2026-08.md](enemy_design_analysis_2026-08.md) §8/§9 and
[sts2_action_plan_2026-08.md](sts2_action_plan_2026-08.md). Everything here is verified against
code as of 2026-08-16 (stale-doc numbers corrected: Canalize >12/+3, Parasite >15/+2,
Greedy +2 Muscle per 6 dice, Flux blocks ALL re-rolls until Power is spent).

Tags: **[verified]** read from code/decompile · **[inferred]** derived · **[estimate]** judgment.

---

## 1. The translation model — energy ⇄ Power

### 1.1 Turn output is directly comparable

STS2's Necrobinder plays every fight below with **66 HP — our exact pool**. Their turn budget:
3 energy × starter cards (Strike 6 / Defend 5) ≈ **15-18 effect points** per turn at run start,
split across ~3 plays. Ours: dice EVs chained into Power ≈ **11-14 points** at run start
(2 Blue + Red + Dice Bag), split across ~2-3 plays. So at act start, *1 energy ≈ 5.5-6 effect
points ≈ 1.6 dice*, and both games start the player within ~20% of the same turn output against
the same HP pool. **Enemy damage and HP therefore compare almost 1:1 at act-1 start — what
diverges is the growth curve**, which is why we translate *ratios* (DPT as % of player HP,
attrition per fight, fight length in turns, spike % of HP), never raw per-floor numbers.

### 1.2 The player curve — updated for the 2026-08-13 dice reprice

The July P bands were derived under the old price table (Blue/Red 180, exotics 150-270, ×1.4).
The reprice (discovery aisle **115-165 under Blue/Red 170**, escalation ×1.5) moves die #1 from
a late-act-1 luxury to a **first-shop commitment (~floor 5)** — and the cheap aisle holds the
*high-EV* dice (Golem 5.0/roll, Ricochet 4.0 vs Blue 3.5). Die #2's absolute cost is nearly
unchanged (165×1.5 ≈ 248 vs old 180×1.4 ≈ 252). Net effect **[inferred]**:

| Floors | July band | **Post-reprice band** | Why |
|---|---|---|---|
| 1-3 | 11-12 (turn 1 ~14) | **11-12** (loadout spread ~8-15) | unchanged; loadout picker adds variance (Elf ~8 raw → Titan ~15) |
| 4-8 | 17-21 | **18-23** | die #1 lands ~fl 5 instead of ~7-8, and it's often a 4.0-5.0 EV die |
| 9-13 | 25-32 (burst 45-70) | **26-34** | compounding from the earlier die #1; die #2 timing ≈ unchanged |
| Act 2 | 26-30 → 40-45 | **28-32 → 42-47** | same shift carried forward |

Two knock-ons the audit accounts for: **Greedy ticks faster** (more rolls/turn = Gargantua's
clock accelerated ~+33% — already the fastest elite clock), and the July self-criticism ("the
attrition budget got cheaper while per-turn danger stayed flat") **has quietly recurred** — the
reprice handed back ~7-8 HP of act-1 slack. The prescriptions in §4 take it back.

### 1.3 The unified sizing formula

One formula reproduces both games' shipped numbers:

> **EHP_target = T × P × s**  and  **DPT_target ≈ B + A**, where
> T = target fight length (turns) · P = on-curve Power · **s = offense share** (fraction of P
> spent on damage; falls as tiers rise because block demand rises) · B = on-curve block
> allocation ≈ P × (1−s) × 0.85 hand-reliability · A = intended net attrition/turn
> (= attrition target ÷ T).

Validation against what's already shipped and felt right in play **[verified fit]**:

| Tier | T | P | s | EHP formula → | Shipped EHP | B + A → DPT target | Current DPT |
|---|---|---|---|---|---|---|---|
| T0 | 3-4 | 11.5 | 0.70 | 24-32 | 26-36 ✓ | ~3 + 0-1.7 = **4-6** solo | 4.7-8.3 ✓ |
| T1 | 3-5 | 19-21 | 0.60 | 34-52 | 34-50 ✓ | ~7 + 2-3.7 = **9-11** | 6-13.8 (solos low) |
| T2 | 4-6 | 28-31 | 0.50-0.55 | 56-92 | 51-78 ✓ | ~11 + 2.4-4.4 = **13-16** | **8.5-12.3 solos — LOW** |
| Elite | 5-7 | 26-30 | 0.55 | 77-108 | 85-95 ✓ | **13-15 effective** (floor 8-12 + mandatory clock) | reaches it *via* clocks ✓ |
| Boss | 6-9 | 28-34 | 0.55-0.65 | 99-175 | 140 ✓ | ~14-16 EV | 15.8 ✓ (playtest-validated) |

The formula independently re-derives **S1 from the action plan** (tier-2 solos under-pressured)
— and post-reprice the gap is wider. It also confirms elites are *designed correctly*: their
floors sit below target and their **clocks** (Absorb / Canalize / Greedy) are what carry them
into band — mastering the counterplay slows the clock but must never stop it.

### 1.4 The per-tier target baseline (the deliverable numbers)

| Tier | Floors | Fight length | EHP band | DPT floor | **Spike cap** (of 66) | Attrition/fight |
|---|---|---|---|---|---|---|
| T0 | 1-3 | 3-4 | 24-36 | 4-6 solo / 8-11 swarm opening | **≤12** (18%) | 0-6 solo / 6-12 swarm |
| T1 | 4-8 | 3-5 | 34-50 | 8-11 | **≤14** (21%) | 8-15 |
| T2 | 9-13 | 4-6 | 51-78 | 13-16 | **≤18** (27%) | 12-22 |
| Elite | 8-13 | 5-7 | 85-95 | 12-15 effective | **≤21** (32%) | 17-23 (25-35%) |
| Boss | 15 | 6-9 | 140 | 14-16 EV | **≤24** w/ rider (36%) | 20-30 (30-45%) |

Spike caps are **ceilings, not targets** — no potion system means the 35-45%-of-current-HP rule
is the potion substitute (action plan 1.2-C). Nothing below proposes raising a spike except the
already-planned DP step (§9), which peaks at 21 = 32%.

STS2 cross-check **[verified]**: their act-1 vs the 66 HP character — normal-fight hits 8-14
(12-21% of pool), elite spikes 17-23 (26-35%), boss burst 26 (39%), fights 4-6 player turns.
Our caps sit at or below theirs on every row once turn-density (our 3-5 turn fights) is priced in.

---

## 2. What the STS2 decompile actually says (A0)

Full tables in [sts2_enemy_dataset_2026-08.md](sts2_enemy_dataset_2026-08.md). What matters
for our decisions:

### 2.1 The anti-stall census — their formula, measured

- **Overgrowth: 12/17 monsters ramp. Underdocks: 12/16. All 6 elites and all 6 bosses have a
  length clock.** Zero of them read the turn counter — every clock is an authored move or a
  self-ticking status (the Cultist pattern: one telegraphed incant installs +2-5 Str/turn).
- **Non-rampers ALWAYS carry a substitute**: a player debuff that taxes output while they live
  (attacks −30%, "only 1 Skill/turn", Tangled), junk-card injection, or defense tech
  (Artifact, Plating, hit-nullify stacks, "first hit each turn +6 block", a hard 20-HP/turn
  loss cap forcing ≥4 turns).
- **Rates**: trash +0.5-2 Str/turn-equivalent (typical +2 per 3-turn cycle); elites +2/4t
  *plus* a signature gimmick; bosses ~+2/cycle *plus a second clock* (junk flood every cycle,
  a death bomb, phase enrage, stat drain).
- **Constrained RNG everywhere**: cannot-repeat on nearly every weighted branch, cooldowns,
  use-only-once, max-N-in-a-row. Twin fights desync identical bodies by starting them at
  different cycle offsets — direct precedent for our §8 slot-keyed openers.

**Translation**: Julien's directive ("most fights have anti-stall, a Strength-gain move on
some — not all — moves") is *exactly* their shipped formula: ~70-75% of trash ramps, 100% of
elites/bosses, substitutes for the rest. Our current coverage is 19/34 fights (§3.2) — the gap
is the single biggest structural difference between our act 1 and theirs.

### 2.2 Junk cards ("status cards") — the full taxonomy, with doses

| Card | Behavior | Who injects it (act 1) | Dose |
|---|---|---|---|
| Slimed | costs 1, Exhaust (pay energy + a play to cycle it) | slime family, from fight 1 | 1-2 per cast |
| Dazed | unplayable, evaporates at end of turn | summoned Eye (3/turn!), Haunted Ship (5 once) | gimmick-sized |
| Wound | unplayable, **persists** | act-1 boss #1, per cycle | 3/cycle |
| Infection | unplayable, end of turn in hand: **take 3** | elite + its spawns | 3 + 1/2t |
| Beckon | end of turn in hand: **lose 6**; pay 1 energy to ditch | act-1 boss #2, per cycle | 3/cycle, 1 seeded into DRAW pile |
| Burn / Void | take 2 at end of turn / lose 1 energy on draw | acts 2-3 | escalation tools |

The ladder runs *evaporates → persists → damages → damages-or-pay*. Notably: **junk injection
starts on floor 1** (slimes), elites use it as their gimmick, and both act-1 bosses flood it as
their second clock. None of their act-1 junk locks the whole hand.

### 2.3 Everything else worth keeping

- **Weak-pool gating**: first 3 fights draw a weak pool = our tier 0, same shape. Their weak
  pool still has texture: a 3-rat pack whose rats *summon a 4th*, slimes injecting from turn 2,
  corpse-slugs eating dead allies for +4 Str.
- **Debuff cadence**: act-1 trash applies Frail/Weak/Vuln 1-3 stacks roughly every 2-3 turns on
  dedicated beats — our Weak/Ink satyr-kraken texture is the same density. Their elites go
  harder (Vulnerable 3, one applies Vulnerable 99 as a phase gimmick).
- **Gold**: 10-20 / elite 35-45 / boss 100 → elite premium ≈ 2.7×. Ours post-N2: 40-50 hallway
  T2 / elite 70-90 ≈ 1.8× — acceptable given dice are an extra sink; no further move.
- **Bosses are the most deterministic enemies in their game** (fixed 4-5 beat loops, visible
  ramp) — validates Leviathan's promoted cadence design.
- Their per-act growth (bodies ×1.7-2.0, elites ×1.5-1.75, boss ×1.5-1.6, damage ×1.4-1.6,
  player HP flat) — our ACT2 multipliers already sit inside the band **[verified]**. Act-2
  bake stays as-is for launch; per-stat authoring (block/debuff scaling) remains Steam-phase.

---

## 3. Dice Odyssey today — the audit

### 3.1 Per-fight audit table (all 34 pool fights, code-verified 2026-08-16)

EV DPT = expected damage/turn over turns 0-5 including ramps; P used for D/P is the
post-reprice on-curve band mid-point for that tier. Verdicts: **OK** in band · **LOW/HIGH** vs
§1.4 targets · **STALL-SAFE** = no clock of any kind.

| Fight | Tier | Comp | HP | EV DPT | Clock | Verdict |
|---|---|---|---|---|---|---|
| tier_0_crab | 0 | Skeleton 26 | 26 | ~5.8 (12-spike %4==3) | RNG +M / spike | OK — the anchor |
| tier_0_plant | 0 | Venom Bloom 32 | 32 | ~4.7 | promised +3M/3t | OK (§8 verdict pending) |
| tier_0_machopeur | 0 | Marauder 31 | 31 | ~8.3 rising | promised +2M/t | OK — hard timer |
| tier_0_octopus_3 | 0 | 8+18+8 krakens | 34 | ~10.5 | none | OK dmg — **STALL-SAFE** |
| tier_0_satyrs_3 | 0 | 8+18+8 satyrs | 34 | ~9.8 | none | OK dmg — **STALL-SAFE** |
| tier_0_octopus_1_satyrs_2 | 0 | 2 satyr + b.kraken | 34 | ~10.5 | none | **STALL-SAFE** |
| tier_0_octopus_2_satyr_1 | 0 | satyr + b.kraken + kraken | 34 | ~10.5 | none | **STALL-SAFE** |
| tier_0_satyrs_1_octopus_2 | 0 | 2 kraken + b.satyr | 34 | ~9.9 | none | **STALL-SAFE** |
| tier_0_satyrs_2_octopus_1 | 0 | kraken + b.satyr + satyr | 34 | ~9.9 | none | **STALL-SAFE** |
| tier_0_bigger_octopus_2 | 0 | 2× b.kraken 18 | 36 | ~11 (8/14 alt) | none | **STALL-SAFE** |
| tier_0_bigger_satyrs_2 | 0 | 2× b.satyr 18 | 36 | ~9.9 | none | **STALL-SAFE** |
| tier_0_bigger_satyrs_octopus | 0 | b.satyr + b.kraken | 36 | ~10.4 | none | **STALL-SAFE** |
| tier_1_crab_satyr | 1 | 2 satyr_t1 + Skeleton_t1 | 40 | ~10 (17 @T3) | RNG + spike | OK |
| tier_1_defender | 1 | Defender 34 | 34 | ~7.8 | promised +1M/3t | OK (bottom of band) |
| tier_1_lurker ⚠️(=Oculus) | 1 | Oculus 44 + Parasite | 44 | ~6 | promised +2M/3t + greed tax | LOW floor — §8 fixes |
| tier_1_oculus_goblin ⚠️(=Lurker+Goblin) | 1 | Lurker 18 (Flux) + Goblin 22 | 40 | ~12.3 | none (Flux tax only) | hot floor, **no clock** |
| tier_1_machopeur_octopus | 1 | Marauder_t1 + b.kraken_t1 | 43 | ~13.8 rising | promised (Marauder) | OK (top of band) |
| tier_1_machopeur_satyr | 1 | Marauder_t1 + b.satyr_t1 | 43 | ~13.2 rising | promised | OK |
| tier_1_plant_goblin | 1 | Venom_t1 + Goblin | 50 | ~11 | promised (plant) | OK |
| tier_1_plant_octopus | 1 | Venom_t1 + b.kraken_t1 | 44 | ~10.2 | promised | OK |
| tier_1_sigil_slug | 1 | Sigil Slug 37 | 37 | ~7.3 | promised +2M/3t | OK (§8 improves) |
| tier_1_octopus_2_satyrs_2 | **2** | 4-body swarm | 59 | ~15.5 | none | OK dmg — **STALL-SAFE** |
| tier_1_lurker_crab | **2** | Lurker_t2 (Flux) + Skeleton_t2 | 53 | ~10.8 (18 @T3) | RNG + spike + Flux | LOW-ish |
| tier_2_defender_machopeur | 2 | Defender_t2 + Marauder_t2 | 78 | ~16.2 (peak 26) | promised ×2 | OK — attrition fight |
| tier_2_defender_satyr | 2 | Defender_t2 + 2 b.satyr_t2 | 78 | ~17.5 | promised | OK (opening 18+Weak4 at cap) |
| tier_2_hound | 2 | Lava Hound 51 | 51 | ~10.5 | none (1-shot Exposed) | **LOW + STALL-SAFE** |
| tier_2_machopeur_octopus | 2 | Marauder_t2 + 2 b.kraken_t2 | 78 | ~19.7 rising | promised | OK |
| tier_2_medusa | 2 | Medusa 58 | 58 | ~12.3-13.6 | promised +3M/4t (shipped) | slightly LOW floor |
| tier_2_plant_crab | 2 | Skeleton_t2 + Venom_t2 | 69 | ~10.2 (19 @T3) | promised + RNG | LOW-ish floor |
| tier_2_vortex | 2 | Maelstrom 54 | 54 | ~8.5 → 18 rising | promised +3M/2t | LOW early (by design) |
| tier_elite_dragonpriest | 3 | DP 90 | 90 | 11 flat + Canalize | greed tax (>12 bank) | OK via clock; §8/§9 planned |
| tier_elite_lich | 3 | Lich 85 | 85 | 8 + Absorb Muscle | **every-turn clock** | OK via clock |
| tier_elite_gargantua | 3 | Gargantua 95 + Greedy | 95 | ~6.7-9 + Greedy | fast greed clock | floor LOW; §8 fixes |
| tier_boss_leviathan | 4 | Leviathan 140 | 140 | ~15.8 EV | promised +4M/4t (shipped) | OK — playtest-validated |

Unreachable leftovers (excluded, unchanged): tier_0_chimera, tier_0_machopeur_satyr,
tier_0_satyrs_octopus_3, tier_0_crab_satyr, tier_1_bat_crab, tier_1_bats3.

### 3.2 Findings

1. **HP is right almost everywhere.** Every EHP sits in the §1.4 bands (the July trims did
   their job). **No HP changes proposed** — pressure moves through DPT floors and clocks,
   never added EHP (anti-bloat rule, now reference-backed).
2. **15/34 fights are stall-safe** — all 12 tier-0 critter fights, Lurker+Goblin, the 4-body
   swarm, and Lava Hound. STS2 ships ~75% coverage + substitutes on the rest; we ship 56%.
   This is the audit's #1 structural gap, and it matters *more* for us than for them: Golem
   carryover, Second Wind healing, Kickstart/blessing stacking, and Charge setup all reward
   stalling in ways STS2's card system doesn't.
3. **Tier-2 solos run 2-4 DPT under target** (S1, confirmed independently by the model, worse
   post-reprice): Hound 10.5, Medusa 12.3, Maelstrom 8.5-early, plant_crab 10.2 vs target
   13-16. The three 78-HP attrition fights are correct.
4. **Elites are structurally sound** — their clocks (Absorb every turn, Canalize, Greedy) do
   the pressure work. New data point: **Lich's Absorb ticks every single turn** (+Muscle =
   player's last rolled face), making it the strongest clock in the game already — which
   changes one §9 recommendation (§4.3).
5. **Debuff coverage**: Weak (satyrs/Medusa/Leviathan), Ink (krakens/Leviathan), Unlucky
   (Goblin), Exposed (Hound/Gargantua) — good density, matches their act-1 cadence. **Depleted
   is the one player-facing status no enemy uses** — our most on-theme debuff (die denial =
   energy attack) is sitting unused.
6. Hygiene (already known, re-confirmed): `tier_1_lurker.tscn` contains Oculus and
   `tier_1_oculus_goblin.tscn` contains Lurker+Goblin (post-swap names); Absorb has **no
   tooltip** (the game's one de-facto hidden intent — §8.4 prerequisite); two fights named
   `tier_1_*` carry `battle_tier = 2` (they're correctly treated as T2 by the pool — naming only).

---

## 4. Prescriptions — per-enemy

Design rules obeyed throughout: raise floors never spikes · DPT-parity texture where a fight is
already in band · one new rule per fight · Strength ramps only (no debuff-escalation spirals —
standing rejection) · ramps land their first step ~turn 4+ in tiers 0-1 so on-curve players
barely see them · prefer riders on existing beats (or one installer move) over added beats ·
every new rider shows honestly via the `icon2` intent system.

### 4.1 New this audit (the riders that close the stall gap)

| Enemy | Change | Numbers | Coverage effect |
|---|---|---|---|
| **Bigger Satyr** (all 3 tier .tres) | +1 Muscle rider on its **attack-6 beat** (the ~47% beat; debuff beat untouched) | ≈ +0.5 Muscle/turn from ~turn 2; a 3-4-turn on-curve fight sees +1, a turn-8 stall faces +3-4/hit | covers **6** stall-safe fights (every satyr swarm incl. the t2 4-body) |
| **Bigger Kraken** (all 3 tier .tres) | +1 Muscle rider on its **7 beat** (ink beat untouched) | ≈ +0.5/turn (strict alternation) | covers **5** more (kraken swarms + mixed) |
| **Goblin** | §9 rider confirmed: +1 Muscle on the 9 (post-§8 kit 7/**9**/5+U1) | cycles 7/9/5 → 8/10/6 → 9/11/7; first step ~turn 5 | covers Lurker+Goblin |
| **Lava Hound** | N4 dial: double-hit 6→7 (12→14) **+** §8 "Molten Roar" at ≤50% HP, once: +2 Str & block 5 | DPT 10.5 → ~12.5-13.5 with roar | kills the last stall-safe fight; T2 solo floor into band |
| **Medusa** | swap **Weak 2 → Depleted 1** on the 12 beat — "her gaze petrifies one of your dice" | net ≈ +0.7 DPT-equivalent (Depleted 1 ≈ −3.5 P next turn vs Weak 2 ≈ −2 once); 15-spike and %4 guard untouched | Depleted debuts on the most thematic carrier; T2 solo pressure up |
| **Maelstrom** | N4 dial confirmed: 12 → 13 | rising line becomes 13→16→19 | T2 solo floor |
| **Leviathan** | *(gated on junk cards existing)* Ink beat also injects **1 Sludge**, cap 3/fight | tempo tax ≈ +8-12 vEHP, no HP damage | boss gets the reference's "second clock" (their bosses flood 3 junk/cycle) |

Small Satyr / small Kraken / Skeleton / Marauder / Venom Bloom / Defender: **no changes** (smalls
die first and stay clean; Skeleton is the calibration anchor; Marauder is already the game's
fastest clock; Venom Bloom awaits its §8 verdict; Defender is the §8 "model enemy").

### 4.2 Already-planned changes this audit endorses unchanged

- **§8 texture batch** at DPT parity: Oculus 7 / +2Str&block4 / 8 · Sigil 12 / 7 / guard ·
  Goblin 7/9/5+U1 · Lich 8 / 10 / 5+Weak2 · **DP 12 / 8&block6 / 15** · Gargantua 8 / 2×4 / 11.
- **§9 DP spike-step 15→18→21** (turns ~3/6/9; 21 = 32% of 66, under cap) — this is exactly
  the reference's "gun gains +5 per use" pattern, now precedent-backed.
- **Gargantua §8 mild buff (8.0→9.0 DPT): recommend YES** (open verdict answered) — elites
  should cost 25-35% and Gargantua is the tamest; the 2×4 multi-hit also plays into its own
  Exposed for honest texture.
- **N4 sequencing** stands: dials only after the §8 batch playtests (§8 may deliver the missing
  pressure as texture). The riders in §4.1 are independent of that gate.

### 4.3 Revisions to the previous plans (new data → two SKIPs)

- **SKIP the §9 Lich rider** (+1 Muscle on soul-sap). The dataset shows Absorb already ramps
  **every turn** (+player's last face — even starved it ticks; skilled play ends turns on a low
  face, which is real counterplay). Adding a second ramp violates one-clock-per-fight and
  double-punishes. §8's 8/10/5+Weak2 texture still goes in.
- **SKIP Lurker creep** (the 6→7→8→9 open verdict → recommend NO). Flux *is* the fight's
  substitute (their non-ramper pattern), Lurker's flat-6 siege identity is documented as the
  point, and its fight-mates now carry the clock (Goblin rider / Skeleton spike). Resolves
  §9.7-(3) without touching the "flatness is the point" identity.
- **SHELVE the global soft-enrage backstop indefinitely** (was "hold until Golem stall
  measured"). The reference argument is now overwhelming: 0 of 33 act-1 monsters (0 of 122
  game-wide) read the turn counter. With §4.1 riders, 31/34 fights carry an authored clock —
  a hidden global rule would add nothing but opacity. Revisit only if playtest shows Golem
  turtling that authored clocks can't answer.

---

## 5. Junk cards ("bad cards") — the baseline

Aligned to the reference ladder (*evaporates → persists → damages → damages-or-pay*), keeping
the already-scoped three, with STS2's real doses:

| Card | Spec (unchanged from §8.3 scoping) | STS2 analog | Carrier | Dose |
|---|---|---|---|---|
| **Sludge** | unplayable, vanishes at end of turn | Dazed | **Deepling** (act-2 b.Kraken) ink beat | 1/cast, cap 2/fight |
| **Cinder** | unplayable, take 2 if in hand at end of turn | Burn/Infection | **Ember Fiend** (act-2 Hound) double-hit | 1/cast |
| **Hex** *(NAME TAKEN - see CLAUDE.md: "Hex" is now the card TYPE for enemy-planted junk, so this card needs a new name before implementation)* | "can't play other cards while a Hex is in hand; play it (does nothing) to discard" | *harsher than anything in their act 1* | **Bog Hag** (act-2 Goblin): Unlucky beat → 5 dmg + 1 Hex | 1, cap 1 in deck |
| *(wave 2)* Lead Die / Cursed Pact | rolls −1 while held / can't roll Red | Void-class | post-launch | — |

**Hex semantics flag** (open verdict, sharpened by the data): none of STS2's act-1 junk locks
the whole hand — their harshest is Beckon (*lose 6 or pay 1 energy*). At a 5-card hand, one
Hex locking everything is closer to a boss mechanic (their "play only 1 card" Ringing) than a
hallway tax. Options: (a) keep as specced but hard-cap 1 Hex ever in deck; (b) soften to
Wound-style "unplayable, persists" (the deck-thinning tax); (c) "while in hand, your rolls are
−1" (moves Lead Die up a wave). **Recommend (a) with the cap** — it preserves the fantasy and
the "play it first" puzzle without stacking into a soft-lock.

**Rollout**: build the three cards with act-2 carriers first (as §8.3 planned — injection is
fight-scoped for free since piles rebuild per combat, and the pickup-refusal messaging already
exists). Then two act-1 backports once the feel is proven: **Leviathan Ink → +1 Sludge**
(boss teaching, §4.1) and — optional, the STS1 "slimes from floor 1" analog — **bigger Kraken
ink beat injects 1 Sludge in act 1 too** (cap 2/fight; vEHP ≈ +3-5, comfortably inside T0
bands). Both are decision-sheet items, not defaults.

vEHP pricing (established scale): junk card ≈ 3-5 each · dose caps keep any fight ≤ ~2/enemy/turn.

---

## 6. Anti-stall coverage — before → after

| | Before | After §4 (+§8/§9 as planned) |
|---|---|---|
| Fights with an authored Strength clock | 16/34 | **31/34** |
| Fights clock-free but carrying a substitute | 3 (Flux/greed taxes) | 3 (Lurker fights via Flux; smalls-only never exists — every critter fight contains a bigger body) |
| Fully stall-safe | **15/34** | **0/34** |
| Enemy types that ramp | 11/19 | **16/19** (smalls + Lurker + Skeleton-RNG stay light by design) |

Reference parity: STS2 act 1 = 24/33 monsters ramp + 100% elites/bosses + substitutes for the
rest. Post-plan we sit at the same shape without touching a single HP or spike value.

---

## 7. The attrition ledger, re-checked

Act-1 worked example (on-curve player, ~half of campfires rested), extending the action plan's
§2.5 with the reprice and the prescriptions:

| Line | July model | Post-reprice (today) | **After prescriptions** |
|---|---|---|---|
| 3 × T0 | −6 | −6 | −7 (riders ≈ invisible on-curve) |
| 3 × T1 | −15 | −12 | −14 (§8 texture + Goblin rider) |
| 3 × T2 | −25 | −22 | **−27** (N4 + Medusa + Hound) |
| 1.3 × elite | −18 | −17 | −20 (§8 kits + DP step) |
| Boss | −22 | −21 | −24 (guard ramp + Sludge tempo) |
| **Damage out** | −85 | **−78 (drifting bloodless)** | **−92** |
| Heals (camps + events) | +50-60 | +50-60 | +50-60 |
| **Boss arrival** | ~45-55/66 | ~48-58/66 | **~42-52/66** |

The reprice had silently handed back the slack the July trims removed; the prescriptions take
it back plus a margin. Shape check against the brief: block cards and campfire rests are worth
real HP again (T2 = "please let me reach a campfire" territory), the bad-tail dies in tier 2,
and the on-curve player reaches the boss with a survivable-but-tense pool — the A0 contract:
**challenging in stretches, winnable most of the time when played well.**

---

## 8. Rollout order & verification

1. **Batch 0 — playtest debt** (unchanged, still first): everything since 08-13 is unplayed.
2. **§8.4 wiring/honesty pass**: explicit `is_performable` on Lich/Gargantua/Sigil, **write
   the Absorb tooltip**, align Flux tooltip. Prerequisite before any new enemy content.
3. **Wave A — riders & dials (XS each, harness-verifiable)**: bigger Satyr/Kraken riders,
   Goblin §8 numbers + rider, Medusa Depleted swap. Each rider = damage-parity + `icon2`
   intent assertion in a `debug_audit_changes`-style harness; Depleted-on-player needs one
   check that enemy-applied Depleted decrements the die pool like Electrify's self-Depleted.
4. **Wave B — §8 T1/elite texture batches** as planned → playtest → **N4 dials** (Hound 6→7,
   Maelstrom 12→13) only if T2 still reads soft.
5. **Wave C — junk cards** Sludge → Cinder → Hex with act-2 carriers → playtest → act-1
   backports (Leviathan, optional b.Kraken).
6. Cadence-collision check: no new modulos introduced (riders sit on existing beats; Hound
   Roar is an HP-threshold CONDITIONAL, the WS2 pattern) — Medusa %4==3 / Leviathan %4==2 /
   Dicelord %3==1 stay the only periodic gates.

## 9. Decision sheet (what needs Julien's verdict)

1. **T0 riders scope** — both bigger critters as specced? (Conservative variant: rider only
   ticks from turn 4+, invisible on-curve but later first step.)
2. **Medusa Weak→Depleted swap** — yes/no (pure flavor+pressure win in my read; her Weak
   density is redundant with satyrs anyway).
3. **Lurker creep = SKIP** and **Lich rider = SKIP** — sign off on the two revisions (§4.3).
4. **Gargantua §8 mild buff = YES** — sign off.
5. **Backstop = SHELVED** — sign off (was "hold"; reference data says never).
6. **Hex semantics** — option (a) cap-1 / (b) Wound-style / (c) roll-malus.
7. **Act-1 junk backports** after act-2 proves out — Leviathan Sludge yes/no; b.Kraken act-1
   Sludge yes/no.
8. Existing open §8 verdicts unchanged: Venom Bloom T0 propagation, slot-keyed openers on
   tier 0, boss-cadence playtest read.
