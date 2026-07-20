# Launch Checklist — pre-subreddit posting (2026-07-19)

Recap of the launch-prep review session. Work through this before posting on subreddits.
Owner tags: **[J]** = Julien, **[C]** = Claude, **[J→C]** = Julien decides/provides, Claude implements.

## Already verified OK — no action needed

- Starting gold = 75 (test value removed), no `force_for_testing` flags left on events
- Starting deck = correct 12-card version (4 Strike / 4 Block / Low Blow / Reinforce / Recombobulate / Scout 3)
- `art/starter-deck-art-refresh` branch merged into main
- Card reward Skip button exists
- Tested by Julien: 9 dice infusions, achievements, exhaust pile placement, card animations, fountain heal event
- Audio placeholders replaced: Evil crack (glass sound), orb-landing SFX, achievement jingle
- Dice Shop icon replaced

## P0 — do before posting

- [ ] **No-reset card visibility** — 47 support-type cards, only 2 say they don't reset Power.
      Biggest confusion/rage-quit risk for new players. **[J→C]** Julien picks the visual language
      (auto-tooltip on hover via `Card.Rarity.SUPPORT` flag + an always-visible marker: banner
      accent / pip icon / other), Claude implements in BOTH card UIs (`card_ui.gd` + `card_menu_ui.gd`).
- [ ] **Web build weight** — 372 images over 1MB (card art ~3MB each, `evil0.png` 7.5MB).
      Itch load time = bounce rate. **[C]** Scripted downscale to ~2× display size + recompress,
      verified with `debug_bg_audit` before/after renders. `--headless --import` after overwriting.
- [ ] **Tutorial corrections** — **[J→C]** Julien sends notes/screenshots, Claude fixes.
- [ ] **Music variety** — one track (`fight_music.ogg`) for every fight in the game, both acts, both bosses.
      **[J]** source minimum a boss theme (ideally + act 2 combat + elite variant).
      **[C]** wire per-context selection (same pattern as `_select_background_texture()`).
- [ ] **Feedback funnel in the build** — Discord invite (or form) link on death screen, victory
      screen, main menu. **[J]** provides URL, **[C]** wires. (Steam wishlist button added later.)
- [ ] **Act 2 decision** — keep with mitigations (recommended) vs cut after act 1 boss. See notes at bottom.
- [ ] **Run summary on death/victory** — floor reached, damage dealt, biggest hit, gold, dice rolled,
      cards drafted. Stats mostly already tracked for achievements. **[C]**
- [ ] **Boss presence** — The Dicelord position/scale runtime override (inherits Leviathan's spot,
      too small/off-center) + boss intro banner reusing `act_banner` pattern. **[C]**

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

- [ ] Hide debug buttons (`MapButton`/`BattleButton` in run.tscn — gate on `OS.is_debug_build()`
      so they still work in-editor for staging screenshots)
- [ ] Remove/clamp the 1920×1080 window override (browser ignores it, but clean it anyway)
- [ ] Version label on main menu + `config/version` in project.godot
- [ ] Housekeeping: delete `scenes/ui/maiB664.tmp`, prune leftover `claude/priceless-hermann` worktree
      branch, commit achievement wave-3 WIP
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
