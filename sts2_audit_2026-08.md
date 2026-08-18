# STS2 Reference Audit — Findings (2026-08)

Companion to [sts2_audit_plan.md](sts2_audit_plan.md). Reference material lives **outside this
repo** at `C:\Users\julie\Desktop\sts2_ref\pck` and is never edited, never copied in, never
committed. Everything below is paraphrased behaviour and raw numbers — no STS2 code, no STS2
art, in this file or anywhere in the repo. Anything adopted gets reimplemented fresh in our
own idiom.

**Verdict legend:** `adopt idea` · `adapt` · `skip` · `already better` · **VERDICT NEEDED**
(Julien's call).

Sessions logged: **A** (WS1 + WS4) · **B** (WS2) · **C** (WS3 + WS5 + WS7) · **D** (WS6 + WS8) —
all 2026-08-15. **All 8 workstreams are complete; the audit plan is fully executed.**
A consolidated list of everything awaiting Julien's call is at
[Open verdicts](#open-verdicts--consolidated-index), just above "Next probes".

---

## WS1 — UI construction & the "one button language" audit

### 1.1 They do not use Godot's Button, Theme, or StyleBox at all — **this is the headline**

- **Theirs:** No project-wide default theme is set (`[gui]` in their project settings has no
  theme entry). The entire 15,991-file project contains **9 files that mention `StyleBoxFlat`**,
  and every one of them is an editor addon, a debug console, the modding screen, or the
  feedback screen — **zero StyleBoxFlat in shipped gameplay UI**. Only 4 `Theme` resources
  exist, three of them narrow (a main-menu text button, a settings line header, a settings
  tab) plus one from a third-party addon.
  Instead they built their own button stack on plain `Control`:
  a base "clickable" class (hand-rolled hover/press/focus state machine, explicitly documented
  in their source as *"a base button class which doesn't rely on Godot's Button class"*), and a
  button class on top of it that adds hotkeys, controller icons, and sounds. Every button in
  the game is a `Control` with a script, and **its appearance is painted art from a sprite
  atlas**, not a stylebox.
- **Ours:** 111 files use `StyleBoxFlat`. Corner radius is set to **15 distinct values** across
  the project (1, 3, 5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20, 25, 34) and border width to
  **7** (1, 2, 3, 4, 5, 6, 20). `main_theme.tres` is the project default and its
  `Button/styles/normal|hover|pressed` point at **card styleboxes**
  (`card_base_stylebox.tres`, `card_hover_stylebox_v2.tres`, `card_pressed_stylebox.tres`) —
  so any Button in the project without explicit overrides renders as a *card*. That is the
  mechanical root of the drift: the default is wrong, so every button author overrides, and
  every override drifts.
- **Verdict:** `adapt`, in two clearly separable pieces — and **do not conflate them**:
  1. **Free, now, low-risk:** fix `main_theme.tres` so the default Button style is an actual
     button, not a card. Collapse the radius/border zoo toward a small set. This is a
     consistency win that costs nothing and doesn't require art.
  2. **Not free, post-launch:** the painted-atlas paradigm. Their buttons look designed
     because each one is *drawn*, not assembled from a rounded rect. That is an art
     commission, not a refactor.
  The important insight for **the live End Turn pick**: candidates A–E in
  `debug_button_variants.gd` all move within the stylebox paradigm (fill / border / radius /
  chamfer). STS2's answer is that the paradigm itself is the tell. See 1.6 for what this
  means for the pick.

### 1.2 Universal button anatomy — a 3-layer stack

- **Theirs:** Every button scene checked (End Turn, Proceed, Confirm, Back) is the same shape:

  | Layer | What it is | Treatment |
  |---|---|---|
  | `Shadow` | **the same texture as the button art**, drawn behind | pure black at **alpha 0.251**, offset **+12px right and +12px down**. A hard offset silhouette — no blur, no separate art. |
  | `Outline` | a **separate pre-rendered outline sprite** | additive blend, `self_modulate` alpha **0** at rest, faded in on hover; tinted gold |
  | `Image` | the painted button art from the atlas | carries an HSV shader material for state changes |
  | children | `Label` / `Icon`, plus a `HotkeyIcon` at scale 0.85 | |

  The shadow trick is the cheap one: reusing the button's own texture as its shadow costs no
  extra art and can never desync from the shape.
- **Ours:** Buttons are single `StyleBoxFlat` rects; the shadow is the stylebox's own
  `shadow_size`/`shadow_color`, and "outline" is the stylebox border, so hover has to be
  expressed by swapping the whole stylebox (which is why we hit the *"remember to cover all
  four states — normal/hover/pressed/focus"* bug on the dice-shop X button).
- **Verdict:** `adopt idea` for the **shadow-from-own-texture** trick if we ever go painted;
  `adopt idea` **now** for the separate always-present outline layer whose alpha is animated —
  it removes the whole class of "swap the stylebox and forget a state" bug, because the
  resting appearance never changes, only an overlay's alpha does.

### 1.3 State changes are HSV-shader + position, never a stylebox swap

- **Theirs:** All four buttons share one tiny HSV shader with `h`/`s`/`v` parameters on the
  Image layer. States:

  | State | What changes | Numbers |
  |---|---|---|
  | Hover (End Turn) | brightness up, 2px lift | shader `v` → **1.5**, visuals position → **(0, −2)**, both applied **instantly** |
  | Hover (Proceed) | brightness up, scale up, outline on | `v` → **1.4** over **0.05s**, scale → **1.05** over **0.05s**, outline alpha → 1 over 0.05s |
  | Press (End Turn) | push **down** | visuals position → **(0, +8)** over 0.5s, cubic ease-out; label → dark gray |
  | Press (Proceed) | shrink + desaturate | scale → **0.95**, `s` → **0.8** over 0.25s, image modulate → gray |
  | Disabled | grayed | image and label `modulate` → **0.5 gray** (same texture, no separate art) |
  | Un-hover | everything drifts back | **0.5s, ease-out, EXPO** |

- **The transferable rule, and the best single find in WS1:** **hover-in is near-instant
  (0.00–0.05s); hover-out is slow (0.5s, expo ease-out).** Both buttons do this, independently.
  Snap to the hot state, drift back from it. It reads as responsive without reading as twitchy,
  and it costs nothing.
- **Why HSV `v` and not `modulate`:** `modulate` multiplies, so it can only *darken*; pushing
  it above 1 to brighten blows toward white and flattens saturation. Scaling the HSV value
  channel brightens while preserving hue and saturation — the button gets brighter, not paler.
- **Ours:** our End Turn is a Godot `Button` with four stylebox overrides plus four font-colour
  overrides, and no motion at all on hover or press. Our card hover uses border width +
  `expand_margin`; our dice-shop hover uses `modulate`.
- **Verdict:** `adopt idea` — all three parts are cheap and paradigm-independent:
  - the **asymmetric hover timing** (instant in / 0.5s expo out) works on a StyleBoxFlat button
    just as well as a painted one;
  - **press = move the visuals down a few px** is a stronger "it depressed" signal than a
    colour swap, and we already have the node structure for it;
  - **brighten via HSV, not modulate** — worth a tiny shared shader, since we already reach for
    `modulate` everywhere and it's why some of our hovers read as "washed out" rather than "lit".

### 1.4 Text treatment is a house constant

- **Theirs:** identical across both buttons measured:

  | Property | Value |
  |---|---|
  | Font | Kreon Bold (a `FontVariation` shared from their themes dir) |
  | Font colour | cream **`#FFF6E2`** (their central palette's `cream`) |
  | **Outline size** | **12** — at font sizes 30 and 34 alike |
  | Outline colour | **keyed to the button's own art hue**: dark navy on the blue End Turn button, dark warm brown-red on the Proceed button |
  | Shadow | black at alpha **0.125–0.19**, offset **(3, 2)**, shadow outline size 12 |
  | Auto-fit | every label is an auto-shrinking label with a min/max font size (e.g. 24–34) |

  Two things stand out. The **12px outline at 30–34px font is a ~35–40% ratio** — far heavier
  than reads "normal", and it's what makes their text sit on top of busy painted art without a
  plate behind it. And the outline colour is *not* a global constant — it's a dark version of
  the button's own colour, so the text looks embedded in the button rather than stuck on it.
- **Ours:** our established title recipe is gold `#EEB52A` with **outline 6** `#170F05` (a
  fixed dark brown, same on every surface). Our End Turn label currently has **no outline at
  all**. We do have measured auto-fit — `TITLE_FONT_SIZE_CANDIDATES` / the description
  step-down — which is the same idea as their min/max label, arrived at independently.
- **Verdict:** `adopt idea` (outline weight + art-keyed outline colour), `already better`
  (auto-fit: ours measures actual rendered width against the real font, which is more robust
  than a min/max clamp). Note our gold `#EEB52A` and their gold `#EFC851` are the same family —
  no reason to change ours.

### 1.5 One central colour class, and rarity lives in the title outline

- **Theirs:** a single static colour class holds the whole palette (~50 named colours): `cream`,
  `gold #EFC851`, `red #FF5555`, `gray 0.5` (the universal disabled tint), plus context colours.
  Their own comment says one-off colours don't belong there — so it's a curated palette, not a
  dumping ground. Notably it contains **seven `cardTitleOutline*` colours, one per card
  rarity/type** (common, uncommon, rare, curse, quest, status, special): rarity is communicated
  by the **colour of the card title's outline**.
- **Ours:** `DicePalette` is exactly this pattern for dice (and it works — it's why infusion
  recolouring came free). But UI colours are scattered as literals across scenes and scripts,
  which is what let the 15-radius / 7-border drift happen. For rarity we use a **banner gem**
  (`rarity_gem_common/uncommon/rare.png`) plus a green title for upgraded cards.
- **Verdict:** `adopt idea` for a `UiPalette` sibling to `DicePalette` — same proven pattern,
  and it's the precondition for the theme cleanup in 1.1. **VERDICT NEEDED** on the rarity
  channel: their title-outline colour is a second, always-visible rarity cue that costs one
  colour lookup and no space. Ours is a gem that Julien already iterated three times (v1 too
  small, v2 too similar, v3 shipped). Adding outline colour on top is cheap and would make
  rarity readable at a glance in the deck view — but it's a change to a system Julien has
  already tuned and signed off, so it's his call, not an obvious win.

### 1.6 The End Turn button specifically — direct input to the live pick

- **Theirs:** 220×90 `Control`, anchored bottom-right, sitting **96px from the right edge and
  144px from the bottom** at their 1920×1080 dev resolution (≈5% / 13% of the screen). Art is
  one painted PNG drawn at half scale, plus a separate glow PNG used twice.
  - **Show/hide is a fly-on/fly-off**, not a fade: the button slides **250px down** off screen.
    In uses **BACK** easing (overshoot), out uses **EXPO**, both 0.5s. It leaves the screen
    entirely during the enemy turn.
  - **The "shiny" state** — their name for it — triggers when *you have no playable cards left
    and haven't ended your turn*: a cyan glow fades in (alpha → **0.75** over **0.8s**, BACK
    ease, with a simultaneous scale pop from 0.45→0.5), and a second additive glow layer
    **loops forever**: scale 0.5 → 0.7 while alpha 0.4 → 0, over **1.5s**. An expanding,
    fading ring. Turning it off is alpha → 0 over 0.5s, EXPO.
  - **Hovering it while you still have playable cards turns the label red** and **flashes the
    playable cards in your hand**. If you have nothing playable, the label turns cyan instead.
  - The label carries the **turn number**.
- **Ours:** a 194×43 Godot `Button`, 26px from the right and 85px from the bottom of a 1280×720
  design viewport (≈2% / 12%). It never moves. Our equivalent of "shiny" exists and is well
  targeted — `battle_ui.gd::_update_end_turn_highlight()` pulses gold when 0 dice remain **and**
  0 Power is banked **and** no Celestial card is in hand — but it's a colour pulse on a static
  rect, and it does not touch the hand.
- **Verdict:** several, ranked by payoff-per-effort:
  1. **`adopt idea` — make it bigger and inset it more.** Theirs is 220×90 on a 1920-wide
     screen; ours is 194×43 on a 1280-wide screen. Normalised, theirs is **~2.3× taller
     relative to the screen** and sits 2.5× further from the right edge. Ours reads small and
     crowded against the edge. This is a pure numbers change to `battle.tscn` and is the
     single cheapest improvement available to the End Turn button — **independent of which
     candidate A–E wins.**
  2. **`adopt idea` — hover feedback the hand.** Their hover-flashes-your-playable-cards is a
     genuinely great teaching beat: the button answers "why would I not end turn?" the moment
     you consider it. We already have `Events.hover_playable_cards` and the glow states to do
     this; it's a wiring job, not new systems.
  3. **`adapt` — the shiny ring.** Ours fires on the right condition already; theirs is
     visually louder (expanding additive ring vs colour pulse) and uses a real "look here"
     shape. Worth upgrading the *presentation*, not the *trigger* — our trigger is arguably
     more precise (it accounts for banked Power and Celestials).
  4. **`skip` — fly-on/fly-off.** Their button leaves during the enemy turn because their
     enemy turn is long and cinematic. Ours re-enables on `player_hand_drawn`; adding a 0.5s
     slide would fight the `_turn_cycle_active` guard we just shipped for the double-end-turn
     bug. Not worth the risk before launch.
  5. **`skip` — turn number in the label.** We have a turn banner already.

### 1.7 Their button hover/press machine solves two bug classes we've hit

- **Theirs:** three details in their base clickable class, all of which map onto bugs we've
  actually shipped:
  - **A press only counts if it started *and* ended on the same control**, and a press is
    **cancelled if the mouse travels past a configurable drag threshold** from where it went
    down. (Our own `card_clicked_state` distinguishes click-to-read from drag by motion, so
    we've solved the adjacent problem; a plain Godot Button hasn't.)
  - **Losing visibility force-fires the unfocus path.** Any control that becomes
    invisible cleans up its own hover state — which is precisely the *"tooltip stays on screen
    forever because the owner was freed / paused mid-hover"* bug we have now fixed **four
    separate times** (intent, relic, battle reward, shop) by adding `_exit_tree()` handlers
    and safety timeouts.
  - **The focus stylebox is explicitly blanked** on every clickable, once, in the base class —
    the exact bug we hit on the dice-shop X button, where an un-overridden `focus`/`pressed`
    state fell back to the default theme and appeared as a pale box.
- **Ours:** each of these is handled, but **per site**, after being hit in the wild.
- **Verdict:** `adopt idea`, cheaply and without a refactor: a small shared helper (or just a
  documented 3-line recipe) that blanks the focus stylebox and clears hover state on
  `visibility_changed`. We are not going to rebuild our buttons on a custom base class before
  launch — but the *"visibility change clears hover"* line is a genuine structural fix for a
  bug family that has cost us four separate patches, and it belongs wherever we spawn tooltips.

### 1.8 Hover tips: instant, wide, and registry-deduped

- **Theirs:** **no delay at all** — there is not a single timer or delay constant anywhere in
  their hover-tip node code; tips appear the instant a control takes focus. Tips are **360px
  wide**, stack vertically with **5px spacing** (a "tip set" — multiple tips for one hover),
  and are held in **one static registry keyed by owning control**, with creation calling
  remove-for-that-owner first. There's a global "block all hover tips" switch, an alignment
  enum with per-context positioning (relics get their own placement rule), and the set follows
  its owner every frame.
- **Ours:** card tooltips wait **1.0s** (`card_ui.gd`, `card_menu_ui.gd`), relic tooltips wait
  **0.5s** (`relic_ui.gd`). Our tooltip panel is **204px** wide with a **180px** text column,
  and we independently arrived at the same kill-before-spawn discipline plus `_exit_tree()`
  cleanup and safety timeouts.
- **Verdict:**
  - **VERDICT NEEDED — the 1s card tooltip delay.** Theirs is 0s. Ours makes the player wait a
    full second on the single most information-dense object in the game. Julien already removed
    the campfire tooltip delay for feeling sluggish, which suggests the instinct. Counter-
    argument: our cards live in a fan and the cursor crosses several on the way anywhere, so
    0s could flicker — a small delay (0.15–0.25s) may be the real answer rather than 0.
  - **`adopt idea` — width.** Their 360px vs our 180px text column is the direct cause of our
    documented **"3 lines and it clips"** ceiling, which has already forced us to shorten real
    tooltip copy and which we now have to verify with a measuring harness on every text change.
    Widening the panel buys headroom permanently and retires a recurring chore.
  - **`already better` — the leak discipline.** Same conclusion as theirs, reached the hard way.

### 1.9 A teaching moment worth stealing outright (bridges to WS5)

- **Theirs:** the first time you press End Turn **while still holding a playable card**, they
  interrupt with a modal instead of ending the turn. It's flagged as a one-time tutorial beat.
  The self-retiring part is the clever bit: if you instead end three turns having *genuinely*
  run out of playable cards, they mark the tutorial complete and never show it — the game
  concludes you understand, and their log line for it reads as a congratulation.
- **Ours:** no equivalent. Our End Turn highlight tells you when you're *done*; nothing catches
  the opposite mistake of ending early with resources unspent. Our nearest relative is the
  dice-slot nudge (other slots breathe when the active type is empty and no Power is banked).
- **Verdict:** `adopt idea` — and note this is the same insight our nudge already encodes, just
  applied to the other end of the turn. **Gate it the same way**: only fire when a card is
  genuinely playable *right now*, and retire it permanently once the player demonstrates
  competence. Cheap: one save flag, one counter, one modal we already have panel styling for.

---

## WS4 — Juice: the impact stack & enemy deaths

### 4.1 Enemy death, end to end — the full spec

This is the headline deliverable of WS4: our most clippable missing beat, and they have a
complete, readable answer. **Their whole sequence, in order:**

1. **Freeze the corpse.** The dying creature's body node is reparented into a `SubViewport`
   sized to its own bounding box, and that viewport is set to render **exactly once**. Everything
   after this point operates on a still snapshot, not a live animating creature. (The viewport is
   allocated at **2× the measured box** with a 1× stretch override, i.e. supersampled so the
   dissolve edge stays crisp.)
2. **The snapshot is already a ghost.** The sprite showing it sits at **alpha 0.467** — the body
   half-vanishes the instant it dies, before any dissolve happens.
3. **Dissolve.** A ~37-line canvas shader with `blend_premul_alpha` and a single `threshold`
   uniform tweened **1.0 → 0.0**, ease-out **SINE**. The technique worth stealing: it samples
   **two** noise textures at **different frequencies** — one fine (≈0.023) and one ~2.8× coarser
   (≈0.008). Big blotches tear away while fine grain eats the edges; a single noise scale reads
   as TV static instead.
4. **Duration is size-scaled but effectively capped.** The formula scales duration against a
   reference length of **10% of screen width** and a reference duration of **2.5s**, then clamps
   to **2.5s**. Doing the arithmetic at their 1920-wide dev resolution: anything whose bounding
   box is wider than ~96px hits the cap — **so in practice essentially every enemy death is a
   full 2.5 seconds.**
5. **Flakes, throughout — not a burst.** `CPUParticles2D`, **500** particles, one-shot,
   lifetime **1.8s**, `explosiveness` **0.08** (≈continuous emission across the whole window, so
   flakes keep peeling off for the entire dissolve rather than puffing at t=0),
   `lifetime_randomness` **0.75** (they expire at wildly different times).
   Emission is a sphere with radius = **viewport height ÷ 4**.
   Motion: direction up-and-right **(1, −0.5)**, spread **30°**, initial velocity **100–150**,
   and **gravity (0, −100) — negative, they float upward.** Angular velocity ≈ **±100–109** and
   fully random start angle, so each flake tumbles.
   Scale **0.05–0.07** on a curve that ramps in by t≈0.17, holds to t≈0.43, then decays to
   ≈0.21 by t=1 — flakes pop in, hold, and shrink out.
   The flake texture is an **8-frame looping sprite sheet** with randomized animation speed
   (0.5–1.5×) and offset, so every flake is individually fluttering.
6. **One sound**, an "enemy fade" event, fired at the start of the dissolve.
7. **Ordering around it.** Before any of this: the creature's UI is tweened away, its orbs are
   cleared, its intent is hidden. Then it **waits for the current animation to finish, plus
   0.5s** (capped 20s), or a per-monster death-length override. Then the VFX node is added to
   the parent **at the dying creature's own child index**, so the dissolve draws in exactly the
   z-order slot the creature occupied. Finally it awaits any attached `IDeathDelayer` children —
   an interface any child VFX can implement to say *"don't remove the corpse until I'm done."*
8. **Opt-outs are first-class.** Per-monster: `ShouldFadeAfterDeath` (some monsters skip it) and
   an extra padding multiplier for the VFX bounds. Globally: the whole thing is skipped when the
   player's speed preference is "Instant", and skipped in automated test mode.

- **Ours:** `enemy.gd` (around line 583): on death we drop the outline shader, emit `enemy_died`,
  then **tween `modulate:a` to 0 over 0.4s and `queue_free`.** No particles, no dissolve, no
  sound, no shake, no wait for anything. One tween, one property.
- **Verdict:** `adopt idea` — this is the concrete spec the plan asked for, and it is **buildable
  by us without Spine**: the reparent-snapshot-dissolve trick works identically on a `Sprite2D`,
  and we already own every other piece (we build particle systems in code routinely, we have
  additive materials, we have `SFXPlayer`).
  **Proposed "Dice Odyssey enemy death v1"**, ordered cheapest-first so it can ship in stages:
  - **Stage 1 (no shader, ~an afternoon):** hold the corpse at ~0.45 alpha, emit an upward
    drift of tumbling fragments — **use dice-face fragments or pips**, which is our version of
    their flakes and is the single most on-brand choice available to us — with negative gravity,
    a 30° cone, continuous emission (not a burst), and a pop-hold-shrink scale curve. Add one
    death sound. Stretch the whole beat to **~1.2–1.5s**, not 0.4s.
  - **Stage 2 (adds the shader):** the two-frequency-noise dissolve on a snapshot. Our sprites
    are flat cel art with hard outlines, which dissolves *better* than painted art, not worse.
  - **Stage 3:** an `IDeathDelayer` equivalent so a lingering VFX (a Magma burn, a thrown die
    still in flight) can hold the corpse until it lands.
  ⚠️ **Two things to carry over deliberately:** the **wait-then-dissolve ordering** (our hit
  reaction currently gets cut off by the fade starting 0.06s after the hit), and the
  **skip-when-fast** escape hatch — a 1.5s death × 4 enemies is 6 seconds, and we have no speed
  setting to hide behind (see 4.5).
  **VERDICT NEEDED — duration.** Theirs is 2.5s. That is a long time to watch, and it works for
  them because a fight has few enemies and their art is elaborate. Our swarms run to 4 bodies and
  our fights are shorter. My recommendation is **~1.2–1.5s with the fragments front-loaded**, but
  the right number is a playtest call, and it interacts with the AoE case (four simultaneous
  deaths) that theirs never really faces.

### 4.2 Hit-stop: same idea, meaningfully better shape — **best cheap win in WS4**

- **Theirs:** time scale snaps to **0.1**, then **ramps back to 1.0 across the duration along an
  easing curve**. The two parameters are enums, and — this is the clever part — **"strength"
  selects the easing function, not the depth**:

  | Strength | Easing | Reads as |
  |---|---|---|
  | VeryWeak | circular-in | leaves 0.1 almost immediately |
  | Weak | sine-in | |
  | Medium | quadratic-in | |
  | Strong | quartic-in | |
  | TooMuch | exponential-in | sits near 0.1 nearly the whole time, then snaps back |

  Duration is a separate enum: **Short 0.15s, Normal 0.3s, Long 0.6s, Forever 2s**.
  A new hit-stop **cancels** the one in flight.
- **Ours:** `Shaker.hit_stop(duration, time_scale)` sets `Engine.time_scale` to a **flat 0.02**
  and holds it, then **snaps back to 1.0**. Expressiveness comes from duration, computed with an
  ad-hoc `clampf` formula at each of ~9 call sites (0.03–0.24s; damage hits use
  `clampf(amount * 0.014, 0.04, 0.24)`). It is reference-counted so overlapping AoE calls compose.
- **Verdict:** `adapt` — and this is the highest value-per-line finding in WS4.
  - **Depth 0.02 → ~0.1 and ramp out instead of snapping.** Our own source comment records that
    we pushed depth down to 0.02 because the effect was imperceptible — but we were compensating
    for the *shape*. A flat hold followed by an instant snap back to full speed is exactly what
    reads as a hitch rather than an impact; the snap is the ugly part. Ramping out lets a
    *shallower*, safer freeze feel heavier.
  - **Move expressiveness from duration to curve.** Named strength levels beating per-call-site
    `clampf` formulas is also a maintainability win: right now the relationship between a 6-damage
    poke and a 20-damage haymaker is encoded in a magic multiplier at each site.
  - **`already better` — keep our reference counting.** Theirs cancels the previous hit-stop;
    ours composes. We adopted ref-counting specifically because AoE cards fire one hit-stop per
    target and the shortest was cutting off the longest. Do not trade that away.
  - Their strongest level being named "TooMuch" is a good reminder that the top of the ladder is
    meant to be used rarely.

### 4.3 Shake: a magnitude ladder, and a better waveform

- **Theirs:** screen shake magnitudes are a named ladder — **VeryWeak 2, Weak 5, Medium 20,
  Strong 40, TooMuch 80** px — with durations **Short 0.3s, Normal 0.8s, Long 1.2s**. Note the
  deliberate **4× gap between Weak (5) and Medium (20)**: there is no gentle slope between "a tap"
  and "a real hit". Note also that **shake outlasts hit-stop at every level** (0.3 vs 0.15, 0.8 vs
  0.3, 1.2 vs 0.6) — you come out of the freeze while the screen is still moving.
  Creature shake is separate and is **horizontal only**: position.x follows a sine oscillation
  (~4 cycles) multiplied by a **second, slower sine acting as a rise-and-fall envelope**, at
  amplitude **10px** over **1.0s**, cubic ease-out on the time parameter. It refuses to restart
  while already running, and refuses to play at all if a hurt animation is playing — so the shake
  is the *fallback* for creatures without bespoke hurt art. It's applied to a child visuals node,
  never the root.
- **Ours:** `Shaker.shake()` is **dead code — it is never called anywhere**; the only two mentions
  in the codebase are comments explaining why the author chose *not* to use it. All actual shaking
  is bespoke inline tweens per site. Our camera has `shake(intensity, duration)`, called once
  (thrown-die impact, intensity 7.0 / 0.12s), implemented as **uniform random 2D jitter with no
  decay envelope**, ending in a hard snap back to the original offset. We also have
  `punch_zoom` (4.5% zoom, 0.08s in / 0.22s out) on hits ≥ 15 damage, which they have no
  equivalent of.
- **Verdict:**
  - `adopt idea` — **the envelope.** Their sine-times-sine (grow then die) versus our
    constant-amplitude-then-stop is the difference between a recoil and a rattle, and it's a
    two-line change to our camera shake.
  - `adopt idea` — **horizontal-only for creature shake.** A creature standing on the ground that
    jitters vertically reads as levitating. This matters more for us than for them: we spent
    multiple sessions getting enemies planted on a consistent ground line, and a 2D jitter
    partially undoes that work every time something gets hit.
  - `adopt idea` — **a named magnitude ladder** shared by shake and hit-stop, with the deliberate
    gap in the middle. Ours are raw floats chosen per call site.
  - `already better` — **`punch_zoom`.** They don't have it; ours is well-tuned and is a genuinely
    good big-hit signal. Keep it.
  - **Housekeeping:** delete or fix `Shaker.shake()`. A helper that no caller uses, which two
    comments actively warn against using, is a trap for the next person.

### 4.4 Damage numbers: ours is more expressive, theirs is more readable

- **Theirs:** spawned at the creature's VFX point **+(0, −100)** with **±10 / ±5** jitter, then
  driven by **real physics in `_Process`** rather than a tween path: initial velocity
  **x ∈ ±100, y ∈ −700…−800**, constant gravity **(0, +2000)**. That works out to an apex at
  ≈**0.375s** and ≈**140px** up — a genuine ballistic arc, different every time, for free.
  Layered on top, all in parallel: colour → cream over **0.5s** (cubic out); **scale 2.5× → 1.0
  over 1.2s** (quad out); and **alpha → 0 over 2.0s with ease-IN** — i.e. it stays fully readable
  for most of its life and disappears late. Label scale is additionally randomized 1.2–1.3 and
  rotation ±5°. **Total lifetime 2.0s.** There is **no damage-scaled treatment at all** — a 4 and
  a 40 get identical choreography.
- **Ours** (`damage_popup.gd`): total lifetime **0.6s**. Everything rides one shared 0–1 curve
  keyed to damage (cap 22): start scale 0.55→0.15, overshoot 1.04→1.6×, hop height 14→42px,
  spawn flash 1.12→2.1 overbright, and a resting size that itself grows with damage. Randomized
  rotation ±8°, spawn offset ±14/−10…+6, drift ±35. Fade holds 60% of life then fades. Plus a
  dedicated `show_blocked()` variant in steel blue.
- **Verdict:**
  - `already better` — **damage-scaled choreography.** Ours makes a big hit *look* like a big hit
    through five simultaneous channels; theirs treats every number identically. Do not trade this.
  - `adopt idea` — **alpha ease-IN.** Ours holds 0.36s then fades over 0.24s; theirs holds nearly
    the full 2s. Ease-in on alpha is a one-word change that buys readability with no extra time.
  - **VERDICT NEEDED — lifetime.** Theirs lives **3.3× longer** (2.0s vs 0.6s). Longer numbers are
    much better for a trailer and for reading a multi-hit. But we fire numbers far more often than
    they do (a dice game with volleys and AoE), so 2.0s could turn into visual soup. A middle
    value (~1.0–1.2s) with our existing damage-scaling is my recommendation, but it's a
    feel call on footage, not something to decide from a table.
  - `adopt idea`, low priority — **ballistic motion in `_process`** instead of two chained
    position tweens. It's not better-looking per se, but it gives per-instance variance for free
    and would let the hop and the fall share one continuous curve rather than meeting at a seam.

### 4.5 Two structural things around the juice, both worth noting

- **A player-facing speed setting.** They ship a four-value speed preference (None / Normal /
  Fast / **Instant**), explicitly documented in their own source as *not* a time-scale multiplier —
  it's a set of branch points where animations are skipped outright. The death VFX checks it and
  returns early. **Ours:** no equivalent; every animation always plays at full length.
  **Verdict:** `adopt idea`, and note the dependency — **this is the thing that makes it safe to
  make our death animation longer.** If we add a 1.5s death with no way to speed it up, replays
  and swarm fights get slower with no escape hatch. The two changes should ship together.
  It's also a real accessibility/QoL feature in its own right, and cheap: a preference plus a
  handful of early-returns at the animation entry points we already have.
- **Impact VFX is authored per attack archetype.** Their VFX shader folder is organised by
  *kind of hit* — dagger, heavy blunt, shiv, missile, goopy impact, sweeping beam, scream, poison,
  fire, and so on. **Ours:** one directional slash for every ATTACK card (plus the separate
  thrown-dice bash), tinted by the active die's colour.
  **Verdict:** `skip` for launch, but worth recording as the shape of the ceiling. Our slash is
  already tinted per die type, which is a cheap approximation of the same idea. If we ever expand,
  the natural axis for us is **per die type**, not per weapon — that's the vocabulary our players
  already read, and it costs one texture per type rather than one per card.

### 4.6 Card and hand motion (partial — see next probes)

- **Theirs:** cards are **300×422** (ours: 140×210 — theirs is over 2× larger per axis, on a
  1920-wide screen vs our 1280). The **hand animates as a single unit**: when disabled it drops
  **100px and dims over 0.2s** (cubic out); when hidden it slides **500px down over 0.8s**
  (back-in on the way out, expo-out on the way in). Selecting a card lifts and scales it via a
  0.5s quad in-out on a dedicated container.
- **Ours:** we dim cards **individually** via per-card `set_playable_visual()` (two brightness
  levels, 0.6 with Power banked / 0.75 without), and the hand itself never moves.
- **Verdict:** `adopt idea` — **drop-and-dim the whole hand as one object during the enemy turn.**
  This is a cheap, high-legibility beat: it says "not your turn" with motion instead of asking the
  player to notice that five separate cards each got slightly darker, and it pairs naturally with
  the End Turn button work in 1.6. Per-card dimming stays for *"this specific card is unplayable
  right now"* — the two signals are different questions and should look different.
- **Next probes (not done):** exact card-play flight timings to verify the values we eyeballed
  from video (WS4 bullet 4 of the plan). The per-card play choreography did not surface in the
  hand or card node constants; it likely lives in a dedicated play-animation class or in
  `animations/`. One focused probe next session should close it.

---

## WS2 — Enemy AI, cadence & encounter math

Session B, 2026-08-15. Probed: `src/Core/MonsterMoves/` (the whole move system, 5 files),
`src/Core/Models/MonsterModel.cs`, 8 of 122 monster classes chosen to match our archetypes,
`src/Core/Models/EncounterModel.cs`, `ActModel.GenerateRooms`, `src/Core/Rooms/RoomSet.cs`,
the intent class list, and targeted greps across all 122 monsters. Our side re-read in code:
`scenes/enemy/enemy_action_picker.gd`, `enemy_action.gd`, `run.gd::_get_unique_battle_for_tier`,
`battle.gd` act-2 tables.

### 2.1 Move selection is a state GRAPH, not a weighted list — **this is the headline**

- **Theirs:** every monster builds a small **state machine** whose nodes are of three kinds:
  a **move state** (one performable move + its intents + a pointer to its follow-up state), a
  **random branch** (weighted pick between states), and a **conditional branch** (an ordered
  list of state/predicate pairs, first true wins). The machine walks from node to node until it
  lands on a move state; branch nodes are transparent (they don't appear in the move history).
  Monsters are code-defined, one C# class each, and the machine is rebuilt fresh per combat.
  A move state can also be flagged "must perform at least once before we're allowed to leave
  this state".
- **Ours:** `EnemyActionPicker` is a **flat list of sibling nodes** with two kinds — CONDITIONAL
  (checked first, in child order, first `is_performable()` wins) and CHANCE_BASED (accumulated-
  weight roll). Verified in `scenes/enemy/enemy_action_picker.gd`.
- **Verdict:** `already better` on the two primitives — our CONDITIONAL list is *semantically
  identical* to their conditional branch, and our weighted roll to their random branch. The
  real difference is not the primitives, it's that theirs **compose**: a branch can point at
  another branch, and a move can point at a specific next state. Ours is one flat pick per
  turn with no memory of where we are in a sequence. See 2.2 and 2.3 for the two things that
  buys them; both are adoptable piecemeal without rewriting our picker.

### 2.2 Their constraint vocabulary is richer than ours — 4 knobs we don't have

- **Theirs:** each branch of a weighted pick carries, alongside its weight:
  - a **cooldown** (an integer N: this move is weight-zero if it appears anywhere in the last N
    *moves actually performed*),
  - a **repeat rule**, one of: repeat freely / **cannot repeat** (not twice in a row) / **can
    repeat at most X times consecutively** / **use only once per combat**,
  - and the weight itself may be a **function evaluated at pick time**, not a constant — so a
    move can get likelier or vanish based on live state.
  The repeat rules are enforced by walking backwards through the move-history log; "use only
  once" checks the whole log, the consecutive rules check the tail.
- **Ours:** the picker itself has **no** repeat/cooldown concept at all. Where we need one, the
  individual action script hand-rolls it — `last_action_count >= 2` appears in exactly **5**
  action scripts (`enemies/leviathan/1.gd`, `leviathan/weak_debuff_attack.gd`,
  `medusa/medusa_attack_action_2.gd`, `medusa/medusa_attack_weak.gd`,
  `satyr/bigger_satyr_attack_debuff.gd`). Weights are constants (`@export_range` on
  `chance_weight`). No cooldown, no once-per-combat, no dynamic weight.
- **Verdict:** `adopt idea`, cheaply and in this order:
  1. **"Cannot repeat" as a base-class flag** rather than five copies of the same hand-rolled
     counter. This is the single highest-value one for §8.2 — our tier-0 note "add *debuff not
     twice in a row* cap to S.Satyr / S.Kraken" is exactly this, and doing it as one `@export`
     on `EnemyAction` makes it free for every future enemy instead of a 6th copy.
  2. **Cooldown N** — this is the tool §8.2 actually wants for the elites and never named. It
     is strictly better than a repeat cap for spikes: "the 15 can't come back for 2 moves"
     guarantees the rhythm without forcing a fixed cycle.
  3. **Use-only-once** — we express this today with ad-hoc booleans (Hound's Exposed beat).
  4. Dynamic weights: `skip` for now. Our `is_performable()` gate already covers the "should
     this be possible at all" question; graded likelihood is a luxury.

### 2.3 Fixed cycles are chains, not modulo arithmetic — and this removes a hazard we hit

- **Theirs:** a fixed cycle is expressed by each move pointing at its own successor. Their
  thief runs a literal 5-link chain; their sleeping boss runs a 4-link awake cycle; their clam
  is a 2-link alternation. **No monster reads a turn counter to decide a cadence** (verified:
  zero of 122 monster classes reference the turn number at all — see 2.5).
- **Ours:** we build cadences with `fight_turn % N` conditions. Our own §9.8 shipped note
  documents the cost: the Leviathan's promoted guard beat (`% 4 == 3`) collided with the
  act-2 Dicelord theft beat (`% 3 == 1`) every 12 turns, one silently eating the other, and
  the fix was to hand-compute a phase offset (`% 4 == 2`) plus reorder the children — with a
  standing warning that *any* future change to either modulus requires redoing that collision
  math.
- **Verdict:** `adopt idea`, **post-launch, and only for enemies that get a new kit anyway.**
  A follow-up pointer per action makes cadence collisions structurally impossible (a chain has
  exactly one successor; there is nothing to collide with) and it reads better in the scene
  tree. But converting shipped, playtested cadences is a real refactor of `EnemyActionPicker`
  and the AI `.tscn`s, and the two we shipped are verified by harness. **Do not retrofit
  Medusa/Leviathan.** Worth noting in §9's guardrails that the modulo approach carries this
  tax so the next authored cadence doesn't rediscover it.

### 2.4 Pack desync is solved by branching the opener on **slot position** — answers an open §8.2 verdict

- **Theirs:** their four-body roach pack opens with a conditional branch keyed on the
  creature's **slot name** ("first" / "second" / "third" / "fourth"): body 1 opens with the
  multi-hit, body 2 with the heavy attack, body 3 with the self-buff, body 4 goes straight to
  the random pool. Four identical monsters, four different opening turns, **deterministically**.
  After the opener they converge onto a shared weighted pool (with cannot-repeat).
- **Ours:** §8.2 lists "B.Kraken 50/50 opener so twin pairs desync naturally" as **OPTIONAL,
  verdict needed**, flagged risky because a random opener *can* still collide (both roll the
  same) and because it changes a validated tier-0 fight — worst case the pair opens 7+7=14
  unblocked.
- **Verdict:** `adopt idea` — and it **resolves the open verdict in a better form than the one
  we proposed.** Position-keyed openers give guaranteed variety with **zero added variance**:
  the twin pair always desyncs, and the 7+7 double-spike that made us hesitate becomes
  *impossible* rather than merely unlikely. We already have the plumbing — an enemy knows its
  index in `EnemyHandler`'s children, which is exactly their "slot name". This is the cheapest
  texture win in the whole §8 batch and it removes a risk instead of adding one.
  **VERDICT NEEDED** only on whether to apply it to tier 0 at all (Julien's standing concern is
  touching validated teaching fights) — but the mechanism question is settled.

### 2.5 Anti-stall: **STS2 has no soft enrage, no global timer, and no monster reads the turn count** — the §9.7 answer

This is the question WS2 existed to answer, so it gets the full evidence:

- **Zero of 122 monster classes reference the turn counter.** The property exists and is widely
  read — by **54 relics** (player-side "on turn N" effects) and a handful of engine files — but
  no monster consults it. There is no per-turn escalation rule anywhere in the monster layer.
- **The word "enrage" in shipped content is a move name and a player-facing power, not a
  timer.** Two monsters have an "Enrage" *move* (a beat in their cycle that grants +2 Strength).
  The Enrage *power* triggers on **the player playing a Skill** — behavioural, not temporal.
- **"Doom" is not a timer either** — it's an execute threshold ("at end of turn, if it has at
  most N HP, it dies"), a finisher mechanic.
- **What they use instead:** ramps are **moves or powers granted by moves**, never rules. Their
  cultist's whole kit is: turn 1 cast a ritual power, then attack for 9 forever — and the
  ritual power grants Strength at the end of every turn thereafter, automatically, with a
  visible badge. So the fight *does* have a clock, but the clock was **installed by a
  telegraphed move on turn 1** and is legible as a status the player can point at.
  A nice honesty detail: the power deliberately **does not tick on the turn it is applied**
  (there's an explicit one-shot skip), so the buff number never jumps by surprise.
- **Their hard deadlines are scripted, not global.** The thief's fixed chain ends in an escape
  move that loops on itself — the "you have 4 turns" pressure is authored into that one
  encounter's script, not into a system.
- **Ours:** §9.5 proposes a shared **soft-enrage backstop**: from turn T (6/7/8/9/11 by tier)
  every living enemy gains +1 Muscle per turn forever, as a hidden global rule surfaced via a
  status badge.
- **Verdict:** **VERDICT NEEDED — but the reference argues against the backstop, and *for* the
  rest of §9.** Precisely:
  - The **authored ramp column (§9.4) is fully vindicated.** Ramp-via-visible-beat is exactly
    and only what they do. Their cultist is our Marauder; that pattern is the reference
    standard. Ship that column.
  - Their ramps are also **more efficient than ours**: one move installs a self-ticking power,
    rather than a beat that must recur to add each stack. Our Defender/Oculus/Venom Bloom
    "+N Muscle on a cycle beat" needs the beat to come around; a Ritual-style status ticks
    every turn from a single application. **`adapt`:** for a *new* ramp where the enemy has no
    natural recurring buff beat, prefer "one early move applies a per-turn Strength status"
    over "add a buff beat to the loop" — it's fewer beats, more legible, and doesn't cost a
    slot in a cycle we're trying to keep short.
  - The **backstop is the one item with no counterpart in the reference.** MegaCrit's answer to
    stable-state is per-fight authored pressure plus encounter design, not a global rule. That
    is evidence, not proof — they also have no uncapped carryover mechanic, which is the
    specific thing that motivated ours (§9.1). So the honest framing for Julien: *the backstop
    is a Dice-Odyssey-specific answer to a Dice-Odyssey-specific problem (uncapped Golem), and
    the reference offers no support for it as a general invariant.* If the authored column
    lands and Golem stall still pays, the backstop is the targeted fix. Shipping it
    pre-emptively as an invariant is the part the reference does not back.
  - Corollary for §9.6's guardrails: their "one clock per fight" is implicit — each monster has
    at most one ramping source. Our stated guardrail matches.

### 2.6 HP thresholds and phases: rarer than expected, and expressed *inside* the move graph

- **Theirs:** only **9 of 122** monsters reference current HP at all, and most of those are
  bookkeeping (setting max HP, segment splitting). Genuine HP-threshold **behaviour** switching
  appears in exactly one of the classes read: a knight whose opening branch picks a different
  move below **50%** HP — and it's written as a **conditional branch in the move graph**, not
  as a damage hook. Their act-1 sleeping boss (222 HP) *does* use a damage hook at 50%, but
  only to open its eyes — a **purely cosmetic** tell; its actual wake-up is driven by a
  3-stack sleep power, and its awake behaviour is a fixed 4-move chain.
- **Ours:** we have no HP-threshold behaviour at all today. §8.2 proposes the Lava Hound's
  "Molten Roar" at ≤50% as the game's first.
- **Verdict:** `adopt idea`, with a **structural correction to the §8.2 plan**: implement the
  threshold as a **CONDITIONAL action whose `is_performable()` reads own HP**, not as a
  damage-received hook. We already have that shape (the unwired `crab_mega_block_action`
  precedent §8.2 cites). It keeps the check on the same path that produces the intent, which
  is what makes it honest — a hook that fires mid-damage can desync from a displayed intent,
  which is the §2.4 Chimera snapshot footgun in a new costume. Also worth copying: they
  separate the **tell** (eyes open, on damage) from the **behaviour** (move choice, in the
  graph). Our Roar can do the same — a VFX tell the moment 50% is crossed, the actual beat
  chosen by the picker next turn.

### 2.7 Encounter generation: a pre-drawn queue from a refilling grab bag, plus a tag-adjacency rule

- **Theirs:** at act generation the **entire act's fight order is drawn up front** into one
  ordered list. A grab bag is filled with every eligible encounter (all at weight 1.0), drained
  without replacement, and refilled when empty. The first **3** entries are drawn from the
  **weak** pool, all remaining entries from the **regular** pool; elites are pre-drawn the same
  way (15 of them); the boss is a single random pick from the act's 3. Rooms then just consume
  the list in order, indexing by "how many of this room type have I visited", wrapping with a
  modulo. Events are one shuffled list consumed the same way, with a validity scan that skips
  forward past events disallowed by run state or already seen **this run**, and logs a warning
  then permits repeats once genuinely exhausted.
  The only variety constraint is: **the next encounter must not be identical to, nor share a
  tag with, the immediately preceding one** — with a fallback that takes anything if no
  candidate qualifies. Tags are a small enum (~16 values: Slimes, Thieves, Knights, Slugs,
  Workers, Exoskeletons…) and an encounter may carry **several**.
- **Ours:** `run.gd::_get_unique_battle_for_tier` draws **at the moment of entering the room**:
  filter the tier's pool by a `used_battles` list, weighted-roll among the survivors, and when
  the tier is exhausted, clear that tier's entries and recurse. Our `group` field (e.g.
  `"slimes"`) marks **every other member of the group as used for the rest of the tier** the
  moment one is picked.
- **Verdict:** mostly `already better`-or-equal, with one idea worth taking:
  - Our **`group` is their tag** — same idea, independently arrived at. Ours is *stronger*
    (whole-group lockout vs. adjacent-only). Given our tier-0 pool is mostly critter fights,
    the strong version is what forces the 3 non-critter fights into floors 1-3, so **keep it**.
    Their multi-tag support is the one refinement worth stealing if a fight ever belongs to two
    families; single-string `group` can't express that.
  - Their **draw-up-front queue** is architecturally cleaner than our draw-on-entry (no
    recursion, no exhaustion special case, and the whole act is inspectable at generation for
    testing). **`skip` pre-launch** — ours is playtested and the save format stores
    `used_battles`; changing to a queue is a save-format change for zero player-visible gain.
    Note it as the shape to adopt if the run generator is ever rewritten.
  - **`adopt idea`, cheap:** their event system distinguishes *"disallowed by current run
    state"* from *"already seen"*, and **degrades to allowing repeats** rather than running dry.
    We added `required_dice_type` gating on 2026-08-14 (the Blue/Red loadout fix) — that is
    their per-event "is this allowed given the current run state" predicate exactly, so that
    design is validated. What we lack is their
    graceful-exhaustion fallback; worth a look at whether a heavily-gated event pool can starve.

### 2.8 Monster HP is a rolled range, and difficulty scales stat-by-stat rather than by multiplier

- **Theirs:** each monster declares a **min and max initial HP** and the actual value is rolled
  per encounter from a per-encounter RNG stream (kept separate from the run RNG on purpose,
  since encounter RNG state doesn't need to persist). Some monsters pin min = max where the
  fight wants an exact number (their thief: 79 flat; their act-1 boss: 222 flat). Examples
  read: trash roach **24–28**, cultist **38–41**, clam **56**, guard-bot **16–20**.
  Difficulty (ascension) is applied **per stat at the declaration site** via a helper — a
  "tough enemies" level bumps the HP range (e.g. 24–28 → 26–30), a separate "deadly enemies"
  level bumps individual damage numbers (e.g. 8 → 9, 17 → 19). There is no global multiplier.
- **Ours:** HP is a single fixed number per `EnemyStats` `.tres`, with a **separate `.tres` per
  tier** for shared enemies. Act 2 applies a **global multiplier table** by tier
  (`ACT2_HP_MULT` = 1.55 / 1.3 / 1.75 / 1.75 / 1.6) plus a flat per-fight damage bake
  (`ACT2_DAMAGE_BASE` = 2 / 3 / 4 / 5 / 4, divided across bodies).
- **Verdict:** `skip` on HP ranges — deliberate. Rolled HP is a *variance* feature, and our
  combats are already variance-heavy by construction (dice). Fixed HP is what makes "Bullseye
  at roll 6 kills an 18 HP Satyr" a learnable fact, which is worth more to us than it is to
  them. Recording it because it explains a real difference in feel, not because we should copy.
  `already better` on the tier `.tres` split — their ascension helper is doing the same job
  (one declaration site, difficulty applied at read time) and our per-tier resources are the
  more explicit form of it.

### 2.9 Intent honesty: N intents per move, and hidden intents are effectively unused

- **Theirs:** a move carries a **variable-length list of intents**, not one. Their act-1 boss
  has a move that is attack **+** defend (two intents on one beat) and another that is debuff
  **+** buff. There are **15 intent types** (attack, multi-attack, single-attack, buff, debuff,
  strong-debuff, defend, escape, heal, hidden, summon, sleep, stun, status-card, card-debuff,
  death-blow). Each intent supplies its own icon, label, and hover tip, so a two-intent move
  produces two tips. **Hidden/Unknown intents appear in 5 monster classes, 4 of which are test
  dummies** — i.e. in shipped content, essentially everything is telegraphed.
- **Ours:** as of 2026-08-14 we have exactly **two** icon slots (`Intent.icon2`, the STS2-style
  rider), with tooltip composition for the pair, and the layout `[number][primary][rider]`.
- **Verdict:** `already better` than we thought, and the rider work is **confirmed correct** —
  we independently landed on their exact model. Two refinements:
  - Their intent list is **N-wide, not 2**. Our §9.9 note says the act-2 wave is where combos
    explode; if a third rider ever appears, the fix is to make the slot row a loop rather than
    add `icon3`. Not needed now.
  - **The honesty bar is higher than ours.** They have a first-class *hidden* intent type and
    still use it almost nowhere. That is a strong argument for closing our §2.4 honesty bugs
    (the Absorb tooltip that doesn't exist, the Flux tooltip that contradicts its code) before
    any new enemy content — those are our de-facto hidden intents, and we didn't choose them.

### 2.10 Archetype-matched numbers (their side, for calibration)

Gold, for reference: monster rooms **10–20**, elites **35–45**, boss **100** flat (before
difficulty modifiers). Ours: tier-2 fights normalized to 40–50, act 2 ×1.5.

| Their archetype | HP | Kit (in order) | Shape | Our nearest |
|---|---|---|---|---|
| Trash, 4-body pack | 24–28 | opener by **slot**: multi-hit 1×3 / heavy 8 / self-buff +2 Str / straight to pool → then weighted pool of {1×3, 8} with cannot-repeat; heavy always chains into the buff | conditional opener → chain → weighted | S.Satyr / S.Kraken packs |
| Ramper | 38–41 | ritual (grants +2 Str **per turn**, forever) → attack 9 → 9 → 9 … | 2-node chain, self-ticking clock | Marauder (True Strength) |
| Guard / protector | 16–20 | one move, forever: **grant 15 Block to allies** | single self-looping node | *nothing* — we have no protector |
| Alternator | 56 | buff ↔ attack 10, strict alternation | 2-node cycle | Oculus (7 / +2 Str) |
| Thief | 79 flat | steal-attack 17 + card theft → buff → 21 → 14 → **escape** (self-loop) | pure 5-link script, no RNG | *nothing* — our §4.2 Cutpurse |
| Act-1 boss | 222 flat | sleep (3 stacks) → on wake, fixed cycle: 17-ish slash → multi-hit → **attack + block** → debuff+buff → repeat | conditional gate → 4-link cycle | Leviathan (weighted 3-beat) |

Two things this table says out loud:

1. **Their trash is more textured than our trash, and their bosses are *less* random than
   ours.** Our Leviathan is a weighted soup with caps; their act-1 boss is a deterministic
   4-beat loop behind a sleep gate. This inverts the intuition §8 was built on — the
   scannable, memorizable pattern is reserved for the **big** fights, where the player is meant
   to plan several turns ahead, and the variance lives in the small fights where a surprise is
   cheap. Our §9.4 note that the Leviathan cadence promotion is "the smallest possible boss
   touch" is directionally right and this is supporting evidence for it.
2. **Roles we have zero of:** a pure protector (grants Block to allies, no attack) and a
   fleeing thief. Both are called out in our §1.6/§4.2 as gaps; both are *tiny* kits in the
   reference — the protector is literally one move. If Julien ever reopens "additive fights",
   the protector is the cheapest new body in the design space and it changes target priority
   in a way nothing in our roster currently does.

### 2.11 Drive-by found while verifying our side (not from the reference)

- `scenes/enemy/enemy_action_picker.gd::get_action()` opens with a bare
  `print(Global.fight_turn)`. It fires **once per enemy per intent refresh**, so several times
  a turn in a multi-body fight, in release builds too (Godot's `print` is not stripped). It's
  leftover debug output — noise in the itch/web console and a small per-call cost. One-line
  delete; unrelated to any WS2 finding but found in the file the workstream sent me to.
- Confirmed for the §8.4 prerequisite list: `EnemyAction.is_performable()` on the base class
  returns **`false`**, so the `get_child(0)` fallback in `get_chance_based_action()` really is
  the only thing keeping the Lich / Gargantua / Sigil steady attacks running. The wiring pass
  §8.4 demands is not optional before any of the pattern edits above.

---

## WS3 — Economy & reward numbers verification

Session C, 2026-08-15. Probed: `src/Core/Odds/` (all 6 files), `src/Core/Models/EncounterModel.cs`
(gold), `src/Core/Entities/Merchant/` (all entries + inventory), `src/Core/Entities/RestSite/`.
Our side re-read: `custom_resources/run_stats.gd`, `scenes/battle_reward/battle_reward.gd`,
`scenes/shop/shop_card.gd`, `shop_relic.gd`, `card_shop.gd`, `scenes/campfire/campfire.gd`.

**Headline: our economy is startlingly close to theirs.** Julien built ours from community data
and feel; the ground truth validates nearly every number. Only two mechanisms differ in a way
worth thinking about, and both are 3.1.

### 3.1 Card reward odds — our numbers are right, our pity curve is a different animal

- **Theirs**, as base probabilities (not weights), per context:

  | Context | Common | Uncommon | Rare |
  |---|---|---|---|
  | Regular fight | 0.60 | 0.37 | 0.03 |
  | Elite | 0.50 | 0.40 | 0.10 |
  | Boss | 0 | 0 | **1.00** |
  | Shop | 0.54 | 0.37 | 0.09 |
  | "Uniform" (some events) | 0.33 | 0.33 | 0.33 |

  The pity is a single **rare-odds offset** carried across the run: it starts at **−0.05**,
  grows **+0.01 per card rolled**, caps at **+0.40**, and resets to **−0.05** whenever a Rare
  comes up. Three refinements: shop rolls **read but never write** the offset; some events roll
  **base odds only** (offset ignored entirely); and boss rolls ignore the offset when rolling
  (they're 100% Rare anyway) **but still reset it** — so taking a boss reward wipes your pity.
- **Ours:** weights 6.0 / 3.7 / 0.3 = **60 / 37 / 3%** — *identical* to their regular-fight row
  (deliberately: Julien asked for "the hallway odds of STS"). Elite is a local multiplier
  (uncommon ×1.4, rare ×4.0) which normalizes to **≈48.5 / 41.8 / 9.7%** — within a point of
  their 50/40/10, arrived at independently. Boss bypasses the draw entirely: all 3 Rare. Pity:
  **+0.2 rare weight per screen** with no rare, cap **2.0** (≈17% per slot), reset to 0.3 when a
  screen contains a rare.
- **Verdict:** `already better` on the base odds and elite/boss handling — nothing to change.
  Two genuine differences, both **VERDICT NEEDED** and both cheap:
  1. **Pity granularity and ceiling.** Theirs steps per *card*, ours per *screen* (3 cards), and
     the ceilings differ a lot: theirs tops out around **43%** rare chance per card, ours at
     **17%**. Ours ramps faster early (+0.2/screen ≈ +0.067/card vs their +0.01/card) but stops
     far lower. Net effect: a long dry spell in their game eventually *guarantees* a rare feels
     imminent; in ours it plateaus at "somewhat likely". Our measured outcome (~2.6 rares/run,
     20% of screens) is healthy, so this is a taste call, not a bug — but if Julien ever wants
     dry spells to end harder, raising `RARE_WEIGHT_PITY_CAP` is the single dial.
  2. **Their starting offset is negative.** At −0.05 against 0.03 base, **the first few card
     rewards of a run literally cannot be Rare** — it takes ~3 non-rare rolls before rare
     becomes possible at all. That's a deliberate "no jackpot on floor 1" rule we don't have.
     It protects the early-run difficulty curve from a turn-3 build-defining drop. Cheap to
     copy (start `rare_weight` below zero-effective for the first screen or two); worth
     considering given our pool has only 5 Rares and several are run-defining.

### 3.2 Shop composition: they guarantee **card types**, we guarantee **rarities**

- **Theirs:** the shop stocks a fixed slot layout — **5 character cards by TYPE**
  (Attack, Attack, Skill, Skill, Power), each slot's *rarity* then rolled at shop odds
  (54/37/9); **2 colourless cards** at fixed rarities (1 Uncommon, 1 Rare); **3 relics**
  (2 at rolled rarity + 1 from a shop-exclusive rarity pool); **3 potions**; **1 card removal**.
  Prices: **Common 50 / Uncommon 75 / Rare 150**, ×1.15 if colourless, then a per-item random
  jitter of **±5%**; relics use a per-relic authored cost × jitter of **±15%**; there's also a
  half-price **sale** flag on individual entries. Removal is **75 base + 25 per removal already
  bought this run** (ascension "Inflation": 100 + 50).
- **Ours:** 5 cards by **rarity** (2 Common, 2 Uncommon, 1 Rare), prices rolled from ranges
  Common **30–45**, Uncommon **50–70**, Rare **95–125**; relics **85–120**; removal
  **50 + 25/use**; 1 discounted "deal die" at −20%; no potions (we have no potion system).
- **Verdict:** `already better` on price *ratios* — theirs is 1 : 1.5 : 3 (50/75/150), ours is
  ~1 : 1.6 : 2.9 (37.5/60/110 midpoints). Same curve, arrived at independently. Removal
  escalation step is **identical** (+25/use); our base is lower (50 vs 75) but so are our card
  prices, so the ratio holds.
  **`adopt idea` — VERDICT NEEDED — on composition-by-type.** Guaranteeing *"there is always an
  Attack, always a Skill, always a Power"* answers a different and arguably more useful player
  question than "there is always a Rare": it means a deck that desperately needs defence can
  always find *something*, and it makes the Blessing/Power slot a reliable shop fixture rather
  than a lottery. Our `SHOP_COMPOSITION` is a 5-element array — swapping it from rarity tiers to
  card types is a small change, but it interacts with our rarity pricing (a type-slot needs a
  rolled rarity to price it), so it's a real decision, not a one-liner. Flagging rather than
  recommending: our shop is playtested and the rare-guarantee is a known good feel.
  `skip`: the ±5%/±15% price jitter (ours already rolls a range, same effect) and the sale flag.

### 3.3 Gold, campfire, and event gating — all three validate ours

- **Theirs:** gold per room — monsters **10–20**, elites **35–45**, boss **100** flat.
  Campfire heal is **30% of max HP**. The base rest site offers exactly **two** options,
  heal and upgrade; the other six options seen in the folder (cook, dig, hatch, kindle, lift,
  clone) are injected by relics/unlocks through a hook, not baseline.
  Events are consumed from a shuffled list, skipping any that a per-event
  "is this allowed in the current run state" predicate rejects or that were already seen **this
  run**, and after a full pass it logs a warning and permits repeats rather than running dry.
- **Ours:** tier-2 fights normalized to 40–50 gold, act 2 ×1.5. Campfire heal **33%** of max HP.
  Campfire offers exactly heal + upgrade. Events deplete from a pool with per-event gating
  (`required_dice_type`, added 2026-08-14).
- **Verdict:** `already better` / no action on all three. Campfire 33% vs 30% is noise. Our
  two-option campfire is *exactly* their baseline — the extra six are relic-granted content,
  which is the right shape for us to grow into later if we want. Gold is not directly comparable
  (different HP scales and price levels) but the *ratio* elite:monster is theirs 2.3× vs ours
  (elites aren't separately tabled — worth a glance during balance work, not now).
  One `adopt idea`, tiny: their **graceful event exhaustion** (warn + allow repeats) versus our
  pool that simply empties. With gating now in place, a heavily-gated pool could in principle
  starve; a fallback is a few lines of insurance.

### 3.4 A mechanism we don't have at all: drifting "?" room odds

- **Theirs:** entering an unknown ("?") map point rolls its actual type from odds that **drift
  across the run**: base Monster **0.10**, Treasure **0.02**, Shop **0.03**, Elite **−1**
  (a sentinel meaning *never*, and explicitly excluded from growth), remainder — about
  **85%** — is an Event. When a type comes up, its odds reset and the others grow. There are
  **10–14** unknown points per act (gaussian, mean 12), against 5 elites, 3 shops, and 6–7 rest
  sites.
- **Ours:** no unknown rooms. Every map node shows its type from the start; our node type
  weights are monster 5.5 / event 3.0 / campfire 1.5 / elite 1.2 / shop 0.8.
- **Verdict:** `skip`, deliberately, but worth recording *why*: "?" rooms are a **tension**
  mechanism (do I risk the unknown?) that costs map legibility — and map legibility is our one
  open playtest complaint (WS5). Adding uncertainty to a map players already find confusing
  would be exactly the wrong order of operations. Revisit only after WS5's fixes land.
  The **negative-sentinel-means-never** trick is a neat pattern worth remembering for any future
  weighted table where "excluded" must not silently become "eventually likely".

---

## WS5 — Onboarding, FTUE & map communication

Session C, 2026-08-15. Probed: `src/Core/Map/` (point model, type counts, post-processing, path
pruning), `src/Core/Nodes/Ftue/` (16 classes), the FTUE localization key list,
`src/Core/Odds/UnknownMapPointOdds.cs`. Our side: `scenes/map/map_generator.gd`.

**This workstream targets the one unaddressed playtest complaint — "je comprends pas la map" —
and the reference turns out to have a direct, documented answer to it.**

### 5.1 They run an explicit map **readability post-pass**, and shipped it *because of player complaints*

- **Theirs:** after the map graph is generated, three clean-up passes run over the grid, in a
  file whose own header comment says these exist to make the map "more clean looking and less
  cluttered" and to address "some of the complaints":
  1. **Centre the grid** — if the outermost columns are empty, shift every node sideways so the
     map sits centred rather than drifting to one edge.
  2. **Straighten paths** — any node with exactly one parent and one child gets nudged toward
     the column that makes the line straight, turning wobbly single-file runs into clean
     verticals.
  3. **Spread adjacent points** — within a row, nodes are moved to the positions that maximise
     the gap to their neighbours, so no two nodes crowd each other.
  All three respect a hard constraint: a node may only sit in the same column as each of its
  parents/children, or one column left/right — so straightening can never create a crossing or
  an implausibly long edge. The author notes the whole pass costs ~0 ms.
- **Ours:** `map_generator.gd` places nodes on a 150×125 grid and adds a **uniform random
  jitter of up to 22 px** (`PLACEMENT_RANDOMNESS`), then connects them. There is **no**
  post-pass: no centring, no straightening, no spreading. The jitter is applied *once, blindly*
  — it can just as easily push two neighbours together as apart. We do have a crossing check
  (`_would_cross_existing_path`) at connection time, which is a different (and good) guard.
- **Verdict:** **`adopt idea` — and this is the highest-value item in Session C.** It is a
  pure-layout, post-generation transform: it cannot change which rooms exist, which paths are
  legal, or any balance number, so it is unusually low-risk for a pre-launch change. It also
  attacks Julien's complaint at the right layer — the map isn't confusing because of what it
  *contains*, it's confusing because of how it *reads*.
  - **Cheap version (recommended):** implement pass 3 only — replace the blind ±22 px jitter
    with "nudge each node to maximise the gap to its row neighbours, clamped to ±22 px". Same
    organic look, but the randomness can no longer work against legibility. Roughly one
    function in `map_generator.gd`, no data changes, verifiable with our existing
    `debug_map_look.gd` harness.
  - **Expensive version:** all three passes plus 5.2's pruning, which starts to be a real
    rewrite of layout and would want its own harness pass.

### 5.2 They detect and delete **duplicate path segments**

- **Theirs:** a separate pruning step finds repeated path segments across the act graph and
  removes them, looping up to **50** iterations. Because deleting nodes can drop a room type
  below its target count, a **repair** step then converts monster rooms back into whatever type
  went missing. Both of their real map generators run this after point-type assignment.
- **Ours:** nothing equivalent. Our 6 paths across a 7-wide, 15-floor grid are generated
  independently and can overlap heavily — two "different" routes can be the same rooms.
- **Verdict:** `adopt idea`, **post-launch**. This is the deeper reason a map feels
  undifferentiated: if two branches are the same, the choice they present is fake, and players
  correctly sense there's nothing to understand. But it's a genuine graph algorithm plus a
  repair pass, and it can change the *distribution* of room types — that makes it a balance
  touch, not just a visual one. Not a pre-launch change. Record as the sequel to 5.1.

### 5.3 Their onboarding is **15 one-shot, opt-in tips**, not one scripted tutorial

- **Theirs:** a family of 16 small modal classes, each with a fixed id, each shown the first
  time its concept appears: cannot-play-a-card, can-play-cards, combat rules, rewards, relic
  reward, chest, merchant, rest site, shuffle, potion, obtain-potion, Power card, enchantment,
  affliction, map select, ascension (×2). The base class is a modal that **registers itself as
  a hotkey-blocking screen** on entering the tree and unregisters on leaving, and frees itself
  on close — so a tip can never leave input in a broken state. Crucially, the *first* tip is
  **"accept tutorials?"** — the whole system is opt-in.
- **Ours:** one long scripted `TutorialDirector` sequence for the first combat (28 sub-steps),
  gated by an opt-in popup at run start, plus **three** ad-hoc one-shot popups on the reward
  screen (bonus-effect — currently disabled, Celestial, Blessing) driven by
  `Global.tutorial_*_explanation_needed` flags.
- **Verdict:** `already better` on two counts, `adopt idea` on one.
  - **Already better:** our opt-in prompt matches theirs exactly, and our scripted first combat
    teaches the *dice-specific* core (roll → bank → spend, the thing no player has seen before)
    far more thoroughly than a modal could. Don't replace it.
  - **Already better:** our one-shot popup flags are the same pattern as their per-tip ids.
  - **`adopt idea`:** we have **3** such tips; they have **15**. The gap list — concepts we
    introduce with zero explanation — is where the value is. Concretely, we have no first-time
    tip for: **the map** (5.4), the **shop** (two shops with different currencies-of-attention),
    the **campfire** choice, the **first relic** you're offered, **reshuffling** the discard
    into the draw pile, and the **card-removal** service. Each is one small modal reusing the
    reward-screen popup we already built. This is the cheapest onboarding work available and it
    directly widens the funnel for the itch/Steam audience.

### 5.4 The "you can't play anything" tip is a small masterclass — and we already have half of it

- **Theirs:** the first time the player has no playable card, a modal appears explaining it.
  Two details make it good: it **raises the End Turn button above the modal dimmer** (so the
  button is literally spotlighted as the answer), and it installs a full-screen invisible
  hitbox where **clicking anywhere both dismisses the tip and ends the turn** — the player
  cannot get stuck, and the very first thing they do teaches the verb.
- **Ours:** we solve the same moment *without* a tip: `battle_ui.gd::_update_end_turn_highlight`
  pulses End Turn gold when no dice, no Power, and no Celestial card remain. And separately, our
  2026-07-30 refusal system shakes an unplayable card and floats a reason.
- **Verdict:** `already better` on the ongoing signal (a pulse every time beats a modal once),
  **`adopt idea`** on the first-time layer: the *first* time our gold pulse fires, a one-line
  tip naming the situation would convert an unexplained glow into a taught rule. The spotlight
  trick (raise the target above the dim) is also directly reusable by our
  `TutorialOverlay.show_glow` — we already dim and glow, we just never raise the real button
  above the dimmer.

### 5.5 Map composition and node states, for reference

- **Theirs:** per act — **15** rows, **5** elites, **3** shops, **10–14** unknowns (gaussian,
  mean 12), **6–7** rest sites (gaussian), the rest monsters, plus one boss and one "ancient"
  node. Map points carry an explicit four-value state: *travelable / traveled / untravelable /
  none*.
- **Ours:** 15 floors, 7 wide, 6 paths; node types by weight (monster 5.5, event 3.0, campfire
  1.5, elite 1.2, shop 0.8) rather than by target count. Our equivalent of their four states is
  the relevance tinting added 2026-07-26 (current 1.0, walked 0.88, passed rows 0.78,
  no-longer-reachable 0.85) plus the availability pulse and the ink selection ring.
- **Verdict:** `already better` on state communication — we tint four relevance levels where
  they carry four state values, and our ink ring + pulse are richer than a state enum implies.
  **One difference worth a `VERDICT NEEDED`:** they hit **target counts** ("this act has exactly
  5 elites, 3 shops"), we roll **weights**. Weighted rolling means a run can, by chance, offer
  two shops or six campfires — variance the player experiences as "this map is bad" rather than
  "this map is different". Target counts with a repair pass are how they guarantee every act is
  *structurally* the same shape while looking different. This is a moderate change to
  `map_generator.gd` and would change run pacing, so: post-launch, but it's the structural
  answer to "why do some of my runs feel starved of campfires".

---

## WS7 — Edge-case & input-locking checklist

Session C, 2026-08-15. Probed: hotkey/blocking-screen manager, card playability + target
validity in the card model, the damage hook phase enums, `Combat/CombatManager.cs` death
handling. Our side: `scenes/modifier_handler/modifier.gd`, `modifier_value.gd`, plus the
already-documented `_turn_cycle_active` guard.

### 7.1 Input locking is a **blocking-screen stack**, not a set of booleans

- **Theirs:** any modal (pause menu, inspect screens, FTUE tips, credits, feedback) calls a
  central manager on entering the tree to register itself as a blocking screen, and unregisters
  on leaving. While registered, every hotkey is bound to a no-op. Registration is keyed by the
  node itself, so it's inherently balanced — a screen that is freed cannot leave input locked.
- **Ours:** we lock input case by case with independent booleans and per-site bookkeeping:
  `_turn_cycle_active` + a generation token for the turn cycle, `map_consult_mode` in `run.gd`,
  `Global.dragging_card`, the tutorial's `_apply_gate` whitelists, `Hand.tutorial_card_gate`,
  plus `process_mode` juggling for the map-consult pause. Each was added in response to a
  specific bug (we shipped a double-end-turn bug, a tutorial soft-lock, and a map-scrolls-under-
  the-dimmer bug — all three are the same class of problem).
- **Verdict:** `adopt idea`, **post-launch** — but this is the most *architecturally* pointed
  finding in Session C. Our three shipped bugs in this family were each fixed correctly and
  each fix was bespoke; a registration-based lock would have made all three impossible by
  construction, because the lock's lifetime is tied to the locking node's lifetime. Not a
  pre-launch change (it would touch every modal we have), but it is the right shape, and the
  next time we add a modal or a pause state it is worth asking whether to introduce the
  registry then rather than adding boolean number four.

### 7.2 "Why can't I play this?" is a structured answer, not a string

- **Theirs:** the playability check returns a **flags enum** of reasons that *accumulate* (a
  card can be blocked for several reasons simultaneously) plus an out-parameter naming the
  **specific model doing the blocking**. The reason set distinguishes: has the Unplayable
  keyword, blocked by an external effect/hook, blocked by the card's own logic, not enough
  energy, not enough of a secondary resource, and no living allies to target.
- **Ours:** `Card.would_no_op_now()` returns a bool, and `card_ui.gd` picks between **two**
  hardcoded strings ("Card requirements are not met" / "You need ✦ Power to play this card").
- **Verdict:** `adapt` — worth doing, and cheap, when we next touch refusal UX. Our refusal
  system is good (drag-time, shake, floating reason, requirement-ribbon pulse) but it can only
  ever say two things. Returning a small reason enum instead of a bool would let it say the true
  thing: *"you have no dice of this type left"*, *"this card is Red-only"*, *"you haven't rolled
  yet"* — all conditions `would_no_op_now()` already distinguishes internally and then throws
  away. The "name the preventer" idea matters more later, when we have relics/statuses that
  block plays; we don't yet.

### 7.3 Target validity is re-checked at play time — their answer to our freed-node bug

- **Theirs:** the card model's target check explicitly rejects a **dead** target before checking
  side/type, and the play path re-validates the target rather than trusting whatever the UI
  captured during hover.
- **Ours:** we hit exactly this bug (2026-07-10): `targets` was populated by `area_entered` and
  never cleared for an enemy freed mid-aim, because `area_exited` doesn't fire for a freed node.
  Fixed with `_prune_stale_targets()` (`is_instance_valid()`) at the three read sites.
- **Verdict:** `already better` — our prune is the same guarantee, applied at the read sites,
  and we additionally handle the *visual* case (thrown dice retarget to a random living enemy
  if their target dies mid-flight, `card.gd::_on_thrown_die_landed`). Recorded to confirm the
  fix was the right shape, not a workaround.

### 7.4 Damage math ordering — ours is correct, and now confirmed against theirs

- **Theirs:** damage modification runs in explicitly typed, ordered categories: **additive**
  (Strength) → **multiplicative** (Vulnerable) → **cap** (Intangible), each with a "late"
  variant, and HP-loss modification is split into two phases that bracket a damage-redirection
  step so a redirect can't be applied twice or skipped.
- **Ours:** `Modifier.get_modified_value()` sums all FLAT values in one loop, then accumulates
  all PERCENT_BASED into a multiplier in a second loop, and returns `floori(flat × percent)`.
  Verified in code — the two-loop structure **guarantees** flat-before-percent regardless of
  child order.
- **Verdict:** `already better` / no action. Our ordering is correct and structurally enforced,
  which is the part that matters. We have no cap category and no redirection step, so those
  phases have no analogue — and shouldn't be added speculatively.

### 7.5 The checklist

| Case | Theirs | Ours | Status |
|---|---|---|---|
| Target dies mid-aim / mid-effect | validity re-checked at play; dead targets rejected | `_prune_stale_targets()` at all 3 read sites; thrown dice retarget in flight | **handled** |
| Input locked during resolution | node-scoped blocking-screen registry | `_turn_cycle_active` + generation token (+ 20 s watchdog) | **handled** (bespoke) |
| Modal leaves input stuck | impossible — lock lifetime = node lifetime | per-case flags; three past bugs in this family | **handled, fragile** — see 7.1 |
| Multiple simultaneous block reasons | flags enum, accumulates | single bool → 1 of 2 strings | **partial** — see 7.2 |
| Damage modifier ordering | typed ordered categories | two-loop flat-then-percent | **handled** |
| Death mid-turn removes actor | creature removed after its move resolves, guarded | enemy `queue_free` is deferred; we filter `is_queued_for_deletion()` in act-2 scaling | **handled** (one known trap, documented) |
| Status stacking merge rules | typed stack kinds (counter/intensity/etc.) per power | `StackType {NONE, INTENSITY, DURATION}` + the documented `can_expire` interaction trap | **handled** |
| Pool exhaustion (events) | warn + allow repeats | pool empties | **unhandled** — see 3.3 |
| Unknown-room odds excluded-vs-unlikely | negative sentinel, excluded from growth | N/A (no unknown rooms) | **N-A** |

### 7.6 Second drive-by release-build log spam (same family as 2.11)

`scenes/modifier_handler/modifier.gd::add_new_value()` prints a line every time a modifier value
is added — so on every Strength/Exposed application, every act-2 damage bake, every relic that
installs a modifier. Together with the `print(Global.fight_turn)` found in 2.11, that's two
hot-path prints shipping in release. Both are one-line deletes; worth doing in the same pass as
the §8.4 wiring work since both files are already open then.

---

## WS6 — Architecture ideas (observational, post-launch)

Session D, 2026-08-15. Probed: `src/Core/GameActions/` (base + executor + the undo action),
`src/Core/Hooks/Hook.cs` (full trigger enumeration), `src/Core/Commands/` (listing),
`src/Core/Models/ModelDb.cs` (registration). Our side: `global/events.gd` (all 93 signals),
`scenes/modifier_handler/modifier.gd`, `relics/magic_sleeve.gd`.

**Everything here is post-launch unless marked otherwise.** Two of the plan's premises turned out
to be wrong, which is itself useful — see 6.1 and 6.2.

### 6.1 There is no effect queue — and their "undo end turn" is not an undo

The plan flagged `GameActions/` as a command queue and `UndoEndPlayerTurnAction` as possible
player-facing undo. Both readings are wrong, and the correction matters because it removes a
tempting idea from our backlog.

- **Theirs:** their own documentation is explicit that this concept **changed from STS1**. In
  STS1 a "game action" was a small unit of logic (deal damage, gain block). In STS2 those units
  are **Commands** (a flat family of ~19 static command classes: damage, creature, power, card,
  card-pile, relic, rewards, map, player, sfx…), and a GameAction is now *only* a thin async
  wrapper around **player input** — play a card, drink a potion, click end turn, pick a map
  node. There are just **25** of them, each with a networked twin. Their doc comment names the
  exclusions directly: dealing damage, gaining block, applying a power, and *monster moves* are
  explicitly **not** game actions, because monster moves never wait on player input.
- **The undo** is a co-op **un-ready** toggle: ending your turn marks you *ready*, a separate
  synchronisation step performs the actual turn switch once everyone is ready, and the undo
  simply clears your ready flag if the turn hasn't advanced. It is guarded by a turn-number
  check and does nothing if the turn already moved on. **No game state is ever rolled back.**
- **Ours:** we have no queue and no analogous wrapper; player input calls into state directly,
  and our `Effect` subclasses (`DamageEffect`, `StatusEffect`, `BlockEffect`, `SupportEffect`)
  are the same layer as their Commands.
- **Verdict:** `skip` the queue, and **strike "undo end turn" from consideration** — it's
  netcode, not a feature. `already better`-adjacent: our `Effect` classes and their Commands are
  the same idea, so the layer we do have is the layer they kept.

### 6.2 The one real gap: they have **`Modify*` and `Should*` hooks, we have none**

This is the finding worth the whole workstream.

- **Theirs:** ~140 hook trigger points, named by a strict convention that encodes each hook's
  *contract*:
  - **`Before*` / `After*`** — notification (e.g. after-card-drawn, after-shuffle,
    after-card-exhausted, after-block-broken, after-room-entered, before-death).
  - **`Modify*`** — *transform a value in flight* (modify damage, modify block, modify hand
    draw, modify shuffle order, modify merchant price, modify card-reward options, modify gold
    gained, modify rest-site heal amount, modify X value, modify generated map).
  - **`Should*`** — *veto a thing from happening* (should-play, should-draw, should-die,
    should-clear-block, should-allow-targeting, should-stop-combat-from-ending,
    should-add-to-deck, should-generate-treasure).
- **Ours:** 93 `Events` signals, and after reading the full list they fall into only two shapes:
  **notifications** (`card_played`, `dice_rolled`, `enemy_died`, `gold_changed`) and
  **commands** (`draw_card`, `discard_random_card`, `add_card_to_hand_requested`,
  `force_end_turn`, `open_deck_view`) — plus a third informal family, the nine `check_*`
  broadcasts (`check_weak_status`, `check_canalize_status`…) which are "everyone re-evaluate
  yourselves" pings. **Zero signals transform a value; zero signals can veto anything.**
  Value transformation happens *only* through `ModifierHandler` (4 types, of which
  `SHOP_COST` is declared but — verified — **never used anywhere in the project**, a dead enum
  member), and vetoes are hardcoded at each call site (our card refusal lives in
  `card_clicked_state.gd`, not in any hook).
- **Concretely, content we cannot express today.** Each of these is a normal card/relic in STS
  and is currently impossible for us without bespoke plumbing:
  - *"Whenever you draw a card, …"* — no draw signal exists (`draw_card` is a **command** we
    emit *to* the handler, not a notification that a card was drawn).
  - *"Whenever you Exhaust a card, …"* — nothing is emitted on exhaust, even though we built
    the exhaust pile on 2026-07-16.
  - *"Whenever you discard a card, …"* — `player_hand_discarded` fires once for the whole hand,
    not per card.
  - *"Cards cost 1 less in shops"* / any price-modifying relic — the modifier type exists and
    is unused, so nothing reads it.
  - *"Prevent death once per combat"* — no death veto; `enemy_died`/`player_died` are pure
    notifications fired after the fact.
  - *"This card cannot be played while X"* — our refusal predicate is not extensible by content.
- **Verdict:** `adopt idea`, **post-launch, incrementally** — and the cheap part is genuinely
  cheap. Adding three notification signals (`card_drawn(card)`, `card_exhausted(card)`,
  `card_discarded(card)`) is a handful of emits at existing choke points in `player_handler.gd`
  and unlocks a whole family of card designs. The `Modify*`/`Should*` families are the real
  architecture and belong after launch. **The naming convention is free and should start now:**
  any new signal gets a name that states its contract, so the taxonomy grows correctly instead
  of needing a rename pass later.

### 6.3 Player-choice-mid-resolution is a first-class state, not an ad-hoc await

- **Theirs:** a game action runs a small state machine —
  *waiting → executing → **gathering player choice** → ready-to-resume → executing → finished*,
  plus a cancelled path — with events fired at every transition. So "this card needs the player
  to pick something halfway through resolving" is a supported, inspectable state rather than a
  coroutine parked on an await.
- **Ours:** we do this with awaits and signals per case (Scout's panel, the card-removal flow,
  red-socket aiming), and we have been bitten by exactly the failure mode a formal state
  prevents: the 2026-07-27 power-reset race, where a coroutine resumed after its await and wrote
  into state the player had already changed. Our fix (generation tokens) is the right local
  patch and is now used in three places.
- **Verdict:** `skip` as a refactor — the pattern is heavy for our size, and our generation-token
  idiom already solves the concrete bug class. Recorded because it names *why* the token trick
  keeps being needed: we have an implicit state machine that nobody wrote down. If a fourth site
  needs it, that's the signal to formalise.

### 6.4 Content registration: reflection vs. hand-maintained pool lists

- **Theirs:** models self-register by **reflection over subclasses** — every class deriving from
  the card/relic/affliction/etc. base is discovered automatically, including modded ones. There
  is no master list to maintain.
- **Ours:** each card is a `.gd` + `.tres` pair, and the `.tres` must additionally be listed in
  a pool resource (`warrior_draftable_cards.tres`). That list is the file that got **silently
  emptied** by the live Godot editor on 2026-07-30 (all 80 cards, recovered from git).
- **Verdict:** `skip`, deliberately — and worth stating plainly so nobody "fixes" it later.
  Our data-driven pairs are the *right* choice for this project: Julien tunes numbers in the
  inspector without touching code, which is the single most-used workflow in the repo. The
  2026-07-30 incident was an editor-lifecycle hazard (documented, with a restart-the-editor
  protocol), not an indictment of the pattern. Their reflection approach buys mod support we
  don't want and costs designer ergonomics we depend on. **This finding validates our pattern —
  say so and move on.**

### 6.5 The memo — five ideas, ranked

| # | Idea | Cost | Benefit | When |
|---|---|---|---|---|
| 1 | **Three lifecycle notifications** — `card_drawn`, `card_exhausted`, `card_discarded` (per card) | **XS** — a few emits at existing choke points in `player_handler.gd` | Unlocks an entire family of card/relic designs we currently cannot write at all | **Free now**, if any planned card wants it; otherwise first post-launch content batch |
| 2 | **Signal naming convention** — new signals declare their contract (`*_happened` vs `modify_*` vs `should_*`) | **Free** — a rule, not code | Stops the taxonomy drifting further; makes the eventual `Modify*` family additive rather than a rename | **Now** |
| 3 | **Delete the dead `SHOP_COST` modifier type**, or implement one price-modifying relic with it | XS | Removes a lie in the enum; if implemented, proves the modifier path works for non-combat values | Post-launch |
| 4 | **`Should*` veto family**, starting with a content-extensible "can this card be played" predicate | **M** — needs a real hook dispatch, and our refusal UX (7.2) should land first | Makes lockout content (curses, Normality-likes, the §8.3 Hex card) expressible instead of bespoke | Post-launch |
| 5 | **`Modify*` transform family** (damage/block already covered by `ModifierHandler`; the gap is rewards, prices, draw counts, map generation) | **L** | The "relics that change the meta-game" design space | Post-launch, only if that design space is wanted |

Ideas 1 and 2 are the only ones I'd act on before launch, and only #2 costs nothing.

---

## WS8 — Dev & test infrastructure

Session D, 2026-08-15. Probed: `src/Core/AutoSlay/` (config, orchestrator, room handlers),
`src/Core/TestSupport/`, `src/Core/DevConsole/ConsoleCommands/`.

### 8.1 AutoSlay is a **smoke test that cheats**, not a balance bot — the plan's premise was wrong

The plan imagined "100 headless runs overnight telling us Golem stall winrates". The reference
says MegaCrit deliberately did **not** build that. What AutoSlay actually does, per its own
description ("runs the game automatically for smoke testing"):

- At the start of every combat it grants the player **Plating 999** and **Regen 999** — the bot
  is effectively invulnerable by construction.
- From **turn 3** onward it grants itself **+200 Strength per turn**, additively, explicitly so
  that dragging fights end. Their comment is candid about why: fights that end before turn 3
  "play out with no offensive buff so real combat is exercised", and only long fights get forced
  toward a kill, to stay ahead of instakill counters and the turn cap.
- Each turn it plays **every card it can legally play**, at a **random valid target**, capped at
  50 cards per turn, tracking already-attempted cards so an unplayable one can't loop.
- Then it ends the turn and repeats. Target floor: **49** (their final boss).

So it measures **nothing** about balance — by design. What it proves is that no card, relic,
enemy, event, shop interaction or screen transition **crashes or hangs** across a full run.
A bot that buffed itself to invincibility would be worthless for tuning and is exactly right for
soak testing.

The scaffolding around it is the transferable part:

- **A handler per room type** (monster/elite/boss, event, rest site, shop, treasure, victory) and
  **a handler per overlay screen** (card reward, relic reward, bundle, deck select, upgrade,
  transform, crystal sphere…).
- **An overlay "drain" loop** — the key insight. Any action can open an arbitrary screen, so the
  driver repeatedly closes whatever is on top of the screen stack while waiting for a pending
  task. Their comment notes the specific bug it fixes: buying certain items opens a reward screen
  *from inside* a room handler, so the room can't finish until the screen closes, and the
  between-rooms drain never runs — deadlock. It also has a fail-fast mode for call sites that
  can't recover.
- **Layered timeouts + a watchdog**: run 25 min, room 2 min (combat 5), screen 30 s, node waits
  10 s, poll every 100 ms; a **30 s no-progress watchdog** dumps state and fails, and handlers
  explicitly *reset* the watchdog when they make progress (e.g. every 10 cards played).
- **Seeded** entry point, with a log file.
- Alongside it: `TestSupport` with a test-mode flag, an RNG injector, and a scripted card
  selector; and a dev console with **44** commands (give card/relic/potion, set act, apply
  power, damage, draw, energy, kill, dump state, art, bestiary…).

### 8.2 Should we build "AutoDaiso"? — yes, and it's smaller than it sounds

- **Ours today:** a genuinely strong harness culture — ~30 `debug_*.gd`/`.tscn` scenes at the
  repo root, each booting a *real* scene and asserting or rendering (the cadence-promotion
  harness alone runs 21 checks with a negative control; the reroll harness runs 1007). They are
  auto-excluded from the web export by the preset's `debug_*` filter. What we do **not** have is
  anything that plays a whole run end to end.
- **Verdict:** **`adopt idea`, post-launch, in the reduced form.** The honest case for it is not
  balance data — it's that our harnesses each test one screen in isolation, and every serious bug
  we shipped this year lived in the *seams between* screens: the double-end-turn (turn cycle vs.
  button re-enable), the tutorial soft-lock (gate vs. card dealing), the map-consult camera/
  CanvasLayer bugs, the freed-target crash. A run-walker is the only harness shape that exercises
  seams.
- **Smallest useful version** (a day's work, roughly, and mostly assembly of things we have):
  1. A single `debug_autorun.gd` that boots `run.tscn` with a fixed seed and a forced loadout.
  2. A **per-view handler** dispatching on our existing view enum — battle, map, shop, card shop,
     campfire, treasure, event, reward, dice infusion, loadout picker. Each handler does the
     dumbest legal thing: map → pick the first available room; reward → take the first; shop →
     leave; campfire → rest; event → click the first button; battle → see 3.
  3. **Combat policy: cheat exactly like they do.** Give the player huge HP and huge Strength
     from turn 3, then each turn roll until dice are exhausted and play every card whose
     `would_no_op_now()` is false, at a random living enemy, then End Turn. Our
     `would_no_op_now()` is already the "can I legally play this" predicate their bot uses.
  4. **A watchdog**: if the view hasn't changed and no signal has fired for N seconds, print the
     current view, the last five signals, and fail. This is the component that turns a hang into
     a diagnosis.
  5. Assert only two things: **no error was printed** and **the run reached the act-2 boss**.
- **Two things to copy exactly, because we'd otherwise rediscover them the hard way:** the
  **overlay-drain loop** (we have modal screens that open from inside other flows — the deck
  view from the campfire, the reward screen from an event — which is precisely the deadlock their
  comment describes), and **watchdog resets on progress** rather than a single flat timeout.
- **What it will not do:** tell us anything about Golem stall winrates, or any balance question.
  If we ever want that, it's a *different* bot with an honest policy and no self-buffs — and
  MegaCrit's choice not to build one is a fair hint about the cost/benefit.

### 8.3 Two smaller things worth stealing before that

- **A dev console.** We have debug buttons gated behind `OS.is_debug_build()`; they have 44
  console commands. The three that would most speed up our own playtesting: *give relic X*,
  *set act/floor*, and *apply status X to the player*. Cheap, and it shortens the loop for every
  future balance question Julien wants to eyeball.
- **A seeded-run entry point.** Their bot takes a seed. We already have deterministic-ish RNG per
  system but no way to say "replay this run". A single `--seed` debug flag that seeds the run's
  RNG would make every future bug report reproducible — including the ones from itch playtesters.

---

## Open verdicts — consolidated index

Everything above that needs Julien's call, in one place. Grouped by how much thinking each needs,
not by workstream. Section numbers link back to the full reasoning.

**Design calls (need a real opinion):**
1. **§9.7 soft-enrage backstop** — build it or not? WS2 (2.5) found MegaCrit has *no* time-based
   enemy scaling anywhere; our authored ramp column is vindicated, the global backstop is the one
   piece with no precedent. Recommendation: ship the authored column, hold the backstop until
   Golem stall is measured.
2. **Shop composition by type vs rarity** (3.2) — guarantee an Attack/Skill/Power every shop, or
   keep guaranteeing a Rare?
3. **Map target counts vs weights** (5.5) — should every act have exactly N campfires/shops
   instead of rolled weights?
4. **Pity ceiling** (3.1) — ours plateaus at ~17% rare; theirs climbs to ~43%. Raise ours?
5. **No-rare-on-floor-1 rule** (3.1) — adopt their negative starting offset?

**Cheap, mostly "yes unless you object":**
6. **Slot-position openers for twin packs** (2.4) — resolves the open §8.2 B.Kraken verdict in a
   strictly safer form than the 50/50 opener we proposed. Only question left: apply to tier 0?
7. **Map spread-nudge** (5.1) — replace blind jitter with gap-maximising nudge. Highest
   value-per-risk item in Session C; directly targets "je comprends pas la map".
8. **First-time tips for map / shop / campfire / relic / reshuffle** (5.3) — reuse the popup we
   already have; we have 3 tips, they have 15.
9. **Cannot-play first-time tip + spotlight-above-dimmer** (5.4).
10. **Graceful event-pool exhaustion** (3.3) and **structured refusal reasons** (7.2).
11. **Delete two hot-path debug prints** (2.11, 7.6).
12. **Signal naming convention** (6.5 #2) — free, a rule not code: new signals state their
    contract so the taxonomy stops drifting.
13. **Three lifecycle signals** — `card_drawn` / `card_exhausted` / `card_discarded` (6.5 #1).
    XS, and the only thing standing between us and a whole family of card designs. Worth doing
    now *if* any planned card wants it, otherwise first post-launch batch.

**Worth scheduling after launch (not just parked — these have real value):**
- **"AutoDaiso" run-walker** (8.2) — the smallest useful version is ~a day and would exercise the
  *seams between screens*, which is where every serious bug we shipped this year lived. Copy their
  overlay-drain loop and progress-resetting watchdog; copy their self-buffing combat policy too
  (it's a smoke test, not a balance bot — 8.1).
- **Dev console + seeded-run flag** (8.3) — shortens every future playtest loop and makes
  playtester bug reports reproducible.
- **`Should*` veto family** (6.5 #4) — the prerequisite for curse/lockout content like the §8.3
  Hex card. Do the refusal-reason work (7.2) first.

**Explicitly parked (recorded so we don't re-litigate):**
- Chain-based cadences instead of `% N` (2.3) — post-launch, do **not** retrofit the two shipped
  cadence promotions.
- Duplicate-path pruning (5.2) — post-launch; it's a balance touch, not just visual.
- Blocking-screen registry (7.1) — post-launch; consider when adding the *next* modal.
- Unknown "?" rooms (3.4) — skip until map legibility is fixed.
- Rolled HP ranges (2.8) — deliberately skipped; fixed HP is worth more to a dice game.
- **Player-facing "undo end turn"** (6.1) — struck: theirs is a co-op un-ready toggle, no state
  is ever rolled back. Not a feature we were missing.
- **An effect/command queue** (6.1) — they don't have one either; their small effect units are
  static command classes, which is what our `Effect` subclasses already are.
- **Reflection-based content registration** (6.4) — our `.gd`+`.tres` pairs are the *better* fit:
  they buy designer-inspector tuning, which is the most-used workflow in the repo. Validated,
  not a gap.
- **Formal player-choice state machine** (6.3) — our generation-token idiom already covers the
  bug class; revisit only if a fourth site needs it.

---

## Next probes / unfinished threads

- **WS1:** their `themes/` folder holds font resources only — a full font-stack comparison
  (sizes, glyph spacing variants) wasn't done and is low value. The long-press-to-confirm bar was
  identified as an opt-in preference but its fill timing wasn't read.
- **WS4:** card-play flight choreography (above). Also unexamined: `shaders/vfx/_util` and
  `common`, which likely hold shared building blocks worth a skim; and `NValueRamp` / `NTrail2D`
  / `NVfxProjectile`, which look like reusable motion utilities in the same family as our
  thrown-dice bash.
- **WS2:** the soft-enrage question is **closed** (2.5) and the encounter/AI structure is
  mapped, but three threads were left deliberately:
  - Only **8 of 122** monsters were read. The sample was chosen to match our archetypes and
    the structural findings converged fast (every class read used the same three node kinds),
    so more reading has diminishing returns — *except* for two specific lookups worth doing if
    the §8 batch proceeds: (a) a **summoner** and (b) a **multi-phase boss** (their
    "Adversary Mk I/II/III" naming suggests phases may be modelled as separate monsters that
    swap in, which would be a cheap pattern for our Dicelord P2 idea in §4.5).
  - **Their damage-number-to-intent path was not traced.** We know a move declares its intents
    with the damage baked in at construction; what wasn't verified is how a mid-fight Strength
    change propagates to an already-displayed intent. That's the precise mechanism behind our
    §2.4 Chimera snapshot footgun, and they must solve it — worth one probe before we ship
    damage-stepping spikes (§9.3 tool 2).
  - **Elite/boss reward and act-scaling numbers** were only partially gathered (gold ranges
    yes, per-act HP/damage progression no). Overlaps WS3; leaving it there.
- **WS3:** potions are a whole system we don't have, so their potion odds/pricing were skipped
  entirely. Ascension modifiers were only skimmed (the ones that surfaced incidentally: tougher
  enemy HP ranges, higher enemy damage, scarcer rares, pricier shops/removals, more elites,
  poorer gold, double boss) — a proper difficulty-mode reference is a post-launch read.
  Their relic costs are authored per-relic rather than by rarity band; not enumerated.
- **WS5:** the actual *wording* of their 15 tips was deliberately not transcribed (that's
  expression, not idea) — only the topic list. If we build tips, we write our own copy. Also
  unread: the map-select tip's contents and their embark/act-transition flow.
- **WS7:** simultaneous-trigger ordering was answered for the *damage* pipeline only. Whether
  they impose an order when several relics/powers respond to the same event (our `Events` fan-out
  order = connection order) wasn't established; the hook dispatch iterates listeners with no
  explicit priority, which *suggests* they accept arbitrary order too, but that's an inference,
  not a verified fact.
- **WS6:** the `Commands` layer was listed but not read — if we ever want a reference for how a
  damage command composes (their builder-style chaining of attacker anim / hit VFX / hit count
  was visible in passing), that's the file family. Their multiplayer/netcode layer stays on the
  do-not-mine list. Not enumerated: which of their ~140 hooks are actually *used* by shipped
  content versus available-but-unused — that would sharpen idea 6.5 #5 if we ever pursue it.
- **WS8:** their screen-handler list was read as filenames only; if we build the run-walker,
  one probe of two or three handlers would show how they detect "this screen is ready to be
  interacted with" (our equivalent problem: knowing a view has finished its entrance tween).
  `RiderTestRunner/` turned out to be an empty directory in the extraction — their unit-test
  conventions are not recoverable from this dump.
- **Bridges to later sessions:** the damage pipeline surfaced a visible hook taxonomy
  (modify-damage, after-modify, before-received, modify-HP-lost with ordered phases) — that is
  WS6's question and there's a clear thread to pull. The self-retiring FTUE flag in 1.9 is WS5's.
