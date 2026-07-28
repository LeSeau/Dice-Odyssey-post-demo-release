# Map icon regeneration prompts (2026-07-26 → 27)

Every prompt below is **complete and self-contained** — copy one, paste it, generate. No assembly.

## Status of the set

| icon | state | live file | mult |
|---|---|---|---|
| fight | ✅ replaced (round 7) | `fight_icon_v3.png` | 0.415 |
| campfire | ✅ replaced (round 5) | `campfire_icon_v2.png` | 0.457 |
| shop | ✅ replaced (round 6) | `shop_icon_v3.png` | 0.458 |
| event | ✅ replaced (rounds 4 + 8) | `event_icon_v11.png` | 0.441 |
| elite | ✅ kept, resized only | `elite_fight_icon_v2.png` | 1.05 |
| boss | ✅ kept, Julien's call — do not re-propose | `boss_icon_v3.png` | 1.0 |
| treasure | ⏳ **only one still open** — see §7b | `treasurenobg.png` | 0.91 |

**The four rules every failure in this file reduces to**, worth re-reading before any new generation:

1. **The meaning must BE the silhouette**, not a detail painted on a bigger object. Killed the
   signposts, the scrolls, the die-in-eye-socket and the die-in-helmet-dent.
2. **No large pale or cream areas.** The map is cream parchment. Killed the scrolls (22–25% of
   pixels camouflaged) and the bright skull (27–37%, the worst result recorded).
3. **Two contrasting materials, not one.** Paper-separation and internal legibility are independent:
   the leather satchel had the *best* separation ever measured (0% camouflaged) and still failed,
   because one uniform brown mass has nothing to read inside it at 60px.
4. **Judge against the set, not in isolation.** The charcoal event die was fine alone but was the
   only desaturated icon (0.39 vs 0.74–0.91) on a screen showing all six at once.

And the meta-lesson: **measure the incumbent before hunting for a replacement.** The original fight
icon already had the best internal contrast in the set; three rounds were spent looking for a
replacement when the answer was to repaint it.

> ## ⚠️ Round 1 result — read this before generating the event icon again
>
> Six event candidates (3 signpost, 3 scroll) were generated, cleaned through the real pipeline and
> dropped into the real map at real size. **Both concepts failed the size test, despite the art
> itself being excellent.** See "Round 2" at the bottom of this file for the corrected prompts.
>
> - **Scrolls camouflage.** Measured: 22–25% of a scroll's pixels land within 25 luminance of the
>   parchment it sits on — because a cream scroll on a cream parchment map *is* the same material.
>   In-engine, the paper body dissolves and only the teal wax seal survives as a small dot.
> - **Signposts survive but don't communicate.** They keep a silhouette (~1% low-contrast pixels,
>   which is fine), but at 60px the arms, post, rope, base and hanging die out-compete the `?`, and
>   the icon reads as a green cluttered blob.
> - **Root cause, and the thing to fix:** in both concepts the `?` is *a small detail on a larger
>   object*. At 60px the object wins and the `?` loses. The current icon — for all that it's a flat
>   glyph — reads instantly because the `?` **is** the silhouette. That property is worth more than
>   object-ness, and Round 2 keeps both.

Verdicts from Julien on the current set: **elite = liked**, **treasure = okay**, **event = rejected**
("big & purple"), **fight / campfire / shop / boss = "could be better"**. Elite and treasure are not
in this doc — they stay as they are.

---

## 1. EVENT — Option A: signpost *(recommended)*

Keeps the `?` that roguelike players expect, but turns it into a painted object instead of a bare UI
glyph. Teal, deliberately not purple.

```
A weathered wooden signpost planted at a crossroads, its plank arms pointing in different
directions, with a large question mark carved and burned deep into the main board. Old rope binding,
iron nails, and a small carved die hanging from one arm. Teal-green painted wood accents over warm
brown timber. Game map icon: single centered object, 3/4 view with a slight top-down angle,
hand-painted cel-shaded fantasy style with 2-3 flat tone steps and no soft airbrush gradients, thick
dark brown outline around the whole silhouette, warm saturated palette with gold accents, crisp rim
highlight along the upper edges. Chunky readable shape, bold and simple enough to stay legible when
shrunk to a small icon. Flat solid magenta background. No shadow, no text, no border, no scenery.
Square image.
```

## 2. EVENT — Option B: sealed scroll

Best fit with the parchment-map fantasy. Same teal reasoning.

```
A rolled-up old parchment scroll tied with a ribbon and sealed with a thick blob of wax stamped with
a question mark. Slightly frayed edges, a small die tucked into the ribbon. Warm cream parchment,
deep teal wax seal, gold ribbon. Game map icon: single centered object, 3/4 view with a slight
top-down angle, hand-painted cel-shaded fantasy style with 2-3 flat tone steps and no soft airbrush
gradients, thick dark brown outline around the whole silhouette, warm saturated palette with gold
accents, crisp rim highlight along the upper edges. Chunky readable shape, bold and simple enough to
stay legible when shrunk to a small icon. Flat solid magenta background. No shadow, no text, no
border, no scenery. Square image.
```

---

# THE REMAINING ICONS — rewritten after the event-icon rounds

The event icon took four rounds. These prompts bake in what those rounds proved, so the rest should
take one or two.

**What the rounds established:**

1. **The subject must BE the silhouette.** Rounds 1 and 2 failed because the `?` was a detail painted
   on a bigger object; at 60px the object won and the meaning lost. Whatever a room icon means, that
   meaning has to be the whole shape.
2. **Nothing cream, tan or pale-dominant.** The map is cream parchment. The round-1 scrolls measured
   22–25% of their pixels within 25 luminance of the background and visually dissolved.
3. **The key element needs contrast against its own body, not just against the map.** A gold outline
   on teal scored 40.9 internal contrast and read as texture; solid gold on charcoal scored 53.6 and
   reads as a symbol.
4. **Colour families are now spoken for.** Blue = fight. Crimson + gold = elite. Orange = campfire.
   Brown + gold = treasure. Purple = shop and boss. **Charcoal + glowing gold = event (new).** Don't
   let a new icon wander into a neighbour's hue.

**⚠️ One consequence of the new event icon: it is a CUBE.** The fight icon is currently a big blue
die with swords behind it, so two of six icons now read as dice. The fight prompt below deliberately
demotes the die to a small accent and puts the crossed swords in charge of the silhouette.

---

## 3. CAMPFIRE

Currently the least-finished icon: flat orange gradient flame, plain logs, no embers or glow. Same
subject, painted to the elite/treasure standard.

```
A small campfire: two or three crossed split logs with visible bark and wood grain, a bright flame
rising from glowing orange embers between them, a few sparks drifting upward. Warm orange and yellow
flame with a hot white core, deep amber glow spilling onto the logs, cool shadow underneath for
contrast. Game map icon: single centered object, 3/4 view with a slight top-down angle, hand-painted
cel-shaded fantasy style with 2-3 flat tone steps and no soft airbrush gradients, thick dark brown
outline around the whole silhouette, warm saturated palette with gold accents, crisp rim highlight
along the upper edges. Chunky readable shape, bold and simple enough to stay legible when shrunk to a
small icon. Flat solid magenta background. No shadow, no text, no border, no scenery. Square image.
```

---

## 4. FIGHT — ✅ SOLVED (round 7): `fight_icon_v3.png`, mult 0.415

**The answer was to repaint the original composition, not replace it** — big bright blue die framed
by crossed swords, with the round-5 wash-out fixed by making the blades *dark blued steel* instead of
pale silver. Measured against the icon it replaced: separation **126.4 vs 115.8**, camouflaged pixels
**4% vs 5%**, internal contrast 55.8 vs 60.2. Better on the two that were failing, marginally lower on
the one that was already fine.

**The bright-skull attempt failed spectacularly and is the cleanest proof of the parchment rule in the
whole exercise: 27–37% of its pixels landed within 25 luminance of the background** — worse than the
round-1 scrolls (22–25%) that started this whole line of investigation. Pale bone on cream paper
dissolves, and no amount of internal detail rescues it; the dark browband and blue eye survived while
the skull itself vanished. Helmets measured fine (114–117 / 5–6%) but the die became a small accent
again and got lost.

The history below is kept because the four-point spec it produced is what made round 7 work first try.

<details>
<summary>How fight got here — three rejected rounds</summary>

Nothing has replaced the original fight icon yet. Three concepts have been tried and rejected, and
the reasons stack into a clear spec.

**Rejected so far:**

- **Crossed swords, pale steel blades** (round 5) — measured *worse* than the incumbent: dL 83–95
  and 14–21% camouflaged pixels, versus 115.8 / 5%. Large pale blades on cream parchment is the
  scroll failure again. Never installed.
- **Green goblin head** (round 6) — Julien: *"I really don't like the green goblin icons."*
- **Dark helmeted skull with a die in the eye socket** (round 6) — great art, and it does read, but
  in the in-map render **the whole map goes dark**. Internal contrast 29.5–34.0, right at the
  warning threshold. Julien: *"clearly the skull is too dark."*

**The spec these failures imply — check a candidate against all four:**

1. **It must be LIGHT.** Fight is by far the most common room type, so its value sets the tone of the
   entire screen. A dark fight icon makes the map heavy no matter how good the art is.
2. **It must not be a head.** The elite is a head; two head-shaped icons at the same size compete,
   and only the elite's red is separating them.
3. **No large pale-steel areas.** Same camouflage trap as the parchment scrolls.
4. **Any bright accent must be BIG.** A die in an eye socket or a dent is a small detail on a bigger
   object — the exact failure mode that killed the round-1 signposts, one level down.

**⚠️ And the thing that reframes all of it: the incumbent icon measures BEST of anything tested.**
`normal_fight_icon_v2.png` scores internal contrast **60.2** — the highest in the set — with 115.8
separation and 5% camouflage. Julien's objection was always stylistic ("could be better"), never
legibility. The blue die also coexists fine with the dark event die (proven in the round-5 render:
different value, different hue, no confusion), which retires the earlier "two cubes on the map"
worry that made me demote the die in the first place. **So the recommended move is to repaint the
existing composition rather than replace it** — Option A below.

</details>

### ✅ Option A — repaint the current concept — THIS ONE SHIPPED

```
A bright blue six-sided die with crisp white pips, large and central, framed behind by two crossed
swords angled in an X. The blades are dark blued steel with deep shadow so they stay distinct against
a light background, with gold crossguards and gold pommels and worn leather grips. The die is the
dominant element, roughly half the icon's height, glossy and vivid. No motion lines, no impact marks,
no sparks. Game map icon: single centered object, 3/4 view with a slight top-down angle, hand-painted
cel-shaded fantasy style with 2-3 flat tone steps and no soft airbrush gradients, thick dark brown
outline around the whole silhouette, crisp rim highlight along the upper edges. Chunky readable shape,
bold and simple enough to stay legible when shrunk to a small icon. Flat solid magenta background. No
shadow, no text, no border, no scenery. Square image.
```

### Option B — brighter skull *(keeps the creature-with-humour idea, inverts the mass)*

```
A weathered skull with a small blue six-sided die wedged into one eye socket in place of the eye,
giving it a comically lopsided expression, wearing only a narrow dark iron browband rather than a full
helmet. The skull is warm pale bone, bright and light-toned, filling most of the icon; the metal band
is a thin dark accent across the brow. The die glows bright blue. Slightly goofy rather than
terrifying. Game map icon: single centered object, 3/4 view with a slight top-down angle, hand-painted
cel-shaded fantasy style with 2-3 flat tone steps and no soft airbrush gradients, thick dark brown
outline around the whole silhouette, crisp rim highlight along the upper edges. Chunky readable shape,
bold and simple enough to stay legible when shrunk to a small icon. Flat solid magenta background. No
shadow, no text, no border, no scenery. Square image.
```

### Option C — dented helmet with a die lodged in it *(armour, so it's combat without being a face)*

```
A battered horned warrior's helmet lying at a slight tilt, empty, with a bright blue six-sided die
lodged firmly in a fresh dent on its side. Polished warm bronze and steel helmet with visible dents
and scratches, short curved horns, dark eye slits. The blue die is vivid and clearly wedged into the
metal. Slightly comical, like someone threw the die hard enough to stick it. Game map icon: single
centered object, 3/4 view with a slight top-down angle, hand-painted cel-shaded fantasy style with 2-3
flat tone steps and no soft airbrush gradients, thick dark brown outline around the whole silhouette,
warm saturated palette with gold accents, crisp rim highlight along the upper edges. Chunky readable
shape, bold and simple enough to stay legible when shrunk to a small icon. Flat solid magenta
background. No shadow, no text, no border, no scenery. Square image.
```

---

### ~~Earlier fight prompt (round 5)~~ — superseded, see above

Two problems: it's busy (two swords + a big die + comic speed lines), and **now that the event icon
is a cube, a die-dominant fight icon makes two of six icons read as dice.** The swords take over the
silhouette here and the die shrinks to an accent at the crossing point. The blades also pick up the
elite's gold so the two weapons read as the same metal family.

```
Two broad swords crossed in a bold X, filling the frame, with a small blue six-sided die nestled at
the point where the blades cross. Polished steel blades with gold crossguards and gold pommels, worn
leather-wrapped grips. The die is a small accent, roughly a quarter of the icon's height, bright blue
with white pips. No motion lines, no impact marks, no sparks. Game map icon: single centered object,
3/4 view with a slight top-down angle, hand-painted cel-shaded fantasy style with 2-3 flat tone steps
and no soft airbrush gradients, thick dark brown outline around the whole silhouette, warm saturated
palette with gold accents, crisp rim highlight along the upper edges. Chunky readable shape, bold and
simple enough to stay legible when shrunk to a small icon. Flat solid magenta background. No shadow,
no text, no border, no scenery. Square image.
```

---

## 5. SHOP — must NOT look like the top-bar Dice Shop icon

**⚠️ Julien's catch, and it invalidated the original prompt here.** `dice shop clean outline.png`
(the top-bar Dice Shop button) is *already* a market stall with a striped awning, dice and coins —
which is nearly word-for-word what the first version of this prompt asked for. It would have produced
a near-clone. Two things make the clash worse than a general resemblance:

- **That icon already renders on the map.** It's the "you can afford a Dice" badge shown on every
  clickable room (`map_room.tscn`, `AffordableBadge`), so the two can sit ~30px apart on screen.
- **The map SHOP room is the CARD shop**, not the dice shop — cards, relics, the removal service and
  one deal die. Building its icon from dice and coins points at the wrong destination.

So the subject changes entirely: **cards and relics, no stall, no awning, no dice, no coin piles.**
Purple stays — that's the shop's established hue.

### ⚠️ ROUND 6 — the satchel shipped, then failed in play. Read this first.

The leather satchel (`shop_icon_v2.png`) was installed and **Julien rejected it: "shop isn't great,
it doesn't read very well at this size."** The measurement had already flagged why, and it's worth
keeping as a rule: **internal contrast 30.7, the lowest of any icon in the set** (vs 41.2 for the old
shop icon, 53.6 for the event die). It separates from the parchment perfectly — 0% camouflaged
pixels, the best score anything achieved — but it is a single uniform brown mass, so at 60px there is
nothing *inside* it to read. Paper-separation and internal legibility are independent problems, and
an icon can ace one while failing the other.

**Also rejected: any card-led concept.** Julien: *"I don't like the idea of showing cards for a shop,
especially since he's also selling relics & dice."* The shop sells cards, relics and a deal die, so
a card-only icon misrepresents it. The two fanned-card prompts below are kept as a record; do not
re-propose them.

**The direction Julien wants is a classic bag** — the concept was never the problem. Two structural
fixes over the satchel:

- **Two high-contrast masses, not one.** A dark pouch with bright gold spilling out gives exactly two
  things to read at map size.
- **Not brown.** Brown leather put the shop in the treasure chest's colour family — two brown
  containers on one map. Purple is the shop's established hue and separates cleanly.

#### Option A — purple coin pouch *(recommended: only two elements)*

```
A plump drawstring coin pouch made of deep royal purple velvet, tied at the neck with a gold cord,
tipped slightly open with bright gold coins spilling out of the top and a few resting at its base.
Strong contrast between the dark purple fabric and the bright gold coins. Simple bold two-part
composition, minimal surface detail. Not brown leather, no market stall, no awning, no dice, no
playing cards. Game map icon: single centered object, 3/4 view with a slight top-down angle,
hand-painted cel-shaded fantasy style with 2-3 flat tone steps and no soft airbrush gradients, thick
dark brown outline around the whole silhouette, crisp rim highlight along the upper edges. Chunky
readable shape, bold and simple enough to stay legible when shrunk to a small icon. Flat solid green
background. No shadow, no text, no border, no scenery. Square image.
```

#### Option B — pouch with a relic *(one extra element, to say "sells more than gold")*

```
A plump drawstring coin pouch made of deep royal purple velvet, tied at the neck with a gold cord,
with bright gold coins spilling from the top and a single ornate gold amulet with a glowing gem lying
beside it. Strong contrast between the dark purple fabric and the bright gold coins and amulet.
Simple bold composition with only two or three elements, minimal surface detail. Not brown leather,
no market stall, no awning, no dice, no playing cards. Game map icon: single centered object, 3/4
view with a slight top-down angle, hand-painted cel-shaded fantasy style with 2-3 flat tone steps and
no soft airbrush gradients, thick dark brown outline around the whole silhouette, crisp rim highlight
along the upper edges. Chunky readable shape, bold and simple enough to stay legible when shrunk to a
small icon. Flat solid green background. No shadow, no text, no border, no scenery. Square image.
```

---

### ~~Option A — fanned cards + relic~~ *(REJECTED — card-led concept, see above)*

```
A fanned hand of three thick playing cards standing upright and slightly spread, with an ornate golden
amulet on a chain resting in front of them. The card backs are deep royal purple with gold filigree
borders and rounded corners. The amulet has a glowing gemstone at its centre. No dice, no coins, no
market stall, no awning. Game map icon: single centered object, 3/4 view with a slight top-down angle,
hand-painted cel-shaded fantasy style with 2-3 flat tone steps and no soft airbrush gradients, thick
dark brown outline around the whole silhouette, warm saturated palette with gold accents, crisp rim
highlight along the upper edges. Chunky readable shape, bold and simple enough to stay legible when
shrunk to a small icon. Flat solid green background. No shadow, no text, no border, no scenery.
Square image.
```

### ~~Option B — merchant's satchel~~ *(SHIPPED then REJECTED — uniform brown mass, see round 6 above)*

```
An open merchant's leather satchel with a brass buckle, packed full, with the tops of several purple
playing cards sticking out of it and an ornate golden amulet with a glowing gem hanging off the side.
Rich brown tooled leather, deep royal purple card backs with gold trim. No dice, no coins, no market
stall, no awning. Game map icon: single centered object, 3/4 view with a slight top-down angle,
hand-painted cel-shaded fantasy style with 2-3 flat tone steps and no soft airbrush gradients, thick
dark brown outline around the whole silhouette, warm saturated palette with gold accents, crisp rim
highlight along the upper edges. Chunky readable shape, bold and simple enough to stay legible when
shrunk to a small icon. Flat solid green background. No shadow, no text, no border, no scenery.
Square image.
```

**To check in the in-map render:** purple cards with gold trim sit near the elite icon's crimson and
gold. Different silhouettes, so it should be fine — but that's exactly the kind of clash that only
showed up in-engine for the cyan die, so don't call it until it's rendered.

---

## 6. BOSS — ✅ SETTLED, KEEPING THE CURRENT ICON

**Julien's call (2026-07-27): "I wanna keep my current boss icon."** Do not regenerate it, and do not
re-propose changing it. The prompt below is kept only as a record of what was written before that
decision.

<details>
<summary>unused prompt</summary>

**GREEN background** — the portal glow is purple. Lean hard into the purple: the new event icon is
also a dark shape with a glow, and purple is what keeps these two clearly apart (the boss also
renders about 5× larger, so the risk is small).

```
A circular stone gateway of rough-hewn blocks with a glowing purple void inside, and the dark
silhouette of a horned monster looming within it with two burning orange eyes. Heavy weathered stone
ring with cracks and moss, intense purple light spilling outward and lighting the stone rim. Game map
icon: single centered object, front view, hand-painted cel-shaded fantasy style with 2-3 flat tone
steps and no soft airbrush gradients, thick dark brown outline around the whole silhouette, crisp rim
highlight along the upper edges. Chunky readable shape, bold and simple enough to stay legible when
shrunk to a small icon. Flat solid green background. No shadow, no text, no border, no scenery.
Square image.
```

</details>

---

## 7b. TREASURE — the last outlier (round 8)

Once the other five were rebuilt, treasure became the measurably weakest icon in the set:
**internal contrast 42.3**, against 50.3–58.9 for everything else, and the darkest at mean luminance
51. The cause is visible at 3× — it is brown-on-brown: chest body, bands and emblem all sit in one
material family, where every other icon pairs two contrasting materials (blue+gold, teal+gold,
purple+gold, orange+wood, crimson+gold).

**The fix is the same structural one that rescued the shop: two contrasting masses.** Open the chest
so dark wood sits against bright gold, instead of one closed brown block.

**⚠️ And keep it from rhyming with the shop pouch**, which is also "container + gold". Separation
comes from two places: silhouette (angular chest with a raised lid vs soft rounded pouch) and
contents — the treasure room awards a **relic**, so a glowing gem reads more accurately than loose
coins *and* keeps the two icons distinct.

### Option A — open chest with a glowing relic *(recommended: semantically right, and the glow lifts it out of being the darkest icon)*

```
An open wooden treasure chest seen at a slight angle, its lid raised, with an ornate golden amulet
holding a large glowing gem resting inside on a small pile of gold coins. The chest is dark walnut
wood with black iron bands and corner fittings; the contents are bright warm gold with a soft glow
spilling up out of the open lid. Strong contrast between the dark chest and the bright glowing
interior. Angular boxy silhouette with a clearly raised lid. Game map icon: single centered object,
3/4 view with a slight top-down angle, hand-painted cel-shaded fantasy style with 2-3 flat tone steps
and no soft airbrush gradients, thick dark brown outline around the whole silhouette, crisp rim
highlight along the upper edges. Chunky readable shape, bold and simple enough to stay legible when
shrunk to a small icon. Flat solid magenta background. No shadow, no text, no border, no scenery.
Square image.
```

### Option B — overflowing chest *(if it should read "loot" more than "one relic")*

```
An open wooden treasure chest seen at a slight angle, lid thrown back, overflowing with bright gold
coins that spill over the front edge, with two or three coloured gemstones glinting among them. The
chest is dark walnut wood with black iron bands and corner fittings; the treasure is vivid warm gold.
Strong contrast between the dark chest and the bright gold pouring out. Angular boxy silhouette with a
clearly raised lid. Game map icon: single centered object, 3/4 view with a slight top-down angle,
hand-painted cel-shaded fantasy style with 2-3 flat tone steps and no soft airbrush gradients, thick
dark brown outline around the whole silhouette, crisp rim highlight along the upper edges. Chunky
readable shape, bold and simple enough to stay legible when shrunk to a small icon. Flat solid magenta
background. No shadow, no text, no border, no scenery. Square image.
```

---

## 7. ELITE — kept, but resized

Elite is the one you liked and treasure is the one you called okay; together they set the bar every
prompt here aims at. Leave them until the rest are done, then look at the set as a whole — if the new
icons land above them, they become the weak ones and it's worth one more pass. Judging that now would
be guessing.

---

## Why these choices (context, not needed to generate)

**The set splits into two sub-styles**, and the ones Julien likes are all in the same half: elite,
treasure and shop are painted 3/4 objects with depth and rim light; fight, campfire and event are
flat symbolic marks. The target is the painted look — an object, not a symbol. That's the single most
useful thing to hold onto.

**Purple collision.** The event `?` and the shop awning are the same purple; at ~60px on parchment
they rhyme. The shop keeps purple, the event moves to teal.

**The die motif is good branding, keep it.** A die already appears in five of the six icons, and it's
threaded through every prompt above.

**Background colour is not cosmetic.** GPT Image paints a literal checkerboard in flat pixels when
asked for "transparent" — there's no alpha channel to key. And a purple subject sits only ~135 RGB
units from magenta, which lands inside the keying ramp: that's what made the intent-icon skull come
out 38% opaque. Hence magenta by default, green for the two purple-heavy subjects.

**It has to read at ~60px.** Silhouette first — squint at the thumbnail; if you can't tell what it is,
it needs fewer elements, not more detail.

---

# ROUND 2 — event icon, corrected

The rule Round 1 taught: **the `?` must be the silhouette, not a decoration on an object.** Both
prompts below keep the instantly-readable `?` shape the current icon has, and fix the actual
complaint (flat UI glyph, wrong purple) by making it a *painted, carved, physical* `?`.

## R2-A — carved wooden question mark *(recommended)*

The whole icon is the `?` shape. Object-ness comes from material and lighting, not from adding props
around it.

```
A large question mark carved from thick weathered wood, standing on its own as a signboard — the
entire shape of the object is the question mark itself, chunky and rounded, with visible wood grain,
worn chipped edges, and two small iron bolts. Teal-green painted wood with the paint worn away at the
edges to show bare timber underneath, warm gold trim along one edge, and a small gold die resting
against the base of the shape. Game map icon: single centered object, 3/4 view with a slight top-down
angle, hand-painted cel-shaded fantasy style with 2-3 flat tone steps and no soft airbrush gradients,
thick dark brown outline around the whole silhouette, crisp rim highlight along the upper edges.
Chunky readable shape, bold and simple enough to stay legible when shrunk to a small icon. Flat solid
magenta background. No shadow, no text, no border, no scenery. Square image.
```

## R2-B — wax seal medallion

The one element that *did* survive the size test in Round 1 was the round teal wax seal — it held its
shape and colour at 60px. This makes that the whole icon, with the `?` big enough to read.

```
A thick round wax seal medallion with a large question mark deeply embossed across its face, the
question mark filling most of the seal. Scalloped uneven wax edges, deep teal wax with a bright glossy
highlight, a warm gold rim around the outside, and a small gold die attached at the bottom edge. Game
map icon: single centered object, viewed straight on, hand-painted cel-shaded fantasy style with 2-3
flat tone steps and no soft airbrush gradients, thick dark brown outline around the whole silhouette,
crisp rim highlight along the upper edges. Chunky readable shape, bold and simple enough to stay
legible when shrunk to a small icon. Flat solid magenta background. No shadow, no text, no border, no
scenery. Square image.
```

**For both:** the `?` should occupy at least ~70% of the icon's height. If a generation comes back
with the `?` as a small element inside a bigger composition, reject it on sight — that is exactly the
Round 1 failure.

**Keep the teal.** Purple is the shop's colour; the two rhyme at map size.

### ✅ Round 2 result — SHIPPED

Nine candidates generated (5 carved wood, 4 wax seal). **Both concepts passed the size test this
time.** The carved wood won and is now live as `event_icon_v10.png` at a 0.43 multiplier (~69px tall).

The wax seals actually scored *better* on the raw numbers (contrast vs parchment 131–136 against the
wood's 110–125), but lost on two things the measurement can't see:

1. At map size the embossed `?` inside the wax reads poorly — you see a teal disc with *something* in
   it. The wooden `?` is an unambiguous silhouette, and nothing else on the map shares that shape.
2. A round medallion risks re-triggering the "circles on every node" look that's been rejected three
   times now — and it would have sat inside the ink selection ring, circle within circle.

**Size note:** the `?` runs at ~69px rather than the 60px norm. It's a narrow glyph full of holes, so
it needs the extra height to carry the same visual weight as the wide icons beside it — verified by
rendering 60 vs 69 side by side.

**Testing any future candidate takes ~40 seconds:** `debug_map_look.gd` reads `EVENT_ICON` and
`EVENT_MULT` env vars, so a candidate can be dropped into the real map without touching code.

---

# ROUND 3 — event icon as a DIE with question-mark faces

Julien's idea, and a better one than either of mine: the icon becomes a **die whose faces carry `?`
instead of pips**. It says "unknown" *and* it's built from the game's own core motif rather than
importing a new object into the set.

**Two constraints carried over from rounds 1 and 2:**

- **The `?` must fill each visible face.** At 60px a die shows 2–3 faces, each ~25px across. A small
  `?` centred in a large face will vanish — same failure as round 1, one level down.
- **Watch the collision with the FIGHT icon**, which is also a d6. Separation comes from colour (the
  fight die is bright blue) and from silhouette (fight has crossed swords spreading wide behind it,
  the event die stands alone). Worth testing rather than assuming — a tilted/dynamic pose helps.

## R3-A — teal stone die *(closest to the direction already set)*

```
A chunky six-sided die carved from teal-green stone, with a large deeply engraved question mark
filling each visible face instead of pips. Worn chipped edges, gold inlay tracing the edges of the
cube, one face angled toward the viewer. Game map icon: single centered object, 3/4 view with a
slight top-down angle, hand-painted cel-shaded fantasy style with 2-3 flat tone steps and no soft
airbrush gradients, thick dark brown outline around the whole silhouette, crisp rim highlight along
the upper edges. Chunky readable shape, bold and simple enough to stay legible when shrunk to a small
icon. Flat solid magenta background. No shadow, no text, no border, no scenery. Square image.
```

## R3-B — dark obsidian die with glowing marks *(highest contrast against parchment)*

A dark object on a light parchment map is the strongest possible separation, and the glow supplies
the colour accent without needing a bright body.

```
A chunky six-sided die carved from dark obsidian stone, with a large question mark on each visible
face glowing bright cyan as if lit from within, filling each face instead of pips. Deep charcoal-black
stone with sharp chipped edges, a faint cyan light bleeding from the engraved marks. Game map icon:
single centered object, 3/4 view with a slight top-down angle, hand-painted cel-shaded fantasy style
with 2-3 flat tone steps and no soft airbrush gradients, thick dark outline around the whole
silhouette, crisp rim highlight along the upper edges. Chunky readable shape, bold and simple enough
to stay legible when shrunk to a small icon. Flat solid magenta background. No shadow, no text, no
border, no scenery. Square image.
```

## R3-C — weathered painted wooden die

Same material language as the round-2 winner, so it sits naturally beside the other icons.

```
A chunky six-sided die made of weathered wood painted teal-green, with a large question mark burned
and carved into each visible face instead of pips. Paint worn away at the corners showing bare timber
underneath, warm gold trim along the cube's edges, visible wood grain. Game map icon: single centered
object, 3/4 view with a slight top-down angle, hand-painted cel-shaded fantasy style with 2-3 flat
tone steps and no soft airbrush gradients, thick dark brown outline around the whole silhouette,
crisp rim highlight along the upper edges. Chunky readable shape, bold and simple enough to stay
legible when shrunk to a small icon. Flat solid magenta background. No shadow, no text, no border, no
scenery. Square image.
```

## R3-D — tumbling die, mid-air *(maximum separation from the fight icon)*

A tilted, off-axis pose reads as "in play / unresolved" and makes the silhouette clearly distinct from
the fight icon's grounded die.

```
A chunky six-sided die tumbling through the air at a dramatic tilted angle, with a large question mark
filling each visible face instead of pips. Deep purple-teal stone with gold edge inlay, a few small
magical sparkles trailing off its corners. Game map icon: single centered object, dynamic tilted
three-quarter angle, hand-painted cel-shaded fantasy style with 2-3 flat tone steps and no soft
airbrush gradients, thick dark brown outline around the whole silhouette, crisp rim highlight along
the upper edges. Chunky readable shape, bold and simple enough to stay legible when shrunk to a small
icon. Flat solid magenta background. No shadow, no text, no border, no scenery. Square image.
```

---

# ROUND 4 — combining what rounds 3A and 3B each got right

Round 3 worked: **all six dice were legible at 60px**, which neither of the earlier concepts managed.
But testing them in the real map split the result cleanly, and neither half is complete:

| | `?` legibility at 60px | Fits the map |
|---|---|---|
| **B1 obsidian** (cyan glow on black) | **Excellent** — internal contrast 63.0, roughly 1.6× any other candidate | **No.** Cyan/blue is the fight icon's colour family; the map turned into a field of blue-cyan cubes, and the event became the single most eye-catching thing on screen — events shouldn't out-shout elites |
| **A3 teal stone** (gold-outlined `?`) | **Weak** — internal contrast 40.9; the `?` reads as surface texture, not a glyph | **Yes.** Clearly separate from the blue fight dice, gold accents match elite/treasure, correct visual weight |

The diagnosis is specific: A3's `?` is **gold outline on teal**, a mid-tone mark on a mid-tone face.
Obsidian works because it pairs an almost-black face with a near-white mark. So: **keep A3's teal
body, give it a solid high-contrast `?` instead of an outlined one.**

## R4-A — teal die, solid gold marks *(recommended)*

Warm gold against dark teal is a big luminance jump, matches the elite/treasure gold, and stays well
clear of the blue dice.

```
A chunky six-sided die carved from dark teal-green stone, with a large solid bright gold question
mark filling each visible face instead of pips. The question marks are polished gold inlay, solid
filled shapes with no outline, brightly lit against the deep teal stone. Chipped worn stone edges,
thin gold trim along the cube's edges. Game map icon: single centered object, 3/4 view with a slight
top-down angle, hand-painted cel-shaded fantasy style with 2-3 flat tone steps and no soft airbrush
gradients, thick dark brown outline around the whole silhouette, crisp rim highlight along the upper
edges. Chunky readable shape, bold and simple enough to stay legible when shrunk to a small icon.
Flat solid magenta background. No shadow, no text, no border, no scenery. Square image.
```

## R4-B — dark die, warm glowing marks *(obsidian's contrast, without the blue)*

Identical to B1 except the glow is amber instead of cyan — keeps the maximum-contrast dark body while
leaving the blue family to the fight icon.

```
A chunky six-sided die carved from dark charcoal stone, with a large question mark on each visible
face glowing warm amber-gold as if lit from within, filling each face instead of pips. Deep charcoal
stone with sharp chipped edges, warm golden light bleeding from the engraved marks. Game map icon:
single centered object, 3/4 view with a slight top-down angle, hand-painted cel-shaded fantasy style
with 2-3 flat tone steps and no soft airbrush gradients, thick dark outline around the whole
silhouette, crisp rim highlight along the upper edges. Chunky readable shape, bold and simple enough
to stay legible when shrunk to a small icon. Flat solid magenta background. No shadow, no text, no
border, no scenery. Square image.
```

**If you'd rather stop here: A3 is shippable as-is.** The cube reads clearly, it sits correctly in the
family, and the legend covers the meaning. The only cost is that the `?` reads as texture rather than
a glyph at map size. B1 is the one I'd actually advise against, despite being the best-looking of the
nine on its own.

---

## After generating

Hand the files over and the usual cleanup runs: chroma-key by distance to the measured background
colour, largest-connected-blob isolation, interior alpha fill (so nothing comes out translucent), 1px
erosion, premultiplied-alpha resize, recentre on a square canvas at ~85% fill. Then the per-icon size
multiplier in `MapRoom.ICONS` gets re-measured so everything lands at ~60px on its long axis, and the
legend swatches in `map.tscn` get repointed to the new files. Size is no longer baked into the art, so
presence can be tuned afterwards with one number — no regeneration needed for "a bit smaller".
