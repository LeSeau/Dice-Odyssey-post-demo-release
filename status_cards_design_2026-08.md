# Status Cards — design plan (2026-08-21)

**Status: DESIGN ONLY, nothing implemented.** Julien's brief: 3 status cards (playable —
exhaust to clear + draw), injected by enemies **from act 1** like STS slimes, so hands get
partly fouled and bad rolls become "status clearers" (Pixie dice as the premier janitor).
This supersedes the earlier junk-card plan (`enemy_design_analysis_2026-08.md` §8.3 /
`enemy_balance_baseline_2026-08.md` §5), which specced **unplayable** junk (Sludge/Cinder/Hex)
with act-2 carriers first. Julien's playable version is strictly better for this game — see §2.
It also answers two open decision-sheet items from the balance baseline: §9.6 Hex semantics
option (c) "roll-malus junk" is now card C, and §9.7's "b.Kraken act-1 Sludge" is **dead**
(Julien: Krakens already have Ink, don't stack a second annoyance on them).

Everything below is checked against the code as of `9f9be9a` (post enemy-ramp pass), not
against the docs — the ramp pass **half-landed**: Bigger Satyr/Kraken/Goblin Muscle riders,
Hound double-hit 2×7, Maelstrom 13 are IN; Medusa Depleted swap, Hound Molten Roar, and the
Leviathan junk beat are NOT (the last one was explicitly gated on this system existing).

---

## 1. The three cards

All three: **new `Card.Type.STATUS`**, target SELF, `exhausts = true`, no rarity gem, never
in any draftable/shop pool, no "+" version, no upgrade. Fight-scoped for free (verified:
`player_handler.start_battle()` rebuilds `draw_pile` as a deep copy of `deck` — anything
injected mid-fight evaporates at fight end, and the persistent deck view / removal service
never see them).

| | Name (proposal) | Requirement | Card text | Extra rule |
|---|---|---|---|---|
| A | **Sludge** | none | "Draw 1 card. Exhaust." | — |
| B | **Tangle** | **Min 3** | "Draw 1 card. Exhaust." | — |
| C | **Cinder** | none | "While this is in your hand, your rolls give 1 less Power. Draw 1 card. Exhaust." | −1 Power per roll, per copy in hand, floor 0 |

Name alternates if these don't land: A "Dross"/"Muck", B "Mire"/"Grime", C "Ember"/"Lead Die".
Sludge and Cinder keep continuity with every prior doc; Cinder's carrier (Hound → act-2 Ember
Fiend) makes the name literal. B's entire identity is its ribbon — same text as A, but the
existing Min-3 badge + refusal system make it cost a real bank.

**Deliberate rules (the load-bearing ones):**

- **They reset Power when played**, like every non-Celestial card (their `apply_effects` emits
  `dice_roll_reset`). This is not optional — it's the whole economy, see §2.
- **They are NOT Celestial** — so the standard refusal ("no card before your first roll this
  turn") applies. You must *spend a roll* to earn the right to clean. Also consistent with the
  07-28 recognizability grid: nothing on them says Power/Refuel/Celestial, so they reset.
- **C uses the existing held-card system**, not a new mechanic: `Global.in_hand_roll_bonus()`
  already grants Dead Weight **+1** per roll while held — Cinder is its exact mirror at −1.
  Two known edits: `dice.gd:2293` `if held_bonus > 0` → `!= 0` + a `max(0, roll_value)` floor
  on that path, and an `in_hand_count(card_id)` sibling to `Global.in_hand()`. Note C taxes
  the **bank** only — natural-face triggers (Arcane 6s, Magma AoE damage, crack SFX) read the
  face before the tax and are untouched, which matches the wording ("rolls give less *Power*").
- **B whiffing on the red socket is allowed and correct**: only Celestials are barred from the
  socket; a socketed card whose requirement fails after the red roll plays, no-ops, and cycles
  to the **discard** (not exhaust — `should_exhaust()` is requirement-gated). So red-socketing
  a Tangle is a gamble: roll ≥3 clears it, roll <3 wastes the red die and keeps the Tangle.

## 2. The clearing economy (why this works structurally, not by tuning)

Verified chain: every Power reset also clears `roll_history`, and the refusal system blocks
non-Celestial plays while `roll_value <= 0 and roll_history.is_empty()`. Therefore:

> **Clearing one status card costs exactly one die (of your choice) + whatever bank that die
> carried.** Play Sludge → bank resets AND history empties → the next Sludge is refused until
> you roll *again*.

- A Pixie 1 is the perfect payment (1 Power sacrificed). An Elf turn has 4 cheap clears.
- Tangle needs a **bank ≥ 3**: one Blue mid-roll, one Pixie 3, or a chained 1+2. A **Golem**
  can't pay with its floor face (2) — it must chain two dice or borrow another type. Ricochet
  can reroll *down* into a cheap 3. Every loadout pays differently — that's the texture.
- The draw-1 makes clearing hand-neutral (act-1 gentle); the tax is the die + the tempo.
- Turn shape becomes a small ritual under intent pressure: "open with my worst die, flush,
  then build the real chain" vs "eat the clog and race damage".
- Known interactions, all favorable: **Reservoir** (`power_kept_on_reset`) keeps the bank
  above 0 through the reset → lets you flush several off one roll (a legit payoff for that
  card); **Kaleidoscope** lets you hop to a cheap type to pay clearing costs without breaking
  the chain; clearing plays feed **Momentum/Stampede/roll-count payoffs** (junk-heavy fights
  have a silver lining for those decks); **Cinder −1 can drop a roll to 0 → From Nothing
  triggers** (same rule as Weak-to-0, already documented behavior — bad cards literally fuel
  the low-roll archetype). Dead Weight (+1 held) and Cinder (−1 held) cancel — fine, both show.

## 3. Carriers — act 1 (the placement table)

Principles applied: severity ladder A→B→C across tiers (STS2's *evaporates → persists →
hurts*); **don't stack annoyances** (Julien's Kraken/Ink rule — extended: no junk on Weak
appliers, on fresh Wave-A rider carriers, or on one-clock elites); injection sits on an
**existing beat as an `icon2` rider** wherever possible; doses at STS2 scale (1-2/cast, ≤~3
per act-1 fight); vEHP ≈ 3-5 per card on the established scale.

| Carrier | Where it appears | Current kit (verified) | Change | Dose on-curve |
|---|---|---|---|---|
| **Venom Bloom** (plant) | t0 solo · t1 ×2 pairs · t2 pair — **the STS slime slot** | 4 → Muscle 3 → 4 → 4 → … — *despite the name it applies no venom whatsoever; its buff beat is its only texture* | Buff beat becomes **"Bloom": Muscle 3 + shed 1 Sludge** (icon2 rider). Injection IS the missing venom identity | turns 2/5/8 → 1-2 per fight |
| **Sigil Slug** | t1 solo | 10 → 10 → block 5 + Muscle 2 (its guard beat) | Guard beat also **leaves 1 Tangle** (slime trail hardens) | turns 3/6/9 → 1-2 |
| **Gargantua** (elite) | elite, act 1+2 | Effectively flat 8s (its 4th child is dead — no weight, no gate — so from turn 4 every turn runs through the anti-freeze fallback) + once Exposed 3. Greedy = its clock | **"Regurgitate" rider: every 3rd attack is 8 + spew 1 Sludge.** Fixes the fallback-driven flatness at the same time (the §8.4 wiring debt) and gives elites the STS2 junk-gimmick slot. **The interesting part: clearing costs rolls, and Greedy counts rolls** — the fight becomes "every mouthful I scrape off feeds the worm" | 2-3 per fight |
| **Lava Hound** (t2) | t2 solo | turn-0 2×6, then 50/50 {11, 2×7} + once Exposed 3. **Molten Roar never landed** — this builds it | **Molten Roar, ≤50% HP, once** (the prescribed HP-threshold event, WS2 pattern): +2 Str, block 5, **spits 2 Cinder**. C debuts here: solo fight, huge telegraph, bloodied trigger | 2, once |
| **Leviathan** (boss) | boss of both acts | 50/50 {18+Ink 3, 15+Weak 2} cap-2-consecutive · guard %4==2 · act-2 theft %3==1 | **Ink beat also injects 1 Sludge, cap 3/fight** — the audit's §4.1 prescription verbatim, previously gated on this system existing. The reference's "second boss clock" | up to 3 |

**Deliberately clean (do not add junk):** small **Satyrs** (Weak is their identity + they die
first), all **Krakens** (Ink — Julien's rule), **Skeleton** (calibration anchor), **Marauder**
(already the fastest clock), **Lurker** (Flux is the substitute), **Oculus** (Parasite),
**Goblin** (just got its ramp rider; Bog Hag Hex covers it in act 2), **Medusa** (pending
Depleted swap is her petrify slot), **Defender** (model enemy), **Lich/Dragon Priest**
(one-clock-per-fight — Absorb/Canalize).

Teaching ramp falls out for free: floors 1-3 meet Sludge on Venom Bloom (mildest card, the
enemy most likely to die before casting twice), floors 4-8 meet Tangle, floors 9-13 meet
Cinder, elite/boss raise the volume. **Fast kills dodge the tax entirely** — injection doubles
as soft anti-stall on exactly the fights that lacked a clock (VB solo was clock-light; the
audit's coverage math still holds since VB's Muscle loop stays).

### Act 2

Everything inherits automatically (same AIs; act-2 pools pull from t1/t2, so Thornheart/Wisp/
Ember Fiend/Devourer/Dicelord all arrive pre-wired). On top, keep from the old plan:

- **Bog Hag** (act-2 Goblin): the one act-2 special stays **Hex** as specced (cap 1 in deck)
  — its "play me first" lock is a different verb from these three, worth keeping distinct.
- **Ember Fiend** (act-2 Hound): optional act-gated escalation — double-hit beat injects
  1 Cinder (`current_act >= 2` gate, dicelord_dice_theft is the exact template).
- **Deepling Sludge: DROPPED** (it's the act-2 Kraken — the Ink rule kills it). Resolves
  baseline decision-sheet #7.

### Optional new enemy (only if you want a poster child — coverage doesn't need it)

**The Mimic** (t1, new fight, new art): ~30 HP. Loop: bite 7 → **"False Gift": inject 2
Fool's Gold (a Sludge reskin)** → guard 6+M1. On death **drops +35 gold**. A treasure-flavored
decision fight: the richest t1 room is also the one that fouls your deck hardest — kill-speed
is literally profit. (Alternative from the parked §4 list: revive **Satyr Shaman** as an
injector-support in a satyr pack — kill-order puzzle.) Recommend post-launch unless the pitch
lands hard; the five carriers above cover the arc without new art.

## 4. Injection mechanics (proposed)

- **Destination: draw pile, random index** (recommended — with 12-16-card fight decks, discard
  injection is nearly the same thing one cycle later; random-in-draw reads "it's coming" with
  the VFX and can surface immediately). One rule everywhere. Alternatives: top-of-pile
  (guaranteed next draw — could be the boss variant) or discard (gentlest).
- **`.duplicate()` is mandatory** on each injected card (shared-resource `instance_id`
  collision — same trap Flywheel documents).
- **VFX exists**: retarget `battle_ui._on_deck_reshuffled`'s mini card-back bezier flight —
  `from` becomes the enemy sprite, `to` the draw-pile button; punch + SFX transfer unchanged.
- **Intent honesty**: injecting beats get an `icon2` rider. Stopgap glyph = the debuff skull
  + a rider tooltip line ("It will also foul your draw pile"); real fix = one new card-glyph
  intent icon in the current family style (single Firefly ask). ⚠️ Leviathan's Ink beat
  already uses its icon2 slot (skull) — either the tooltip covers both, or IntentUI grows an
  icon3, or the Sludge moves to his guard beat. Decision-sheet item.
- New tooltip keyword **"Status"** on all three cards ("A worthless card. Play it after a roll
  to exhaust it and draw a fresh card. It vanishes after this fight." — must be measured
  against the 3-line tooltip cap).

## 5. Implementation map (for when we build — batches, XS-S each)

**S1 — chassis, no enemies**: `Card.Type.STATUS` + ashen-gray stylebox family (⚠️ the full
19-touchpoint checklist was mapped: both duplicated card UIs at `card_ui.gd:753-768` /
`card_menu_ui.gd:211-233` + hover branches + drag state, the `else:` reset branch for reused
nodes, tooltip stacks ×2, rarity-gem hide for STATUS, `_requirement_bypassed` stays
BLESSING-scoped, `play()`'s non-ATTACK particle burst check, socket-panel styling); the 3
cards (~10-line scripts: draw 1 via `Events.draw_card`, emit `dice_roll_reset`); the
`in_hand_count` helper + the `held_bonus != 0` fix + floor; injection primitive
(`draw_pile.cards.insert(randi_range(0, size), card.duplicate())` + an `Events` signal) +
retargeted mini-card VFX. Harness: injection lands fight-scoped, pre-roll refusal, clear →
exhaust pile + reset + draw, Tangle gate at bank 2 vs 3, Cinder −1/−2 math with floor-0 and a
negative control, red-socket clear + whiff-cycles-to-discard, end-of-turn junk survives via
discard→reshuffle, next battle starts clean.

**S2 — early carriers**: Venom Bloom rider + Sigil Slug rider + icon2 assertions
(cadence-promotion-style harness) → **playtest** (the feel gate: is one Sludge annoying-fun
or just annoying?).

**S3 — heavy carriers**: Gargantua Regurgitate (+ its wiring fix), Hound Molten Roar (+2 Str,
block 5, 2 Cinder — also note the half-landed dial: his turn-0 opener is still 2×6 while the
mid-fight double is 2×7), Leviathan Ink rider cap 3.

**S4 — act 2**: doses via act gates, Bog Hag Hex (existing plan), optional Mimic.

**Art asks (Julien)**: 3 card arts via the card-art prompt guide (subjects from the EFFECT:
a die drowning in dull ooze / a die bound in thorny snarls / a scorched die smoking like a
coal); 1 intent card-glyph in the intent-icon family.

**Ledger note**: junk prices at ~3-5 vEHP each → a typical run eats ~4-8 across act 1
(~−4-8 effective HP), on top of a ledger already at target (−92). Hound's Roar was already
priced in the −27 T2 line, and VB/Slug/Gargantua injections partly *replace* planned texture
(VB's pending §8 Weak rider dies — Weak was redundant with satyrs anyway). Net drift is small;
re-read the ledger after the S2 playtest, and if act 1 tightens too much the first lever is
dose (VB 1/cycle → 1/fight), never card harshness.

## 6. Decision sheet (Julien)

1. **Reset-on-play** — sign off that all three reset Power (the §2 economy depends on it).
2. **Names** — Sludge / Tangle / Cinder?
3. **Injection destination** — random-in-draw-pile everywhere (rec), vs top-of-pile for
   boss, vs discard.
4. **Venom Bloom = primary act-1 carrier**, replacing its pending §8 Weak-rider texture? (rec
   yes — it currently has no venom identity at all.)
5. **Gargantua Regurgitate** — rider form "8 + spew 1" (DPT flat, tax ≈ the endorsed mild
   buff) vs dedicated spew turn (2 Sludge, skips the attack)?
6. **Hound Roar dose** — 2 Cinder (rec) or 1? Keep the +2 Str & block 5 from the audit spec?
7. **Leviathan** — Ink-beat rider cap 3/fight as audited; and the icon2 collision: tooltip
   covers both / icon3 / move Sludge to the guard beat?
8. **Red-socket clearing** stays legal (rec yes — zero code, real gamble)?
9. **Cinder stacking** — −1 per copy, uncapped count but ≤2 ever injected per fight (rec)?
10. **Mimic** — build now / post-launch / never?
11. **Act 2** — Hex stays the one special (cap 1)? Ember Fiend act-gated +1 Cinder? Deepling
    dropped (Kraken rule) — sign off.
12. Cosmetic: per-source reskins of Sludge later ("Spore"/"Fool's Gold" clone .tres, art only)?

## 7. Found in passing (not this feature's scope)

- `battles/tier_1_lurker.tscn` actually contains the **Oculus** (44 HP + Parasite) and
  `tier_1_oculus_goblin.tscn` contains the **Lurker** — swapped filenames, trap for future
  sessions.
- Hound's turn-0 opener still deals 2×6 while the mid-fight double attack was dialed to 2×7 —
  if N4 meant both, the opener was missed.
- Gargantua's 4th AI child is unreachable (no weight, no gate) and the whole post-turn-3 loop
  runs on the anti-freeze fallback — §3's Regurgitate proposal would retire this quirk.
