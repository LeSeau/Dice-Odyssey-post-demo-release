# Dice Odyssey — Card Pool Depth Expansion (2026-07-06)

Companion to `card_pool_analysis.md` (2026-06-24 audit) and `balance_analysis_2026-07.md`. Scope of this pass, per Julien's brief: analyze ONLY the starter deck + `warrior_draftable_cards.tres`, rate every major mechanic on generators/enablers/payoffs/finishers, then add a SMALL number of high-quality cards where the pool is weak — depth over volume, "reward HOW the player generated Power", no plain multiplier cards. Relics and dice in this doc are **designs only, not implemented** (cards ARE implemented and in the pool).

## 0. Ground truth at time of analysis

- **Pool: 60 cards** (post all 2026-06/07 cuts and reworks). Now **68** with this pass.
- **Starter deck (11)**: currently Bullseye + 3× Strike + 4× Block + Low Blow + Reinforce + Recombobulate — Bullseye sits in the 4th Strike's slot. **Julien confirmed (2026-07-06): test insert, leave as is.**
- **4 of the 9 Blessings built on 2026-06-24 are NOT in the draftable pool**: Precision Engine, Counterweight, Guard Stance, Lucky Sevens. **Julien confirmed (2026-07-06): intentional cut ("not a fan"), do not re-add.**

## 1. Mechanic ratings (1–10)

"Generators" create the resource/condition · "Enablers" make it consistent · "Payoffs" reward it mid-size · "Finishers" end fights with it.

| Mechanic | Gen | Enab | Payoff | Finisher | Verdict |
|---|---|---|---|---|---|
| Power banking (spend X) | 9 | 8 | 9 | 8 | Saturated. Add nothing. |
| Exact / Multiple | – | 9 | 8 | 7 | Best-served archetype (by design). |
| Scout | 8 | – | **3** | – | 6 sources, but scouting itself pays nothing — it's pure info funneled into Exact. |
| Boost | 7 | – | 2 | – | Glue between archetypes (deliberate per design doc). Fine as glue. |
| **Red dice (gamble)** | **2** | 3 | 4 | **2** | Worst pillar. **No card adds Red dice** — a "red deck" is literally impossible to build. Payoffs: Flurry/Kamikaze/Berserk only. Known-thin (design doc priority #7). |
| Low Roll (Green) | 6 | 7 | 7 | 5 | Healthy: Catapult/Finesse/Unity/Fumigation/Geomancy/Overdrive + starter Low Blow. |
| Lucky / Unlucky | 3 | – | – | – | Catapult is the pool's only Lucky source. Niche; relic space, not card space. |
| **Chain shape** (`roll_history`) | 8* | 6 | **2** | 2 | **Biggest hole.** Only Diceslap reads the chain, and only its LENGTH. Nothing reads its CONTENT (pairs, values) — the dice-game fantasy (doubles!) is absent. |
| **Turn throughput** (`power_generated_this_turn`) | 8* | – | **1** | **1** | Tracked in Global since forever, read by zero player cards (only Oculus' Parasite punishes it). Whole playstyle (spend-fast volume) has no payoff. |
| Refuel | 4 | – | (2) | – | Recombobulate/Catalyst/Voodoo. Its natural payoffs are chain payoffs — which didn't exist. |
| Charge | 9 | – | – | – | Saturated (the audit already flagged the redundant Blue-charge cluster). |
| Mech | 5 | 8 | 5 | – | Fine. Cogwork + ±1 adjust + Exact synergy. |
| Giant / big single roll | 3 | 5 | 4 | 4 | Thin, and its one payoff (Smash) is exactly the "Deal X2" card this brief bans. |
| **Evil dice (0-face)** | 5 | – | **0** | 0 | The 6/6/6/0 die has ZERO interaction with its own downside. Rolling 0 is pure feels-bad. Tagline says "no bad roll, only bad builds" — the 0 disproves it. |
| Magma / AoE | 5 | – | 4 | 3 | Acceptable (Fumigation, Catapult, Tsunami cover AoE). |
| Celestial (no-dice) | 7 | – | 3 | – | 7 celestials; good glue density. |
| Blessings / engines | 8 | – | – | – | 8 in pool; healthy count. |
| **Enemy-block counterplay** | – | – | **0** | – | No anti-block tech at all, while Crab/Defender/Sigil Slug/Leviathan all run block turns. |

*\* generators exist as dice/charge/refuel cards, but nothing pays the behavior off.*

### The five holes worth filling
1. **Chain content** — nothing rewards WHAT you rolled, only what you're holding.
2. **Turn throughput** — nothing rewards spending fast and rolling a lot across the whole turn.
3. **Red** — no generators, no finisher, for a core pillar.
4. **Evil's 0** — a designed downside with no build-around.
5. **Anti-block** — a missing tactical answer, and a natural home for the underfed "big single roll" payoff.

## 2. The 8 new cards (implemented, in pool)

Fewer than the 15 allowed — the remaining holes are better served by relics/dice or deliberately deferred (see §5).

| Card | Type / Req | Text | Hole / archetype | Encourages (one sentence) |
|---|---|---|---|---|
| **Resonance** | Attack | Deal X damage. If your last two rolls match, your Power is not reset | Chain content / pairs | Engineer doubles (Scout, Focus, Even/Odd's 3 faces, Evil's 6/6/6) to attack **without losing your bank** — the chain keeps growing through the hit. |
| **Crescendo** | Attack, Exhaust | Deal damage equal to all Power generated this turn | Turn throughput / volume finisher | Anti-Doomsday: don't bank — roll, spend, refuel, spend again, then convert the whole turn's throughput into one nuke (and you end the turn low, dodging Lich/Canalize taxes). |
| **All In** | Attack, RED | Deal X damage. Spend all your remaining Red Dice: each adds its own roll | Red finisher | Stockpile Red dice all fight, then shove the entire pool into one swing — the game's purest gamble moment (Berserk doubles it). |
| **Adrenaline** | Skill | Charge 2 Red Dice | Red generator | Finally makes a Red deck buildable at all — and feeds All In's stockpile. |
| **From Nothing** | Skill (Celestial), Exact 0, Support | If your current roll is 0: gain 12 Power | Evil 0-face | Turns Evil's disaster face into its jackpot face — hold it and the 0 you dread becomes the roll you want ("no bad roll, only bad builds", literally). |
| **Breach** | Attack, Min 9 | Remove the target's Block, then deal X damage | Anti-block + big-roll payoff | Save your Giant/boosted rolls for the enemy's block turn instead of racing past it — a timing decision, not a bigger number. |
| **Foresight** | Blessing, Min 6 | Whenever you Scout, Charge 1 | Scout payoff | Scouting stops being pure information and becomes an engine — with Marionette it's a free die every turn, so Scout cards get drafted for tempo, not just accuracy. |
| **Perpetual Motion** | Blessing, Min 6 | The first time you run out of Dice each turn, Refuel 2 | Refuel engine | Rewards dumping your dice fast and completely — the opposite decision pattern from careful banking, and the engine heart of a Crescendo/Tsunami volume deck. |

**Deliberate synergy web** (each card is also a payoff for another): Adrenaline → All In; Foresight/Perpetual Motion → Crescendo/Diceslap/Tsunami; Necromancy (Evil) → From Nothing → a 12-Power bank → Resonance keeps it alive; Scout/Focus → Resonance pairs; Occultism (Giant) → Breach.

**Implementation notes**
- All follow existing plumbing only: `Global.roll_history` (Resonance), `Global.power_generated_this_turn` (Crescendo), `Global.no_reset` (Resonance, same valve as Eclipse), `Events.scout_effect` (Foresight), `Events.dice_rolled` + dice counters (Perpetual Motion), `stats.block = 0` (Breach). **Zero new systems.**
- Blessings follow all conventions: MIN 6 cast, `exhausts = true`, no "for the rest of combat"/"Exhaust" in text, effect lives in an EVENT_BASED status (`status_foresight`, `status_perpetual_motion`) with the LuckySevens `is_instance_valid(target)` zombie guard.
- Dynamic descriptions implemented on Resonance / Crescendo / All In / Breach / From Nothing (ink-aware where power is shown).
- All new `.tres` files carry explicit `uid=`s (per the Bullseye+ lesson). Art = recycled from CUT cards (pulse/detonation/nova/barricade/snatch/ambush pngs are pool-orphans) + scroll.jpg for Blessings; **no art duplicated against a live pool card**. Placeholder as usual.
- **No "+" upgrade versions yet** — Julien specs those himself batch-wise; `can_be_upgraded()` returns false gracefully meanwhile.
- Balance stance per house philosophy: build-defining over safe. Watch-list: From Nothing's 12 (vs Evil's 4.5 avg face) and Perpetual Motion's engine loop with Emanation/Cogwork.

## 2b. Batch 2 — the 10 "rare-feel" cards (implemented, in pool — 2026-07-06, same day)

Julien's follow-up brief after approving batch 1: 10 more cards, each with its own identity, optimized for the dopamine "YES!" at the reward screen — future rares once true rarity exists. Pool 68 → **78**.

| Card | Type / Req | Text | The "YES!" moment |
|---|---|---|---|
| **Bulwark** | Attack | Deal damage equal to your Block | The Body Slam fantasy: your Aegis turn suddenly reads as an 18-damage turn — block decks finally get a sword, and the block-payoff archetype (rated 0) is born. |
| **Cascade** | Attack (AoE) | Deal the total of your chain to ALL enemies. Only works if your chain holds 3 consecutive values | Yelling "STRAIGHT!" at a dice game — Mech's ±1 and Scout turn it from luck into a craftable Yahtzee moment. |
| **Jackpot** | Attack | Deal 6 damage. If your last three rolls all match, deal 30 instead | 6-6-6 slot machine. Evil dice (three 6-faces) hit the triple ~42% of the time — the degenerate build Necromancy always wanted to enable. |
| **Rigged** | Skill (Celestial, Support, Exhaust) | Gain Lucky 2 | Two guaranteed max rolls, playable BEFORE rolling: 12+12 on a Giant, or a certain Doomsday setup. A trump card you save all fight. |
| **Dark Pact** | Blessing, Min 6 | Whenever you roll a 0, gain 2 Strength | Third pillar of the Evil arc: 0s now scale you permanently. With From Nothing, the die's worst face is the one you pray for. |
| **Stockpile** | Blessing, Min 6 | At the end of your turn, keep up to 5 Power for next turn | Quietly breaks the game's most sacred rule (Power dies at turn end) — capped at 5, riding the existing `starting_power_next_turn` plumbing. Lich tension: you now always end turns "high". |
| **Transmutation** | Skill (Celestial, Support) | Convert all your remaining Dice into your active type | "ALL my dice are Magma now." The single most build-warping card in the pool — mono-type turbo for Blood Sword/Berserk/Magma dreams. |
| **Momentum** | Attack | Deal 4 damage, plus 4 for each other card played this turn | A damage source that ignores Power entirely — celestials, supports and draw suddenly count as attack setup; you re-sequence your whole turn around playing it LAST. |
| **Second Wind** | Skill, Exhaust | Heal HP equal to half your Power. Exhaust | The only in-combat heal in the pool — a 24-Power bank becomes 12 HP, and at 15/66 HP it's the most beautiful card the reward screen can show. |
| **Executioner** | Attack | Deal X damage. If this kills the target, your Power is not reset | Chain executions: one big bank sweeps a 3-pack kill by kill, if your target-math is exact. Overkill is waste — precision is rewarded. |

**Identity separation notes** (each rides a different axis): Bulwark = block economy · Cascade = chain *pattern* (run) · Jackpot = chain *pattern* (triple, fixed-number slot machine — deliberately not X-scaling) · Rigged = certainty-on-demand · Dark Pact = permanent scaling via worst face · Stockpile = time (cross-turn banking) · Transmutation = dice-pool identity · Momentum = card-count (Power-independent) · Second Wind = HP conversion · Executioner = target-math. The three no-reset cards use the same valve with different psychology: Resonance (how you rolled), Shockwave (what you rolled), Executioner (what you killed).

**Implementation**: same rules as batch 1 — zero new systems (`roll_history` patterns, `cards_played_this_turn` [resets per turn in player_handler], `starting_power_next_turn` [already consumed by dice.gd at turn start], `stats.block`/`stats.heal`, Lucky duration, muscle stacks), explicit uids everywhere, art from cut-card orphans (cover/rainbow/clover_bath/cloak/beam/slice/beanstalk/bloodlust) + scroll.jpg for Blessings, dynamic descriptions on Bulwark/Cascade/Jackpot/Momentum/Second Wind/Executioner, two new EVENT/END_OF_TURN statuses (`status_dark_pact`, `status_stockpile`) with the usual zombie guards. No "+" versions yet.

**Balance watch-list** (fun-first per house rule): Jackpot's 30 with Evil dice, Transmutation into Magma (one AoE per roll × whole pool), Stockpile+Opening Gambit (carried 5 → first-roll double... they don't stack numerically, carried power isn't a roll — verified: `starting_power_next_turn` sets `roll_value` directly, bypassing roll doubling), Second Wind loops with Geomancy (×3 then heal half).

## 2c. Debuff-applier cards (NOT implemented — Julien reviewing, 2026-07-06)

Second brief from Julien, opened right after batch 2 landed: the pool has almost no enemy-debuff appliers — **only Rupture** (Deal X, Exposed 2) does this at all. Julien wants more, dice-flavored over generic STS ports (yes to Weak-style stuff, but bonus points for things that use the game's own dice identity — Sigil, Red-sensitivity, etc.), explicitly citing the Sigil Slug's native mechanic as a template worth stealing for the player.

All of these ride plumbing enemies already have (StatusHandler + ModifierHandler on `Enemy`, DMG_TAKEN modifiers already used the same way Berserk conditions DMG_DEALT on active dice type) — zero new systems, though each needs its own new Status.

| # | Card | Effect | Archetype fed | Why it's interesting |
|---|---|---|---|---|
| 1 | **Crimson Brand** | Apply Red-Sensitive: target takes +50% damage from cards played on Red Dice | Red | Realizes the old design doc's "Red Sensitive" status; the missing Red *enabler* — brand on a Blue turn, swing on a Red turn, a two-phase rhythm nothing else creates. |
| 2 | **Corrode** | Apply Rust: target loses 2 Strength at the start of each of its own turns (min 0) | Anti-ramp | The counterplay Machopeur/Plant/Lich have never had — and it gets MORE relevant as Act 2 (all enemies scaled with starting Muscle) grows. |
| 3 | **Sigil** (card) | Apply a Sigil to target: bears a number 1-6; whenever your banked Power exactly matches it, gain +1 Blue Dice. Doesn't stack (one Sigil per enemy) | Exact/Mech/Scout | Steals the Slug's own mechanic as a player tool — a POSITIVE debuff, turns any fight into an on-demand Sigil Slug minigame. |
| 4 | **Hex** | Apply Hexed: whenever you roll your active die's maximum face, target takes 5 damage | Lucky/Evil/Crit | Damage from the ACT of rolling, not from spending — second payoff lane for Lucky, Evil's 6/6/6, and Critical Edge decks. |
| 5 | **Tuning Fork** | Deal X. Apply Resonant Mark: whenever you roll a value already present in your chain, target takes 4 damage | Pairs/chain | Gives the pairs archetype (Resonance/Jackpot/Echo Chamber) a debuff limb of its own. |
| 6 | **Enfeeble** | Deal X; if X is odd, apply Weakened 2 (target deals -25% damage, 2 turns) | Odd dice | The "safe" STS-standard pick — Odd dice make the parity gate reliable rather than a coin flip. |
| 7 | **Siphon** | Apply Drain: at the end of your turn, target takes damage equal to your unspent Power | Anti-waste / anti-Lich tension | Turns "wasted bank" into a weapon — but tempts you to end turns high, which Lich's Absorb explicitly punishes. Built-in risk/reward. |
| 8 | **Shatter** | Deal X. Apply Brittle 2: target gains no Block for 2 turns | Anti-block (alternate) | Suppression cousin to Breach's timing-based anti-block — **pick one of the two, not both**, they'd overlap the same hole. |

Julien flagged as strongest picks (marked in original proposal): Crimson Brand, Corrode, Sigil, Hex — each feeds an archetype already in the pool rather than existing as a generic debuff. **Open question before implementation**: how the Slug's own native Sigil mechanic is wired (`sigil_enemy` / `enemies/sigil_slug/`) needs a read before promising card #3 is a pure reuse — flagged, not yet investigated.

## 2d. Big-power payoff cards (NOT implemented — Julien reviewing, 2026-07-06)

Third brief, same session: Smash (Deal X2, Max... actually Min 10, X2) is the only "big power feels powerful" payoff, and Julien doesn't want more X2/X3 clones (he already has Meteorite sitting as an unpooled near-duplicate at a higher threshold). Explicit design goal: cards that reward comfortably hitting ~10-15+ Power, WITHOUT being dead weight in Act 1 (currently the whole game for public players) — this is also forward-looking prep for Act 2+, where Power ceilings will climb further and Strike shouldn't be the only thing worth playing at 30+.

| # | Card | Effect | Shape (vs Smash's flat X2) |
|---|---|---|---|
| 1 | **Tidal Force** | Deal X damage; Power above 10 counts DOUBLE | Rewards the SURPLUS, not the total — Strike-equivalent at 10, 30 at 20 Power, 50 at 30 Power. Never dead early, monstrous later. Strongest recommendation for the Act 2 problem specifically — no requirement gate, draftable turn 1, grows with the run's ceiling. |
| 2 | **Earthquake** | Min 12: Deal X damage to ALL enemies | The threshold AoE — Fumigation's big sibling, swarm fights make the number feel enormous. |
| 3 | **Obliterate** | Min 10: Deal X; damage beyond the target's HP carries over to the next enemy | Overkill stops being wasted — lining up a kill order at 25 Power is a puzzle, not just a number. Spiritual sibling to Executioner (that one KEEPS Power on a kill, this one SPILLS damage on a kill). |
| 4 | **Juggernaut** | Min 12: Deal X and gain X Block | Duo's dual-purpose shape, pushed to threshold scale — one big bank resolves the whole turn. |
| 5 | **Dominance** | Min 15: Apply Exposed 2 to ALL enemies and gain X Block | Bridges both new areas (debuffs + big power) — spends a huge bank on board control instead of raw damage. Highest threshold proposed, explicitly Act-2-shaped. |
| 6 | **High Roller** (Blessing) | Whenever you reach 15+ Power in a single bank, gain 2 Strength (once per turn) | The ENGINE version of "big power feels good" — mirrors Oculus' Parasite trigger onto the player; makes repeatedly reaching the threshold the build, not a single payoff card. |

Design guardrails applied: nothing above Min 15 (mid-run Act 1 already reaches 16-22+ Power per the balance doc's P-by-stage table, so nothing here is dead-on-arrival for the public build); no two cards share a payoff shape (damage-surplus / AoE-threshold / overkill-carryover / dual damage+block / board-control / recurring-engine); Tidal Force deliberately ungated so it scales gracefully across acts without needing a redraft.

**Implementation notes for later**: Rust, Hexed, Resonant Mark, Drain, Weakened, Brittle, Red-Sensitive are all new Status resources but reuse existing hook types (dice_rolled, START_OF_TURN, DMG_TAKEN modifier) — same effort class as `status_dark_pact`/`status_perpetual_motion` from batch 2. Area 2 (big-power payoffs) is pure card-script work, no new statuses needed at all except High Roller's Blessing status.

## 3. Relic designs (NOT implemented — pick and I'll build)

Chosen to feed existing/new archetypes, no flat "+damage" anywhere.

| # | Relic | Effect | Why / build |
|---|---|---|---|
| 1 | **Cartographer's Quill** | Your Scout cards show 5 faces instead of 3 | Scout/Exact consistency; the Scout-5 panel already exists in battle.tscn — cheap to build, big draft signal. |
| 2 | **Snake Eyes Charm** | Whenever you roll a 1, gain 1 Strength | Makes the worst normal face fuel; Low Roll decks *want* 1s, everyone else gets consolation — inverts roll disappointment. |
| 3 | **House Money** | Whenever a Red die rolls a 5 or 6, gain 3 Block | Red risk insurance that pays on the WIN (you committed blind and it landed — keep the change). |
| 4 | **Echo Chamber** | Whenever you roll the same value twice in a row, Boost 2 | Pairs-archetype glue; makes Resonance decks hum and Even/Odd dice (3 faces) quietly better. |
| 5 | **Obsidian Scale** | Whenever you roll a 0, draw 2 cards | Second Evil-0 payoff; with From Nothing, a 0 becomes "12 Power + 2 cards" — the full dark-bargain fantasy. |
| 6 | **Metronome** | Every 3rd die you roll each turn gives +2 Power | Volume/refuel reward that scales with behavior, not stats. |
| 7 | **Overflow Valve** | At end of turn, unspent Power becomes Block (max 8) | Kills the "wasted bank" feels-bad — but you now END turns high, which is exactly what Lich's Absorb punishes. Built-in tension. |
| 8 | **Prayer Beads** | Your Blessing cards can be cast on any roll | Blessing decks come online turn 1 instead of fishing for a 6 — a real "build enabler" relic. |
| 9 | **Flywheel** | Whenever you Refuel, Boost 2 | Links the refuel engine to the NEXT chain; Recombobulate/Catalyst/Perpetual Motion payoff. |
| 10 | **Trick Scale** | Your Mech dice can adjust ±2 instead of ±1 | Upgrades the expert Scout+Mech line (the one Julien himself plays) without touching damage. |

## 4. Dice designs (NOT implemented — pick and I'll build)

Each priced against the Magma-270 / Green-150 band, with a real reason to buy AND a real cost.

| # | Die | Faces / behavior | Strength | Weakness | Synergy | Shop |
|---|---|---|---|---|---|---|
| 1 | **Sticky** | d6, 1–6; switching away from it does NOT reset Power | Multi-type turns: bank on Sticky, switch to Red for Blood Sword/Berserk/RED cards without losing the bank | Vanilla faces, does nothing alone | Blood Sword, Berserk, All In, every RED requirement | ~230g. (The doc's long-planned die, now spec'd; touches the reset code — most complex build.) |
| 2 | **Anchor** | d6, faces 2–5; unrolled Anchor dice carry over to next turn | Action-economy banking: skip a roll today, have 4 dice tomorrow | Never rolls a 6 or a 1 — no spikes, no Low Roll | Setup turns before Crescendo/Doomsday; Lich counterplay (roll nothing, absorb nothing) | ~200g |
| 3 | **Gemini** | d4, 1–4; each roll counts as TWO rolls of that value (chain +2, per-roll effects trigger twice) | Engine accelerator: Hardened Grip, Diceslap, Metronome, Lucky Sevens all double-tick — and it always pairs with itself for Resonance | Tiny face values (max 4 Power per roll) | Resonance, Echo Chamber, every "per roll" effect | ~220g |
| 4 | **Mirror** | No faces: always rolls whatever your previous roll was (first roll of a chain = 1) | Deterministic pairs and Exact math: roll a 6, mirror a 6 | Worthless opener; faithfully copies your bad rolls too | Resonance/Echo Chamber, Bullseye (6→6 = guaranteed Mult 6), Calculations | ~250g |
| 5 | **Leech** | d6, faces 1–4; heals 1 HP whenever rolled | Sustain between campfires — HP as a slow drip | Lowest damage ceiling in the game; hurts throughput | Volume decks that roll a lot anyway (Perpetual Motion) | ~180g |
| 6 | **Casino** | d6; each roll resolves on a random OTHER die type's face table (can 1–12, can AoE, can 0) | Cheap chaos with jackpot moments (Giant 12s, free Magma splashes) | Unplannable — poison for Exact decks | Recombobulate (reroll the chaos), From Nothing (it can roll 0!) | ~150g — the impulse buy |

## 5. Still underserved (deliberately deferred — future expansion material)

- ~~Block-payoff / retaliation archetype~~ — **partially filled by Bulwark (batch 2, §2b)**: damage = current Block. `has_blocked_last_turn` (Dragonpriest spaghetti, retaliation-on-hit) remains untouched — a true "you blocked well, now retaliate" enemy-reaction card is still open.
- ~~Straight/run chain patterns~~ — **filled by Cascade (batch 2, §2b)**: 3-consecutive-values chain check, AoE payoff. A second card reading chain patterns (e.g. a full run of 5, or "no repeats") is still open if Cascade proves players actually read `roll_history` shape.
- **Type-switching / rainbow** — blocked on the Sticky die by design; a card there now would fight the core reset rule. Transmutation (batch 2) goes the OPPOSITE direction (mono-type funnel) rather than filling this hole.
- **Lucky generators** — still only Catapult + Rigged (§2b). Echo Chamber (relic, §3) is the gentle fix before dedicating another card.
- **Magma/AoE payoffs** — "if you hit 3+ enemies this turn" space, untouched. Earthquake (§2d, proposed) is a threshold AoE, not a hit-count payoff — different hole.
- **Boost payoffs** — kept as glue on purpose; revisit only if Boost decks emerge.
- **Hand/discard manipulation** — real new system; out of scope by brief.
- **The 4 shelved Blessings** (Precision Engine, Counterweight, Guard Stance, Lucky Sevens) — **RESOLVED**: Julien confirmed intentional cut, do not restore (see §0).
- **Debuff-applier cards** (§2c) and **big-power payoff cards** (§2d) — designs proposed 2026-07-06, **awaiting Julien's review before any implementation.** Do not build until he picks.
