# Dice Odyssey — Combat juice audit for clip appeal (2026-08)

**Question asked:** what looks flat / could be more spectacular without becoming noise, specifically so short muted combat clips make strangers click?

> ## STATUS (updated 2026-08-07, shipped in 0.2.7)
> **P0 (roll motion) — DONE.** Hop/tumble/slam built, then the tumble REMOVED for good: rotation gave Julien vertigo within minutes, which makes it an accessibility constraint over a 30-floor run, not a taste call. Shipped style is `CALM` (upright hop, value-scaled height/timing). Four rotating presets survive behind `ROLL_STYLE_DEFAULT` but should not be shipped.
> **P0b (chain ladder) — DONE.** Chain-scaled number punch, roll-history rack punching in sync with the landing, 18+ Power ignition flare, and the landing thud whose pitch climbs per consecutive roll. Landing SFX are placeholders (`LAND_THUD_SOUND` / `LAND_SMASH_SOUND`).
> **P1a (directional hit smear) — DONE, and it REPLACED the radial burst on attacks** (Julien's call: a slash makes more sense than a particle circle for an attack). Final anatomy: white flash → saturated accent blade + additive white core → 40–90-mote cone along the cut → sparks.
> **P1b (enemy death shatter) and P1c (camera zoom-punch) — NOT DONE.** These are the remaining clip-facing wins.
> **Button→die weld and the §4 micro-polish menu — DONE** (coil-on-press, plinth dip, max-fall smear, dud sag+dim).
>
> **⚠️ The single most useful lesson this audit produced wasn't in the original text:** *an effect under ~4px or ~10% brightness does not exist at play speed.* Three "verified" effects (2px plinth dip, dud sag, thin slash) were invisible to Julien. Verifying an effect *executes* is not verifying it *reads*. Also: **check `z_index` against the enemy's Sprite2D at 7** — the slash spent four iterations being "too subtle" when it was simply rendering behind the body.

**Method:** code-level audit of every combat feedback system (dice.gd, enemy.gd, card_ui.gd, damage_effect.gd + everything documented in CLAUDE.md). I cannot *watch* the game — motion judgments below are inferred from the animation code and should be A/B checked against captures (see §7).

---

## 0. The headline finding

**The game is not under-juiced — it's unevenly juiced. The most-performed verb has the least animation in the scene.**

Compare what the two kinds of dice got:

| | Thrown dice (Meteor, Avalanche…) | **The main die — the core verb** |
|---|---|---|
| Choreography | windup pop → arc → mid-flight tumble → hang with face-lock glint → recoil → diagonal haymaker → flare + debris cone + shock puff + camera shake | squash (0.11s) → ±10px sideways wiggle → **3 texture swaps in place** → snap + punch |
| Motion | flies across the screen, rotates, physically hits something | **never leaves its spot, never rotates** |
| Total | ~0.95s of cinema | ~0.4s of face-swapping |

(`dice.gd::roll_dice()` lines ~652–684 vs. the `_thrown_die_*` pipeline.)

A player who knows the game doesn't notice, because the *meaning* of the roll (the Power number, the orbs) carries it. **A stranger watching a muted clip sees: a square changes its picture, a number changes.** That's the flatness you're sensing. Every clip contains 5–15 rolls; the roll IS the clip. This is the single highest-leverage fix on this list, and almost everything else is secondary to it.

The good news: your own thrown-dice pipeline proves the team (you) can already do this — the skills, the debris/flare/squash recipes, the face-cycling code all exist in the same file.

---

## 1. P0 — Make the main die physically roll

**Goal:** the roll should read as a *physical event* even at thumbnail size, in under ~0.55s (it runs constantly — it must stay snappy; the current total is ~0.4s, so this adds motion, not wait).

Concrete recipe, reusing what exists:

1. **Anticipation (keep):** the current squash wind-up is right. Slightly deepen it.
2. **The hop:** the die leaps up ~40–60px off its resting spot (position tween, TRANS_QUAD EASE_OUT), **rotating** as it goes — spin the TextureRect/sprite itself (±180–360°), swapping faces at rotation quarter-points so the spin and the face-cycling read as one motion. This is exactly what `_start_die_tumble` already does for thrown dice mid-flight — same idea, shorter and vertical.
3. **The slam:** accelerated fall back onto the plinth (TRANS_QUAD EASE_IN), landing on the *result* face with:
   - the existing scale punch (keep, maybe +10%)
   - a **dust/impact puff at the base** (reuse the shock-puff recipe from the thrown-die impact, smaller, colored neutral)
   - 1–2px camera micro-shake (already have the shaker; a whisper, not the damage shake)
   - the existing land SFX
4. **Settle bounce:** one small residual bounce (squash 1.08/0.94 → 1.0). Sells weight.

**Guardrails:**
- Keep `_roll_in_progress` exactly as is; total duration ≤0.55s so rapid multi-roll turns don't drag. If it feels slow in playtest, compress the hop, never the slam — the impact is the beat that matters.
- Rotation on a ~120px die is fine (the animate-position-not-scale rule is about *small* sprites shimmering; this die is large and the rotation is the point).
- Max rolls: let the existing gold burst + hit-stop ride ON the landing frame — the slam and the celebration become one beat instead of two.

**Effort: 1–2 sessions.** All ingredients exist in dice.gd already.

---

## 2. P0b — Let the chain escalate (the Balatro lesson)

Your hook is *the number climbing*. For a stranger, "number goes up" only reads as exciting if the **presentation escalates with it**. You already have most of a ladder:

Already built: dice-colored number, punch + flash per change, power-scaled resting size, crackle, orbs, emanation glow that grows with charge. That's a real base — this is a *tuning and topping* job, not a new system.

What's missing is the **top end and the rhythm**:

- **Escalating SFX pitch per chain step.** Each consecutive same-type roll pitches the roll/land sound up a step (you already do rising pitch on card-reward reveals — same trick). This is THE most legible "combo" signal that exists in games, and it costs a pitch multiplier. Bonus: TikTok/Shorts play WITH sound, unlike Steam — an ascending pitch ladder is what makes those clips satisfying.
- **Per-roll "+N" beat scales with chain position.** The 3rd consecutive roll's arrival should visibly hit harder than the 1st (bigger punch, brighter flash) even for the same face value. Chain position is in `roll_history.size()` — one multiplier on the existing punch.
- **A distinct top tier.** Above a threshold (~15–20 Power), one *new* visual state you currently never show: e.g. the number ignites (emanation-style licks directly on the glyph), or a slow screen-edge glow pulse. **One** new thing, reserved for rare moments — that's what gives clips a climax that doesn't exist in minute-to-minute play, without adding noise to normal turns.
- Optional: pulse the roll-history mini-faces when the chain extends (they're your streak pips; right now they're passive footer).

**Effort: ~1 session.** ⚠️ The emanation's subtlety at low-mid power was explicitly tuned and validated with you — don't touch the bottom of the curve; add a top.

---

## 3. P1 — Impact reads: direction and death

Hit feedback is already decent (white flash + rightward knockback + squash + chip HP bar + hit-stop + colored popup — `enemy.gd` 521–600). Two additions move it from "correct" to "clippable":

**a) Directional impact VFX on attack hits.** The current on-hit particles are a radial magic burst. Radial = "a thing happened HERE"; directional = "a force came FROM somewhere." Add a short diagonal slash-arc / smear overlay on the enemy for attack cards (1–3 frames, dice-accent colored, thick-outlined to match the art style). STS does this per attack; it's a big part of why its combat screenshots look violent. One generic slash + one heavy variant for 15+ damage is enough — don't do per-card art.

**b) Enemy deaths: shatter, don't fade.** Current death = white flash → modulate fade. It's the weakest beat in the kill sequence, and kills are the punctuation of every clip. Signature idea that's *on-theme*: the enemy **bursts into dice fragments/motes** (reuse the debris-cone + mote recipes; a handful of tiny tumbling die faces among the shards would be very "this game"). One shared effect, tinted per enemy, ~0.5s. Memorable deaths are disproportionately what gets clipped.

**c) Camera zoom-punch on big hits.** You have shake + hit-stop; add a 2–3% camera zoom-in snap that releases over ~0.2s for hits ≥~15. Zoom reads as impact even at phone-screen size where pixel shake gets lost. Cheap (battle Camera2D tween), big perceived-force gain.

**Effort: a+c ~1 session, b ~1 session.**

---

## 4. P2 — Smaller opportunities (only after the above)

- **Roll button feedback:** the button that triggers the core verb has no press juice of its own. A press-down depress + the die visibly *reacting* to the press (tiny pre-hop shiver) welds button→die causality for viewers. Tiny effort.
- **Block/defend beat:** block gain is quieter than damage. A brief shield-shimmer ring on the player when big block lands would balance defensive turns in clips. Low priority — clips should be offense anyway.
- **Background reactivity:** on 20+ Power or kills, a subtle 1-frame background brightness dip makes the foreground flash read harder (you already own the background shader with brightness param). Very cheap, but test against the vignette — easy to overdo.
- **Multi-kill / overkill tag:** you track overkill for achievements already; a rare "OVERKILL" stamp on 15+ overkill is the kind of moment people clip. Borderline noise — your call.

---

## 5. What NOT to touch (already at or above bar)

So the effort goes where it's needed — these are **done** and clip-ready:

- Thrown-dice bash choreography (your best asset, period)
- Emanation glow ("alive light" — playtested, validated, tuned)
- Power orbs (individuality + SFX pass done)
- Card play staging, mote trails, exhaust ember, reward ceremony w/ rare beat + deck flight
- Chip HP bars, damage/block popups, hit-stop system, intent bob
- Scout flow, coin flip, act/boss banners, dice infusion ceremony

Also: **resist adding a second thing to any beat that already has one.** Your own additive-stacking and "flat fills, sharp flash" rules are why the game reads clean. The plan above adds motion to the one beat that has none (the roll), and one reserved top tier — it does not layer more glow onto existing glow.

---

## 6. Honest caveat on the diagnosis

Juice is *probably part* of why the posts flopped, but n=2 posts with confounds (venue, title framing, first-2-seconds clip choice, a possible anti-AI downvote factor on a dev sub). Don't treat this audit as "fix juice → posts work." Treat it as: the roll animation gap is real, it's in every clip, and fixing it raises the floor of all future footage. The clip *selection* rules (open on the money shot, thumbnail frame with a big number) matter at least as much.

---

## 7. Verification loop

1. Before changing anything: capture 10s of current combat via Movie Maker (baseline).
2. Implement P0 (the roll). Capture the same 10s. Watch both **muted, at phone size** — that's the actual test condition.
3. Iterate the roll feel with the existing debug-harness pattern (a `debug_roll_feel.gd` that boots battle.tscn and force-rolls a scripted sequence would make this a 30s loop, same as your other harnesses).
4. Then P0b, same loop. Then reshoot the trailer/clips from §Part A of the trailer doc — all of that footage automatically inherits the upgrade.

**Suggested order: P0 roll → P0b chain ladder → reshoot clips → P1a/c impact+zoom → P1b deaths.** After P0+P0b alone, re-cut one 15s clip and post it — that's your real A/B test.
