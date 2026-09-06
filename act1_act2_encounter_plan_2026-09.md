# Encounter plan — act 1 finish, act 2 start (2026-09-06, verdicts applied same day)

Status: guideline + ordered work list. Built from Julien's morning notes of 2026-09-06, his verdicts on the Exordium Gap Check (https://claude.ai/code/artifact/0a4a49d4-eb94-4359-b02f-625f24ec8a85), the 20k-path variety sim behind it, and his answers to the first draft of this doc. Companion docs: `enemy_balance_baseline_2026-08.md` (bands, clocks, ledger), the Encounter Forge / Slate artifacts (kits), `t0_enemy_rework_plan_2026-09.md` (tier 0 as built).

The one-line version: **act 1's roster is done; it needs spikes, better elites and a second boss. Act 2 needs its own list, seeded by the mechanics that are too strong for act 1.**

---

## 0. Done log

| Date | Change | Where |
|---|---|---|
| 2026-09-06 | Group burn scoped to the tier (was whole-pool) | `scenes/run/run.gd` `_get_unique_battle_for_tier`, gdtoolkit-clean, NOT played |
| 2026-09-06 | Dice Mimic and Quartermaster removed from the act-1 pool (files kept) — pool 35 → 33 | `battles/battle_stats_pool.tres` |
| 2026-09-06 | Spike caps (G3) confirmed by Julien | this doc |

⚠ Both game edits were made outside the editor: **restart the editor before playing.** ⚠ Until act 2 has its own pool (step 7), the Mimic and the Quartermaster appear **nowhere** — act 2 recycles act-1 tiers 1–2 through `ACT2_SOURCE_TIER`.

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
| Medusa, Lava Hound | T2 | one-mechanic solos | **Spice** — table in §3 step 1. Parked by Julien ("later"), numbers ready. |
| Maelstrom | T2 | one-mechanic (Chaos) | Keep — already quiet opener + rising line. |
| Famished | T2 | Gorge | **Stays in act 1** (Julien). |
| Dice Mimic | — | tool removal | **Removed 09-06** → act 2 list. |
| Quartermaster | — | spend cap | **Removed 09-06** → act 2 list (the cap needs act-2 refuel engines to bite anyway). |
| Dragon Priest | elite | greed tax | **Replaced by Parity Brothers** (step 4). |
| Lich, Gargantua | elite | Absorb / Greedy | **Keep** (Julien: different questions). |
| Leviathan | boss | the only ending | Second boss later (step 5). |

---

## 3. Ordered work list

**Step 1 — Spice pass on the T2 solos and the boss (parked by Julien, numbers ready).** Exactly what changes under the G3 caps, all NON PLAYTESTÉ, to be run through the Forge Lab first:

| Enemy | Today | Proposed | Attrition check (per 4-turn cycle) |
|---|---|---|---|
| **Medusa** T2 58 HP | Hiss 12 + Weak 2 (w5) / Bite 15 (w6), both chance; Guard 9 + Str 3 on `% 4 == 3` | **Petrifying Gaze 22** on `% 4 == 2` (turn 3, telegraphed, COND); Hiss **10** + Weak 2 (w5) / Lash **7** (w6) on the two chance turns; Guard unchanged | ~41 → ~39. Spike 15 → 22 (33 %), floor 13.6 → 8.5. Cycle 2 gaze = 25 with her Str — that is her clock. |
| **Lava Hound** T2 51 HP | Opener 6; Bite 11 / Exposed 1 / Double 7×2, equal weights | **Molten Roar** once at ≤ 50 % HP (interrupts intent): +2 Str, block 5 — first HP threshold in the hallway; after it, Double reads **9×2 = 18** and Bite 13 | EV 8.3 → ~8.3 before the roar, ~11 after. Raw spike 14 → 18 (+Exposed on you = 27; raw cap only). |
| **Temple Defender** T2 42 HP variant | Strike 10 / Double 6×2 / Guard 5 + Str 1, fixed cycle | T2 variant only: Double **8×2 = 16**, Strike **8** | 27 → 29 per cycle; T1 variant untouched. Optional. |
| **Famished** T2 56 HP | Gnaw 6 + Weak 1 / Burrow 6 blk + Str 1 / Devour 13, fixed cycle | Gnaw **5** + Weak 1, Devour **16** | 19 → 21 per 3-turn cycle; Devour 13 → 16 (24 %) before Gorge. Optional. |
| **Leviathan** boss 140 HP | Ink Tide 18 (w5) / Crush 15 + Weak 2 + Exposed 1 (w5); Guard 8 + Str 4 on `% 4 == 2` | **Ink Tide 24** (w4) / Crush **11** + Weak 2 + Exposed 1 (w6); Guard unchanged | ~49.5 → ~52 per cycle. Spike 18 → 24 (36 %); with +4 Str per guard the 3rd Ink Tide is 32 — the boss clock, target fight 6–9 turns. |
| Skeleton, Sigil Slug, Maelstrom | — | **No change.** Skeleton's 12 is at the T0 cap; Maelstrom already rises 13 → 16 → 19 → 22. | — |

*Where:* `enemies/<slug>/*_ai.tscn` (damage exports live in the scene, not the script) + one new COND action for the Gaze and one HP-threshold action for the Roar (first `health <= max/2` check in the roster — keep it on the action, not the status). *Proof:* Forge Lab DPT parity, then the fight harness; T2 attrition target 12–22 per fight unchanged. *Done when:* one "he's hitting for 22" turn per T2 solo without a fight leaving the ledger.

**Step 2 — The statue → act 2.** Julien: the Shackled Brute belongs in act 2, and its art is already on the Quartermaster. So the act-2 list carries a countdown body (new art needed, or the Quartermaster body inherits the chained pattern), and act 1's countdown feeling comes from step 1's cadenced spikes (Medusa's turn-3 Gaze is the statue in miniature).

**Step 3 — Brace rider on Temple Defender.** Parked (Julien: later). Spec unchanged: block the first time it takes damage, once per fight; EVENT_BASED status with an owner check.

**Step 4 — Elites: Parity Brothers replace Dragon Priest.** Lich and Gargantua stay (Julien). *Where:* `enemies/brother_odd/` scaffold + generate Even Brother (never done — same session as Odd, mirrored silhouette), `battles/tier_elite_brothers`, swap in `battle_stats_pool.tres`. *Proof:* harness for Rage-on-brother-death; elite no-repeat unchanged.

**Step 5 — Second act-1 boss.** Later (Julien). Bone Colossus remains the candidate (HP threshold + split + summon in one body; builds the spawn hook the Necromancer needs).

**Step 6 — Act 2 gets its own list (Julien: yes).** Design session first: a slate for act 2 with one question per fight, seeded by Dice Mimic, Quartermaster, the Brute countdown, the Forge's act-2 kits (Cinderlord, Necromancer, Gorgon, Harlequin, Bog Hag, Deepling, Tempest, Warden), and the junk ladder. Then plumbing: an `act` field on `BattleStats` + pool filtering by act, replacing `ACT2_SOURCE_TIER`. Reskins stay as the art of native bodies.

**Step 7 — More junk givers (Julien: yes).** Act 1: Leviathan's Ink beat injects 1 Sludge, cap 3 (baseline §4.1) once Sludge exists. Act 2: Sludge on Deepling cap 2, Cinder on Ember Fiend, Hex on Bog Hag cap 1.

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

1. Step 1 numbers: Forge Lab check, then a single playtest — when Julien wants it.
2. Act-2 design session (step 6) — the next big one.
