# Card art prompts - 2026-09-07 batch (22 cards)

Written against the working formula in [card_art_prompt_guide.md](card_art_prompt_guide.md).
Every prompt is the template verbatim with only the three bracketed slots filled, so the
whole block gets copied - **do not trim the boilerplate**, every clause in it is load-bearing
(guide section 3).

**Live deck with copy buttons:** https://claude.ai/code/artifact/99da03cb-5643-442e-9988-0d92cbc37106

**Generator settings:** Wide **3:2**, no reference image. If a batch comes out Square,
Generative-Expand it left/right - never crop (guide section 5).

---

## The brief these were rewritten to

WARNING: **a first version of this file invented 22 brand-new scenes and threw away the
deck's cast.** Julien, 2026-09-07: *"i want you to keep most of the current concept of current
card illustrations, i like a humorous side with a goblin, a dwarf, ... dont completely make up
new ideas."* Every subject below was rewritten **after looking at the card's current art**,
and each one records what it **keeps**.

The cast the existing art has already established, and which these prompts feed:

| Who | Looks like | Shows up in |
|---|---|---|
| **Goblin** | orange-red skin, big hooked nose, pointed ears, slouch cap, gold teeth | usually *taking* the hit (Dice Slap, Eyepoke); also casting (Blaze, Finesse) |
| **Dwarf** | stout, huge red beard, steel plate with gold trim, warhammer | Unity, and now Refinement |
| **Hooded rogues** | purple-and-gold cloaks, grinning or glowing-eyed | Trickery, Occultism |
| **Wizards** | robed, mid-shout, throwing something enormous | Electrify, Crescendo |
| **The Dicelord** | bone mask, purple and gold, dice pouring from a skeletal hand | Anarchy |

**Only three subjects genuinely change**, and each says why on its own entry: **Trebuchet**
(it was borrowing Windfall's gambler art), **Pulverize** (the old wave belonged to the old
name) and **Refinement** (two disembodied hands, now the dwarf smith).

---

## Filenames to save under

| Card | Save as | Note |
|---|---|---|
| Focus | `focus.png` | Current art is `assets/images/focus.jpg` — a new PNG needs a two-line `.tres` repoint. I do that. |
| Occultism | `occultism.png` | overwrite in place |
| Trickery *(was Rigged)* | `rigged.png` | Filename stays `rigged.png` — only the card name changed. |
| Blaze | `blaze.png` | overwrite in place |
| Dice Slap | `dice_slap.png` | overwrite in place |
| Eyepoke | `eyepoke_fixed.png` | overwrite in place |
| Refinement | `gptrefinement.png` | Weakest of the current set: the existing art is two disembodied hands around a glowing block. Giving it the dwarf smith puts it back in the cast. |
| Electrify | `electrify.png` | Deliberately keeps the existing BLUE lightning rather than switching to Ricochet orange — the orange dice read as accents against it. |
| Stampede | `lunge.png` | overwrite in place |
| Voodoo | `voodoo.png` | overwrite in place |
| Crescendo | `crescendo_v2.png` | overwrite in place |
| Trebuchet | `trebuchet.png` | **Done.** New art is in as `trebuchet.png` and both `.tres` are repointed off `high_roller.png`, which now belongs to the cut card Windfall alone. |
| Finesse | `finesse.png` | overwrite in place |
| Pixie Volley | `fireflies_ok.png` | **Watermark already fixed, separately from this prompt.** The card was on `fireflies.png`, which has a “ChatGPT” mark baked into the bottom-right corner; it now points at your clean `fireflies_ok.png` (same art, no mark), so the shipped card is fine even if you never regenerate this one. The prompt below also moves the swarm from blue to green, since Pixie Dice are green. |
| Duo | `gptduo.png` | overwrite in place |
| Unity | `unity.png` | overwrite in place |
| Kamikaze | `kamikaze_nano_new.png` | overwrite in place |
| Haste *(was Overclock)* | `overclock.png` | Adds a goblin to the existing machine — the old art is a good object but has nobody in it. |
| Dice Aura *(was Dead Weight)* | `dead_weight.png` | **The current art is already right** — it was fixed once before, away from a cursed ball-and-chain that read as a penalty when the card is a *buff* you hold. Keep the monument. Reject any generation with chains, weights, or anything dragging. |
| Sixplosion *(was Jackpot)* | `jackpot_new.png` | The rename turns the payout into a detonation: same triple-six jackpot read, but the dice are coming apart rather than dropping coins. |
| Pulverize *(was Tidal Force)* | `tidal_force.png` | ⚠️ **Keeps the composition, drops the water.** The old art is a literal tidal wave, tied to the old name. Reject anything with water in it — the curling mass is now stone dice. |
| Anarchy *(was Dicelord's Gift)* | `dicelord_gift.png` | Keeps the dicelord exactly; the offering just stops being tidy — the rename is about chaos, not generosity. |

Every other file is shared only between a card and its own `+` version, which is intended -
the upgrade reuses the base art.

WARNING: `--headless --import` after any PNG drop, and that has to run with the editor closed.

---

## 1. Focus - *"Your next Dice roll is a 6"*

**Keeps:** the existing gold-on-black hand pinching a glowing six

> A weathered hand pinching a glowing die between finger and thumb, the six-pip face locked toward us and blazing while the die's other faces sit dark and forgotten. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant gold-and-black color palette, the background filled edge to edge with a radiating burst of golden light shards, brightest behind the subject and fading to darker golden tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

Current art is `assets/images/focus.jpg` — a new PNG needs a two-line `.tres` repoint. I do that.

## 2. Occultism - *"Charge 1 Giant Dice. Gain Unlucky 1"*

**Keeps:** the hooded conjurer with burning eyes, die floating between his cupped hands

> A hooded conjurer with burning slit eyes drawing an oversized heavy die up out of nothing between his cupped hands, a column of gold light pouring off it while dark threads coil back around his wrists. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant gold-and-black color palette, the background filled edge to edge with a radiating burst of golden light shards, brightest behind the subject and fading to darker golden tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

## 3. Trickery *(was Rigged)* - *"Gain Lucky 2. Exhaust"*

**Keeps:** the grinning purple-and-gold hooded rogue with glowing dice in his open palm

> A grinning hooded rogue in a purple and gold cloak holding out an open gloved palm with two glowing golden dice sitting on it, a third die still half-hidden up his sleeve. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant violet-purple-and-black color palette, the background filled edge to edge with a radiating burst of golden light shards, brightest behind the subject and fading to darker golden tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

Filename stays `rigged.png` — only the card name changed.

## 4. Blaze - *"Add 7 to your Power. Gain Weak 1"*

**Keeps:** the red-bearded goblin in a slouch cap blowing fire onto a die in his palm

> A red-bearded goblin in a slouch cap blowing a hard stream of fire onto a die balanced on his open palm, the die glowing white hot while the flames curl back and singe his own eyebrows. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant amber-orange-and-black color palette, the background filled edge to edge with a radiating burst of fiery orange light shards, brightest behind the subject and fading to darker fiery orange tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

## 5. Dice Slap - *"Deal X damage, plus 3 for each consecutive Dice roll"*

**Keeps:** the goblin taking a flying die square in the face, howling

> A huge glowing die cracking into a goblin's cheek and folding his face around it, the goblin howling, a whipping chain of more dice trailing back behind the impact. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant gold-and-black color palette, the background filled edge to edge with a radiating burst of golden light shards, brightest behind the subject and fading to darker golden tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

## 6. Eyepoke - *"Deal X damage. Draw 3 cards"*

**Keeps:** the goblin with a playing card jammed into his eye, gold teeth bared

> A goblin recoiling with a playing card jammed edge-first into his screwed-shut eye, gold teeth bared in a yelp, more cards spraying loose past his head. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant amber-orange-and-black color palette, the background filled edge to edge with a radiating burst of fiery orange light shards, brightest behind the subject and fading to darker fiery orange tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

## 7. Refinement - *"Increase your Power to the next multiple of 7"*

**Keeps:** hands working a glowing die into shape — now given a smith to do the working

> A red-bearded dwarf smith squinting down a hammer blow at a rough die pinned on his anvil, its dull faces splitting away as clean sharp new ones come up underneath in a spray of gold filings. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant gold-and-black color palette, the background filled edge to edge with a radiating burst of golden light shards, brightest behind the subject and fading to darker golden tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

Weakest of the current set: the existing art is two disembodied hands around a glowing block. Giving it the dwarf smith puts it back in the cast.

## 8. Electrify - *"Charge 2 Ricochet Dice"*

**Keeps:** the wild-eyed hooded wizard mid-shout inside a cage of blue lightning

> A wild-eyed hooded wizard braced mid-shout inside a cage of forking blue lightning, bright orange dice snapping and rebounding along the bolts toward his outstretched hand. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant royal-blue-and-black color palette, the background filled edge to edge with a radiating burst of electric blue light shards, brightest behind the subject and fading to darker electric blue tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

Deliberately keeps the existing BLUE lightning rather than switching to Ricochet orange — the orange dice read as accents against it.

## 9. Stampede - *"Deal X damage. If you rolled at least 5 Dice this turn, deal it twice"*

**Keeps:** the cloaked warrior charging low with a blade, dragging a long fire trail

> A cloaked warrior charging low and fast with his blade out, dragging a long trail of fire behind him, dice churning up off the ground under his boots like hooves. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant crimson-and-black color palette, the background filled edge to edge with a radiating burst of fiery red light shards, brightest behind the subject and fading to darker fiery red tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

## 10. Voodoo - *"Refuel into a random Dice type"*

**Keeps:** the green goblin in a purple hood, clawed hands spread over cracking violet energy

> A fanged green goblin in a purple hood spreading his clawed hands over a floor of cracking violet energy, spent grey dice rising out of the cracks and igniting into new colours as they turn. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant violet-purple-and-black color palette, the background filled edge to edge with a radiating burst of sickly violet light shards, brightest behind the subject and fading to darker sickly violet tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

## 11. Crescendo - *"Deal damage equal to all Power generated this turn. Exhaust"*

**Keeps:** the white-and-gold robed wizard hurling an enormous building blast

> A white and gold robed wizard with both arms flung forward, releasing an enormous building wave of golden light that swallows the whole right of the frame, dice caught up and tumbling inside it. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant gold-and-black color palette, the background filled edge to edge with a radiating burst of golden light shards, brightest behind the subject and fading to darker golden tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

## 12. Trebuchet - *"Your thrown Dice deal 3 more damage"*

**Keeps:** nothing — it currently borrows the gambler art, which belongs to Windfall

> A goblin siege crew scattering as their trebuchet snaps forward and hurls an enormous iron-banded die skyward, one goblin still clinging to the counterweight on the way down. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant iron-grey-and-black color palette, the background filled edge to edge with a radiating burst of steely light shards, brightest behind the subject and fading to darker steely tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

**Done.** New art is in as `trebuchet.png` and both `.tres` are repointed off `high_roller.png`, which now belongs to the cut card Windfall alone.

## 13. Finesse - *"Boost 8 · gated on a low roll"*

**Keeps:** the goblin balancing a tall stack of coloured dice on one fingertip, eyes shut

> A long-nosed goblin with his eyes serenely shut balancing a tall swaying stack of coloured dice on the tip of one raised finger, the whole column glowing where it touches his skin. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant gold-and-black color palette, the background filled edge to edge with a radiating burst of golden light shards, brightest behind the subject and fading to darker golden tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

## 14. Pixie Volley - *"Throw X Pixie Dice at random enemies. Each deals damage equal to its roll"*

**Keeps:** the swarm of glowing winged sprites arcing through the dark

> A swarm of tiny winged pixies each hauling a glowing green die, streaking outward through the dark in darting crossing arcs and trailing sparks behind them. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant leaf-green-and-black color palette, the background filled edge to edge with a radiating burst of luminous green light shards, brightest behind the subject and fading to darker luminous green tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

**Watermark already fixed, separately from this prompt.** The card was on `fireflies.png`, which has a “ChatGPT” mark baked into the bottom-right corner; it now points at your clean `fireflies_ok.png` (same art, no mark), so the shipped card is fine even if you never regenerate this one. The prompt below also moves the swarm from blue to green, since Pixie Dice are green.

## 15. Duo - *"Deal X4 damage and gain X4 Block"*

**Keeps:** the two heroes standing back to back against a ring of shadowed enemies

> Two heroes standing back to back against a closing ring of red-eyed shadows, the swordswoman lunging out while the big shielded warrior plants his guard, a die set in her pommel and another in his shield boss. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant amber-orange-and-black color palette, the background filled edge to edge with a radiating burst of warm amber light shards, brightest behind the subject and fading to darker warm amber tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

## 16. Unity - *"Gain X12 Block · gated on the smallest roll"*

**Keeps:** the stout red-bearded dwarf in gold-trimmed steel plate

> A stout red-bearded dwarf in gold-trimmed steel plate planting his warhammer and bracing, a towering wall of interlocking shields rising up out of the single small die at his feet. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant iron-grey-and-black color palette, the background filled edge to edge with a radiating burst of steely light shards, brightest behind the subject and fading to darker steely tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

## 17. Kamikaze - *"Deal X3 damage. If you roll a 1, lose 6 HP instead"*

**Keeps:** the roaring bloodied berserker throwing himself forward

> A roaring bloodied berserker throwing himself bodily forward with a crimson die gripped in his fist like a live grenade, the blast already blooming open between his knuckles. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant crimson-and-black color palette, the background filled edge to edge with a radiating burst of fiery red light shards, brightest behind the subject and fading to darker fiery red tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

## 18. Haste *(was Overclock)* - *"Draw 2 cards. Charge 2. Exhaust"*

**Keeps:** the glowing brass crank machine spitting out dice and cards

> A goblin cranking a glowing brass contraption so hard his cap flies off, the machine juddering and spitting a jet of cards out one side while dice pour into the tray below. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant amber-orange-and-black color palette, the background filled edge to edge with a radiating burst of fiery orange light shards, brightest behind the subject and fading to darker fiery orange tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

Adds a goblin to the existing machine — the old art is a good object but has nobody in it.

## 19. Dice Aura *(was Dead Weight)* - *"While this is in your hand, gain Surge 1. This card cannot be played"*

**Keeps:** the colossal die standing on a glowing ring with smaller dice gathered around it

> A colossal weathered die standing upright on a glowing ring cut into the flagstones, throwing off wide rings of golden light that make the smaller dice ringed around its base glow brighter. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant gold-and-black color palette, the background filled edge to edge with a radiating burst of golden light shards, brightest behind the subject and fading to darker golden tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

**The current art is already right** — it was fixed once before, away from a cursed ball-and-chain that read as a penalty when the card is a *buff* you hold. Keep the monument. Reject any generation with chains, weights, or anything dragging.

## 20. Sixplosion *(was Jackpot)* - *"Deal 6 damage for every 6 you rolled this fight. Exhaust"*

**Keeps:** the row of six-pip faces paying out in a gold blast

> A row of six-pip die faces blowing apart in one gold detonation, their pips firing outward like shrapnel through a storm of spinning coins. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant gold-and-black color palette, the background filled edge to edge with a radiating burst of golden light shards, brightest behind the subject and fading to darker golden tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

The rename turns the payout into a detonation: same triple-six jackpot read, but the dice are coming apart rather than dropping coins.

## 21. Pulverize *(was Tidal Force)* - *"Deal X damage. Power above 10 counts double"*

**Keeps:** the composition — a small braced figure dwarfed by an enormous curling mass about to break over him

> A small hooded figure braced low and dwarfed by an enormous curling avalanche of tumbling stone dice about to break over him, the flagstones already splitting under the leading edge. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant iron-grey-and-black color palette, the background filled edge to edge with a radiating burst of dusty amber light shards, brightest behind the subject and fading to darker dusty amber tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

⚠️ **Keeps the composition, drops the water.** The old art is a literal tidal wave, tied to the old name. Reject anything with water in it — the curling mass is now stone dice.

## 22. Anarchy *(was Dicelord's Gift)* - *"Charge a random Dice each turn"*

**Keeps:** the bone-masked purple-and-gold hooded dicelord offering dice from his skeletal palm

> A bone-masked hooded dicelord in purple and gold flinging a skeletal hand open, mismatched dice of every colour and shape bursting up out of his palm and scattering wildly past his shoulders. Bold ink-outlined comic book illustration in the style of Slay the Spire card art, flat cel-shaded coloring with graphic hard-edged highlights, thick black linework, dominant violet-purple-and-black color palette, the background filled edge to edge with a radiating burst of sickly violet light shards, brightest behind the subject and fading to darker sickly violet tones at the corners, never pure black. Not photorealistic, not a 3D render, not glossy or overly detailed. No text, no numbers, no card border or frame, no watermark.

Keeps the dicelord exactly; the offering just stops being tidy — the rename is about chaos, not generosity.

---

## Notes on the colour spread

Palettes follow the art that exists, not a fresh scheme: Focus / Dice Slap / Finesse stay gold
on black because that is what they are now, Electrify keeps its blue lightning even though it
charges orange Ricochet dice (the dice read as accents against it), and Trickery keeps the
purple hood with gold dice.
