# Playtest Checklist — Batches 1–5 (pool 95)

Everything below was built 2026-08-16 and **has never been played**. 205 harness checks pass,
but every one of them is data, logic or compilation — **none of it has been seen on screen.**
The two bugs you already found (Rupture double-triggering, socketless Red not consuming the
die) both passed every harness, so treat "verified" as "not obviously wrong", not "works".

Build summary: **19 new cards, 3 reworked, 4 cut, 1 relic, 7 statuses, 8 engine subsystems.**

---

## Tier 0 — do these first, 10 minutes, they gate everything else

If any of these five is broken, most of the rest of the list is untestable.

| # | do this | expect |
|---|---|---|
| 0.1 | Start a run, enter a fight, roll each dice type you own | Power banks normally, no errors |
| 0.2 | Play any card | Power resets, card flies to discard |
| 0.3 | Socket a card on Red, roll | Card plays **once**, Red die count drops by 1, Power clears after ~1s |
| 0.4 | End turn, start next turn | Dice refill correctly |
| 0.5 | Win a fight, take a reward, continue | Reward screen shows 3 cards, map advances |

**0.3 is the one to watch** — it is the exact path both known bugs lived on, and Batch 5
changed how socketed cards are tracked (`charged_card_instance_id` → a list).

---

## Tier 1 — could be silently broken

### Surge (Batch 2)
1. Play **Sleight** → badge shows 2, and every roll banks **+2 more than the face**.
2. End turn → next turn the badge is **gone**. (Turn-scoped slice expiring is the trickiest
   logic in the batch.)
3. Play **Ringer** (Min 5) → badge 1, and it **survives** into next turn.
4. Both in one turn → badge 3 this turn, **1 next turn**.
5. ⚠️ With Surge up, roll a natural 5 on an **Arcane-infused Blue** → Arcane must **NOT** fire.
   Same for Gnome (natural 1), Octet (natural 8), Critical Edge (natural max face).
   *Surge must never fake a natural face.*

### Counters and their cards (Batch 3)
6. **Spectrum** — roll 3 different types in one turn, play it → 12 damage to all. The
   description should read "(12)" **before** you play it.
7. **Jackpot** — roll several 6s across a fight, play it → 6 × that many. Buy an **Evil** die
   (75% sixes) and watch it climb.
8. **Effigy** — curse an enemy, then roll 6s → 8 damage each. ⚠️ **Test a RED 6 and a thrown 6
   specifically** — those go through different signals.
9. **Rupture** — play at **0 Power**, then roll 3–4 times → 3 damage per roll.
   ⚠️ **Roll Red while it's active → must be 3 damage ONCE, not twice.** (This was the bug.)
10. **Prismatic Lens** relic — counter label climbs 0→4 as you roll different types, fires at 4,
    resets each turn.

### Face editing (Batch 4)
11. **Red Edge** → Red shows **3/4/5/6** in the roll, **in the Scout preview**, and on a thrown
    Red. All three must agree.
12. With Red Edge up, play **Kamikaze** → its "if you roll a 1" clause can no longer trigger.
13. **Counterfeit** on Blue → faces become 2,3,4,5,6,**6**; check the duplicate 6 renders.
14. **Talisman** (Batch 5) held in hand → your dice can't roll their lowest face. Check the
    **Scout preview** agrees. Discard it → faces return to normal.

### Dice economy (Batch 4)
15. **Hoard** — end turn with dice left → they carry over. ⚠️ With **Golem** dice, confirm they
    do **not** double.
16. **Socketless Red** — roll Red with an **empty socket** → AoE damage, **die count drops**,
    Power clears. With **Berserk** up, damage should double.
17. **Kaleidoscope** — switch dice type without losing your Power chain, for that turn only.
18. **Reservoir** — play a card → Power drops to **5**, not 0. Play with less than 5 → normal.

### In-hand passives (Batch 5) — ⚠️ these fail INVISIBLY
19. **Blood Oath** *held, not played* → Red rolls bank **+3**. Compare the same roll with it in
    hand vs discarded. **There is no visual held-state**, so this is the card most likely to be
    silently broken and read as "feels weak".
20. **Dead Weight** held → every roll banks **+1**. Try to drag it → refusal shake + message.
21. **Quicksilver** → the **reroll button appears on Blue** and works once per roll.

### Second socket (Batch 5) — the riskiest thing in the build
22. Play **Second Socket**, then socket a card → normal. Socket a **second** card → it should
    fill a **second socket to the left** rather than evicting the first.
23. Roll Red → **both cards play**, in socket order.
24. Cancel → **both** sockets clear.
25. Socket 2 + a **single-target** card → targeting still works.
26. ⚠️ **Without** the card in play, socket behaviour must be **exactly as before** — this is the
    single most important regression check in the list.

---

## Tier 2 — works, but might feel wrong

- **Necromancy** is now Max 3 — from always-playable to bad-roll-only. Biggest feel change.
- **Cursed Toss** throws **Evil**: 25% of throws do **0** damage (crack face). Gamble or bug?
- **Runic Bones** draws 2 instead of 4 Block.
- **Artillery** — a die flies every turn. Watch it against the turn-start animation queue.
- **Greed** — mid-fight gold. Legible?
- **Dominance** — two separate hits on an Exposed target. Kill with the first; the second must
  not error.
- **Cadence** (Max 6, 7 per consecutive roll) — is the two-conditions-fight-each-other puzzle
  fun or fiddly?
- **Count-based cards without a tray readout** — Spectrum/Jackpot/Cadence show "(12)" in their
  own text. Is that enough, or do you need the readout I deferred?

## Tier 3 — balance watch

- **Socketless Red × Berserk** — doubling confirmed, **and Strength applies too**. Probably the
  strongest thing in the five batches.
- **Second Socket × Berserk** — two cards, one roll, both doubled.
- **Kaleidoscope + Spectrum** — keep the chain *and* go rainbow.
- **Blood Oath held permanently** — is never playing it the correct line? If so it needs a
  bigger play effect.
- **Surge vs Exact** — your original worry. Surge 1–2 should still allow Exact play.
- **Pool at 95, 13 rares.** Draft variety, and whether the 19 new cards actually show up.

## Tier 4 — quick sanity

Perpetual Motion / Spark / Low Profile / Supplication gone from rewards · Earthquake only
appears as Rare · Rampart throws Blue · Campfire upgrades (⚠️ **19 new cards have no `+`
version** and will not be upgradable).

---

## Known gaps going in

- **No tray counter readout** — deferred; dynamic descriptions are the only feedback.
- **No `+` versions** for the 19 new cards.
- **Placeholder art** on all 19 (recycled from cut cards).
- **No visual held-state** for in-hand passives — see #19.
- **Talisman's play effect is Lucky 1**, not the "reroll your last roll" you specced; the reroll
  machinery is Ricochet-specific and driving it from a card meant reaching into dice.gd
  internals. Say the word and it can become a real reroll.
- **Dead Weight discards** instead of "exhausts at end of turn" — it cycles back, so it is a
  permanent small buff that costs a hand slot rather than a one-shot.
- **Ladder holes still open**: Volume concluder (27 cards, nothing to build toward), Low Roll
  engine, Block concluder, Sixes engine, AoE, Throw payoff, Card draw, Exposed, Strength.
