# Dice Odyssey — Enemy Design & Combat Pacing Analysis (2026-08-08)

**STATUS: ANALYSIS ONLY — NOTHING IMPLEMENTED.** Requested by Julien: "let's add spice, tension,
variety & pace to combats. But don't implement yet." This doc is the STS1/STS2 study + the
dice-native enemy design space + concrete proposals, to be reviewed and cherry-picked.

**⚠️ SCOPE NARROWED BY JULIEN (same day, after reading): focus is polish & marketing — no new
systems/enemies for now. Keep only (a) a pattern/numbers pass on EXISTING enemies to escape the
"attack, block & gain strength, same attack" trap, and (b) maybe 2-3 curse/status cards. That
scoped plan is §8 — read it first; §1–§7 remain as the reference analysis and the post-launch
menu (new fights, die theft, timers, summons, Dicelord P2 are all PARKED). §9 (added 2026-08-13,
on Julien's follow-up "pretty much every fight should have an implicit timer") extends §8 with
an enemy-scaling ramp column — same scope philosophy, designed to land in the same batches.**

**Sources**: (a) deep-dive of the STS1 Fandom wiki per-enemy Pattern sections (decompiled move
logic: weights, repetition caps, conditional overrides, A17/18/19 pattern changes) + the GDC 2019
MegaCrit talk; (b) STS2 wiki.gg (EA since **March 2026**, ~5 months of patches — full movesets
documented) + patch notes + community reception; (c) a fresh code dossier of all 21 Dice Odyssey
enemies (every action script, AI scene, tier .tres, pool entry — 2026-08-08 working tree);
(d) `balance_analysis_2026-07.md` (D/P model, agreed principles), `balance_analysis_2026-07-14.md`,
`balance_audit_2026-07-27.md` (elite taxonomy, roster gaps), `lurker_oculus_swap_spec_2026-07.md`.

**Relationship to the launch plan**: `launch_checklist_2026-07.md` already lists "Act 2 real
content (unique movesets)" as Steam-phase work. This doc is effectively the design for that item,
plus a cheap act-1 texture pass and two wiring/honesty bugs found during the audit (§2.4) that are
worth fixing before any of it.

---

## 1. Why STS combat has rhythm — the grammar worth stealing

Distilled from both games. Each principle below is something Dice Odyssey can adopt without
copying a single enemy.

### 1.1 The five-part AI grammar

Nearly every STS enemy's move selection is composed from the same five parts:

1. **Weighted random move table** — percentages encode personality (Book of Stabbing 85%
   multi-stab = relentless; Repulsor 80% pollution = passive-aggressive).
2. **Repetition caps** — "never twice in a row" / "not 3× in a row". This is the texture
   generator: pure RNG that *feels* hand-authored, bounds worst-case streaks, and guarantees the
   gimmick shows up. Cheapest tool in the box.
3. **Conditional overrides** checked before the roll — turn number (openers, Collector's turn-4
   Mega Debuff), own HP (splits, phase flips), own resources (minion count, once-per-fight flags),
   **player state** (Spire Growth checks whether YOU are Constricted; Mystic checks ally missing
   HP), partner state (Centurion changes kit when his healer dies).
4. **Per-combat rolled parameters** — Louse rolls its bite damage 5–7 once per battle; gremlin
   gangs roll their composition. Cheap per-instance variety, zero new content.
5. **Player-caused interrupts** — splits, mode shifts, armor-break stuns, wake-ups overwrite the
   displayed intent mid-round. STS allows breaking its own telegraph promise **only when the
   player caused it** — never the RNG.

**Bosses trend MORE deterministic than normals** (Hexaghost's 7-beat wheel, Automaton's fixed
6-beat loop, Donu & Deca's offset alternation): a scripted 35-damage slam you saw coming for two
turns is fair; a random one isn't. Boss difficulty = executing a plan against known escalation.

### 1.2 Every fight is a clock

The single deepest STS rule: **no fight is stable-state**. Something always degrades — enemy
stats ramp (Ritual/Cultist, +3 Str/turn Orb Walker), use-counters escalate (Book's 6×N), your
deck rots (status injection), or a hard timer runs (Lagavulin's sleep, Exploder's 3-turn bomb,
Giant Head's countdown, Transient's 5-turn self-destruct). Turtling always loses to math, so the
correct play is always forward — that's where pace comes from. Conversely, STS inserts deliberate
**pacing valves**: zero-pressure beats (Preparing, Stunned, Charging, sleep turns) roughly once
per boss loop, so the player can breathe and set up.

### 1.3 Openers state the fight's thesis

Almost every STS enemy has a forced first move that installs the gimmick turn 1 (Cultist's
Incantation, Snecko's Confused, Gremlin Nob's Enrage, The Insatiable's death-countdown). Most
openers deal **zero damage** — a grace beat disguised as menace, which also hands the player one
free race turn. Dice Odyssey already does this (Machopeur, Lich, DP, Vortex — documented as the
"free race turn" pattern in the July balance doc) — the difference is STS openers install a
*rule*, ours mostly install a *stat*.

### 1.4 Counterplay is authored into the enemy (STS2's biggest evolution)

STS1 fights were mostly "damage race + handle the debuff". STS2 builds a **button** into most
kits: stun it by fully blocking its hit (Bowlbug's Imbalanced), break its guard with hit count
(Byrd, Flutter), HP-threshold stuns with a free turn (Ceremonial Beast loses ALL Strength at
150 HP), kill-to-refund theft (stat vampires return everything on death), kill-before-deadline
(Thieving Hopper flees with your cards on turn 5). **"Steal with a receipt"**: theft of
cards/gold/stats is always recoverable via a kill or a deadline — tension without permanence.

### 1.5 The deck is a second HP bar

Status-card injection (Slimed/Dazed/Wound/Burn/Void) is damage aimed at **tempo and draw
equity** — a resource HP-focused players don't guard. It scales inversely with deck quality
(thin optimized decks feel each dead card most — elegant rubber-banding against the strongest
builds), it compounds (harmless now, lethal over 10 turns), and destination is a severity dial
(draw pile hits now, discard pile hits later, top-of-draw hits guaranteed next hand). STS2 doubled
down: **Afflictions** curse the cards themselves (Bound: only 1 playable/turn; Tangled: costs
more; Galvanized: hurts you when played), and junk became *interactive* (Beckon: lose 6 HP if
held; Wither: punishes holding; Frantic Escape: junk that is also the escape mechanism).

### 1.6 Roles, not bodies

Multi-enemy fights are kill-order interviews built from roles: **protector** (Shield Gremlin
shields allies, converts to attacker when alone), **healer** (Mystic — threshold-triggered, so
chip damage action-locks her into heal-botting: two valid opposite plans), **buffer**, **summoner**
(Gremlin Leader's action table changes with minion count — add-clearing is tempo control, not
chores), **bomb** (Exploder/Daggers hijack targeting with short fuses), **thief**, **metronome**
(Taskmaster). Identical bodies get **desynchronized cycle offsets** (Sentries, Darklings, STS2's
Gardeners) so threats never land in lockstep.

### 1.7 Information rules

Damage numbers are **always shown exactly** (block math must be answerable); *events* (splits,
summons, transformations) may hide behind the "?" intent — surprise is allowed, ambush of your
HP bar is not. STS2 kept this and removed the one relic that hid intents. Writhing Mass is the
exception that proves the rule: hitting it re-rolls its intent — information as a destructible
resource. Dice Odyssey's Ink is actually a **novel third door** neither STS game has: hiding the
player's *own* resource instead of the enemy's plan. Worth extending (§3.2-G).

### 1.8 Curriculum structure

Acts draw their first fights from an **easy pool** before switching to the hard pool; act 1
normals are one-lesson bodies; act 2 attacks your *rules* (attack shapes, card types, costs);
act 3 inverts win conditions (race/survive/synchronize). Elites are exams that invalidate one
lazy default each. Dice Odyssey's 3-tier structure already does the between-tier half of this;
the within-act complexity ramp (§1.4 devices appearing gradually) is the missing half.
Ascension's top tiers change **patterns, not numbers** (A18 Gremlin Nob goes deterministic;
Snake Plant locks into its optimal loop) — the same enemy supports 4+ difficulty tiers with zero
new art. Free future-hard-mode design for Dice Odyssey: tighten repetition caps.

### 1.9 The guardrails

- **The complexity threshold** (MegaCrit, June 2026, deleting the Doormaker boss): "interesting
  micro decisions… but over the complexity threshold of what we want." They replaced a shipped
  triple-lockout boss with a *simpler* one whose depth lives in one accumulating status. Julien's
  "don't overkill act 1" instinct is this doctrine.
- **Tax, don't delete** (the Awakened One anecdote): when data showed it was *crushing*
  power decks rather than taxing them, they reduced the punisher rate and raised flat damage.
  A counter-enemy should tax an archetype, not delete it.
- **Fight-length bloat is the #1 STS2 community complaint** — damage caps, respawn chains and
  revives literally add turns. Any mechanic that extends fights past the tier's turn target needs
  to buy that time with real decisions.

---

## 2. Dice Odyssey today — the honest audit

### 2.1 The census (Julien's complaint, measured)

From the code dossier (21 enemy kits, 2026-08-08 tree):

- **14 of 21 are flat deterministic loops** — fixed 2/3-beat cycles (Defender 10 → 2×6 → block;
  Goblin 7 → 7 → 5+Unlucky; Oculus/Plant attack → buff → attack) or literally the same number
  every turn (Lurker 6, Lich 8, DP 11, Machopeur 4+ramp).
- **7 use weighted-random with caps** (Satyr, B.Satyr, Medusa, Crab, Hound, Leviathan, Chimera) —
  the STS default grammar. Note several "weighted" enemies are secretly deterministic: small/big
  Kraken's mutual-exclusion gates force strict A-B alternation; Vortex alternates after turn 1;
  Temple Defender's three `chance_weight = 4.0` values are **dead** (no `type=1` line → all
  CONDITIONAL).
- **3 turn-cadenced beats exist in the entire game**: Crab's every-4th-turn 12, the Dicelord's
  every-3rd-turn theft, the tutorial Skeleton's scripted 35.
- **4 mechanics react to how the player plays**: Canalize (bank > 12), Parasite (>15 generated in
  a turn), Greedy (per 6 dice rolled), Absorb (last die face) — all elite or tier-1-solo.
- **Zero** of: HP-threshold behavior, phases, timers/countdowns, summons, healers, protectors,
  thieves (except the act-2 boss), deck injection, hit-count/full-block counterplay, desync
  offsets on twin bodies, per-combat rolled parameters, "?" intents.

So the "attack, block & gain strength, same attack" feeling is real and structural: most fights
have a CLOCK (ramps everywhere — good) but a flat QUESTION (block-the-big-one, race-the-ramp) and
no EVENTS (nothing ever changes mid-fight, nothing reacts to you below elite tier).

### 2.2 What's already genuinely good (protect it)

- **The bank-tax family is ahead of STS1's act 1.** Five *different* resource taxes (Flux on
  throughput, Parasite on per-turn generation, Canalize on bank size, Greedy on roll volume,
  Absorb on the last face) is exactly STS's "punisher pincer" idea, applied to the game's own
  core resource. The July audit's elite taxonomy (volume/bank/face) is a real design asset. It's
  also **over-covered** — §3 deliberately adds no new bank taxes.
- **Weak/Unlucky are already dice-facing debuffs** — the enemy roster attacks the roll, not just
  HP. Goblin is the game's only Unlucky applier (confirmed in code).
- **Ink is an original info-warfare device** (hides YOUR resource, not their plan).
- **Sigil is a positive mini-game** (match the number → bonus die) — the roster's one playful
  reactive mechanic, and it's charming.
- **The tier structure = STS's easy-pool/hard-pool curriculum**, already in place, validated by
  playtests. Tier 0 stays a teaching tier (agreed principle).
- **Crab/Skeleton is the model citizen**: weighted moves + repeat cap + a telegraphed cadence
  spike. It's the pattern every "vanilla" enemy should look like.
- **Dice Theft (Dicelord) proved the key implementation pattern**: an act-gated CONDITIONAL
  action node (`Global.current_act >= 2` in `is_performable()`) added to a shared AI scene gives
  an act-2 identity a new move with **zero act-1 risk**. The entire act-2 roster below rides on
  this precedent.

### 2.3 Device coverage — STS vs Dice Odyssey at a glance

| Device | STS example | DO today | Proposal (§) |
|---|---|---|---|
| Weighted moves + repeat caps | everyone | 7 of 21 kits | default grammar for new/edited kits (§4.1) |
| Scripted opener installs a RULE | Cultist, Snecko | openers install stats only | act-2 kits (§4.3) |
| Telegraphed cadence beat | Champ's turn-4 Taunt | Crab spike, Dicelord theft | more of these — cheapest texture (§4.1) |
| HP-threshold event | Slime split, Champ Anger | **none** | Hound enrage (§4.1), Dicelord P2 (§4.5) |
| Sleep / countdown / timer | Lagavulin, Exploder, Giant Head | **none** (documented gap) | Cinderlord ritual (§4.6) |
| Playstyle punisher | Nob, Time Eater, Snake Plant | bank-tax family (rich) | attack-shape pincer via Thornheart (§4.3) |
| Deck/status injection | Slimed/Dazed/Burn | **none** | junk-card system (§4.4) |
| Theft with a receipt | Thieving Hopper, Stasis orb | Dicelord (1 turn) | die hostage, gold thief (§4.2-4.3) |
| Roles: protector/healer/summoner | Shield Gremlin, Mystic, Reptomancer | **none** (documented gap) | Warden, Satyr Shaman, Necromancer (§4.2-4.3) |
| Desync offsets on twins | Sentries, Darklings | none (twins run same RNG) | free win on pack fights (§4.1) |
| Full-block / hit-count counterplay | Bowlbug, Byrd | none | Ravager Imbalanced (§4.3) |
| Enemy rolls dice / own economy | Spiny Toad banks Thorns | **none** | Roll the Bones, Onlooker mirror (§4.3, §4.5) |
| "?" intent (authored surprise) | splits, summons | none — everything exact | one per act max (§4.3 Wisp) |
| Pattern-dial difficulty (A17+) | Nob goes deterministic | n/a | future ascension lever (§6) |

### 2.4 Found during this audit — fix these regardless of everything else

1. **Absorb has NO tooltip.** No entry in `status_tooltip.gd`, empty `.tres` tooltip → the Lich's
   whole mechanic shows "No description available". The balance docs assumed elite counterplay is
   "taught only by tooltips" — for the Lich it isn't taught at all. Cheap, pre-release-worthy.
2. **Flux's tooltip lies.** Tooltip: "prevents you from rolling the same Dice type twice in a
   row." Code (`dice.gd::roll_dice`): refuses **any** roll while `roll_history` is non-empty —
   i.e. one roll per Power-reset, switching type doesn't help. The July balance docs describe the
   code behavior; the tooltip (and the lurker swap spec) drifted. Decide which is the design:
   the coded version is harsher but is also what got playtested/priced (Flux ≈ 15–20 virtual
   EHP). Recommend: keep code, fix tooltip ("prevents you from rolling again until you spend
   your Power").
3. **Fallback-driven kits** (known, on the post-launch list, repeated here because every proposal
   depends on it): Lich, Gargantua, Sigil Slug, Minotaur run their main loop through the
   anti-freeze `get_child(0)`. Explicit `is_performable() → true` on intended steady attacks is
   the prerequisite for any pattern work on those scenes.
4. Minor: Goblin's `goblin_attack_action_2.gd` comment claims a double hit it doesn't perform;
   Chimera (unreachable) hits 6 instead of its scene-authored 12 via the `base_damage` snapshot
   footgun — both harmless today, both traps for future editors.

---

## 3. The dice-native design space

### 3.1 Julien's idea list, mapped

Every idea from the request, where it lands (several were already in the old design notes as
planned statuses — Strict, Stuck, Red Sensitive — this is partly your own backlog resurfacing):

| Julien's idea | Verdict | Proposal |
|---|---|---|
| Take a die for a turn | **exists** (Dicelord Dice Theft) | escalate in P2 (§4.5) |
| Take a die **until killed** | best single new mechanic | Harlequin die hostage (§4.3) |
| Force a certain dice type first | = old planned "Strict" | Tempest's Gale (§4.3) |
| Apply Unlucky | exists (Goblin only) | give act-2 Bog Hag a 2-stack version; keep rare |
| Extra damage from Red dice | = old planned "Red Sensitive" | Gorgon: +50% from red-socketed cards — "she can't petrify what doesn't look at her" (§4.3) |
| Enemy rolls a die himself | the most on-brand idea of the list | Roll the Bones template (§3.3 rule 1, §4.5) |
| Negative cards: must play first | junk "Hex" | §4.4 |
| Negative cards: reduce roll value | junk "Lead Die" (interactive junk, STS2-style) | §4.4 |
| Negative cards: can't roll Red while held | junk "Cursed Pact" (wave 2) | §4.4 |
| Negative cards: inert do-nothing | junk "Sludge" (= Slimed) | §4.4 |
| More Ink / thinking-warfare | Blind Roll (the trailer gag as a mechanic) | Deepling (§4.3) |

### 3.2 The full lever catalog

Organized by family. Each lever: what decision it forces / cost / act placement. Levers marked ★
are the ones the proposals in §4 actually use — the rest are inventory for later.

**A. Dice-pool attacks (resource denial)**
- ★ **One-turn theft** — exists (Dicelord). Plumbing: `*_dice_bonus_amount -= 1`, self-healing
  at refill. Cheap, reusable.
- ★ **Hostage until killed** — a die leaves your pool while the thief lives; killed (or fight
  ends) → returned. The STS2 "receipt" pattern. Forces a kill-order decision every turn it's
  alive. Belongs on a LOW-HP body (the Lurker lesson: HP decides whether a mechanic is a puzzle
  or a tax — 2-turn rescue, not a 5-turn siege). Plumbing: persistent variant of theft + restore
  on death/battle-end. Act 2.
- **Seal a type** ("can't roll Red while I live") — harsher than hostage (denies the *type*, not
  one die). Act-2-elite-grade if ever; safety rail: never seal the player's only owned type.
- **Depleted application** — the status exists (Electrify self-inflicts it), no enemy uses it.
  A cheap "−1 die next turn" attack rider for act 2 hallways.
- **Corruption** (your Blue rolls as Evil for a turn) — flavorful, but touches the roll pipeline
  deeper than it looks. Parked.

**B. Roll manipulation (dice-facing debuffs)**
- ★ **Unlucky** (exists), **Weak** (exists) — shared vocabulary, fine to spread a little.
- **Roll cap** ("Heavy 2: your rolls above 4 count as 4") — anti-jackpot, the mirror of Weak.
  Distinct feel (truncates highs instead of shaving all). Anti-Giant/Evil tech. Inventory.
- ★ **Forced first type** (Strict/Gale) — "next turn your first roll must be [shown type]".
  Attacks sequencing, not value: you can still do everything, but your chain plan reshuffles.
  Plumbing exists in spirit (tutorial slot gating). Act 2.
- **Parity pressure** ("odd rolls deal 2 back to you") — inventory, niche.

**C. Bank taxes — deliberately NO new entries.** Five already exist; the audit calls the space
arguably over-covered. Any new act-2 enemy that needs a punisher should tax a *different* resource
(hand, dice pool, sequencing, information).

**D. Hand/deck attacks**
- ★ **Junk-card injection** — the one genuinely new SYSTEM proposed (§4.4). STS's proven
  second-HP-bar, with dice-native junk designs.
- ★ **Card petrify** — one random card in hand is stone (unplayable) for one turn, then
  recovers. Affliction-lite without deck plumbing: a temporary in-hand lock. Gorgon's signature.
- **Chaos** (exists on Vortex — per-roll discard/draw churn). Keep unique to it.

**E. Enemy-side dice**
- ★ **Roll the Bones (the template)** — when the enemy DECLARES its intent, it visibly rolls
  its own die/dice; the intent shows the **final resolved number** ("rolled 5 → hits 13").
  Variance lives *between* turns, the allocation math stays exact — see design rule 1 in §3.3.
  Massive theme payoff: enemies play the same game you do.
- ★ **Bank mirror** — an attack whose damage equals your **current banked Power at resolution**
  (intent live-updates as your bank moves). "Spend before his swing" — punishes holding, the
  complement of Parasite's punishing generation. Onlooker's signature.
- **Enemy banks its own Power** (rolls each turn, banks it, cashes out a scaled attack — the
  Spiny Toad pattern) — the full version of Roll the Bones; boss-grade. Dicelord P2 material.

**F. Red/gamble interaction**
- ★ **Red Sensitive** (takes +50% from red-socketed cards) — a *carrot* punisher-inverse: the
  fight where the gamble is correct. Teaches the red system by rewarding it. One enemy only.

**G. Information warfare (the Ink family)**
- ★ **Blind Roll** — your next roll resolves face-down; revealed when you play a card. The
  trailer's "roll in the dark, big damage anyway" gag as a real mechanic. One status, act 2.
- **Intent fog** ("?" on the enemy's own numbers) — use at most once per act, STS-style, for
  events only (a summon, a transformation), never for damage.

**H. Structural devices (not dice-specific, all missing)**
- ★ **Timer/ritual** (countdown to a big telegraphed hit) — the documented missing archetype.
- ★ **Protector / support body** — the other documented missing archetype.
- ★ **Gold thief with escape** — Looter role; meta-resource stake + hard deadline.
- ★ **HP-threshold event** — one-way mode change at ≤50%, intent-interrupting (player-caused).
- ★ **Full-block stun** (Imbalanced) — block-payoff counterplay, pairs beautifully with the
  existing Bulwark/Juggernaut block archetype.
- **Summons** — mid-fight spawn plumbing (EnemyHandler insert + layout). The heaviest lever;
  one marquee use (Necromancer), not a family.
- **Death payload / revive** — inventory; watch the STS2 fight-length-bloat warning.

### 3.3 Design rules for dice mechanics (before any implementation)

1. **Telegraphed variance only.** The agreed spike principle ("counterplay is same-turn
   allocation; spikes survivable-if-unblocked at 35–45% HP") means an enemy roll must NEVER be
   hidden magnitude at block time. Roll the Bones rolls at intent-declaration; by the time you
   allocate, the number is exact. The die roll is theater + between-turn variance, not ambush.
2. **Tax, don't delete.** Type seals/hostages must leave the player a functioning turn: steal
   only when ≥2 types owned, prefer the most-stocked type, cap concurrent hostages at 1. A
   Flux-style total lockout already exists — don't stack lockouts in one fight.
3. **Price mechanics in virtual EHP and pay for them in stats.** Flux ≈ 15–20 vEHP on an 18 HP
   body is the calibration point. Rough prices: one-turn theft ≈ 4–6 (a die's EV in Power +
   tempo); die hostage ≈ 10–15 (forces ~2 focus turns); junk card ≈ 3–5 each (hand slot for a
   cycle + purge cost), Lead Die ≈ 6–8 while held; protector block-to-ally ≈ its block × expected
   turns; bank mirror ≈ 0 (player-controlled). A fight that carries a mechanic gives the
   difference back in HP/damage so it stays inside the tier's D/P band.
4. **Mechanics must not extend fights past the turn targets** (T0 3–4, T1 3–5, T2 4–6, elites
   5–7, boss 6–9). Timers *compress* fights (good). Revives/damage caps *extend* them (the STS2
   complaint) — avoid, or budget the extra turns explicitly.
5. **One new rule per fight, max two per act-2 elite/boss.** The Doormaker rule. Vanilla bodies
   remain part of the curriculum — an act needs stat-checks between the puzzles.
6. **No copy-pasting signature statuses** (standing rule): every new aura is native to one owner;
   Weak/Unlucky/Ink/Exposed/Depleted stay the shared vocabulary.
7. **New intent categories need icons**: steal (bag), countdown (number badge), summon, enemy-die
   (die face), curse-card (card back), "?" — worth batching as one Firefly prompt session.

---

## 4. Proposals

### 4.1 Act 1 — a texture pass, not a rework (cheap, low-risk)

Act 1's hallway fights are individually defensible; the samey feel comes from device monotony,
not broken kits. Keep it vanilla-leaning (teaching act), fix texture:

1. **Desync the twin packs** — the bigger-satyr/bigger-kraken pairs currently run identical RNG
   in lockstep. Give the second body an offset (opener on beat 2) or force complementary picks
   (one attacks while the other debuffs). The STS Sentries trick, ~free.
2. **Repetition caps where missing** — small Satyr/Kraken can currently repeat forever (50/50 no
   caps). "Debuff not twice in a row" on each = strictly better texture at zero balance impact.
3. **One HP-threshold event in tier 2, as the act's phase-teaching beat**: **Lava Hound at ≤50% —
   "Molten Frenzy"** (one-way): +2 Str and its double-hit becomes the steady beat. Simple,
   readable, teaches "enemies can change" before act-2 bosses do it for real. (Hound is also the
   body that later becomes Ember Fiend, so the identity carries.)
4. **Give one more enemy a cadence beat** — the Crab-spike pattern (CONDITIONAL on
   `fight_turn % N`) is proven and cheap. Candidate: Medusa every 4th turn "Stone Stare 15 +
   Weak 2" replacing one of her weighted picks — a scheduled event to plan around instead of
   pure weighted soup. Optional.
5. **Leave alone**: tier 0 entirely (validated twice), Defender/Sigil/Goblin/Oculus/Plant strict
   cycles (they're the metronome class — STS keeps those too; the problem was that *everything*
   was one), Medusa/Leviathan weights, the elite trio's mechanics.

### 4.2 Act 1 — two additive fights that buy whole new archetypes

Both are *new pool entries* (additive = zero risk to validated content), both fill gaps the
July audit already named, both are act-1-complexity-appropriate (STS has thieves and protectors
in its act 1):

1. **Goblin Cutpurse** (tier 2, reuses Goblin art, own .tres/AI): **the Looter role.**
   Steals ~15 gold per hit (tracked), pattern: hit → hit → "Smoke Bomb" (block) → **Escapes with
   the gold on turn 4-5** (intent shows the flee). Kill it → gold returned (+ its normal reward).
   First fight in the game that can *end without a winner*; a pure DPS check with an economic
   stake, and it makes gold feel alive. New plumbing: an "escape" resolution (enemy leaves
   combat) + steal counter — moderate, self-contained.
2. **Satyr Shaman** (tier 2 comp, reuses Satyr art per the 07-04 sketch): **the support role.**
   Never attacks; each turn +2 Str to ALL allies (or alternating buff/small block-to-ally).
   Paired with a bruiser (Marauder or B.Kraken). The kill-order interview: hitting the buffer
   means eating the bruiser unblocked. One new action script; trivial plumbing.

These two, plus the Hound threshold, are the whole act-1 story. Everything spicier goes to act 2
(explicit request: complexity lives there).

### 4.3 Act 2 — real kits for the reskin identities (the flagship)

This is the "Act 2 real content (unique movesets)" Steam-phase item, designed. Implementation
rides the **Dice Theft precedent**: new action nodes in the SHARED AI scenes, gated
`Global.current_act >= 2` in `is_performable()` — act 1 physically can't change. Statuses can be
injected per-act via the `ACT2_RESKIN` table (it already applies box_mult/x_shift; an
`add_status`/`swap_status` key is the same pattern). Ship one wave at a time.

Not every identity gets a mechanic (rule 5) — 9 real kits, 3 light touches, 5 stay
pattern-upgraded vanilla:

| Identity (act-1 body) | Thesis — "the question it asks" | Kit sketch | Ancestor | Cost |
|---|---|---|---|---|
| **Harlequin** (Lurker) | *"Rescue your die or play without it."* | On its first turn, **pickpockets 1 die — held until Harlequin dies** (returned on kill/fight end). Low HP (18–22) keeps it a 2-turn rescue. **Replaces Flux in act 2** (two lockouts on one body = overdose); flat 6 dmg stays. | Thieving Hopper / Stasis orb | M |
| **Bog Hag** (Goblin) | *"Your deck is cursed."* | Keeps 7/7/5+Unlucky cycle; every 3rd turn **injects 1 Hex** (junk, §4.4) instead of the plain hit. The junk system's debut body. | Chosen's Hex / hag flavor | M (needs §4.4) |
| **Onlooker** (Oculus) | *"Spend before it swings."* | Keeps Parasite + ramp. New beat every 3rd turn: **Mirror Gaze — damage = your banked Power at resolution** (intent live-updates as your bank moves). Punishes hoarding; the player controls the hit. | Spire Growth's player-state AI | M (live intent hook) |
| **Warden** (Defender) | *"Kill the shield or the sword?"* | The 3-beat cycle's block move becomes **Block 6 to self AND each ally** in act 2. In its pair comps this creates the game's first protector. | Shield Gremlin / Centurion | S |
| **Thornheart** (Plant) | *"Your throw/multi-hit deck meets its pincer."* | Keeps the Muscle ramp. Adds **Bristle: +1 Block per hit taken this turn, escalating** (2nd hit +2, 3rd +3…, resets each turn). The anti-multi-hit half of the attack-shape pincer (Flurry/Stampede/throw volleys finally have a bad matchup; big-bank single hits shine). | Snake Plant's Malleable | S |
| **Ravager** (Marauder) | *"Full block = free turn."* | Keeps True Strength ramp. **Overcommit: if his attack is FULLY blocked, he is Stunned next turn** (intent shows it). Block-payoff decks (Bulwark/Juggernaut) get their moment; blocking becomes offense. | STS2 Bowlbug's Imbalanced | S |
| **Gorgon** (Medusa) | *"Don't look at her."* | Keeps the weighted spike kit. Adds **Petrify: one random card in hand is stone for a turn** (act-2 beat), and **Red Sensitive: +50% damage from red-socketed cards** — the red gamble is literally attacking without looking; Perseus rules. | Afflictions-lite + punisher-inverse | M |
| **Tempest** (Maelstrom) | *"The wind picks your first die."* | **Gale replaces the Chaos opener in act 2**: each of its turns shows a die type; **your next turn's FIRST roll must be that type**. Sequencing attack — your chain plan reshuffles every turn. Alternation kit stays. | old "Strict" status, formalized | M (slot-gating exists via tutorial plumbing) |
| **Deepling** (Kraken) | *"Roll in the dark."* | Ink upgraded: act-2 ink also applies **Blind Roll 1 — your next roll resolves face-down, revealed when you play a card**. The trailer gag, mechanized. Small bodies keep their loop. | Ink's own logical extension | M (UI) |
| **Cinderlord** (DP, elite) | *"Kill him before the sky falls."* | §4.6 — the ritual timer. | Lagavulin/Giant Head | M |
| **Necromancer** (Lich, elite) | *"The dead keep coming."* | §4.6 — the summoner. | Gremlin Leader | H |
| **The Dicelord** (boss) | *"He plays your game."* | §4.5 — phase 2 + Roll the Bones. | Champ/Automaton | M-H |
| Screecher (Satyr) | light touch | Weak family + pairs at desync offsets; optional "Screech: discard 1 random card" rider on the big body. | — | S |
| Wisp (Sigil Slug) | light touch | Keeps the Sigil number game (it's good). Optional: the game's one **"?" intent** on its 3rd beat. | — | S |
| Gnawer / Devourer / rest | vanilla-plus | Pattern upgrades only (caps, desync). An act needs stat-checks between puzzles. | — | ~0 |

The wave grouping in §6 orders these by value-per-effort.

### 4.4 The junk-card system (the one new system worth building)

STS's proven "second HP bar", with dice-native junk. Scope-checked against the codebase:

- **Plumbing is smaller than it looks.** Fight piles (`draw_pile`/`discard`) are rebuilt from the
  persistent deck each battle, so mid-fight injection is naturally fight-scoped — no cleanup
  system needed, no permanent-curse plumbing (deliberately skipped: hallway theft stays
  "with a receipt"; permanence is boss/event material if ever). Injection visual: the
  reshuffle mini-card-back flight already exists (`deck_reshuffled` → card-backs flying
  between piles) — reuse it to show a junk card flying INTO your discard pile. The
  unplayable-card refusal system (shake + reason, shipped 07-29) already handles "you can't play
  this / you must play Hex first" messaging.
- **Wave-1 junk designs (3 max — complexity threshold):**
  - **Sludge** — "Unplayable. Vanishes at end of turn." Pure hand-slot tax (STS Slimed). The
    gentle one; dose 1–2 per cast.
  - **Cinder** — "Unplayable. If in your hand at end of turn, take 2 damage." (STS Burn.)
    Ember Fiend's ammo.
  - **Hex** — "You cannot play other cards while a Hex is in your hand. Play it (does nothing)
    to get rid of it." The must-play-first tempo tax — Julien's exact request, and the most
    dice-odyssey-feeling of the three because it eats a *card play*, which is tempo, not damage.
- **Wave-2 (interactive junk, STS2-style):** **Lead Die** — "Unplayable. While in your hand,
  your rolls are −1." (hold-pain: dump it with discards or eat the roll tax); **Cursed Pact** —
  "While in your hand, you cannot roll Red." Both attack dice through the hand — the crossover
  only this game can do.
- **Injectors**: Bog Hag (Hex), Ember Fiend (Cinder), one big act-2 body (Sludge ×2). Cap: ~2
  junk per enemy turn, act 2 only at first.

### 4.5 Bosses

- **Leviathan (act 1): leave for launch.** Validated ("clutch-but-fair"), and boss churn before
  release is risk without need. Post-launch option, one beat only: at ≤50%, one-time telegraphed
  **"Abyssal Maw — next turn: 26"** (a scripted block exam, Slime-Boss-Slam style).
- **The Dicelord (act 2): phase 2 at ≤50% — "Now I roll."** One-way, intent-interrupting
  (player-caused, per the STS rule). Phase 2:
  - **Drops Ink entirely** (thematic inversion: he stops hiding information and starts showing
    you dice — also mercy on cognitive load, per the complexity threshold).
  - **Roll the Bones**: at intent-declaration he visibly rolls 2 dice; attack = 8 + sum
    (10–20, exact number shown — telegraphed variance, rule 3.3-1). The finale's signature
    image: the Dicelord playing your game back at you.
  - **Grand Theft** every 3rd turn upgraded: steals 1 die from TWO different owned types
    (one-turn, existing plumbing ×2).
  - Block/Muscle beat stays. **No debuff cleanse** on the transition (tax, don't delete — the
    Champ's Anger wipe is exactly what the community calls feel-bad).

### 4.6 Elites

- **Cinderlord (act-2 DP): the ritual timer.** Turn 1 opener: **"Cataclysm — 4 turns"**
  (countdown on the intent). Steady 11s continue beneath it. At zero: **28 damage** — at the
  35–45% spike ceiling, NOT lethal (softer than STS2's Sandpit death clocks; you're meant to
  survive one and be unable to afford two — the second countdown starts immediately). Killing
  him before the second Cataclysm is the fight. **Drop Canalize in act 2** for this identity:
  a bank tax that punishes big turns directly fights a timer that demands them — that's not
  tension, that's a contradiction (and DP keeps Canalize in act 1 anyway).
- **Necromancer (act-2 Lich): the summoner.** Keeps Absorb (with its tooltip finally written).
  Opens by **raising 2 Bonelings** (small skeleton adds, reusing act-2 skeleton art, ~10 HP,
  flat 3s). Every 3rd turn, if fewer than 2 stand, raises one more. Add-clearing = tempo control
  (his raise turns are his weakest). This is the one HEAVY plumbing item (mid-fight spawn +
  layout) — marquee use only, and it's worth it: a Necromancer who doesn't raise the dead is a
  reskin, this one is a fight.
- **Devourer (act-2 Gargantua)**: Greedy carries (volume tax is still unique). Optional receipt
  mechanic later: "Devour — eats the top card of your draw pile until killed."
- **Counterplay teaching (all elites, cheap)**: the audit noted spend-small (DP) / end-low
  (Lich) are taught only by tooltips — and Absorb's tooltip doesn't exist (§2.4). Fix the
  tooltip; consider one hint line in the elite's intro banner (the tier-4 banner plumbing from
  07-31 could take a subtitle) — "The Lich drinks your last roll."

---

## 5. Balance framework for mechanic-carrying enemies

1. **The D/P model stays authoritative.** Fun zone 0.4–0.7 D/P, spike ceiling 35–45% of current
   HP, fight-length targets T0 3–4 / T1 3–5 / T2 4–6 / elites 5–7 / boss 6–9. Mechanics slot
   into the "taxes" bucket, which the July model already prices as the drag-free difficulty
   lever.
2. **Virtual-EHP pricing** (§3.3 rule 3): a mechanic's cost to the player is bought back from the
   body's stats. Harlequin at 18–22 HP with a hostage die ≈ a 35-EHP body without one. The
   Cinderlord trades ~10 EHP vs DP for the ritual's pressure. Publish the price next to each
   mechanic in the implementation notes so future tuning has the dial.
3. **Deadline math for timers**: required-DPS = EHP ÷ deadline-turns, checked against the P
   bands. Cinderlord at ~80 EHP (act-2 elite ~140 after ×1.75) vs act-2 P ≈ 25–35 damage-side:
   first Cataclysm (turn 4) is unavoidable by design; killing before turn 8 (second Cataclysm)
   needs ~18 DPT — comfortably in band, tight for bad drafts. That's the intended shape: eat
   one, never two.
4. **Telegraphed variance** (rule 3.3-1) for anything enemy-rolled — the roll happens at intent
   time; block math is always exact.
5. **Anti-bloat guardrail**: no damage caps, no revive chains, no "extra HP bars" in hallways —
   the STS2 length complaint is the cautionary tale. Timers/thresholds/theft all *compress*
   fights or leave length unchanged.
6. **Tax, don't delete**: hostage/seal rails (≥2 types owned, 1 concurrent hostage), junk dosing
   caps, no debuff-cleanse phase transitions, Red Sensitive is a carrot not a stick.
7. **Watch-list items this plan touches**: Trebuchet×Pixie Volley and throw decks gain a natural
   predator in Thornheart's Bristle (intended — the pincer); Fumigation vs the Necromancer's
   adds is a swarm-payoff moment (fine); Greedy vs throw decks already counts thrown dice
   (deliberate counterplay, unchanged).

---

## 6. Rollout plan (phased, cost-tagged — nothing started)

**Phase 0 — honesty & wiring (pre-release worthy, hours):**
Absorb tooltip written; Flux tooltip aligned to code; explicit `is_performable` on the four
fallback-driven kits (prerequisite for all pattern work); Goblin/Chimera comment/decoy cleanup.

**Phase 1 — act-1 texture (days, pre- or post-launch):**
Desync twin packs; repeat caps on small critters; Hound ≤50% Molten Frenzy; (optional) Medusa
cadence beat.

**Phase 2 — act-1 archetype fights (a few days each, additive):**
Goblin Cutpurse (gold thief + escape resolution); Satyr Shaman comp (support/kill-order).

**Phase 3 — act-2 identity wave 1 (the Steam-phase "real movesets" core):**
Ravager Overcommit (S); Warden protector block (S); Thornheart Bristle (S); Harlequin die
hostage (M); Cinderlord ritual (M). All via act-gated action nodes; one identity per session,
playtest between waves.

**Phase 4 — act-2 identity wave 2:**
Onlooker Mirror Gaze (M); Tempest Gale (M); Deepling Blind Roll (M); Gorgon Petrify + Red
Sensitive (M); Dicelord Phase 2 + Roll the Bones (M-H).

**Phase 5 — the junk system + its injectors:**
Junk plumbing + Sludge/Cinder/Hex; Bog Hag + Ember Fiend as carriers; wave-2 junk (Lead Die,
Cursed Pact) after playtest.

**Phase 6 — the marquee heavy:**
Necromancer summons (mid-fight spawn plumbing). Plus, someday: repetition-cap tightening as the
ascension/hard-mode dial (the A17 trick — zero new content).

**Art asks to batch for Julien** (one generation session): intent icons for steal / countdown /
summon / enemy-die / curse-card / "?"; card art for 3–5 junk cards; (already have: all 17 act-2
enemy bodies).

---

## 7. Open questions for Julien

1. **Flux**: keep the coded behavior (one roll per Power-reset — harsher, playtested) and fix
   the tooltip, or re-implement the tooltip's gentler "no same type twice in a row"?
2. **Act-1 spice level**: are the two additive fights (Cutpurse, Shaman) + Hound threshold the
   right amount, or should act 1 stay 100% untouched until after the itch feedback wave?
3. **Junk system go/no-go** — it's the one new SYSTEM here (everything else is action nodes and
   statuses). If yes: are Hex's "must play first" semantics right, or too annoying at 5-card
   hand size?
4. **Harlequin**: replace Flux with the die hostage in act 2 (my recommendation), or stack both?
5. **Enemy dice visuals**: Roll the Bones needs the enemy to visibly roll (a small die anim near
   the intent). Worth the animation work for the Dicelord alone, or should a hallway enemy get
   it too so the device isn't boss-only?
6. **Necromancer summons**: appetite for the spawn plumbing (the one heavy item), or park it and
   ship wave 1-2 first?
7. **Cinderlord**: OK dropping Canalize on the act-2 identity so the timer works (DP keeps it in
   act 1)?
8. **Cutpurse escape**: gold returned in full on kill + normal reward (generous) or STS2-style
   50% refund if it escapes (harsher)?

---

## 8. SCOPED PLAN (2026-08-08, post-review) — pattern & numbers pass on existing enemies + a few curse cards

Julien's verdict: polishing/marketing focus — no new enemies, no new systems beyond a small
curse-card family. Goal in his words: escape "attack, block & gain strength, same attack" and get
"this is a big attack / this is a smaller attack but it applies Weak / this is a block before its
big attack". This section is that plan, self-contained. Everything uses plumbing that already
exists in the codebase (weighted nodes + repeat caps, CONDITIONAL chains, cadence checks like
Crab's `% 4`, own-HP conditions like the unwired `crab_mega_block_action`, StatusEffect riders,
multi-execute double hits, block+Muscle actions). NOT IMPLEMENTED YET.

### 8.1 The beat vocabulary (the anti-monotony formula)

Five beat types, all already proven somewhere in the roster. A textured enemy = 2–3 *visibly
different* beats arranged in a readable order; monotony = one beat repeated.

- **FLOOR** — the small steady hit (Skeleton's 6).
- **RIDER** — smaller hit + a debuff (Goblin's 5+Unlucky, Satyr's 2+Weak).
- **SPIKE** — the big telegraphed hit, blockworthy (Skeleton's 12, Medusa's 15).
- **GUARD** — block ± Muscle, ideally right BEFORE the spike ("he winds up behind his shield").
- **EVENT** — a one-time beat on a condition (Hound's Exposed; new: HP-threshold roars).

Skeleton (weighted + cap + cadence spike) and Temple Defender (big → double → guard) are already
model citizens — the pass below brings the flat-liners up to their standard, at DPT parity.

### 8.2 Per-enemy pattern table (current → proposed, exact numbers)

**Shared-AI warning**: AI scenes are shared across tiers (and act 2 inherits everything), so a
pattern edit touches every tier that enemy appears in — per-enemy tier lists below. Tier-0-only
concerns are flagged.

**Tier 0 — essentially untouched (validated teaching tier):**

| Enemy | Today | Proposed | Notes |
|---|---|---|---|
| S. Satyr / S. Kraken | 50/50 two moves, no caps | add "debuff not twice in a row" cap | zero number change, pure texture |
| B. Satyr | opener + 67/33 + cap | **leave** | already textured |
| B. Kraken | T0 4+Ink2 → strict 7 / 4+Ink loop | **OPTIONAL, verdict needed**: opener becomes 50/50 (ink-first or 7-first) → twin pairs desync naturally, ink coverage spreads | ⚠️ propagates to T0: pair can open 7+7=14 unblocked (swarm-burst level, exists elsewhere, but changes a validated fight) |
| Skeleton, Marauder, Venom Bloom (T0 solo) | — | **leave** (see Plant note below) | Skeleton = the model; Marauder = the Cultist ramp, the growing number IS the drama |

**Tier 1 — the main texture work:**

| Enemy (tiers) | Today | Proposed | DPT check |
|---|---|---|---|
| **Goblin** (T1) | 7 → 7 → 5+Unlucky1 | 7 → **9** ("winds up after the jab") → 5+Unlucky1 | 6.3 → 7.0 — restores the tier's spike beat, exactly the pre-scoped dial from the 07-28 audit ("that beat to a single 8-9") |
| **Oculus** (T1) | 7 → +2 Str → 7 → … | 7 (FLOOR) → +2 Str **& block 4** (GUARD — "flexes behind cover") → **8** (SPIKE) | 4.7+ramp → 5.0+ramp ≈ parity; the guard telegraphs the big swing — Julien's "block before its big attack", literally |
| **Sigil Slug** (T1) | 10 → 10 → block 5+M2 | **12** (Sigil Slam, SPIKE) → **7** (FLOOR) → block 5+M2 (GUARD) | 6.7 → 6.3 ≈ parity. Prerequisite: wiring fix (§8.4) — its loop currently re-enters via `get_child(0)` |
| **Venom Bloom** (T0 solo 32, T1 pairs 28, T2 38) | 4 → +3 Str → 4 | **3 + Weak 1** (venom spit, RIDER) → +3 Str → **7** (lash, SPIKE) | 2.7+ramp → 3.3+ramp + Weak tax. ⚠️ **touches the validated T0 solo** — verdict needed. Weak is already taught in T0 (B.Satyr), and small/buff/BIG reads far better than 4/buff/4. No-Weak variant: 3 → buff → 7 |
| Lurker, B. Satyr, Defender, Marauder | — | **leave** | Lurker's flatness is the point (Flux carries it); Defender is the model cycle |

**Tier 2:**

| Enemy | Today | Proposed | Notes |
|---|---|---|---|
| **Lava Hound** (T2 only) | T0 2×6; then 33% 11 / 33% Exposed3 (once) / 33% 2×6 | + one EVENT: at **≤50% HP, one-time "Molten Roar" — +2 Str & block 5** (intent-visible), then his normal beats hit harder | the game's first HP-threshold event; own-HP condition = existing pattern (unwired crab_mega_block reads own HP). Texture-first alternative to the pre-scoped "double 6→7" dial |
| Medusa | weighted 3-beat + caps | **leave** (she's the tier's Jaw Worm) | optional later: every-4th-turn forced Stone Stare for a readable pulse |
| Maelstrom (Vortex) | Chaos opener → 12 / block 5+M3 alternation | **leave** | beats already differentiated; 12→13 stays the pre-scoped safety dial |

**Elites — the actual worst offenders (auras stay 100% untouched; only the flat turn-to-turn
gets beats). All three need the §8.4 wiring fix first:**

| Elite | Today | Proposed | DPT check |
|---|---|---|---|
| **Lich** 85 (Absorb) | 8 flat forever | **8** (FLOOR) → **10** (SPIKE) → **5 + Weak 2** (soul-sap RIDER) | 8.0 → 7.7 + Weak tax ≈ parity. Absorb untouched — and finally gets its tooltip (§8.4) |
| **Dragonpriest** 90 (Canalize) | 11 flat forever | **12** (FLOOR) → **8 & block 6** (GUARDED STRIKE — channels behind the shield) → **15** (SPIKE) | 11.0 → 11.7 ≈ parity; DP stays the hardest elite, now with a blockworthy rhythm instead of a flat tax. Canalize untouched |
| **Gargantua** 95 (Greedy) | scripted 8 / 8 / Exposed3, then 8 flat | keep the opener script; the loop becomes **8** (FLOOR) → **2×4** (Devouring Flurry — multi-hit) → **11** (SPIKE) | 8.0 → 9.0 — mild deliberate buff (he's the lowest-pressure elite at ~55-70/5t); the multi-hit beat plays with his own Exposed window |

**Boss (Leviathan 140):** leave — weighted 3-beat with caps, validated. Optional pulse for
later: every 4th turn force the block+M4 beat (Champ's-Taunt trick, makes the fight scannable).

### 8.3 The curse/status cards — minimal version

Two junk cards, carried by existing act-2 identities via act-gated beats (the Dice Theft
`current_act >= 2` pattern) — act 1 stays clean, act 2 gets visible identity for cheap (which
also serves the itch "act 2 is a preview" framing):

- **Hex** — "Unplayable… almost: you cannot play other cards while a Hex is in your hand. Play
  it (it does nothing) to discard it." Carrier: **Bog Hag** (act-2 Goblin) — in act 2 her
  Unlucky beat becomes 5 dmg + inject 1 Hex into the discard pile. The must-play-first tempo tax.
- **Cinder** — "Unplayable. If in your hand at end of turn, take 2 damage." Carrier: **Ember
  Fiend** (act-2 Hound) — his double-hit beat also injects 1 Cinder.
- *(optional 3rd)* **Sludge** — "Unplayable. Vanishes at end of turn." Carrier: **Deepling**
  (act-2 B.Kraken) ink beat. Only if the first two feel good.

Implementation notes (why this is small): fight piles rebuild from the deck each battle →
injection is fight-scoped with zero cleanup code; the 07-29 card-refusal system (shake + reason)
already handles "you can't play this / play the Hex first" messaging; the `deck_reshuffled`
mini-card-back flight can visualize the injection. Needs: 2-3 card .tres + tiny scripts, one
end-of-turn hand hook (Cinder/Sludge), the Hex gate in the click path, 2 act-gated action edits,
and 2-3 card arts from Julien. Order: Sludge (simplest) → Cinder → Hex.

### 8.4 Prerequisites & order

1. **Wiring/honesty pass first (hours)**: explicit `is_performable` on Lich / Gargantua / Sigil
   Slug steady attacks (their loops currently run on the `get_child(0)` anti-freeze fallback —
   pattern edits are unsafe until then); **write the missing Absorb tooltip**; **fix the Flux
   tooltip** to match code ("prevents you from rolling again until you spend your Power").
2. **Tier-1 texture batch** (Goblin, Oculus, Sigil, ±Venom Bloom) → playtest.
3. **Elite texture batch** (Lich, DP, Gargantua) + Hound's Molten Roar → playtest.
4. **Curse cards** (act-2 carriers) → playtest act 2.
5. Tier-0 caps + the optional B.Kraken desync whenever convenient (verdict first).

Open verdicts needed from Julien before implementing: Venom Bloom's T0 propagation (take it or
skip Plant), B.Kraken 50/50 opener (T0 propagation), Gargantua's mild buff (intended?), Hex
semantics at 5-card hand size, and 2 vs 3 curse cards.

---

## 9. EXTENSION (2026-08-13) — "every fight is a clock", systematized (implicit timers via enemy scaling)

**STATUS: ANALYSIS ONLY — NOTHING IMPLEMENTED, NO VERDICTS YET.** Julien's follow-up ask:
*"pretty much every fight should have an implicit timer (enemy scaling)."* This section
systematizes §1.2 across the roster. It EXTENDS §8, same scope philosophy — existing enemies,
existing plumbing, numbers not systems — and the ramp column below is designed against §8's
*proposed* kits, so each enemy gets ONE edit pass covering both.

### 9.1 Why now — three facts that sharpened this

1. **Golem carryover shipped uncapped (08-12).** Unspent Golem dice now carry to the next turn,
   and the stall was validated as fun ("changes how you plan & play your turn"). But with no
   timers anywhere, "turtle behind Block, stockpile Golem, unload once" is unpriced — the
   optimal line risks becoming the degenerate one. **The implicit timer is the price of a
   stockpile turn**, and it's the alternative to capping carryover: prefer pricing time
   (dramatic, a decision every turn) over capping the pool (feels bad, kills the fantasy).
   Corollary: if this pass ships, do NOT also cap carryover later — that's a double nerf.
2. **Disciplined play disarms the elite clocks.** Canalize / Absorb / Parasite are *greed*
   clocks: their counterplay (spend small / end on a low face / spread generation) produces a
   **stable-state fight** — DP hits 11 flat forever while you politely spend in packets; the
   Lich hits 8 flat forever while you politely end low. Mastering the counterplay currently
   *stops the clock* instead of slowing it — the exact stable-state §1.2 forbids, and it gets
   worse with mastery (the better you play, the flatter the fight). Note §8's proposed elite
   cycles are DPT-parity and clockless too — §9 is their missing half.
3. **§2.1's census line "ramps everywhere — good" was too generous.** The file-level re-audit
   (9.2, code-verified 2026-08-13) shows promised time ramps on only ~6 kits; several apparent
   ramps are dead code or dodgeable taxes.

### 9.2 The real clock census (code-verified)

Four different qualities of "clock" exist today — only the first one satisfies the principle:

- **Promised time ramps (6 kits)**: Marauder (True Strength engine — the Cultist model),
  Defender (+1 Str/cycle), Oculus (+2 Str/cycle), Venom Bloom (+3 Str/cycle), Sigil Slug
  (+2 Muscle in its guard beat), Maelstrom (+3 Muscle in its alternation).
- **RNG ramps (3 kits)** — rise in *expectation* only: Skeleton (block+Muscle 1, weighted,
  capped), Medusa (block+Muscle 3, weighted, capped), Leviathan (block+Muscle 4, weighted).
  Over a long stall these do close in — a legitimate gentle clock.
- **Greed clocks (5)** — scale with player behavior, not time, and are *dodgeable* (that's
  their design, fine — but they don't give the FIGHT a timer): Canalize, Absorb, Parasite,
  Flux (a lockout, not even a ramp). **Exception: Greedy is semi-unavoidable** (you must roll
  dice to play at all) ≈ the roster's one real timer today. ⚠️ The 08-13 dice-price pass
  raised rolls/turn (~+33% on floors 4-8) → Greedy silently *accelerated*; Gargantua is now
  the fastest clock in the game. Use him as the calibration ceiling, and if he overshoots in
  playtest the dial is his per-6-rolls rate, not this plan.
- **No clock at all**: Goblin, S.Satyr, B.Satyr, S./B. Kraken, Hound, Lurker, and the elite
  base kits — Lich & Gargantua's block+Muscle nodes exist in their AI scenes but are **dead
  code** behind the `get_child(0)` fallback (§2.4-3), so Lich = 8 flat forever, DP = 11 flat
  forever. **Lurker is the purest siege in the game**: Flux throttles YOUR dps while he never
  grows — long fight, zero escalation, nothing degrades. The stable-state poster child.

### 9.3 The toolkit — four tools, two rejected

1. **Muscle ramp rider** — an existing cycle beat gains "+N Muscle to self". The Defender
   model generalized. Badge = free legibility, and post-07-04 every intent already shows
   modified damage, so the ramp telegraphs itself one turn ahead at zero UI cost.
2. **Damage-step on repeat** — an action's damage grows per *use* (Book of Stabbing's 6×N):
   runtime counter on the action node (fresh per battle — no save concern, checkpoints are
   map-only). Silent but intent-honest. Best used on SPIKES: **ramp the spike, not the floor**
   — the floor stays stable learnable block math, pressure concentrates in the one beat you
   were already supposed to block. ⚠️ Implementation caution: the step must feed the same
   path the intent reads (the §2.4 Chimera `base_damage` snapshot footgun is exactly the trap
   here — no perform-time surprises).
3. **Cadence promotion** — force an existing weighted block+Muscle pick every Nth turn
   (Crab's `fight_turn % 4` plumbing, zero new numbers): converts an RNG clock into a promised
   one AND gives a weighted-soup kit a scannable pulse. For Medusa and Leviathan.
4. **Soft-enrage backstop** (the only new-ish piece, optional) — §9.5.

Rejected: **cadence acceleration** (spike every 4 turns, then 3, then 2 — changing the
pattern's *shape* mid-fight breaks the legibility §8 exists to build; grow the numbers, keep
the shape) and **debuff escalation** (Weak 1→2→3 or Unlucky ramps = misery spiral; ramp an
applier's damage instead — Goblin's Unlucky stays at 1 forever).

### 9.4 Per-enemy ramp column (builds on §8.2's proposed kits, not today's)

**Tier 0: untouched entirely.** Validated teaching tier, solos die by turn 4, Marauder/Venom
Bloom already ramp — and critter-pack stalls are *harmless by irrelevance*: no cross-fight
resource exists (Power, Muscle, Golem stock all reset per battle), so turtling a fight you've
already won pays nothing. Stalling only pays where a hard body must eventually be burst —
that's T1+ keys, elites, boss, which is where the column lands.

| Enemy | Clock after §8 | §9 addition | Check |
|---|---|---|---|
| **Goblin** (T1) | none | **+1 Muscle rider on the new 9 beat** ("winds up harder every round") | cycles: 7/9/5+U → 8/10/6 → 9/11/7; DPT 7.0 → 8.0 → 9.0; first visible step ~turn 5 = T1's par edge — deliberate, T1 is where tempo teaching starts. Alt: silent damage-step 9→11→13 (verdict 9.7-4) |
| **Lurker** (T1) | none (Flux carries) | **VERDICT NEEDED**: flat 6 becomes 6→7→8→9… (+1/turn damage-step) | overrides §8's "flatness is the point". Rationale: Flux caps the player's throughput, so this is the game's longest stable siege — +1/turn converts it into the race a Flux fight should be. Skip if playtest says double-taxed |
| Skeleton, Oculus, Sigil, Defender | RNG creep / promised ramps | **leave** | already satisfy the principle; Skeleton stays the untouched model |
| **Medusa** (T2) | RNG ramp | ✅ **IMPLEMENTED 2026-08-13** (see 9.8): guard promoted to `fight_turn % 4 == 3` | RNG clock → promised clock, weighted soup gets a pulse, zero new numbers |
| **Hound** (T2) | Molten Roar EVENT (§8) | **leave** — the Roar is his drama; backstop covers deep stalls | flag: an HP-threshold event is damage-triggered, not time-triggered — it never punishes stalling; he stays clockless without the backstop |
| Krakens, B.Satyr | none | **leave** (comp filler, small bodies; backstop) | — |
| **Lich** (elite) | clockless after §8 (8/10/5+W2, Absorb aside) | **+1 Muscle rider on the soul-sap beat** (5+Weak2 also stokes HIM — he drains you and keeps it; the flavor writes itself) | cycles: 8/10/5+W2 → 9/11/6 → 10/12/7; disciplined Absorb-dodging now *slows* the clock instead of stopping it. Absorb untouched |
| **Dragonpriest** (elite) | clockless after §8 (12 / 8+block6 / 15, Canalize aside) | **damage-step the 15 SPIKE per use: 15 → 18 → 21** ("the channeling builds") | spikes land ~turns 3/6/9; 21 = 32% of 66 HP, under the 35-45% ceiling, and only deep stalls see it. Floors stay 12 and 8+6 forever — stable math, growing exam |
| **Gargantua** (elite) | Greedy ≈ real timer | **leave** — the calibration ceiling; no authored ramp should out-pace Greedy | see 9.2 note on its silent acceleration |
| **Leviathan** (boss) | RNG ramp (weighted M4) | ✅ **IMPLEMENTED 2026-08-13** (see 9.8): guard promoted to `fight_turn % 4 == 2` — note the different phase, forced by the Dicelord theft collision | smallest possible boss touch (a cadence gate on an existing beat, not a kit change) — but it IS a boss touch pre-release, **still revertible in one line if Julien vetoes** |

**Why DP's spike-ramp doesn't repeat the §4.6 Canalize contradiction**: Cinderlord's argument
was that a hard *deadline* demands big turns while Canalize punishes big turns — contradiction.
A soft *ramp* demands **pace**, not bursts: with Canalize up, the pushed line is "spend small
but constantly" — more total spending, less hoarding. That's tension (the good kind), not
contradiction. The same logic clears the Lich: end-low discipline still works, it just no
longer freezes the fight.

### 9.5 The soft-enrage backstop (optional — the "no fight is stable-state" invariant)

One shared status + one turn hook, nothing per-enemy: **from turn T (per tier), every living
enemy gains +1 Muscle per turn, forever, uncapped.** Proposed T = fight-length target max + 2
(§5): **T0 turn 6 / T1 turn 7 / T2 turn 8 / elites turn 9 / boss turn 11.**

- **Invisible on-curve by construction** — §5 targets end fights 2+ turns before it starts.
  It exists so "turtle + stockpile" is *mathematically dead everywhere* (uncapped beats any
  block ceiling eventually), not to be seen in normal play. That also makes it shippable
  pre-release with near-zero balance risk.
- **Honesty rule (the §2.4 Absorb lesson)**: unlike authored ramps (self-telegraphing via
  intent), this is a hidden RULE — so it must surface as a visible status badge with a real
  tooltip written day one ("Gains 1 Strength every turn", name TBD by Julien — Frenzy /
  Restless / Dungeon's Wrath). Shared-vocabulary status like Weak, not a signature aura
  (standing rule respected). Optional courtesy: badge appears 1 turn before the first stack.
- **Multi-body note**: +1/turn/enemy quadruples the total ramp in 4-body fights — likely fine
  (bodies are dying by then), but the ACT2_DAMAGE_BASE per-fight-budget precedent is the
  fallback if playtests disagree. Accelerating variant (+1/+2/+3…) is the tuning lever if
  flat +1 outlasts anyone's patience.
- **It's optional**: without it, the authored column already covers every fight where stalling
  *pays* (T1 keys, elites, boss); the clockless leftovers (critter packs, Hound, Krakens) are
  stall-proof by irrelevance (9.4). Recommended anyway as the invariant + future-content
  insurance — it's the cheapest item in this whole doc (1 status .tres + 1 hook + tooltip).

### 9.6 Guardrails & interactions

- **One time-clock per fight.** Never Muscle-creep AND damage-step the same kit; fights that
  already carry a greed clock get the gentlest ramp (Lich/DP get one slow beat, Gargantua gets
  none, Lurker is a verdict).
- **Setup archetypes are protected by placement**: every authored ramp's first visible step
  lands turn 4+; Blessing/Scout/infusion setup is turns 1-2. The backstop only ever bites
  degenerate stalls, not setup.
- **Block archetype stays valid**: ramped damage is still exact, telegraphed, blockable —
  Block *buys* time, it just no longer *stops* time. That's the correct relationship.
- **New players**: slopes are +1-3 per cycle, never cliffs; the spike math they actually lose
  to is unchanged. A beginner deep past par eats a faster loss, not a grindier one —
  roguelike-correct mercy.
- **Anti-bloat (§1.9)**: ramps add zero turns and only shorten stalls; the two cadence
  promotions gate existing beats rather than adding defensive ones.
- **Honesty**: all ramps surface in intent numbers automatically (07-04 fix); Muscle ramps get
  the badge free; damage-steps are silent-but-honest (the intent number IS the display, the
  Book-of-Stabbing precedent); only the backstop needs new UI (its badge). No invisible
  MID-fight growth ever — the act-2 flat bake stays fine because it's fight-START state, not
  growth.

### 9.7 Order & verdicts

Rides §8's batches — one edit pass per enemy: the T1 texture batch adds Goblin's rider
(+ Lurker if approved); the elite batch adds Lich/DP ramps + the Medusa/Leviathan cadence
gates. The backstop is a standalone XS item, viable pre-release. The §8.4 wiring pass remains
the prerequisite for everything (Lich/Gargantua/Sigil edits are unsafe until `is_performable`
is explicit).

**Verdicts needed from Julien:**
1. **The elite principle** — ramps on TOP of the greed taxes, yes? (The philosophical one:
   "mastering the counterplay should slow the clock, not stop it.")
2. **Backstop go/no-go** (+ its name, + whether it telegraphs 1 turn early).
3. **Lurker creep** — override "flatness is the point", or keep the siege?
4. **Goblin**: Muscle rider (visible badge) vs silent damage-steps?
5. ~~Medusa / Leviathan cadence promotions~~ — **DONE 2026-08-13, see §9.8.** Still needs a
   playtest verdict on the boss touch specifically.
6. **Numbers sign-off** — every figure above is first-pass, priced against §5's D/P bands.

### 9.8 SHIPPED (2026-08-13) — the cadence promotions

**VERIFIED BY HARNESS (19 checks, 0 fail, incl. a negative control) — NOT PLAYTESTED.**
Harness: `debug_cadence_promotion.gd`/`.tscn` at repo root (not committed, auto-excluded from
the web export by the preset's `debug_*` filter). It boots the REAL AI scenes and drives
`EnemyActionPicker.get_action()` over fight_turn 0-23 × 80 trials.

**What changed (4 files):**

| File | Change |
|---|---|
| `enemies/medusa/medusa_block_action.gd` | `is_performable` → `Global.fight_turn % 4 == 3` |
| `enemies/medusa/medusa_enemy_ai.tscn` | BlockAction: `type`/`chance_weight` lines removed (→ CONDITIONAL); intent icon → `buff_block_intent.png` |
| `enemies/leviathan/2.gd` | `is_performable` → `Global.fight_turn % 4 == 2` |
| `enemies/leviathan/leviathan_enemy_ai.tscn` | block_buff: same removal + icon swap; **dice_theft moved ahead of block_buff in child order** |

**Promotion means REMOVAL from the chance pool, not addition on top of it.** The beat is now
CONDITIONAL only — leaving it weighted as well would roughly double its frequency and tank DPT.
Removing `chance_weight` matters too: a stale weight on a CONDITIONAL node is dead data, exactly
the decoy §2.4 flags on Temple Defender. Verified via `total_weight`: Medusa 15→11, Leviathan
14→10.

**Measured parity** (harness, damage-weighted over 24 turns, guard beats counting 0):

| | DPT before (analytic) | DPT after (measured) | Δ | Muscle/turn before → after |
|---|---|---|---|---|
| Medusa | ~10.76 | **10.23** | −4.9% | 0.63 (RNG) → **0.75 (guaranteed)** |
| Leviathan | ~12.83 | **12.35** | −3.7% | 0.89 (RNG) → **1.00 (guaranteed)** |

The "before" figures are steady-state with the old `never twice in a row` cap, which held the
real block rate at ~21-22% rather than the naive weight share (26.7% / 28.6%). So both enemies
land slightly softer early and reliably heavier late — the intended promoted-clock trade.

**⚠️ The two enemies use DIFFERENT phases, and that is deliberate.** Medusa matches the
Skeleton's playtested `% 4 == 3`. Leviathan uses `% 4 == 2` because its AI scene is shared with
the act-2 Dicelord, whose theft is CONDITIONAL on `% 3 == 1`. Two conditional cadences on
moduli 4 and 3 collide every 12 turns and the picker resolves collisions by **child order** —
one beat is silently dropped. `% 4 == 3` first collides on **turn 7**, inside the 6-9 turn boss
target; `% 4 == 2` pushes it to **turn 10**, outside it. Belt-and-braces: dice_theft is now
ordered before block_buff, so when a collision does land the boss's identity move always beats
his metronome (verified: act-2 theft fires on 1/4/7/10/13/16/19/22, guard on 2/6/14/18).
Anyone changing either modulus must redo this collision math.

**Also checked**: child 0 of the Leviathan picker is still `leviathan_ink_attack` — the picker's
last-resort `get_child(0)` anti-freeze return must never become the act-2-only theft node, or an
act-1 Leviathan could steal dice.

**Intent honesty fix, same pass**: both guard beats grant Muscle (3 / 4) but telegraphed with
the plain `block_icon_intent.png`, i.e. the ramp was invisible on the very beat that produces
it. Both now use `buff_block_intent.png`, which already existed with a wired tooltip and was
used by exactly one enemy (Temple Defender). Now that the ramp is promised rather than random,
its telegraph has to say so. The block number ("9" / "8") is unchanged.

### 9.9 Intent icon debt (raised by Julien 2026-08-13: "we'll need a new intent for attack+buff?")

Correct — and the gap is slightly wider than that. Current icon set: attack, block, buff,
**buff+block** (the only painted combo), debuff (×3 near-duplicate files: `debuff_intent`,
`debuff_icon`, `intent_debuff`). Combos beyond buff+block do not exist.

The existing convention for uncovered combos is *pick the more notable icon and let the number
mean damage* — Medusa's attack+Weak shows the debuff icon with "12". It ships and it playtests,
but it's ambiguous, and §8/§9's beats lean on combos much harder:

| Needed by | Combo | Status |
|---|---|---|
| §9.4 Goblin rider (9 + 1 Muscle), §9.4 Lich rider (5 + Weak 2 + 1 Muscle) | **attack + buff** | **missing — Julien's catch** |
| §8.2 Dragonpriest GUARDED STRIKE (8 & block 6) | **attack + block** | **missing** |
| §8.2 Oculus GUARD (+2 Str & block 4) | buff + block | covered |
| Dicelord Dice Theft | steal | placeholder (`debuff_intent`), pre-existing debt |
| §4.6 Cinderlord ritual / §4.5 Roll the Bones / §4.6 summons / junk cards | countdown, enemy-die, summon, curse-card, "?" | post-launch (already listed in §3.3 rule 7) |

**Two ways to solve it, and the choice matters more than the art:**

- **(a) Paint the combos** — follows the `buff_block_intent` precedent, ~2 new icons for the
  scoped plan. Cheapest now, but combos grow combinatorially: attack+buff+debuff (the Lich
  rider is literally that) has no icon and would need a third.
- **(b) Composite intent — a second icon slot.** `IntentUI` is already an `HBoxContainer` of
  `IconSlot` + `LabelSlot`; adding an optional second `IconSlot` lets ANY pair be expressed
  from the existing single-purpose icons, with no new art ever. More code (an `Intent` gains a
  secondary icon; `_sync_label_slot`'s hand-maintained width logic gains a sibling), and it
  makes the telegraph visually wider/busier, which matters because the intent already bobs
  above every enemy's head. **Recommendation: (a) for the scoped §8/§9 batch** (2 icons, zero
  risk, matches the shipped precedent), and keep (b) in the pocket for the post-launch act-2
  wave, where the combo count actually explodes.

**⚠️ Whichever way: `intent_ui.gd::_get_tooltip_text_for_icon()` matches on the icon's FILE
BASENAME.** A new icon with no matching `match` case silently falls through to the generic
"This enemy is preparing something." — the same class of bug as Absorb's missing tooltip
(§2.4-1). Add the case in the same commit as the art.

---

## Appendix — proposal quick-reference (FULL menu — §8 is the scoped subset)

| Proposal | Act/Tier | New plumbing | Cost | Phase |
|---|---|---|---|---|
| Absorb tooltip / Flux tooltip / is_performable pass | — | none | XS | 0 |
| Twin-pack desync + repeat caps | A1 T0-2 | none | XS | 1 |
| Hound Molten Frenzy (≤50%) | A1 T2 | none (conditional node) | S | 1 |
| Medusa cadence beat (optional) | A1 T2 | none | S | 1 |
| Goblin Cutpurse (gold thief + flee) | A1 T2 | escape resolution | M | 2 |
| Satyr Shaman comp (support role) | A1 T2 | ally-target buff | S | 2 |
| Ravager Overcommit (full-block stun) | A2 | block-check hook | S | 3 |
| Warden protector block | A2 | ally-target block | S | 3 |
| Thornheart Bristle (anti-multi-hit) | A2 | per-hit counter | S | 3 |
| Harlequin die hostage | A2 | persistent theft + restore | M | 3 |
| Cinderlord ritual timer | A2 elite | countdown intent | M | 3 |
| Onlooker Mirror Gaze (bank mirror) | A2 | live intent refresh | M | 4 |
| Tempest Gale (forced first type) | A2 | slot gating (tutorial-style) | M | 4 |
| Deepling Blind Roll | A2 | hidden-roll UI | M | 4 |
| Gorgon Petrify + Red Sensitive | A2 | in-hand lock + dmg modifier | M | 4 |
| Dicelord Phase 2 + Roll the Bones | A2 boss | threshold + enemy-die anim | M-H | 4 |
| Junk system (Sludge/Cinder/Hex) + Hag/Fiend | A2 | injection + junk flags | M-H | 5 |
| Lead Die / Cursed Pact (junk wave 2) | A2 | in-hand passives | M | 5 |
| Necromancer summons | A2 elite | mid-fight spawn | H | 6 |
| Repetition-cap "ascension" dial | future | none | S | later |
| §9 ramp column (Goblin/Lich/DP + Medusa/Leviathan cadence, ±Lurker) | A1-A2 | none (riders, use-counters, cadence gates) | S | rides §8's batches |
| §9 soft-enrage backstop status | all fights | 1 status + 1 turn hook | XS | standalone, pre-release viable |
