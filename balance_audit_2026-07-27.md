# Dice Odyssey — Full Pre-Release Balance Audit (2026-07-27)

**STATUS 2026-07-28: Julien reviewed everything and ALL his verdicts are IMPLEMENTED** (see the
CLAUDE.md TL;DR entry of the same date for the full change list + playtest watch items). Remaining
open threads: the tier-2 D/P treadmill watch (§2.3), the rejected §6A designs (fortress stays
keystone-less by choice), and playtest confirmation of the whole batch.

**Scope**: everything — enemies/fights, all 81 draftable cards (+ upgrades + starters), all 9 dice
types + infusions, all 26 relics, the run economy, and a gap analysis with new card designs.
**Method**: scripted extraction of the live working tree (every `.tres` HP/damage/price, every card
description + a script-level check of which cards actually emit `dice_roll_reset`), deep-reads of
~60 `.gd` files, cross-checked against `balance_analysis_2026-07.md` / `-07-14.md` (whose D/P model
is reused, not re-derived) and the 2026-07-25 full-clear playtest. Successor doc to those two.

**Headline**: the game is in the best shape it's ever been — the 07-14 trims + the Lurker/Oculus
swap + the 07-26 tier-2 retune landed, and the full clear confirms it. This audit found **dead/
fragile enemy AI wiring (Dragonpriest above all), a handful of clear card outliers in both
directions, one relic that needs a cap, several consistency traps**, and a set of gaps where cheap
additions buy a lot of depth. Almost nothing here says "retune the numbers broadly" — the message
is *fix the wiring, trim the bland, cap two outliers, and spend the remaining pre-release energy
on the gap list*.

---

## 1. What is healthy — do not touch

Named explicitly so future passes don't churn it:

- **Tier 0** (fl 1–3): critters 8/18, Crab 26 + 12-spike, Plant 32 (+3 ramp), Machopeur 31 (TS2).
  Validated twice. Leave.
- **Tier structure & EHP spreads**: T1 34–50, T2 51–78 (the 07-26 defender/satyr retune landed;
  the three long fights all sit at exactly 78). Kill-turn math: median 3–4, bad-tail 5–7. In band.
- **Lich 85 @ base 8 + Absorb** — still the best design in the roster, counterplay teachable.
- **Leviathan 140** (18+Ink3 / 15+Weak2 / block8+M4) — the full clear read it as clutch-but-fair.
- **Lurker/Oculus swap** — Flux on an 18 HP body + Oculus 44 solo scaler is the right shape.
  (Still needs its own playtest confirmation, but the design is correct; don't pre-tune it.)
- **Campfire 33% heal vs upgrade**, reward pity (6.0/3.7/0.3 +0.2/screen cap 2.0), shop 2C/2U/1R
  + guaranteed rare, boss = all-rare offers. All working as designed.
- **The gates-read-the-BANK system** (Min/Max/Exact/parity check accumulated Power, not the last
  face) — this is the game's actual brain and it's good. Several suggestions below lean into it
  harder rather than adding new systems.

---

## 2. Enemy & fight audit

### 2.1 Dragonpriest — dead content, a fragile picker path, and the quiet "hardest elite" title

Code-verified chain (`scenes/enemy/enemy_action.gd` + `enemy_action_picker.gd` +
`enemies/dragonpriest/*`). Three facts, one design question:

- Base `EnemyAction.is_performable()` returns **false** — an action with no override is never
  pickable through its own rules. Dragonpriest's `AttackAction2` (11 dmg, CONDITIONAL, no
  override) therefore **never fires. Dead node.**
- His observed pattern (turn 0 Canalize → 13/turn flat) *is* what happens, but half of it is
  accidental: `BuffAction` has no `type` in the scene, so it defaults to CONDITIONAL and its
  `fight_turn == 0` check wins turn 0 (good — deterministic Canalize ✓). But `FirstAttackAction`
  (13, CHANCE) is *also* gated `fight_turn == 0` — on turns 1+ **nothing is performable at all**
  and every turn falls through to the anti-freeze fallback `return get_child(0)`, which happens
  to be the 13 attack. His entire steady output runs on the "avoid freezing" emergency path, and
  his opener's turn-0-only condition effectively fires on every turn *except* turn 0. It works
  today purely because the right node is child 0.
- **The design question**: Canalize (+3 Muscle each time the bank crosses 9, re-arming whenever it
  drops back ≤9) is effectively **+3 Muscle per turn** for any player who builds a normal 10+ bank
  each turn — so DP curves 13 → 16 → 19 → 22 → 25 ≈ **~95 unblocked over 5 turns, more than
  post-nerf Lich (~80)**. He is currently the hardest elite in the game. There IS clean
  counterplay — spend in small sub-10 packets (the "spend small" mirror of Lich's "end low") —
  but nothing teaches it beyond the status tooltip, and the packet-spending line costs real
  damage output at P 20+.

**Recommended fix (behavior-preserving cleanup + one dial):**
1. Give the 13 attack an explicit `is_performable() -> true` so the steady hit is rule-driven,
   not fallback-driven; delete or repurpose the dead `AttackAction2`.
2. Leave Canalize's mechanic untouched (Julien's 07-04 ruling) but treat DP as the elite to watch
   in feedback: if he's the wall, the dial is Canalize's Muscle 3 → **2** (≈ −10 over 5 turns),
   not his base 13.

Same-family note (no pre-release action, just awareness): Lich, Machopeur, and Gargantua's steady
attacks are *also* only reachable via the `get_child(0)` fallback. Any future re-ordering of AI
children silently changes enemy behavior. Post-launch cleanup: explicit `is_performable → true`
on every intended-steady attack.

### 2.2 Inconsistencies & small fixes

| Item | Detail | Fix |
|---|---|---|
| **Tier-2 gold uneven** | `medusa` / `defender_machopeur` / `machopeur_octopus` pay 40–50; `hound`, `vortex`, `plant_crab`, `defender_satyr` (78 EHP!), `lurker_crab`, the 4-body pay 30–40. The tier's longest fight pays less than its shortest. | Set all tier-2 fights to 40–50. (~6 `.tres` edits) |
| **Crab "big attack" isn't** | `crab_big_attack_action.gd` deals 6 — same as the normal attack. Pure flavor bug; the intent shows the same number for two different-named moves. | Make it 8, or delete the node (his 12-spike already covers "big"). |
| **Goblin's double-hit is undocumented** | `goblin_attack_action_2.gd` executes damage **twice** → his cycle is 7 → **14** → 5+Unlucky (avg 8.7/turn, the highest steady in tier 1). Both balance docs modeled him at 6–7. Live in Lurker+Goblin (during the Flux window!) and Plant+Goblin. | Not necessarily wrong — it's a real spike with a readable "2x7" intent — but it's *accidental* tuning. If Lurker+Goblin playtests hot, the 14 is why. Watch, don't pre-nerf. |
| **Absorb/Canalize icon numbers lie** | `absorb.stacks = 5`, `canalize.stacks = 5` are set at cast but mean nothing (real effects read `last_roll` / +3). The status badge shows "5". | Set `stack_type = NONE` on both `.tres` (same treatment as the Blessing statuses on 07-16). |
| **Boss finale is a stat-rerun** | The Dicelord = Leviathan ×1.6 HP + flat +4, zero new behavior. Already P1 on the launch checklist ("signature move"). | Concrete pitch that fits the name and costs ~a day: **Dice Theft** — "Steals a die: 10 dmg + one random owned type gets −1 die next turn" (plumbing = the Depleted pattern, `*_dice_bonus_amount -= 1`). A Dicelord messing with your *dice pool* instead of your HP is the on-brand missing beat. |

### 2.3 Tier-by-tier verdict tables (current numbers, post-everything)

**Tier 1 (fl 4–8, P ≈ 17–21)** — spread 34–50, D floor 6–9, spikes 12–14. In the fun zone.

| Fight | EHP | Steady D | Notes |
|---|---|---|---|
| Oculus solo | 44 | ~6 rising (+2/cycle, Parasite >18) | New scaler; the greed dial. Playtest priority #1. |
| Lurker 18 + Goblin 22 | 40 | 6 + 7/14/5 cycle | Flux window vs Goblin's 14 = the tier's spiciest turn. Playtest priority #2. |
| Plant+Goblin | 50 | 11–13 rising | Longest T1, fine post-trim. |
| Defender / Sigil / others | 34–44 | 6.7–7.3 | Healthy. |

**Tier 2 (fl 9–13, P ≈ 25–32)** — spread 51–78. Solos (51–58) melt for good decks but carry spike
identity; the three 78s are the attrition fights. **Structural watch, not a change**: T2's D/P
(~0.3–0.45 steady) is now *below* T1's — the same treadmill the 07-14 doc called out. The full
clear said it feels right, so leave it — but when the next "too safe" report comes in, the
pre-scoped levers are: Hound's double-hit 6→7 (+2/activation), Vortex 12→13, and *nothing else*
(Medusa's 15 and Defender+2Satyr's turn-1 18+Weak4 are at the 35–45% survivability ceiling).

**Elites**: Lich 85 ✓, Gargantua 95 ✓ (8-flat + Greedy is intentionally the "volume tax" fight),
Dragonpriest 90 — blocked on the §2.1 fix. **Boss** ✓.

**Act 2**: inherits everything via the multipliers; the DP fix is act-2-relevant too (an act-2
Canalize-branch DP opens at 18 and ramps +3/turn — with the coin flip, that's a run-killer lottery
at ×1.75 HP). Post-fix with Muscle 2 it's a legitimate final-elite.

### 2.4 Roster gaps (post-launch, unchanged from 07-04 §7 — still true)

Pacing archetypes covered: race ✓ attrition ✓ spike ✓ setup-denial ✓ anti-bank ✓ (rich, arguably
over-covered: Flux + Parasite + Canalize + Absorb + Greedy all tax the bank in different ways).
Still missing: **target-priority** (a support/healer body worth killing first — the Satyr Shaman
sketch) and **timer** (countdown ritual, the Lagavulin role). Those two would do more for fight
variety than any number change. Not pre-release work.

---

## 3. Card audit (81 draftable + starters)

### 3.1 The efficiency frame

A card converts bank → effect. Baseline = Strike (1.0×). The ladder: X2 (Flurry-red / Smash-Min10 /
Overdrive-Max12 / Tidal>10), X3 (Bullseye-Mult6 / Low Blow-Max3 / Kamikaze-red-risk), X4
(Duo-Exact2 / Doomsday-Exact13), flat jackpots (Unity 12, Low Roller 12−X, Blackjack kill). Gates
price the multiplier. That structure is sound. The outliers below are the cards that break the
price — in either direction.

### 3.2 Overtuned / watch list (in order of concern)

1. **Cursed Toss (COMMON, Celestial, no-reset)** — 2d6 ≈ **7 free damage every turn it's in
   hand**, costs nothing, resets nothing, no gate, and **Strength applies per die** (verified in
   script), so at +3 Str it's ~13/turn. It also feeds every throw/roll trigger (Hunting Bow,
   Snake Eyes, Metronome, Crown...). It was consciously shipped as the Slash replacement, but
   Slash was 6 flat and this is 7-avg *with two scaling hooks*. As a Common it's an auto-pick in
   100% of decks. **Recommend: Uncommon**, or 1d6 base / 2d6 on the "+" (currently + is 3d6 ≈
   10.5/turn free — that's a Rare's output on a Common's slot).
2. **Shockwave (COMMON, Max 10, no-reset)** — the only no-reset direct-damage-X card: at a 10 bank
   it's "deal 10, keep the 10" — a free extra Strike bolted onto every cycle. Auto-pick tier.
   **Recommend: Uncommon** (keep numbers — the effect is great, the drop-tier is the problem).
   These two plus the cut list below would leave Commons much flatter in "free value", which is
   where Commons should be.
3. **Kickstart (COMMON, Max 3)** — "Gain X Strength" = up to **+3 permanent Strength per play,
   repeatable every deck cycle, no exhaust**. Two plays ≈ +5 Str; every multi-hit card
   (Flurry ×2, Stampede ×2, Cursed Toss ×2 dice, Avalanche ×N) double-dips it. The cost (a low
   bank + reset) is real but small. It's the strongest scaling engine at Common. **Recommend one
   of: Exhaust, or Uncommon, or "Gain 2 Strength" flat at Max 3.** (Kickstart+ Max 5 = up to +5/play
   compounds the issue.)
4. **Sledgehammer (relic)** — +2 **permanent** Strength every time the bank crosses 10, re-armed
   whenever it drops below 5 — i.e., *every bank cycle*, which by floor 8 is every turn and
   sometimes twice a turn. A 6-turn fight ≈ +12 Str, silently. Nothing else in the relic pool is
   within half of this. **Recommend: once per turn** (re-arm on `player_turn_started` instead of
   on power<5). Still an S-tier pickup after the cap.
5. **Critical Edge + Repented Evil (combo watch)** — Repented makes every Evil face a 6 = max →
   Critical Edge procs **every roll** (5 dmg each; 7 with the +). Three Evil dice = 15–21 free
   damage/turn. It's act-2-only and needs the infusion pick, so it's probably a *good* "broken
   build" story — flag so it's a known one, not a surprise.
6. **Dice Avalanche** — biggest Strength multiplier in the pool (per-die), but Exhaust + Rare +
   celestial caps it at once-per-fight. Fine as the watch-list entry it already is.
7. **Blackjack** — deletes any enemy including act-2 Dicelord. Julien already ruled bosses die
   too; Exact-21 + Exhaust + Rare is real setup cost, and the Refinement→21 line (21 = 3×7) is a
   genuinely beautiful hidden build. Keep as-is; just know the finale *can* end in one card.

### 3.3 Undertuned / bland — and the open cut list

Julien's pending cut candidates, with verdicts:

| Card | Verdict | Why |
|---|---|---|
| **Fumigation** (C, Max 5 AoE) | **CUT** | Catapult (Max 2: flat 6 AoE + Lucky 1) is strictly more fun at the same job; ≤5 X-AoE is the weaker *and* blander twin. |
| **Bolster** (U, Min 10, EXH, 4 Str) | **CUT** | Kickstart owns cheap Strength; paying a 10+ bank *and* exhausting for +4 is a visible feel-bad. |
| **Dynamite** (C, CEL, Boost 5) | **CUT** | Pure number-smoothing with no identity; Finesse (Max 2 → Boost 8) is the characterful Boost card, Hidden Dagger covers the passive version. |
| **Smash** (C, Min 10, X2) | **CUT** (or adopt the + as base) | Third X2 with the least identity — Bullseye pays more at 12, Tidal needs no gate, Overdrive covers mid banks. If kept, ship it as "X2 + Exposed 2" (the current +) so it has a reason to exist. |
| **Electrify** (C, Charge 3 Blue + Depleted) | **CUT** | Fourth blue battery (Gang Up 4 @Exact 6, Compound, Spark, + Emanation/Echo Chamber). Redundancy, not badness. |
| **Overdrive** (C, Max 12 X2 + Depleted) | **KEEP** | It's the only X2 that works at *mid* banks (5–12) without a color/exact gate — a real niche between Low Blow and Smash — and Depleted is a real cost. Julien's "maybe" resolved: keep. |

Pool 81 → 76 after cuts; §6 proposes what replaces them.

**Rework-don't-cut:**

- **Second Wind** (U, Max 12, EXH): heals ≤6 HP once, for a whole ≤12 bank. Six HP is a rounding
  error next to 33% campfires and 15–25 HP events. It's the only in-combat heal — make it matter:
  **"Heal HP equal to your Power. Max 8. Exhaust"** (cap 8 heal, full-bank rate) or Max 12 keep
  half but no Exhaust. Current version is a trap pick.
- **Windfall** (U, sup): "Throw a Pixie Dice: draw its roll" — **it RESETS your Power** (script
  emits `dice_roll_reset`) while wearing the support glow, and the text doesn't say so. Spending a
  whole bank for avg-2 cards is far below Repel (Block X + draw 2) / Eyepoke (X dmg + draw 3).
  **Make it genuinely no-reset** — a thrown die doesn't touch the bank thematically, and as a free
  cantrip it's finally pickable. (This is also a P0-adjacent honesty fix.)
- **Experiment** (C): "Gain a random Support card" — (a) "Support" is dead vocabulary (launch
  checklist P0), (b) the grant pool (`warrior_draftable_support_cards.tres`: Focus, Low Profile,
  Oracle, Dynamite, Refinement, Catalyst, Eclipse) still contains the **"Oracle"-named Scout 3**
  — so the non-standard name Julien flagged *does* reach players through this live card — and
  Dynamite, which may be cut above. Fix the wording ("Gain a random no-reset card"?), rename
  card_oracle → "Scout 3", and prune the grant pool to taste.

### 3.4 Consistency & honesty items (cheap, high player-trust value)

- **No-reset visibility stays the #1 pre-release card item** (launch checklist P0): 18 pool cards
  never reset; only Shockwave, Coiled Spring and Eclipse say so. The support *glow* meanwhile is
  worn by 4 cards that DO reset (Double or Nothing, Catalyst, Voodoo, Windfall) — the marker
  Julien picks must track the *script truth* (`dice_roll_reset` emission), which this audit's
  extractor already computes per card; reuse it to stamp the flag.
- **Momentum** text says "for each other card" and code matches (counter−1) — ✓ verified, no bug.
- **Requirement wording**: gates read the accumulated bank, and nothing in-game ever teaches that
  "Min 6" means *bank*, not *die face*. One tooltip line on the requirement ribbon ("checks your
  current Power") would pre-empt the #1 predictable Reddit confusion.

### 3.5 Gate-distribution health

none 26 / Min 17 / Max 9 / Exact 9 / Red 3 / Odd 2 / Mult 2 / Even 1 (+12 Celestial). Two
observations:

- **Every Uncommon Blessing is "Min 6"** (7 of them; +Exact 6 Cogwork). Uniform and invisible —
  by mid-game a 6 bank is trivial, so the gate is flavor. Fine mechanically, but it's a missed
  opportunity: re-gating 2–3 Blessings to Even/Odd/Mult would make parity dice matter (see §4).
- **Parity is a ghost archetype**: Even/Odd dice cost 210/190g but exactly one Even card and two
  Odd cards exist. Either the dice are overpriced for what the pool supports, or the pool owes
  them 2–3 payoffs (§6 designs).

### 3.6 Upgrade (+) spot-audit

Sane across the board (verified all 81): gates loosen or numbers grow, none regress. Standouts
worth knowing: Doomsday+ = 78 at Exact 13; Cursed Toss+ = 3d6 free (see §3.2); Dicelord's Gift+
drops its Odd gate entirely (fine, it's the rare); Catapult+ loosens Max 2→3 without a damage bump
(weakest +, could become "Deal 8"); Second Wind+ inherits the base card's problem.

---

## 4. Dice audit

Per-die per-turn EV (all dice refill every turn — a die is *income*, price = permanent +EV/turn):

| Die | Price | EV/roll | Identity | Verdict |
|---|---|---|---|---|
| Green | 150 | 2.0 | low-roll enabler (Low Blow 9, Duo, Unity, Kickstart) | Fair — cheap utility, right price. |
| Blue | 180 | 3.5 | baseline, Arcane target | Fine. |
| Red | 180 | 3.5 | socket gamble, Flurry/All In/Berserk, Blood Sword/House Money | Fine — identity carried by cards. |
| Odd | 190 | 4.0 | has the only 7 (Corrode/Refinement web) | Fine. Fun fact worth a tooltip someday: two odd rolls make an *even* bank. |
| Mech | 200 | 3.5 | ±1 = Exact enabler | Fine — precision tax is correctly priced. |
| **Even** | **210** | **5.0** | guaranteed even bank, 8s (Octet) | **Sleeper best generic buy**: +43% EV over Blue for +17% gold, *and* a parity guarantee. Not broken, but it out-values Blue for pure power every time. Either +10–20g, or (better) leave it and give parity real payoffs so the choice is about identity, not just EV. |
| Evil | 240 | 4.5 | 75% sixes → Hunting Bow / Critical Edge / Echo Chamber pairs | Good. Repented (act 2) → EV 6.0. |
| Giant | 240 | 6.5 | variance, Min-gate enabler | Priced fine; **identity gap** — nothing cares about *rolling high* per-roll (see Seismic Slam, §6). Bulky (act 2) → EV 9.5(!) is the biggest infusion EV swing, watch it. |
| Magma | 270 | 3.5 + roll as AoE | free AoE every roll | Correctly the crown jewel. In 3-body fights a magma roll is ~2× a blue. |

**Infusions** (act-2 spike): all 9 verified live. Relative power is uneven — Bulky (+3 EV/roll) and
Repented (EV 4.5→6 + Critical Edge combo) are clearly above Clockwork (±1 more) and Gnome (charge
on nat 1) — but infusions are a pick-1-of-2 celebration, not a balance surface; variance here is
acceptable spice. No action.

---

## 5. Relic audit (26, both pools identical)

Rough per-fight value tiers at mid-game power:

- **S**: Sledgehammer (see §3.2 — cap it), Overflow Valve (every wasted point → damage; quietly
  worth ~4–8/turn of pure efficiency), Magic Sleeve (+1 draw — universal, always right).
- **A**: War Drum (5 AoE per bank-cycle >9 — the AoE mirror of Sledgehammer but flat, fine),
  Hunting Bow (5/six — scales hard with Evil/Arcane builds), Blood Sword, House Money, Crown,
  Echo Chamber (Evil pairs proc constantly), Snake Eyes Charm (green/low-roll).
- **B**: Metronome, Spyglass, War Horn, Clover, Hidden Dagger, Runic Bones, Fuel-o-meter,
  Flywheel, Volcanic Rock, Quill, Prayer Beads (deck-dependent spike), Arcane Hat, The One.
- **C**: Obsidian Scale / Trick Scale (one die on a fixed turn ≈ +4.5/3.5 EV *once per fight* —
  the floor of the pool), Runic Shield (2 block per *unused* die — actively anti-synergy with
  rolling; it's a "turtle turn" reward that fights the game's core verb).

At a flat 85–120g / one-treasure-slot price, S vs C is a big lottery spread. Cheapest smoothing:
**bump the C-floor** rather than reprice — Obsidian/Trick Scale → "turn 2/3 **and every 3rd turn
after**" (one-line change each, turns them into cadence engines like Volcanic Rock feels), and
Runic Shield → 3/die or "unused **or thrown**". Sledgehammer capped per §3.2. Everything else is
healthy variance.

Also worth a line: the treasure pool and shop pool are currently byte-identical — fine for launch,
but it's a free lever later (shop-only economy relics, treasure-only build-arounds).

---

## 6. Gaps & new card designs

The pool's archetype coverage today: dice-spam ✓✓, precision/Exact ✓✓, low-roll ✓, red/gamble ✓,
refuel-as-means ✓, scout ✓, AoE ✓, block-*generation* ✓. The holes, with designs sized to existing
plumbing (no new systems; every hook named already exists):

**A. Reaffirmed from `archetype_card_designs_2026-07.md` (still the right calls, awaiting verdicts)**
1. **Bastion** — R Blessing: "You no longer lose Block at the start of your turn." The fortress
   keystone; Bulwark/Juggernaut/Dominance/Fortify/Hardened Grip are 80% of a deck with no capstone.
   One flag in `player_handler.gd`. (+ revive on-disk **Cracking** as its alternate finisher.)
2. **Mulligan** — R Skill, Celestial, Exhaust: "Refuel ALL your Dice." All In's mirror; the refuel
   deck's dream turn.
3. **Backdraft** — R Blessing: "Whenever you Refuel, deal 5 damage to ALL enemies." Turns the
   entire refuel suite (Recombobulate/Catalyst/Voodoo/Supplication/Perpetual Motion + 3 relics)
   into a win condition. Hook: `Events.refuel_happened`.
4. **Prophecy** — R Blessing: "Your Scout reveals become your next rolls, in order." Scout
   capstone; the FIFO already exists (`tutorial_forced_rolls` pattern).
5. **Bulletproof** — U Skill, Red: "Block X3." Red's zero-defense gap; gambling your safety.

**B. New from this audit**
6. **Split Even** — U Attack, **Even**: "Deal half your Power to ALL enemies." Even = divisible:
   the gate IS the theme. 16 bank → 8 AoE. Gives Even dice their missing payoff and the parity
   space its identity card. (Hook: `roll_value / 2`, AoE execute.)
7. **Seismic Slam** — U Attack, no gate: "Deal X damage. +10 if your last roll was 7 or higher."
   The first *per-roll-height* payoff — finally a reason Giant/Odd-7/Even-8 faces feel different
   from a 6 (hook: `Global.last_roll`). Bulky-infused act-2 version always procs — good.
8. **Trebuchet** — U Blessing, Min 6: "Your thrown Dice deal 3 more damage." The throw family
   (Cursed Toss, Meteor, Pixie Volley, Avalanche, All In) has zero support cards; one flat
   modifier in `_land_thrown_die` covers all of them. (If Cursed Toss moves to Uncommon per §3.2,
   this is its build-around justification.)
9. **Last Rites** — U Attack: "Deal X damage. If this kills, Charge 2." Execution reward that
   feeds the dice economy instead of the bank (no Executioner-style power-keep, which was cut
   deliberately). Swarm fights get a sequencing puzzle.
10. **Even Tempered / Gathering Storm** — U Skill (Omen family): "Next turn, Charge 3 Blue Dice."
    The clean delayed-discount template; Earthquake/War Ritual/Compound/Coiled Spring already
    prove the next-turn pattern players enjoy — one more generic member makes it a visible family
    (and a future "Omen:" keyword candidate).
11. *(Optional, only if the cut list ships and Commons feel thin)* **Sleight** — C Skill,
    Celestial, no-reset: "Draw 1 card." Pure smoothing cantrip; Commons' honest version of the
    free-value slot Cursed Toss currently occupies.

Net motion: cut 5 bland (→76), add ~6–8 characterful (→82–84), and the pool gains three genuinely
new axes (parity, per-roll height, throw support) without a single new engine system.

**C. Deliberately NOT proposed** (standing decisions respected): Evil-0 payoffs (From Nothing cut
closed that space), multiplier-stacking, revivals of cut cards, "your <type> gets <bonus>" cards
(parked), monuments/min_act gating (post-launch — needs the offer-gating field first).

---

## 7. Economy & meta-run

- **Act-1 gold arc** ≈ 75 start + ~500 income (fights ~370, elite ~52, boss ~90, events ±) vs
  sinks: die #1 150–270, die #2 ×1.4, cards 30–125, relic 85–120, removals 50/75/100. Healthy —
  the full clear's "campfires genuinely contested" is the tell.
- **Act 2 accumulation** (income ×1.5, sinks flat, already on the watch list): confirmed by math —
  by mid-act-2 a player banks 300+ with nothing to want. If it shows up in feedback, the clean
  lever is act-2 shop prices ×1.25 (one multiplier at the price sites), not touching act-1.
- **Tier-2 gold inconsistency** — see §2.2.
- **`RunStats.STARTING_GOLD := 25` / `STARTING_HP := 66`** — the 25 is dead (Global's reset
  writes 75) but it's a booby trap for future readers; align the constant.

---

## 8. Priority-ordered action list

**Pre-release, cheap, do:**
1. Dragonpriest cleanup (§2.1) — explicit steady attack, delete the dead node.
2. No-reset visibility (existing P0) + Windfall made truly no-reset + Experiment wording/Oracle
   rename (§3.3–3.4).
3. Cut Fumigation, Bolster, Dynamite, Smash, Electrify (keep Overdrive).
4. Cursed Toss & Shockwave → Uncommon; Kickstart gets Exhaust *or* Uncommon.
5. Sledgehammer → once per turn.
6. Second Wind rework (heal X, Max 8).
7. Tier-2 gold normalize to 40–50; crab "big attack" 6→8; Absorb/Canalize badge cleanup.
8. Requirement-ribbon tooltip line ("checks your current Power").

**Pre-release if time (P1-tier):**
9. 3–5 cards from §6 (Bastion, Split Even, Seismic Slam, Backdraft, Bulletproof are the
   highest value-per-effort).
10. Dicelord signature move (Dice Theft pitch, §2.2).
11. C-floor relic bumps (Obsidian/Trick Scale cadence, Runic Shield).

**Post-launch:**
12. Explicit `is_performable` on all steady attacks (de-fragilize the picker).
13. Target-priority + timer enemy archetypes; Even/Odd Blessing re-gates; monuments + min_act
    offer gating; shop/treasure relic pool divergence; act-2 price multiplier if gold pools.

---

## 9. Open questions for Julien

1. **Dragonpriest**: OK with the behavior-preserving cleanup? And are you comfortable that he's
   currently the hardest elite (~95 unblocked over 5 turns vs Lich ~80) with counterplay that
   nothing teaches — playtest as-is, or pre-emptively drop Canalize to +2?
2. **Cursed Toss / Shockwave / Kickstart**: agree these three are above the Common power line, or
   is "some commons are just premium" intended? (Rarity moves are zero-risk; the Kickstart choice
   — Exhaust vs Uncommon vs flat 2 — changes its feel the most.)
3. **Sledgehammer cap**: once per turn, or is "the bank-cycle engine relic" the intended fantasy?
4. **Cut list**: sign off on the 5 cuts + Overdrive staying?
5. **Second Wind**: is in-combat healing something you *want* viable, or vestigial by design
   (heal economy lives in events/campfires)? Determines rework vs cut.
6. **Even dice**: price bump, or parity payoffs (Split Even etc.) to justify the EV?
7. **New cards budget pre-release**: how many of §6 fit before the subreddit post — 0, the top 3,
   or the full 6? (Each is a .gd+.tres pair on existing hooks; no new systems.)
8. **Boss**: green-light the Dice Theft signature move?

---

## 10. Post-batch state review (2026-07-28, after all verdicts landed)

**Release verdict: balance and content are launch-ready pending ONE playtest cycle on the watch
list below.** The remaining pre-release risk is concentrated in presentation/technical items
(web build weight, music variety, tutorial corrections, boss presentation), not in game balance.

### 10.1 The game as it stands

- **Pool: 80 cards — 40 C / 30 U / 10 R (50 / 37.5 / 12.5%), 35 ATK / 33 SKL / 12 BLS.**
  Gates: none 36, Min 17, Max 9, Exact 9, Red 4, Mult 2, Odd 2, Even 1; 11 Celestial, ~16
  no-reset, 23 Exhaust. The Common shelf is now honest: no auto-picks left (Cursed Toss at
  EV 5, Shockwave moved up, Dynamite gone) - draft decisions at Common are real again.
- **Enemy curve**: T0 untouched (validated twice). T1 spread 34-50; the Goblin fix lowers the
  tier's steady ceiling 8.7 -> 6.3, making it the safest-trending band in the game. T2 51-78
  with the D/P treadmill watch unchanged. **Elites are now a clean taxonomy - Gargantua taxes
  dice VOLUME (Greedy), Dragonpriest taxes bank SIZE (Canalize, 11 + 2/turn = ~75/5t), Lich
  taxes the last FACE (Absorb, ~80/5t) - three different resource taxes within ~10% of each
  other.** This is a genuine design strength worth preserving as-is.
- **Boss**: act-1 Leviathan unchanged; the act-2 Dicelord now has real identity (Dice Theft
  every 3rd turn). The "keep act 2 with mitigations" strategy is fully executed design-side.
- **Dice/parity**: Even remains the best EV/gold buy (accepted - Split Even rejected). The
  parity lattice is now functional without new payoffs: Calculations feeds Even -> Fortify;
  Electrify feeds Odd -> Mirror Blow / the 7-web (Corrode/Refinement/Blackjack).
- **Relics**: spread narrowed from both ends (Sledgehammer capped ~halved at top; C-floor
  doubled). Top pair is now Overflow Valve + Magic Sleeve - both interesting, no cap needed.

### 10.2 Risks INTRODUCED by the batch (ranked, dials pre-scoped)

1. **Tier-1 softening** - Goblin 14 -> 7 removed the tier's only non-ramp spike, in a band
   already trending safe. Dial: that beat to a single 8-9 (not the double).
2. **Fumigation Max 7 vs early swarms** - one wave per enemy means up to ~21/head vs 3-packs
   at bank <=7, from a Common draftable on floor 1. Dials: Max 6, or Uncommon, or cap at 3 waves.
3. **Trebuchet x Pixie Volley(+)** - +3 per thrown die on up to 6 dice = a two-Uncommon combo
   with Rare-level output (~30 for a 6 bank). Watch, don't pre-nerf - it's a build story.
4. Dice Theft turns replace an 18+Ink / 15+Weak turn with 14+steal - slightly lower boss damage
   on those turns, texture gain. Neutral-good.

### 10.3 Accepted-for-launch weaknesses (conscious, on record)

Rare pool = 10 with no defensive/economy rare (fortress keystone rejected); Even gate has one
payoff; Second Wind stays modest by design; elite counterplays (spend-small vs DP, end-low vs
Lich) taught only by tooltips; Bulletproof/Trebuchet ship with placeholder art; T2's D/P sits below T1's (the treadmill).

### 10.4 Launch-checklist deltas from this batch

DONE by the batch: boss signature move (was P1) - rares wave resolved by rejection - no-reset
visibility closed by the 07-28 disclosure audit - tier-2 gold normalized. STILL OPEN, now the
critical path: **web build weight (biggest technical risk), music variety, tutorial corrections,
boss position/scale override + intro banner, itch act-2 framing.** Recommend promoting
**unplayable-card click feedback** (shake + reason) from P1 - it is the net that makes
"hover tooltip is enough" true for requirement ribbons.

### 10.5 Playtest script (next 2-3 runs, highest information first)

1. Steer into all three elites: does DP's spend-small counterplay emerge naturally at +2/turn?
2. Tier-1 pacing: Lurker+Goblin and Plant+Goblin - flat or fine without the 14?
3. Draft Fumigation early and aim it at packs - degenerate or delightful?
4. Force the throw build (Cursed Toss + Trebuchet + Pixie Volley) - fun-strong or busted?
5. Act 2 to the Dicelord: theft cadence feel, intent readability (debuff icon + number).
6. Kickstart post-Exhaust: still drafted? Second Wind at Max 6: ever picked?
7. Gold level at mid-act-2 (the pooling watch).

---

*Method note: enemy numbers from `enemies/**` + `battles/*.tscn` + `battle_stats_pool.tres` on
2026-07-27 (post lurker-swap, post defender/satyr 78-retune, uncommitted tree included); card truth
from the 81 pool `.tres` + per-script `dice_roll_reset` scan; picker semantics from
`scenes/enemy/enemy_action*.gd` — note `is_performable()` defaults to FALSE, which is what makes
the Dragonpriest finding real and the fallback-reliance systemic. Extraction scripts live in this
session's scratchpad (`extract_balance.py`, `dump_scripts.py`) — rerun after any pool/enemy change.*
