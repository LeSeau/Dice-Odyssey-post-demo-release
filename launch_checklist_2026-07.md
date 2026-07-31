# Launch Checklist — pre-subreddit posting (2026-07-19)

Recap of the launch-prep review session. Work through this before posting on subreddits.
Owner tags: **[J]** = Julien, **[C]** = Claude, **[J→C]** = Julien decides/provides, Claude implements.

## Already verified OK — no action needed

- Starting gold = 75 (test value removed), no `force_for_testing` flags left on events
  — ⚠️ re-verified 2026-07-31: the fountain-heal flag had been RE-enabled since this line was
  written (flipped on to test that event, never flipped back — every event room forced Fountain
  of Healing). Fixed again. Also normalized the leftover `weight = 10.0` on the Leviathan battle
  (inert — it's the only boss — but same testing-leftover pattern). Re-grep `force_for_testing`
  right before export.
- Starting deck = correct 12-card version (4 Strike / 4 Block / Low Blow / Reinforce / Recombobulate / Scout 3)
- `art/starter-deck-art-refresh` branch merged into main
- Card reward Skip button exists
- **"Choose a card" screen — full ceremony pass done 2026-07-30/31 (not yet playtested).** Fixed the
  "REWARDS" ghost bleeding through the picker's dimmers; added a staggered card reveal with a gold
  flash + motes on Rares (the pity system's payoff); added a pick beat that flies the chosen card to
  the top-bar deck button; restyled Skip and the title banner into the shared navy/gold language
  (the banner was the only panel title in the game still on white MinionPro, and its red-plus-gold
  plaque read like a fourth card). Two long-standing bugs fixed in passing: wrong `@onready` paths
  logging two "Node not found" errors on every reward screen, and stale shop-button stylebox UIDs.
  Skip consolation and a boss-specific screen variant were **explicitly declined by Julien** — don't
  re-propose. Tuning knobs are the `REVEAL_*`/`RARE_*`/`PICK_*`/`FLIGHT_*` constants in `card_rewards.gd`.
- Tested by Julien: 9 dice infusions, achievements, exhaust pile placement, card animations, fountain heal event
- Audio placeholders replaced: Evil crack (glass sound), orb-landing SFX, achievement jingle
- Dice Shop icon replaced
- **No-reset card disclosure — audited 2026-07-28, NOT a problem (this P0 was based on a bad count).**
  The original "47 cards, only 2 disclose" figure counted the `Card.Rarity.SUPPORT` flag, which does
  NOT mean "doesn't reset Power" (it only drives the red-socket glow, `hand.gd:325`). Re-audited by
  actual `dice_roll_reset.emit()` behaviour across all 180 card resources (81 draftable + their `+`
  versions + starters, comments stripped): **38 no-reset entries, and every one of them tells the
  player** via at least one of — Celestial styling, naming Power in its text ("Add 4 to your Power",
  "Triple your Power"), saying Refuel, or saying "Does not reset your Power" outright. The single
  hole was **Coiled Spring / Coiled Spring+**, which lost its only tell when it stopped being
  Celestial on 07-25 — Julien's call was to make it reset instead (done, see CLAUDE.md TL;DR).
  Requirement-gated cards whose reset sits inside an `if` (Bullseye, Aegis, Duo…) are not a gap:
  whiffing the requirement does nothing at all, and the requirement badge already says so.

## P0 — do before posting

- [x] **Web build weight — handled via import-level Lossy 0.5 instead of source downscale (2026-07-31).**
      What ships is the imported `.ctex` (WebP), not the PNG — so Julien's per-image "Compress:
      Lossy 0.5" method was adopted wholesale and batch-applied: the 175 texture imports still on
      Lossless with sources ≥150KB (285MB of source, `evil0.png` 7.5MB included) were flipped to
      `compress/mode=1` + `lossy_quality=0.5` by script (he had already converted the rest by hand).
      Sources untouched → fully reversible via the import setting. Also: ~349MB of harness render
      output archived out of the tree to `C:\Users\julie\Desktop\daiso_archive_2026-07-31\`, 3GB of
      stale `.claude/worktrees` removed (WIP saved as patches in the archive), and the Web preset
      got `exclude_filter="res://debug_*"` so root harnesses never ship.
      **Reimported and measured 2026-07-31 — the item is closed. Shipping payload is 78.8 MB**
      (images 51.4 / audio 22.1 / fonts 5.2), plus 13.8 MB that the `debug_*` filter strips.
      Individual assets compress 14-69× (`evil0.png` 7.47 MB → 0.11 MB).
      **Quality verified two ways, not assumed:** the WebP that actually ships was extracted from
      each `.ctex` and compared to its source — 34-36 dB PSNR on backgrounds (the riskiest class,
      they render near-native), 29-33 dB on sprites and card art, and **alpha is bit-identical
      everywhere**, so silhouettes and the hover-outline shader are untouched. Side-by-side at real
      display size (worst-scoring sprite + a background at 1:1) is indistinguishable.
      ⚠️ Do NOT judge this from two engine renders: the idle-sway shader and bobbing intent icon
      put separate runs at different animation phases, which reads as a fake 23 dB PSNR.
      Source downscale stays a phase-2 option only if web memory becomes an issue (lossy shrinks
      disk, not decoded RAM). `main_menu.png` is the last Lossless holdout — it's an orphan
      superseded by `main_menu_v4.png`, so it costs nothing to leave alone.
- [x] **Unreferenced assets pruned (2026-07-31)** — 11.1 MB of files nothing referenced by path or
      uid, archived to `daiso_archive_2026-07-31\unreferenced_assets\` (with a MANIFEST; also in
      git history). Biggest: `main_menu_theme.mp3` 4.35 MB (superseded by `main_menu_theme_v2.ogg`),
      `sounds/gameover.mp3` 1.19 MB (the screen actually plays `gameoversound.wav`),
      `removecardsound.wav` (superseded by the 68 KB `.mp3`), 5 unused font files. Boot-tested
      clean afterwards. ⚠️ `export_filter` must STAY `all_resources` — this project `load()`s a lot
      by constructed path (`"res://assets/images/" + dice_type + N + ".png"`), which the
      "resources"-only filter would silently drop. So orphan pruning is manual, and any future
      pass must not flag dice-face images as unused.
- [x] **Music re-encoded (2026-07-31)** — three tracks were bitrate outliers (`taverna_mystica.mp3`
      and `final_boss_battle.mp3` at 320 kbps, `main_menu_theme_v2.ogg` at **499**) while the two
      most-heard tracks, `map_music.ogg` and `fight_music.ogg`, already ship at 112 kbps. Re-encoded
      the three in place to **128 kbps** — same filenames/formats so no reference changes, and still
      above the game's own established bar. 11.4 MB → 4.2 MB (**−7.2 MB**). Originals in
      `daiso_archive_2026-07-31\original_audio\`. Verified: duration, channels, sample rate identical
      and loudness within 0.5 dB (structural check — nobody listened to them yet).
      ⚠️ Needs one more editor reimport before it shows up in the payload.

### Remaining size levers (not done — judgment calls)

- **Images, ~44.8 MB across 413 files at ≥1024px, and NO import has `process/size_limit` set.**
  That's the one big lever left (est. 15-25 MB). `process/size_limit` is the clean way to do it:
  import-level like the lossy flag, so sources stay untouched and it's reversible, and unlike lossy
  it also cuts decoded RAM (a 1024² card art still costs 4 MB of RAM no matter how small the file).
  Needs per-class values (backgrounds must stay ≥1280; enemies ~512; card art displays at 140px so
  256-384 is plenty; dice faces ~256) plus render verification per class — a focused session, not a
  rushed pre-export change.
- **SFX WAVs, 5.4 MB across 26 files, all uncompressed PCM (1411-2304 kbps).** Their `.import`
  files have `compress/mode=0`; switching to QOA (mode 2) saves roughly 4 MB. Left for Julien to
  do in the editor UI he already knows (select the wavs → Compress Mode → QOA → Reimport) so he
  can judge the result by ear — the one thing Claude can't verify.
- [ ] **Tutorial corrections** — **[J→C]** Julien sends notes/screenshots, Claude fixes.
- [ ] **Music variety** — one track (`fight_music.ogg`) for every fight in the game, both acts, both bosses.
      **[J]** source minimum a boss theme (ideally + act 2 combat + elite variant).
      **[C]** wire per-context selection (same pattern as `_select_background_texture()`).
- [ ] **Feedback funnel in the build** — Discord invite (or form) link on death screen, victory
      screen, main menu. **[J]** provides URL, **[C]** wires. (Steam wishlist button added later.)
- [ ] **Act 2 decision** — keep with mitigations (recommended) vs cut after act 1 boss. See notes at bottom.
- [ ] **Run summary on death/victory** — floor reached, damage dealt, biggest hit, gold, dice rolled,
      cards drafted. Stats mostly already tracked for achievements. **[C]**
- [x] **Boss presence — done 2026-07-31 (render-verified, banner not yet playtested).**
      Runtime-only `box_mult: 1.26` + `x_shift: -72` on the Leviathan entry of `ACT2_RESKIN`
      (battle.gd): the Dicelord now renders ~390px tall (vs 307 — he was barely above the Lich
      elite's 292) and his staff no longer crowds the right screen edge (the enemy template bakes
      the sprite +124px right of the node — that's where the drift came from). Feet stay planted
      (half the added box height is given back to position.y). The shared .tscn is untouched, so
      the act-1 Leviathan is unaffected by construction. `_reskin_enemy` is now **static** and
      `debug_act2_reskin.gd` calls the real function instead of a mirror copy. Plus a **boss intro
      banner**: `start_battle` on tier-4 fights instances `act_banner.tscn` after 0.55s and
      announces the boss's post-reskin display name (LEVIATHAN / THE DICELORD); the turn banner
      can't collide (it skips turn 0). Parse-checked, not seen in a live fight yet.

## P1 — high value if time allows

- [ ] **Shop card-removal service** — no purge exists anywhere except random events. One button in
      card shop, escalating price (75, +25 per use), reuses existing `Global.removing_card` flow. **[C]**
- [ ] **Rare cards** — pick 3-4 from the drafts: Retribution (block→damage Blessing), Colossus (2×Block
      attack), Perpetuum (type-switch Charge), Oracle's Eye (auto-Scout 2), Grinning Void (0-roll AoE),
      Fuel Fever (refuel→Block). **[J→C]** ⚠️ Close the editor before Claude patches `.tres` files
      (property-strip incident). New Blessings need `or Global.blessing_cast_any_roll`.
- [ ] **Unplayable-card click feedback** — click a gated card → small shake + reason tooltip
      ("Requires Min 6"). Teaches requirements passively. **[C]**
- [ ] **The Dicelord signature move** — one new action the Leviathan doesn't have, so the finale
      isn't a stat-buffed rerun for the players who get there. ~1 day. **[C]**
- [ ] **Screen shake / hit-stop intensity slider** in settings (everything routes through `Shaker`). **[C]**
- [ ] **Damage preview on aimed enemy** (STS-style, on HP bar) — math already exists in
      `apply_target_modifier`; the one medium-sized item. **[C]**

## Pre-export pass (right before building/uploading — say "go" and it's ~30 min) **[C]**

- [x] Hide debug buttons — done 2026-07-31: `$DebugButtons.visible = OS.is_debug_build()` in
      run.gd `_ready` (visible in editor/debug builds, hidden in the release export)
- [x] ~~Remove the 1920×1080 window override~~ — **decided 2026-07-31: LEAVE IT.** It only sets the
      desktop OS window size (design viewport stays 1280×720, `stretch/mode="canvas_items"` scales
      up), and the Web preset has `html/canvas_resize_policy=2` ("adjust to whole window"), so the
      browser sizes the canvas from the itch iframe and ignores the override entirely. Removing it
      changes nothing in the export and only shrinks Julien's F5 window. Keep it — it's also why
      his screen renders ~1.5× design size, which is how the power-glyph halo artifact was ever
      spotted.
- [x] Version label — done 2026-07-31: `config/version="0.1.0"` in project.godot (bump it there,
      it's the single source of truth) + `VersionLabel` bottom-right of the main menu reading it
      via ProjectSettings in main_menu.gd. Render-verified.
- [x] Housekeeping (done 2026-07-31): `scenes/ui/maiB664.tmp` already gone; all three stale
      `claude/*` worktrees removed (~3GB) and their merged branches deleted — dirty WIP saved as
      patches in `daiso_archive_2026-07-31\worktrees\`; achievement WIP long since committed.
      One empty locked folder shell remains at `.claude/worktrees/wonderful-solomon-64246f` (0 files,
      something held a handle) — delete manually whenever, it's outside the export either way.
- [ ] Fresh export + one full run test in an actual browser (not the editor)

## Itch page **[J]**

- [ ] Embed size 1280×720, enable itch's fullscreen button
- [ ] Description: one honest line that act 2 is an early preview (enemies share act 1 movesets for now)
- [ ] Screenshots + a lead GIF (roll → orbs → big damage number, 5-15s)

## Reddit plan **[J]**

- [ ] Feedback-focused subs first: r/DestroyMyGame (brutal, ideal for balance), r/playmygame,
      r/godot (dev-process framing). r/roguelikes and r/slaythespire: check self-promo rules first.
- [ ] Lead with the GIF, not text
- [ ] Post US evening hours; reply to every comment in the first 2 hours
- [ ] AI art: disclose if asked, don't hide it; Jenya's enemy art is the counterpoint
- [ ] Balance feedback is the goal — you're too close to the game to judge it yourself now

## Later (Steam phase — after the feedback wave)

- [ ] Steam page: capsule art commissioned from Jenya (main 1232×706, header 920×430, small 462×174,
      library 600×900 — one key art piece, one focal point, title readable at thumbnail size)
- [ ] AI-content disclosure checkbox on the Steam page (mandatory)
- [ ] Check "Dice Odyssey" for name collisions on Steam before printing it on assets
- [ ] Wishlist button on victory/death screens once the page is live
- [ ] Act 2 real content (unique movesets), rares wave 2

## Act 2 decision notes

Options discussed:
1. **Keep act 2 with mitigations (recommended)** — Dicelord signature move + preview framing in the
   itch description. Infusions (the game's most distinctive system) get a whole act of real use;
   the most engaged players get more game; honest framing defuses the "reskin" criticism.
2. **Cut after act 1 boss** — safest if shipping with zero extra act-2 work, but kills the infusion
   system entirely (it triggers at the act transition), and picking an infusion right before an
   end screen would feel worse than a preview act.
3. Middle grounds considered and rejected: moving infusions earlier (breaks their design as the
   act-transition power spike), a shortened act 2 (map generator changes + rebalance risk days
   before launch).
