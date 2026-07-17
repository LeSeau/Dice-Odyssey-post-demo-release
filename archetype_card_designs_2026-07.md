# Archetype deep-dive & card designs — 2026-07-15

Brief from Julien: for each archetype below, propose cards that fill gaps and make the game more exciting. Bias toward **rare candidates** (pool currently has only 5 rares, all damage/finishers). Powerful/slightly-busted is fine. New mechanics welcome (All In precedent). Archetypes are flavors, not hard walls — a "red deck" still plays other dice.

**Status: DESIGNS ONLY — nothing implemented. Awaiting Julien's verdicts.**

---

## 0. What the current 5 rares have in common (and why that's the gap)

Berserker (double Red damage), Crescendo (damage = power generated this turn), All In (spend all dice for damage), Transmutation (convert all dice for a turn), Tidal Force (power above 10 counts double). **All five answer the same question: "how do I turn a big turn into more damage?"** None of them are engines, defense, economy, or control.

The "All In test" for a rare (why that card works so well):
1. The rule fits in one sentence.
2. It does something **dramatic with a resource** (spends everything / breaks a core rule).
3. It creates a **story** ("I Mulligan'd into a second All In").
4. It **changes how you draft and shop** from the moment you take it.

Every design below is aimed at that test. Gap coverage vs the noted missing rare categories: block capstone → **Bastion**; dice-economy → **Mulligan / Gutterball / Regrowth**; scout → **Prophecy**; Evil-0 → **Annihilation**.

---

## 1. Dice spam (many blue/green dice, reward volume of rolls)

**Have:** Gang Up, Electrify, Shattering, Supplication, Emanation, Spark (generators); Dice Slap (consecutive), Tsunami (per-combat count), Crescendo, Hardened Grip (1 block/roll), Critical Edge (payoffs).
**Missing:** an AoE payoff for *this turn's* roll count; anything that makes green dice specifically matter; a rare engine.

### Stampede — Rare Attack, no requirement
> "Deal 3 damage to ALL enemies for each Dice you rolled this turn."

The board-wipe reward for a spam turn. 6 rolls = 18 AoE, a Gang-Up-into-refuel turn hits 30+. Distinct from Dice Slap (single target, consecutive-gated) and Tsunami (single target, per-combat). Impl: `Global.dice_amount_rolled_this_turn` already exists (Metronome reads it).

### Regrowth — Rare Skill (could live as strong Uncommon)
> "Refuel all your Green Dice."

The literal "sucks alone, insane in numbers" card. With 1 green it's a bad Recombobulate; with 6 greens it's a second wave of rolls that re-triggers every per-roll effect (Hardened Grip, Crescendo accumulation, Critical Edge). Works even when green isn't your active type — that's the difference vs Recombobulate. Impl: scoped refuel, emit `refuel_happened`.

### Déjà Vu — Rare Blessing
> "Whenever you roll the same value as your previous roll, Charge 1."

A pure math engine: d6 triggers ~17%, **green d3 triggers ~33%** (the green flood partially self-sustains), and **Evil dice trigger ~62%** (6,6,6,0 — back-to-back 6s constantly). One sentence, two archetypes served, gambling flavor. Impl: compare last two entries of `roll_history`.

### Seed (uncommon): Fertile Soil — Blessing
> "Your Green Dice rolls grant +1 Power."

Blood Sword pattern applied to green (d3 effectively becomes 2–4). Makes greens draftable without a full spam build.

---

## 2. Red gamble & boost

**Have:** Flurry (X2), Kamikaze (X3 + risk), Adrenaline, Berserker (rare), Boost suite (Dynamite/Finesse/Snatch/Fireflies), Blood Sword, House Money, Berserker infusion.
**Missing:** red payoffs beyond 2 attacks; any defensive red card; a Boost capstone; a second "signature" red rare next to All In.

### Powder Keg — Rare Blessing
> "Your Boost no longer expires after a roll."

Boost becomes a permanent +N on every roll for the rest of the fight. Dynamite (Boost 5) turns into "+5 forever". This is the boost-deck capstone and red loves it most (one roll, one payout). Impl: flag skipping the `next_roll_modifier` clear.
⚠️ Watch: Steady Hand (Boost 3/turn) would *stack cumulatively* every turn (+3, +6, +9…). Escalating madness — possibly the fun kind, but flag it.
⚠️ Anti-synergy: permanent Boost breaks MAX gates and From Nothing (can't roll 0 anymore). Honestly good — real deck identity tension.

### Twin Fates — Rare Attack, Red
> "Deal X3 damage. Your Red Die rolls twice and keeps the higher roll."

Advantage rolling — new mechanic, huge feel. Two dice tumble, the better one lands. Average d6 keep-highest = 4.47 vs 3.5, so ~13 avg / 18 max with a much safer floor. It's Flurry that removes the fear. Impl: red-dice roll path in `dice.gd`; visual = roll two, one shatters.

### Skullsplitter — Rare Attack, Red
> "Deal X4 damage. Excess damage hits another enemy."

Overkill carry — new mechanic. A boosted red 6 = 24+ damage that cleaves through a dying enemy into the guy behind. Answers a real tactical annoyance (wasting a monster red roll on a 5 HP target). Impl: `DamageEffect` checks target HP, spills remainder to next enemy in `EnemyHandler`.

### Seeds
- **Revive Enrage** (already on disk, off-pool): "Refuel your active Dice into Red Dice" — the enabler that makes a red build possible without buying 3 red dice.
- **Bulletproof — Uncommon Skill, Red:** "Block X3." Red has zero defensive payoffs; gambling your safety is a fun new decision.

---

## 3. Precision (Exact / Mult)

**Have:** Bullseye, Duo, Doomsday, Gang Up, Unity, Aegis, Eruption (payoffs); Scout suite, Focus, Mech dice, Boost, Reinforce, Refinement (enablers).
**Missing:** a capstone payoff worth building the toolbox for; a scout rare.

### Seventh Seal — Rare Attack, Exact 7
> "Deal 35 damage to ALL enemies."

**7 is the impossible number** — no basic d6 can roll it. You have to *engineer* it: 5+Reinforce, 6+Boost 1, Giant natural 7, Even 6 + Mech +1, Odd 5 + Reinforce… A puzzle printed on a card, with a nuke as the answer. The ribbon alone ("Exact 7") makes players stop and think. Optional safety: Exhaust.

### Prophecy — Rare Blessing
> "Whenever you Scout, ALL revealed faces become your next rolls, in order."

The scout capstone. Scout 3 stops being "pick one guaranteed roll" and becomes "script your next three rolls". Exact decks go deterministic; Foresight/Marionette/Calculations all spike in value. Impl: queue of forced rolls — the FIFO pattern already exists (`tutorial_forced_rolls`); clear the queue on dice-type change, same rule as `next_guaranteed_roll`.

### Seed (uncommon): Turnabout — Skill
> "Invert your last roll (1↔6, 2↔5, 3↔4)."

Serves precision AND low-roll: a dead 2 becomes a 5 for Doomsday setup, a wasted 6 becomes a 1 for Low Blow. Cheeky, tiny, very "dice game".

---

## 4. Low roll

**Have:** Low Blow, Catapult, Low Profile, green dice, From Nothing, Unlucky-as-tech (Occultism), Gnome infusion.
**Missing:** a rare payoff of any kind; an Evil-0 capstone; the "big dumb number" mirror of Dominance/Tidal Force.

### Underdog — Rare Attack, Max 2
> "Deal 30 damage."

The exact mirror of the big-power finishers: a huge flat number gated at *tiny* power. Green d3 hits ≤2 two-thirds of the time; Unlucky forces min face on demand; an Evil 0 qualifies. Simple, absurd, memorable — "my 1 just hit for 30."

### Annihilation — Rare Attack, Exact 0
> "Deal 40 damage." *(spicy version: "Kill a non-boss enemy.")*

The Evil crack-face capstone. Rolling the 0 — the worst moment in the game — becomes a win condition you can chase: Evil dice roll it 25% of the time, **Unlucky on an Evil die forces it** (works reliably since the `-1` sentinel fix), and Scout can find it. Turns the most feel-bad face into the most feel-good card in the pool. Also finally gives From Nothing/Evil decks a second payoff.

### Gutterball — Rare Blessing
> "Whenever you roll a 2 or lower, Charge 1."

Low rolls refund themselves. Greens become nearly self-sustaining (~3 rolls per die on average — bounded, not infinite), blue 1s stop hurting, and Evil 0s recharge the die that betrayed you. Overlaps conceptually with the Gnome infusion (roll 1 → charge blue) but as a draftable build-around rather than act-2 spice — worth keeping both since infusions are once-per-run.

---

## 5. Refuel madness

**Have:** Recombobulate, Catalyst, Voodoo, Supplication, Perpetual Motion, Flywheel/Fuel-o-meter/Overflow Valve relics. Payoffs are all indirect (more rolls → Grip/Crescendo/magma).
**Missing:** refuel as a *payoff*, not just a means; a rare.

### Mulligan — Rare Skill, Celestial, Exhaust
> "Refuel ALL your Dice."

Every die of every type, back to full. It's All In's mirror image — one spends everything, one refills everything — **and playing them in the same turn is the dream combo the archetype deserves.** Celestial matters: the moment you want it is exactly when you're at 0 dice. Late game with 10+ owned dice this is basically a bonus turn. Exhaust is mandatory.

### Backdraft — Rare Blessing
> "Whenever you Refuel, deal 5 damage to ALL enemies."

Turns every Recombobulate/Catalyst/Voodoo/Supplication/Perpetual Motion trigger into a magma pulse. Suddenly the refuel deck has a win condition instead of just stamina. Impl: listen to `Events.refuel_happened` (no loop risk — refuel never triggers itself).

---

## 6. New archetype pitches

### A. Rainbow / type-hopping (anti-mono)
The core rule — switching dice type resets Power — makes owning many types a liability. One rare flips that into a build:

**Kaleidoscope — Rare Blessing**
> "Changing Dice type no longer resets your Power."

Chain green → blue → giant → magma and keep banking. Voodoo (refuel into a *random* type) goes from cute to amazing; shop dice-hoarding becomes a strategy; magma can be woven into any chain for free AoE. ⚠️ Watch: it's near-universally good — but mono decks get little, so in practice it's build-enabling. It also deliberately steps *near* Transmutation without replacing it (Transmutation makes everything one type for a turn; Kaleidoscope makes types irrelevant forever).

**Prismatic Burst — Rare Attack**
> "Deal 5 damage to ALL enemies for each different Dice type you rolled this turn."

The payoff that makes you actually roll the weird dice. 4 types = 20 AoE. Impl note: needs a parallel type-history next to `roll_history` (small addition — values alone aren't enough today).

### B. Fortress (block payoff)
Bulwark (damage = Block), Juggernaut, Unity, Dominance already exist — the archetype is 80% built and missing only its keystone:

**Bastion — Rare Blessing**
> "You no longer lose your Block at the start of your turn."

The proven STS-Barricade archetype-maker. Bastion + Hardened Grip (1 block per roll) + dice spam = a tower that Bulwark converts into a cannon. Impl: skip the block reset in `player_handler.gd` start-of-turn (one flag).
Bonus cheap win: **Cracking** already exists on disk off-pool ("Deal damage equal to your Block. Lose all block") — revive it as the fortress deck's alternate finisher.

### C. Giant / threshold (seed only)
Giant dice have no identity beyond "big number." One seed: single-roll thresholds only a d12 (or Bulky infusion) can hit — *"Seismic Slam — Uncommon: If your last roll was 7 or higher, deal 20 damage."* Cheap to add, gives Giant dice a reason to exist mid-shop.

---

## 7. Shortlist — strongest rare candidates by the All In test

1. **Mulligan** — one sentence, dramatic resource swing, All In's soulmate.
2. **Powder Keg** — breaks a core rule (Boost expiry), warps drafting instantly.
3. **Prophecy** — scout capstone, makes a whole enabler suite sing.
4. **Bastion** — proven archetype-maker, completes an 80%-built deck.
5. **Annihilation** — most feel-bad moment → most feel-good card.
6. **Kaleidoscope** — the boldest rule-break; watch its universality.

Second tier (still rare-worthy): Stampede, Twin Fates, Seventh Seal, Underdog, Gutterball, Déjà Vu, Backdraft, Skullsplitter, Regrowth, Prismatic Burst.

## 8. ROUND 2 (same day) — Julien's refined brief

New inputs: (1) the game needs BIG cards for late-run or players will dump 20 power into a starter Strike in act 3 = failed design — use rarity + an offer-gating system so Min 12/Min 18 cards never appear early act 1; (2) what makes All In great = warps how you think the turn + big dopamine spectacle + introduces a new mechanic (rolling dice as part of the card) — wants more cards with those properties, ok with "deal X and also Y" IF the effect is fun, rares preferred; (3) unexplored mechanic: "Next turn, X" delayed setups; (4) "your <dicetype> gets <bonus>" cards parked for later (unplayable-if-you-don't-own-the-type problem).

### 8.0 The scaling analysis

Strike never gets *worse* — "Deal X" is ratio 1.0 per power with no gate. It gets **outcompeted** only when better ratios are reliably live. The ratio ladder already exists (Flurry X2 → Bullseye/Low Blow X3 → Doomsday X4) but its gates are all early-game-sized. The missing piece is the top of the ladder (Min 12/15/18 cards) plus a system so the top doesn't pollute act-1 rewards.

**Offer-gating mechanism:** new `@export var min_act: int = 1` on Card, filtered in ONE place — `CardRarityDraw.pick_card()` (already the shared draw helper for rewards + shop, already does owned-rare exclusion). Explicit field > deriving from requirement_number (also lets non-MIN epics be gated). Nice detail: the act-1 **boss reward** should offer `min_act = 2` cards — you're about to enter act 2, that's exactly when "here's your act-2 weapon" feels like a trophy.

### 8.1 Family: the All In family (cards that ROLL DICE when played)

Design fork, decided by All In precedent: cast-time rolls are **pure rolls** — they don't enter the power pipeline (no roll_history, no per-roll triggers, no bank interaction). Loops impossible, the bank stays sacred, and the synergy comes from debuffs/timing instead. Visual grammar already exists (All In's consumed-dice flourish, Scout's flying die): dice fly out of the card and tumble onto the target.

- **Open Season — Rare Attack.** "Apply Exposed 2. Then roll 3 Blue Dice at the target: each deals its roll as damage." Debuff lands FIRST, barrage benefits, Exposed persists for the rest of your turn. Variant with bigger swing: **Skyfall** — 1 Giant Die instead of 3 Blue (1–12, all-or-nothing).
- **Reverberate — Rare Attack.** "Deal double your last roll as damage. Does not reset your Power." (Julien's "re-summon last roll".) Timing puzzle: play it the instant a Giant 12 lands = 24 damage WITHOUT breaking the chain, keep banking. No-reset attack precedent: Shockwave. Visual: ghost die materializes showing the echoed face.
- **Second Harvest — Rare Attack.** "Deal X damage. Then reroll every Green Die you rolled this turn: each deals its roll as damage." (Julien's idea.) Needs a per-turn type-history array next to roll_history — same plumbing Prismatic Burst needs.
- **Domino — Rare Attack.** "Deal X damage. If the target dies, roll a Red Die: it deals triple its roll to another enemy. If that kills too, repeat." Chain-execution casino.
- Seed (uncommon): **Dice Wall** — "Roll 3 Blue Dice: gain Block equal to the total."

### 8.2 Family: Monuments (big-gate scaling finishers, min_act-gated)

- **Guillotine — Rare Attack, Min 15, min_act 2.** "Deal X3 damage." 45+ single-target — the boss-ender; the card that makes a 15-bank feel earned.
- **Cataclysm — Rare Attack, Min 12, min_act 2.** "Deal X2 damage to ALL enemies." (Cheap alt: revive off-pool Equilibrium — identical text — and stamp Min 12 + rare on it.)
- **Reckoning — Rare Attack, Min 12, min_act 2.** "Deal X damage plus a quarter of the target's Max HP." Auto-scales with act HP inflation — the anti-scaling-treadmill card.
- **Coronation — Rare Skill, Min 12, min_act 2.** "Gain Strength equal to a third of your Power." A non-damage monument: the bank buys permanent scaling instead of burst.
- **Extinction — Rare Attack, Min 18, min_act 2 (or 3). Exhaust.** "Deal X4 damage." 72+. The run trophy — exists to be screenshotted.

### 8.3 Family: Omens ("next turn" setups)

Keyword pitch: **"Omen:" = at the start of your next turn.** One keyword, one tooltip entry, reusable forever. Impl: statuses already support START_OF_TURN + duration-1 expiry; `starting_power_next_turn` (Stockpile/Tension) is the precedent for turn-crossing state. Self-balancing niche: delayed payoffs are worthless in dying fights, great in elite/boss fights — exactly the late-run space.

- **The Calm — Rare Skill.** "Gain 8 Block. End your turn. Omen: your Dice refill at DOUBLE their maximum." Sacrifice a whole turn for a god-turn — the spam deck's ritual (Stampede/Crescendo/Hardened Grip all explode).
- **Red Dawn — Rare Skill.** "Omen: your first Red roll adds the rolls of ALL your Red Dice." (Julien's idea.) Socket Flurry into a 3-red salvo = X2 on 3d6.
- **Gathering Storm — Uncommon Skill.** "Omen: Charge 3 Blue Dice." The clean delay-discount template (bigger than instant equivalents, no downside, but later).
- Seeds: "Omen: your Blue Dice grant +2 Power per roll" / "Omen: rolling a 6 grants 6 Block" (Julien's examples, uncommon-tier).

### 8.4 Parked: "your <dicetype> gets <bonus>" cards

Three unlock patterns for later: (a) **self-enabling** — the card grants the dice AND the bonus ("Charge 2 Green Dice. This turn, Green rolls grant +2 Power"), never dead; (b) word it against the **active type** instead of a named type; (c) **ownership-filtered offering** — CardRarityDraw can see owned dice types, same touchpoint as min_act filtering. Not designed further per Julien.

## 9. Explicitly avoided
- No revivals of the intentionally-cut blessings (Precision Engine, Counterweight, Guard Stance, Lucky Sevens) or cut cards (Cascade, Jackpot, Resonance, Swipe, Stockpile, Sigil, Executioner, Nova, Slice).
- No multiplier-stacking cards (per the original expansion brief).
- Nothing duplicating an existing effect found in the description sweep of all ~219 `.tres`.
