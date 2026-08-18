# STS2 Reference Audit — Plan (2026-08-15)

Reference material: recovered STS2 project at `C:\Users\julie\Desktop\sts2_ref\pck`
(Godot 4.5.1 Mono, 15,991 files, 3,591 decompiled C# scripts under `src/`, scenes/themes/
animations recovered as readable `.tscn`/`.tres`). Produced by GDRE full recovery; the 7
non-decompiled scripts and 1,253 lossy texture imports are irrelevant to this audit.

## Ground rules (read before every session)

1. **Read-only reference.** Never edit anything under `sts2_ref`. Never copy a file from it
   into the Dice Odyssey repo. It stays outside the repo and uncommitted, always.
2. **Ideas and numbers, never expression.** Tuning values, timings, orderings, structural
   patterns are fair game to record. STS2 code is never pasted into our repo — not into
   scripts, not into the findings doc. Paraphrase behavior in prose; list constants as
   numbers. Anything we adopt gets reimplemented fresh in our own idiom.
3. **Findings go in `sts2_audit_2026-08.md`** at the Dice Odyssey repo root, one section per
   workstream, one entry per finding in this format:
   - **Theirs:** what STS2 does (facts, numbers, file where seen)
   - **Ours:** current Dice Odyssey state (verify in our code, don't recall from memory)
   - **Verdict:** `adopt idea` / `adapt` / `skip` / `already better` — anything needing
     Julien's call gets flagged **VERDICT NEEDED** instead.
   "Already better" findings are worth recording too — they tell us where NOT to spend.
4. **Don't scan, probe.** 16k files. Every workstream below starts from greps and reads a
   handful of files. If a probe drags past its effort box, write down what's known and move on.
5. Never open the recovered project in the Godot editor (it's 4.5, ours is 4.3, and an
   editor pass could rewrite files). Text tools only.
6. Decompiled C# has no comments and occasionally compiler-generated names. Two tricks:
   `localization/` holds display strings — find content by its on-screen name, then grep the
   key to reach code. And `src/Core/Models/` is data-shaped (one class per card/relic/etc.),
   `src/Core/Nodes/` is view-shaped (`N*` classes), `src/Core/GameActions/` is verbs.

## Map of the extraction (verified at root level)

- `scenes/` — recovered `.tscn` (seen: `scenes/combat/combat_ui.tscn`, `end_turn_button.tscn`)
- `themes/` — theme resources (button/panel/font language lives here)
- `animations/`, `materials/`, `shaders/` — feel/VFX side
- `src/Core/` — all game logic: `Models/` (Cards, Relics, likely Monsters), `Nodes/`,
  `GameActions/`, `Combat/`, `Commands/`, `Entities/`, `Assets/`, `AutoSlay/`, `Multiplayer/`
- `localization/` — display strings (use as index)
- `banks/` (FMOD), `models/` (Spine), `images/` — mostly do-not-mine
- Already-spotted curiosities: `src/Core/AutoSlay/` (an AI that plays the game — see WS8),
  `GameActions/UndoEndPlayerTurnAction.cs` (they support undoing an end turn),
  `Nodes/Combat/NEndTurnLongPressBar.cs` (hold-to-confirm affordance).

---

## Workstreams

### WS1 — UI construction & the "one button language" audit — **P0, effort S**
**Why:** Julien's stated pain ("my buttons are the biggest 'not a team' tell") + the End Turn
variant pick is live right now (candidates A–E rendered 2026-08-15).
**Answer these:**
- How is `scenes/combat/end_turn_button.tscn` built — painted texture / 9-slice / stylebox?
  Separate art per state (normal/hover/pressed/disabled) or modulate? Exact sizes, font, text
  outline treatment, offsets.
- What does `NEndTurnButton.cs` add in code — hover scale? punch? sounds? disabled logic?
  What is `NEndTurnLongPressBar` for (likely controller hold-to-confirm — note as idea only).
- `themes/`: how many theme resources, what the master theme defines, how they keep ONE
  button/panel language game-wide (our drift: 3 border widths, 2 radii, 3 palettes — and our
  `main_theme.tres` default Button style wrongly points at CARD styleboxes).
- Their tooltip system: one scene? anchoring/clamping? delay values?
**Start here:** read `end_turn_button.tscn`, `combat_ui.tscn`, everything in `themes/`; grep
`Nodes/Combat/` for `Tween|hover|pressed|scale` in button classes.
**Deliverable:** a "UI recipe card" (construction pattern + numbers) → final input for the
End Turn pick + a spec for the game-wide button unification pass.

### WS2 — Enemy AI, cadence & encounter math — **P0, effort L (biggest payoff)**
**Why:** our entire §8/§9 enemy plan (`enemy_design_analysis_2026-08.md`) was reconstructed
from wikis. This is the ground truth it never had.
**Answer these:**
- How move selection is encoded: per-enemy class? data-driven? How constraints are expressed
  (no-repeat caps, first-turn rules, "never X twice"), and the exact numbers for a few
  archetype-matched enemies (early trash, a guard-cadence enemy, a ramper, a thief, one boss
  with phases).
- HP-threshold behavior switches and phase transitions (we have almost none).
- **Anti-stall mechanisms**: do they have soft enrage / escalating timers? This directly
  decides our open §9.7 verdict (the +1 Str/turn backstop motivated by uncapped Golem
  carryover). Their answer is the strongest evidence we can get.
- Encounter pools: floor→pool mapping ("easy fights" window), weights, anti-repeat rules
  (compare our `group` mechanism), elite/boss scaling, act multipliers vs our ACT2 tables.
- Intent honesty mechanics: rider ordering, multi-intent, hidden/unknown intents.
**Start here:** `ls src/Core/Models/` for a Monsters/Enemies dir; pick 5 enemies via
`localization/`; grep `Intent|pattern|history|lastMove|threshold|enrage`; find the encounter
table via the room/run generation code (`CombatRoomHandler.cs` under AutoSlay shows the
handler shape — the real one is probably under `src/Core/` map/run code).
**Deliverable:** "theirs vs ours" table feeding exact numbers into the §8/§9 batch + a
one-page answer on soft enrage. Flag VERDICT NEEDED items for Julien.

### WS3 — Economy & reward numbers verification — **P1, effort S**
**Why:** our odds/pricing were built from community data and feel; cheap to verify against
ground truth. Low urgency because ours are playtested and work.
**Answer these:** card reward odds per context + pity implementation; gold ranges per room
type and act; shop composition, price ranges per rarity, removal cost curve, reroll pricing;
campfire heal %; event pool gating (act-gated? once-per-run? weights). Ascension modifier
list (future difficulty reference, skim only).
**Start here:** grep `rarity|weight|pity` under `src/Core/` reward/shop code; localization
for shop strings → keys → code.
**Deliverable:** side-by-side constants table; only deltas that matter get verdicts.

### WS4 — Juice: the impact stack & enemy deaths — **P0, effort M**
**Why:** the trailer is the point of all the juice work, and our most clippable missing beat
(enemy death) is unbuilt. We copied their card choreography from video; here we get the
actual numbers.
**Answer these:**
- **Enemy death sequence, end to end**: layers (dissolve shader? particles? corpse fade?),
  durations, sound timing. This becomes the spec for ours.
- The attack impact stack: which layers (flash/shake/hit-pause/particles/number), with ms
  values and amplitudes. Compare against our slash + thrown-dice bash values.
- Damage number behavior: font, motion curve, lifetime, crit treatment.
- Card play choreography timings (verify the values we eyeballed from video).
- `shaders/`: skim for death/dissolve/outline/highlight techniques worth reimplementing.
**Start here:** grep `Nodes/` + `Combat/` for `death|die|dissolve|shake|hitstop|freeze|
pause`; `ls animations/ shaders/`; read the creature/combat node classes' tween code.
**Deliverable:** timing table vs ours + a concrete "enemy death" spec proposal.

### WS5 — Onboarding, FTUE & map communication — **P1, effort M**
**Why:** the one unaddressed playtest complaint: "je comprends pas la map". Launch-relevant.
**Answer these:** how the map teaches itself (path preview, current-position marker, hover
states, legend, embark flow); their first-run gating (tips shown once, "first time you see
X" flags, tutorial structure); how they stage complexity in the first hour.
**Start here:** map scene + map node classes; grep `FirstTime|seen|tip|tutorial|ftue`.
**Deliverable:** list of teaching moments we lack, each with a cheap/expensive version.

### WS6 — Architecture ideas (observational, post-launch) — **P2, effort M**
**Why:** we're not refactoring before launch. But their shape is the "what good looks like"
reference for after, and a few ideas may be trivially cheap now.
**Answer these:**
- The `GameActions/` command-queue: how actions are queued/resolved/undone (they undo END
  TURN — player-facing?). What ordering problems does the queue solve that we handle ad hoc?
- `Models/` vs `Nodes/` separation; how content classes (one per card/relic) register —
  compare our .gd+.tres pairs (this likely VALIDATES our pattern; say so if true).
- Hook taxonomy: enumerate their trigger points (on-draw, on-shuffle, on-damage-final, etc.)
  vs our `Events` signals — the gap list = future content enablers (things we currently
  cannot express as a card/relic).
**Deliverable:** memo, max 5 ideas, each with cost/benefit and a post-launch tag unless
genuinely free.

### WS7 — Edge-case & input-locking checklist — **P2, effort S**
**Why:** cheap insurance. Their handled-cases are a QA checklist for bugs we haven't hit yet.
**Answer these:** death-mid-effect and retargeting rules; simultaneous trigger ordering;
input locking during resolution (their equivalent of our `_turn_cycle_active` — we shipped a
double-end-turn bug, they presumably solved this class of problem); stacking merge rules;
"can't play this card" messaging vs our refusal UX.
**Start here:** grep `IsValid|retarget|locked|CanPlay|queue` in `Combat/`+`GameActions/`.
**Deliverable:** checklist of cases → quick pass marking each: handled / unhandled / N-A.

### WS8 — Dev & test infrastructure — **P2, effort S (one gem)**
**Why:** `src/Core/AutoSlay/` is an AI that plays their game — that's a balance-testing bot.
We already have a harness culture; this is the next rung (imagine 100 headless runs
overnight telling us Golem stall winrates).
**Answer these:** what AutoSlay does (policy? scripted? random-legal-move?), how it's driven,
what it reports; their test runner conventions (`RiderTestRunner/`); debug flags/console.
**Deliverable:** short note: is a minimal "AutoDaiso" worth building post-launch, and what's
the smallest useful version.

---

## Do-not-mine list (big, tempting, irrelevant)

- `Multiplayer/` everything (huge surface, we're single-player)
- `ControllerInput/`/`MegaInput` (post-launch at best)
- FMOD/`banks/`, Spine/`models/`, platform/Steam code, save/cloud serialization internals
- `localization/` as content (use only as an index to find things)
- Their art, in any form, ever.

## Suggested session slicing (for Opus execution)

1. **Session A (P0 visual):** WS1 then WS4. Both are scene/node reading; findings feed the
   button pick and the death-anim spec. Start by creating `sts2_audit_2026-08.md`.
2. **Session B (P0 design):** WS2 alone — it's the big one. Bring
   `enemy_design_analysis_2026-08.md` §8/§9 into context first so numbers land somewhere.
3. **Session C (sweep):** WS3 + WS5 + WS7.
4. **Session D (optional/post-launch):** WS6 + WS8.

Each session: open this plan, work its workstreams top-down, write findings as you go (not
at the end), stop at the effort box, leave a "next probes" note per unfinished thread.
