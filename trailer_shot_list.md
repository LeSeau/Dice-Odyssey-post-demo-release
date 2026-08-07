# Dice Odyssey — Trailer shot list & production plan

**Target:** 60 seconds, 1920×1080, H.264 MP4
**Purpose:** Steam store page primary trailer (+ a 15s vertical cut for TikTok/Shorts from the same footage)

---

## The three rules that decide whether this works

1. **Frame 1 is gameplay.** No studio logo, no fade-from-black, no "in a world…" text card. Every second before the game appears is a second people spend leaving. Logo goes at the *end*.
2. **The Steam store trailer autoplays MUTED.** Assume most viewers never hear the audio. Every beat that carries meaning needs a text overlay or must be self-evident visually.
3. **The first 5 seconds must sell the hook: dice replace energy.** Not the story, not the art, not the genre — the one thing that isn't like Slay the Spire.

---

# PART A — Shooting checklist

Record these as separate clips. Don't try to film one continuous run — **stage everything.**

### Stage the footage, don't play honestly

You already have the tools for this. Use them:

- `OS.is_debug_build()` DebugButtons + `Global.debug_battle_entry` → jump straight into any fight, skip the 1s victory delay
- `Global.tutorial_forced_rolls` → force exact roll values so the money shots land every take
- Hand-edit the starting deck / `*_dice_max_amount` / `relic_handler` to give yourself the exact cards, dice and relics a shot needs
- `force_for_testing` on an `EventStats` → force a specific event to appear

Trailer footage is *curated best-case*, not representative. Every trailer does this. Don't spend three hours hoping Dice Avalanche shows up naturally.

---

### 🎬 Group 1 — The hook (highest priority; shoot these first and shoot them well)

| # | Shot | Setup notes |
|---|---|---|
| **1.1** | **Power chain climbing.** Blue die, three consecutive rolls: `4` → `7` → `13`. Hold on the Power number as it climbs and the roll-history mini-faces fill in underneath. | The single most important shot in the trailer. Force the rolls. Frame tight on the dice cluster + Power number. |
| **1.2** | **The emanation glow at full charge.** Same cluster at ~15+ banked Power — the aura's flame-licks at maximum reach. Slow push or hold. | This is your prettiest asset. Shoot it in Movie Maker mode (see Part C). |
| **1.3** | **Power orbs flying.** A big roll, orbs arcing from the die into the Power number with the arrival flash. | Get a version on **magma** (orange) and one on **blue** (indigo) — you'll want the color contrast later. |
| **1.4** | **Max-roll burst.** A natural 6 on blue (or 12 on giant): gold flash, hit-stop, radial burst. | Best celebration in the game. Shoot 3–4 takes, pick the cleanest. |
| **1.5** | **The reset.** Big banked Power → play a card → Power crashes to 0. | This is the *tension* half of the hook. Needed for the "most cards spend it all" beat. |

### 🎬 Group 2 — The gamble

| # | Shot | Setup notes |
|---|---|---|
| **2.1** | **Red die socket.** Drag a card into the red die's socket, then roll. Card resolves after the roll. | Your clearest "commit first, roll after" visual. |
| **2.2** | **Evil die crack.** The `0` face landing, with the crack sound/flash. | The risk beat. |
| **2.3** | **Evil die 6.** Same die paying off. | Cut 2.2 → 2.3 back to back for a risk/reward micro-beat. |

### 🎬 Group 3 — The money shots (cinematic)

| # | Shot | Setup notes |
|---|---|---|
| **3.1** | **Dice Avalanche.** Up to 9 dice thrown in sequence — each hangs above-left of the enemy, locks its face with a glint, then haymakers down with flare + debris + shake. | **Your single best-looking effect.** Stage it against a wide enemy (Marauder) so the hang position reads. Movie Maker mode, no question. |
| **3.2** | **Meteor / single thrown die.** One clean windup → hang → slam. | The readable version of 3.1 — use this one if Avalanche is too chaotic to parse at speed. |
| **3.3** | **Magma AoE.** A magma roll burning every enemy at once, in a 3–4 body fight. | Shows scale. |
| **3.4** | **A huge damage number.** 35–40+ on a single hit. Blackjack, All In, Crescendo or Doomsday. | Frame so the popup is clearly readable. |
| **3.5** | **An enemy dying** with the death/impact feedback. | Short. Punctuation. |

### 🎬 Group 4 — Variety (proves depth, sells replayability)

| # | Shot | Setup notes |
|---|---|---|
| **4.1** | **The dice row** with 6+ different types owned, cycling the active type so each aura/color flashes in turn. | Fast cuts or one continuous click-through — this is the "9 dice types" proof shot. |
| **4.2** | **Card reward screen with a Rare.** The staggered entrance, the gold flash + perimeter motes on the rare, then the pick and the card flying to the deck button. | Beautiful and it reads instantly as "deckbuilder". |
| **4.3** | **The relic bar** filling out — a hover tooltip popping on one relic. | 1 second. Signals build variety. |
| **4.4** | **Dice Infusion ceremony.** The post-act-1 upgrade screen: two glowing panels, motes rising, the gather → detonation flash. | A whole cinematic beat already built. Steal it. |
| **4.5** | **The map**, with the pawn hopping to a new room and the ink selection ring drawing itself. | 1–2 seconds max. Signals "roguelike run structure" and nothing more. |
| **4.6** | **Enemy roster flashes** — Marauder, Lich, Kraken, Dragonpriest, Gargantua. 3–5 frames each, intent icons visible. | Cut to the music. |

### 🎬 Group 5 — Boss & payoff

| # | Shot | Setup notes |
|---|---|---|
| **5.1** | **The Dicelord** entrance — the act-2 boss banner announcing "THE DICELORD", then the boss on screen. | Your best boss visual. |
| **5.2** | **A boss hit landing** for big damage. | — |
| **5.3** | **"DUNGEON CONQUERED!"** end screen with the scoreboard counting up. | Optional. Only if you want to end on triumph rather than on the logo. |

### 🎬 Group 6 — Title card

| # | Shot |
|---|---|
| **6.1** | Logo on dark background (from the capsule commission), with "Wishlist on Steam" beneath. Hold 3 seconds. |

---

# PART B — The edit

**60 seconds. Times are approximate — cut to your music, not to this table.**

| Time | Shots | On-screen text | Notes |
|---|---|---|---|
| **0:00–0:05** | 1.1 | *(none — let it read)* | **Cold open on the Power chain climbing.** No logo, no fade. Just the number going 4 → 7 → 13 with the roll history filling in. If a stranger watches only this, they should already be curious. |
| **0:05–0:08** | 1.4 | **"DICE ARE YOUR ENERGY"** | Max-roll burst lands exactly on the text. Gold Cinzel, matches the game. |
| **0:08–0:14** | 1.3, 1.2 | **"ROLL THE SAME DICE TO CHAIN YOUR POWER"** | Orbs flying in, aura swelling to full charge. This is the mechanic explained purely visually. |
| **0:14–0:19** | 1.5 → 3.4 | **"MOST CARDS SPEND IT ALL"** | The crash to 0, immediately followed by the huge damage number it bought. Cause and effect in one cut — this is the whole game in five seconds. |
| **0:19–0:26** | 2.1, 2.2, 2.3 | **"OR COMMIT FIRST — AND ROLL AFTER"** | Red socket, then the evil die's `0`, then its `6`. Risk, then reward. |
| **0:26–0:34** | 3.2 → 3.1 | *(none — let it breathe)* | Single thrown die to establish the beat, then Dice Avalanche as the escalation. **Music should hit hardest here.** |
| **0:34–0:40** | 4.1, 3.3 | **"9 DICE. EACH BREAKS THE RULES DIFFERENTLY."** | The dice row cycling, then magma burning the whole board. |
| **0:40–0:48** | 4.2, 4.3, 4.4 | **"80+ CARDS · RELICS · DICE INFUSIONS"** | Fast montage. Rare card reveal → relic bar → infusion detonation. |
| **0:48–0:53** | 4.5, 4.6, 5.1 | **"TWO ACTS. ONE DICELORD."** | Map pawn hop, enemy flashes cut to the beat, then the boss banner. |
| **0:53–0:56** | 5.2 | *(none)* | Big hit on the boss. Final impact. |
| **0:56–1:00** | 6.1 | **DICE ODYSSEY** / *Wishlist on Steam* | Logo, hold 3s, cut to black. |

### Text overlay style
Gold `#EEB52A`, **Cinzel Decorative Bold**, dark outline `#170F05` — identical to the game's own titles, so the trailer and the store page feel like one object. Keep each line under ~6 words. Hold each for at least 1.5s (people read slower than you think, and they're often half-watching).

### Pacing rule
Nothing after 0:26 should hold longer than ~2 seconds. The first half explains; the second half overwhelms. Rising cut rate is what makes a trailer feel like it's building.

---

# PART C — How to actually capture and cut it

### Capture: use both tools, for different shots

**Godot Movie Maker mode** — for every VFX-heavy hero shot (1.2, 1.3, 1.4, 3.1, 3.2, 3.3, 4.4). You already know this workflow from your debug harnesses:

```bash
Godot_v4.3-stable_win64_console.exe --path . --write-movie trailer_frames/f.png --fixed-fps 60 --resolution 1920x1080
```

It renders offline, so **every frame is perfect** — no dropped frames, no stutter, no matter how heavy the particle load. Your loading hitches on dice-face textures can't eat a beat. Then assemble with ffmpeg:

```bash
ffmpeg -framerate 60 -i trailer_frames/f%08d.png -c:v libx264 -crf 16 -pix_fmt yuv420p shot_3_1.mp4
```

⚠️ Movie Maker output starts at engine boot, so **trim the first couple of seconds off every clip** — and remember frame numbers won't match between two runs (boot time varies), so don't compare timecodes across takes.

**OBS Studio** (free) — for normal interactive gameplay (2.1, 4.1, 4.2, 4.5). Record 1920×1080 @ 60fps, high bitrate. Easier when you need to actually play.

### Edit
**DaVinci Resolve** (free) is the strongest option and handles a 60-second cut easily. Shotcut or Kdenlive if Resolve feels heavy.

### Music
Use your own game music — `final_boss_battle.mp3` is your most energetic track and it ties the trailer to the product. **One caveat:** if any of your tracks came from a stock/asset library, check the license actually permits promotional/trailer use — some audio licenses cover in-game use only. Worth verifying before the trailer is public.

Cut your visual beats to the music's beats, not to the clock. The 0:26 escalation should land on a musical hit.

### Sound design
Keep your game's own SFX under the music: the roll clatter, the max-roll burst, the throw-slam impacts. Duck the music slightly under the big hits. Even though most Steam viewers hear nothing, the YouTube and social versions play with sound and it matters there.

### Export
1920×1080, H.264 MP4, ~10–20 Mbps. Verify current Steam trailer specs in Steamworks before upload — they occasionally revise the requirements.

### Free extra: the vertical cut
From the same footage, cut a **15-second 9:16 vertical** for TikTok / YouTube Shorts / Reels: shot 1.1 (chain climbing) → 1.4 (max roll burst) → 3.1 (Dice Avalanche) → logo. Crop to the dice cluster and the enemy; the game's 1280×720 design viewport crops to vertical acceptably if you frame on the action. Costs you 20 minutes and it's the cheapest reach you have.

---

## Priority order, if you only do part of this

If you shoot nothing else, shoot **1.1, 1.4, 1.5, 3.1** and cut a 20-second teaser. Chain climbing → max roll → the crash → Dice Avalanche. That's the hook, the payoff and the spectacle, and it's enough to post on Bluesky and Reddit *today* — long before the Steam page exists.

---

*Written 2026-08-06. Verify Steam trailer specs against current Steamworks documentation before upload.*
