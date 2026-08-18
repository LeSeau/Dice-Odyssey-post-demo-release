# Card Rework Slate & New Cards — 2026-08-16 (VERDICTS LOCKED)

Julien has ruled on everything below. **Nothing is implemented yet.** This is the build order.

Companion: the review board (**Group → By ladder**) —
https://claude.ai/code/artifact/63a88c58-aa05-4a7a-8570-eff97aea40c2 — taxonomy in
`ladders.py` (session scratchpad).

**The diagnosis this serves** (GPT's phrasing, Julien endorsed): *"lots of interesting individual
mechanics, but not enough deep archetypal structures that make you excited to see a particular
card because of what it enables."* Measured: **10 of 12 ladders incomplete, only 2 orphans** — the
problem is missing rungs, not junk cards. Every entry is tagged with the rung it fills.

**Net pool effect: 80 − 3 cuts + 19 new = 96 cards.** Julien on the size: *"yeah pool gets too big
but i'll cut boring cards after"* — a trim pass is expected once these are in and playable.

---

## 1. Changes to existing cards — LOCKED

### 1.1 Cuts (3)

| card | reason |
|---|---|
| **Perpetual Motion** | "Way too strong", no rework worth saving |
| **Spark** | "Not interesting" — a goodie bag with no identity; 11 Celestials can afford the cut |
| **Low Profile** | Rework considered (draw / +block) and rejected — cut instead |

Files stay on disk per convention; they're removed from `warrior_draftable_cards.tres` only.

### 1.2 Reworks (6)

| card | from | to | rung |
|---|---|---|---|
| **Necromancy** | Charge 1 Evil Dice | **Max 3: Charge 2 Evil Dice** | sixes / enabler — becomes the Low Roll ↔ Evil bridge |
| **Rampart** | throw a Ricochet Dice | throw a **Blue** Dice | throw — obeys the throw-die rule (§1.4) |
| **Cursed Toss** | throw a Golem Dice | throw an **Evil Dice**<br>**Cursed Toss+ → 2 Evil Dice** | throw / sixes — 75% six, 25% crack-for-0; a free Celestial *should* gamble, and the art is already a purple cursed figure |
| **Rupture** | Min 6: X dmg + Exposed 2 | **Deal X damage. The enemy takes 3 damage each time you roll a Dice this turn** | volume / payoff — ⚠️ **ROLL, not throw** (confirmed). Inverts sequencing: play at 0 Power, then roll *into* it. Fills volume's single-target gap |
| **Dominance** | Min 10: Exposed 2 AoE + X Block | **Min 8: Deal X damage, twice against Exposed enemies** | **exposed / payoff** — this is the card previously drafted as "Open Wound". Reworked **in place** (keeps name, art, uid, pool slot); Exposed had 4 applicators and 0 payoffs |
| **Supplication** | Celestial: if no Dice left, Charge 3 Pixie | **Charge 2 Pixie Dice. Gain Loaded 1** | lowroll / enabler — ⚠️ **the one item Julien never explicitly ruled on** (asked twice). Proceeding on his original complaint (*"the requirement is annoying… I like the idea of giving pixie dice though"*). Blocked on Loaded, so it lands in Batch 2 — easy to veto before then |

### 1.3 Rarity move (1)

| card | change | why |
|---|---|---|
| **Earthquake** | Common → **Rare**, numbers unchanged | The drop rate *is* the nerf (≈3%/slot vs 60%). Zero values to re-playtest, and it already feels rare |

### 1.4 Relic change (1)

| relic | from | to |
|---|---|---|
| **Runic Bones** | "Each turn, the first time you Charge a Dice from a card or a relic, gain **4 Block**" | "…**draw 2 cards**" — **replaces** the block, not additive |

### 1.5 Explicitly kept unchanged

**Coiled Spring** ("creates very fun turns"), **Voodoo** ("very fun"), **Kickstart** ("is cool"),
**Tsunami**, **Meteor** (variance complaint withdrawn — keep the Giant throw), **War Ritual**
(similarity to Compound accepted — no Red rework), **Smash**.

### 1.6 Standing design rules from this pass

- **Throw-die rule** — only throw dice whose identity **is their faces**: Blue, Red, Giant, Pixie,
  Evil. Mechanic dice (Golem = carryover, Ricochet = reroll, Mech = ±1, Magma = AoE-on-roll)
  advertise a rule a one-shot conjured die immediately breaks.
- **Charge is a verb, not an archetype** — a charge belongs to the ladder the charged *die* serves.
- **No new mechanic without its ladder** — ship an enabler, a payoff and a planned concluder, or
  explicitly demote it to spice.

---

## 2. New cards — LOCKED (19 cards + 1 relic)

### 2.1 No new systems needed (7 cards)

| name | text | rung |
|---|---|---|
| **Socketless Red** | *Blessing:* you may roll the Red Dice with an empty socket. It deals X damage to ALL enemies | **red / enabler** — ⚠️ **Berserk DOES double this** (confirmed) |
| **Red face trim** | *Blessing:* remove the 2 lowest faces from Red Dice this combat | red / enabler — Red becomes 3/4/5/6, and **Kamikaze's "if you roll a 1" clause stops existing**. Uses `DiceInfusions.roll_values_override` |
| **Counterfeit** | *Exact 6:* this combat, your active die's highest face replaces its lowest | sixes / enabler — Blue becomes 2/3/4/5/6/**6**. Same override plumbing |
| **Keep your dice** | End your turn. Keep your Dice for next turn | volume / enabler — Golem's refill exception is the template. Fair now that enemies ramp |
| **Consecutive burst** | *Max 6:* deal 7 damage per consecutive Dice roll | lowroll / payoff — **the two conditions fight each other**; solvers already in pool (Pixie ×3, deliberate Unlucky, Mech −1) |
| **Kaleidoscope** | *No requirement:* this turn, switching Dice types does not reset your Power | aoe / enabler — the fair-sized Attunement |
| **Reservoir** | *Blessing:* when a card resets your Power, keep 5 | chain / engine |

### 2.2 Needs the Loaded status (2 cards)

| name | text | rung |
|---|---|---|
| **Loaded 2** | *No requirement:* gain Loaded 2 this turn | volume / enabler |
| **Loaded 1** | *Min 5:* gain Loaded 1 for the rest of combat | volume / enabler |

### 2.3 Needs a dice-type counter (2 + 1 relic)

| name | text | rung |
|---|---|---|
| **Rainbow nuke** | For each Dice type you have rolled this turn, deal 4 damage to ALL enemies | **aoe / payoff** — new archetype; nothing else reads type diversity. Self-balancing: switching types costs your chain |
| **Fluorescent relic** | *Relic:* if you roll 4 different Dice types in one turn, Charge a random different Dice | aoe / engine — self-accelerating |

### 2.4 Needs a sixes-this-fight counter (2 cards)

| name | text | rung |
|---|---|---|
| **Jackpot** | *Exh:* deal 6 damage for every 6 you rolled this fight | **sixes / concluder** — Evil (75% sixes) becomes the best fuel in the game |
| **Effigy** | Curse an enemy: whenever you roll a 6 this combat, it takes 8 damage | sixes / payoff — single-target sixes |

### 2.5 Needs in-hand passives (3 cards)

| name | text |
|---|---|
| **In-hand Red aura** | While this is in your hand, your Red Dice rolls gain 3 bonus Power | ⚠️ needs a real *play* effect too, so holding is a choice — and a visual held-state or nobody believes it works |
| **Talisman** | While in hand: your dice cannot roll their lowest face. *Play:* reroll your last roll |
| **Dead Weight** | While in hand: Loaded 1. Cannot be played. Exhausts at end of turn |

### 2.6 Needs die-ability grafting (1 card)

| name | text |
|---|---|
| **Blue reroll** | *Blessing:* your Blue Dice gain the reroll ability | ⚠️ opens "any die can borrow any die's power" as a family — players will ask for the rest |

### 2.7 Needs the second Red socket (1 card) — most expensive item on the list

| name | text |
|---|---|
| **Second socket** | You get a second card socket on the Red Dice | **red / concluder.** ⚠️ **One roll fires BOTH sockets** (confirmed). Socket state is singular throughout `dice.gd` / `card_released_state.gd` — `socketed_card_ui`, `charged_card_instance_id`, one drop area |

### 2.8 Others

| name | text | rung |
|---|---|---|
| **Artillery** *(was "Siege Engine")* | *Blessing, Min 6, Exh:* at the start of each turn, throw a Dice of a random type you own at a random enemy | **throw / engine** — free Trebuchet scaler, very clippable |
| **Greed** *(was "777")* | *Exact 7:* deal 7 damage, gain 7 Block, gain 7 Gold. Exh | precision / payoff — Refinement is the stealth 7s tutor |

---

## 3. Not taken (parked, not dead)

- **All of §2.5 in the old doc — card draw & turn planning.** Premeditation, Held Action, Sleight
  of Hand, Sixth Sense, Encore, Stasis, Second Sight. Julien: *"not fan of the ideas there, will
  think later about more draw."* **Draw stays at 4 cards in 96 — the thinnest ladder in the pool.**
- **Rule-breakers:** Attunement, Cascade, Perfect Memory, Blood Pact.
- **Roll/dice manipulators:** Humility, Fortune's Favor, Fine Tuning, Escalation, Whetstone,
  Wild Die, Rewind, Resonance, Dice Tower.
- **Payoffs:** Ritual Scars, Colossus, Executioner's Mark, Loaded Dice.
- **Families:** Steady Grip, Echo Socket, Spellbreaker, Full Spectrum.
- **Runic Bones as a *card*** — resolved by changing the relic directly instead (§1.4).

**Ladder holes still open after this batch:** Low Roll engine (Humility was the fix), Volume
concluder (Dice Tower), Strength engine (Ritual Scars, still 3 cards), and card draw. Worth a
conscious re-look after playtest.

---

## 4. Systems to build

| system | needed by | cost |
|---|---|---|
| **Loaded status** (rename dormant `Infused` → `Loaded`; +N Power per roll) | Loaded 1/2, Dead Weight, Supplication | **Cheap** — mirror of enemy Weak through the same modifier path, sign flipped. Only live user of `Infused` is Rainbow, which isn't in the pool. ⚠️ Must show in the next-roll/Scout panel (Boost's "+N" badge rides here) and must **not** change natural-face triggers (Arcane 6, Gnome 1, Octet 8, Critical Edge) — same ruling already made for Boost |
| **Distinct dice types rolled this turn** | Rainbow nuke, Fluorescent relic | Trivial — a Set in Global, cleared on turn start |
| **Sixes rolled this fight** | Jackpot, Effigy | One fight-scoped counter. Thrown 6s should count (consistent with Hunting Bow) |
| **Rolls-since-played tracking** | Rupture | A short-lived status on the target listening to `dice_rolled` — the Sigil/Parasite pattern |
| **In-hand passives** | In-hand Red aura, Talisman, Dead Weight | New pattern + a visual held-state |
| **Die-ability grafting** | Blue reroll | Ricochet's reroll exists; needs to apply to another type fight-scoped |
| **Second Red socket** | Second socket | **Expensive** — singular socket state throughout |
| **Per-fight face-set override** | Red trim, Counterfeit | **Already exists** — `DiceInfusions.roll_values_override`, already honoured by thrown dice and the Scout preview |
| **Turn-scoped reset suppression** | Kaleidoscope | Eclipse-adjacent |
| **Partial Power reset** | Reservoir | Small change at the reset site |
| **Counter readout UI** | every count-based card above | Small tray-adjacent display (dice rolled this turn / types this turn) — without it these read as slot-machine math |

---

## 5. Batches

**Batch 1 — ✅ DONE 2026-08-16, verified (`debug_batch1_check.tscn`, 27/27), NOT playtested.**
Cut Perpetual Motion / Spark / Low Profile; Earthquake→Rare; Necromancy; Rampart; Cursed Toss
(+ its `+`); Dominance→Exposed payoff; Runic Bones→draw 2. **Closed the Exposed payoff hole.**

**Batch 2 — ✅ Loaded status + both cards DONE 2026-08-16, verified
(`debug_batch2_check.tscn`, 29/29), NOT playtested.** Pool 77 → 79.
- `Global.loaded_amount` + `loaded_expiring`, reset at both run and fight scope
- `statuses/loaded.gd` / `loaded.tres` — replaces the dormant `Infused` (which was a one-shot
  "+2 next roll", i.e. a second Boost, reachable only from out-of-pool Rainbow). START_OF_TURN
  so the turn slice expires and the badge resyncs; INTENSITY so the count shows; never
  self-expires; hides at 0
- `dice.gd::_apply_roll_result` adds it **after** every natural-face trigger, so a Loaded roll
  can't fake a natural 6/1/8 for Arcane / Gnome / Octet / Critical Edge
- **Weighted Dice** (Common, ungated) "Gain Loaded 2 this turn"
- **Loaded Dice** (Uncommon, Min 5) "Gain Loaded 1 for the rest of combat"
- **Supplication: CUT** (Julien, asked at implementation time). The "no Dice left" gate *was*
  its cost — dropping it left a Celestial, keeps-Power card that charges dice for free, and
  neither of the two ways to re-price it (make it a normal Skill, or keep it free but Exhaust)
  was worth keeping. Pixie charging survives on Shattering; Loaded now has two dedicated cards.
- ⚠️ **Dead Weight is NOT in this batch** — it also needs in-hand passives, so it moved to
  Batch 5. (The original batch list was wrong about this.)
- Placeholder art recycled from the cuts: `low_profile.png` (Weighted Dice),
  `perpetual_motion.png` (Loaded Dice). `spark.png` is still free.

**Batch 3 — ✅ DONE 2026-08-16, verified (`debug_batch3_check.tscn`, 36/36), NOT playtested.**
Pool 78 → 81, rares 10 → 12.
- `Global.dice_types_rolled_this_turn` (set, cleared per turn) and `sixes_rolled_this_fight`
  (fight-scoped). Both fed by real rolls **and** thrown dice; sixes keyed on the natural face.
- **Spectrum** (Unc, AoE) "For each Dice type you have rolled this turn, deal 4 damage to ALL
  enemies" — the rainbow payoff
- **Prismatic Lens** (relic, both relic pools) — 4 types in a turn → Charge a type you have not
  rolled
- **Jackpot** (Rare, Exhaust) "Deal 6 damage for every 6 you rolled this fight" — **closes the
  Sixes concluder hole**
- **Effigy** (Unc) "Curse an enemy: whenever you roll a 6 this combat, it takes 8 damage"
- **Rupture** reworked to the per-roll bleed (`statuses/ruptured.gd`)
- ⚠️⚠️ **THE RED ROLL SIGNAL TRAP — get this exactly right, a half-understanding of it caused
  both bugs Julien found on 2026-08-16.** `dice.gd` does not emit `dice_rolled` for Red; it
  emits `red_dice_rolled`. **But `card_ui.gd:909` re-emits `dice_rolled` immediately after a
  socketed card plays.** So:
  - A **socketed** Red roll raises **BOTH** signals → anything listening to both fires **twice**
    (this was Rupture dealing 3 damage twice).
  - That re-emit is also **the only thing in the game that decrements the Red die**, because the
    decrement lives in `dice_interface._on_dice_rolled`. With an empty socket it never runs →
    the die is rolled for free (this was the socketless-Red bug).
  - `dice_rolled` carries the **accumulated Power**, not the rolled face — use `Global.last_roll`
    for any face check.

  **Rules for any future roll-reactive thing:** listen to `dice_rolled` + `red_dice_rolled` +
  `dice_thrown_landed` for coverage, then **dedupe on `Global.fight_dice_rolled`** (it ticks
  once per real roll and once per thrown-die landing) so the double emit can't double-fire.
  `RupturedStatus._consume_roll_token()` / `EffigyStatus._consume_roll_token()` are the pattern.
  Regression: `debug_redroll_bugs.tscn`.
- ⚠️ Rupture moved off the Exposed ladder, so **Exposed is back down to 3 cards** (2 appliers,
  1 payoff — the reworked Dominance).
- ⚠️ The five new cards have **no `+` upgrade versions yet** (campfire can't upgrade them).
- ⚠️ **Tray counter readout NOT built.** The dynamic descriptions resolve live
  ("…deal 4 damage to ALL enemies (12)"), which covers the functional need; a persistent
  readout near the dice tray is still the nicer answer and is unbuilt.

**Batch 4 — ✅ DONE 2026-08-16, verified (`debug_batch4_check.tscn`, 39/39), NOT playtested.**
Pool 81 → 90. **Red is now a complete ladder.**

Cards: **Socketless Red** · **Red Edge** (trim 2 lowest Red faces) · **Counterfeit** (Exact 6) ·
**Hoard** (end turn, keep your dice) · **Cadence** (Max 6, 7 dmg per consecutive roll) ·
**Kaleidoscope** · **Reservoir** · **Greed** (Exact 7) · **Artillery** (throw engine).

Four engine changes, all with their own risks:
- **Fight-scoped face-edit layer** — `Global.face_overrides` + `Global.current_face_values()`,
  the single source of truth. Layered ON TOP of a dice infusion's set, and computed at play
  time from the *effective* faces so trims stack. ⚠️ **Four consumers must stay in step**:
  the roll (dice.gd), the **Scout preview** (battle.gd), thrown dice
  (`Card.thrown_faces_for`, now just delegates), and any future one — a missed consumer means
  the preview shows a face the die cannot roll.
- **Socketless Red** — the red roll gate accepts an empty socket under the blessing, and
  `dice.gd::_fire_socketless_red` deals the AoE. Routed through the **player's DMG_DEALT
  modifiers**, because that is literally how Berserk doubles it (a PERCENT_BASED modifier that
  switches on while Red is active). ⚠️ Side effect: **Strength applies too**, unlike magma's
  flat per-roll burn. Deliberate, and a tuning dial.
- **Kaleidoscope / Reservoir** — the type-switch wipe and the card reset now both consult a
  flag. Reservoir only ever *lowers* Power to its floor, never adds.
- **Hoard** — every type's leftovers stashed at turn end and re-added on refill, mirroring
  Golem's carryover. ⚠️ **Golem is excluded from the stash** so the two can't double up.

Watch items: `keep_power_on_type_change` is turn-scoped (player_handler), everything else is
fight-scoped (battle.gd) — both cleared in `reset_run_state()` too. Placeholder art recycled
from cut cards throughout; `spark.png` is still free.

**Batch 5 — expensive fantasies.** Second socket, in-hand passives, Blue reroll.

---

## 5b. Playtest checklist (Batches 1–4, pool 90)

Nothing below has been played. Ordered by *what could actually be broken*, not by batch.
131 harness checks pass, but every one of them is data/logic — **none of it has been seen
on screen.**

### Tier 1 — could be silently broken, test first

| # | test | why it could fail |
|---|---|---|
| 1 | **Loaded**: play Weighted Dice, roll, confirm Power jumps by +2 per roll and the badge reads 2 | The whole status is new. If the badge shows but Power doesn't move, the dice.gd hook is misplaced |
| 2 | **Loaded expiry**: play Weighted Dice, end turn — badge must drop to 0/vanish next turn. With Loaded Dice (Min 5) too: 3 this turn → 1 next | The trickiest logic in the batch; the badge has to resync *downward* |
| 3 | **Loaded must NOT fake natural faces**: with Loaded up, roll a natural 5 on infused Blue — Arcane's AoE must **not** fire. Same for Gnome (1), Octet (8), Critical Edge | Explicitly coded for; if wrong, every face trigger becomes unreliable |
| 4 | **Red rolls fire the new triggers**: with Effigy on an enemy, roll a **Red** 6 — it must take 8. Same for Rupture's bleed and the Prismatic Lens counter | `dice_rolled` is *not emitted for Red*. Handled, but this is the trap most likely to have been missed somewhere |
| 5 | **Red Edge**: play it, then open the dice tray and Scout — Red must show **3/4/5/6** everywhere (roll, Scout preview, thrown Red) | Four consumers of the face list must agree; a mismatch means Scout lies |
| 6 | **Counterfeit**: on Blue, faces become 2,3,4,5,6,**6** — check the second 6 renders (same texture twice) | Face textures are loaded by `"<type><value>.png"`; duplicates are new |
| 7 | **Hoard**: leftover dice carry to next turn — and Golem's carryover does **not** double | Golem is excluded from the stash; if that's wrong Golem doubles |
| 8 | **Socketless Red**: roll Red with an empty socket → AoE damage, and the roll is consumed | New branch in the roll gate |
| 9 | **Dominance**: on an Exposed enemy it must hit **twice** (two popups). Kill it with the first hit — the second must not error | Second hit is a deferred timer with a re-validated target |
| 10 | **Rupture**: play at 0 Power, then roll 3-4 times — 3 damage per roll, badge gone next turn | Turn-scoped EVENT_BASED status has to expire itself |

### Tier 2 — works, but might feel wrong

- **Necromancy** is now Max 3 — it went from always-playable to only on a bad roll. Biggest
  feel change in Batch 1.
- **Cursed Toss** throws Evil: 25% of the time it does **0** (crack face). Does that read as a
  gamble or as a bug? The crack sound should fire.
- **Runic Bones** draws 2 instead of 4 Block — does losing the block hurt more than the draw helps?
- **Artillery**: a die flies every turn. Watch the timing — does it collide with the turn-start
  animation queue?
- **Prismatic Lens** counter label: does it show 0–4 and reset each turn?
- **Greed**: gold going up mid-fight — is it legible?
- **Jackpot / Spectrum** read their counters live in the description. Without a tray readout,
  is "(30)" enough to understand *why*?

### Tier 3 — balance watch

- **Socketless Red × Berserk** — confirmed doubling, and **Strength applies too**. Likely the
  strongest thing in the four batches.
- **Kaleidoscope + Spectrum** — keep the chain *and* go rainbow. The combo flagged as dangerous.
- **Second-socket-free Red decks** generally: Red now has a full ladder for the first time.
- **Loaded vs Exact** — your original worry. Loaded 1–2 should still allow Exact play; the
  Loaded engine deck is meant to be walking away from Exact.
- **Pool at 90** with 12 rares. Draft variety, and whether the 16 new cards actually show up.

### Tier 4 — quick sanity

Perpetual Motion / Spark / Low Profile / Supplication gone from rewards · Earthquake only
appears as a Rare · Rampart throws Blue · Cadence at Max 6 · Reservoir keeps 5 through a reset ·
Kaleidoscope keeps Power across a type switch.

---

## 5c. What is left for Batch 5

**Cards (5)** — all blocked on systems that do not exist yet:

| card | text | blocked on |
|---|---|---|
| **Second socket** | Second card socket on the Red Dice; one roll fires **both** | Socket state is singular throughout `dice.gd` / `card_released_state.gd` (`socketed_card_ui`, `charged_card_instance_id`, one drop area). Much the biggest job here |
| **In-hand Red aura** | While in hand, your Red Dice rolls gain 3 bonus Power | In-hand passive system + a visual held-state. Needs a real *play* effect too, so holding is a choice |
| **Talisman** | While in hand: dice cannot roll their lowest face. *Play:* reroll your last roll | Same system + the face-edit layer (which now exists) |
| **Dead Weight** | While in hand: Loaded 1. Cannot be played. Exhausts at end of turn | Same system. Loaded already exists |
| **Blue reroll** | *Blessing:* your Blue Dice gain the reroll ability | Die-ability grafting. Opens "any die can borrow any die's power" as a family |

**Systems (3):**
1. **In-hand passives** — a new card class that does something while held, plus a held-state
   visual or players won't believe it works. Serves 3 of the 5 cards.
2. **Second Red socket** — the expensive one.
3. **Die-ability grafting** — Ricochet's reroll applied to another type, fight-scoped.

**Also outstanding, not in any batch:**
- **Tray counter readout** (deferred from Batch 3) — dice rolled this turn / types this turn.
  The count-based cards currently rely on their own resolved descriptions.
- **14 cards have no `+` upgrade version** and so cannot be upgraded at a campfire: Artillery,
  Cadence, Counterfeit, Effigy, Greed, Hoard, Jackpot, Kaleidoscope, Loaded Dice, Red Edge,
  Reservoir, Socketless Red, Spectrum, Weighted Dice.
- **Placeholder art** on all 16 new cards (recycled from cuts). `spark.png` still free.
- **The trim pass you flagged** — "I'll cut boring cards after". Pool is 90.
- **Ladder holes still open:** Volume concluder (26 cards, nothing to build toward — Dice Tower
  was the proposed fix), Low Roll engine, Block concluder, Sixes engine, AoE, Throw payoff,
  Card draw (everything), Exposed, Strength.

---

## 6. Playtest watch list

1. **Kaleidoscope + Rainbow nuke** — Kaleidoscope shipped *ungated*, so: roll five types without
   losing your chain, then nuke for 20 AoE on top of a full-size X. Cheap two-card assembly. If
   anything here needs a limiter after playtest, it's this pair.
2. **Socketless Red × Berserk** — confirmed doubling, so a stack of Red dice is an artillery
   battery. Interacts with Blood Sword and House Money for free.
3. **Second socket** — one roll, two cards, both doubled by Berserk. The ceiling is very high.
4. **Rupture** — 3 damage × rolls-after can be large in a volume deck; it also rewards playing a
   card at 0 Power, which no other card does.
5. **Pool at 96** — Julien expects to cut boring cards after these are playable.
