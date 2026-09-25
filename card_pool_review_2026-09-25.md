# Card pool + starter deck review (2026-09-25)

**Status: Julien's verdicts in (2026-09-25): "fix the crescendo and second copies bug but im fine with the rest".** B1 and B2 are FIXED (see the end of this file), NOT COMMITTED, NOT PLAYTESTED. Every other finding is CLOSED as "leave as is". Starter: the Dice Slap swap is still being discussed (Julien worries about the number of distinct starter cards). Claude's advice on 09-25 was to keep the starter as it is: 12 cards / 6 distinct already beats every STS2 starter (3-4 distinct: Ironclad 10/3, Silent 12/4, Defect, Necrobinder, Regent 10/4).

Source: the live pool (78 draftable cards, 29 C / 29 U / 20 R, 31 Attack / 32 Skill / 15 Blessing) extracted from the `.tres` + `.gd` files on 2026-09-25, and the starter deck in `characters/warrior/warrior_starting_deck.tres` (4 Strike, 4 Block, Low Blow, Reinforce, Recombobulate, Scout 3).

Method: a workflow of 5 reviewers (power math, fun and decisions, draft and archetypes, text vs script, starter deck) produced 62 claims. Then 2 skeptic agents tried to refute each claim against the scripts and against Julien's past verdicts in `docs/history/`. Only claims that survived (UPHELD) or survived with a correction (PARTLY) are listed as findings. REFUTED claims are listed at the end so they are not re-raised. Claude re-checked the three code bugs marked "re-read" by hand.

Cost note: the first run hit the session limit on the 2 skeptics (1.7M subagent tokens for the 5 reviewers). The retry replayed the reviewers from cache and cost 0.6M for the skeptics.

---

## 1. Bugs: the card does not do what its text says

| # | Card | What happens | Where | Checked |
|---|---|---|---|---|
| B1 | **Crescendo** | "all Power generated this turn" counts only the die face. Boost, Surge and a held Blood Pact are added to `roll_value` after the counter is credited, so they never count. A roll cut by Weak still counts at its full face. Blood Sword does count (it goes through `change_current_power`). Example from the reviewer: Amplify+ and 8 Blue rolls bank about 44, Crescendo hits for about 28. The live description shows the real (lower) number. | `dice.gd:3033` credits `last_roll`, bonuses land at `dice.gd:3160-3187` | UPHELD, re-read |
| B2 | **Second copy does nothing** for Die Hard, Dice Echo, Artillery, Marionette, Anarchy, Effigy (same target), Rupture (same target, same turn), Buzzer Shot (two before it fires) | Their statuses have `stack_type = 0` (NONE). `add_status` returns on a second copy, and the card is still exhausted. Die Hard + Die Hard+ and Dice Echo + Dice Echo+ share the same `.tres`, so base + upgrade does not stack either. Emanation, Amplify, Trebuchet and Cogwork do stack (Global counters). | `status_handler.gd:47-48` | UPHELD, re-read |
| B3 | **Focus** | "Your next roll is a 6" on a die with no 6 face (Pixie, Ricochet, Bulky Giant) logs `push_error` and rolls a random face. The preview slot loads `green6.png` / `odd6.png`, which do not exist, so it shows an empty face. Switching the active die clears the guarantee. Focus is a blank card on the Elf loadout. | `dice.gd:1392-1402`, `dice.gd:3336` | UPHELD, re-read |
| B4 | **Red socket glow** | Every non-Support Max card socketed on Red glows HOT ("sure thing"), whatever its number. Low Blow (starter) glows HOT and misses on a Red 4-6 (50%). Also Catapult, Finesse, Kickstart, Necromancy, Geomancy, Pixie Volley. The comment above the line says only already-true requirements should glow. | `hand.gd:492` | UPHELD, code only, not seen on screen |
| B5 | **Kamikaze** | "If you roll a 1" tests banked Power, not the face. Held Blood Pact or Blood Sword remove the backfire. Weak 1 turns a rolled 2 into a backfire. The 6 HP is ordinary damage that Block absorbs. | `kamikaze.gd` | UPHELD |
| B6 | **Overdrive** (Depleted) | Blue refill has no `maxi(0, ...)` clamp (Golem has one). On Elf, Blue goes to -1 hidden, so the next Blue Charge that turn is short by one. | `player_handler.gd:109`, `dice_interface.gd:371` | UPHELD, code only, not verified in game |
| B7 | **Mirror Blow** | The only direct-damage attack that skips `DMG_DEALT`: Strength, Dice Aura+ and Berserk do not apply. Against a block or buff intent it deals 0, but the card still plays and resets. | `mirror_blow.gd` | UPHELD |
| B8 | **Dice Echo / Buzzer Shot** + reroll | Rerolling the first roll (Ricochet, or Blue under Malleable) restores the pre-roll snapshot, so the double/triple is lost. Buzzer Shot is wasted entirely. | `_ricochet_restore_snapshot`, `status_opening_gambit.gd`, `status_coiled_spring.gd` | PARTLY (the counter increments are deliberate) |
| B9 | **Sleight+** | Same text as Sleight, but it is Celestial and does not reset. The Celestial frame and hover tooltip do show it. Cheap fix: add "Does not reset your Power". | `card_sleight_plus.tres` | PARTLY |

Fix sketches (not applied):
- B1: in `_apply_roll_result`, credit `power_generated_this_turn += Global.roll_value - power_before` after the Surge and held-bonus lines. Parasite (Oculus, >15) reads the same counter and would trigger a bit earlier. Rerun `debug_parasite_power.gd`.
- B2: make those statuses INTENSITY and read `stacks` in their handlers, or refuse the play in `would_no_op_now()` when the status is already there.
- B3: resolve the guarantee per die at roll time like Lucky does (6 if the die has it, else the face closest to 6 or the highest face).
- B4: HOT on Red only when `requirement_number` is at least the highest possible Red result including Blood Sword / Blood Pact / Surge. Otherwise AVAILABLE.

## 2. Draft structure

- **D1. Red cards are offered on loadouts without Red.** 9 cards need a Red die (Kamikaze, Flurry, Blood Pact, All In, Berserk, Forge, Armageddon, Red Cannon, Ooga Booga), and 6 of them are Rares. Neither `battle_reward.gd:352` nor `CardRarityDraw.pick_card` filters by owned dice. On Elf, Titan and Architect, a boss screen (3 Rares) shows at least one Red card 68% of the time (1 - C(14,3)/C(20,3)). Red can only be bought when it is one of the 3 random dice-shop types (base 170). H-057 (08-13) accepted dead Red drafts when there were 4 Red cards; there are now 9. Proposed fix: skip Red-dependent cards while no Red die is owned (a `needs_red` export is cleaner than tags), or halve their weight. UPHELD (skeptic lowered severity: only run 2+ players on a no-Red wish).
- **D2. About 6 of 20 Rares play at Common or Uncommon level**, and the boss screen is all-Rare, so a weak Rare is a trap on the best reward screen: Grand Scheme, Mirror Blow, Earthquake, Pulverize, Sixplosion, Effigy (details in section 4).
- **D3. The Throw archetype is the thinnest.** 4 sources (Meteor C, Pixie Volley C, Artillery U, Avalanche R), 1 payoff (Trebuchet), no relic listens to `dice_thrown_landed`. All In does not count as a throw for Trebuchet. Once assembled it pays (Trebuchet x Pixie Volley+ about 30 per play, 07-28 review), the problem is how rarely the pieces meet. Fastball (on disk) was cut as "too similar to Cursed Toss / coinflip", both since cut, and it still lands through `_land_thrown_die`. PARTLY.
- **D4. Dice economy is overfull, draw is thin.** About 17 Charge/Refuel cards against about 9 payoffs, and base draw is Eyepoke, Insight and Haste only. Matches the 09-08 "too many dice compared to cards" complaint.
- Exact/Mult, Low roll/Max and High/Min are the healthiest archetypes (13, 14 and 8 payoffs).

## 3. Too strong or outsized

- **Smash** (Common, X2 to ALL, Min 10). Beats Pulverize (Rare) on any target whenever playable, and makes Earthquake (Rare) redundant in act 2. Not the strongest single-target card (Bullseye, Doomsday, Flurry+ hit harder), and the Min 10 gate is 17% on 2 Blue dice after turn 1. The AoE was Julien's 08-20 verdict (H-043), so the question is rarity: Uncommon, or "Deal X to ALL". PARTLY.
- **Eyepoke** (Common, Deal X, draw 3, no gate). Dominates Insight at X <= 7. Julien moved it to Common on 08-20 to keep draw accessible and asked for more draw on 09-08, so the skeptics advise flagging only. PARTLY.
- **Amplify+** (Surge 2 at Min 6). Probably the largest Blessing upgrade (+3 to +10 Power per turn over the base), but Anarchy+, Marionette+, Trebuchet+ and Armageddon+ also change the effect at the same gate, so there is precedent. PARTLY.
- **Fortify** (Common, X Block + 2 permanent Strength, Even, no Exhaust). About +20-25 damage over a 6-turn fight, roughly one extra Strike. Audits since 07-27 saw it and did not flag it. PARTLY, low.
- **Crescendo+** (no Exhaust). Adds one extra play of about 35-45 in a long fight, comparable to Bullseye+. Playtest in the act-2 boss before changing. PARTLY, low.
- **Refinement + Blackjack**: Refinement lifts any bank of 14-20 to 21, so the pair is a guaranteed kill (bosses included) when both are in hand with 14+. The Exact 7 cluster and the boss kill are Julien's calls. Recorded as a known interaction, not a proposal. PARTLY, severity 0.

## 4. Weak, will rarely get picked

| Card | Why | Suggested fix | Verdict |
|---|---|---|---|
| **Buzzer Shot** (U) | Costs a roll, the whole bank and Exhaust for about +7 next turn (net about +3.5 once per fight). Blaze (C) gives +7 now without Exhaust. | Drop Exhaust, or make it Celestial + no reset (H-082 made it reset on purpose, so that part is Julien's call). | UPHELD x2 |
| **Cogwork** (U Blessing) | Same +1 die/turn as Emanation but behind Exact 6 (36% unaided), and a lone Mech die cannot join another chain. | Min 6 / Min 4 like the other +1-die Blessings. | UPHELD |
| **Artillery** (U Blessing) | About 4 damage per turn (random type, random target, no Strength) for a Min 6 bank. | Throw 2 per turn, Artillery+ at Min 4. | UPHELD |
| **Voodoo** (U) | Recombobulate into a random type, about +0.5 Power per refunded die. Cutting it is refuted: it is one of only 2 Refuel cards in the draftable pool and 3 relics listen to Refuel. | Add "Charge 1 of that type", or keep the bank. | UPHELD (weak), cut REFUTED |
| **Spectrum** (U) | 2 AoE per type rolled: 4 on Disciple, 2 on Elf, 6 on 3-type wishes. Free and Celestial, just small. | 3 per type (4 upgraded). | UPHELD |
| **Grand Scheme** (R) | Haste has the same rarity and frame and gives strictly more (Draw 2 + Charge 2 vs Charge 1 + a Scout 5 card). Occultism+ (a Common's upgrade) gives a free Giant die every draw. | Uncommon, or Charge 3 with the + dropping Exhaust. | UPHELD |
| **Mirror Blow** (R) | Plays like a Common: 6-14 in act 1, 0 against non-attacks, no Strength. The 09-04 rework question is still unanswered. | Uncommon, route through DMG_DEALT, deal X when the target is not attacking. | UPHELD |
| **Earthquake** (R) | In act 2 (where Rares land) Smash's gate is always met, so Earthquake is a Smash that lands a turn late, through the Block enemies gained. | X3 base (X4 upgraded), or Uncommon. | UPHELD |
| **Pulverize** (R) | 2X-10: barely above Strike+ at 14 Power (18 vs 17), below Smash on any target. Beats Dice Slap only in big-die / Power-card decks. | "Power above 10 counts triple" (3X-20). | PARTLY |
| **Sixplosion** (R) | 6 per natural 6, Exhausts. About 36 on turn 4 on Blue in act 2, 50-55 with Golem (6 in 1 of 4). Focus, Lucky and Scout 6s count. | 10 per 6, or drop Exhaust. | PARTLY |
| **Effigy** (R) | 5 per natural 6 to one enemy, no Strength. Matches a Bullseye in about 2 act-2 turns, 50-60 over a boss fight, recastable. | The open 09-04 Uncommon proposal. | PARTLY, low |
| **Malleable** (R) | Reroll on Blue only. Blank on Elf, weak with 1 Blue die. | "Your active Dice type gains Reroll" (type locked at cast). | UPHELD |
| **Avalanche** (R) | 1 throw per owned type, once: 2-5 on Elf, 7 on Disciple. Free Celestial, grows with Charged types. | Base without Exhaust, + adds damage per die. | PARTLY, low |

Deliberately NOT proposed (Julien's past calls): Second Wind (07-28 "stays modest by design"), Forge (09-06 rework, playtest Red first), Emergency (kept 09-06, `plays_at_zero_power` added 09-10 without Celestial), Cataclysm's 0-face payoff (Julien, 09-10, in `low_roller.gd`).

## 5. Cards that make the best moments (do not touch)

Crescendo, Cadence, Geomancy, Refinement, Shockwave, Rupture, Shattering, Catapult, Calculations, and Scout 3 in the starter (non-Exhaust Celestial Scout lifts Exact 6 from about 36% to 58% and is what makes the early Exact/Mult cards worth drafting).

## 6. Starter deck

Verdict: a sound STS-style starter (8 basics you later thin, 4 signature cards that each match a tutorial beat). Fair against tier-0 fights on the Disciple (estimate, NOT PLAYTESTED).

Upheld problems:
- **Chaining is not rewarded by the basics.** Strike and Block pay the same whether 2 rolls are chained or split (splitting is even slightly better because you see each roll first). Only Low Blow rewards a short bank (1+2 chained = 9, split = 5). Min is the most common gate in the pool (17 of 78, 12 of them Min 6 Blessings) and the starter never shows one. PARTLY (skeptic: normal for an STS starter).
- **Red socket has nothing to gamble on**, and the one gamble (Low Blow on Red) glows HOT while missing 50% (bug B4). UPHELD.
- **Acrobat, Titan and Architect cannot chain after turn 1** (1 die per type). This follows from the wish spec (H-057). UPHELD.
- **Elf is the weakest wish** with the bare starter (about 8 Power/turn vs Disciple 10.5, Titan 15), but many floor-1 Commons fit it (Catapult, Duo, Unity, Finesse, Kickstart, Pixie Volley, Cataclysm, Insight). PARTLY.
- **No AoE**, while 6 of 9 tier-0 fights are 3-enemy swarms (8 + 18 + 8). Catapult is the early answer. UPHELD, low.
- Recombobulate is the weakest signature card on paper but it is the intended safety valve (CLAUDE.md playtest notes). PARTLY, severity 0.

Proposals (all NOT PLAYTESTED):
1. Replace one Strike with a chain payoff. Simplest: move **Dice Slap** into the starter (it was tested there before) and out of the pool (78 -> 77). Use `warrior_axe_attack1` or `4`, since the tutorial only forces attack2/3 and block1-4 (`player_handler.gd` `TUTORIAL_HAND_BY_TURN`).
2. Alternative: a Min 6 starter attack ("Deal X+4") to teach the Min ribbon. Conflicts with the 07-29 choice that Low Blow stays the only gated starter card.
3. Run 2+ only: one signature card per wish (Elf Catapult, Titan Meteor or nothing, Architect Bullseye, Disciple/Acrobat Flurry), swapped in `run.gd::_on_dice_loadout_completed`. Needs code.
4. Fix B4 (the Red glow), because it misleads on the starter's own Low Blow.

## 7. Refuted claims (do not re-raise)

- Tsunami+ is outsized: no, in line with Bullseye+ / Crescendo+.
- Haste is a weak Rare: no, it gives 2 cards, the scarce resource.
- Cut Voodoo as a redundant Refuel: no, only 2 Refuel cards in the pool, 3 Refuel relics.
- Ooga Booga is confusing: no, the text names the condition, and Min 6 Blessings socketed on Red miss naturally.
- Cataclysm's 0-face payoff breaks the From Nothing ruling: no, Julien made that exception himself on 09-10.
- Recombobulate is dead weight: no, intended safety valve.

## 8. Fixes applied (2026-09-25)

**B1, Crescendo / Parasite counter.** `dice.gd::_apply_roll_result` no longer credits `power_generated_this_turn` with the raw face. It credits `maxi(0, roll_value - power_before)` at the roll-popup site, after Weak, Boost, Surge and the held Blood Pact bonus, and before `dice_rolled` / `red_dice_rolled` go out (Parasite re-reads the total on `dice_rolled`). Side effect: Parasite (Oculus, > 15) now also sees Surge, Boost and Blood Pact Power, so it can trigger earlier in those builds.

**B2, second copies.** New opt-in hook `Status.absorb_copy(other) -> bool` (default false). `StatusHandler.add_status()` offers a copy to the status already present before its "NONE means unique" rule drops it. The 8 statuses override it with `stacks += other.stacks` and read `stacks` in their effect: Die Hard (Block per roll), Dice Echo (extra copies of the first roll), Buzzer Shot (x2 per copy), Marionette and Marionette+ (Scout cards per turn), Anarchy and Anarchy+ (dice per turn), Artillery (dice thrown per turn, volley-staggered), Effigy and Rupture (damage per trigger, same enemy). `stack_type` stays NONE, so no number badge appears; each status's `get_tooltip()` spells out the merged count, and `status_tooltip.gd` now falls back to `get_tooltip()` instead of the raw `.tres` text. Single-copy text is unchanged. Base + upgrade merge where they share a status id (Die Hard + Die Hard+, Dice Echo + Dice Echo+). Where the + has its own id (Marionette+, Anarchy+, Effigy+, Rupture+), base + upgrade were already two separate statuses.

Verified by `debug_copies_and_power.gd`/`.tscn` (real battle, forced rolls): 40 checks, 0 fail, including a negative control (a plain NONE status is still dropped). Regression: `debug_parasite_power` 12/12. gdtoolkit parse clean on the 13 touched scripts. NOT PLAYTESTED, NOT COMMITTED. Only scripts were touched (no `.tres`), but Julien should restart the editor before playing (`status.gd` is the `class_name` base of every status).

Known leftovers, not fixed on purpose (Julien: "fine with the rest"): the Ricochet reroll still wipes a Dice Echo / Buzzer Shot bonus (B8), and the other bugs B3-B9.
