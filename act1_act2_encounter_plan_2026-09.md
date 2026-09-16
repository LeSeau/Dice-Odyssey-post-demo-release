# Encounter plan — act 1 finish, act 2 start (2026-09-06, verdicts applied same day)

Status: guideline + ordered work list. Built from Julien's morning notes of 2026-09-06, his verdicts on the Exordium Gap Check (https://claude.ai/code/artifact/0a4a49d4-eb94-4359-b02f-625f24ec8a85), the 20k-path variety sim behind it, and his answers to the first draft of this doc. Companion docs: `enemy_balance_baseline_2026-08.md` (bands, clocks, ledger), the Encounter Forge / Slate artifacts (kits), `t0_enemy_rework_plan_2026-09.md` (tier 0 as built).

The one-line version: **act 1's roster is done; it needs spikes, better elites and a second boss. Act 2 needs its own list, seeded by the mechanics that are too strong for act 1.**

---

## 0. Done log

| Date | Change | Where |
|---|---|---|
| 2026-09-06 | Group burn scoped to the tier (was whole-pool) | `scenes/run/run.gd` `_get_unique_battle_for_tier`, gdtoolkit-clean, NOT played |
| 2026-09-06 | Dice Mimic and Quartermaster removed from the act-1 pool (files kept) — pool 35 → 33 | `battles/battle_stats_pool.tres` |
| 2026-09-06 | **Spice pass shipped** (step 1): Medusa Petrifying Gaze, Leviathan Ink Tide | 1 new script, 2 AI scenes |
| 2026-09-06 | **Lava Hound Molten Roar REVERTED same day** (Julien: "lets not add this hp threshold thing to the lava hound, i like how he was before") — second time this beat has been cut | Hound scene and `battle.gd` byte-identical to HEAD again |
| 2026-09-06 | **Act gating shipped**: `BattleStats.act` + filter; Dice Mimic and Quartermaster back in the pool as act-2-only — pool 33 → 35 | `custom_resources/battle_stats.gd`, `run.gd`, 2 `.tres`, pool |
| 2026-09-06 | Spike caps (G3) confirmed by Julien | this doc |
| 2026-09-07 | **4 recycled comps cut** (Marauder+B.Kraken T1, Bloom+B.Kraken T1, Skeleton+Bloom T2, Marauder+2 B.Kraken T2) — pool 35 → 31, act-1 hallway 29 → 25 (T0 9 / T1 8 / T2 8). Files kept on disk. | `battles/battle_stats_pool.tres` |
| 2026-09-16 | **Tier-0-by-fight-count BUILT, MEASURED, then REVERTED the same day** so 0.3.0 could ship on the row rule (Julien: "i'll eventually switch to that system"). The finding is the reason to revisit: the row rule gives a path **1.5-2.4 tier-0 fights** depending on map shape, the fight-count rule gives a flat **3.0** — but it drains the T1 band hard (T1 mean roughly halves, and the share of paths seeing **zero** T1 fights goes from under 10 % to a third or more). Repro: `debug_tier_compare.gd` at the repo root, self-contained, runs both rules over the same maps. | none in game code; plan in `tier0_fight_count_plan_2026-09.md` |

⚠ All edits were made outside the editor: **restart the editor before playing.** `BattleStats` gained an `@export`, which is exactly the configuration of the documented strip incident — an editor left open with a stale copy would drop `act = 2` from the two `.tres` files and those fights would leak back into act 1.

**Nothing below has been playtested.** Verified: gdtoolkit clean on all 10 touched scripts, the three AI scenes have no dangling references and correct `load_steps`, the pool has 35 entries with no dangling refs, and `enemy_action_picker.gd` was re-read to confirm conditionals are tried before chance beats, in child order.

---

## 1. Guidelines — decide once, stop re-asking

**G1 — Act 1 annoys, act 2 disarms.** An act-1 mechanic may cost part of a turn (Weak, Ink, Exposed, a junk card, a small Strength ramp) but never removes a tool you cannot play around. Mechanics that take a die, cap spending or lock a hand belong in act 2, where the player has refuel, carryover and more dice to answer with. Famished stays in act 1 (Julien): Gorge punishes a reflex, it does not take a tool.

**G2 — Not every enemy needs a mechanic.** Three roles; a fight needs only one:
- **Stat check** — attack / block / Strength / sometimes Weak. Satyr, Kraken, Skeleton, Marauder, Temple Defender, Goblin. Allowed to be plain.
- **One-mechanic solo** — Sigil Slug is the model. Medusa, Maelstrom, Lava Hound, Famished.
- **Exam** — elites and bosses, each asking a different question.
Stop designing multi-body kill-order puzzles by default.

**G3 — Damage shape: redistribute, don't add.** Per-tier attrition targets (baseline §1.4) stay. Inside a fight: quiet, readable turns, then a telegraphed hit. Caps for **telegraphed beats only** (intent shows the number, the turns before are visibly softer) — **confirmed by Julien 2026-09-06, NOT playtested**:

| Tier | Cap on a telegraphed beat | Floor on other turns |
|---|---|---|
| T0 | 12 (18 %) — unchanged | 4–6 |
| T1 | **16** (24 %) | 7–9 |
| T2 | **22** (33 %) | 9–12 |
| Elite | **24** (36 %) | 10–13 |
| Boss | **28** (42 %) | 12–15 |

Caps are on the **raw** number; Exposed on the player and the enemy's own Strength ramp may carry a late-fight beat above the cap — that is the clock, not a violation. Any retune: raise the spike, lower the floor, keep the fight's attrition where the baseline put it; verify in the Forge Lab before touching a `.tscn`.

**G4 — One new device per debut, never on tier-0 furniture.** Satyr and Kraken keep exactly what they have.

**G5 — Pool plumbing stays.** Fixed `.tscn` per fight (hand-tuned positions), groups (now per tier), no randomised lineups, no splitting `slimes`.

**G6 — Every fight has a clock** (baseline §2.1 / §6). A telegraphed spike on a cadence is a clock.

**G7 — A body with a solo fight in tier T may not appear in a comp in tier T.** Julien's rule from 2026-07-04 (Lurker solo + Lurker+Crab both in T1: *"the same tier had a fight that's literally the same, but harder"*), restated here because a 2026-09-07 proposal round broke it in 4 places. The same body one tier LATER is fine and is the shipped pattern (Temple Defender solo T1 → Defender+Marauder and Defender+2 Satyrs at T2).

⚠ **The consequence, which is why T2 looks recycled.** Solos by tier today: T0 Skeleton / Venom Bloom / Marauder · T1 Temple Defender / Sigil Slug / Oculus · T2 Medusa / Lava Hound / Maelstrom / Famished. So **all four T2 device bodies are locked as solos**, and a legal T2 comp can only use bodies whose solo sits at T0 or T1, or bodies that have no solo at all (Kraken, Satyr, Goblin, Lurker, Slanderer). The only unused legal promotions into T2 are **Sigil Slug and Oculus** — the Defender promotion already shipped. **And T1 is device-saturated**: Defender, Sigil and Oculus are locked as T1 solos, and Lurker, Goblin and Slanderer already appear in T1 entries, so T1 cannot gain a new device body without a new body. That is the structural argument for the Acolyte and the Grave Grub, and it is stronger than the variety-count argument.

---

## 2. The act-1 roster, sorted (after 09-06)

| Body | Tier | Role | Verdict |
|---|---|---|---|
| Satyr S/B, Kraken S/B | T0–T2 | stat check | Keep exactly (G4). |
| Skeleton | T0–T2 | stat check, fixed cycle | Keep — its turn-3 spike already follows G3. |
| Marauder, Venom Bloom, Goblin | T0–T2 | stat check + ramp | Keep. |
| Temple Defender | T1–T2 | stat check | Keep. Brace rider parked (Julien: later). |
| Lurker / Oculus | T1–T2 | one-mechanic (Flux / Parasite) | Keep. |
| Sigil Slug | T1 | one-mechanic solo | Keep — the model. |
| Slanderer pair | T1 | junk giver | Keep. |
| Medusa | T2 | one-mechanic solo | **Spiced 09-06** — Gaze 22 on a cadence. See §3 step 1. |
| Lava Hound | T2 | stat check | **Unchanged.** Roar reverted 09-06; Julien will rework him himself. |
| Maelstrom | T2 | one-mechanic (Chaos) | Keep — already quiet opener + rising line. |
| Famished | T2 | Gorge | **Stays in act 1** (Julien). |
| Dice Mimic | act 2 T0 | tool removal | **Moved to act 2 09-06** (`act = 2`, `battle_tier = 1`). |
| Quartermaster | act 2 T1–T2 | spend cap | **Moved to act 2 09-06** (`act = 2`, `battle_tier = 2`) — the cap needs act-2 refuel engines to bite anyway. |
| Dragon Priest | elite | greed tax | **Replaced by Parity Brothers** (step 4). |
| Lich, Gargantua | elite | Absorb / Greedy | **Keep** (Julien: different questions). |
| Leviathan | boss | the only ending | Second boss later (step 5). |

---

## 3. Ordered work list

**Step 1 — Spice pass. SHIPPED 2026-09-06, NOT PLAYTESTED.** As built:

| Enemy | Before | Now | Attrition per 4-turn cycle |
|---|---|---|---|
| **Medusa** T2 58 HP | Hiss 12 + Weak 2 (w5) / Bite 15 (w6), both chance; Guard 9 + Str 3 on `% 4 == 3` | New **Petrifying Gaze 22**, CONDITIONAL on `% 4 == 2` with a longer wind-up tween (`medusa_gaze_action.gd`); Hiss **9** + Weak 2 (w5) / Lash **10** (w6); Guard untouched | **40.9 → 41.1** (flat by design). Spike 15 → **22** (33 %), floor 13.6 → 9.5. Her +3 Muscle per cycle makes gaze 2 read 25 and gaze 3 read 28 — that ramp is her clock. |
| **Lava Hound** T2 51 HP | Opener 6; Bite 11 / Exposed / Double 7×2, equal weights, no ramp | **UNCHANGED — Molten Roar built then reverted on Julien's call, 2026-09-06.** He likes the current shape and wants to change the Hound his own way later. ⚠ This beat has now been cut twice (08-29 and 09-06); do not re-propose it without him raising it first. | Unchanged: ~8.3 DPT, no clock. He is the last stall-safe T2 solo, knowingly. |
| **Leviathan** boss 140 HP | Ink Tide 18 (w5) / Crush 15 + Weak 2 + Exposed 1 (w5) | **Ink Tide 24** (w4) / Crush **11** (w6); Guard untouched | **49.5 → 48.6** per cycle. Spike 18 → **24** (36 %). With +4 Str per guard the third Ink Tide reads 32, on a 6–9 turn fight. |
| Temple Defender T2, Famished | — | **Not done.** Both were marked optional; left alone to keep this pass to three fights and one playtest. | — |
| Skeleton, Sigil Slug, Maelstrom | — | **No change.** Skeleton's 12 is at the T0 cap; Maelstrom already rises 13 → 16 → 19 → 22. | — |

⚠ **The damage numbers live in the SCRIPT, not the scene.** Every one of these actions does `var base_damage = damage` at class scope, which runs **before** Godot applies the scene's exported override — so a `damage = 22` line in a `.tscn` would set `damage` and be ignored by `perform_action()`. None of the touched actions had a scene override; the script default is the live value, and that is what was edited.

⚠ **If a per-fight flag is ever added** (the reverted roar used one), it must be reset in **both** `reset_run_state()` and `battle.gd::start_battle()`. Miss either and it fires once per RUN instead of once per fight — the exact bug already fixed once on this enemy.

⚠ **A new action node must never be child 0** of an AI scene, because `enemy_action_picker.gd` ends on a blind `return get_child(0)`.

*Still to prove:* Forge Lab DPT parity, then a playtest. *Done when:* one "he's hitting for 22" turn per T2 solo without a fight leaving the ledger.

**Step 2 — The statue → act 2.** Julien: the Shackled Brute belongs in act 2, and its art is already on the Quartermaster. So the act-2 list carries a countdown body (new art needed, or the Quartermaster body inherits the chained pattern), and act 1's countdown feeling comes from step 1's cadenced spikes (Medusa's turn-3 Gaze is the statue in miniature).

**Step 3 — Brace rider on Temple Defender.** Parked (Julien: later). Spec unchanged: block the first time it takes damage, once per fight; EVENT_BASED status with an owner check.

**Step 4 — Elites: Parity Brothers replace Dragon Priest.** Lich and Gargantua stay (Julien). *Where:* `enemies/brother_odd/` scaffold + generate Even Brother (never done — same session as Odd, mirrored silhouette), `battles/tier_elite_brothers`, swap in `battle_stats_pool.tres`. *Proof:* harness for Rage-on-brother-death; elite no-repeat unchanged.

**Step 5 — Second act-1 boss.** Later (Julien). Bone Colossus remains the candidate (HP threshold + split + summon in one body; builds the spawn hook the Necromancer needs).

**Step 6 — Act 2 gets its own list (Julien: yes).** **The plumbing is now done** (2026-09-06): `BattleStats.act` (0 = any act, 1 = act 1 only, 2 = act 2 only) and the filter in `run.gd::_get_unique_battle_for_tier`, which falls back to the unfiltered tier if the filter would empty it. Dice Mimic (`battle_tier = 1`, `act = 2`) and Quartermaster (`battle_tier = 2`, `act = 2`) are the first two users, so through `ACT2_SOURCE_TIER` the Mimic serves act-2 floors 1–3 and the Quartermaster act-2 floors 4–13. Both get the normal act-2 runtime treatment from `battle.gd::_apply_act2_scaling` — Mimic 20 HP → 31 and Goblin 22 → 34 at act-2 tier 0; Quartermaster 54 → 70 or 94 depending on the band.

What remains is the **design session**: a slate for act 2 with one question per fight, seeded by those two, the Brute countdown, the Forge's act-2 kits (Cinderlord, Necromancer, Gorgon, Harlequin, Bog Hag, Deepling, Tempest, Warden) and the junk ladder. Then author act-2-only fights with `act = 2` and retire `ACT2_SOURCE_TIER` recycling once there are enough of them. Reskins stay as the art of native bodies.

**Step 7 — More junk givers (Julien: yes).** Act 1: Leviathan's Ink beat injects 1 Sludge, cap 3 (baseline §4.1) once Sludge exists. Act 2: Sludge on Deepling cap 2, Cinder on Ember Fiend, Shackles (the hand-lock junk card, specced as "Hex" before that word became the card type) on Bog Hag cap 1.

**Later:** Acolyte protector, Grave Grub, third boss.

---

## 4. Not doing, and why

- **Flee with gold (Looter / Miser).** Julien: no.
- **Randomised lineups.** The six `slimes` scenes are the roll space with hand-tuned positions; the benefit only appears at act-2 scale. Revisit only if the act-2 list balloons.
- **Splitting the `slimes` group.** Gives back-to-back swarms, not variety; keep.
- **Curl Up on Kraken / Satyr.** G4.
- **Soft-enrage, Venom Bloom Weak rider, Lurker creep, Lich rider.** Shelved in the baseline; unchanged.

---

## 5. Open

1. **Playtest the spice pass.** Two fights to feel: Medusa (does the turn-3 gaze read as a wind-up?) and Leviathan (is 24 into a 32 too much on a 6–9 turn fight?). Forge Lab parity check first if you want the numbers double-checked before playing.
2. **The Lava Hound is Julien's** — he wants to change him a bit, his own way. Until he says how, the fight ships as it is and act 1 has no HP-threshold beat.
2. **Act-2 design session** (step 6) — the next big one. The plumbing is ready; it needs the list.
3. Temple Defender T2 and Famished bumps were left undone as optional. Say if you want them.
