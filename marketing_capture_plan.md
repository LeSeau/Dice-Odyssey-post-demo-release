# Marketing capture plan + Steam page copy (2026-07-10)

## Part 1 — The 30-second combat clip

Goal: one take that teaches "dice = energy, push your luck" in the first 3 seconds,
then shows depth (Scout/Mech/dice-switching) without any text needing to be read.
Reddit video = full ~30s clip. GIF version = just beats 1–2 (first ~10s), looping.

### The fight

Use the **Marauder + 2× Kraken** comp (the documented expert-playtest fight).
Three bodies = shows AoE, targeting, and intent icons in one frame. Launch it via
the debug Battle button (`Global.debug_battle_entry` also skips the 1s victory delay
between takes).

### Rig the take (temporary edits — COMMIT FIRST, then revert with git after)

1. `global.gd`: `gold = 75` (not 7575).
2. Starting deck (`warrior_starting_deck.tres`): swap in the take's hand —
   Scout 3, Catapult, Flurry, Recombobulate, Block ×2, Strike ×2. Viewers can't
   tell a rigged deck; a clean combo is worth it.
3. Starting dice: 2 Blue + 1 Red + 1 Mech (add Mech temporarily).
4. Add Blood Sword to starting relics (or buy it in a prior shop on the same save).
5. Double-check no `EventStats.force_for_testing` is left checked.
6. Run **fullscreen** (no "(DEBUG)" title bar in frame). OBS at 1920×1080, 60 fps.

### Beat-by-beat script (~30–35s)

| Time | Action | What the viewer learns |
|---|---|---|
| 0–4s | Already mid-combat, hand visible. Roll Blue → power orbs fly, number climbs. Roll second Blue → power **accumulates**. | Dice generate a banked resource. The juice hooks them. |
| 4–10s | Play Scout 3 on the **Mech** die → outcome panel appears → roll, then click the ±1 arrow to force a **1** → play **Catapult**: AoE damage popups on all three enemies + hit-stop. | There's manipulation and low-roll payoffs — not a slot machine. |
| 10–17s | Catapult granted Lucky → **switch active die to Red** (power resets — visible) → roll: Lucky guarantees the 6, Blood Sword adds +2 → play **Flurry** into the Marauder. Big number, big hit-stop. | Dice-type switching is a tactical tool; relics interact with dice types. |
| 17–26s | Roll remaining Blues, get trash (1, 2) → play **Recombobulate** → dice refuel animation → reroll better → finish off a Kraken (death). | Bad luck has counterplay. |
| 26–32s | Block the telegraphed attack, End Turn highlight pulses gold, click End Turn. Cut on the enemy turn starting. | Clean loop closure. |

Do 5–10 takes; Scout + Lucky de-randomize the key beats so most takes will land.
Keep the one where the rolls cooperate on beat 4. Don't move the mouse in circles
between actions — cursor path reads as confidence.

If 30s must become 25s: cut beat 4 (Recombobulate), never beats 2–3.

### Pre-flight checklist (any public footage, not just this clip)

- [ ] gold shows 75, not 7575
- [ ] No "(DEBUG)" in any visible chrome → fullscreen or exported build
- [ ] Deck has no obvious test inserts unless intentionally rigged
- [ ] 1080p60, native Reddit upload (no YouTube link)
- [ ] Consider hiding the Discord button overlay during capture

## Part 2 — Steam page copy (draft)

> Before committing to the name, search Steam for "Dice Odyssey" collisions.

### Short description (Steam limit ~300 chars)

> A roguelike deckbuilder where dice replace energy. Roll to bank Power, push your
> luck — playing a card usually spends it all. Rig the odds with Scouts, Lucky
> charms and mechanical dice, and build around nine dice types with their own rules.

### Long description

**ROLL. BANK. SPEND.**

In Dice Odyssey there is no mana. Every turn you roll dice to bank Power — and
keep banking as long as you chain the same die. But play a card, or switch dice,
and it's gone. How greedy do you get before the Lich punishes you for hoarding?

**NINE DICE, NINE GAMBLES**
- **Blue** — roll before you commit. The planner's die.
- **Red** — roll *after* you pick your card. The gambler's die.
- **Evil** — faces 6, 6, 6… and 0.
- **Giant** — a d12 for when you need it huge.
- **Mech** — nudge any roll ±1. The cheater's die.
- …plus Magma, Green, Odd and Even, each warping how a turn plays out.

**BEND THE ODDS**
Scout future rolls, force guaranteed maximums with Lucky, weaponize *bad* rolls
with Low Roll cards, or refuel a whole turn of trash dice and try again. The dice
are random — your run doesn't have to be.

**BUILD THE MACHINE**
- 75+ cards, each with an upgraded version
- Relics that hook into specific dice types and roll patterns
- Branching map: elites, shops, campfires, treasure, 20+ narrative events
- Two acts and a boss who makes you regret every Power you saved

### Tags (in order)

Roguelike Deckbuilder, Deckbuilding, Dice, Turn-Based Strategy, Roguelite,
Singleplayer, Indie, Card Game

### Screenshots (5)

1. The combat beat from the clip — big roll, orbs mid-flight, damage popup
2. Full hand of visually distinct cards (a Blessing + a Celestial in frame)
3. The map (path-dimming makes it read well)
4. Dice shop with tooltips visible
5. A narrative event with its new art

### Capsule

The one asset to pay a human artist for. Brief: warrior + one oversized glowing
die as the focal object, title readable at 231×87. No AI capsule — it's the
first thing an AI-hunting commenter screenshots.

## Part 3 — Final Reddit titles (pick per subreddit)

- r/roguelikedeckbuilders: "In my deckbuilder, dice replace energy — you keep
  rolling to bank Power, but most cards spend it all. Here's one turn."
- r/DestroyMyGame: "30 seconds of my dice deckbuilder's combat. Destroy it."
- r/godot: "A year of juice work in Godot: hit-stops, power orbs, dice feel —
  before/after in my roguelike deckbuilder." (before/after clips perform great here)
