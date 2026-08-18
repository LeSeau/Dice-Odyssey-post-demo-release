# STS2 (Early Access) — Extracted Balance Dataset

Source: decompiled C# at `C:\Users\julie\Desktop\sts2_ref\pck\src\Core` (MegaCrit.Sts2). Extracted 2026-08-16.
**All numbers are A0 baselines.** Ascension encoding: `AscensionHelper.GetValueIfAscension(level, ascendedValue, baseValue)` — 3rd arg = A0. HP boosts live on `AscensionLevel.ToughEnemies` (asc 8), damage boosts on `AscensionLevel.DeadlyEnemies` (asc 9). Ascension levels enum: 1 SwarmingElites, 2 WearyTraveler, 3 Poverty (gold ×0.75), 4 TightBelt, 5 AscendersBane, 6 Inflation, 7 Scarcity, 8 ToughEnemies, 9 DeadlyEnemies, 10 DoubleBoss.

## 0. Act structure

| Act | Class | Index | Rooms (excl. boss) | Weak fights | Notes |
|---|---|---|---|---|---|
| Act 1 A | `Overgrowth` (default) | 0 | 15 | first **3** | jungle variant |
| Act 1 B | `Underdocks` (unlock) | 0 | 15 | first **3** | docks variant |
| Act 2 | `Hive` | 1 | 14 | first 2 | |
| Act 3 | `Glory` | 2 | 13 | first 2 | |

Gating mechanism (`ActModel.cs` ~line 349): the first `NumberOfWeakEncounters` monster rooms draw from the **Weak pool** (encounters with `IsWeak => true`), all later monster rooms draw from the **Regular pool**. Both use a grab-bag (each encounter once before refill) with `AddWithoutRepeatingTags` (encounter tags, e.g. `Nibbit`, prevent same-family back-to-back). Elites are a separate grab-bag. 3 bosses per act, discovery-ordered; one per run.

Rest sites per act-1 map: `NextGaussianInt(7,1,6,7)` → 6–7. Move selection framework: `MoveState.FollowUpState` = deterministic script; `RandomBranchState` = weighted random with `CannotRepeat` (never 2× in a row), `CanRepeatXTimes(n)` (max n in a row), `UseOnlyOnce`, and per-move `cooldown k` (can't reappear within last k moves).

---

## 1. ACT 1 — OVERGROWTH monsters (A0)

### Weak pool (floors 1–3)
| Encounter | Composition | Total HP |
|---|---|---|
| FuzzyWurmCrawlerWeak | 1× Fuzzy Wurm Crawler | 55–57 |
| NibbitsWeak | 1× Nibbit (alone mode) | 42–46 |
| ShrinkerBeetleWeak | 1× Shrinker Beetle | 38–40 |
| SlimesWeak | 1 medium slime (Twig M or Leaf M) + 2 small (Twig S + Leaf S, random order) | ~44–54 |

### Regular pool (floors 4+)
| Encounter | Composition | Total HP |
|---|---|---|
| CubexConstructNormal | 1× Cubex Construct | 65 (+13 block, Artifact 1) |
| FlyconidNormal | 1× Flyconid | 47–49 |
| FogmogNormal | 1× Fogmog (+ summons Eye with Teeth 6) | 74 (+6) |
| InkletsNormal | 3× Inklet | 33–51 |
| MawlerNormal | 1× Mawler | 72 |
| NibbitsNormal | 2× Nibbit (front/back roles) | 84–92 |
| OvergrowthCrawlers | Shrinker Beetle + Fuzzy Wurm Crawler | 93–97 |
| RubyRaidersNormal | 3 distinct raiders from 5 types (each capped at 1) | ~56–81 |
| SlimesNormal | Twig M + Leaf M + Twig S + Leaf S | 76–89 |
| SlitheringStranglerNormal | Slithering Strangler + Snapping Jaxfruit | 84–88 |
| SnappingJaxfruitNormal | Flyconid + Snapping Jaxfruit | 78–82 |
| VineShamblerNormal | 1× Vine Shambler | 61 |

### Monster specs — Overgrowth trash

**Fuzzy Wurm Crawler** — HP 55–57. Acid Goop **4**; Inhale: **+7 Str** (self). Script: Goop → Inhale → Goop → Goop → Inhale → Goop … (cycle [Inhale, Goop, Goop] after opener). Effective hits: 4, 11, 11, 18, 18… **Ramp: +7 Str / 3-turn cycle.**

**Nibbit** — HP 42–46. Butt **12**; Hesitant Slice **6 + 5 Block**; Hiss **+2 Str**. Fixed cycle Butt → Slice → Hiss → repeat. Solo starts Butt; pair: front starts Slice, back starts Hiss (desynced). **Ramp: +2 Str / 3 turns.**

**Shrinker Beetle** — HP 38–40. T1 Shrink: player attacks deal **−30%** damage while Beetle alive (applied with infinite duration; the power also exists in a 3-turn form). Then Chomp **7** ↔ Stomp **13** alternating forever. No ramp. (Bestiary hides Stomp.)

**Twig Slime (M)** — HP 26–28. Pokey Pounce **11**; Sticky Shot: **+1 Slimed → discard**. Start Sticky; then random 50/50 {Pounce (max 2 in a row) | Sticky (not 2× in a row)}. No ramp; **junk injector**.

**Leaf Slime (M)** — HP 32–35. Clump Shot **8**; Sticky Shot: **+2 Slimed → discard**. Starts Sticky, strict alternation Sticky/Clump. **Junk injector.**

**Twig Slime (S)** — HP 7–11. Tackle **4** every turn.

**Leaf Slime (S)** — HP 11–15. Tackle **3**; Goop: **+1 Slimed → discard**. Random, no repeats → alternation. **Junk injector.**

**Inklet** (×3) — HP 11–17 each. Innate **Slippery 1** (next time it loses HP, loses only 1 — anti-poke). Jab **3**; Whirlwind **2×3**; Piercing Gaze **10**. Pattern: Jab → rand{Gaze | Whirlwind} (both no-repeat) → Jab → … Middle Inklet opens Whirlwind, outer two open Jab. No ramp.

**Cubex Construct** — HP 65, starts with **13 Block + Artifact 1**. T1 Charge Up **+2 Str**; then loop Repeater Blast (**7**, then **+2 Str**) → Repeater Blast → Expel (**5×2**) → repeat. **Ramp: +2 Str on each Blast ≈ +4 Str / 3-turn cycle.**

**Flyconid** — HP 47–49. Vulnerable Spores: **Vulnerable 2** (cooldown 3); Frail Spores: **8 + Frail 2** (cooldown 2); Smash **11**. All weight 1, none twice in a row. Opens with Frail Spores or Smash. No ramp.

**Fogmog** — HP 74. T1 Illusory Spores: **summons Eye with Teeth**. Thwack (Swipe) **8 + gains +1 Str**; Headbutt **14**. Pattern: Swipe → rand{40% Swipe(again) → Headbutt | 60% Headbutt} → Swipe … **Ramp: +1 Str per Swipe (~every 2 turns).**
- **Eye with Teeth** — HP 6, innate **Illusion** (when killed, revives next turn at full HP — can't be permanently removed). Every turn: Distract = **+3 Dazed → discard**. **Junk fountain; the real fight clock.**

**Mawler** — HP 72. Rip and Tear **14**; Roar: **Vulnerable 3** (UseOnlyOnce); Claw **4×2**. Equal weights, no move twice in a row, opens Claw. No ramp.

**Ruby Raiders** (pick 3 distinct of 5):
| Raider | HP | Moves |
|---|---|---|
| Axe Raider | 20–22 | Swing **5 + 5 Block** ×2 turns → Big Swing **12** → repeat |
| Assassin Raider | 18–23 | Killshot **10** every turn |
| Brute Raider | 30–33 | Beat **7** ↔ Roar **+3 Str** (ramp +3/2 turns) |
| Crossbow Raider | 18–21 | opens Reload (**3 Block**) ↔ Fire! **14** |
| Tracker Raider | 21–25 | opens Track (**Frail 2**), then Hounds **1×8** every turn |

**Slithering Strangler** — HP 53–55. Opens Constrict: **Constrict 3** (take 3 dmg at end of your turn while it lives), re-cast every other turn (re-applies/stacks the counter). Between Constricts: rand 50/50 {Thwack **7 + 5 Block** | Lash **12**}. **Soft ramp via repeated Constrict.**

**Snapping Jaxfruit** — HP 31–33. Single move every turn: Energy Orb **3 dmg + gains +2 Str**. Damage: 3, 5, 7, 9… **Pure per-turn ramp (+2 Str/turn).**

**Vine Shambler** — HP 61. Fixed cycle: Swipe **6×2** → Grasping Vines **8 + Tangled 1** (your Attacks cost +1 Energy this/next turn) → Chomp **16** → repeat. No ramp.

### Overgrowth elites

**Bygone Effigy** — HP **127**. Innate **Slow 1** on itself (takes +10% more attack damage per card you play each turn — STS1 TimeEater-ish reward for long combos). Script: T1 Sleep (nothing) → T2 Wake **+10 Str** → T3+ Slashes **13** (+Str → 23) every turn. **Ramp: one-shot +10 Str at T2. Race clock: kill/burst in 2 free-ish turns or eat 23/turn.**

**Byrdonis** — HP 81–84 (+ Byrdpip, 9999 HP untargetable prop with no HP bar). Innate **Territorial 1: gains +1 Str at end of EVERY one of its turns** (permanent per-turn ramp). Swoop **17** ↔ Peck **3×3** alternating, opens Swoop. **Ramp: +1 Str/turn.**

**Phrog Parasite** — HP 61–64. Innate **Infested 4**: on death **summons 4 Wrigglers**. Infect: **+3 Infection → discard** ↔ Lash **4×4** alternating, opens Infect.
- **Wriggler** — HP 17–21. Bite **6** ↔ Wriggle (**+1 Infection → discard, +2 Str self**) alternating. **Junk injectors both phases; killing the elite spawns 68–84 more HP of adds.**

### Overgrowth bosses

**Vantom** — HP **173**. Innate **Slippery 8** (the next 8 times it loses HP, it loses only 1 instead — hard anti-multi-hit/poke shield; ~8 wasted hits). Fixed 4-turn loop: Ink Blot **7** → Inky Lance **6×2** → Dismember **26 + 3 Wound → discard** → Prepare **+2 Str** → repeat. **Ramp: +2 Str/4-turn cycle. Junk: 3 Wound per cycle.**

**Ceremonial Beast** — HP **252**. Phase 1: T1 Stamp: applies **Plow 150** to itself ("first time its HP reaches 150 or below → Stunned + loses ALL Strength"); T2+ Plow charge **18 + gains +2 Str** EVERY turn (ramping 18, 20, 22…). Phase 2 (when you push it to ≤150 HP): Stunned (free turn) → then loop Beast Cry (**Ringing 1**: you can play only 1 card next turn!) → Stomp **15** → Crush **17 + gains +3 Str** → Beast Cry → … **Ramp in both phases (+2 Str/turn P1, +3 Str/3 turns P2). Phase trigger is player-controlled damage race.**

**The Kin** — Kin Priest **190** + 2× Kin Follower **58–59** (**Minion**: flee if leader dies). Total ≈ **306–308**.
- Priest fixed loop: Orb of Frailty **8 + Frail 1** → Orb of Weakness **8 + Weak 1** → Beam **3×3** → Ritual **+2 Str** → repeat. (+2 Str/4 turns)
- Followers cycle: Quick Slash **5** → Boomerang **2×2** → Power Dance **+2 Str** → repeat; slot1 opens with Dance (desynced). (+2 Str/3 turns each)

---

## 2. ACT 1 — UNDERDOCKS monsters (A0)

### Weak pool
| Encounter | Composition | Total HP |
|---|---|---|
| CorpseSlugsWeak | 2× Corpse Slug (cycle positions staggered) | 50–54 |
| SeapunkWeak | 1× Seapunk | 44–46 |
| SludgeSpinnerWeak | 1× Sludge Spinner | 37–39 |
| ToadpolesWeak | 2× Toadpole (front/back) | 42–50 |

### Regular pool
| Encounter | Composition | Total HP |
|---|---|---|
| CorpseSlugsNormal | 3× Corpse Slug | 75–81 |
| CultistsNormal | Damp Cultist + Calcified Cultist | 89–94 |
| FossilStalkerNormal | 1× Fossil Stalker | 51–53 |
| GremlinMercNormal | 1× Gremlin Merc (splits on death: Fat 13–17 + Sneaky 10–14) | 47–49 (+23–31) |
| HauntedShipNormal | 1× Haunted Ship | 63 |
| LivingFogNormal | 1× Living Fog (+ Gas Bombs 7 each) | 80 (+7/2 turns) |
| PunchConstructNormal | 1× Punch Construct | 55 (Artifact 1) |
| SeapunkNormal | Seapunk + Calcified Cultist | 82–87 |
| SewerClamNormal | 1× Sewer Clam | 56 (Plating 8) |
| TwoTailedRatsNormal | 3× Two-Tailed Rat (can grow to 6) | 51–63 (+17–21/summon) |

### Monster specs — Underdocks trash

**Corpse Slug** — HP 25–27. Innate **Ravenous 4**: when another enemy dies, it eats the corpse — Stunned that turn, then **+4 Str** permanently (punishes kill order / rewards AoE finishes). Fixed cycle Whip Slap **3×2** → Glomp **8** → Goop (**Frail 2**) → repeat; multi-slug fights desync each slug's start (`EnsureCorpseSlugsStartWithDifferentMoves`).

**Seapunk** — HP 44–46. Cycle: Sea Kick **11** → Spinning Kick **2×4** → Bubble Burp (**7 Block, +1 Str**) → repeat. **Ramp +1 Str/3 turns.**

**Sludge Spinner** — HP 37–39. Random (equal, no repeats): Oil Spray **8 + Weak 1**; Slam **11**; Rage **6 + gains +3 Str**. Opens Oil Spray. **RNG ramp ≈ +1 Str/turn.**

**Toadpole** — HP 21–25. Cycle: Whirl **7** → Spiken (**+2 Thorns** self) → Spike Spit **3×3** (sheds the 2 Thorns) → repeat. Front opens Spiken, back opens Whirl. Thorns = 2 dmg back per hit while up.

**Damp Cultist** — HP 51–53. T1 Incantation: **Ritual 5** (+5 Str at end of each of its turns). Then Dark Strike **1** every turn: 1, 6, 11, 16, 21… **Ramp: +5 Str/turn — the act's hardest clock; low base, HP race.**

**Calcified Cultist** — HP 38–41. T1 Incantation: **Ritual 2**. Then Dark Strike **9**: 9, 11, 13… **Ramp +2 Str/turn.**

**Fossil Stalker** — HP 51–53. Innate **Suck 3: gains +3 Str every time it deals UNBLOCKED attack damage** (block-or-snowball pressure; per hit — Lash can trigger twice). Random (equal, each max 2 in a row): Tackle **9 + Frail 1**; Latch **12**; Lash **3×2**. Opens Latch. **Conditional ramp.**

**Gremlin Merc** — HP 47–49. Innate **Surprise** (hidden) + **Thievery 20: steals up to 20 gold on EVERY attack move**. Cycle: Gimme **7×2** → Double Smash **6×2 + Weak 2** → Hehe **8 + gains +2 Str** → repeat (steals each move). ON DEATH: splits into **Sneaky Gremlin** (10–14 HP, Tackle **9**/turn) + **Fat Gremlin** (13–17 HP, carries ALL stolen gold via Heist; its move script: spawn-turn idle → **FLEE** — escapes combat). Kill Fat Gremlin before it flees → gold returned as bonus reward; if it escapes with gold → encounter gold reward ×0 (×0.5 if it fled without stealing). **"Theft with receipt" model.**

**Haunted Ship** — HP 63. T1 Haunt: **Weak 3 + 5 Dazed → discard** (single huge junk dump). Then Swipe **13** ↔ Stomp **4×3** alternating forever. **Junk injector (front-loaded).**

**Living Fog** — HP 80. Opens Advanced Gas **8 + Smoggy 1** (you can play only **1 Skill** per turn — anti-block!); then loop Bloat **5 + summon Gas Bomb** → Super Gas Blast **8** → repeat.
- **Gas Bomb** — HP 7, Minion. Next turn: **Explode 8** (DeathBlow intent). A 7-HP "pay 8 damage or spend a card" tax every 2 turns.

**Punch Construct** — HP 55, **Artifact 1**. Cycle: Ready (**10 Block**) → Fast Punch **5×2 + Frail 1** → Strong Punch **14** → repeat.

**Sewer Clam** — HP 56. Innate **Plating 8** (gains 8 Block at end of each turn; Plating −1/turn → 8,7,6,…0 ≈ 36 EHP that decays). Jet **10** ↔ Pressurize **+4 Str** alternating, opens Jet. **Ramp +4 Str/2 turns.**

**Two-Tailed Rat** (×3) — HP 17–21. Random: Scratch **8**; Disease Bite **6**; Screech **Frail 1** (cooldown 3); **Call for Backup: summons another rat** (needs: 2 turns elapsed for that rat, ≤3 total backups per combat, free slot, no teammate already summoning; once available its weight is 0.75 vs 1/12 each for the others → ~90% pick). Swarm that refills itself up to 3 times.

### Underdocks elites

**Phantasmal Gardeners (×4)** — HP 26–31 each (**104–124 total**). Innate **Skittish 6: the first time it's hit each turn it gains 6 Block** (punishes single big hits, rewards multi-hit/AoE sequencing). All four run the same 4-move cycle at staggered offsets (first→Flail, second→Bite, third→Lash, fourth→Enlarge): Bite **5** → Lash **7** → Flail **1×3** → Enlarge **+2 Str** → repeat. **Ramp: each gardener +2 Str/4 turns; kill order constantly reshuffles which moves land.**

**Skulking Colony** — HP **75** with innate **Hardened Shell 20: cannot lose more than 20 HP per turn** (fight lasts ≥4 turns no matter your burst — hard anti-burst). Fixed cycle: Zoom **14** → Zoom **14** → Inertia **9 + gains +2 Str** → Piercing Stabs **7×2** → repeat. **Ramp +2 Str/4 turns.**

**Terror Eel** — HP **140**. Innate **Shriek 70: first time HP ≤70 → Stunned** (free turn). After the stun: Terror = **Vulnerable 99 on the player** (rest of fight you take +50% from attacks). Combat loop (before and after): Crash **16** ↔ Thrash **3×3 + Vigor 6** (its next attack +6 → Crash hits 22). **Second-half soft-enrage via player-side Vulnerable.**

### Underdocks bosses

**Waterfall Giant** — HP **240**. T1 Pressurize: applies **Steam Eruption 15** to itself; EVERY subsequent move adds **+3 Steam Eruption**. Loop after T1: Stomp **15 + Weak 1** → Ram **10** → Siphon (**heals 10** × player count) → Pressure Gun **20 (+5 per use — 20, 25, 30…)** → Pressure Up **13** → back to Stomp. When "killed": becomes invulnerable ("About to Blow", HP display infinite) then **Explodes for the accumulated Steam Eruption total** at end of your next turn (DeathBlow) — the longer the fight, the bigger the death bomb (~15+3/turn; kill on turn 8 ≈ 36+ dmg incoming). **Double clock: Pressure Gun ramps AND the death-bomb grows.**

**Soul Fysh** — HP **211**. Fixed 5-turn loop: Beckon (**+2 Beckon**: 1 → random spot in draw pile, 1 → discard) → De-Gas **16** → Gaze **7 + 1 Beckon → discard** → Fade (**Intangible 2**: ALL damage it takes reduced to 1 for 2 turns) → Scream **13 + Vulnerable 3** → repeat. Beckon card: cost 1, Status — at end of turn if in hand, **lose 6 HP (unblockable)**; +3 copies per cycle. **Clock = junk accumulation + 2/5 turns quasi-invulnerable.**

**Lagavulin Matriarch** — HP **222**. Starts **Asleep 3** (wakes after 3 turns OR upon losing HP) + **Plating 12** (12 Block end of each turn, decaying 1/turn — poke through it to wake her early at a cost). Awake fixed loop: Slash **19** → Disembowel **9×2** → Slash2 **12 + 12 Block** → Soul Siphon (**player −2 Str −2 Dex, self +2 Str**) → repeat. **Ramp: +2 Str AND player stat drain every 4 turns (double-dip like STS1 Lagavulin).**

---

## 3. Anti-stall census — Act 1

"Ramp" = damage output scales with fight length (guaranteed, not RNG-gated).

### Overgrowth: 12 of 17 distinct monsters ramp
| Monster | Ramp | Rate |
|---|---|---|
| Fuzzy Wurm Crawler | YES | +7 Str / 3 turns |
| Nibbit | YES | +2 Str / 3 turns |
| Shrinker Beetle | no (debuff instead) | — |
| Twig/Leaf Slimes | no (junk instead) | — |
| Inklet | no | — |
| Cubex Construct | YES | ~+4 Str / 3 turns |
| Flyconid | no | — |
| Fogmog | YES | +1 Str / ~2 turns (+ immortal Dazed fountain = soft clock) |
| Mawler | no | — |
| Ruby Raider (Brute) | YES | +3 Str / 2 turns |
| Snapping Jaxfruit | YES | +2 Str / turn |
| Slithering Strangler | soft | +3 end-of-turn DoT reapplied / 2 turns |
| Vine Shambler | no | — |
| Bygone Effigy (elite) | YES | +10 Str once (T2), then flat 23/turn |
| Byrdonis (elite) | YES | +1 Str / turn |
| Phrog Parasite (elite) | no (junk + death adds) | Wrigglers self-ramp +2 Str/2 turns |
| Vantom (boss) | YES | +2 Str / 4 turns + 3 Wound / 4 turns |
| Ceremonial Beast (boss) | YES | +2 Str / turn (P1); +3 Str / 3 turns (P2) |
| Kin Priest + Followers (boss) | YES | +2 Str / 4 turns (priest); +2 Str / 3 turns (each follower) |

### Underdocks: 12 of 16 distinct monsters ramp
| Monster | Ramp | Rate |
|---|---|---|
| Corpse Slug | conditional | +4 Str per allied death (eats corpses) |
| Seapunk | YES | +1 Str / 3 turns |
| Sludge Spinner | RNG | +3 Str per Rage (~1/3 turns) |
| Toadpole | no (thorns) | — |
| Damp Cultist | YES | **+5 Str / turn** |
| Calcified Cultist | YES | +2 Str / turn |
| Fossil Stalker | conditional | +3 Str per unblocked hit |
| Gremlin Merc | YES (mild) | +2 Str / 3 turns + steals 20g / turn |
| Haunted Ship | no (junk) | — |
| Living Fog | soft | +1 Gas Bomb (8 dmg pending) / 2 turns |
| Punch Construct | no | — |
| Sewer Clam | YES | +4 Str / 2 turns |
| Two-Tailed Rat | soft | +1 body (≤3) |
| Phantasmal Gardener (elite) | YES | +2 Str / 4 turns each (×4 bodies) |
| Skulking Colony (elite) | YES | +2 Str / 4 turns (+ hard 20-HP/turn kill floor) |
| Terror Eel (elite) | YES (phase) | Vulnerable 99 on player after 50% + Vigor 6 / 2 turns |
| Waterfall Giant (boss) | YES | +5 dmg per Pressure Gun use + death bomb +3 / turn |
| Soul Fysh (boss) | YES (junk) | +3 Beckon cards / 5 turns (6 HP each if stuck in hand) |
| Lagavulin Matriarch (boss) | YES | +2 Str self AND −2 Str/−2 Dex player / 4 turns |

**Bottom line: ~70% of act-1 monsters have a length-scaling mechanic; every single act-1 elite and boss has one.** The ones without ramps compensate with debuffs (Shrink/Tangled/Smoggy), junk injection, or defensive gimmicks (Slippery/Skittish/Artifact/Plating).

---

## 4. Act 2 (Hive) & Act 3 (Glory) HP ranges (A0)

### Hive (act 2)
- Weak pool bodies: Exoskeleton 24–28 (×N), Thieving Hopper 79, Tunneler 87, Bowlbugs 21–48 per variant
- Normal bodies: Bowlbug variants Egg 21–22 / Nectar 35–38 / Rock 45–48 / Silk 40–43, Chomper 60–64, Myte 61–67, Slumbering Beetle 86, Hunter Killer 121, Spiny Toad 116–119, The Obscura 123, Ovicopter 124–130, Louse Progenitor 134–136
- Elites: Decimillipede (segments 40–46 each ×N), Entomancer **145**, Infested Prism **161**
- Bosses: The Insatiable **321**, Knowledge Demon **379**, Kaiser Crab = Crusher **209** + Rocket **199** (= **408** total)
- Act-2 normal single-body range ≈ **60–136** (vs act-1 ≈ 47–80); elites ≈ 145–161 (vs 61–140); bosses ≈ 321–408 (vs 173–308).

### Glory (act 3)
- Weak: Devoted Sculptor 162, Turret Operator 41 (+turret?), Scrolls of Biting 30–37 ×N
- Normal: bots 16–23 each (swarms: Guardbot/Stabbot/Zapbot/Noisebot), Axebot 70–78 (respawns), Frog Knight **191** (see spec below), Fabricator 150, Globe Head 148, The Lost 93 + The Forgotten 106, Owl Magistrate 231, Slimed Berserker 261 (injects **10 Slimed**)
- Elites: Magi Knight 82 + Spectral Knight 93 + Flail Knight 101 (Knights = **276** total), Mecha Knight **300**, Soul Nexus **234**
- Bosses: Queen **400**, Test Subject **100 first form** (multi-form respawns), Aeonglass **512**
- **Frog Knight (act-3 normal, fully extracted as reference): HP 191, innate Plating 15. Loop: Tongue Lash 13 + Frail 2 → Strike Down Evil 21 → For the Queen +5 Str → repeat; one-time Beetle Charge 35 replaces Tongue Lash when first below 50% HP.**

**Act-over-act multipliers (normal single bodies): act1→act2 ≈ ×1.7–2.0; act2→act3 ≈ ×1.4–1.6. Bosses: 173–308 → 321–408 → 400–512+.**

---

## 5. Player baselines

| Character | HP | Energy | Draw | Gold | Starting deck | Starting relic |
|---|---|---|---|---|---|---|
| **Necrobinder** | **66** | 3 | 5 | 99 | 4× Strike(6) + 4× Defend(5) + Bodyguard + Unleash (10 cards) | Bound Phylactery: at start of your turn, Summon 1 (feeds Osty minion) |
| Ironclad | 80 | 3 | 5 | 99 | 5× Strike + 4× Defend + Bash(2c: 8 dmg + Vuln 2) (10) | Burning Blood: heal 6 after combat |
| Silent | 70 | 3 | 5 | 99 | 5× Strike + 5× Defend + Neutralize + Survivor (12) | Ring of the Snake: draw +2 cards on combat start |
| Defect | 75 | 3 | 5 | 99 | 4× Strike + 4× Defend + Dualcast + Zap (10) | Cracked Core: Channel 1 Lightning at combat start |
| Regent | 75 | 3 | 5 | 99 | 4× Strike + 4× Defend + Falling Star + Venerate (10) | Divine Right: gain 3 Stars at combat start |

- Strike = 1 cost, 6 dmg. Defend = 1 cost, 5 Block. Bodyguard = 1 cost, Summon 5. Unleash = 1 cost, Osty attack + bonus = Osty's current HP.
- Base hand draw constant: `baseHandDrawCount = 5` (`CombatManager.cs`).

## 6. Gold rewards (A0, `EncounterModel.cs`)

| Room | Gold |
|---|---|
| Normal monster fight | **10–20** |
| Elite | **35–45** |
| Boss | **100** flat |
| (Poverty ascension) | ×0.75 |
| Gremlin Merc steal-back | stolen gold returned as extra reward if Fat Gremlin killed before fleeing |

## 7. Status/junk card specs (all `CardType.Status`, `CardRarity.Status`, not upgradable)

| Card | Cost | Keywords | Effect | Injected by (act 1–2) |
|---|---|---|---|---|
| **Slimed** | 1 | Exhaust | On play: draw 1 card (pay 1 energy + a play to cycle it) | Twig Slime M (1→discard), Leaf Slime M (2→discard), Leaf Slime S (1→discard); act 3 Slimed Berserker (10!) |
| **Dazed** | — | Unplayable, Ethereal | Dead draw; evaporates at end of turn if in hand | Eye with Teeth (3/turn→discard), Haunted Ship (5 once→discard); act 2 Chomper (3→discard) |
| **Wound** | — | Unplayable | Dead draw, PERSISTS (stays through reshuffles) | Vantom boss (3 per 4-turn cycle→discard) |
| **Infection** | — | Unplayable | At end of turn, if in hand: take 3 damage | Phrog Parasite (3→discard), Wriggler (1/2 turns→discard) |
| **Beckon** | 1 | — | At end of turn, if in hand: lose 6 HP (unblockable). Playable for 1 to discard it | Soul Fysh boss (3 per 5-turn cycle; 1 goes to RANDOM spot in draw pile) |
| **Burn** | — | Unplayable | At end of turn, if in hand: take 2 damage | act 3: Mecha Knight (4→HAND), Test Subject |
| **Toxic** | — | (act 2) | injected directly TO HAND by Myte (2) | act 2 Myte |
| **Void** | — | Unplayable, Ethereal | On draw: lose 1 Energy | (colorless/act 3 sources) |
| **Wither** | — | (act 3) | Aeonglass boss junk | act 3 |

Pile destinations used: `Discard` (most), `Hand` (Burn/Toxic — immediate pressure), `Draw` at `CardPilePosition.Random` (Beckon — delayed landmine).

## 8. Reusable power/mechanic glossary (act-1 relevant)

| Power | Effect (A0 text) |
|---|---|
| Ritual N | +N Str at end of its turn, every turn |
| Territorial N | same as Ritual (elite flavor) |
| Plating N | gains N Block at end of turn; N decays 1/turn |
| Slippery N | next N times it loses HP → lose only 1 instead |
| Skittish N | first time hit each turn → +N Block |
| Hardened Shell N | cannot lose more than N HP per turn |
| Shriek N | first time HP ≤ N → Stunned (1 free player turn) |
| Plow N | first time HP ≤ N → Stunned + loses all Str (boss phase gate) |
| Steam Eruption N | on kill: explodes for N at end of your next turn |
| Ravenous N | ally dies → eats corpse, Stunned 1 turn, then +N Str |
| Suck N | +N Str each time it deals UNBLOCKED damage |
| Thievery N | steals ≤N gold per attack; Heist carrier refunds on kill |
| Surprise | on death, splits into hidden second wave |
| Illusion | on death, revives next turn at full HP |
| Infested N | on death summons N adds |
| Asleep N | wakes after N turns or on HP loss |
| Intangible N | all damage taken reduced to 1 for N turns |
| Minion | flees when leader dies |
| Artifact N | negates N debuffs |
| Constrict N | take N dmg at end of your turn while source alive |
| Shrink | your Attacks −30% dmg (while alive / 3 turns) |
| Tangled N | your Attacks cost +1 Energy for N turns |
| Smoggy N | you can play only N Skills per turn |
| Ringing N | you can play only N cards per turn |
| Slow 1 (self) | takes +10% attack dmg per card you played this turn |
| Weak / Frail / Vulnerable | −25% attack dmg / −25% block / +50% dmg taken (STS1 values) |
| Vigor N | its next attack +N |
| Thorns N | attacker takes N per hit |

## 9. Notable design patterns worth stealing

1. **Every elite/boss has a length clock**; trash splits ~70/30 ramp vs. gimmick.
2. **Desync twins**: identical monsters in one fight start at different points of the same cycle (Nibbits front/back, Corpse Slugs indexed, Gardeners by slot, Kin Followers slot1) — variety without RNG.
3. **Phase gates are player-driven damage thresholds** (Plow 150, Shriek 70, Lagavulin sleep), not timers — the player controls when the phase flips, and it's telegraphed on the power icon.
4. **Theft with receipt**: Thievery steals per attack → hidden Surprise split → Heist carrier tries to flee → killing it refunds; escaping zeroes the fight's gold reward.
5. **Junk injection is act-1-native** (5 of ~28 act-1 encounter families inject), mostly to DISCARD (delayed pain); to HAND only in later acts (Burn/Toxic); Beckon uniquely seeds the DRAW pile at a random position.
6. **Anti-burst vs anti-poke tools are distributed**: Slippery (anti-poke), Skittish (anti-big-hit), Hardened Shell (burst cap), Artifact (anti-debuff), Intangible (2/5-turn windows), Plating (decaying armor).
7. **First-3-fights weak pool** with strictly smaller HP (38–57 solo) and simpler kits; regular pool starts at fight 4.
8. **Weighted RNG movepools are constrained**: `CannotRepeat` everywhere, cooldowns (Flyconid Vuln 3-move CD), `UseOnlyOnce` (Mawler Roar), max-N-in-a-row (Twig Slime pounce ×2) — variance is bounded on both sides.
