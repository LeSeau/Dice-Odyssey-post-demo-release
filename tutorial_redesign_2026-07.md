# Tutorial Redesign — Detailed Plan (2026-07-12)

Design + implementation plan for rebuilding the combat tutorial. **Nothing here is implemented yet** — this doc is the handoff spec for an implementation session (Sonnet). Read CLAUDE.md first for codebase conventions and pitfalls; this doc references them where relevant.

**Revised same day after Julien's review — three corrections baked in below:** (1) Recombobulate DOES reset Power (verified: `recombobulate.gd:15` emits `dice_roll_reset`; the refund count is read at :4 before the reset, so the refuel is correct) — T2 now rolls a forced 3 after the refuel for the Low Blow moment; (2) the "Support" keyword is dropped as a player-facing term and no-reset cards currently have no visual differentiator — the tutorial teaches the *behavior* via Reinforce, never the word (see §9.3); (3) **All In was a test insert and is leaving the starter deck** — the finale is now an exact-lethal Strike off a scouted, guaranteed 6.

**Ultimate goal (Julien's brief):** retain players. Make them understand fast that this game gives you *tools to manipulate odds and mitigate bad RNG* — that there is an interesting, satisfying gameplay to discover. Every design decision below serves that.

---

## 1. Current state audit (verified 2026-07-12)

### How the current tutorial works
- **15 hardcoded panels** (`Tutorial1`–`Tutorial15`) + `WarningPowerReset` popup + `SkipTutorialButton`, all living in `battle.tscn` under `CanvasLayer/Tutorial` (lines ~692–1383). Fixed pixel offsets, static arrow `TextureRect`s (`tutorial_arrow.png` / `tutorial_arrow_down.png`).
- **Sequencing** via `Events.tutorial_step_requested.emit(N)` + a web of one-shot `Global.tutorial_*` flags spread across **5 files**:
  - `battle.gd:87-92, 697-809` — panel show/hide dispatch (magic step ints, panel N hides → N+1 shows)
  - `dice.gd:462-468` — forced roll application; `dice.gd:859-870` — step progression keyed on *which value was forced* (including a magic "forced 2 becomes forced 1" chaining hack)
  - `card.gd:155-166` — 4 flag checks in `play()`
  - `dice_interface.gd:132-231` — dice-select steps + the power-reset warning
  - `player_handler.gd:32-44, 52-82` — forced opening hands for turns 1 & 2
- **Tutorial fight** = `battles/tier_0_crab.tres` forced in `run.gd:385-391` (Skeleton, 26 HP — shared with the real tier-0 pool, so balance passes silently retune the tutorial).
- **Dice Bag relic is disabled during tutorial** (`relics/mana_potion.gd`: `if Global.tutorial_on == false`) → tutorial loadout is exactly **2 Blue + 1 Red**.
- Current flow: welcome → roll Blue (forced 6) → power explanation → play Block → intent panel → roll Blue (forced 3) → Low Blow → select Red → socket Strike → roll Red (forced 5) → End Turn → enemy hits 6 → turn 2: select Blue → roll 2 Blues (forced 2, 1) → Recombobulate → "you're on your own".

### Confirmed problems
1. **Stale forced hand (real bug):** `player_handler.gd:34` forces `warrior_axe_attack1.tres` into the turn-1 hand, but that file is **no longer in the starter deck** (deck now has attack2/3/4 + All In + Scout 3). `remove_card()` silently no-ops, `push_front` then *adds* it → the tutorial fight plays with a 13th card.
2. **Zero gating:** `_any_tutorial_panel_visible()` (`battle.gd:805`) is dead code — never called. The player can roll the Red die early, play the wrong card, or End Turn mid-script and desync the whole tutorial.
3. **Aiming is never taught**, and it's needed *twice*: Low Blow (step 7) and the red-socketed Strike (step 10 — `card_ui.gd:497` forces AIMING state after the red roll). A single-enemy card released without a target silently bounces back to AIMING (`card_released_state.gd:12-16`) — to a new player this reads as "the game ate my card".
4. **Power reset on card play is never taught.** Panel 3 says cards "use" your Power; nothing says playing a card sets it to 0, nothing contrasts the rare no-reset cards (Reinforce, Scout 3). The only reset lesson is the *type-switch* warning popup — a different mechanic.
5. **Stacking same-type rolls is taught LAST** (step 13, "one last thing") — it's the core resource loop and should be in the first 30 seconds.
6. **Scout 3 is in the starter deck now and completely unexplained.** Celestial cards likewise (Scout 3 *is* Celestial: `can_play_without_dice = true`). (All In is in the deck today too, but it's a test insert on its way out — §1 inventory.)
7. **Requirements (Min/Max/Exact ribbons) are never explained** — Low Blow's Max 3 is load-bearing in the current script and the text just says "works great with lower rolls".
8. Only panel 1 dims the screen; later panels float over a fully interactive battle.
9. `scenes/tutorial_overlay.tscn` is an unfinished skeleton (Dimmer + HighlightBox + Arrow + TextPanel + NextButton) — never wired to anything. Good bones for the new overlay.

### Starter deck & mechanics inventory (verified against .tres/.gd files)
- **Deck (12 today → 11 for the tutorial):** 3× Strike (`warrior_axe_attack2/3/4`, "Deal X damage", single-enemy), 4× Block (`warrior_block1-4`, "Block X", self), Low Blow ("Deal X3 damage", **Max 3** ribbon, gate is `Global.roll_value < 4` in `low_blow.gd:7` — silent no-op above), Reinforce ("Add 2 to your Power", **no reset** — `reinforce.gd` never emits `dice_roll_reset`, Max 12), Recombobulate ("Refuel your active Dice", refunds `roll_history.size()` dice of active type **and resets Power** — `recombobulate.gd:15` emits `dice_roll_reset`; the refund count is read at :4 before the reset, so the refuel is correct), **Scout 3** (`card_scout3_no_exhaust`, **Celestial**, no reset, emits `scout_effect(3)`). **All In is a test insert and will NOT be in the starter deck** (Julien, 2026-07-12) — remove it from `warrior_starting_deck.tres` as part of this implementation if he hasn't already (1-line array edit); the tutorial must not reference it.
- **"Support" is a dropped keyword.** `Card.Rarity.SUPPORT` still exists in code (there's even a gold title-color mapping in `card.gd:11`), but Julien has dropped it as a player-facing term, and no-reset cards currently have **no visual differentiator**. Whether a card resets Power is decided per-script (each card's `apply_effects` emits `dice_roll_reset` or doesn't — the rarity field guarantees nothing, see Recombobulate above). The tutorial therefore teaches the *behavior* (Reinforce: "watch the number go UP, not back to zero"), never the word "Support" — see §9.3 for the open differentiator decision. **Celestial** (blue frame) = playable with no Power and no dice; on Red it plays directly without socketing (`card_released_state.gd:31`).
- **Scout:** `battle.gd::_on_scout_effect` picks the shown faces **randomly** (`faces[randi() % faces.size()]`, line ~345) → needs a forcing hook. Click → `Global.next_guaranteed_roll` set immediately; `Events.next_roll_determined` fires when the flying die lands. Guarantee is wiped by a dice-type switch (sentinel −1 system). The full open/reveal/pick/close animation shipped 2026-07-11.
- **Red socket flow:** select red → drop card on socket (`Events.card_charged`) → roll → if card is single-enemy, AIMING is forced post-roll; self-target cards auto-resolve.

---

## 2. Design principles

1. **Do-first.** Every step should demand a player action; reading-only panels are capped at 4 (welcome, intent, reset-spotlight, victory). The current tutorial front-loads reading; the new one front-loads rolling.
2. **One flagship lesson per turn.** T1 = the machine (roll → stack → spend → aim → reset). T2 = bad luck is a puzzle you have tools for. T3 = you can *choose* your luck. This is the engagement arc: competence → adversity answered → power fantasy.
3. **Every "bad" moment is answered within one step.** Two 1s → Recombobulate. A third 1 → Low Blow turns it into 9 damage. Never let the player sit in "RNG screwed me" without immediately handing them the counter-tool — that's the retention thesis of the whole game.
4. **Deterministic script, gated inputs.** Forced rolls, forced hands, forced scout faces, and a per-step input allowlist. No possible desync. Skip always available.
5. **A finale that proves the thesis.** The Skeleton ends at exactly 6 HP; the player needs exactly a 6 — and instead of praying for it, they Scout it, choose it, and cash it in through the Red socket. "You needed a 6, so you took a 6" is the whole game in one beat, and it uses the flashiest new system (the scout pick-your-future flight) as the closing image.
6. **The fight is flawless by design** (player takes 0 damage if they follow the script). Feeling powerful > feeling punished, in minute one. (Open question §9 if Julien prefers one scratch for honesty.)

Estimated duration: **3–4 minutes**, 3 player turns, ~19 interactions.

---

## 3. The scenario — turn by turn

Tutorial fight: **dedicated battle** (see §6.D) — Skeleton, **22 HP** (see damage accounting §4), attacks 6 every enemy turn.

Legend per step: **Text** = final copy (BBCode, conventions: `[color=gold]` keywords/Dice, `[color=purple]` Cards, `[color=red]` Power, dice-type colors from `DicePalette` accents, Celestial callout in the celestial-frame blue). **UI** = affordances (components in §5). **Gate** = what's interactive. **Done when** = completion signal (existing `Events` signals unless noted).

### TURN 1 — "Learn the machine"
Forced hand: **Strike, Strike, Block, Block, Block**. Forced roll queue: **[4, 3, 6]**.

**T1.1 — Welcome** *(center panel, full dimmer, button)*
> **Welcome to Dice Odyssey!**
> Down here, luck isn't something that happens to you — it's something you [color=gold]use[/color]. Combat runs on two things: [color=gold]Dice[/color] and [color=purple]Cards[/color].
> *(button: "Let's roll")*
- UI: full-screen dim + centered panel. Gate: button only. Done: button pressed.

**T1.2 — First roll**
> This is a [color=blue]Blue Dice[/color]. Click [color=gold]ROLL[/color]!
- UI: arrow + pulse frame on the ROLL button; soft dim on everything else. Gate: roll only. Done: `dice_rolled` (forced 4).

**T1.3 — Stacking (the core loop, first 30 seconds)**
> You rolled a 4 — that's your [color=red]Power[/color] now. And here's the trick: same-type Dice [color=gold]STACK[/color]. Roll your second [color=blue]Blue[/color]!
- UI: spotlight cutout on the Power number for ~1s as the text appears, then arrow back on ROLL. Gate: roll only. Done: `dice_rolled` (forced 3 → Power 7).

**T1.4 — Spend it: AIM at the enemy** *(the pointing lesson)*
> 7 [color=red]Power[/color] banked! Now spend it: drag [color=purple]Strike[/color] up and [color=gold]point it AT the Skeleton[/color] — release on him, not on empty air.
- UI: pulse on one Strike in hand (others dimmed); **enemy outline force-enabled** + bouncing arrow above the Skeleton. While the card is in AIMING state, keep the enemy highlight hot. **Fallback nudge:** if the card sits in AIMING >4s with no target hovered, wiggle the enemy arrow + flash the outline (this is exactly the "release into the void" confusion moment).
- Gate: only Strike playable; no rolls; no End Turn. Done: `card_played` (Strike) → 7 dmg, Skeleton 22→15.

**T1.5 — The reset lesson** *(THE new concept Julien wants; auto-triggers the instant the reset lands)*
> See that? Your [color=red]Power[/color] crashed back to [color=red]0[/color]. Playing a card spends [color=gold]ALL of it[/color] — roll first, build it up, *then* strike. That's the heart of every turn.
> *(button: "Got it")*
- UI: dim + spotlight cutout on the Power number (which now reads 0). Optional juice: brief ghost of the old "7" fading above the 0 (stretch goal). Gate: button only. Done: button.

**T1.6 — Enemy intent** *(button panel, short)*
> That icon above the Skeleton is his [color=gold]next move[/color]: 6 damage, landing at the end of your turn. Let's do something about it.
- UI: arrow at the IntentUI icon + spotlight cutout on it. Gate: button only ("Continue"). Done: button.

**T1.7 — Red dice: select**
> Your [color=blue]Blue Dice[/color] are spent — but the [color=red]Red Dice[/color] is ready. Red plays backwards: [color=gold]card first, roll after[/color]. Click it.
- UI: arrow + pulse on the red die in the dice interface. Gate: only red die clickable; nothing else. Done: `active_dice_changed("red")`. (Power is 0 here, so the type-switch warning can't fire — intentional, see §7.)

**T1.8 — Red dice: socket**
> Drop your [color=purple]Block[/color] onto the Red Dice. Whatever it rolls becomes your armor.
- UI: pulse on one Block; arrow at the socket zone on the big die. Gate: only Block draggable. Done: `card_charged`.

**T1.9 — Red dice: roll**
> Now [color=gold]ROLL[/color] — and pray. (Kidding. Mostly.)
- Gate: roll only. Done: `dice_rolled` (forced 6 → Block auto-resolves since it's self-target → 6 Block). *Note: Block, not Strike, is deliberately the first socketed card — self-target means the red intro teaches ONLY the card-first timing, without stacking the aim-after-roll quirk on top (the current tutorial's step 10 mixes both with zero text). Aim-after-roll gets its moment at T3.6, when aiming is already learned.*

**T1.10 — End turn**
> A 6! The Skeleton's hit is fully covered. [color=gold]End your turn[/color] — all your Dice come back every turn.
- UI: gold pulse on End Turn (reuse `battle_ui.gd::_update_end_turn_highlight` styleboxes). Gate: End Turn only. On click: hide overlay during the enemy turn. Enemy attacks 6 → fully blocked. Done: `player_turn_started`.

### TURN 2 — "Bad luck is a puzzle"
Forced hand: **Low Blow, Recombobulate, Reinforce, Strike, Block**. Forced roll queue: **[1, 1, 3, 4]**. Enemy intent: 6 again.

**T2.1 — Roll**
> Fresh turn, fresh [color=gold]Dice[/color]. Roll a [color=blue]Blue[/color]!
- Gate: roll only. Done: `dice_rolled` (forced 1).

**T2.2 — Roll again** *(comedy beat begins)*
> A 1. Charming. Try the other one.
- Gate: roll only. Done: `dice_rolled` (forced 1 → Power 2).

**T2.3 — Recombobulate: the bad-luck undo**
> TWO 1s?! Okay, breathe. Bad luck can be [color=gold]undone[/color]: [color=purple]Recombobulate[/color] refuels every Dice you rolled this turn. It resets your Power too — but be honest, you won't miss these 2. Play it!
- UI: pulse on Recombobulate. Gate: only Recombobulate. Done: `card_played` → 2 Blues refunded, Power 2 → 0. *(The reset here is the norm, not a surprise — it quietly reinforces T1.5's "playing a card spends everything" lesson before the exception shows up at T2.7.)*

**T2.4 — Re-roll**
> Fresh Dice, clean slate. Roll!
- Gate: roll only. Done: `dice_rolled` (forced 3 → Power 3).

**T2.5 — Low Blow: requirements turn trash into gold** *(the requirements lesson)*
> A 3. Not glorious... unless you're holding [color=purple]Low Blow[/color]. That [color=gold]MAX 3[/color] ribbon is a [color=gold]Requirement[/color]: this card only works while your Power is 3 or less — and right now it deals 3 × 3 = [color=gold]9 damage[/color]. Low rolls have their own weapons. Aim it at the Skeleton!
> *(small sub-line, lighter color:)* Every ribbon works like this — Min, Max, Even, Odd... it tells you what Power a card wants.
- UI: pulse on Low Blow + **arrow pointing at its requirement ribbon specifically**; enemy outline + arrow again (aim rep #2). Stretch: zoomed CardMenuUI copy next to the text with the ribbon circled (pattern: `card_rewards.gd` ExampleCard). Gate: only Low Blow. Done: `card_played` → 9 dmg, Skeleton 15→6, Power resets to 0.

**T2.6 — Defend again**
> He's winding up another 6-damage hit. One [color=blue]Blue[/color] left — roll it.
- UI: arrow at intent icon for 1s, then ROLL. Gate: roll only. Done: `dice_rolled` (forced 4).

**T2.7 — Reinforce: the exception to the reset** *(the no-reset lesson, taught by behavior — "Support" is not a player-facing keyword anymore, see §9.3)*
> 4 Power. Two short of that 6-damage hit... [color=purple]Reinforce[/color]: +2 Power. And watch the number closely — it goes [color=gold]UP[/color], not back to zero. A precious few cards spare your Power like that.
- UI: pulse on Reinforce; spotlight the Power number as it ticks 4→6. Gate: only Reinforce. Done: `card_played` → Power 6.

**T2.8 — Block it all**
> 6 [color=red]Power[/color] — exactly enough. [color=purple]Block[/color] it all.
- Gate: only Block. Done: `card_played` → 6 Block.

**T2.9 — End turn**
> Sealed tight. [color=gold]End your turn[/color].
- Gate: End Turn only. Enemy attacks 6 → fully blocked. Done: `player_turn_started`.
- *(The Red die sits unused this turn — the script never mentions it, and gating keeps it locked. Deliberate: T2 is about the Blue toolkit; red returns as the star of T3.)*

### TURN 3 — "Bend fate" (Scout + Celestial + the exact kill)
Forced hand: **Scout 3, Strike**, + 3 don't-care cards (gated anyway). Skeleton at exactly **6 HP** (guaranteed — every point of prior damage is forced, §4). Forced scout faces: **[2, 6, 4]** (see §6.B). No forced roll this turn: the roll is guaranteed by the scout pick itself.
*(The two Blue Dice sit unused in T3, mirroring the Red sitting out T2 — the script never points at them and gating keeps them locked. T3 is the Red die's arc.)*

**T3.1 — Select red first**
> Last stretch — he's barely standing. Start by picking up your [color=red]Red Dice[/color].
- UI: arrow + pulse on red die. Gate: red die only. Done: `active_dice_changed("red")`.
- *Why first: Scout previews and guarantees the roll of the ACTIVE die, and a type switch wipes the guarantee (sentinel −1 system). Red must be active before scouting.*

**T3.2 — Celestial cards: free plays**
> Notice [color=purple]Scout 3[/color] glowing while everything else is dark? That's a [color=#5cb3ff]Celestial[/color] card — the blue frame means it's [color=gold]free[/color]: no Power, no Dice needed. Play it [color=gold]before[/color] you roll anything.
- UI: pulse on Scout 3 (it already glows HOT by design — lean on that); other cards dimmed by gating. Match the callout color to the actual celestial frame blue. Gate: only Scout 3. Done: `scout_effect` fired.

**T3.3 — Choose your future** *(the fantasy centerpiece)*
> The Skeleton has [color=gold]6 HP[/color]. A gambler would pray for a 6. You're not a gambler — the die is showing you [color=gold]three possible futures[/color], and you get to [color=gold]choose[/color]. Take the 6.
- UI: the new scout open/reveal animation plays as normal; once faces are revealed, pulse the 6; the other two faces get `mouse_filter = IGNORE` + slight dim **during this step only** (reuse the flicker-gating pattern already in the scout code). Text panel positioned beside the scout panel, not over it. Gate: scout face #2 (the 6) only; Exit button disabled. Done: `next_roll_determined` (fires on the flying die's landing).
- *The "6 HP" in the copy is safe because §4's numbers are all forced — if any forced roll is retuned, this line must move with it.*

**T3.4 — Socket the kill**
> Your next roll is a [color=gold]guaranteed 6[/color] — exactly what you need. Drop [color=purple]Strike[/color] onto the Red Dice.
- UI: pulse on Strike; arrow at the socket. Gate: only Strike draggable. Done: `card_charged`.

**T3.5 — Roll**
> [color=gold]ROLL.[/color]
- Gate: roll only. Done: `dice_rolled` (guaranteed 6 consumed → Power 6; Strike is single-enemy so AIMING is forced automatically after the red roll).

**T3.6 — Finish him** *(aim-after-red-roll, the quirk from §1.3, now taught in context)*
> Point at the Skeleton. [color=gold]Finish him.[/color]
- Trigger: `card_aim_started` right after the red roll. UI: enemy outline + arrow (aim rep #3). Gate: aiming only. Done: `card_played` → Strike deals exactly 6 → 6 HP → **dead, exact kill**.
- Safety: the director's *victory* step should ride the existing battle-won flow (the 1s auto-advance in `battle_over_panel.gd`), not `card_played` alone — and if the Skeleton somehow survives (impossible per §4 unless a damage modifier sneaks in), drop all gates and let the player finish freely rather than soft-locking.

**T3.7 — Victory** *(short, sells the run)*
> Flawless. You needed [color=gold]exactly a 6[/color] — so you took exactly a 6. That's this game: you don't [color=gold]hope[/color] for luck. You stack it, reroll it, cash in your worst rolls, and when it matters most, you [color=gold]choose[/color] it. Out there you'll find stranger Dice, wilder Cards, and enemies who cheat harder than you do. [color=gold]Hover anything[/color] to learn more.
> *(button: "Begin the run")*
- UI: center panel over the (1s-delayed) victory flow. On button: tutorial fully ends (`tutorial_on = false`), normal reward screen continues.

---

## 4. Damage & HP accounting (the tuning contract)

| Beat | Rolls | Power at spend | Card | Damage/Block | Skeleton HP after |
|---|---|---|---|---|---|
| T1 Strike | 4 + 3 | 7 | Strike | 7 dmg | 22 → 15 |
| T1 Block | red 6 | 6 | Block | 6 blk vs 6 atk | — (player 66) |
| T2 Low Blow | 1 + 1 (lost to Recombobulate's reset), then 3 | 3 | Low Blow | 3×3 = 9 dmg | 15 → 6 |
| T2 Block | 4, Reinforce +2 | 6 | Block | 6 blk vs 6 atk | — |
| T3 Strike | scouted red 6 | 6 | Strike | 6 dmg — **exact kill** | 6 → dead |

**Constraints that must hold if any number is retuned:**
- Skeleton tutorial HP = (T1 Strike dmg) + (T2 Low Blow dmg) + (scouted face) = 7 + 9 + 6 = **22**. The finale is an EXACT kill by design ("you needed exactly a 6") — deterministic because the tutorial has no damage modifiers (no statuses, no damage relics; Dice Bag is disabled). If drama loses to paranoia, HP 21 kills with 1 to spare — but then T3.3/T3.7's "exactly" framing must be dropped.
- Recombobulate resets Power to 0 AND clears `roll_history` (refund count is read first, `recombobulate.gd:4` — the refuel stays correct). T2's pre-Low-Blow Power therefore comes entirely from the single forced 3, and must stay **≤ 3** (Low Blow hard-gates at `roll_value < 4`).
- T2 Reinforce beat: roll + 2 must equal the enemy attack (4 + 2 = 6) for the "exactly enough" line.
- Scout pick gated to the 6 is **structurally required** with the Strike finale: a picked 2 or 4 cannot kill (see §9.1).
- Enemy attack = 6 flat, both enemy turns.

Player ends at 66/66. Total scripted actions: 19. Reading-only stops: 4.

---

## 5. UI affordance kit (build once, reuse per step)

One new scene (finish/replace the abandoned `scenes/tutorial_overlay.tscn` skeleton — Dimmer, HighlightBox, Arrow, TextPanel, NextButton already stubbed there) on a high CanvasLayer (`layer = 20+`, above BattleUI; check existing layer numbers in battle.tscn). Components:

1. **Dimmer with spotlight cutout** — full-screen dark overlay with a rect/rounded hole over the focus target. Implementation: either a shader ColorRect (uniform hole rect, animatable) or 4 plain ColorRects framing the hole (simpler, no shader). **`mouse_filter = IGNORE` on ALL overlay visuals** — input restriction is the gating system's job (§6.C), never the overlay's. Two intensities: full dim (welcome/victory/reset-lesson) and soft dim (action steps).
2. **Pointer arrow** — reuse `tutorial_arrow.png`/`tutorial_arrow_down.png`, add a 0.4s bob tween. Positioned each step from the target node's `get_global_rect()` (recompute on step enter; targets don't move mid-step).
3. **Pulse frame** — gold border panel over the target rect, slow alpha/scale pulse. Reuse the End Turn highlight styleboxes / map HoverGlow pattern.
4. **Enemy target highlight** — expose a `set_tutorial_highlight(on: bool)` on `Enemy` that force-enables the existing hover outline shader. Combined with a bounce arrow above the sprite (position from the enemy's IntentUI anchor, which already accounts for sprite height).
5. **Power-number spotlight** — dimmer cutout centered on the `CurrentPower` label in `dice.tscn` (T1.3, T1.5, T2.7). Note: the label is right-anchored and extends further than the die box (see CLAUDE.md IntentUI/CurrentPower audit) — size the cutout to the label's *actual* rect at runtime.
6. **Ribbon pointer** — small arrow at the card's `RequirementPanel` (in-hand, ~40px target, fine at rest since the hand is frozen by gating). Stretch: a 1.5×-scaled `CardMenuUI` clone beside the text panel with the ribbon circled (pattern: `card_rewards.gd` ExampleCard + upgrade-preview pivot conventions).
7. **Text panel** — ONE reusable panel (RichTextLabel, `fit_content`, BBCode, `mouse_filter = 2` — RichTextLabel defaults to STOP, known gotcha) with ~5 anchor presets: center, top-center, above-hand, beside-dice, beside-enemy. Slide/fade 0.15s between steps so the tutorial feels alive instead of teleporting. Optional Continue button slot for the 4 reading steps.
8. **Skip button** — always visible, top-right, as today.

---

## 6. Implementation spec

### A. TutorialDirector (new: `scenes/battle/tutorial_director.gd` + node in battle.tscn)
Data-driven replacement for the 15-panel/flag web. An ordered array of step dicts; the director shows text/affordances, applies gates, connects to ONE completion signal per step, advances. All completion signals already exist in `events.gd`: `card_played(card)`, `card_charged(card_ui)`, `dice_rolled(active_dice, roll_value)`, `active_dice_changed(active_dice)`, `next_roll_determined`, `scout_effect(amount)`, `player_turn_started`, `enemy_turn_ended`, `card_aim_started(card_ui)`.

Suggested step schema:
```gdscript
{
    "id": "t1_aim_strike",
    "text": "...bbcode...",
    "text_anchor": TextAnchor.ABOVE_HAND,
    "continue_button": false,
    "dim": Dim.SOFT,                              # NONE / SOFT / FULL
    "pointer": {"target": "enemy_0", "dir": "down"},
    "pulse": ["card:strike"],                     # resolved via small target registry
    "spotlight": "",                              # "" or target key e.g. "power_number"
    "gate": {"cards": ["strike_id"], "roll": false, "dice": [], "end_turn": false, "scout_faces": []},
    "on_enter": ["enemy_highlight_on"],           # named hooks, incl. forced-roll queue pushes
    "on_exit": ["enemy_highlight_off"],
    "done": {"signal": "card_played", "filter": {"card_id": "strike_id"}},
}
```
Target registry maps string keys → live nodes (roll button, red die slot, socket, a card in hand *by card id* — check the actual `id` strings on the .tres files at implementation time; the 3 Strikes likely share one id, which is exactly what gating wants). Keep the step array in ONE place. Panels no longer live in battle.tscn — text comes from this array, layout from the overlay scene.

### B. Determinism hooks
1. **Forced roll queue** — replace `Global.tutorial_forced_roll: int` (+ the "forced 2 → forced 1" hack at `dice.gd:869-870` and the value-keyed step emissions at 859-868) with `Global.tutorial_forced_rolls: Array[int]`, popped front in `roll_dice()` where the current forced-roll branch lives (`dice.gd:462-468`). Keep the existing safety `push_error` if the value isn't in the die's faces. Steps no longer key off roll values — the director advances on `dice_rolled`.
2. **Forced scout faces** — new `Global.tutorial_forced_scout_faces: Array[int]` consumed in `battle.gd::_on_scout_effect` at the random-pick loop (line ~343-345): if non-empty, use these values (mapped to textures via the existing `dice_faces` lookup) instead of `randi()`, then clear. Face-click gating for T3.3: during that step only, set non-target faces `mouse_filter = IGNORE` + modulate dim — the scout reveal code already toggles `mouse_filter` per-face during flicker (see CLAUDE.md scout section), extend the same mechanism.
3. **Forced hands** — rewrite the two blocks in `player_handler.gd` (turn-1 at :32-44 via `start_battle`, turn-2 at :52-77) into a director-driven per-turn lookup and add turn 3: T3's forced cards (Scout 3 + a Strike) may be split across piles by then (12-card deck, 15 draws → reshuffle before/during the T3 draw); the injection helper must search draw pile AND discard and move the cards to the draw pile front. *(Correction from Julien post-implementation: All In was a temporary REPLACEMENT for `warrior_axe_attack1.tres`, not an addition — the real starter deck is 12 cards with 4 Strikes: attack1-4, block1-4, low_blow, reinforce, card_recombobulate, card_scout3_no_exhaust. attack1 restored; none of the damage accounting changes.)*

### C. Input gating (new, the anti-desync layer)
Per-step allowlist applied by the director:
- **Cards:** `CardUI.disabled` already exists (used during other cards' drags) + a dim modulate for locked cards. Gate by `card.id` so any copy of Strike counts.
- **Roll button / dice selection:** guard clicks in `dice.gd` / `dice_interface.gd` behind a director check (`if Global.tutorial_on and not TutorialGate.allows("roll"): return`). Small static helper or autoload-style access via the battle scene — keep it dumb.
- **End Turn:** the button lives in `scenes/ui/battle_ui.gd` — toggle `disabled` (and suppress its gold idle pulse while disabled).
- **Scout faces / Exit:** §6.B.2.
- **Skip button:** never gated. On skip: restore ALL gates, kill overlay tweens/nodes, clear forced queues, call the (extended) `end_tutorial()` reset. Test skipping at *every* step.
- When `tutorial_on == false`, the gate helper must be a zero-cost pass-through.

### D. Dedicated tutorial battle content
- `battles/tutorial_fight.tres` (BattleStats, `battle_tier` irrelevant — it's only reachable via the forced path in `run.gd:385-391`; keep gold reward 20-30) + `battles/tutorial_fight.tscn` (single Skeleton, reuse positioning from `tier_0_crab.tscn`).
- `enemies/crab/crab_enemy_tutorial.tres` — duplicate of `crab_enemy.tres` with `max_health = 22`, `enemy_name = "Skeleton"`, and a **dedicated tutorial AI scene** (`crab_tutorial_ai.tscn`): one action, attack 6, always performable — replacing the one-shot `Global.tutorial_enemy_attack` flag + `enemies/crab/tutorial_attack.gd` gate (which currently only fires once; T2 needs a second attack). This follows the established per-variant `.tres` convention (see CLAUDE.md tier duplication rule) and unpins the tutorial from balance passes on `tier_0_crab`.
- Swap the forced load in `run.gd::_get_unique_battle_for_tier` to the new .tres. Don't append it to `used_battles` (it's not in any pool).
- New .tres files need explicit `uid=` headers (CLAUDE.md uid rule).

### E. Global.gd cleanup
- **Remove** the per-step flags: `tutorial_forced_roll`, `tutorial_block`, `tutorial_low_blow`, `tutorial_enemy_attack`, `tutorial_red_dice`, `tutorial_charging_card`, `tutorial_red_attack`, `tutorial_end_turn`, `tutorial_blue_dice`, `tutorial_second_turn`, `tutorial_recombobulate`, `tutorial_fight` (replaced by a single `tutorial_on` check at the battle-pick site, or keep `tutorial_fight` if the "only first fight" semantics stay — implementer's call, document it).
- **Keep:** `tutorial_on`, `tutorial_reset_power_warning` (§7), and the post-tutorial explanation flags (`tutorial_dice_shop/bonus_requirement/transcendent/blessing_explanation_needed`).
- **Add:** the forced queues from §6.B.
- Update BOTH `Global.reset_run_state()` (global.gd:223-239) and `run.gd::SAVED_TUTORIAL_FLAGS` (:823-829) — save-system rule: run-scoped Global state lives in both places. The new queues should reset; they don't need saving (a load lands on the map, mid-combat tutorial state is deliberately not persisted — same policy as today, documented at run.gd:819-822).

### F. Old system removal
- Delete `Tutorial1`–`Tutorial15` + their buttons/arrows from battle.tscn; delete the dispatch code in battle.gd (:45-92 onready block, :697-809 handlers), the flag checks in `card.gd:155-166`, `dice.gd:859-870` + `:1179-1181`, `dice_interface.gd` step emissions (:138-140, :155-157), `player_handler.gd` old forced-hand blocks, and the `Events.tutorial_step_requested` signal once nothing references it.
- **KEEP `WarningPowerReset`** (battle.tscn) and its `tutorial_reset_power_warning` triggers in `dice_interface.gd` — see §7.
- **KEEP** the post-combat explanation systems (dice shop popup, Blessing/bonus reward tutorials in `card_rewards.gd`) — out of scope.
- .tscn editing pitfall (CLAUDE.md): do scene edits in single atomic Writes, ideally with the Godot editor closed — the file watcher re-saves and can clobber mid-edit states with broken ext_resource refs.

### G. Build order (suggested)
1. Determinism foundations (§6.B + §6.D + hand fix) — old tutorial still runs, now on the new fight; smoke-test.
2. TutorialDirector + step array with bare text panels (no affordance kit yet) — full flow playable end-to-end.
3. Affordance kit (§5), wire per step.
4. Gating (§6.C) + skip path + edge cases.
5. Strip old system (§6.F), final copy pass.
6. Playtest checklist (§8).

### H. Known-pitfall checklist for the implementer (all documented in CLAUDE.md/memory)
- RichTextLabel `mouse_filter` defaults to STOP → set 2 on all overlay labels.
- A CanvasLayer child ignores parent `hide()` — the overlay is its own layer; hide by toggling the layer node itself.
- Scout panel children: never `hide()` a face mid-layout (re-flows the HBox) — use `modulate.a`; face positions must be computed arithmetically, not read from the container mid-frame.
- `:=` on values read from untyped Global vars fails to infer — type explicitly.
- Typed-array ternaries lose their type — declare + append.
- New .tres files: explicit `uid=`.
- `Engine.time_scale` hit-stops still run during tutorial — fine, but overlay tweens that must survive pauses need explicit process modes only if anything pauses (nothing in this flow pauses the tree).
- Syntax check via `python -m gdtoolkit.parser <file>` — `--check-only` headless is broken on this project (autoloads).
- `card.id` values: verify actual id strings on the .tres files before gating by id (e.g. Low Blow's id is `warrior_duo`, not `low_blow`).

---

## 7. Deliberately unscripted (and why)

- **Type-switch power reset:** the existing one-shot `WarningPowerReset` popup stays as the teacher. The script never switches types with Power > 0 (T1.7 and T3.1 both happen at 0), so the popup fires the first time the player *actually* does it in a real fight — better timing than a tutorial lecture, and it already carries the "sometimes this is a smart play" nuance.
- **Dice type shopping, Blessings, bonus requirements, map/meta:** existing post-combat/one-shot systems, untouched.
- **All 9 dice types, Exhaust, statuses:** hover tooltips + discovery. The victory text explicitly points at hovering.

## 8. Playtest checklist (for the implementation session)
1. Full happy path — every step advances, Skeleton dies to the exact-6 Strike (verify it's a kill, not a 1-HP survivor — §4 constraints), rewards screen follows, `tutorial_on` false afterward, next fight is normal (Dice Bag fires, random hands, no gates).
2. Skip at each of the ~19 steps → everything restored (gates, dimmer, forced queues empty, enemy highlight off, End Turn enabled, scout faces clickable).
3. Spam-click ROLL during gated steps; drag every locked card; click every locked die — nothing moves.
4. T1.4 released-into-void: card returns to AIMING, nudge fires, no soft-lock.
5. T3.3: only the 6 clickable; Exit disabled; guarantee survives to the roll; pick lands → `next_roll_determined` advances the step.
6. Reshuffle before T3 hand: Scout 3 + a Strike present in the T3 hand even when they sat in the discard.
7. T2 Recombobulate: exactly 2 Blues refunded, Power drops 2 → 0, then the forced 3 puts Low Blow in range (Max 3 respected).
8. Save/quit on the map after the tutorial fight → reload → no tutorial residue (flags via SAVED_TUTORIAL_FLAGS unchanged in behavior).
9. Run with tutorial disabled from the main menu → zero overhead, no gates, Dice Bag works, normal fight picked. Starter deck no longer contains All In.

## 9. Open questions for Julien (defaults chosen, flag if you disagree)
1. **Scout pick gated to the 6** — now structurally required, not just script hygiene: with the Strike finale, a picked 2 or 4 cannot kill, and the tutorial can't end on a whiff. If free pick at the fantasy moment matters more, the finale needs a variance cushion again (e.g. forced faces [6,6,6], or lower Skeleton HP so any pick kills) — flag it and §4's numbers get reworked.
2. **Flawless tutorial** (chosen) vs. letting one 6 land unblocked in T2 for a "you can't always block — sometimes you race" lesson. Flawless is friendlier; the scratch is more honest.
3. **No-reset cards need a differentiator** (Julien, 2026-07-12: "Support" keyword dropped, "I should probably put one or explain it"). The tutorial teaches the behavior verbally via Reinforce (T2.7) and deliberately never names a keyword, so the copy survives whatever gets picked. Options, cheapest first: (a) a "Doesn't reset your Power." line appended to the description of every no-reset card — self-explaining, works with hover-to-learn, zero new art; (b) a small icon — the hidden `SupportIcon` slot already exists in `card_ui.tscn`/`card_menu_ui.tscn` (both copies, usual duplication caveat), waiting for an asset; (c) reinstate a keyword + tooltip via the existing tags/KeywordColorizer pipeline. Decide separately from the tutorial work; (a) could ship with it if wanted.
4. Two 1s in a row as the T2 comedy beat — intended tone ("TWO 1s?! Okay, breathe."). Too mean? Forced rolls are trivially retunable.
5. Victory copy tone ("you needed exactly a 6, so you took exactly a 6" / "bend fate") — matches the Auguria luck-abandonment lore direction; adjust freely.
6. Old `Tutorial1-15` panels: delete outright (chosen) or keep commented in a branch until the new flow is validated in playtest.
