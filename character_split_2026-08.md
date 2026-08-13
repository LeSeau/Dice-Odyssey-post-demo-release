# Character Split — Paper Exercise (2026-08-11)

**Status: design exercise only. Nothing implemented, no verdicts given.** Assigns each of the 80
draftable cards to one of two hypothetical characters, to answer: "does the current pool actually
contain two characters, and what would each side's density look like?"

Companion to `balance_audit_2026-07-27.md` (§3.5 "parity is a ghost archetype", §6 archetype
coverage). Context: Julien wants to explore Even/Odd requirements, small-dice swarm, and Strength
further, and feels one character is carrying too many systems. The split axis is **dice access**,
not an arbitrary halving — each character can only buy/see its own dice types, so archetypes get
a home where they can be dense.

---

## 0. TL;DR

| | Char 1 "Bruiser/Gambler" | Char 2 "Tinkerer" | Shared |
|---|---|---|---|
| Dice | Blue, **Red, Evil, Giant, Magma** | Blue, **Pixie, Mech, Even, Odd** | Blue is the common baseline |
| Cards (own) | **29** (15 At / 10 Sk / 4 Bl) | **39** (15 At / 17 Sk / 7 Bl) | **12** (5 At / 6 Sk / 1 Bl) |
| Rarity (own) | 12 C / 13 U / 4 R | 21 C / 15 U / 3 R | 7 C / 2 U / 3 R |
| Effective pool (own+shared) | **41** | **51** | — |
| Gate vocabulary | none · Min · Red | none · Max · Exact · Mult · Even · Odd | — |
| Fantasy | multiply a big number | engineer the exact number / many small numbers | — |
| Roll manipulation | amplify variance (Lucky, first-roll ×2/×3) | remove variance (Scout, Focus, Boost, Mech ±1) | — |

**Headline finding: the current pool already leans Tinkerer (39 vs 29).** The warrior is carrying
a second character's worth of precision/parity/swarm cards — that's the crowding feeling,
quantified. The split is not "cut the pool in half", it's "give half the pool the character it was
already written for."

**Second finding: the infusion system already partitions perfectly along this axis.**
Arcane (Blue) shared · Berserker (Red), Repented (Evil), Bulky (Giant), Inferno (Magma) → Char 1 ·
Gnome (Pixie), Clockwork (Mech), Bulwark (Odd), Octet (Even) → Char 2. 4/4 + shared baseline,
zero conflicts. The dice system was already two characters.

**Third finding (the Strength surprise, see §6.3): the existing design language puts Strength on
Char 2, not Char 1.** Both Strength cards in the pool are gated low/parity (Kickstart Max 3,
Fortify Even), the Even infusion (Octet) grants Strength, and Strength is a **per-hit flat bonus**
— it multiplies with hit COUNT (swarm, Flurry-style multi-hits, per-die throws), not with hit
SIZE. Char 1's damage identity is multipliers (X2/X3/X4 on a big bank); flat +N per hit is
mathematically the small-dice character's scaling. This resolves both "tension cards" for free.

---

## 1. The axis

- **Char 1 — Bruiser/Gambler** (the current warrior, minus the tinkerer half). Rolls big dice,
  banks big Power, multiplies it, gambles on Red sockets and Evil faces, throws one huge die,
  refuels to keep spending. Accepts variance and amplifies the good outcomes.
- **Char 2 — Tinkerer.** Rolls many small dice, fixes rolls (Scout/Focus/Boost/Mech ±1), lands
  Exact/Mult/parity gates, gets paid per-roll and per-hit. Removes variance and gets paid for
  precision.
- **Blue is shared**: tutorial die, Arcane infusion target, both starter sets keep it. Every other
  die is exclusive. Char 2 never sees the Red socket system at all — that is a *teaching win*
  (one fewer system per character), not a loss.

---

## 2. Char 1 — Bruiser/Gambler (29 own)

### Red gamble (6)
| Card | Gate | Why |
|---|---|---|
| Flurry | Red | red_only, X twice |
| Kamikaze | Red | red_only, X3 or self-damage — gambler flavor |
| All In (R) | Red | red capstone, spends every die |
| Bulletproof | Red | red_only Block — red's defense |
| Unity | Exact 1 (red_only) | red insurance: the worst red roll becomes 12 Block |
| Berserk (R) | Min 6 | Blessing: double damage with Red |

### Big bank & multipliers (11)
| Card | Gate | Why |
|---|---|---|
| Disintegrate | Min 10 | bank payoff + Charge 2 |
| Smash | Min 10 | X2 + Exposed |
| Dominance | Min 10 | bank → AoE Exposed + Block |
| Juggernaut | Min 12 | bank → dmg + Block |
| Tidal Force (R) | none | bank capstone (>10 counts double) |
| Shockwave | Max 10 | chip damage that does NOT reset — the bank-builder's common |
| Overdrive | Max 12 | X2 with a dice cost — spend big |
| Blaze | none | +7 Power flat, Weak 1 — bank fuel with a bruiser downside |
| Eclipse | none (CEL) | next card doesn't reset — chain extender |
| Coiled Spring | none | next turn first roll ×3 — Giant dream |
| Opening Gambit | Min 6 | Blessing: first roll counts double — Giant 12→24 |

### Variance & Evil (5)
| Card | Gate | Why |
|---|---|---|
| Double or Nothing | none | coin flip — the gambler common |
| Rigged | none (CEL) | Lucky 2 = force MAX faces; best on Giant/Evil (documented burst pattern) |
| Blackjack (R) | Exact 21 | casino flavor; Evil 6s + Blue math to hit 21 (swing card, see §5) |
| Necromancy | none | Charge 1 Evil |
| Critical Edge | Min 6 | Blessing: max-face → 5 dmg. **This is Evil's missing payoff** (3 of 4 faces are max) |

### Magma / AoE (2 + the dice themselves)
| Card | Gate | Why |
|---|---|---|
| Eruption | Exact 6 | Charge 2 Magma (gate could loosen to Min 6 on this side) |
| Earthquake | none | bank X2 → delayed AoE |

### Throw (1 own + shared Avalanche)
| Card | Gate | Why |
|---|---|---|
| Meteor | Min 5 | throws a Giant — the "one huge die" throw |

### Refuel engine (4)
| Card | Gate | Why |
|---|---|---|
| Catalyst | none | refuel active + Charge 1 |
| Voodoo | none | refuel into random type |
| Perpetual Motion | Min 6 | Blessing: first dice-out → Charge 1 |
| Occultism | none (CEL) | Charge Giant + Unlucky |

(+ Recombobulate stays in this character's starter deck — refuel is his soul.)

---

## 3. Char 2 — Tinkerer (39 own)

### Precision / Exact / Mult (8)
| Card | Gate | Why |
|---|---|---|
| Bullseye | Mult 6 | the "hit the number" payoff |
| Duo | Exact 2 | precision + low-roll overlap |
| Doomsday | Exact 13 | precision-bank capstone (engineer exactly 13) |
| Corrode | Exact 7 | the 7-family (Odd max face, Refinement) |
| Aegis | Mult 6 | precision Block |
| Gang Up | Exact 6 | precision → Blue economy |
| Calculations | Exact 6 | precision → Even dice + Scout |
| Cogwork | Exact 6 | Blessing: +1 Mech/turn — **the only Mech card in the pool** |

### Roll-fixing tools (6)
| Card | Gate | Why |
|---|---|---|
| Focus | none (CEL) | next roll IS a 6 — variance removal |
| Finesse | Max 2 | Boost 8 |
| Steady Hand | Min 6 | Blessing: Boost 3/turn |
| Low Profile | none | −1 Power = poor man's Mech adjustment |
| Refinement | none | Power → next multiple of 7 — number engineering |
| Geomancy | Max 4 | low roll → tripled (small numbers become big) |

### Scout (4 + starter Scout 3)
| Card | Gate | Why |
|---|---|---|
| Spark | none (CEL) | Charge Blue + Scout 3 card |
| Marionette | Min 6 | Blessing: Scout 3 every turn |
| Foresight | Min 6 | Blessing: Scout → Charge |
| Grand Scheme (R) | none (CEL) | Charge + Scout 5 |

### Low roll (4)
| Card | Gate | Why |
|---|---|---|
| Catapult | Max 2 | AoE + Lucky |
| Low Roller | none | 12 − X |
| Pixie Volley | Max 4 | throw X Pixie dice |
| Second Wind | Max 6 | heal X (movable by re-gate — Char 1 has no heal, see §7) |

### Swarm / count payoffs (6)
| Card | Gate | Why |
|---|---|---|
| Dice Slap | none | +3 per consecutive roll |
| Stampede | none | 5+ dice rolled → double |
| Tsunami | none | +1 per die rolled this combat |
| Crescendo (R) | none | dmg = ALL Power generated this turn — volume capstone (swing, see §5) |
| Hardened Grip | Min 6 | Blessing: 1 Block per roll |
| Trebuchet | Min 6 | Blessing: thrown +2 — Pixie Volley's multi-die throws profit most |

### Parity (7)
| Card | Gate | Why |
|---|---|---|
| Mirror Blow | Odd | dmg = enemy's intent |
| Electrify | none | Charge 3 Odd + Depleted |
| Rampart | none | Block + throw an Odd block-die |
| Cursed Toss | none (CEL) | throws an Even die |
| Fortify | Even | Block + 2 Strength |
| Dicelord's Gift (R) | Odd | Blessing: Charge random each turn (movable by re-gate) |
| Fumigation | Max 7 | per-enemy AoE (gate is Odd-max-face flavored) |

### Strength (2 — the exploration space, see §6.3)
| Card | Gate | Why |
|---|---|---|
| Kickstart | Max 3 | Gain X Strength — low-roll Strength engine |
| (Fortify) | Even | counted above — parity Strength |

### Dice economy, own-type (4)
| Card | Gate | Why |
|---|---|---|
| Shattering | Min 6 | Block + Charge 3 Pixie |
| Supplication | none (CEL) | empty → Charge 3 Pixie |
| Bulwark | none | dmg = Block — fortress payoff (block-GEN skews this side: Aegis/Fortify/Rampart/Grip) |
| (Electrify) | | counted in parity |

---

## 4. Shared (12) — both pools include these

| Card | Tier | Why shared |
|---|---|---|
| Experiment | C | Charge a random Dice — works with any roster |
| Momentum | C | +3 per card played — deck velocity, dice-agnostic |
| Rupture | C | the generic Exposed common |
| Eyepoke | U | generic draw attack |
| Dice Avalanche | R | throws one of EACH owned type — scales with either roster |
| Compound | C | draw + Charge Blue (shared baseline) |
| Emergency | C | panic Block |
| Repel | C | Block + draw |
| War Ritual | C | Charge 2 random next turn |
| Overclock | R | draw 2 + Charge 2 |
| Transmutation | R | convert all dice to active type — Magma alpha-strike on C1, Pixie swarm on C2 |
| Emanation | U | +1 Blue/turn (shared baseline) |

---

## 5. Swing cards — the genuinely contestable calls

These are the ones where I made a judgment call; flipping any of them doesn't break the split.

| Card | Put on | Case for the other side |
|---|---|---|
| **Blackjack** | C1 | Mechanically it's precision (Mech ±1 makes 21 consistent = C2 tool). Kept C1 for casino flavor + Evil-6 math. |
| **Crescendo** | C2 | Bank generates huge Power too. Given to C2 as the swarm capstone AND because C2 only has 3 own rares vs C1's 4. |
| **Critical Edge** | C1 | Pixie (d3) procs max-face constantly on volume. Kept C1 because Evil (3 of 4 faces = max) has no other payoff. |
| **Rigged** | C1 | It's roll-fixing (C2's identity) — but Lucky forces the MAX face, and max-forcing is the big-dice character's dream, not the exact-number character's. |
| **Bullseye** | C2 | Julien's own best run was Bullseye + Arcane (Blue 6s) + Hunting Bow on C1 dice. Mult gate says C2; this combo is a real casualty of the split. |
| **Bulwark** | C2 | Juggernaut/Dominance (C1) also stack Block. Fortress *payoff* follows the block-GENERATION density, which is C2 (Aegis/Fortify/Rampart/Grip). |
| **Shockwave** | C1 | Max 10 gate reads C2, but "chip without resetting" is the bank archetype's enabler. |
| **Second Wind** | C2 | Pure gate call (Max 6). C1 ends up with zero heals — either re-gate a copy or author C1 its own heal. |
| **Fumigation / Geomancy / Dicelord's Gift** | C2 | All pure gate calls; any could be re-gated and moved if a side runs thin. |

---

## 6. What the split reveals

### 6.1 Each side's gate vocabulary halves the teaching load
- **C1 sees:** none · Min · Red. Three gate kinds, all simple ("bank at least N" / "socket on red").
- **C2 sees:** none · Max · Exact · Mult · Even · Odd (+ Min on a few Blessings). The whole
  precision vocabulary — on the character whose tools (Scout/Focus/Boost/Mech) exist to satisfy it.

Today one player meets all 9 gate kinds at once, with 1–2 support cards each for the exotic ones.
After the split, every exotic gate lives next to its enablers. This is the concrete fix for
"too many things at once."

### 6.2 The ghost archetypes become real
- **Parity** today: 1 Even + 2 Odd cards across 80 (audit §3.5: "ghost archetype"). On C2 it's 7
  parity-touching cards out of 39 — before authoring anything new.
- **Swarm/count** today: buried. On C2: 6 dedicated payoffs + Pixie/throw support = a real deck.
- **Red** today: 4-of-80 (a ~5% sliver). On C1: 6-of-29 own (~20% of the identity) — and it can
  grow to 9–10 because there's finally room.

### 6.3 Strength belongs to Char 2 (recommendation, Julien's call)
Three independent signals all point the same way:
1. **The existing cards already say so**: Kickstart (Max 3) and Fortify (Even) — Strength is
   currently gated on low/parity rolls, i.e. "my rolls are small but my hits are iron."
2. **The Even infusion (Octet) grants Strength** (+8 on a natural 8). The dice system already
   linked Strength to parity.
3. **The math says so**: Strength is a flat per-HIT bonus (documented: it applies once per thrown
   die on Dice Avalanche, twice on Flurry). Flat bonuses scale with hit COUNT → many small
   hits (swarm/volley/multi-hit). C1's scaling is multipliers (X2/X3/X4), which scale with hit
   SIZE. Giving C1 Strength would be giving the multiplier character the additive tool.

If accepted: both "tension cards" (Fortify, Kickstart) stop being tensions — their gates and
their payoff agree, on C2. The Ironclad instinct ("strength = the simple bruiser") gets satisfied
on C1 by multipliers instead, which ARE his simple math. If rejected (Strength → C1): re-gate
Fortify/Kickstart, author C1 multi-hit support, and accept that Octet's Strength grant sits on
the wrong character.

### 6.4 The audit's §6 pending designs distribute 2/2
- **Mulligan** (refuel ALL) and **Backdraft** (Refuel → 5 AoE) → C1's refuel engine.
- **Bastion** (keep Block) and **Prophecy** (Scout reveals become your rolls) → C2's fortress/Scout.
Nothing needs redesigning; the pipeline was already feeding both characters.

---

## 7. Gaps each side needs authored (to reach ~50/60 effective)

**Char 1 (larger gap — 41 effective today):**
- 2–3 more Red commons (as its own character Red can carry 9–10 cards, not 6).
- 1–2 more Throw cards (big-die flavor: hurl a Magma die, hurl an Evil die).
- Refuel payoff: **Backdraft** (already designed). Refuel capstone: **Mulligan** (already designed).
- 1–2 Evil payoffs beyond Critical Edge (the 6/6/6/0 identity deserves a second card; the cut
  From Nothing / Jackpot space, but simpler).
- **A heal** (Second Wind went to C2) — or re-gate a Second Wind variant.
- 1–2 rares (only 4 own).
- Total: **~8–12 new cards.**

**Char 2 (smaller gap — 51 effective today):**
- 2–3 **Even** payoffs (Even is still the thinnest gate: Fortify + Calculations).
- 1–2 **Mech** cards (Cogwork is alone; the die does the work but one card is still lonely).
- The **Strength package** if §6.3 is accepted: 3–4 cards (a Strength Blessing, a multi-hit
  Strength attack, a parity-Strength engine).
- Capstones: **Bastion**, **Prophecy** (already designed).
- 1–2 rares (only 3 own).
- Total: **~6–10 new cards.**

Both sides land around 50–60 effective cards at char-2 launch. Below STS's ~71–75 per character,
but healthy for an EA content update, and each archetype inside is denser than it is today.

---

## 8. Starter kit sketch (5 minutes of thought, not a spec)

| | Char 1 | Char 2 |
|---|---|---|
| Dice | 2 Blue + 1 Red *(= today, unchanged)* | 2 Blue + 1 Pixie (or 1 Mech) |
| Starter relic | Dice Bag *(= today)* | new: Scout- or Pixie-flavored (e.g. "your first Scout each combat is free") |
| Deck | 4 Strike, 4 Block, Reinforce, **Recombobulate**, + 2 red/bank teachers | 4 Strike, 4 Block, **Low Blow**, **Scout 3**, + 1 parity teacher |

Note: Low Blow (Max 3) and Scout 3 — currently in the shared starter — are *C2-flavored*; they
migrate naturally. Recombobulate (refuel) is C1-flavored. The current starter deck is, like the
pool, already two characters interleaved. Char 1 stays the tutorial character (current tutorial
script works unchanged: Blue dice + Red socket). Char 2 unlocks after a run, no scripted tutorial
(STS model).

---

## 9. Deliberately not covered here (later, if the split is greenlit)

- **Relics**: same exercise needed (~26 relics; Blood Sword/House Money/Obsidian Scale are C1,
  Trick Scale/Cartographer's Quill are C2, most are neutral). Smaller job than the cards.
- **Events that grant specific dice** (Crimson Eclipse grants an Evil die) need a character check.
- **Dice shop / deal die**: reads a per-character allowed-dice list — all centralized in
  `global.gd` (`DICE_TYPE_ORDER`, `pick_dice_deal_index()`) since 07-23, so one filter point.
- **Plumbing**: `characters/warrior/` is already a self-contained character slot (stats, starter
  deck, draftable pool, starting relic). Char 2 = new folder + character select + save field.
- **Economy**: dice prices are tuned globally; each character seeing only 5 types changes
  gold-sink pacing — retune after playtests, single table in `global.gd`.

---

## 10. Open questions for Julien

1. **Strength on C2** (§6.3) — accept the data's answer, or force it onto C1 and re-gate
   Fortify/Kickstart?
2. **Blue shared** — or does C2 get a different baseline (making even Blue exclusive)?
   Recommendation: shared; the tutorial, Arcane infusion, and half the economy cards assume it.
3. Any swing card in §5 you'd flip on gut? (Bullseye and Crescendo are the two that hurt most to
   move — both are marquee cards the current warrior loses.)
4. Names/fantasy for the two characters — "Bruiser/Gambler" and "Tinkerer" are working labels.
5. Timing confirmation: this stays a post-launch project; pre-launch the only behavior change is
   **authoring new exploration cards (parity/swarm/Strength) into an on-disk side list instead of
   the live pool**, so the crowding stops getting worse while char 2's pool quietly fills.
