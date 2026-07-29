# Lurker ↔ Oculus role swap — spec (2026-07-24)

**STATUS: IMPLEMENTED 2026-07-24 — see section 9.** Sections 1-8 are the approved spec.
Julien's one amendment: **no Strength escalation on the Lurker** (flat 6 damage every turn),
so section 2's "+2 Strength per attack" and section 7 step 5's self-buff were NOT built.
Art/textures untouched throughout — only HP, damage, statuses, AI wiring and fight
assignment changed. NOT PLAYTESTED.

---

## 1. Why: their mechanics are on the wrong bodies

Read from the actual scripts, not from memory:

| | **Lurker** (36 solo / 47 paired) | **Oculus** (20) |
|---|---|---|
| status | **Flux** — "prevents you from rolling the same Dice type twice in a row" | **Parasite** — +3 Strength if you generate >15 Power in one turn |
| nature | **removes agency** — Power accumulates by rolling the same type consecutively, so Flux switches the core engine off. No counterplay except killing it. | **punishes a choice** — stay under 15 and it never fires. Fully opt-in. |
| AI | T1 hit 10 → T2 self Muscle +2 → T3 hit 12 | hit 7 → Muscle +3 → hit 10 → hit 10 → Muscle +3 → hit 13 → … |
| lifespan at current HP | 4–6 turns | ~2 turns |

The mismatch is exact:

- **Flux is un-counterable, and it's attached to the longest-lived body in tier 1.** That is
  precisely "really annoying" — the player has no lever, for many turns.
- **Oculus's AI is already a ramping scaler** (its own Muscle stack *plus* Parasite), but at
  20 HP it dies on turn 2 and the ramp never gets to happen. Its whole design is invisible.

Your own balance notes already flagged the symptom:
> *"Lurker+Crab (tier 1, gateway fight) felt like a wall … Flux (anti-bank) from turn 1 …
> I can tell right away I'm gonna lose a ton of HP."* (~66 combined EHP)

So the swap isn't cosmetic — it puts each mechanic on the body length that lets it work.
**HP is what decides whether a mechanic is a puzzle or a tax.**

### Bug found while reading this
`LurkerEnemyAI`'s chain **dead-ends**. `lurker_first_attack` requires `Global.fight_turn == 0`,
`lurker_block` requires last == first_attack, `lurker_second_attack` requires last == block.
After the second attack **no action is performable**, so from turn 4 on the Lurker's behaviour
is whatever the picker's fallback does. Worth fixing regardless of this swap.
(Also: `lurker_block_action` grants Muscle 2 and **no Block at all** — the name is a lie.)

---

## 2. New stat blocks

### Lurker — "burst me down" (squishy lockout)

| | now | proposed |
|---|---|---|
| HP (tier 1) | 36 | **18** |
| HP (tier 2) | 47 | **22** |
| damage | 10 → 12 | **6, +2 Strength per attack** (6 → 8 → 10 → 12) |
| self-buff turn | Muscle +2 on its own turn | **removed** — it attacks every turn |
| Flux | from turn 1 | **unchanged, from turn 1** |

**Design intent:** its threat is Flux, not damage. It attacks *every* turn and gets +2
Strength each time, so ignoring it escalates — that's the pressure to kill it now. Two turns
of focus removes it (see §5 for why not one).

### Oculus — "punish greed" (tanky scaler)

| | now | proposed |
|---|---|---|
| HP (tier 1) | 20 | **44** |
| HP (tier 2, if used) | — | **56** |
| base damage | 7 | **7** (unchanged — already in the doc's 6–9 tier-1 band) |
| own buff | Muscle **+3** | **Muscle +2** (so its two ramps don't compound absurdly) |
| Parasite | +3 Strength if >15 Power in a turn | **+2 Strength if >15 Power in a turn** (threshold shipped at 18, reverted to 15 on 2026-07-28 — 18 sat above a normal turn so the punish almost never fired) |
| AI | unchanged | unchanged |

**Damage curve at 44 HP (~5 turn fight):**

| | T1 | T2 | T3 | T4 | T5 |
|---|---|---|---|---|---|
| disciplined (never >15 Power) | 7 | buff | 9 | 9 | buff → 11 |
| greedy (>15 every turn) | 7 | buff | 11 | 13 | buff → 17 |

That's the tension you wanted: going fast makes it hit much harder, and it's entirely the
player's call.

---

## 3. Status retunes

- `statuses/parasite.gd`: `muscle.stacks` **3 → 2**, threshold `> 15` → **`> 18`**.
  **This threshold is the main dial.** At 44 HP the player *needs* bigger turns to kill it,
  so a 15 threshold would fire nearly every turn even for careful play — which deletes the
  choice. 18 keeps "go slow and safe vs fast and punished" a real decision.
- `statuses/flux.gd`: **no change.**

---

## 4. Fight / pool reassignment

The fights themselves stay; which enemy stands in them flips. This also fixes the documented
"wall" fight.

| fight | now | proposed | total EHP |
|---|---|---|---|
| `tier_1_lurker` (solo) | Lurker 36 + Flux | **Oculus 44 + Parasite** | 36 → **44** |
| `tier_1_oculus_goblin` (pair) | Oculus 20 + Goblin 22 | **Lurker 18 + Flux, Goblin 22** | 42 → **40** |
| `tier_1_lurker_crab` (pair, battle_tier 2) | Lurker 47 + Crab 31 = **78** | **Lurker 22 + Crab 31** | 78 → **53** |

Rationale:
- **A low-HP annoyance is pointless solo** — you'd kill it before it does anything. Lurker's
  best expression is beside a real threat: *"do I spend this turn unlocking my engine, or on
  the dangerous one?"* That's a genuine decision; solo it's a non-fight.
- **Oculus needs a long fight to express its ramp**, and solo is where it gets one.
- Pair totals of 40/53 look low against the doc's 55–65 tier-1 pair target, but **Flux is
  worth roughly 15–20 "virtual EHP"** — it roughly halves your Power throughput while it's
  up. 53 for lurker+crab directly answers the "wall" complaint (was 78).

---

## 5. Known tension: Flux fights the plan it demands

Flux blocks chain-rolling — which is exactly how you'd burst the Lurker down. Measured
against the starting kit: under Flux you must alternate dice types, and switching type
resets Power, so you're capped at roughly one roll's worth of Power per card. Turn-1 burst
drops from ~14 to **~8–10**.

That's why **18 HP, not 10**: at 18 it's a *two-turn* focus, which is a real cost without
being a coin-flip. Getting a true one-turn kill would need ~10 HP, too flimsy for tier 1.

**Alternative if two turns still feels bad in play:** have Flux start on the Lurker's
*second* turn, so turn 1 is a clean burst window. I'd try 18 HP first and only reach for
this if it still grates.

---

## 6. Free consequence: sizes fix themselves

The size ladder is HP-driven, so re-running it after the HP change auto-resizes both — and
it happens to read exactly right:

| | now | after |
|---|---|---|
| Lurker (paired) | 243px | **~178px** (S band) |
| Oculus (solo) | 179px | **~271px** (L band + solo boost) |

Oculus visibly becoming the big one as it takes over the tanky role, and the Lurker shrinking
to a squishy support body, is the read we want. No manual art work.

---

## 7. Implementation checklist

1. `enemies/lurker/lurker_enemy.tres` 36 → 18; `lurker_enemy_tier2.tres` 47 → 22.
2. New `enemies/oculus/oculus_enemy_tier1.tres` at 44 HP (keep the 20 HP original on disk
   in case you want a weak Oculus elsewhere).
3. `statuses/parasite.gd`: stacks 3 → 2, threshold 15 → 18.
4. `enemies/oculus/oculus_attack_buff_action.gd`: Muscle 3 → 2.
5. Lurker AI: collapse to **attack every turn, damage 6, self Muscle +2 after each attack**;
   this also fixes the dead-end chain in §1. `lurker_block_action` becomes unused.
6. Repoint the 3 battle `.tscn` files per §4 (swap `stats` + `initial_statuses`).
7. Re-run the size-ladder solver + `validate.py`, re-render the 3 fights.

**Nothing here touches `art`** — both keep their current textures, as you asked.

---

## 8. Decisions I need from you

1. **Lurker solo → Oculus solo** (§4): this retires the solo Lurker fight in favour of a solo
   Oculus. Agreed, or do you want to keep a solo Lurker somewhere?
2. **Parasite threshold 18** — the main dial. Higher = more forgiving, lower = punishes
   sooner. Happy to start at 18 and tune on feel.
3. **Lurker damage 6 with +2/turn escalation** vs. a flat 6. Escalation creates the "kill it
   now" urgency; flat is simpler and safer.
4. **Oculus tier-2 variant at 56 HP** — build it now, or leave Oculus tier-1-only for the
   moment?

---

## 9. IMPLEMENTED 2026-07-24 — NOT PLAYTESTED

Built as specced, with Julien's one amendment: **no Strength escalation on the Lurker** — it
attacks for a flat 6 every turn.

### Files changed
| file | change |
|---|---|
| `enemies/lurker/lurker_enemy.tres` | 36 → **18** HP |
| `enemies/lurker/lurker_enemy_tier2.tres` | 47 → **22** HP |
| `enemies/lurker/lurker_attack_action.gd` | damage 10 → **6**; `is_performable()` → **always true** |
| `enemies/lurker/lurker_enemy_ai.tscn` | reduced to a **single** action node |
| `enemies/oculus/oculus_enemy_tier1.tres` | **new**, 44 HP (20 HP original kept on disk) |
| `statuses/parasite.gd` | **+2** Strength (was 3) at **>18** Power (was 15), both now named consts |
| `enemies/oculus/oculus_attack_buff_action.gd` | self Muscle 3 → **2** |
| `battles/tier_1_lurker.tscn` | now **Oculus 44 + Parasite** (solo) |
| `battles/tier_1_oculus_goblin.tscn` | now **Lurker 18 + Flux**, Goblin 22 |
| `battles/tier_1_lurker_crab.tscn` | Lurker 47 → **22**, Crab 31 |

`art` untouched on both — they keep their textures exactly as before.

### Verified
- All 57 fight renders clean, no script errors. In-engine: Oculus solo **44/44** at 271px,
  Lurker **18/18** at ~179px with its Flux icon left-aligned under the bar, Lurker **22/22**
  beside Skeleton 31/31.
- Fight EHP: solo Oculus **44**; Lurker+Goblin **40**; Lurker+Crab **78 → 53** (the fight
  your balance notes called "a wall").
- Size ladder re-run from a fresh audit; `validate.py` reports **zero** violations.
- gdtoolkit parse clean on every touched script.

### Side effects worth knowing
- **The dead-end AI bug is fixed** as a by-product: the Lurker's single action is
  unconditionally performable, so the picker can no longer fall through to `get_child(0)`.
- `lurker_attack_action_2.gd` and `lurker_block_action.gd` are now **orphaned** (left on
  disk per project convention). `oculus_enemy.tres` (20 HP) is likewise unreferenced.
- `STAGE_L` moved 750 → **758** in the layout solver. A front enemy with a full-size bar put
  its bar's left edge at ~760, just inside the *tallest* card of the fan (top y562); two px
  further right the binding card becomes the next one over (top y569), worth +7px of vertical
  budget. This removes a recurring 2px card-clearance failure structurally.

### Left for playtest
- Whether 18 HP really is a two-turn kill under Flux. Fallback if it still grates: have Flux
  start on the Lurker's **second** turn (§5).
- Parasite's **18** threshold is the greed dial (§3).
- No Oculus tier-2 (56 HP) variant was built — tier-1 only for now.
