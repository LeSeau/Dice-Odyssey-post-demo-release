# Card Art Prompt Guide

How to write generation prompts that match this game's card art. Derived from the prompt
that produced the good **Block** card, then hardened over five failed rounds on 2026-08-18.

**Live prompt deck (all current card/icon prompts, copy buttons, progress tracking):**
https://claude.ai/code/artifact/4c343e1e-5cc6-4303-bb44-c1b6ebda913e

---

## 1. The template

Copy this whole thing. Change **only the three bracketed slots**. Do not "improve" the
rest — every clause in it is load-bearing (see §3).

> **[SUBJECT SENTENCE]** Bold ink-outlined comic book illustration in the style of Slay the
> Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black
> linework, dominant **[COLOR]**-and-black color palette, the background filled edge to edge
> with a radiating burst of **[TINT]** light shards, brightest behind the subject and fading
> to darker **[TINT]** tones at the corners, never pure black. Not photorealistic, not a 3D
> render, not glossy or overly detailed. No text, no numbers, no card border or frame, no
> watermark.

**The three slots:**

| Slot | What goes in | Examples |
|---|---|---|
| `[SUBJECT SENTENCE]` | One flowing sentence describing a physical action. See §2. | *"A crimson die pressed against a spinning whetstone, a bright fan of sparks flying from the grind, the remaining pips glowing hotter."* |
| `[COLOR]` | The dominant hue, hyphenated with black | `crimson`, `gold`, `royal-blue`, `iron-grey`, `violet-purple`, `amber-orange` |
| `[TINT]` | The burst color — normally the same family as `[COLOR]` | `fiery red`, `golden`, `silvery blue`, `sickly violet` |

Worked example (Red Edge, "remove the 2 lowest faces from Red Dice"):

> A crimson die pressed against a spinning whetstone, a bright fan of sparks flying from the
> grind, the remaining pips glowing hotter. Bold ink-outlined comic book illustration in the
> style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged
> highlights, thick black linework, dominant crimson-and-black color palette, the background
> filled edge to edge with a radiating burst of fiery red light shards, brightest behind the
> subject and fading to darker fiery red tones at the corners, never pure black. Not
> photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no
> card border or frame, no watermark.

---

## 2. Writing the subject sentence

**Read the card's EFFECT, not its name.** This is the rule that produced the worst miss of
the session: *Dead Weight* is an unplayable card that sits in your hand **granting Loaded** —
i.e. it BUFFS your dice — and it got drawn as a cursed ball-and-chain, which reads as a
penalty. Rewritten as a colossal die planted like an anvil, radiating rings of golden light
that make nearby dice glow brighter, it reads as the buff it is.

So, before writing: *what does this card DO to the player?* Then:

- **A buff must look like a gift** — warm light, something being strengthened, the player's
  dice glowing brighter. Not chains, not decay, not something being taken away.
- **A debuff/curse looks ominous** — but only when it's aimed at the ENEMY (Effigy is the
  only card in the batch that legitimately gets the sinister treatment).
- **One sentence, one action.** A physical, drawable moment — hands doing something, an
  object mid-transformation, an impact. Not an abstract concept.
- **Include dice** wherever it makes sense. Dice are the game's visual signature; a card with
  no die in it stops looking like a Dice Odyssey card.
- **Say what the effect literally does** when it's depictable: Counterfeit shows the forger
  *carving the lowest face into a six*, which is precisely the card's rules text.
- **Show the mechanic, never the number.** Charge, Scout, Refuel and friends should be
  *readable* in the image — dice being fed light, ghostly faces of possible rolls, a die
  materialising — but never counted out. "A fan of five die-faces" for Scout 5 dates the art:
  the upgraded card shares the exact same PNG (all `_plus.tres` point at the same file), and
  the base number gets retuned anyway. Draw *a spread* of ghost faces, *dice* tumbling into
  the tray, *cards* spraying out — quantity left vague on purpose.
- **Aim at the fantasy, not the rules text.** "Deal X damage and gain X Block" is one armoured
  charge that hits and guards in the same motion; "Exact 21: kill" is one perfect cut that
  ends anything regardless of size. Cards get re-costed and re-gated constantly — art tied to
  the *feeling* of the effect survives that, art tied to a specific condition does not.

---

## 3. Why each clause matters

Don't drop these — each one exists because its absence broke a round of generation:

| Clause | Without it you get |
|---|---|
| `flat cel-shaded coloring` | Glossy, engraved, metallic 3D-looking renders |
| `in the style of Slay the Spire card art` | Generic fantasy illustration; this is the strongest single anchor |
| `thick black linework` | Soft painterly edges that don't match the deck |
| `dominant [COLOR]-and-black palette` | Muddy multi-color images with no identity |
| `background filled edge to edge … never pure black` | Empty black voids (GPT reads "dark background" as literally black) |
| `brightest behind the subject, fading to darker [TINT] at corners` | Flat, evenly-lit backgrounds with no focus |
| `Not photorealistic, not a 3D render, not glossy or overly detailed` | Overcooked, over-rendered images |
| `No text, no numbers, no card border or frame, no watermark` | Fake card frames and gibberish text baked into the art |

---

## 4. Failure log — five approaches that did NOT work

Don't retread these. Each was tried on 2026-08-18 and rejected:

1. **"Dark fantasy, painterly, rich colors"** → soft multi-color paintings, wrong medium
   entirely. (Written from documentation instead of looking at the actual art.)
2. **"Explosive radial burst + speed lines + flying debris shards + jagged hatching"** →
   wall-to-wall yellow spike confetti filling every square inch of every image. The single
   worst offender: over-specifying the background gets you a background made of noise.
3. **"Deep black background"** → literal empty voids. The shipped cards have colored
   light-fields, not blackness.
4. **"Rich saturated colors, dramatic glowing light"** → overcorrection; glossy, blown-out,
   engraved-metal look.
5. **Attaching a reference image** → GPT Image 2 copies references far too literally,
   reproducing the reference's composition. **Do not use reference images.** The prompt
   must be self-sufficient.

**Meta-lesson:** when a sibling asset already has a prompt that produced a good result,
copy its structure verbatim rather than theorizing a new style description. Four rounds were
wasted before the working Block prompt was used as the template.

---

## 5. Generator settings

- **Cards: Wide (3:2)** — matches the shipped card art exactly (strike_v3, meteor,
  low_roller, dicelord_gift are all 1.5:1), so nothing gets cropped on integration.
- **If a batch comes out Square by mistake, EXPAND it — never crop it.** These prompts
  compose vertically (Coiled Spring stacks ghost dice above the die and puts the spring
  below it; Sleight's whole gesture is the gap between the hand and the die), so a 3:2
  window has to delete one end of the composition. Use Firefly's Generative Expand,
  widen left and right only, leave the fill prompt empty. What it has to invent is just
  more radiating background, which is the easiest fill there is. Watch for a duplicate
  subject appearing in the new strip, and for a brightness step at the seam.
- **Icons: Square (1:1)** — relic icons, status icons, the mech arrow.
- **No reference images** (see failure #5).
- If one generation comes out wrong but the prompt is right, **re-roll before re-writing** —
  variance between generations is larger than most prompt tweaks.

---

## 6. Icons are a DIFFERENT family

Relic icons, status icons and UI arrows do **not** use the card template. They're flat
cel-shaded objects on a chroma-key background, designed to read at ~30px:

> Game [relic/status] icon: **[SUBJECT]**, flat cel shading with two or three tones, thick
> near-black outline, bold simple silhouette readable at 30 pixels, single centered object on
> a solid pure **[green or magenta]** background, no text, no glow.

Chroma key color: **green** normally; **magenta** when the subject itself contains green.
Always add **"no [key colour] anywhere in the subject itself"** to the prompt — the Artillery
icon came back with a green sling that fought its own key background.

**Two icon failure modes that a re-roll will NOT fix** (change the concept instead):

1. **The shape collapses into a known UI glyph.** "A rounded square with two rectangular
   slots side by side" is a *pause button*, and that's what came back every time. Break the
   symmetry and add die-ness: view the die at a three-quarter angle so pips show, and put
   actual *cards* in the slots, fanned at uneven angles.
2. **The subject borrows the key colour.** See above — name the forbidden colour explicitly
   and pin the subject's own palette ("warm brown timber with dark iron fittings").

General rule: if the described shape could be mistaken for a media control, an arrow, or a
loading spinner, it *will* be. Describe the thing, then describe what makes it *not* that.
Never magenta for a purple/violet subject — the keying pipeline can't separate them (a purple
skull once came out 38% transparent).

---

## 7. Shipped style anchors

When judging whether a generation fits, compare against these (repo root): `strike_v3.png`,
`meteor.png`, `low_roller.png`, `dicelord_gift.png`, plus the Block card art. Look at them at
**actual card size**, not full-resolution — detail that reads at 2K disappears at 140px.

---

## 8. Integration (handled by Claude, don't do this by hand)

- Save each keeper under the filename shown on its deck card, all in one folder, then point
  Claude at the folder.
- Card art: cropped to 3:2, no keying needed.
- Icons: chroma-keyed (distance ramp → blob cleanup → interior fill → premultiplied resize).
- **Never overwrite a shared placeholder in place** — several new cards currently borrow art
  from older cards (`high_roller.png` is shared 6 ways), so each new card gets its own PNG and
  its `.tres` is repointed.
- Mech arrow is the exception: it's a dedicated file, so it's overwritten in place with the
  ink normalized for the 57×85 cover-crop buttons (zero scene edits).
- `--headless --import` after any PNG drop, then render verification. Lands in an
  editor-closed window.
