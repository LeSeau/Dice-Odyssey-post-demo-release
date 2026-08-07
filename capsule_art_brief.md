# Dice Odyssey — Capsule Art Brief

**For:** commissioned illustrator
**Client:** Julien Meremans (solo dev) — julien.meremans@gmail.com
**Deliverable:** Steam capsule key art + full size set
**Engine/platform:** Godot 4 → Steam (PC)

---

## 1. First-contact message (send this in the DM / email)

> Hi — I'm a solo dev looking to commission key art + the full Steam capsule size set for **Dice Odyssey**, a dark-fantasy roguelike deckbuilder where dice replace the usual energy system.
>
> I have a full written brief, the game's existing art, palette, and screenshots ready to send. Style target is painted, cel-shaded dark fantasy with thick outlines and strong gold accents — I can show you exactly what the in-game art looks like.
>
> What I need: one key art illustration + a title logo lockup, delivered layered so it can be re-composed into the 9 Steam capsule sizes (or you deliver the crops directly — happy to pay for that as part of the scope).
>
> Could you share your rate and availability for that? Thanks!

---

## 2. The game, in three sentences

**Dice Odyssey** is a roguelike deckbuilder where **dice replace the classic energy system**. Instead of spending mana, you roll dice to build up **Power** — and rolling the same dice type repeatedly *chains* and accumulates that Power, but most cards spend it all when played. Every turn is a push-your-luck decision: roll again and risk it, or cash in now.

There are 9 dice types, each with its own faces, color identity and effect (a d12 giant, a d3, a "magma" die that damages every enemy when rolled, an "evil" die whose faces are 6/6/6/0, a red die you roll *after* committing a card). You descend through dungeon acts fighting skeletons, satyrs, krakens and liches, up to a hooded horned final boss called **The Dicelord**.

---

## 3. The one job of this image

At **thumbnail size**, on a page of 40 other dark-fantasy games, a stranger must instantly read:

1. **Deckbuilder** (cards are present)
2. **Dice are the point** (not decoration — the hook)
3. **Dark fantasy, painted, premium** (not cute, not flat-vector)

If someone can't tell it's a dice-driven card game from a 462×174 thumbnail, the image has failed regardless of how good it looks at full size. **Legibility at small size is the primary constraint, not detail.**

---

## 4. Concept direction

### ★ Recommended: "The Gambler's Descent" — character + hero die

A **single hooded figure** (the player-hero, or read as The Dicelord) in three-quarter view, mid-cast, with **oversized glowing dice tumbling out of / orbiting their hands**. One die is the clear hero object — large, foreground, caught mid-tumble, its face reading a bold **6** with gold-glowing pips. A **fan of cards** rims the lower frame or trails from the other hand. Gold **Power motes** stream upward from the dice toward the figure, implying accumulation. Background: a dark stone dungeon interior, heavily simplified, deep value falloff so the silhouette pops.

**Why this one:** character-led capsules are the most memorable on the Steam grid, the tumbling dice sell the hook without any text, and the dark painted treatment carves out a lane away from the two obvious comparisons (*Dicey Dungeons* is bright and flat-cartoon; *Astrea: Six-Sided Oracles* is white/celestial/clean). Dice Odyssey's lane is **gothic, painted, gold-on-dark**.

### Alternate A: "The Big Die"
One enormous die dominating the frame, cracked with light bleeding from the seams, gold pips glowing, cards fanned behind it like wings, a small silhouetted hero at its base for scale. **Strongest possible small-capsule readability** — a die is a perfect chunky silhouette. Less memorable/emotional than the character route.

### Alternate B: "The Table"
Low, near-first-person angle across a stone altar-table: cards fanned toward the viewer, dice mid-tumble across the surface, an enemy silhouette looming on the far side out of the dark. Most directly communicates "this is a card game," but first-person compositions tend to read as busy at thumbnail size.

**If in doubt, go with the recommended direction.**

---

## 5. Visual language

### Palette (pulled from the actual game)

| Role | Hex | Notes |
|---|---|---|
| **Universal gold** | `#C9A227` | The single most important color — every card border, panel and title in the game uses it |
| Bright gold (titles/glow) | `#EEB52A` | For the logo and light accents |
| Deep gold outline | `#170F05` | Outline color under gold text |
| Card wine red | `#4F0012` | The body color of most cards |
| Panel navy | `#212A3E` / `#141A29` | UI panels, backgrounds |
| Ink sepia | `#4A2F14` | Map/parchment ink |

**Dice color identities** (use 2–3 max in the image, don't include all nine):
- Blue (the default/starter die, most iconic) — **royal indigo**
- Red — **blood crimson**
- Evil — **deep violet with magenta veining**
- Magma — **full-intensity lava orange**
- Giant — moss green · Odd — brass/bronze · Even — saturated orange · Pixie — leaf green · Mech — light steel with rusted rivets

→ **Recommended for the capsule: indigo hero die + gold Power glow, with one crimson or magma accent die.** Blue+gold is the game's signature pairing.

### The Power glyph ✦
The game's core resource has its own symbol: a **four-pointed star / spark**, slightly elongated, near-monochrome gold. It appears inline in every card's text. **Please work it in** — as the shape of the light motes rising off the dice, or as a subtle repeated motif. It's the closest thing the game has to a brand mark. (Asset file: `power_glyph.png`, included in the reference pack.)

### Style target
- **Painted / cel-shaded**, with **thick dark outlines** on the main subject — matches the existing enemy and card art
- Comic-book-adjacent readability, not photoreal, not soft-airbrushed
- **High value contrast**: bright subject, deep dark background. The game's own art rule is that pale/washed-out subjects on light grounds disappear
- Warm gold light source, cool dark surroundings

### Do NOT
- ❌ Bright, flat, cartoon vector (that's *Dicey Dungeons*' lane)
- ❌ White/clean/celestial (that's *Astrea*'s lane)
- ❌ Busy scenes with many small elements — it dies at thumbnail size
- ❌ Realistic photo-render dice
- ❌ A generic hooded fantasy figure with *no dice* — the dice are the entire differentiator
- ❌ Text baked into the illustration layer (see deliverables)

---

## 6. Composition constraints — please read, this is the technical crux

Steam needs the **same art at nine wildly different aspect ratios**, from ultra-wide (`3840×1240`) to tall portrait (`600×900`). A composition that only works at one ratio will need expensive rework.

So please:

- **Compose the subject centrally**, with generous **bleed on all four sides** — extend the background well beyond the main crop so tall and wide versions can both be pulled from it
- Keep the subject's **head and hero die inside a central safe zone** that survives a `600×900` portrait crop *and* a `462×174` letterbox crop
- **Keep the title logo on its own layer(s)** — it must be re-positioned per ratio and delivered separately as a transparent PNG
- Work at a **large master canvas** (≥4000px on the long edge) so the `3840×1240` library hero can be pulled without upscaling
- **sRGB**, please

### The logo
The game's in-game title font is **Cinzel Decorative Bold** (a Roman/Trajan-style engraved serif). The logo should either use it or be custom lettering that rhymes with it — engraved, gold `#EEB52A`, dark outline, slightly weathered. **"DICE ODYSSEY" must stay legible at 462px wide.** Bonus if a die face or the ✦ Power glyph can be integrated into the lettering without hurting legibility.

---

## 7. Deliverables

**Core:**
1. Key art illustration, layered source file (`.psd` or `.clip`), ≥4000px long edge, sRGB
2. Title logo lockup, layered, **plus a transparent PNG, logo only, no background**

**Steam size set** (verify against current Steamworks docs before final export — Steam adjusts these occasionally):

| Asset | Size | Where it appears |
|---|---|---|
| **Header capsule** | 920 × 430 | Top of store page, wishlist emails — **the most-seen asset** |
| **Small capsule** | 462 × 174 | Search results and lists — **the hardest one, design to this** |
| **Main capsule** | 1232 × 706 | Front page / featured placements |
| Vertical capsule | 748 × 896 | Sale and event features |
| Page background | 1438 × 810 | Store page backdrop |
| Library capsule | 600 × 900 | Player's own library grid |
| Library header | 460 × 215 | Library list view |
| Library hero | 3840 × 1240 | Library page banner |
| Library logo | 1280 × 720 | Transparent PNG, logo only, overlays the hero |

**Please confirm whether producing all nine crops is inside your quoted scope** — some artists price key art and the crop set separately, and I'd rather agree on it upfront than discover it at delivery.

**Rights:** full commercial usage rights for the game, store pages, marketing and press. Happy to credit you in-game and on the store page.

---

## 8. Reference pack to send with this brief

- 6–10 in-game **screenshots** (combat, card rewards, the map, an end screen)
- The **card art** files — they show the painted style target directly
- **Enemy sprites**: the Marauder, the Lich, and especially **The Dicelord** (hooded horned figure with dice) — best existing reference for the character direction
- `power_glyph.png` — the ✦ mark
- The **dice face textures** (`blue6.png` etc.) so the die design stays consistent with the game
- The palette table from §5
- **3–5 comparison capsules** for tone calibration: *Slay the Spire* (character + readable silhouette), *Monster Train*, *Griftlands*, *Astrea: Six-Sided Oracles* and *Dicey Dungeons* (as **counter**-examples — "not this look, but this is my genre neighborhood")

---

## 9. Where to hire, and roughly what it costs

**Where:**
- **ArtStation** — job board + browse artists with game key art in their portfolio, then DM
- **Bluesky / Twitter** `#PortfolioDay`, `#gameart` — many indie-friendly illustrators post availability
- **Reddit** — r/gameDevClassifieds, r/HungryArtists (both have paid-work posting formats)
- **Fiverr Pro** — faster and more transactional, quality varies more
- **Your existing contacts** — Jenya already did your enemy sketches. Ask her first, or ask her for a referral. An artist already fluent in your game's look is worth more than a stronger portfolio that has to learn it from scratch.

**Budget:** indie capsule/key art commissions commonly land somewhere in the **low hundreds to under a thousand USD**, depending heavily on the artist's experience, the complexity of the piece, and whether the full crop set is included. Get two or three quotes before committing — the spread is wide.

**How to run it well:**
- Ask for a **sketch/thumbnail stage** before rendering, with 2–3 rough compositions to choose from. Catching a composition problem at sketch stage costs nothing; catching it at final render costs a repaint.
- Agree upfront on **how many revision rounds** are included.
- Send **everything in §8 in the first message.** The single biggest cause of bad commissions is a thin brief — this document exists so that doesn't happen to you.

---

*Written 2026-08-06. Steam capsule dimensions should be re-verified against the current Steamworks documentation before final export.*
