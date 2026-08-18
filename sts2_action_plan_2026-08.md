# STS2 → Dice Odyssey — Systems Comparison & Action Plan (2026-08-15)

Companion to [sts2_audit_2026-08.md](sts2_audit_2026-08.md) (the findings) — this doc is the
**decision layer**: what's actually different between the two games, how STS2 builds run-long
difficulty pressure and what that translates to in our numbers, everything worth doing ranked
by ROI, and the art/UI commission list with generation prompts.

Sources: the full audit, the four balance docs (numbers re-verified against code 2026-08-15),
`enemy_design_analysis_2026-08.md` §5/§8/§9, a fresh UI construction inventory (every combat
surface, stylebox vs painted), and **new reference probes the audit didn't cover**: player-side
numbers and per-act enemy progression (§2.1 below — this closes the audit's open thread
"per-act HP/damage progression: not gathered").

Verdict tags: things marked **[verified]** were read from the reference or our code;
**[inferred]** is derivation; **[estimate]** is general genre knowledge, treat with care.

---

## 1. The two games, structurally — the recap

### 1.1 One-table comparison

| Axis | STS2 | Dice Odyssey | Materially different? |
|---|---|---|---|
| Turn resource | 3 energy, fixed for the run | Dice → banked Power; dice count **grows by purchase** | **YES — see 1.2-A** |
| Variance source | Draw order (values are fixed) | Roll outcomes (draw too, but rolls dominate) | **YES — 1.2-B** |
| Attack vs defense | Cards gated by shared energy | Attack & Block cards drain the **same Power bank** | partially (similar in practice) |
| Player HP | 80 / 70 / **66** (Necrobinder) | **66**, both acts | **No — direct read-across works** |
| Emergency valve | Potions (3 slots) | None (Scout/Mech/Lucky are *pre-roll* control) | **YES — 1.2-C** |
| Run length | 3 acts (act 1 has 2 map variants), 15 rows each | 2 acts, 15 floors each | scale, not shape |
| Inter-act | (act transition heal) | Full heal + infusion pick | equivalent |
| Healing | Campfire 30%, ~6-7 rest sites/map | Campfire 33%, ~4/map + guaranteed floor 14 | equivalent |
| Fight generation | Whole act pre-drawn, tag-adjacency rule | Draw-on-entry, group lockout | ours equal/stronger |
| Enemy AI | State graph (chains + branches) | Flat CONDITIONAL + weighted list | primitives equal; composition differs (audit 2.1-2.3) |
| Anti-stall | Authored ramps only, **zero** turn-count reads | 6 promised ramps + greed taxes; §9 plan | aligned once §9 ships |
| Reward odds | 60/37/3, elite 50/40/10, boss 100R, pity −0.05→+0.40 | Same odds; pity +0.2/screen cap 2.0 (~17%) | odds identical; pity shape differs |
| Economy | C50/U75/R150, removal 75+25, gold 10-20/35-45/100 | Same ratios; **dice are an extra sink STS has no analog for** | **YES — 1.2-A again** |
| UI chrome | Zero styleboxes in gameplay UI; every button is painted art on plain `Control` | 111 files of StyleBoxFlat; default Button theme = *card* styleboxes | **YES — §4** |
| Juice grammar | Long readable beats (2.5s deaths, 2.0s damage numbers), curve-shaped hit-stop | Short beats (0.4s death, 0.6s numbers), flat-hold hit-stop | **YES — §3 batch 1** |
| Onboarding | 15 one-shot opt-in tips | 1 scripted combat tutorial + 3 tips | ours deeper, narrower — §3 batch 2 |

### 1.2 The four differences that actually drive decisions

**A. Energy is purchasable.** In STS2 the power curve is cards + relics on a fixed 3-energy
chassis. In DO, buying a die is buying **permanent energy** (~+3.5 expected Power/turn ≈ +25-35%
of early output per die). Consequences: (1) our within-act player-power curve is steeper and
**step-shaped** — P ≈ 11 → 17-21 → 25-32 across act 1, with a visible step at each dice
purchase; (2) the shop does load-bearing difficulty work that STS's shop doesn't, so **shop
availability variance is a difficulty bug for us in a way it isn't for them** (a shopless
stretch = a flat power curve = the next tier overshoots). This is why "map target counts vs
rolled weights" (audit 5.5) matters *more* for us than it did for them.

**B. Variance lives in the roll, and our answer is *pre-roll control*, not post-hoc smoothing.**
STS2 smooths bad luck with card draw over fixed values + potions as the panic button. We expose
raw variance every turn and sell the tools to shape it (Scout, Mech, Lucky/Boost, Ricochet
reroll, Recombobulate). This is the identity — don't sand it off. But it has one hard design
consequence STS2 respects from the other side: **enemy-side numbers must stay deterministic and
telegraphed** (our standing rule; their "hidden intent exists and is used nowhere" is the same
rule). The player gambles; the dungeon never does.

**C. No potions = no emergency valve = the spike ceiling is load-bearing.** Their late-game
spikes reach ~35 base damage vs a 66-80 HP pool **[verified]** — survivable partly because a
potion can absorb the failure case. We have no potion, so our "spike ≤ 35-45% of current HP"
ceiling isn't a guideline, it's the *substitute* for the potion system. Never ship a number
above it, including in act 2 after the flat damage bake.

**D. Turn density inverts fight-length targets.** A DO turn contains 5-15 roll decisions; an
STS2 turn plays ~4 cards. Their fights run ~4-7 player turns in hallways, ours target 3-5 —
and ours is correct *for us*. Their community's #1 complaint (fight bloat) is the cautionary
tale: **difficulty must never come from added EHP or added defensive beats — only from clocks,
spikes, and textures.** (Our §5 anti-bloat guardrail, now reference-backed.)

### 1.3 Already at or above parity — the protect list (do not "fix")

From the audit's `already better` verdicts, so nobody relitigates: base reward odds and
elite/boss handling; price ratios and removal escalation; campfire model; damage-scaled popup
choreography; `punch_zoom`; ref-counted hit-stop composition; measured text auto-fit; group
lockout in fight generation; per-tier `.tres` stat split; `.gd`+`.tres` data-driven content
(explicitly validated over reflection); `_prune_stale_targets`; two-loop flat-then-percent
modifier order; the intent rider (`icon2`) model; map relevance tinting; opt-in tutorial with
scripted first combat; fixed (unrolled) enemy HP — deliberate, keeps "Bullseye at 6 kills an
18 HP Satyr" learnable in a game that's already variance-heavy.

---

## 2. How STS2 maintains pressure — and the Dice Odyssey translation

### 2.1 New reference numbers (probed 2026-08-15, closing the audit's open thread)

**Player side [verified]:** Ironclad 80 HP, Silent 70, **Necrobinder 66 — exactly our pool.**
Starting gold 99 (ours 75). This makes the read-across unusually direct: MegaCrit ships a
character who faces every number below with our exact HP total.

**Act structure [verified]:** 3 acts; act 1 is one of two variants (Underdocks / Overgrowth),
act 2 = Hive, act 3 = Glory. 15 rows per act; the first 3 fights draw from a "weak" pool
(acts 2-3: first 2) — the same shape as our tier 0 = floors 1-3.

**Enemy HP progression, base values [verified]** (bodies, not fight totals):

| | Weak/trash body | Normal body | Elite | Boss |
|---|---|---|---|---|
| Act 1 (Underdocks) | 17-27 (rat 17-21, toadpole 21-25, slug 25-27) | 37-82 (cultist 38-41, clam 56, construct 55-60, fog 80-82) | 75-150 (colony 75-80, eel 140-150) | **211-250** |
| Act 2 (Hive) | 21-92 | 60-141 (chomper 60-67, toad 116-124, louse-mother 134-141) | 145-171 | **321-399** |
| Act 3 (Glory) | 30-172 | 93-281 (globehead 148-158, frog-knight 191-199, berserker 261-281) | 234-320 (+ a ~276 three-knight pack) | **400-535** |

**Damage progression, base values [verified, sampled]:** act 1 floors 8-10, spikes 17-21,
boss ~17. Act 2 floors 7-8 (packs) / 17-19 singles, spikes ~23. Act 3 floors 13-21, spikes
**30-35**. Against the fixed 66-80 HP pool: spike threat goes from ~21-26% of max HP in act 1
to **~38-53% in act 3** — their endgame lives at the top of the exact ceiling we already use.

**Act-over-act growth rates [inferred from the table]:** normal bodies ~×2.0 per act, elites
~×1.5-1.75, bosses ~×1.5-1.6, damage ~×1.4-1.6 — while player HP stays flat. **Our
`ACT2_HP_MULT` (1.3-1.75 by tier, 1.6 boss) + flat damage bake sits inside their measured
per-act band.** The act-2 placeholder multipliers, chosen from feel in July, are independently
validated by the reference. What they do better: per-stat authoring (block and debuff stacks
scale too — the two known holes in our bake), and that's Steam-phase work, not launch work.

### 2.2 The pressure model — four mechanisms, not one

Reading everything together, STS2's difficulty is maintained by four interlocking systems.
None of them is "make enemies stronger mid-fight by a hidden rule" — the audit verified zero
turn-count reads across all 122 monsters.

1. **An attrition economy.** HP is the run currency. Fights are priced in expected HP loss
   (~5-12% of max for on-curve hallways, ~25-35% elites, ~30-45% boss), healing is scarce and
   *contested* (campfire heal vs upgrade — the same tension we ship), and the run is lost by
   compounding, not usually by one fight. The per-fight price is enforced by…
2. **Per-fight clocks, authored as moves.** The cultist pattern: one telegraphed early move
   installs a self-ticking Strength engine, visible as a badge, and the fight's cost rises
   every extra turn. Deadlines are scripted per-encounter (the thief escapes), never global.
   Trash gets texture (slot-keyed openers, cannot-repeat, cooldowns); **bosses get
   deterministic cycles** — planning pressure, not surprise. [= our §8/§9 program, verbatim]
3. **A stat race the player must keep up with.** Body HP ×2 per act, damage ×1.5, HP flat —
   the deck must roughly double in output per act or fights leave the fun band. Elites/bosses
   gate the race; the reward system feeds it.
4. **Variance control on the *reward inflow*, not the combat.** Pity timers, guaranteed shop
   slots, target-counted maps (exactly N elites/shops/rests per act), and a **negative starting
   rare offset — the first ~3 card rewards of a run literally cannot roll Rare**. Difficulty
   stays stable because the *power inflow* is stable: no floor-1 jackpot, no starved-of-shops
   act. This is the least visible mechanism and the one we match least.

### 2.3 Dice Odyssey against the model — where we're aligned, where we're soft

**Aligned (and now reference-backed):** fight-length targets (T0 3-4 / T1 3-5 / T2 4-6 /
elite 5-7 / boss 6-9 ≈ their lengths minus our turn-density discount); the D/P fun zone
0.4-0.7; the 35-45% spike ceiling (= their act-3 reality); the attrition targets
(hallway ~12% / elite 25-35% / boss 30-45% — same bands); campfire economy; act-2 multipliers
(2.1 above); the whole §8/§9 enemy program (their mechanism #2 is our plan, almost move for
move — including "install a self-ticking status" being preferred over "add a buff beat").

**Soft spots, each with a concrete fix in 2.4:**

- **S1 — Tier 2 is under-pressured relative to tier 1.** Measured steady D/P ≈ 0.30-0.45,
  *below* T1's 0.45-0.6 — the documented "treadmill". The July docs' own line: "the attrition
  budget got cheaper for the player while per-turn danger stayed flat."
- **S2 — Elites go stable-state under disciplined play** (Canalize/Absorb dodged → DP hits 11
  flat forever). Mechanism #2 says mastering counterplay should *slow* the clock, never stop
  it. [= §9's thesis; audit 2.5 vindicated the authored column, questioned only the backstop]
- **S3 — Reward inflow is spikier than theirs.** No floor-1 rare protection (5-rare pool,
  several run-defining); pity plateaus at ~17% (theirs climbs to ~43%); maps roll weights so
  a run can starve of shops/campfires — and per 1.2-A, a shopless act hurts us *more* than it
  would hurt them.
- **S4 — The elite risk premium is underpaid.** Theirs: elite gold ≈ 2.3-2.7× a hallway fight,
  plus a relic. Ours: 45-60 vs tier-2's 40-50 ≈ **1.2×**, plus a relic. Fighting an elite is
  a 25-35% HP wager for a ~10-gold premium.
- **S5 — Act-2 scaling is a blunt (but correctly-sized) instrument.** Block amounts and debuff
  stacks don't scale; tiers 1-2 draw the same pool. Fine for the "early preview" framing;
  becomes real work at Steam.

### 2.4 Concrete number moves (each independently shippable)

| # | Move | Exact change | Rationale / risk |
|---|---|---|---|
| N1 | **No-rare-early rule** | First **2** reward screens of a run roll Common/Uncommon only (rare weight 0; pity starts accumulating from screen 3) | Their negative offset, simplified. Protects the early curve from a turn-3 build-defining drop; invisible to most players. XS, zero risk. |
| N2 | **Elite gold premium** | Act-1 elite gold 45-60 → **70-90** (act 2 keeps ×1.5) | Fixes S4; makes the elite wager read as a wager. XS. |
| N3 | **Shop floor guarantee** | Map generation: if floors 4-13 rolled zero shops, convert one mid-act monster room | Fixes the S3 tail that hurts us most (1.2-A). Small generator change, verify with `debug_map_look`. The full "target counts" rework stays post-launch (audit 5.5). |
| N4 | **T2 pressure dials — only after §8 lands** | The two pre-scoped levers and nothing else: Hound double-hit 6→7, Maelstrom 12→13 | Fixes S1 *if* §8's texture batch doesn't already (it adds spikes/riders at parity — pressure without DPT). Sequence: §8 → playtest → then decide. |
| N5 | **§9 authored ramps** | As written in §9.4 (Goblin rider, Lich rider, DP spike-step 15→18→21, cadence gates shipped) | Fixes S2. Audit-vindicated. Hold the global backstop until Golem stall is actually measured in play (audit 2.5). |
| N6 | **Pity ceiling** | Leave at 2.0 (~17%) for launch | Their 43% ceiling serves a huge rare pool; ours has 5 rares + dedup — a high ceiling distorts more than it delights. Revisit on feedback only. |
| N7 | **Act-2 gold sink** | When playtest confirms mid-act-2 pooling: act-2 shop prices ×1.25 | Already pre-scoped in the audit; just keeping it attached to the plan. |

### 2.5 The attrition ledger — act 1 worked example (the model made concrete)

Typical path: 15 floors ≈ 3 T0 + ~3 T1 + ~3 T2 fights, ~1-1.5 elites, ~3 events, ~1 shop,
~2-3 campfires (1 guaranteed at floor 14), boss.

| Ledger line | On-curve player [estimate] | Pressure band (design targets) |
|---|---|---|
| 3 × T0 | −6 | 0-6 solo / 6-12 swarm |
| 3 × T1 | −15 | 8-15 each |
| 3 × T2 | −25 | 12-22 each |
| 1.3 × elite | −18 | 17-23 each (25-35% max HP) |
| Boss | −22 | 20-30 (30-45%) |
| **Damage out** | **≈ −85** | worst-band ≈ −150 |
| Campfires (≈half rested) | +33 | +22 each rested |
| Healing events | +15-25 | pool-dependent |
| **Net** | **≈ −35 → arrive at boss ~45-55/66 after the floor-14 rest** | bad runs die in tier 2 — which is where "please let me reach a campfire" is supposed to live |

The ledger closes with ~20 HP of slack for the on-curve player and none for the bad-tail —
that's the correct shape, and it's the frame to re-check after every future numbers change:
**a fight retune is really a ledger-line retune.** S1/S2 above are visible here as the −25 and
−18 lines currently running under target; N4/N5 are what bring them back up without touching
fight length.

---

## 3. The ROI-ranked plan

Ranking = player-visible impact ÷ effort, weighted by the two stated goals (trailer-ready
footage; itch/Steam funnel) and by risk to validated content. Cost letters: XS < half-day,
S ≈ day, M ≈ 2-4 days, L ≈ week+.

### Batch 0 — Pay the playtest debt first (0 code, ~1 evening)

Everything shipped since 08-13 is harness-verified but **unplayed**: charge delivery, loadout
picker, dice-gate events, intent riders, mech arrows, cadence promotions, Ricochet feel. Plus
the two landing-SFX placeholders awaiting your pick. One session of play produces: the §8
verdicts (Venom Bloom T0, B.Kraken, Gargantua buff), the Golem-stall read that decides the
backstop, and confidence that batches below build on solid ground. **Highest ROI item in this
doc: it costs nothing and unblocks three others.**

### Batch 1 — The feel pass (all audit-`adopt`, mostly XS-S, ~3-4 days total)

Everything here touches every fight and every clip. Ordered by payoff-per-line:

1. **Hit-stop reshape** (audit 4.2) — depth 0.02→**0.1**, ramp back out along named easing
   curves (strength = curve, duration = separate small enum), keep our ref-counting. Our own
   comment says we pushed depth to 0.02 because it read as nothing — we were compensating for
   the flat-hold + snap shape. XS, transforms every hit.
2. **Enemy death v1 + speed setting** (4.1 + 4.5, ship together) — corpse holds at ~0.45
   alpha, continuous upward drift of tumbling **dice-pip/face fragments** (negative gravity,
   30° cone, pop-hold-shrink scale, ~1.2-1.5s total), one death sound, wait-then-dissolve
   ordering so the hit reaction isn't cut off. Speed pref (Normal/Fast/Instant) as early
   returns at animation entry points. S+S. The single most clippable missing beat — our kill
   moment is currently a 0.4s alpha fade.
3. **Button feel kit** (1.3 + 1.7) — one tiny shared HSV-brighten shader (modulate can only
   darken; HSV-v brightens without washing out), **instant hover-in / 0.5s expo hover-out**,
   press = visuals shift down 3-4px, disabled = 0.5 gray, blank the focus stylebox once,
   clear hover state on `visibility_changed` (retires the 4×-fixed tooltip-stuck family at
   the root). Apply to End Turn, ROLL, shop and menu buttons. S.
4. **End Turn button package** (1.6) — resize ~194×43 → **~150×62** and inset to ~(64, 96)
   from the corner (matches their screen-relative size); **hover flashes the playable cards**
   (wiring over `Events.hover_playable_cards`); upgrade the "shiny" pulse to an expanding
   additive ring (keep our trigger — it's more precise than theirs). XS-S. Painted art in §4.
5. **Damage numbers** (4.4) — lifetime 0.6→**~1.0s** with **alpha ease-in** (holds readable,
   fades late); keep all our damage-scaled choreography. XS. Verdict inline: recommend 1.0s,
   not their 2.0 — we fire far more numbers (volleys/AoE).
6. **Shake upgrade** (4.3) — sine×sine envelope on camera shake (recoil, not rattle),
   creature shake horizontal-only (protects the ground-line work), one named magnitude ladder
   with the deliberate gap, delete dead `Shaker.shake()`. XS.
7. **Hand drops-and-dims as one object during enemy turn** (4.6) — "not your turn" as motion.
   Per-card dimming stays for "this card is unplayable". XS-S.
8. **Hygiene riders:** delete the two hot-path release prints (2.11, 7.6). XS.

### Batch 2 — Onboarding & map (the itch funnel, ~2-3 days)

9. **Map spread-nudge** (5.1 cheap version) — replace the blind ±22px jitter with
   "maximize gap to row neighbours, clamped ±22". Directly targets the one unaddressed
   playtest complaint ("je comprends pas la map"); zero balance risk; verify with
   `debug_map_look`. S.
10. **First-time tips** (5.3) — one-shot modals reusing the reward-popup pattern for: map,
    shop(s), campfire, first relic, reshuffle, card removal. We have 3, they have 15; these
    six are the gap that matters. S-M total.
11. **"Can't-play-anything" first-time tip + spotlight** (5.4) — name the situation the first
    time the gold End Turn pulse fires; raise the real button above the dimmer (our overlay
    already dims/glows). Include their self-retiring trick from 1.9 for the inverse case
    (ending turn with a playable card): fire only when truly playable, retire after the
    player demonstrates competence 3 times. XS-S.
12. **Tooltips** (1.8) — panel 204→~320px wide (retires the 3-line ceiling chore), card
    tooltip delay 1.0s→**0.2s** (their 0s would flicker across a fanned hand). XS.
13. **Graceful event-pool exhaustion** (3.3) — warn + allow repeats instead of running dry;
    insurance now that events are gated. XS.

### Batch 3 — Combat depth (the §8/§9 program with audit upgrades, ~1 week + playtests)

14. **§8.4 wiring/honesty pass first** — explicit `is_performable` on Lich/Gargantua/Sigil,
    write the Absorb tooltip, align the Flux tooltip. These are our de-facto *hidden intents*
    and the reference's honesty bar says fix them before any new enemy content. XS-S.
15. **Picker vocabulary upgrade** (2.2) — `cannot_repeat` and `cooldown_n` as `@export`s on
    `EnemyAction` (replaces 5 hand-rolled counters; gives §8.2's caps for free and future
    enemies a real grammar). S.
16. **Slot-keyed openers** (2.4) — twin packs desync **deterministically** by body index;
    resolves the open B.Kraken verdict in a strictly safer form (7+7 turn-1 becomes
    impossible, not just unlikely). XS. Remaining call: apply to tier 0 at all.
17. **T1 texture batch** (§8.2: Goblin 7→9, Oculus guard, Sigil 12/7/guard, ±Venom Bloom)
    → playtest. **Elite batch** (Lich 8/10/5+W2, DP 12/8+6/15, Gargantua flurry, Hound Roar
    at ≤50% — implemented as CONDITIONAL `is_performable` reading own HP per audit 2.6, with
    the tell/behaviour split) → playtest. §9 ramps ride the same edit passes (N5).
    New-ramp style rule from the reference (2.5): where an enemy has no natural recurring
    buff beat, prefer **one early move that installs a self-ticking status** over adding a
    beat to the cycle.
18. **Reward-side guards** N1-N3 (above). XS each.
19. **Curse cards** (§8.3, Sludge→Cinder→Hex) after the batches, act-2 carriers. M.

### Batch 4 — Painted chrome (art + integration, §4 below, ~2-4 days spread)

20. Generate + integrate: ROLL, End Turn, dice tray, top bar, banner ribbon, scout plate
    (prompts in §4.3). Integration recipe in §4.4 (shadow-from-own-texture, animated outline
    overlay, no per-state art needed).
21. **UiPalette + default-theme fix** (1.1 piece 1, 1.5) — a `UiPalette` sibling to
    `DicePalette` (navy, golds, teal, cream, disabled-gray as named constants), point
    `main_theme.tres` Button styles at an actual button style instead of card styleboxes,
    collapse the 15-radius/7-border zoo on touched scenes. S. This is the foundation that
    stops the drift from regrowing.

### Post-launch parking lot (recorded, argued, not for now)

Painted-atlas paradigm across all UI · chain-based cadences (never retrofit the two shipped
promotions) · duplicate-path pruning (5.2) · blocking-screen registry (7.1, adopt at the
*next* new modal) · AutoDaiso run-walker + dev console + `--seed` flag (8.2/8.3 — the
run-walker exercises the screen *seams* where all four of this year's serious bugs lived) ·
lifecycle signals `card_drawn/exhausted/discarded` + the `Modify*/Should*` hook families
(6.2/6.5 — adopt the **naming convention now**, it's free) · map target counts (5.5) · shop
composition by type (3.2 — if ever, as a hybrid: keep the rare guarantee, add "≥1 Attack, ≥1
Skill, ≥1 Blessing across the 5") · "?" rooms (3.4, only after map legibility) · refusal
reason enum (7.2, next time refusal UX is touched) · a potions-analog consumable system and
meta-unlocks (retention design space, deliberately untouched pre-launch).

---

## 4. Art & UI — what's below the bar, and the prompts

### 4.1 The inventory verdict

Fresh sweep of every combat/HUD surface (2026-08-15): **the world is painted, the chrome is
not.** Backgrounds, characters, cards' art, pile icons, top-bar icons, map parchment and map
icons are all real art. Every *interactive* surface is a `StyleBoxFlat` rounded rect: End
Turn (dark red, no text outline), ROLL (flat gold), the dice-slot tray (navy), the top bar
(teal strip), the scout panel (teal with a bright-yellow blend border — the loudest clash in
the game), both banners (bare text, no plate), tooltips, shop buttons. There is **zero**
NinePatch/StyleBoxTexture usage in the project. Amusing archaeology: `assets/images/`
contains an orphaned `end-turn-button.PNG.import` whose painted source was lost — the game
*had* a painted End Turn button once.

STS2's answer (audit 1.1) is that the whole paradigm is the tell — but their full solution is
an art commission across every screen. The pre-launch move is surgical: **paint the ~6 chrome
pieces that are on screen in every combat frame**, where the flat-rect-vs-painted-world
contrast is most visible, and leave menus/shops on the (consistent, already-styled) navy/gold
styleboxes.

### 4.2 The commission list, ranked by frames-on-screen

| # | Surface | Current | Size (design px) | Notes |
|---|---|---|---|---|
| 1 | **ROLL button** | flat gold stylebox | 150×42 (suggest keep) | The game's signature verb, pressed 5-15×/turn, dead-center. Already has the coil/press animation — painted art multiplies work already done. No per-type tint (standing rejection). |
| 2 | **End Turn button** | flat red stylebox | 194×43 → **~150×62** | Keep the red identity (it's the only red chrome = "commit"). Bigger + inset per batch 1. |
| 3 | **Dice-slot tray** | navy stylebox r18 | ~200×72 | The row above the die. Slots/labels render on top; art must be quiet. |
| 4 | **Top bar** | teal strip + gold bottom rule | 1280×80 | Needs 9-slice (uniform middle, decorated end caps). Biggest surface, most conservative design. |
| 5 | **Turn/Act banner ribbon** | bare text | ~700×140 (art) | One ribbon serves both banners (Act banner scales it up). Instant trailer value. |
| 6 | **Scout panel plate** | teal + yellow border | 336×128, resizes 3-6 dice | 9-slice. Even without art, restyling to navy/gold kills the clash for free — art is the upgrade. |
| 7 | (later) RelicBar backing, map legend plate, tooltip plate | — | — | Small, consistent already, post-launch. |

### 4.3 Generation prompts

House style contract (put at the top of every generation session): *flat cel-shaded 2D game
asset, 2-3 flat tone steps, thick near-black outline (like a chunky sticker), crisp clean
edges, no gradients, no gloss, no photorealism, orthographic front view, no perspective, no
text, no logos, isolated on a solid pure green background (#00FF00)* — matching the dice/cel
language Julien picked for the dice shop ("aligned with the dice textures, less realistic").
Generate the whole set in **one session** so the family stays coherent (the intent-icon
lesson: swap families whole, never mix). Use green bg for gold/red/warm subjects, **magenta
bg for the navy/teal subjects** (tray, top bar, scout) so keying never eats the subject.
Generate large (≥1024 wide) — we downscale through the premultiplied pipeline.

**P1 — ROLL button plate** (wide ~3.5:1, used at 150×42):
> Wide horizontal fantasy game button plate, rounded rectangle about 3.5:1, warm golden-amber
> lacquered surface (#D9A31A) with a slightly darker amber lower half as a painted bevel step
> (#A87A0C), bold dark-brown outline all around (#2A1708), tiny carved notches at the left and
> right ends, empty center, flat cel-shaded 2-tone style, thick near-black contour like a
> sticker, no gradients, no gloss, no text, orthographic, solid pure green background.

**P2 — End Turn button plate** (wide ~3:1, used at 194×62 — the shipped 2026-08-15 size):
> Wide fantasy game button plate, rounded rectangle about 3:1, deep crimson-red lacquered
> surface (#6B1F1F) with a darker maroon lower bevel step (#3D0D0D), ornate but restrained
> gold trim border (#C9A227) just inside a thick near-black outline, two small gold corner
> studs, empty center for text, flat cel-shaded 2-tone style, no gradients, no gloss, no
> text, orthographic front view, solid pure green background.

**P3 — Dice-slot tray** (wide ~2.8:1, used at ~200×72):
> Horizontal dice tray plate for a fantasy dice game UI, rounded rectangle about 2.8:1, dark
> navy-blue felt-like flat surface (#1B2237), thin muted gold rim (#8A6F2B) inside a thick
> near-black outline, very subtle darker navy inner lip suggesting a shallow tray, otherwise
> completely plain and quiet (small dice icons will sit on top), flat cel-shaded style, no
> gradients, no text, orthographic, solid pure magenta background (#FF00FF).

**P4 — Top bar** (very wide, 9-sliced; generate ~4:1 and stretch the middle):
> Long horizontal ornate header bar for a fantasy game HUD, about 4:1, dark teal-navy flat
> surface (#172A2E) with a bold gold lower edge trim (#C8A84B) and a thick near-black outline,
> decorative carved end caps on the far left and far right only, the entire middle section
> perfectly uniform and repeatable, flat cel-shaded 2-tone style, no gradients, no gloss, no
> text, orthographic, solid pure magenta background.

**P5 — Banner ribbon** (wide ~5:1, behind "YOUR TURN" / "ACT 2"):
> Wide heroic banner ribbon for announcement text, about 5:1, dark charcoal-navy fabric with
> painted gold edge borders and slightly forked swallow-tail ends, gently curved silhouette,
> center area plain and dark so bright text reads on top, flat cel-shaded style with 2 tone
> steps and a thick near-black outline, no gradients, no text, no emblem, orthographic, solid
> pure magenta background.

**P6 — Scout panel plate** (~2.6:1, 9-sliced; used at 336×128 and wider):
> Rectangular fantasy game panel plate, about 2.6:1, dark navy-blue flat surface (#141A29)
> with a clean gold border frame (#C9A227) inside a thick near-black outline, small gold
> corner accents, entirely empty interior, flat cel-shaded style, uniform edges suitable for
> stretching, no gradients, no gloss, no text, orthographic, solid pure magenta background.

If a batch comes out styled inconsistently, regenerate the outlier with the winner attached
as a style reference — same protocol as the intent-icon family.

### 4.4 Integration recipe (why one art file per button is enough)

Per the audit's 3-layer anatomy (1.2/1.3), no per-state art is needed:

- **Shadow** = the button's own texture duplicated behind, pure black, alpha ~0.25, offset
  ~(+6, +6) at our scale. Can never desync from the shape. Free.
- **Hover glow outline** = a pre-dilated gold silhouette we derive *programmatically* from
  the keyed PNG (alpha dilate + tint — same PIL pipeline as everything else), sitting on top
  at alpha 0, faded in on hover. Kills the "forgot a stylebox state" bug class structurally.
- **States** = the batch-1 feel kit: HSV-v brighten on hover (instant in, 0.5s expo out),
  visuals shift +3-4px on press, 0.5-gray modulate on disabled.
- **Text** = adopt their weight rule on painted plates: cream `#FFF6E2`-family label with a
  **heavy outline (~30-40% of font size) colored a dark version of the plate's own hue**
  (dark maroon on End Turn, dark brown on ROLL — our End Turn label currently has *no*
  outline). Keep our measured auto-fit.
- **Godot side:** `TextureButton` or `TextureRect`+`Control` for fixed-size buttons;
  `NinePatchRect` for the top bar / scout plate (first uses in the project — margins set to
  the end-cap width). Keep every stylebox as fallback until the swap is verified in a render
  harness (`debug_button_variants.gd` already renders in-context sheets — extend it to accept
  a texture candidate).

---

## 4b. SHIPPED 2026-08-15 — Batch 1 + N1/N2, verified by harness, NOT PLAYTESTED

Julien's calls: do Batch 1, ship N1-N3, generate P1-P6. **No speed setting** (removed on his
call mid-implementation — and the harness had already shown it wasn't load-bearing, see below).

Verification: **`debug_feel_pass.gd`/`.tscn`** at repo root (not committed, auto-excluded from
the web export by the `debug_*` filter) — 35 checks, 0 fail, plus rendered frames
(`debug_death_render.gd`, output in `death_render/`). All six existing regression harnesses
re-run green: double_endturn, audit_changes (28), golem_carryover (12), ricochet_reroll (26),
cadence_promotion (21), tutorial_lock.

**What landed**

| Item | Change |
|---|---|
| Impact ladder | New `Shaker.Impact {VERY_WEAK…HUGE}` + `SHAKE_MAGNITUDE` / `SHAKE_DURATION` / `HIT_STOP_DURATION` / `HIT_STOP_TRANS` tables, and `impact_for_damage()` / `impact_for_fraction()`. One rung now drives shake **and** hit-stop together; `damage_effect.gd`'s two hand-tuned `clampf` curves are gone. Shake outlasts the freeze at every rung by construction. |
| Hit-stop | Depth **0.02 → 0.1**, and recovery now **ramps along a curve** instead of holding flat then snapping. Expressiveness moved from duration to curve (SINE→QUAD→CUBIC→QUART→EXPO). "Longest wins" on overlap is preserved (see below). |
| Camera shake | Rise-and-fall envelope (fast attack, eased decay) replacing constant-amplitude jitter, plus a generation token so overlapping AoE shakes don't fight over `offset`. |
| Node shake | Dead `Shaker.shake()` (zero callers, two comments warning against it) deleted; replaced by `shake_horizontal()` — X-only with a sin×sin envelope, so a hit can't make a grounded enemy read as levitating. |
| Enemy death | Was one 0.4s alpha tween. Now: corpse leaves the `enemies` group + Area2D goes inert + combat UI hides **immediately**, then pre-delay → ghost to 0.4 alpha → 60 rising, tumbling dice-chip fragments (negative gravity, 30° cone, continuous emission, pop-hold-shrink) tinted by the active die's accent → hold → fade. ~1.3s game time. One death sound (placeholder). |
| Damage numbers | Fade switched to **ease-IN** so the number stays fully readable for ~all of its life. (Its lifetime was already 1.0s — `DamageEffect` overrides the popup default; the audit's "0.6s" read the default, not reality.) Same for the block popup. |
| End Turn | 194×43 → **194×62**, inset 26/85 → **64/104** px. Ours was already proportionally *wider* than the reference (15.2% vs 11.5% of screen); only height was deficient (6.0% vs 8.3%) — so growing width would only have risked clipping "End Turn" at 26px Cinzel. Verified non-overlapping with the discard pile. |
| End Turn hover | Hovering it **flashes the still-playable cards** in hand — the reference's best teaching beat: the button answers "why would I *not* end my turn?" before the click. Modulate-only (fan owns position/rotation, hover owns scale). |
| Shiny nudge | Trigger unchanged (ours is more precise than theirs — it accounts for banked Power and Celestials); presentation upgraded with an expanding, fading additive ring behind the button. |
| `ButtonFeel` | New `scenes/ui/button_feel.gd`: instant hover-in / **0.5s expo hover-out**, press = visuals drop 4px, focus stylebox blanked once, and **hover state cleared on `visibility_changed`** — a structural fix for the bug family we'd patched four separate times. Attached to End Turn; `ButtonFeel.attach(button)` is ready for the rest. |
| N1 | Run starts with `rare_weight = 0`, so the **first card reward cannot be Rare**; existing pity lifts it to base from the second screen. The reference's negative-offset rule at our granularity (their offset clears after ~3 card rolls; we draw 3 per screen). No new saved state. |
| N2 | Act-1 elite gold **45-60 → 70-90** (act 2 keeps ×1.5). |
| Hygiene | Both hot-path release prints deleted (`enemy_action_picker.gd`, `modifier.gd`). |

**Four bugs the harness caught that code review had not** — worth recording, all four were
invisible in the diff:
1. `Tween.set_ignore_time_scale()` **does not exist in Godot 4.3**. Calling it threw *inside a
   coroutine*, which also skipped the restore — leaving the entire game at 0.1 speed
   permanently. (`Shaker.hit_stop`.)
2. `tween_property(Engine, "time_scale", …)` doesn't animate either — `Engine` is a singleton
   outside the scene tree. Both are why the ramp is now hand-driven in `_process` against real
   time; `Tween.interpolate_value` is still used as a **static** helper for the curves.
3. Naïvely replacing the in-flight ramp broke the "longest wins" compose guarantee that
   ref-counting existed to provide (a short poke after a haymaker cut the freeze short). Now
   guarded by a real-time deadline.
4. The first death-fragment render showed ~5 chips over a whole body — the count/size were
   below the project's own documented "mass beats form" floor. Raised 26 → 60 and sizes ~1.9×
   after looking at rendered frames, not after reading the code.

**Two things measured rather than built**
- **N3 (shop guarantee) is unnecessary — dropped.** New `debug_map_composition.gd` over 400
  generated maps: shops **min 2 / max 4 / mean 2.95**, campfires min 5, elites min 3,
  **zero maps with no shop at all**, and only 2% with no shop on floors 4-13. The map has used
  a *quota bag* (exact counts) since 2026-07-04, so the audit's "we roll weights, they hit
  target counts" framing (5.5) was already out of date. Nothing to fix.
- **The speed setting wasn't load-bearing.** The audit paired it with the longer death as a
  dependency ("a 1.5s death × 4 bodies is 6 seconds"). Measured: each dying enemy owns its own
  tween, so a **3-body wipe completes in 1.37s total, not 3×1.3s** — deaths overlap. Julien
  cut the setting; the death sequence keeps its full length safely.

**To watch in playtest** — the honest list:
- Death sound is a **placeholder** (`sfx/186658__shmeepz__timpani-1.wav`, pitched 0.72-0.8).
- The killing blow's hit-stop slows the *start* of the death sequence, so a kill occupies
  ~2s of wall clock vs the 1.3s of game time it's authored in. Intentional (the freeze
  emphasises the kill) but it's the first thing to shorten if kills feel slow.
- **Victory panel timing after the last kill** is the one thing the harness could not prove:
  its own environment doesn't reproduce run.gd's wiring, and it behaved identically when
  corpses were freed on the old schedule — so it's a harness gap, not a regression. What *is*
  proven is the precondition: a full wipe empties the enemy container in 1.37s.
- ButtonFeel is attached to End Turn only so far; roll it out to ROLL and the shop/menu
  buttons once the feel is confirmed.

---

## 4c. Enemy layout & size audit (2026-08-15, after the End Turn move)

Julien asked for a full sweep once End Turn changed shape: "make sure nothing overlaps
(status bar, enemies between each other, hp bar, end turn, cards…). Some enemies feel too
small (small satyrs) and some too big (lava hound), and it's always been a struggle to find
sizes & positions with 0 overlap AND making them look grounded."

New harness **`debug_enemy_layout.gd`/`.tscn`** (repo root, not committed). Unlike
`debug_bg_audit` (which renders and dumps *node* rects), this measures each sprite's
**alpha-scanned ink bounds** transformed through the live sprite transform — most enemy art
carries large transparent padding, so node rects lie about where the body is — then checks
every HUD zone, body-vs-body, bar-over-neighbour, off-screen, and feet-line spread across
**all 40 fight files**, and prints a size census.

**The one genuine bug, and it was caused by the End Turn move.** `enemy.gd` clamps an
enemy's status-icon row so it can't reach the End Turn button — against **hardcoded copies
of the button's rect** (`END_TURN_LEFT = 1060`, `END_TURN_TOP = 592`). The button moved 38px
left and 38px up, so those went stale instantly, leaving a 38px band on each axis where a
status row could sit on the button while the clamp believed all was well. **Nothing errors
when these drift — the clamp just silently stops clamping.** Updated to 1022/554 with a
warning comment; anyone moving that button again must update them.

**Sizes — both of Julien's instincts confirmed by measurement, and both fixed:**

| | Before (ink) | After (ink) | Why |
|---|---|---|---|
| Lava Hound | 310×244, **area 75.7k** | 266×210, **area 55.9k** | It was the **widest body in the game — wider than the Leviathan boss** — and out-sized both elites (Lich 69.5k @ 85 HP, Dragon Priest 67.8k @ 90 HP) despite being a 51 HP tier-2 regular. Now sits just under Medusa (56.7k), which is the right rank. Box 320→275. |
| Small Satyr ×8 | 75×140 | 86×162 | Smallest bodies in the game; their HP bar was wider than the body. Box 143→165. |
| Small Kraken ×6 | 119×131 | ~135×149 | Same. Box 134→152. |

Positions were compensated from **measured** feet-distance ratios (satyr 0.4825×box, kraken
0.485×box, hound 0.3906×box) rather than eyeballed, and the re-audit confirms the feet lines
landed **unchanged to the pixel**: satyrs still at 516/518/520, Hound still at 511. That is
the "resize without breaking grounding" recipe — *derive the y-compensation from the measured
centre→feet distance, then verify the feet number is identical afterwards.*
`tier_1_octopus_2_satyrs_2` was deliberately left alone (its bodies were already compressed
by hand to fit four of them).

**Result: every reachable fight is now 0 HIGH / 0 MED.** The only remaining flags are in
`tier_0_satyrs_octopus_3`, which is **not in `battle_stats_pool.tres`** — an unreachable
leftover (one of the four documented ones), so its HP-bar-on-End-Turn and 106px feet spread
can never be seen in a run.

**Two classes of false positive, worth recording because the first audit reported 14 HIGHs
that were not real** — and a harness that cries wolf gets ignored:
- **"ART overlaps PowerNumber" (8 fights).** The Power *label node* is 90×96, but a 1-2 digit
  number inks only ~46px of it. Verified on renders that no enemy visually touches the
  number. Zone narrowed to the measured ink box.
- **"status row overlaps Hand" (3 fights).** The hand is a fanned **arc** — the middle card
  sits ~17px higher than the outer ones. Modelling it as one rectangle flagged status icons
  that actually sit in the clear gap between the fan's right edge and the End Turn button
  (confirmed on renders). Zone split into HandCenter + HandOuter.

---

## 4d. SHIPPED 2026-08-16 — painted chrome (P1-P6 integrated)

Julien generated 26 candidates in one session. All respected the house style and the
9-slice constraint (decorated end caps, dead-flat middles). Picks and the reasoning:

| Slot | Pick | Why |
|---|---|---|
| ROLL | plain gold plate | Renders at 150×42 - the ornamented variants would be mush |
| End Turn | 4-stud red plaque | Thickest frame + symmetric studs survive 62px; one rival had a chipped frame, another top-only studs |
| Dice tray | evenest rim | Must stay quiet under the dice |
| Top bar | compact scroll caps | Taller caps crowd the 80px bar |
| Banner | flatter arc | More room for "YOUR TURN" at 64px |
| Panel | gold-corner frame | **Serves BOTH the scout panel and the tooltip** - same frame language, two sizes, which is exactly what a 9-slice is for |

**Only two of the six actually needed 9-slicing.** End Turn, ROLL, the top bar and the
banner are all fixed-size, so they ship as plain textures stored at 2× design size. The
dice tray (grows with dice count) and the panel (scout 336×128 + tooltip 204×108) are the
only ones that resize; those are stored at ~1× with margins measured from the art (tray 9px,
panel 21px) — 9-slice corners draw at *source* pixel size, so a 2× source would render
double-size corners. The **banner cannot be 9-sliced at all**: it is curved, so no column
repeats.

Assets in `assets/images/ui/`; styleboxes in `scenes/battle/end_turn_texture[_disabled].tres`,
`scenes/dices/roll_button_texture.tres`, `scenes/dices/ui_dice_tray.tres`,
`scenes/ui/ui_panel_plate.tres`, `scenes/run/ui_top_bar.tres`.

**Five things caught during integration, each of which would have shipped as a visible bug:**
1. **ROLL's hover/pressed were still flat gold rects** — only `normal` had been swapped, so
   the painted plate would have popped away to a stylebox on hover. All four states now
   point at the plate. (ROLL keeps its own scale-based hover/press kit, which touches
   `scale`, not `position`, so it does not fight the socket dip.)
2. **End Turn had two writers on `modulate`** — the gold "nothing left to do" pulse and
   ButtonFeel's hover. The nudge is now carried entirely by the expanding ring, which is a
   separate node and cannot contend.
3. **`.tscn` requires every `ext_resource` in the header block**, before sub_resources.
   Inserting before the first `[node ...]` (which is *after* them) produced
   `Parse Error: Unknown tag in file: ext_resource` and broke two scenes.
4. **Filling "enclosed background" baked opaque magenta into the art.** Scroll curls and
   corner cut-outs are genuine holes; treating every enclosed key-coloured region as
   interior is wrong for ornaments. That was the purple rim on the top bar's end cap.
5. **The generator anti-aliased its black contour against the key colour** and baked the
   result in as *fully opaque* dark purple — far enough from pure magenta to pass a
   distance test, so it survived every earlier pass. Fixed by excluding key-*hued* pixels
   from the de-fringe source so the true outline colour floods over them.
   Also: **LANCZOS rings at a hard cel outline**; un-premultiplying that overshoot at low
   alpha leaves a 1px coloured rim. Downscale these with BOX.

**Keying recipe for any future UI plate** (all six verified at 0 residual key pixels):
distance ramp 60→120 → largest-blob speck removal → **no hole filling** → de-fringe from a
core of `distance > 140` **and not key-hued** → premultiplied **BOX** downscale →
un-premultiply → second de-fringe in the downscaled image → zero out alpha below 8%.

**Also:** top-bar contents inset 84px each side so the gold coin no longer sits on the gold
end cap, and a **third** hot-path release print deleted (`"roll pressed"`, firing 5-15×/turn).

**Still stylebox (deliberate):** event/Skip/Leave/menu buttons and the reward rows. Those go
to the generic P7/P8 plates in a later pass — one art file each restyles ~30 buttons via the
three shared `shop_button_*.tres`, so it is worth doing only once the cel-plate look is
confirmed in play.

### 4d-bis. P7/P8 generic button plates (2026-08-16)

Picked the **Greek-key pair** (gold + teal) rather than the individually-prettiest of each
set: these two sit side by side on the same screens (Cancel/Confirm, Leave/Continue), so a
matching ornament family matters more than silhouette preference. One generation came back
off-prompt entirely (an isometric loot crate instead of a button) - discarded.

- **Teal = the workhorse secondary.** Rewrote the three SHARED `scenes/shop/shop_button_*.tres`
  in place as `StyleBoxTexture`. That restyles every consumer at once - event choices, Skip,
  Leave, shop services, pause menu, campfire, battle-over, load-run confirm: ~30 buttons,
  **zero scene edits**. Hover/pressed are the same plate with `modulate_color` 1.16 / 0.82,
  so all three states exist without extra art.
- **Gold = the one emphasised action per screen.** New `shop_button_gold_*.tres`; wired so
  far to "Continue to Act 2" only. Adding another primary is a 3-line repoint of that
  button's normal/hover/pressed.
- Both stored at **height 56** with 14px vertical margins: these buttons run 46-58px tall,
  and a 9-slice corner draws at *source* pixel size, so a taller source would overflow the
  shortest button.

**⚠️ Do not change the uid of a shared `.tres` when rewriting it.** `shop_button_*.tres` are
referenced by uid from ~30 scenes; giving the rewritten resource a fresh uid breaks every one
of those references. Rewrite the body, keep the header uid.

**⚠️ Shared ext_resource ids inside a scene.** In `battle_reward.tscn` the three shop
styleboxes were referenced by Back, Confirm AND Continue through the same ids - repointing
those ids to gold gilded all three. Add separate ids and repoint only the target node's block.

### 4d-ter. Top bar sizing + the NEAREST-filter trap (2026-08-16, Julien's feedback)

Two reports on the first painted build: *"the top bar doesn't look good, there are overlaps
with icons/labels; it's not tall enough"* and *"skip button looks good but a bit pixelated?
top bar too"*.

**Overlaps — the plate's usable band is smaller than the node.** The painted bar's TEAL BODY
occupies only y 14..137 of its 160px canvas: the decorated end caps are deliberately TALLER
than the bar itself. Drawn into an 80px node that leaves a ~61px band, so the 80px top-bar
icons spilled straight over the gold trim. Fix: bar 80 -> **96** tall (which is also the
"not tall enough" ask), contents inset to the band (y 8..82), icons 80 -> **64** and the map
button 90x70 -> 78x60 so they sit inside it with margin, and the relic row moved 82 -> 98 to
follow. **Rule for any future painted bar: measure the plate's interior band, not the canvas.**

**Pixelation — the project renders with NEAREST filtering.**
`project.godot: textures/canvas_textures/default_texture_filter=0` is *Nearest*. That is
invisible on the existing art (high-res painted sources, downscaled) but brutal on these
plates: thin 1-2px gold trim drawn at a non-integer scale (the 1280x720 canvas is stretched
to the window, so it essentially always is) gets its lines irregularly dropped or doubled -
which reads exactly as "pixelated".
Fixed by setting `texture_filter = 2` (Linear) on the nodes that draw a painted plate: the
top bar, End Turn, the dice tray, the tooltip, and — scripted across 28 scenes — every
button using the shared `shop_button_*` styleboxes (56 buttons).
**Deliberately NOT flipping the project default**, even though Linear is arguably correct for
a game with no pixel art: that would change the sampling of every asset in the game at once,
which is a look decision for Julien and not a side effect of a UI pass. If he ever wants it
globally, it is one line and these per-node overrides become redundant (harmless).

### 4e. ⚠️ VERDICT 2026-08-16: the painted CHROME is REJECTED — restart from the reference

Julien, on the shipped painted build: *"the buttons & top bar still look off"*, then after the
tone-down pass: *"no that's ugly."* **Do not iterate further on the current top bar or button
plates — the direction is wrong, not the tuning.**

**What the comparison actually shows.** Held next to STS2 screenshots, the problem is not art
quality, it is the DISTRIBUTION of decoration:

| | STS2 | Ours (rejected build) |
|---|---|---|
| Top bar | flat unornamented plate, 9.3% of screen height (see §4g — the "no plate" reading here was wrong) | painted plate, 13.3% of screen height |
| Decorative caps | none | 223 px = **17% of screen width** (halved to ~8% and still rejected) |
| Buttons | **zero ornament** — Skip is a plain pill | Greek keys on all ~30, ~20% of each button's width |
| Decorated elements | **one per screen** (the parchment banner) | everything |

STS2 rations decoration so the ART is loud and the chrome recedes. We made decoration the
default, so nothing recedes.

**~~The decisive probe (do not re-litigate this): STS2 SHIPS NO TOP-BAR ART.~~ ⚠️ THIS CLAIM
IS FALSE — DISPROVED 2026-08-16, see §4g.** It searched `images/packed/**`; the top bar
lives in `images/atlases/**` as an atlas region. STS2 **does** ship a top-bar plate. The
*ornament-distribution* diagnosis in the table above survives (their plate carries zero
ornament); only the "no plate" conclusion was wrong.

**Their button anatomy, from the files** (`sts2_ref/pck/images/packed/`):
- `combat_ui/end_turn_button.png` (512×256 RGBA) + `combat_ui/end_turn_button_glow.png` —
  one plate plus a SEPARATE glow layer, matching the audit's 3-layer anatomy (§1.2).
- `common_ui/event_button.png` (284×110) + `event_button_outline.png` + **`event_button_sdf.png`
  (512×512)** — they ship an **SDF** alongside the button art. Also `peek_button_sdf.png`.
  That is how their buttons stay crisp at any scale and get clean animated outlines, and it is
  the piece we have no equivalent of. **Read these before designing anything new.**
- `common_ui/ancient_event_option_button.png` + `_outline.png` — same pattern again:
  art + outline as separate layers.

**What survives from this pass (keep):** ROLL and End Turn plates read well in combat and were
not part of the complaint; the dice tray, tooltip and scout panel plates are quiet and fine;
the keying recipe (§4d) and the NEAREST-filter fix (§4d-ter) are both independent of the art
direction and stay.

**What to redo:** the top bar (probably by DELETING the plate and letting icons sit on the
world, STS2-style, possibly with a soft dark scrim for legibility over bright backgrounds),
and the ~30 shared buttons (plain plates, no end ornaments — the current teal/gold Greek-key
pair is the thing being rejected). `shop_button_normal/hover/pressed.tres` are the single
swap point for all 30; reverting them to StyleBoxFlat restores the old look instantly if
needed (git has the originals).

### 4g. ⚠️ CORRECTION 2026-08-16: STS2 **DOES** ship a top-bar plate — measured from the atlas

Julien, on a screenshot of STS2 combat: *"they do have a plate, check again! where hp gold etc
are."* He is right and §4e's headline probe was wrong. **Root cause of the bad probe: it
searched `images/packed/**` only.** The top bar is not there — it is an **AtlasTexture region**:
`scenes/ui/top_bar.tscn` → `BgImage` (first child) → `images/atlases/ui_atlas.sprites/top_bar/top_bar.tres`
→ `ui_atlas_0.png`, `region = Rect2(1, 1, 2046, 80)`. A filename keyword search over one image
subtree is weak evidence; **the scene files are the authority — read `scenes/ui/<thing>.tscn`
before concluding an asset does not exist.**

**What their bar actually is** (extracted and measured, not eyeballed):
- **2046×80 texture**, drawn by a TextureRect at 2560×100 (`expand_mode = 1`, scale 1.01), so
  it overhangs 1920 on both sides — the ragged edge never shows a seam at the screen edge.
  **100/1080 = 9.3% of screen height** (ours rejected: 13.3%; our pre-paint: 11.1%).
- **Flat dark slate `RGB(44, 68, 79)`**, essentially one tone, with very low-contrast darker
  crack/masonry lines. **Zero gold. Zero end caps. Zero ornament.**
- Its one characterful move: the **bottom edge is ragged/chipped**, like a broken stone slab,
  with a thin dark lip — not a straight rule and *not* a trim line.
- Text on it: `font_size 32`, **`outline_size 12` (37% of font size)**, outline colour a *dark
  version of the bar's own hue* `(0.098, 0.161, 0.188)` — not pure black — plus a soft shadow
  at offset (5,4). Their icons run 80px in a ~101px bar = **0.79 icon:bar ratio**.
- Potions/portrait sit on a *separate* small NinePatch (`top_bar_char_backdrop`, 90×85,
  32px margins) — a sub-plate inside the bar, which is where their only "frame" lives.

**So the §4e diagnosis survives, but its remedy was wrong.** The problem was never "we have a
plate and they don't" — it is that ours was *decorated* (gold caps at 17% of screen width, gold
rule) where theirs is a plain slab. The fix is a flat plate, not no plate.

### 4f. IN FLIGHT 2026-08-16 (evening) — the redo: top bar SHIPPED, buttons awaiting art

**Top bar — DONE, verified by render (per §4g, this is a flat PLATE, not a scrim).** `run.tscn`
was restored to pre-paint geometry (`git checkout HEAD`; the painted state was uncommitted)
then re-edited toward the measured reference: `Background` keeps a **StyleBoxFlat, bg
`Color(0.1725, 0.2667, 0.3098)` = their exact `RGB(44,68,79)`, NO border** (the old 3px gold
bottom rule is gone — that rule plus the painted caps were the whole complaint), soft shadow,
80px tall (11% — a touch over their 9.3%, kept because our canvas is 1280×720 so absolute
legibility matters more). The two gold VSeparator sticks are dissolved (`modulate` alpha 0,
keeping their 20px layout gaps) since STS2 has no separators. `BarItems` gets
`offset_left = 16`. **Icons 80 → 64** and map button 90×70 → 78×60, matching their measured
**0.79 icon:bar ratio** — at 80px in an 80px bar ours filled edge-to-edge, which is what read
as cramped. Text follows their hue-matched-outline trick: `topbar_label_settings.tres`
outline 2 → **6** with outline colour `(0.098, 0.161, 0.188)` + soft shadow; dice-count
`LabelSettings_cbb1u` outline 1 → 3.
⚠️ **An intermediate version of this pass used a soft gradient scrim and no plate** (built on
§4e's false premise). It is gone; do not reintroduce it.
Verified via **`debug_topbar_render.gd/.tscn`** (root, uncommitted): boots the REAL run.tscn in
a SubViewport using debug_dice_loadout's profile backup/restore recipe (booting run.tscn
overwrites the save checkpoint — byte-backup + restore of `run_save.save` AND `runs_started`
is mandatory). **Both §4e carry-over caveats are closed**: the deck "12" / green "!" badges sit
clean, and the ROLL plate was re-rendered post-Linear-filter (debug_dice_glow) — crisp.
**Remaining gap vs reference: our bottom edge is a straight line, theirs is chipped stone.**
That is one optional asset (prompt given to Julien 2026-08-16), stretchable horizontally like
theirs; the flat plate stands on its own until then.

**Buttons — DONE, plain plates installed.** Julien generated 19 candidates (2026-08-16 evening).
Only the 21:55-21:56 batch used the corrected prompt; the 18:18 batch still carried greek-key /
filigree end caps (i.e. the rejected direction) and was discarded wholesale — **13 of 19
candidates were ornamented and thrown away**, which is the prompt clause doing its job.
Picks: **teal_00** (10px corner radius — closest to the established `corner_radius = 8`, less
pill-like than teal_01's 13px) and **gold_00** (stronger cel bevel on the lower quarter,
matching the approved ROLL plate's darker amber half). Both are plain plates: flat body, one
thin gold rim, thick near-black contour, dead-flat middle, **no end ornament**.
⚠️ Note the generator gave a **thin gold rim, not the tone-on-tone teal rim Julien asked for** —
kept because it is restrained and matches the game's existing gold-border language (the
pre-paint flat buttons had a 2px gold border). Swappable if he dislikes it.
Processed with the §4d recipe (0 residual key pixels on all four finalists), cropped to bbox,
premultiplied BOX downscale to **height 56**, 9-slice margins measured from the alpha
silhouette: **teal 14, gold 11** (corner radius + slack; both < 46px, the shortest button, so
corners never overflow). All six `.tres` rewritten in place **keeping their uids** — zero scene
edits, ~30 buttons restyled at once. Hover/pressed remain the same plate at `modulate_color`
1.16 / 0.82.
**One real fix found by rendering:** "Continue to Act 2" was gold text on a gold plate and was
nearly illegible (pre-existing, not caused by the new art). Now cream `#FFF6E2` +
`outline_size 10` in dark brown — the §4.4 text rule, which had never actually been applied.

**Top bar chipped edge — DONE.** From the same batch, **slab_02** (finest, most irregular
chipping — the others scalloped like a valance). ⚠️ **Two cutting mistakes worth remembering:**
cropping from the solid body gave a strip that just *extended* the bar; cropping at the chip
line gave an all-dark strip that read as a **stripe** under the bar. Correct cut is
`y436..466`: a few rows of **body** colour, then the dark lip, then the chips — so the panel
flows into the edge with no seam. Measured colour handoff: body `(54,79,91)` → lip `(36,48,60)`
→ chips. The Panel's `bg_color` is set to the **art's own body colour** `(0.2118, 0.3098,
0.3569)` for exactly this reason (do not "correct" it back to STS2's `(44,68,79)` — it must
match our slab art, not theirs). Stored 2560×40, drawn at y78..96, `stretch_mode = 1`
(stretched horizontally like STS2's, whose irregular edge hides the distortion); RelicBar moved
82 → 98 to clear it. Solid bar mass stays 80px (11.1%, the pre-paint height Julien never
complained about); the chips are sparse and mostly transparent, so they add texture, not mass.

**Verified by render:** top bar over parchment (worst case), all 7 end/menu screens, an event
screen. Main menu is unaffected — its buttons use their own maroon styleboxes, not the shared
ones. **NOT PLAYTESTED.** Keying pipeline saved as `key_plate.py` in the session scratchpad —
it implements §4d verbatim and is the tool to reuse for any future plate.

**Round 2 — Julien's first playtest feedback (same evening), three fixes:**
1. **Bar edge "pixelated / too much" — root cause was a DOUBLE RESAMPLE, not the art.** The
   strip was stored 2560×40 but drawn at 1280×18: 2× minification with no mipmaps = aliasing
   (jaggies even under Linear filter), and the horizontal squash drew every chip at 0.66× its
   authored size = high-frequency noise. **Rule: an edge/trim strip must be stored at exactly
   its design-res draw size** (window upscale is magnification, which Linear handles fine —
   it's *minification* that aliases). Rebuilt 1280×18 via BOX prefilter, chips at **1.3×
   author scale** (a 50% horizontal crop of the band, stretched to full width) — 3 candidates
   composited over the real map render, calmest picked (slab_02 @1.3×; slab_03 read as torn
   paper, native-scale slab_02 still busy).
2. **Event buttons — delivered the tone-on-tone teal rim Julien originally picked** (round 1
   had kept the generator's gold rim with a "swappable" note; he wasn't a fan in context —
   a gold ring around every event choice). No regeneration needed: the gold rim pixels were
   **recolored programmatically** (gold mask by R>B+30 hue test, luminance mapped onto a
   teal ramp) in `iterate_v2.py`. Gold plate untouched.
3. **Tray ↔ tooltip plate swap (his idea, and it lands the doctrine):** the dice interface —
   the screen's centerpiece — now wears the corner-accent gold frame (`ui_panel_plate.png`,
   margins 21/20) and tooltip + scout panel get the quiet thin-rim plate (`ui_dice_tray.png`,
   margins 9/8). Pure `.tres` texture+margin exchange, uids kept, zero scene edits. The one
   decorated element per screen in combat is now the dice cluster.
All three verified by PIL composites over real renders (editor was open — no CLI import, no
engine render; **the CLI import must never run concurrently with an open editor**). Engine
render pass + reimport happen automatically next time the editor gets focus / next headless
run.

**Round 3 — second playtest feedback (same evening), three more:**
1. **Tray "a bit small for the dice"** — the corner-accent frame's thick painted border eats
   interior vs the old thin rim. Fix in CODE, not the scene (editor was open):
   `dice_interface.gd::_resize_panel_for_dice_inventory()` now also sets
   `dice_panel.offset_top = -8 / offset_bottom = 8` — the plate outgrows its control by 8px
   on both vertical sides, idempotent on every refresh. Zero .tscn edits.
2. **Tooltips: Julien prefers the OLD flat style** ("like when you hover dice in the dice
   interface" = `tooltip.tres`). One-file fix with zero scene edits:
   `scenes/ui/ui_panel_plate.tres` was **rewritten from StyleBoxTexture to a StyleBoxFlat
   clone of `tooltip.tres`** (same uid — a .tres can change type freely, consumers just get
   a StyleBox). Covers both consumers at once: tooltip.tscn AND the scout panel. The quiet
   plate art from round 2's swap lasted one look — **rule confirmed: tooltips want the flat
   navy/gold chrome, painted plates are for the world-side pieces.** `ui_dice_tray.png` is
   now orphaned on disk (nothing references it; the tray wears ui_panel_plate.png).
3. **Event buttons round 3: "simpler, not a fan of the gradient"** — the plate's lower
   bevel band read as a gradient at full event width. Flattened programmatically: interior
   = alpha silhouette **eroded 7px** (a luminance-threshold mask missed the dark bevel band
   at lum≈38 — geometric masks beat color masks for "everything inside the rim"), filled
   with the flat body tone (40,67,55). Contour + tone-on-tone rim + corner AA untouched.
   This is the **third confirmation of `feedback_flat_fills_preferred`** — flat fill, sharp
   edges, no tone steps on interactive chrome. The gold plate keeps its bevel (ROLL-plate
   language, approved, appears once per screen).

### 4i. SHIPPED 2026-08-17 — round 4: the de-ornament pass (End Turn, tray, top bar)

Julien's verdict after playing the round-3 state: **still too many ornaments** — the tray's
corner-accent frame, End Turn's gold trim + studs, and the bar's chipped edge all "too much";
directive = STS2 simplicity, with **fit-with-the-game as the primary selection criterion**
(he changed the dice textures for exactly this). New 31-candidate batch
(`Adobe_2026-08-17.zip`), picks made by MEASUREMENT against the game's own art anchors, not
by eye:

- **End Turn → #08, flat crimson.** Body RGB(128,21,21) = the closest of the batch to the
  red die's own body (dist 20.8 vs 27.7/33.7 for the other flats), 5px near-black contour.
  Baked at **388×124 (2× design)** with a bake-time 9-slice to reach the button's 3.13:1
  aspect — the End Turn stylebox is full-stretch (no texture margins), so corners must be
  pre-baked at the target aspect or they'd distort. Disabled state = same texture + grey
  `modulate_color` (wiring unchanged). The stone-slab candidates were the *prettiest art in
  the batch* and were rejected **at size**: irregular silhouette + rim + cracks = visual
  static at 194px — same failure class as the greek keys, "beautiful at 2K, noise in game".
- **Tray → #03's structure, recolored to the established navy.** The measurement fork: #02
  had the *exact* established navy body (dist **1.7** from the old tray tone) but a gold
  rim; #03 had the right rimless tone-on-tone structure but a bluer body (19,40,77).
  Structure is hard to change, color is one function: channel-scaled #03 to #1B2237, landed
  (26,34,55). Written to `ui_dice_tray.png` (**h=88 = 1× display height** for the runtime
  9-slice, margins 15) and `ui_dice_tray.tres` repointed back at it — the round-2
  tray↔tooltip naming cross is undone; the corner-accent `ui_panel_plate.png` is now
  referenced by nothing and archived in the rejected dir.
- **Top bar → chipped edge RETIRED.** `BottomEdge` node hidden (strip stays on disk as an
  instant fallback), bar = flat `#364F5B` + a **2px near-black bottom border on the
  StyleBoxFlat** — procedural, zero noise, and it gives the bar the near-black contour
  language every other element has (the one thing a bare slab lacked).

**New harness `debug_chrome_battle.gd/.tscn`** (root, uncommitted): boots the REAL
battle.tscn via the debug_double_endturn recipe and takes one frame with End Turn + tray +
ROLL over the combat backdrop — THE fit-judgment shot for any future chrome change.
⚠️ Trap hit while writing it: `battle.battle_stats` takes the fight's **`.tres`
(BattleStats)**, NOT its `.tscn` — assigning the PackedScene errors mid-`_ready`, the
coroutine dies before `quit()`, and the harness hangs forever.

**Round 4b — "give the bar personality" attempt: FAILED TWICE, reverted to flat.** Julien asked
for a bit of character up there. Tried, in order: (1) map the slab's **body** onto the whole
bar so it carries real stone cracks — at 100% one crack ran through the HP heart and read as
**a hair on the screen**, and at 55% it was the same hair, fainter. **Strength was never the
problem: a single thin isolated line stretched across 1280px cannot read as masonry.** STS2's
cracks work because they sit inside a broader stone field, not alone. (2) Blur every thin line
away and **amplify the broad tonal variation 2.6×** — Julien: *"some oil on it, transparency
issue?"*. It is not alpha; amplified low-frequency mottle reads as **blotches / an oil slick**.
Final state: `ui_top_bar_slab.png` is a **dead-flat 1280×80 `#364F5B` with the 2px near-black
contour line baked in** (verified in-engine: stddev **0.000**, median exactly (54,79,91) on an
icon-free band). The StyleBoxTexture wiring stays, so the bar's look is now a pure PNG swap.
**If character is ever wanted there it needs art with a crack NETWORK across the whole
surface** — not one line (hair) and not a tonal wash (oil).
⚠️ Both fixes this round were shipped as **PNG overwrites only** (no scene/.tres edits)
specifically because the editor AND a debug game were open — the safe move when Julien is
mid-playtest.

**Round 4c — tray #04 + dice-count font.** Tray swapped #03 → **#04** (softer rim); its 14px
corner radius fits inside the existing 15px 9-slice margin, so **no .tres edit was needed**.
⚠️ **Colour verdict reversed on sight:** #04 was first installed channel-recoloured to the
established navy `#1B2237` (one-variable-at-a-time reasoning), but Julien picked the
**native brighter blue RGB(20,45,88)** it was generated with — that is what ships. So the
tray is now deliberately a lighter, more saturated blue than the tooltip/panel navy; it reads
as its own object rather than another container, which is the point. The matched-navy version
is kept in the scratchpad if it is ever wanted back. Julien then noticed the dice
counts in a mockup looked better than the game's: the mockup used **LuckiestGuy**, the scene
used **MinionPro-Bold 13 + shadow**. Adopting LuckiestGuy is a consistency win, not just
taste — the **top bar's dice counts already use it** (LuckiestGuy 14, cream, outline 3), so
`LabelSettings_dsa2r` in `dice_interface.tscn` (shared by all 10 slot labels — one edit) now
matches the top bar exactly.

**The doctrine that survives this round** (write it into any future chrome selection):
candidates are judged at TRUE display size against measured anchors from the game's own art
(body hue vs the red die / the established navy; contour weight vs the dice outlines).
Prettiest-at-2K loses to fits-at-62px, every time.

### 4h. SHIPPED 2026-08-17 — the label pass (STS2's three tiers, on Belwe)

Font bake-off first: Podkova / Bitter / Alegreya downloaded (OFL) and rendered against Belwe
on the real plate at real sizes. **Two predictions died on contact with the render** — Bitter
was supposed to be the narrow safe pick and is the *widest* (58% of the 500px button, with
spacing so tight the inter-sentence gap nearly closes), and Podkova (my pick) didn't beat the
incumbent — it's the most readable but reads *polite* against thick cel outlines. Alegreya won
on width (51%). **Julien's call: Belwe** — already shipped, zero payload, most punch.
Eval fonts live in the session scratchpad, NOT the repo.

**Tier 2 — 67 buttons across 28 scenes** (`label_pass.py`, dry-run-by-default, backup of
`scenes/` taken first). Two node shapes, both found via the shared `shop_button_*.tres`
ExtResource **ids** (⚠️ NOT by filename — the styleboxes appear in node blocks only as
`ExtResource("id")`, which is why a filename-based survey returns 0 buttons): 14 plain
`Button`s with `text`, and **53 `RichTextLabel` children** of buttons (all the event options).
Applied: Belwe + cream `#FFF6E2` + `font_shadow_color` black 25% + shadow offset (3,2), and
outlines forced to 0 where any existed. **Gold text on teal plates is retired** (5 end-screen
buttons were gold-on-teal; with a gold *plate* now carrying primary emphasis, gold *text* was
redundant). Pause menu moves off CinzelDecorative, card_shop's Leave off the theme default.
BBCode keyword colors inside event labels are untouched — `default_color` only repaints the
uncoloured runs, so green heals / red costs survive by construction.

⚠️ **Event labels step 20 → 18px, and that is a fit fix, not taste.** Belwe runs **~13.6%
wider** than MinionPro; the longest label ("Dig out the coins left below…") would hit **510px
inside a 492px RichTextLabel** (measured off the render, not guessed), wrapping to a second
line that the 40px-tall label then clips. Belwe@18 and MinionPro@20 have an **identical 9px
x-height**, so the step is optically invisible. Verified after the fact: **all 53 labels fit,
worst case 94% of 492px.** Any future long event label must be re-measured against 492px.

**Tier 1 — hero verbs.** End Turn and ROLL both render at 26px (End Turn via `Theme_8evby`,
ROLL's Label via `main_theme`), so STS2's ~40% outline = **10**, coloured a dark version of
each plate's own hue (dark maroon `(0.157,0.047,0.047)` on End Turn, dark brown
`(0.165,0.090,0.031)` on ROLL) — never black — plus the (3,2) shadow. End Turn also gets
`shadow_outline_size = 10` so the shadow casts the whole lettermark, which is what makes
theirs read carved rather than drop-shadowed.

Verified by engine render: events (healing_spring = the worst-case label, patient_monk), all
7 end/menu screens, and the combat dice cluster. **NOT PLAYTESTED.**

---

## 5. Errata & housekeeping found during this work

- **Docs vs code drift** (code wins, older balance docs are stale): Canalize = threshold 12 /
  +3 Str (docs say 9); Parasite = threshold 15 / +2 (docs say +3/18); Greedy grants **+2**
  Muscle per 6 dice (docs say +1); Dicelord theft deals 10 (audit §10.2 says 14).
  `RunStats.STARTING_GOLD = 25` is dead (Global's 75 wins).
- Two misleading filenames: `tier_1_lurker.tscn` contains **Oculus**; `tier_1_oculus_goblin.tscn`
  contains **Lurker** (post-swap; known, but re-noting for anyone touching battles).
- The audit's remaining "next probes" that still matter: their card-play flight timings (WS4)
  and how a mid-fight Strength change updates an already-displayed intent (WS2 — needed before
  shipping DP's damage-stepping spike).
