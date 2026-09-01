# Art prompts — T0 rework (2026-09-01)

Four assets. Written against `card_art_prompt_guide.md` (§6 icon family, §5 settings, §4
failure log). Copy each prompt whole — every clause is load-bearing.

**Generator settings: all four are Square (1:1). No reference images** (GPT Image 2 copies
them far too literally — failure #5). If one generation is wrong but the prompt is right,
**re-roll before re-writing**: variance between generations beats most prompt tweaks.

Save keepers under the exact filenames below, all in one folder, then point me at the folder.
I handle keying/cropping/import — don't clean them up by hand.

---

## 1. `dice_mimic.png` — the Dice Mimic (enemy body)

Enemy art, not card art: no radiating background burst, and it needs a flat key-able
background because it gets cut out. White background + hole-punch is the pipeline that
worked for the Skeleton / Marauder / Lich replacements, and this subject genuinely needs
holes punched (gaps between the teeth, under the lid).

> A hulking treasure chest monster: its hinged lid is a wide open jaw lined with splintered
> wooden teeth, a fat tongue lolling out with dice scattered across it, one glowing blue die
> clenched between its front teeth, two small glinting eyes deep under the raised lid,
> stubby clawed feet under the box, rusted iron bands and a snapped padlock hanging off the
> front. Full-body single creature, standing, three-quarter view, menacing. Bold
> ink-outlined comic book illustration in the style of Slay the Spire enemy art, flat
> cel-shaded coloring with graphic hard-edged highlights, thick black linework, warm brown
> timber with dark iron fittings and tarnished gold trim. Not photorealistic, not a 3D
> render, not glossy or overly detailed. Plain solid pure white background, no scenery, no
> ground, no cast shadow, no white or near-white anywhere on the creature itself. No text,
> no numbers, no border, no watermark.

**Why this subject:** the fantasy is "it swallowed one of your dice and gives it back when
you hurt it enough", so the die must be visibly *held* — in the teeth, not on the floor.
Blue specifically because white/cream would fight the white key background, and Blue reads
as "one of yours".

**Watch for when picking:** a closed chest (needs an open maw), a friendly/cute face (it's
an enemy), or any large white area on the creature — that last one will punch holes in the
body during keying.

---

## 2. `dice_hostage_status_icon.png` — hostage status icon

Sits on the Mimic's status row and renders at **30px**. Keep it brutally simple.

> Game status icon: a single die wrapped tightly in an iron chain with a small closed
> padlock resting against it, the die tilted at a three-quarter angle so its pips show, flat
> cel shading with two or three tones, thick near-black outline, bold simple silhouette
> readable at 30 pixels, single centered object on a solid pure green background, no green
> anywhere in the subject itself, no text, no glow.

**Watch for:** more than ~3 chain links (turns to mush at 30px), or a die so small the
chain dominates. The die should be the biggest thing in the frame.

---

## 3. `dice_debuff_intent.png` — "will tamper with your Dice" intent icon

Joins the intent family (sword / shield / up-arrow / skull) — that family **swaps as a
block, never mixed**, so this has to match it: 500×500, flat 2-tone, thick near-black
outline. Renders at **60px** above the enemy's head.

> Game combat intent icon: a dark clawed hand closing around a single die, the die tilted at
> a three-quarter angle so its pips show, violet energy leaking out between the claws, flat
> cel shading with two or three tones, thick near-black outline, bold simple silhouette
> readable at 60 pixels, single centered object on a solid pure green background, no green
> anywhere in the subject itself, no text, no glow.

**Why a claw and not a crack:** a cracked die is already taken — the Evil die's 0 face is a
crack, so a cracked-die icon would read as "Evil rolled a zero". Violet keeps it in the same
emotional family as the skull without being the skull.

**Watch for:** the claw eating the die (the die must stay the dominant shape), or the hand
reading as a generic blob. Fingers should be countable at 60px.

---

## 4. `junk_card_intent.png` — "will give you bad cards" intent icon

Not used yet — this is for the act-2 junk-card plan. Same family rules as #3.

> Game combat intent icon: a small fan of three tattered playing cards with torn frayed
> edges, violet rot creeping up from their bottom edges, the middle card cracked down the
> center, flat cel shading with two or three tones, thick near-black outline, bold simple
> silhouette readable at 60 pixels, single centered object on a solid pure green background,
> no green anywhere in the subject itself, no text, no numbers on the cards, no glow.

**Watch for:** card faces with symbols or pips baked on (it must not read as a real playing
card), or a fan so wide it loses its silhouette. Three cards, tight fan.

---

## Notes that apply to all four

- **Green key, never magenta**, on all three icons — every one of them has violet in the
  subject, and the keying pipeline cannot separate violet from magenta (a purple skull once
  came out 38% transparent).
- The "no [key colour] anywhere in the subject" clause is not optional: the Artillery icon
  came back with a green sling fighting its own background.
- Judge at **actual display size** (30px / 60px / in-combat), not at 2K. Detail that reads at
  full resolution disappears entirely at icon size.
- If an icon's shape could be mistaken for a media control, an arrow, or a loading spinner,
  it will be — that's a concept problem, not a re-roll problem.
