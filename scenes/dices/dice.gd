class_name Dice
extends Control

@onready var dice_display: TextureRect = $Panel/DiceDisplay

@onready var current_power: Label = $CurrentPower
@onready var power_hover_zone: Control = $CurrentPower/PowerHoverZone

# Hover tooltip for the Power glyph/number in the HUD - the "definition site" that teaches
# what the inline card glyph means. Same leak-safe pattern as card_ui.gd's tooltips
# (kill-before-spawn, safety timer, _exit_tree cleanup).
const PowerTooltipScene := preload("res://scenes/ui/tooltip.tscn")
const POWER_TOOLTIP_POS := Vector2(788, 300)
var _power_tooltip: Node = null
@export var dice_type: String = "blue"
@onready var card_drop_area: Control = $CardDropArea
@onready var charged_card_texture: TextureRect = $CardDropArea/CardBackground/CardFrame/Panel/ChargedCardTexture
@onready var charged_card_description: RichTextLabel = $CardDropArea/CardBackground/CardFrame/DescriptionPanel/ChargedCardDescriptionCenter/ChargedCardDescription
@onready var requirement_panel: Panel = $CardDropArea/CardBackground/CardFrame/RequirementPanel
@onready var requirement_label: Label = $CardDropArea/CardBackground/CardFrame/RequirementPanel/RequirementLabel
@onready var bonus_effect: HBoxContainer = $CardDropArea/CardBackground/CardFrame/BonusEffect
@onready var bonus_requirement_panel: Panel = $CardDropArea/CardBackground/CardFrame/BonusEffect/BonusRequirementPanel
@onready var bonus_requirement_label: Label = $CardDropArea/CardBackground/CardFrame/BonusEffect/BonusRequirementPanel/BonusRequirementLabel
@onready var bonus_effect_label: Label = $CardDropArea/CardBackground/CardFrame/BonusEffect/BonusEffectLabel
@onready var mech_section: Control = $MechSection
@onready var mech_increase: TextureButton = $MechSection/MechIncrease
@onready var mech_decrease: TextureButton = $MechSection/MechDecrease
@onready var ricochet_section: Control = $RicochetSection
@onready var ricochet_button: TextureButton = $RicochetSection/RicochetButton
@onready var bonus_separator: ColorRect = $CardDropArea/CardBackground/CardFrame/BonusSeparator

@onready var aura: ColorRect = $Panel/Aura
@onready var emanation: ColorRect = $Emanation
@onready var animation_player: AnimationPlayer = $Panel/DiceDisplay/AnimationPlayer
@onready var animation_player_power: AnimationPlayer = $CurrentPower/AnimationPlayerPower
@onready var ink_animation: AnimationPlayer = $Panel/DiceDisplay/DiceInk/InkAnimation

@onready var panel: Panel = $CardDropArea/CardBackground/CardFrame/Panel
@onready var title: Label = $CardDropArea/CardBackground/CardFrame/CardBanner/Title
@onready var card_banner: Panel = $CardDropArea/CardBackground/CardFrame/CardBanner

@onready var dice_roll_player: AudioStreamPlayer = $DiceRollPlayer

@onready var next_roll_panel: Panel = $NextRollPanel
@onready var next_roll_texture: TextureRect = $NextRollPanel/NextRollTexture

@onready var next_roll_bonus_panel: Panel = $NextRollBonusPanel
@onready var next_roll_bonus_label: RichTextLabel = $NextRollBonusPanel/NextRollBonusLabel


@onready var dice_ink: TextureRect = $Panel/DiceDisplay/DiceInk
@onready var power_ink: TextureRect = $CurrentPower/PowerInk

@onready var gpu_particles_2d: GPUParticles2D = $Panel/DiceDisplay/GPUParticles2D
@onready var cancel_red_card_panel: Panel = $CardDropArea/CancelRedCardPanel
@onready var cancel_red_card: TextureButton = $CardDropArea/CancelRedCardPanel/CancelRedCard

@onready var roll_history: RichTextLabel = $RollHistory
@onready var description_panel: Panel = $CardDropArea/CardBackground/CardFrame/DescriptionPanel


var ink_is_on = false


func _process(delta: float) -> void:
    # Glow follow (see GLOW_FOLLOW_* above). No-op until the first roll captures the rest
    # transforms; from then on the glows track the die's offset every frame - which is 0
    # whenever the die is at rest, so this also pins them home between rolls.
    if _dice_display_rest_captured:
        var glow_offset := dice_display.position - _dice_display_rest_position
        aura.position = _aura_rest_position + glow_offset * GLOW_FOLLOW_AURA
        emanation.position = _emanation_rest_position + glow_offset * GLOW_FOLLOW_EMANATION
    _tick_overcharge_gust(delta)


# Called by the ROLL button on button_down: compress the die and hold. Refused when the
# active type has no dice (the button's own press flash skips too - the pair stays
# visibly inert) or mid-roll (nothing to coil, the die is airborne).
func coil_die() -> void:
    if _roll_in_progress:
        return
    if int(Global.get(Global.dice_type + "_dice_current_amount")) <= 0:
        return
    _die_coiled = true
    dice_display.pivot_offset = dice_display.size / 2.0
    if _die_coil_tween and _die_coil_tween.is_valid():
        _die_coil_tween.kill()
    _die_coil_tween = create_tween()
    _die_coil_tween.tween_property(dice_display, "scale", Vector2(1.12, 0.82), 0.08) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# Relax a held coil without rolling - the cancel path (cursor dragged off the button,
# or the roll refused at release). No-op when nothing is coiled.
func release_die_coil() -> void:
    if not _die_coiled:
        return
    _die_coiled = false
    if _die_coil_tween and _die_coil_tween.is_valid():
        _die_coil_tween.kill()
    _die_coil_tween = create_tween()
    _die_coil_tween.tween_property(dice_display, "scale", Vector2.ONE, 0.09) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
# How many ±1 power adjustments have been spent on the CURRENT mech roll. Base mech allows 1;
# the Clockwork infusion (Mech) allows 2 (see _mech_adjustments_allowed).
var mech_adjustments_used := 0

# --- Ricochet Dice ("odd"): one reroll per roll ---------------------------------------------
# Deliberately built on the Mech ±1 pattern (same "post-roll adjustment" shape, same button
# polish, same column beside the die) with ONE critical divergence, flagged here because it is
# the thing that breaks if someone later "tidies" the two to match: Mech's allowance refreshes
# at the end of EVERY roll, because every Mech roll is a new die. A Ricochet reroll is the SAME
# roll happening again, so refreshing on its landing would grant an endless reroll chain. See
# the guarded reset at the end of _apply_roll_result.
var ricochet_rerolls_used := 0
# Power state as it stood immediately BEFORE the current roll resolved, so a reroll can put the
# discarded result back exactly. Captured in roll_dice() on fresh rolls only - a reroll has
# already restored to this same state, so re-capturing would be a no-op at best.
var _ricochet_snapshot := {}


# One reroll per roll. A function rather than a constant so a future Ricochet infusion can
# raise it the way Clockwork raises _mech_adjustments_allowed().
func _ricochet_rerolls_allowed() -> int:
    return 1


# Inferno infusion (Magma): only the FIRST magma roll of a turn double-burns. Reset in
# _on_player_turn_started.
var _magma_burned_this_turn := false
# Gap between Inferno's two burns - fired back-to-back they merged into what read as a
# single hit/number; the beat makes the double-burn legible (Julien, 2026-07-16).
const INFERNO_SECOND_BURN_DELAY := 0.35

# Guards against the Roll button's ~0.25s toss animation: the actual dice-count
# decrement only happens in dice_interface.gd::_on_dice_rolled, reacting to the
# dice_rolled/red_dice_rolled signal emitted at the END of _apply_roll_result()
# (i.e. after the animation finishes). Spam-clicking Roll during that window let
# every click pass the can_roll check against the same not-yet-decremented count,
# rolling far more dice than the player actually had. Set true the instant a roll
# is accepted, cleared once _apply_roll_result() has emitted that signal.
var _roll_in_progress := false

# --- Roll animation presets --------------------------------------------------------
# Four different takes on the core roll verb. Change ROLL_STYLE_DEFAULT below to switch;
# debug_roll_feel.gd renders any of them via the ROLL_STYLE env var so they can be
# compared side by side without editing code.
#   HOP  - leaps off the plinth, tumbles, slams back down. Playful, physical. (default)
#   TOSS - thrown toward the camera: swells until it dominates the panel, hangs, snaps
#          back on the result. Biggest frame presence - built for muted thumbnails.
#   SPIN - never leaves the plinth: spins like a roulette reel, decelerating, then
#          wobbles to a stop. Compact, tense, slot-machine energy.
#   DROP - yanked up and dropped hard, then bounces twice to rest. Heaviest, longest
#          settle - the most literal "real dice hitting a table".
#   CALM - the hop with the tumble removed: the die stays upright the whole flight and
#          swaps faces slowly. Keeps the weight (dust, landing squash, hit-stop) without
#          the vertigo. Default, because rotating a large centred element 5-15x per turn
#          is a genuine motion-sensitivity problem, not just a taste call (Julien got
#          dizzy testing the spinning versions - players would too, over a full run).
enum RollStyle { HOP, TOSS, SPIN, DROP, CALM }
const ROLL_STYLE_DEFAULT := RollStyle.CALM
var roll_style: RollStyle = ROLL_STYLE_DEFAULT

# ---- Rare surprise flight -------------------------------------------------------------
# A roll that already MATTERS occasionally arrives in a different presentation. Tuning
# knobs, all in one place:
#   CHANCE          how often an eligible roll gets one (Julien asked for ~2%)
#   MIN_VAL_FRAC    "big roll" gate - fraction of the die's own top face, so a 3 on a d3
#                   qualifies exactly like a 12 on a d12 (same ladder rule as the roll feel)
#   MIN_POWER       "big power" gate - an alternative way in, for a modest roll landing on
#                   an already-huge bank
#   MAX_PER_FIGHT   hard cap: the beat has to stay a surprise, not a mechanic
const SURPRISE_ROLL_CHANCE := 0.02
const SURPRISE_ROLL_MIN_VAL_FRAC := 0.8
const SURPRISE_ROLL_MIN_POWER := 18
const SURPRISE_ROLL_MAX_PER_FIGHT := 2
# Every style EXCEPT the default: the point is that it doesn't look like the usual roll.
const SURPRISE_ROLL_STYLES: Array[RollStyle] = [
    RollStyle.HOP, RollStyle.TOSS, RollStyle.SPIN, RollStyle.DROP,
]
var _surprise_rolls_this_fight := 0

# CALM tuning. Lower and slower than HOP - without the tumble to carry the eye, a big
# fast arc reads as twitchy. TILT is a gentle one-way rock (radians) instead of a spin:
# 0.0 is dead upright (what "hop without spin" literally means); ~0.10 adds a little
# life without anything going round. Face swaps are slow enough to read as a die
# settling rather than a strobe.
const CALM_HOP_HEIGHT := 46.0
const CALM_RISE_TIME := 0.15
const CALM_FALL_TIME := 0.12
const CALM_ARC_X := 8.0
const CALM_TILT := 0.0
# Must finish inside the SHORTEST possible flight, else the landing has to cut them off
# (it does - see _on_roll_landed - but a visibly truncated shuffle is worse than a short
# one). Worst case is a coiled press on a low roll with fast jitter: 0.05 + 0.132 + 0.103
# = ~0.285s. These sum to 0.23, leaving ~0.05s of margin.
const CALM_FLIP_DELAYS := [0.09, 0.07, 0.07]
# Per-roll timing spread + value-driven landing character (Julien, 2026-08): every roll
# jitters its rise/fall a little; HIGH rolls hang briefly at the apex; MAX rolls hold
# visibly in the air (with a tiny shiver of potential) then fall faster and harder - the
# hang-then-SMASH grammar the thrown dice already speak.
const CALM_TIME_JITTER := 0.12
const CALM_HIGH_HANG := 0.05
const CALM_HIGH_HANG_FRAC := 0.7
const CALM_MAX_HANG := 0.15
const CALM_MAX_FALL_TIME := 0.085
# Landing rattle, every roll, scaled by value^2 so low rolls stay quiet: on a d6 a 1-3
# doesn't shake at all (under LAND_SHAKE_MIN), a 4 barely trembles, a 6 rattles hard.
const LAND_SHAKE_STRENGTH := 8.0
const LAND_SHAKE_MIN := 2.0
# --- Landing audio + chain ladder (juice_audit P0b) -------------------------------
# The landing was SILENT before this - all roll audio played at the button press. Now
# every slam lands a thud whose PITCH climbs with the chain (each consecutive same-type
# roll steps up - the Balatro scoring ladder, and the thing that makes sound-on clips
# satisfying) while its VOLUME scales with the roll's value. Max rolls add a heavier
# impact on top. Both streams are PLACEHOLDERS (documented convention) - swap the files
# freely, the pitch/volume structure is the point.
const LAND_THUD_SOUND := preload("res://sounds/dicerollsound3.mp3")
# PLACEHOLDER landing audio, auditionable live in debug builds. The big-roll SMASH moved to
# Global (Global.high_roll_sound()) so the debug panel's SFX button and the F9 shortcut share
# one selection that also survives leaving the fight - F9 now just drives that same list.
# The RISER (swell at the max-roll hang, leading INTO the smash) is still local and still
# folder-driven: drop candidates into res://debug_sfx_candidates/riser/ and press F10 during
# any fight - each press swaps the stream, previews it once and prints the filename. The
# debug_* folder name rides the web export's exclude_filter, so candidates never ship.
var land_riser_sound: AudioStream = null  # none by default - F10 auditions candidates
const LAND_THUD_BASE_PITCH := 0.72
const LAND_THUD_CHAIN_PITCH_STEP := 0.07
const LAND_THUD_CHAIN_PITCH_CAP := 6
# The Power number's side of the beat: its punch deepens with chain depth (not just this
# roll's value), and crossing POWER_TIER_THRESHOLD banked power in one chain fires a
# one-shot ignition flare on the number - a top-tier moment ordinary turns never show.
const POWER_CHAIN_PUNCH_STEP := 0.06
const POWER_CHAIN_PUNCH_CAP := 5
const POWER_TIER_THRESHOLD := 18
# Mid-roll impact curve (Julien, 2026-08: "the 6s look really good, the others need more
# impact"). Ordinary landings get a value-scaled mini flash, a deeper squash, a frac-based
# hit-stop and a faster fall - the middle of the ladder rises, while the max keeps its
# exclusive KIND of celebration (gold flash + burst + flare + hang) so headroom survives.
const LAND_FLASH_BASE := 0.15
const LAND_FLASH_VALUE_BONUS := 0.55
const LAND_HIT_STOP_MIN := 0.05
const LAND_HIT_STOP_MAX := 0.13
const LAND_FALL_SPEEDUP := 0.15

# TOSS tuning. Peak scale is the whole point - at 1.55 the 140px die renders ~215px and
# briefly owns the frame, which is what makes it read at thumbnail size.
const TOSS_PEAK_SCALE := 1.55
const TOSS_MAX_BONUS := 1.08
const TOSS_LIFT := 26.0
const TOSS_RISE_TIME := 0.16
const TOSS_HANG_TIME := 0.05
const TOSS_FALL_TIME := 0.10
const TOSS_SPIN_TURNS := 1.25
const TOSS_FLIP_DELAYS := [0.06, 0.05, 0.05, 0.06, 0.07]

# SPIN tuning. The squeeze narrows the die while it's fast, which sells "spinning on
# edge" without any new art.
const SPIN_TURNS := 3.0
const SPIN_WINDUP_TIME := 0.07
const SPIN_TIME := 0.34
const SPIN_SQUEEZE := 0.84
const SPIN_WOBBLE_ANGLE := 0.15
const SPIN_WOBBLE_TIME := 0.11
const SPIN_FLIP_DELAYS := [0.07, 0.03, 0.03, 0.035, 0.04, 0.05, 0.06, 0.075]

# DROP tuning. Bounce fractions are of the drop height, decaying.
const DROP_HEIGHT := 150.0
const DROP_LIFT_TIME := 0.09
const DROP_FALL_TIME := 0.13
const DROP_SPIN_TURNS := 1.5
const DROP_BOUNCES := [0.30, 0.12]
const DROP_FLIP_DELAYS := [0.04, 0.045, 0.05, 0.06]

# --- Roll hop (the core roll verb: hop + tumble + slam, see juice_audit_2026-08.md P0) ---
# The die physically leaves its plinth, spins a full turn while cycling faces, and slams
# back down on the result. Total airtime ~0.25s + 0.10s wind-up squash = same budget as the
# old wiggle-in-place, so multi-roll turns don't get slower - the motion replaces dead time.
const ROLL_HOP_HEIGHT := 52.0
const ROLL_HOP_RISE_TIME := 0.14
const ROLL_HOP_FALL_TIME := 0.11
# Full turns over the airtime (sign randomized per roll). Most of the spin happens on the
# way up so the tumble visibly decelerates into the landing instead of spinning at a
# constant robotic rate.
const ROLL_SPIN_TURNS := 1.0
# Per-roll variation so back-to-back rolls don't trace the identical path (Julien,
# 2026-08: "solid base but a bit too similar each time"). Height/arc/spin-rhythm jitter
# is trajectory-only - every toss still lands on the exact rest transform.
const ROLL_HOP_HEIGHT_JITTER := 0.18
const ROLL_HOP_ARC_X := 16.0
const ROLL_SPIN_RISE_FRACTION_MIN := 0.52
const ROLL_SPIN_RISE_FRACTION_MAX := 0.72
# Some rolls get a small second bounce after the slam (real-dice read). NEVER on a max
# roll - the hit-stop + celebration own that landing beat, and diluting it would cost
# the "smash" Julien specifically likes; also skipped on a rolled 1 (a dud shouldn't
# bounce with energy).
const ROLL_DOUBLE_BOUNCE_CHANCE := 0.35
const ROLL_DOUBLE_BOUNCE_HEIGHT := 0.26
# Max rolls toss slightly higher: bigger rise -> bigger fall -> bigger smash, a subtle
# wind-up for the celebration that follows.
const ROLL_MAX_HOP_BONUS := 1.15
# Face-swap delays (seconds between swaps) across the airtime - decelerating, like the old
# flip_intervals, but now the swaps ride a die that's actually tumbling.
const ROLL_FLIP_DELAYS := [0.10, 0.06, 0.07, 0.07]
# The in-flight animation tweens, tracked so a new roll (or anything else that needs the
# die at rest) can kill them and snap the die back to its true resting transform first.
# Without this, capturing "start position" while a previous max-roll shake is still
# offsetting the die would bake that offset in as the new rest and the die would drift.
var _roll_anim_tween: Tween
var _roll_flip_tween: Tween
# Secondary motion that runs alongside the main flight on its own timeline (SPIN's
# squeeze). Tracked with the rest so a re-roll kills it instead of leaving the die
# squashed at whatever width the interrupted spin left behind.
var _roll_aux_tween: Tween
var _dice_shake_tween: Tween
# Set by a builder whose settle already owns dice_display.position after landing (the
# double bounce) - the landing rattle would fight it for the same property, alternating
# writes every frame. One-shot: _on_roll_landed reads and clears it.
var _suppress_land_shake := false
# Tier-crossing latch for POWER_TIER_THRESHOLD. Deliberately NOT reset by the power-reset
# paths: it's recomputed on every roll, and after a reset the first roll's recompute sets
# it false (no single face reaches the threshold), so a stale true can't suppress a real
# crossing - and touching the reset paths isn't worth it for a celebratory one-shot.
var _power_tier_active := false
var _roll_history_punch_tween: Tween
var _dice_display_rest_position := Vector2.ZERO
var _dice_display_rest_captured := false
# The glow layers follow the die's flight (Julien, 2026-08): each _process frame mirrors
# the die's offset-from-rest onto the aura (1:1 - it's the die's own halo) and the
# emanation (damped - it's the ambient light pool, and it should LAG like heavy light,
# which also keeps its shader's hard-coded dice-row clearance band from shifting far).
# Mirroring in _process instead of parallel tweens means every motion source (hop, hang
# shiver, landing shake, double bounce) is covered automatically, and at rest the offset
# is ZERO so both layers are pinned exactly to their captured homes.
const GLOW_FOLLOW_AURA := 1.0
const GLOW_FOLLOW_EMANATION := 0.35
var _aura_rest_position := Vector2.ZERO
var _emanation_rest_position := Vector2.ZERO
# Button->die weld (Julien, 2026-08: "feel your ROLL press make the dice hop"). Godot
# buttons fire `pressed` on RELEASE, which this exploits: button_down COILS the die into
# its wind-up squash and HOLDS it there for as long as the button is held; releasing
# launches the hop from the coil (the builders skip their own compress step when coiled).
# The press literally compresses the die, the release lets it go.
var _die_coil_tween: Tween
var _die_coiled := false
# Plinth dip on big landings ("the table felt it"). ⚠️ The ROLL Button is NOT inside
# Panel - it's a sibling on the dice root (button.gd's $".." is the Dice itself) - so the
# dip must move BOTH. Dipping Panel alone moved only die+aura, which vanished inside the
# landing celebration: "the roll button is not moving by an inch" (Julien, 2026-08).
var _panel_dip_tween: Tween
var _panel_rest_position := Vector2.ZERO
var _roll_button_rest_position := Vector2.ZERO
# Max-fall motion smear: ghost counter reset per roll, advanced by _smear_step.
var _smear_spawned := 0

const MECH_ARROW_HOVER_SCALE := Vector2(1.2, 1.2)
const MECH_ARROW_HOVER_DURATION := 0.1
const MECH_ARROW_PUNCH_SCALE := Vector2(0.8, 0.8)
const MECH_ARROW_PUNCH_DURATION := 0.08

var _mech_increase_tween: Tween
var _mech_decrease_tween: Tween
var _ricochet_reroll_tween: Tween

# Power "clang" impact (power-manipulation cards - see _play_power_clang). Tracked so rapid
# re-triggers kill the prior tweens instead of compounding. _power_resting_modulate is
# captured in update_dice_display() so the flash always returns to the true dice-type color
# rather than whatever mid-flash brightened value modulate happens to hold.
var _power_clang_scale_tween: Tween
var _power_clang_flash_tween: Tween
# Roll/orb-arrival flashes tween current_power.modulate back to a SNAPSHOT of the
# color taken when they started. If the active dice type switches mid-flash (playing a
# red card then hopping to blue before the 0.2s flash finishes), that snapshot is the
# OLD dice color and the flash restores it on top of the new type's color - the power
# number "stays red". Tracked here so the dice switch can kill it. See _on_active_dice_changed.
var _power_color_flash_tween: Tween
var _power_clang_rattle_tween: Tween
# Bumped by anything that establishes a NEW power baseline (a roll, a dice-type switch, a
# turn start, a later reset). _on_dice_roll_reset's red branch waits 1s before zeroing (so
# the red roll stays readable for a beat), and that pending wipe must NOT land on power the
# player has earned since: play a red card, hop to blue and roll inside that window and the
# stale timer used to blank the fresh blue roll (Julien, 2026-07-27). The coroutine captures
# this counter before awaiting and bails if it moved.
var _power_reset_generation := 0
var _power_resting_modulate := Color.WHITE
# Last power value shown on screen (kept current by _set_power_text). The clang only fires
# when a change_current_power emit is accompanied by the value actually differing from this -
# so power cards (Reinforce etc.) clang, but cards that emit the signal only to refresh their
# display after charging dice / blocking / dealing damage do not.
var _last_shown_power := 0

# Next-roll slot "delivery" pop (see _on_next_roll_determined) - tracked so back-to-back
# emissions (e.g. two Focus plays) restart the punch instead of compounding tweens.
var _next_roll_pop_tween: Tween

# Cached so the power-orb texture (a soft radial gradient) isn't rebuilt on every single roll -
# this effect fires very frequently, unlike the one-off refuel/discard animations elsewhere.
var _power_orb_texture: GradientTexture2D

# Refuel "dice return" (Recombobulate, Enrage, Voodoo, Catalyst...) - see
# _spawn_refuel_return(). The dice you rolled this turn pop out of the played card, rise to
# hover above it (giving the player a moment to register "those are the dice I just rolled"),
# then fly back into the die, showing they've been put back into your pool.
const REFUEL_RETURN_MAX_ICONS := 8    # cap so a huge roll_history doesn't spawn a swarm
const HISTORY_FACE_SIZE := 22         # px size of the mini die faces in the roll-history row
const REFUEL_RETURN_RISE := 0.14      # pop out of the card + rise to hover, time
const REFUEL_RETURN_HOVER := 0.4      # how long they float above the card before flying in
const REFUEL_RETURN_HOVER_BOB := 7.0  # small vertical drift while hovering, so it reads as floating, not paused
const REFUEL_RETURN_FLIGHT := 0.5     # hover position -> die, time
const REFUEL_RETURN_STAGGER := 0.06   # delay between successive icons launching

# Power orbs (2026-07-03): a small handful of glowing orbs travel from the die to the Power
# label on every single roll, each along its own randomized curved path - guided (they always
# land exactly on the Power label, so the "charging" story reads clearly) but bowed through a
# randomized control point so several orbs fan out differently instead of tracing the same
# line, reading as an emanating spray rather than a mechanical conveyor belt. This fires VERY
# frequently (every roll of every dice type), so it must stay small/fast, especially on low
# rolls - it's a complement to the roll's own landing juice (impact punch, aura pulse,
# hit-stop, and on max rolls the existing gold flash + radial burst), never the main event.
const POWER_ORB_MIN_COUNT := 3
const POWER_ORB_MAX_COUNT := 11
const POWER_ORB_MAX_ROLL_BONUS := 4      # extra orbs on a max roll, on top of the count formula below
const POWER_ORB_SIZE_MIN := 12.0
const POWER_ORB_SIZE_MAX := 22.0
const POWER_ORB_SIZE_BIG_ROLL_BONUS := 10.0  # added to size on top rolls, so big hits read visibly chunkier
const POWER_ORB_BRIGHTNESS := 1.5
const POWER_ORB_MAX_ROLL_BRIGHTNESS := 2.1   # extra overbright punch specifically on max rolls
const POWER_ORB_FLIGHT_MIN := 0.12
const POWER_ORB_FLIGHT_MAX := 0.95       # widened again (was 0.14-0.58) - Julien: "all of them are always pretty fast" - the old max wasn't slow enough for a slow orb to actually read as slow next to a fast one
# Per-orb launch delay is drawn independently at random across this whole window (0 to
# STAGGER*count), rather than each orb owning a fixed slot (index*STAGGER) with jitter on top.
# The indexed version still mostly preserved launch ORDER even with jitter, which is exactly
# what read as a "train" - fully independent draws mean orb #7 can launch before orb #2.
const POWER_ORB_LAUNCH_WINDOW_PER_ORB := 0.05
# Each orb also gets its own acceleration PROFILE (trans/ease pair), not just its own speed -
# same-shaped easing curves on every orb was the other big remaining "everything moves
# identically" cue, even once individual speeds/paths already varied.
const POWER_ORB_EASE_PROFILES := [
    [Tween.TRANS_SINE, Tween.EASE_IN],
    [Tween.TRANS_QUAD, Tween.EASE_IN],
    [Tween.TRANS_CUBIC, Tween.EASE_IN_OUT],
    [Tween.TRANS_SINE, Tween.EASE_IN_OUT],
    [Tween.TRANS_EXPO, Tween.EASE_IN],
]
# Perpendicular sine wobble layered onto the bezier path itself, so the trajectory squiggles
# instead of being a clean mechanically-smooth arc - envelope is 0 at both endpoints (via
# sin(t*PI)) so orbs still launch cleanly from the die and land exactly on the Power label,
# only the MIDDLE of the flight drifts off the pure curve.
const POWER_ORB_WOBBLE_FREQ_MIN := 1.1   # oscillations across the full flight
const POWER_ORB_WOBBLE_FREQ_MAX := 2.6
const POWER_ORB_WOBBLE_AMP_MIN := 5.0
const POWER_ORB_WOBBLE_AMP_MAX := 16.0
# Where along the path (0=die, 1=Power label) each orb's control point sits - randomized per
# orb instead of a fixed 0.55, so some orbs bow early/steep and others late/shallow rather than
# all tracing the same silhouette.
const POWER_ORB_MID_X_MIN := 0.35
const POWER_ORB_MID_X_MAX := 0.75
# The die sits left of the Power label at roughly the same height - a straight line between
# them reads as flat/boring. Orbs instead arc UP and over (a rough "rainbow" shape per Julien's
# note - deliberately loose, not a precise math curve), landing on the Power label FROM ABOVE
# rather than approaching it level, which reads as much more impactful.
const POWER_ORB_ARC_HEIGHT_MIN := 40.0
const POWER_ORB_ARC_HEIGHT_MAX := 130.0

# Landing sfx - a light tick per orb as it's absorbed into the Power number. Placeholder
# asset (unused elsewhere in the project) - swap for a proper "chime" sound if Julien has one.
# Pitch/volume are jittered per hit so a burst of orbs doesn't read as the same note on repeat.
const POWER_ORB_LAND_SFX := preload("res://sfx/578807__nomiqbomi__pluck-1.mp3")
const POWER_ORB_LAND_PITCH_MIN := 0.85
const POWER_ORB_LAND_PITCH_MAX := 1.25
const POWER_ORB_LAND_VOLUME_DB := 2.0     # bumped again from -4 (Julien: still louder) - was -10 originally
const POWER_ORB_LAND_VOLUME_JITTER := 3.0

# Support-card power orbs (2026-07-17): when a played CARD raises Power (Reinforce, Blaze,
# From Nothing...), orbs fly from the card into the Power number - the same visual language
# as the roll orbs above, but a card-driven gain is much rarer than a roll, so this burst is
# deliberately bigger, slower and more ceremonial: fewer-but-chunkier orbs that first bloom
# OUTWARD from the card's resolve point, then get pulled down into the number (the roll orbs'
# rainbow arc would read as "just another roll"). Detection lives in _on_change_current_power:
# "power genuinely increased in the same frame as a card play" - Card.play() emits card_played
# as its first line and every power-raising card emits change_current_power synchronously
# inside that same play() call, which cleanly excludes roll-adjacent sources (Blood Sword,
# Metronome, Opening Gambit all fire on a roll frame) and the ~19 display-refresh-only
# emitters (no actual power delta).
const CARD_ORB_MIN_COUNT := 5
const CARD_ORB_MAX_COUNT := 12
const CARD_ORB_SIZE_MIN := 18.0
const CARD_ORB_SIZE_MAX := 30.0
const CARD_ORB_SIZE_DELTA_BONUS := 8.0    # extra size as the power gain approaches ~10
const CARD_ORB_BRIGHTNESS := 1.8
const CARD_ORB_FLIGHT_MIN := 0.5
const CARD_ORB_FLIGHT_MAX := 1.1
const CARD_ORB_LAUNCH_WINDOW := 0.35      # per-orb launch delay drawn independently across this window
const CARD_ORB_FLING_DIST_MIN := 60.0     # how far the outward bloom reaches before curving into the number
const CARD_ORB_FLING_DIST_MAX := 140.0
const CARD_ORB_WOBBLE_AMP_MIN := 8.0      # slightly loopier than the roll orbs - longer flights can carry it
const CARD_ORB_WOBBLE_AMP_MAX := 22.0

# Die-glow-charges-with-power tuning (see _update_dice_aura_charge()). All 9 per-dice-type
# shaders (blue_dice_shader.tres etc.) share a "power_intensity" uniform (hint_range 0.1-2.0)
# that was previously left at its authored default (~1.8, near the top of its own range) at
# all times - these constants now own that value explicitly instead. Levers that scale
# together with banked power this turn: brightness (power_intensity), spread (glow_reach),
# swirl speed (wave_speed), and color (charge_heat, blends toward a warm highlight - see
# dice_glow.gdshader). REST is kept clearly visible (not "no glow"), and the ramp uses sqrt
# so a couple of early rolls already reads as charged rather than needing a whole big turn.
#
# Deliberately NOT scaling the aura node's own transform to make it "grow" - border_size
# (where the glow ring starts) is defined relative to the node's OWN size, but the die itself
# never grows, so scaling the node up dragged the ring away from the die again as power
# increased (worked fine near rest, visibly gapped by ~power 8 - the die and its glow have
# no shared reference frame once the node scales). glow_reach instead widens how far the glow
# fades OUT within the node's fixed footprint, so the anchor point at the die's edge never
# moves regardless of charge level.
const AURA_INTENSITY_REST := 1.1
const AURA_INTENSITY_MAX := 2.0
const AURA_REACH_REST := 0.15  # matches the shader's original hardcoded value
const AURA_REACH_MAX := 0.45
const AURA_WAVE_SPEED_MULT_MAX := 1.9  # swirl runs ~90% faster at full charge
const AURA_HEAT_MAX := 1.0  # shader's own 0.55 blend cap keeps each die's base hue visible
# How far the on-charge flash may push glow_reach above its banked-power level. Small by
# design - see the comment at the reach_rise tweener in _on_charge_delivered().
const AURA_CHARGE_FLASH_REACH_BUMP := 0.05
const AURA_CHARGE_FULL_AT_POWER := 12.0  # used by the power-number crackle (_update_power_float), not the aura glow curve below
# Aura glow curve shape: t = 1 - e^(-roll_value / AURA_CHARGE_SOFTNESS). ~10 lands power 5
# at roughly the same charge level the old smoothstep(0,12,x) curve gave (~39%), while power
# 9/13/20+ all come in lower than that curve did (~59%/~73%/~86% vs ~84%/100%/100%).
const AURA_CHARGE_SOFTNESS := 10.0
const AURA_RED_BASELINE_CHARGE := 0.47  # ~6-7 power on blue, under the curve above

# Transient per-roll punch (aura_pulse, in roll_dice()) still uses aura.scale for a quick
# in-and-immediately-back-out impact - that's momentary so it doesn't create a persisting
# gap. It always settles back to this fixed 1.0, not a charge-dependent value.
const AURA_SCALE_REST := 1.0

# Per-type base wave_speed (read from each dice_*_shader.tres) - needed so driving wave_speed
# dynamically multiplies from the RIGHT starting point per type instead of a single guess;
# magma is the only outlier (2.55 vs 2.022 everywhere else).
const AURA_BASE_WAVE_SPEED := {"magma": 2.55}
const AURA_BASE_WAVE_SPEED_DEFAULT := 2.022

# Magma's own authored power_intensity default was already 2.0 (the shader's ceiling) before
# any of this charge system existed - that WAS its "always hot" identity. Driving it from the
# same AURA_INTENSITY_REST as every other (calmer-by-design) type meant it actually read
# dimmer than its old always-on baseline for most of a turn. Override its own rest point
# closer to the ceiling instead, so growth is a smaller top-up rather than a big dip-then-rise.
const AURA_INTENSITY_REST_OVERRIDE := {"magma": 1.75}

# Emanation layer ("magic energy" tongues rising off the die, dice_emanation.gdshader on
# $Emanation - Necrobinder-inspired pass, 2026-07-23). Colors come from DicePalette
# (accent = bright tongues/rim, outline = tongue bodies), which is infusion-aware, so
# infused dice recolor for free. The shader derives reach/density/speed internally from
# its single "charge" uniform (same t curve as the ring glow) - only these stay in code:
const EMANATION_BASE_SPEED := {"magma": 1.26}  # matches magma's faster ring (2.55/2.022)
const EMANATION_BASE_SPEED_DEFAULT := 1.0
const EMANATION_SURGE_DECAY_TIME := 0.55  # landing flare fade-out

var _emanation_surge_tween: Tween
# The aura's charge flash (brightness+reach flare on every dice_charged) - tracked so a
# rapid multi-type volley restarts the flare instead of stacking writers on the uniforms.
var _charge_flash_tween: Tween

# Contained charge pulse - ROUND 2 (2026-08-25). Round 1 drove a scaled sprite band and it
# did NOT read as a wave; measured frame by frame, its body (~35px) was as wide as its
# entire travel (40px), so no gap ever opened between the die and the front. It inflated
# and faded in place: a BREATH. A scaled sprite can never fix this - the band thickens at
# exactly the rate it advances.
#
# Round 2 drives a CONSTANT-WIDTH front through the emanation shader instead, so the wave
# is made of the die's own light field: the licks lean outward and flare as it passes
# (the "gust"), and a bright front rides out along the die silhouette. Still contained -
# it dies inside its own light pool, roughly half a die-width past the edge (see round 3
# below for the current number) - so the 2026-08-14 "too much intensity & too fast" verdict
# stays respected; what changed is that the travel is now legible at all.
#
# ROUND 3 (2026-08-29, Julien): "it feels rushed atm, like instantly after the charged dice
# goes to the dice interface we get a very fast pulse. I want more dice goes to dice
# interface, very small anticipation, boom! pulse. And more of a strong shockwave than a
# fast pulse." Two separate fixes, and neither is a number tweak on its own:
#   TIMING  - the front used to fire on the same frame the last die landed, so the clack,
#             the panel kick and the eruption were one undifferentiated bang. There is now
#             a wind-up beat (CHARGE_PULSE_ANTICIPATION) between the landing and the
#             detonation: the converging particle ring collapses inward and the aura dips
#             (an inhale) during it, then everything erupts on one later frame. The absorb
#             ceremony already had exactly this shape internally (squash -> hold -> punch)
#             and just happened to punch 0.3s AFTER the front - now both land together.
#   WEIGHT  - the shipped variant used to be the FAST one (travel x0.78). That is the exact
#             quality being complained about, so "punchy" now means heavier and wider, not
#             quicker: longer travel, more reach, higher amplitude, and a HOLD at peak so
#             the front has body instead of blinking. The width/travel ratio still respects
#             the round-1 lesson (a front as thick as its travel reads as a breath).
const CHARGE_PULSE_ANTICIPATION := 0.22  # landing -> detonation. The wind-up beat.
# Roughly when the inward-converging particle ring reaches the die centre at speed_scale 1
# (emission radius 85px under ~1500px/s^2 of inward accel). The ring is time-scaled so its
# arrival always lands ON the detonation - it IS the visible anticipation, so it must not
# still be falling in after the bang.
const CHARGE_PARTICLE_CONVERGE := 0.33
const CHARGE_AURA_INHALE := 0.78      # how far the aura dims during the wind-up
const CHARGE_GUST_TIME := 0.50        # die edge -> full extent (was 0.34 shipped: too quick to read)
const CHARGE_GUST_REACH := 78.0       # px beyond the silhouette (still contained, see rect note)
const CHARGE_GUST_START := -14.0      # born just INSIDE the edge, so it emerges from the die
const CHARGE_GUST_PEAK := 1.02
const CHARGE_GUST_RISE := 0.045       # amplitude snap
const CHARGE_GUST_HOLD := 0.10        # peak HOLD - this is what turns a blink into a wave front
const CHARGE_GUST_COUNT_STEP := 0.06  # ladder: Charge 4 reads a little heavier than Charge 1
const CHARGE_GUST_PEAK_CAP := 1.35    # under the uniform ceiling on purpose - a saturated
                                      # front loses the lick texture that keeps it organic
# The volley freeze moved here from dice_interface (2026-08-29). It belongs on the loudest
# moment, and the loudest moment is now the detonation, not the landing 0.22s earlier. Two
# freezes that close apart read as stutter, so the landing keeps its clack/kick/flash and
# this owns the time distortion. Cooldown mirrors the one it replaced: a multi-type charge
# is N separate one-die volleys and must not chain N freezes.
const CHARGE_HIT_STOP_SCALE := 0.05
const CHARGE_HIT_STOP_COOLDOWN_MS := 350
var _last_charge_hit_stop_ms := -99999
# Guard against N fronts stacking in one instant (the additive-overexposure trap). Since
# 2026-08-28 the pulse fires on DELIVERY and same-frame multi-type volleys are sequenced by
# the interface (>= CHARGE_STAGGER apart), so each volley legitimately gets its own tinted
# front - that IS the multi-type reveal. This now only catches degenerate same-instant
# deliveries, e.g. two no-flight fallbacks resolving in a single frame.
const CHARGE_PULSE_COOLDOWN_MS := 110
var _last_charge_pulse_ms := -10000
var _charge_gust_tweens: Array[Tween] = []
# Optional companion sprite band (mode 1). Thin ON PURPOSE - see the round-1 post-mortem
# above; it must stay far thinner than its travel or it stops reading as motion.
const CHARGE_RING_TIME := 0.44
const CHARGE_RING_TRAVEL_MULT := 1.9
const CHARGE_RING_ALPHA := 0.34

# Pulse variant. 2 is what SHIPS (Julien's pick off the 2026-08-25 bake-off plate); the
# other values exist so that plate stays reproducible - the render harness sets this, and
# nothing in gameplay ever does.
#   0 = gust, standard        1 = gust + thin sprite ring
#   2 = gust, punchier (LIVE) 3 = none (pre-pulse baseline: aura flare + particles only)
var charge_pulse_mode := 2

var evil_faces = [
                load("res://assets/images/evil0.png"),
                load("res://assets/images/evil6.png"),
                load("res://assets/images/evil6.png"),
                load("res://assets/images/evil6.png"),
            ]
var giant_faces = [
                load("res://assets/images/giant1.png"),
                load("res://assets/images/giant2.png"),
                load("res://assets/images/giant3.png"),
                load("res://assets/images/giant4.png"),
                load("res://assets/images/giant5.png"),
                load("res://assets/images/giant6.png"),
                load("res://assets/images/giant7.png"),
                load("res://assets/images/giant8.png"),
                load("res://assets/images/giant9.png"),
                load("res://assets/images/giant10.png"),
                load("res://assets/images/giant11.png"),
                load("res://assets/images/giant12.png"),
            ]

var magma_faces = [
                load("res://assets/images/magma1.png"),
                load("res://assets/images/magma2.png"),
                load("res://assets/images/magma3.png"),
                load("res://assets/images/magma4.png"),
                load("res://assets/images/magma5.png"),
                load("res://assets/images/magma6.png"),

            ]
            

var even_faces = [
                load("res://assets/images/even2.png"),
                load("res://assets/images/even4.png"),
                load("res://assets/images/even6.png"),
                load("res://assets/images/even8.png"),
            ]
var odd_faces = [
                load("res://assets/images/odd1.png"),
                load("res://assets/images/odd3.png"),
                load("res://assets/images/odd5.png"),
                load("res://assets/images/odd7.png"),
            ]
            
var green_faces = [
                load("res://assets/images/green1.png"),
                load("res://assets/images/green2.png"),
                load("res://assets/images/green3.png"),
            ]
var mech_faces = [
                load("res://assets/images/mech1.png"),
                load("res://assets/images/mech2.png"),
                load("res://assets/images/mech3.png"),
                load("res://assets/images/mech4.png"),
                load("res://assets/images/mech5.png"),
                load("res://assets/images/mech6.png"),
            ]
            
var dice_roll_sounds = [
    "res://sounds/dicerollsound1.mp3",
    "res://sounds/dicerollsound2.mp3",
    "res://sounds/dicerollsound3.mp3"
]

var socketed_card_ui: CardUI = null
# Second Red socket (the Second Socket card). Null and unused at capacity 1, which keeps
# every existing single-socket path bit-identical.
var socketed_card_ui_2: CardUI = null
var _socket_2: Control = null
# Where the duplicated socket sits relative to socket 1. Socket 1 is 140 wide at scale
# 0.857 (~120 on screen), so this clears it with a small gap. Verified by render.
const SOCKET_2_OFFSET := Vector2(-126.0, 0.0)
var _flying_charged_card_to_discard := false
# _on_card_charged awaits mid-function while auto-canceling a previous socketed card. Without
# this guard, socketing a second card during that 0.1s window could race: the interleaved call
# would see socketed_card_ui already null (the first call's auto-cancel already cleared it),
# skip its own auto-cancel, socket itself, and then get silently overwritten when the first
# call resumes and re-assigns socketed_card_ui - orphaning the interleaved card hidden/disabled
# in the hand with nothing pointing at it to ever bring it back (looks like "cards vanished").
var _socketing_in_progress := false

# The socketed/charged-card display (charged_card_texture/charged_card_description) is a
# separate, static UI built directly into this scene — not the actual CardUI's own Label,
# which already refreshes itself via card_ui.gd's dice_rolled/dice_roll_reset/
# change_current_power/red_dice_rolled connections. This needs its own refresh call at the
# same trigger points so the socketed card shows live resolved damage too.
func _update_charged_card_description() -> void:
    if not is_instance_valid(socketed_card_ui):
        return
    var card = socketed_card_ui.card
    if card and card.has_method("get_dynamic_description"):
        # See card_ui.gd::_on_dice_rolled_update_description - the socketed panel is a hand
        # -built copy of the card's description slot, so it needs the same requirement scope
        # or a gate-boosting relic would show here but not on the card, or vice versa.
        Global.playing_card_requirement = card.requirement
        _set_charged_description(card, card.get_dynamic_description(
            socketed_card_ui.player_modifiers, _socketed_aimed_target()))
        Global.playing_card_requirement = -1


# Mirrors card_ui.gd::_apply_description(): this panel is a hand-built copy of the card's
# description slot, so its text goes through the same colorizer - keywords, the Power glyph,
# resolved-value parens - or a card would drop its glyph the moment it entered the socket,
# which is exactly where a red-die card is read the longest. [center] is explicit because
# RichTextLabel has no horizontal_alignment (the CenterContainer around it does the vertical
# half, as in card_ui.tscn). Glyph size follows the card convention of font_size + 2, and the
# step-down mirrors card_ui.gd's: this panel is the same 140x44 slot, so anything that overflows
# on the card (Crescendo, Resonance, Transmutation...) overflows here too - the old "socket text
# is never long enough" assumption was wrong, any card can be dropped on the red die.
const CHARGED_DESC_FONT_SIZE_CANDIDATES: Array[int] = [12, 11, 10, 9, 8]


func _set_charged_description(card: Card, text: String) -> void:
    # Same reclaim as the card's own panel (see CardUI.DESC_PANEL_HEIGHT): the panel is invisible
    # (its bg matches the card body), so it can eat the dead space below whenever the BonusEffect
    # row is hidden. Must run before the measuring loop below.
    description_panel.offset_top = CardUI.DESC_PANEL_TOP
    description_panel.offset_bottom = CardUI.DESC_PANEL_TOP + (
        CardUI.DESC_PANEL_HEIGHT_WITH_BONUS if card.bonus_requirement != Card.Requirement.NONE
        else CardUI.DESC_PANEL_HEIGHT)
    var available := description_panel.size.y
    for font_size: int in CHARGED_DESC_FONT_SIZE_CANDIDATES:
        charged_card_description.add_theme_font_size_override("normal_font_size", font_size)
        charged_card_description.text = "[center]%s[/center]" % card.get_colorized_description(
            text, font_size + 2)
        if charged_card_description.get_content_height() <= available:
            return


# The socketed CardUI stays hidden the whole time it sits in the socket (see _on_card_charged's
# card_ui.hide()), INCLUDING during the forced aim after the red roll - so this panel, not the
# card's own label, is what the player reads while pointing at an enemy. It therefore needs the
# aimed target too, or the preview silently drops the target's DMG_TAKEN modifier and undercounts
# against an Exposed enemy (the damage actually dealt was always right; only this number lied).
# card_target_selector.gd fills CardUI.targets as you sweep over enemies; an entry can be freed
# mid-aim (an AoE killing the enemy you're hovering), hence the validity check - read-only here,
# the card prunes its own array in _prune_stale_targets().
func _socketed_aimed_target() -> Node:
    for target in socketed_card_ui.targets:
        if is_instance_valid(target):
            return target
    return null


# Takes the card argument even though it goes unused: card_aim_target_changed emits one, and a
# 0-arg callable on an N-arg signal connects fine but errors at emit time and never runs.
# _update_charged_card_description already no-ops unless something is actually socketed.
func _on_card_aim_target_changed(_card_ui) -> void:
    _update_charged_card_description()



func _on_power_hover_entered() -> void:
    _cleanup_power_tooltip()
    var tooltip := PowerTooltipScene.instantiate()
    Global.add_tooltip(tooltip, self)
    var tooltip_panel: Panel = tooltip.get_node("Tooltip")
    tooltip_panel.get_tooltip_content("Power")
    tooltip_panel.show_tooltip(POWER_TOOLTIP_POS)
    _power_tooltip = tooltip
    # Safety net: mouse_exited never fires if the tree pauses mid-hover (map consult, pause
    # menu) - same failure mode as every other tooltip in the project.
    get_tree().create_timer(8.0).timeout.connect(_cleanup_power_tooltip)


func _on_power_hover_exited() -> void:
    _cleanup_power_tooltip()


func _cleanup_power_tooltip() -> void:
    if _power_tooltip and is_instance_valid(_power_tooltip):
        _power_tooltip.queue_free()
    _power_tooltip = null


func _exit_tree() -> void:
    _cleanup_power_tooltip()
    _shutdown_overcharge()


func _ready():
    power_hover_zone.mouse_entered.connect(_on_power_hover_entered)
    power_hover_zone.mouse_exited.connect(_on_power_hover_exited)
    Events.active_dice_changed.connect(_on_active_dice_changed)
    Events.battle_started.connect(_on_battle_started)
    Events.dice_rolled.connect(_on_dice_rolled)
    Events.player_turn_started.connect(_on_player_turn_started)
    Events.dice_roll_reset.connect(_on_dice_roll_reset)
    Events.card_charged.connect(_on_card_charged)
    Events.card_aim_target_changed.connect(_on_card_aim_target_changed)
    Events.reset_charged_card.connect(_on_reset_charged_card)
    Events.change_current_power.connect(_on_change_current_power)
    Events.next_roll_determined.connect(_on_next_roll_determined)
    Events.dice_charge_delivered.connect(_on_charge_delivered)
    Events.put_ink_on_dice.connect(_on_put_ink_on_dice)
    Events.remove_ink_from_dice.connect(_on_remove_ink_from_dice)
    Events.display_next_roll_modifier.connect(_on_display_next_roll_modifier)
    Events.clear_socket.connect(_on_clear_socket)
    Events.update_roll_history_ui.connect(update_roll_history_ui)
    Events.refuel_happened.connect(_on_refuel_happened)
    Events.dice_thrown.connect(_spawn_thrown_dice)
    Events.coin_flip.connect(_spawn_coin_flip)
    Events.card_played.connect(_on_card_played_track_frame)
    # 2-arg signal, 2-arg handler: a 0-arg callable would connect without complaint and then
    # silently never run (documented Godot 4 arity trap).
    Events.battle_over_screen_requested.connect(_on_battle_over_screen_requested)

    
    # Long chains (Turbo Mode territory, 8+ rolls) wrap to a second row of mini faces
    # instead of clipping at the RichTextLabel's fixed width (fit_content grows height).
    roll_history.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY

    # Bounds of the slot-row clearance come from the row's real rect, once layout settles.
    _sync_emanation_row_clearance.call_deferred()

    # Surge motes: the timer polls forever and spawns nothing while Surge is 0, so there is
    # no signal to hook and no way for a grant/expiry path to forget to switch it on.
    _setup_surge_motes()
    _cache_die_rest_rect.call_deferred()

    # Overcharge: the ember timer polls forever and spawns nothing below its tier, same
    # no-signal-to-forget design as the Surge motes above.
    _setup_overcharge()

    # Initialize the dice display with the correct texture based on dice_type
    update_dice_display()

    # Make sure Global.dice_type is synchronized
    Global.dice_type = dice_type
    _set_socket_empty()
    _update_power_float()
    _update_dice_aura_charge()

# Single chokepoint for the Power number's text, so the font size can shrink as the number
# grows. An 80px glyph looks great at 1 digit but too big at 2+ (and the magnitude
# rest-scale compounds it). Keeps single digits punchy while taming "14"-style values.
func _set_power_text(value) -> void:
    var s := str(value)
    current_power.text = s
    # Single source of truth for "what power value is currently on screen". Every display
    # update (rolls, power-cards, resets, refuel drain) flows through here, so the clang can
    # compare against this to know whether power ACTUALLY changed vs the signal just firing.
    _last_shown_power = s.to_int()
    var fs := 80
    if s.length() >= 3:
        fs = 48
    elif s.length() == 2:
        fs = 60
    if current_power.label_settings:
        current_power.label_settings.font_size = fs

# The power label's idle float (power_float.gdshader) should only play while there's
# actually power banked - at 0 it should sit dead still, not "emanate" nothing. The crackle
# specifically also scales WITH how much power is banked (barely perceptible at 2-3, full
# "about to go BOOM" intensity by ~12+) rather than snapping straight to full at any power -
# reuses the same smoothstep-to-12 curve and cap as the die's aura charge for consistency.

# Flux (Lurker): "you cannot roll the SAME Dice type twice in a row".
#
# The chain (roll_history) is cleared by a Power reset AND by a dice-type change, so
# hopping type is normally a legal escape already - at the cost of your banked Power.
# The last_rolled_type test is what makes the rule per-TYPE rather than "no second roll":
# under Kaleidoscope the chain SURVIVES a type change, and without it Flux would lock the
# player out for the whole turn instead of being countered. That is the Kaleidoscope play
# against a Flux enemy (Julien, 2026-08-19): keep banking Power for as long as you keep
# alternating dice types. Verified end to end by debug_flux_rule.gd - do NOT collapse this
# back into a blanket "roll_history is not empty" check.
#
# A Ricochet reroll is exempt: a reroll is not a second roll - it replaces the one roll you
# already legally made, spends no extra die and leaves the chain the same length. (Side
# effect, and a good one: Ricochet is a soft counter to Flux too. Flagged rather than
# assumed - if it should instead be locked out under Flux, drop the parameter below.)
func _flux_blocks_roll(is_ricochet_reroll: bool) -> bool:
    if is_ricochet_reroll:
        return false
    if Global.roll_history.is_empty():
        return false
    if Global.last_rolled_type != dice_type:
        return false
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if enemy.status_handler._has_status("flux"):
            return true
    return false

func _update_power_float() -> void:
    if current_power.material:
        current_power.material.set_shader_parameter("float_intensity", 0.0 if Global.roll_value == 0 else 1.0)
        var crackle_charge := smoothstep(0.0, AURA_CHARGE_FULL_AT_POWER, float(Global.roll_value))
        current_power.material.set_shader_parameter("crackle_charge", crackle_charge)

func roll_dice():
    if _roll_in_progress:
        return
    var can_roll = false
    var is_ricochet_reroll: bool = Global.ricochet_reroll_active
    dice_type = Global.dice_type
    if _flux_blocks_roll(is_ricochet_reroll):
        release_die_coil()
        play_error_sound()
        return
    # Check if we can roll this type
    match dice_type:
        "blue":
            can_roll = Global.blue_dice_current_amount > 0
        "red":
            if Global.red_dice_current_amount > 0:
                if charged_card_texture.texture != null:
                    can_roll = true
                    Global.playing_red_card = true
                elif Global.socketless_red:
                    # Socketless Red blessing: an empty socket is legal, and the roll becomes
                    # board damage instead of a card play (see _fire_socketless_red).
                    # playing_red_card stays FALSE - nothing is being played, and the flag
                    # gates Berserker's socketed-card boost.
                    can_roll = true
                else:
                    print("Trying to roll red before selecting a card")
                    play_error_sound()
            else:
                can_roll = false
        "evil":
            can_roll = Global.evil_dice_current_amount > 0
        "giant":
            can_roll = Global.giant_dice_current_amount > 0
        "magma":
            can_roll = Global.magma_dice_current_amount > 0
        "even":
            can_roll = Global.even_dice_current_amount > 0
        "odd":
            can_roll = Global.odd_dice_current_amount > 0
        "green":
            can_roll = Global.green_dice_current_amount > 0
        "mech":
            can_roll = Global.mech_dice_current_amount > 0

    # A reroll bypasses the stock check entirely: it consumes no die, so rerolling the result
    # of your LAST Ricochet die (count now 0) has to stay legal - otherwise the reroll silently
    # stops working exactly when the die is scarcest.
    if is_ricochet_reroll:
        can_roll = true

    if not can_roll:
        print("no more " + dice_type + " dice")
        release_die_coil()
        play_error_sound()
        return

    _roll_in_progress = true

    # Snapshot the Power state this roll is about to modify, so a Ricochet reroll can put back
    # exactly what the discarded result changed. Fresh rolls only - a reroll has already
    # restored to this same state, and re-capturing would overwrite the original with itself.
    # Taken here, before _apply_roll_result banks anything and before next_roll_modifier is
    # consumed, so the captured modifier is the un-spent one.
    if _type_can_reroll(dice_type) and not is_ricochet_reroll:
        _ricochet_snapshot = {
            "roll_value": Global.roll_value,
            "power_generated_this_turn": Global.power_generated_this_turn,
            "roll_history": Global.roll_history.duplicate(),
            "next_roll_modifier": Global.next_roll_modifier,
            "power_tier_active": _power_tier_active,
        }

    play_dice_roll_sound()
    Global.fight_dice_rolled+=1
    Global.dice_amount_rolled_this_turn+=1
    AchievementManager.report_dice_rolled_this_turn(Global.dice_amount_rolled_this_turn)
    # Setup dice faces and values (unified for both modes)
    var faces = []
    var values = []

    match dice_type:
        "evil":
            values = [0, 6, 6, 6]
            faces = evil_faces
        "giant":
            values = [1,2,3,4,5,6,7,8,9,10,11,12]
            faces = giant_faces
        "magma":
            values = [1,2,3,4,5,6]
            faces = magma_faces
        "even":
            values = [2,4,6,8]
            faces = even_faces
        "odd":
            values = [1,3,5,7]
            faces = odd_faces
        "green":
            values = [1,2, 3]
            faces = green_faces
        "mech":
            values = [1,2, 3, 4, 5, 6]
            faces = mech_faces
        _:
            values = [1,2,3,4,5,6]
            faces = [
                load("res://assets/images/" + dice_type + "1.png"),
                load("res://assets/images/" + dice_type + "2.png"),
                load("res://assets/images/" + dice_type + "3.png"),
                load("res://assets/images/" + dice_type + "4.png"),
                load("res://assets/images/" + dice_type + "5.png"),
                load("res://assets/images/" + dice_type + "6.png")
            ]

    # Dice infusions that change the value/face set (Repented -> [6,6,6], Bulky -> [7..12]).
    # Rebuild faces to stay index-aligned with the overriding values, keyed by the same
    # "<type><value>.png" convention every die uses. Kept in sync with the Scout preview
    # (battle.gd applies the same override to its dice_faces list).
    var override_values := DiceInfusions.roll_values_override(dice_type)
    if not override_values.is_empty():
        values = override_values
        faces = []
        for v: int in override_values:
            faces.append(load("res://assets/images/%s%d.png" % [dice_type, v]))

    # Fight-scoped face edits from cards (Red trim, Counterfeit). Applied AFTER the infusion
    # override because the card computed its list from the effective faces at play time -
    # re-deriving here would undo that. Same "<type><value>.png" convention.
    if Global.face_overrides.has(dice_type):
        # Explicitly typed: a Dictionary subscript returns Variant, and assigning Variant into
        # `values` degrades what the compiler statically knows about it from Array to Variant -
        # which breaks the `var forced_index := values.find(...)` inference further down and
        # makes the WHOLE FILE fail to parse. Typing it here keeps `values` an Array.
        var card_faces: Array = Global.face_overrides[dice_type]
        values = card_faces
        faces = []
        for v: int in values:
            faces.append(load("res://assets/images/%s%d.png" % [dice_type, v]))

    # Determine the roll result index
    var roll_index = randi() % values.size()
    Events.check_unlucky_status.emit()
    Events.check_lucky_status.emit()

    # Marked Die relic (id `marked_deck`): the first Red roll of a fight lands on its best
    # face. Skipped when a
    # guarantee is already pending (Scout/Lucky/Focus) so the relic can never overwrite a
    # face the player deliberately chose - and it stays armed for the next Red roll instead
    # of being silently burned. values.max() rather than a hardcoded 6 so a future Red
    # infusion that edits the face set is respected for free.
    if Global.marked_deck_armed and dice_type == "red" and Global.next_guaranteed_roll == -1:
        Global.marked_deck_armed = false
        var best_face: int = values.max()
        roll_index = values.find(best_face)

    # Handle guaranteed rolls. Sentinel is -1, NOT 0 - the Evil dice's crack face IS 0, a
    # legal guaranteed value (see Global.next_guaranteed_roll's declaration for the bug this
    # used to cause: scouting/forcing the crack face silently rolled normally instead).
    if Global.next_guaranteed_roll != -1:
        var target_value = Global.next_guaranteed_roll
        var found_index = values.find(target_value)

        if found_index == -1:
            push_error("Guaranteed roll value %s is not in dice values: %s" %
                    [str(target_value), str(values)])
            found_index = randi() % values.size()
        roll_index = found_index

        Global.next_guaranteed_roll = -1
        next_roll_panel.hide()
    
    # Handle tutorial forced rolls - pops the front of the queue so a multi-roll turn
    # (e.g. two forced Blue rolls in a row) consumes one value per roll_dice() call.
    if not Global.tutorial_forced_rolls.is_empty():
        var target_value: int = Global.tutorial_forced_rolls.pop_front()
        var forced_index := values.find(target_value)

        if forced_index == -1:
            push_error("Tutorial forced roll value %s is not in dice values: %s" %
                    [str(target_value), str(values)])
            forced_index = randi() % values.size()
        roll_index = forced_index

    # --- Testing mode: skip animation ---
    if Global.testing_mode:
        _apply_roll_result(roll_index, values, faces)
        return

# --- Normal roll with animation: wind-up squash -> hop with tumble -> slam on the result ---
    # Kill any leftover motion (previous max-roll shake, previous hop) and snap the die back
    # to its true rest transform BEFORE reading it, so a fast re-roll can't bake a mid-shake
    # offset in as the new resting spot.
    for stale in [_roll_anim_tween, _roll_flip_tween, _roll_aux_tween, _dice_shake_tween]:
        if stale and stale.is_valid():
            stale.kill()
    # One-shot flag from the previous roll's builder - if that roll got interrupted
    # before landing, a stale true here would silently eat THIS roll's landing rattle.
    _suppress_land_shake = false
    _smear_spawned = 0
    if _die_coil_tween and _die_coil_tween.is_valid():
        _die_coil_tween.kill()
    if _dice_display_rest_captured:
        dice_display.position = _dice_display_rest_position
    else:
        _dice_display_rest_position = dice_display.position
        _aura_rest_position = aura.position
        _emanation_rest_position = emanation.position
        _panel_rest_position = (dice_display.get_parent() as Control).position
        _roll_button_rest_position = ($Button as Control).position
        _dice_display_rest_captured = true
    dice_display.rotation = 0.0
    # Center pivot so the spin (and every scale punch) rotates/grows around the die's
    # middle - the TextureRect default is top-left, which reads as the die swinging on a hinge.
    dice_display.pivot_offset = dice_display.size / 2.0

    var tween = create_tween()
    _roll_anim_tween = tween
    var start_position := _dice_display_rest_position
    # The result is already decided (roll_index above), so the flight can be flavored by
    # it: max rolls toss bigger, and the landing dust scales with the value (see
    # _on_roll_landed). Explicit bool, not `:=` - values is an untyped Array so .max() is
    # Variant and the analyzer refuses to infer through the comparison.
    var roll_val_ahead: int = values[roll_index]
    var is_max_ahead: bool = roll_val_ahead == values.max()
    # Every preset ends by handing off to the same landing beat, so the celebration,
    # orbs, hit-stop and dust stay identical no matter which flight played.
    var land := _on_roll_landed.bind(roll_index, values, faces)

    # Rare surprise flight (Julien, 2026-08-18: "only on big rolls & big powers, rare enough
    # like 2%. Spinning is okay cause it'll be rare"). The four non-default presets already
    # exist and all hand off to the same landing beat, so this only picks a different flight
    # - nothing about the result, the celebration or the face swap changes. The vertigo
    # objection that killed the rotating styles as a DEFAULT doesn't apply at this rarity:
    # roughly once every few fights, never twice in the same fight.
    var flight_style := roll_style
    var top_face_ahead: int = values.max()
    if _surprise_roll_allowed(roll_val_ahead, is_max_ahead, top_face_ahead):
        _surprise_rolls_this_fight += 1
        flight_style = SURPRISE_ROLL_STYLES[randi() % SURPRISE_ROLL_STYLES.size()]

    match flight_style:
        RollStyle.TOSS:
            _build_roll_toss(tween, faces, start_position, is_max_ahead, land)
        RollStyle.SPIN:
            _build_roll_spin(tween, faces, is_max_ahead, land)
        RollStyle.DROP:
            _build_roll_drop(tween, faces, start_position, is_max_ahead, land)
        RollStyle.HOP:
            _build_roll_hop(tween, faces, start_position, roll_val_ahead, is_max_ahead, land)
        _:
            _build_roll_calm(tween, faces, start_position, roll_val_ahead,
                    float(roll_val_ahead) / maxf(1.0, float(values.max())), is_max_ahead, land)


# CALM: the hop with the tumble taken out. Same leap, dust, landing squash and hit-stop
# as HOP, but the die never rotates - it stays upright the whole way and swaps faces
# slowly, so a turn full of rolls doesn't spin anything in the centre of the screen.
# Timing is value-aware: high rolls hang at the apex, max rolls hold-then-SMASH.
# Gate for the rare surprise flight. Deliberately reads the roll that is ABOUT to land
# (already decided at this point) plus the power banked so far, so the surprise always
# decorates a moment that was going to feel good anyway - never a dud.
# top_face comes from the live `values` array rather than a face table, so dice infusions
# that change the face set (Repented 6/6/6, Bulky 7-12) are handled for free.
# Magma's AoE had no visual at all - just damage numbers appearing on every enemy at once,
# which read as "something happened somewhere". The burn is placed AT EACH BODY rather than
# as one screen-crossing wave: contained beats at the target are what worked for the block
# ward, and a wave that sweeps the whole screen is the direction already rejected on the
# charge effect. A small per-enemy stagger turns a 4-body wipe into bam-bam-bam.
const MAGMA_BURN_STAGGER := 0.05
const MAGMA_EMBERS := 7


func _spawn_magma_burn(enemies: Array) -> void:
    var accent := DicePalette.accent("magma")
    for i in enemies.size():
        var enemy = enemies[i]
        if not is_instance_valid(enemy):
            continue
        var parent: Node = enemy.get_parent()
        if parent == null:
            continue
        # Body centre, not the enemy root: the root sits far left of its own art.
        var centre: Vector2 = Card.thrown_impact_pos(enemy)
        var delay := MAGMA_BURN_STAGGER * float(i)

        var bloom := Sprite2D.new()
        bloom.texture = DicePalette.glow_texture()
        bloom.material = DicePalette.additive_material()
        bloom.z_index = 8
        bloom.modulate = Color(accent.r, accent.g, accent.b, 0.0)
        parent.add_child(bloom)
        bloom.global_position = centre
        bloom.scale = Vector2.ONE * (90.0 / float(bloom.texture.get_width()))

        var bt := bloom.create_tween()
        bt.tween_interval(delay)
        bt.set_parallel(true)
        bt.tween_property(bloom, "scale", Vector2.ONE * (215.0 / float(bloom.texture.get_width())), 0.30)             .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        # Alpha on its own leg so the peak is a flash, not a held wash (additive trap).
        var at := bloom.create_tween()
        at.tween_interval(delay)
        at.tween_property(bloom, "modulate:a", 2.1, 0.06)             .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        at.tween_property(bloom, "modulate:a", 0.0, 0.26)             .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        at.tween_callback(bloom.queue_free)

        # Embers rising off the body - the mass that sells "it is burning" after the flash.
        for e in MAGMA_EMBERS:
            var ember := Sprite2D.new()
            ember.texture = DicePalette.glow_texture()
            ember.material = DicePalette.additive_material()
            ember.z_index = 8
            var px := randf_range(10.0, 20.0)
            ember.scale = Vector2.ONE * (px / float(ember.texture.get_width()))
            ember.modulate = Color(accent.r, accent.g, accent.b, 0.0)
            parent.add_child(ember)
            var from := centre + Vector2(randf_range(-42.0, 42.0), randf_range(-6.0, 26.0))
            ember.global_position = from
            var rise := randf_range(46.0, 92.0)
            var life := randf_range(0.34, 0.58)
            var et := ember.create_tween()
            et.tween_interval(delay + randf_range(0.0, 0.10))
            et.set_parallel(true)
            et.tween_property(ember, "global_position",
                    from + Vector2(randf_range(-14.0, 14.0), -rise), life)                 .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
            et.tween_property(ember, "modulate:a", randf_range(1.3, 1.9), life * 0.3)
            var ef := ember.create_tween()
            ef.tween_interval(delay + life * 0.45)
            ef.tween_property(ember, "modulate:a", 0.0, life * 0.55)                 .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
            ef.tween_callback(ember.queue_free)


func _surprise_roll_allowed(roll_val: int, is_max: bool, top_face: int) -> bool:
    if _surprise_rolls_this_fight >= SURPRISE_ROLL_MAX_PER_FIGHT:
        return false
    if Global.tutorial_on:
        return false  # the tutorial scripts exact rolls; never surprise a first-time player
    var val_frac := float(roll_val) / float(maxi(top_face, 1))
    var big_enough := is_max or val_frac >= SURPRISE_ROLL_MIN_VAL_FRAC \
            or Global.roll_value >= SURPRISE_ROLL_MIN_POWER
    if not big_enough:
        return false
    return randf() < SURPRISE_ROLL_CHANCE


func _build_roll_calm(tween: Tween, faces: Array, start_position: Vector2,
        roll_val: int, val_frac: float, is_max: bool, land: Callable) -> void:
    var hop_height := CALM_HOP_HEIGHT \
            * randf_range(1.0 - ROLL_HOP_HEIGHT_JITTER, 1.0 + ROLL_HOP_HEIGHT_JITTER)
    # Hop height scales with the value: a rolled 1-2 does a small unenthusiastic hop
    # (~55-65% height), a big roll leaps. Extends the value ladder into the FLIGHT -
    # before this, only the landing scaled and small rolls hopped like winners
    # (Julien, 2026-08: "1s and 2s hop a bit too much").
    hop_height *= lerpf(0.55, 1.0, val_frac)
    if is_max:
        hop_height *= ROLL_MAX_HOP_BONUS
    var arc_x := randf_range(-CALM_ARC_X, CALM_ARC_X)
    # One-way rock, not a turn: leans out on the rise and returns upright on the fall.
    # At CALM_TILT = 0.0 these are no-ops and the die is perfectly level throughout.
    var tilt := CALM_TILT * (1.0 if arc_x >= 0.0 else -1.0)
    var do_double_bounce: bool = randf() < ROLL_DOUBLE_BOUNCE_CHANCE \
            and not is_max and roll_val > 1
    # Per-roll timing spread + apex hang by value: nothing on low rolls, a blink on high
    # ones, a real held beat on max. The fall after a max hang is faster and harder
    # (cubic ease-in) - the hang loads the smash.
    var rise_time := CALM_RISE_TIME * randf_range(1.0 - CALM_TIME_JITTER, 1.0 + CALM_TIME_JITTER)
    var fall_time := CALM_FALL_TIME * randf_range(1.0 - CALM_TIME_JITTER, 1.0 + CALM_TIME_JITTER)
    var hang_time := 0.0
    if is_max:
        hang_time = CALM_MAX_HANG * randf_range(0.85, 1.2)
        fall_time = CALM_MAX_FALL_TIME
    else:
        # Bigger rolls fall faster - arrival speed is most of perceived impact, and a
        # 5 dropping at the same lazy rate as a 1 is why mid rolls read as weightless.
        fall_time *= 1.0 - LAND_FALL_SPEEDUP * val_frac
        if val_frac >= CALM_HIGH_HANG_FRAC:
            hang_time = CALM_HIGH_HANG * randf_range(0.7, 1.3)

    # Anticipation squash - the only "wind-up" cue left now that there's no spin to
    # telegraph. Skipped when the ROLL button already coiled the die on button_down (the
    # held press IS the wind-up); the release step below then launches straight from the
    # held compression, which is the whole button->die weld.
    if not _die_coiled:
        tween.tween_property(dice_display, "scale", Vector2(1.12, 0.82), 0.05) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _die_coiled = false
    tween.tween_property(dice_display, "scale", Vector2(1.0, 1.0), 0.05) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

    var apex := start_position + Vector2(arc_x, -hop_height)
    tween.tween_property(dice_display, "position", apex, rise_time) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(dice_display, "rotation", tilt, rise_time) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    if hang_time > 0.0:
        if is_max:
            # Pre-crush riser slot: fires as the max-roll hang begins, leading into the
            # landing smash. Silent unless a riser candidate is selected (F10 audition).
            tween.tween_callback(_play_land_riser)
            # The held beat before the smash, with a tiny shiver - the die vibrating
            # with potential rather than parking mid-air.
            var shiver_steps := 3
            for i in shiver_steps:
                var jit := Vector2(randf_range(-2.5, 2.5), randf_range(-1.5, 1.5))
                tween.tween_property(dice_display, "position", apex + jit,
                        hang_time / shiver_steps)
        else:
            tween.tween_interval(hang_time)

    tween.tween_property(dice_display, "position", start_position, fall_time) \
        .set_trans(Tween.TRANS_CUBIC if is_max else Tween.TRANS_QUAD) \
        .set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(dice_display, "rotation", 0.0, fall_time) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    if is_max:
        # Motion smear on the smash fall: 3 ghost afterimages trail the die down. Rides
        # the fall step in parallel so it stays synced no matter how the earlier timing
        # varied (coil skip, hang jitter).
        tween.parallel().tween_method(_smear_step, 0.0, 1.0, fall_time)
    if do_double_bounce:
        _suppress_land_shake = true
    tween.tween_callback(land)

    if do_double_bounce:
        tween.tween_interval(0.05)
        tween.tween_property(dice_display, "position",
            start_position + Vector2(arc_x * -0.3, -hop_height * ROLL_DOUBLE_BOUNCE_HEIGHT),
            0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(dice_display, "position", start_position, 0.08) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

    _start_face_flips(faces, CALM_FLIP_DELAYS)


# HOP: leap off the plinth, tumble, slam back down. Playful and physical; the per-roll
# height/arc/spin-rhythm jitter and the optional rebound keep repeat rolls from tracing
# an identical path.
func _build_roll_hop(tween: Tween, faces: Array, start_position: Vector2,
        roll_val: int, is_max: bool, land: Callable) -> void:
    var spin_sign := 1.0 if randf() < 0.5 else -1.0
    var total_spin := spin_sign * TAU * ROLL_SPIN_TURNS
    var hop_height := ROLL_HOP_HEIGHT \
            * randf_range(1.0 - ROLL_HOP_HEIGHT_JITTER, 1.0 + ROLL_HOP_HEIGHT_JITTER)
    if is_max:
        hop_height *= ROLL_MAX_HOP_BONUS
    var arc_x := randf_range(-ROLL_HOP_ARC_X, ROLL_HOP_ARC_X)
    var rise_fraction := randf_range(ROLL_SPIN_RISE_FRACTION_MIN, ROLL_SPIN_RISE_FRACTION_MAX)
    # Never on a max roll (the hit-stop owns that landing) or a rolled 1 (a dud shouldn't
    # rebound with energy).
    var do_double_bounce: bool = randf() < ROLL_DOUBLE_BOUNCE_CHANCE \
            and not is_max and roll_val > 1

    # Anticipation squash: a quick compress right before the toss, so the whole roll
    # has a wind-up beat instead of starting cold straight into the hop.
    tween.tween_property(dice_display, "scale", Vector2(1.12, 0.82), 0.05) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(dice_display, "scale", Vector2(1.0, 1.0), 0.05) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

    # Rise and fall are separate steps so the spin can be split across them (rise_fraction
    # up, the rest down) - the tumble decelerates into the landing rather than rotating at
    # a constant robotic rate.
    tween.tween_property(dice_display, "position",
        start_position + Vector2(arc_x, -hop_height), ROLL_HOP_RISE_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(dice_display, "rotation",
        total_spin * rise_fraction, ROLL_HOP_RISE_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(dice_display, "position", start_position, ROLL_HOP_FALL_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(dice_display, "rotation", total_spin, ROLL_HOP_FALL_TIME) \
        .set_trans(Tween.TRANS_LINEAR)
    if do_double_bounce:
        _suppress_land_shake = true
    tween.tween_callback(land)

    # Optional rebound with a counter-drift, so the die settles back opposite its toss
    # direction. The landing squash's elastic settle runs in parallel on scale, which
    # reads as the die wobbling through the bounce.
    if do_double_bounce:
        tween.tween_interval(0.05)
        tween.tween_property(dice_display, "position",
            start_position + Vector2(arc_x * -0.3, -hop_height * ROLL_DOUBLE_BOUNCE_HEIGHT),
            0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(dice_display, "position", start_position, 0.08) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

    _start_face_flips(faces, ROLL_FLIP_DELAYS)


# TOSS: thrown up toward the camera. The die swells until it dominates the panel, hangs
# for a beat at peak (the "read the face" moment), then snaps back to rest on the result.
# Biggest frame presence of the four - the die carries the shot on its own, which is what
# a muted thumbnail needs.
func _build_roll_toss(tween: Tween, faces: Array, start_position: Vector2,
        is_max: bool, land: Callable) -> void:
    var spin_sign := 1.0 if randf() < 0.5 else -1.0
    var total_spin := spin_sign * TAU * TOSS_SPIN_TURNS
    var peak := TOSS_PEAK_SCALE * randf_range(0.94, 1.06)
    if is_max:
        peak *= TOSS_MAX_BONUS
    var drift := randf_range(-10.0, 10.0)

    # Grip-and-throw wind-up: squeeze narrow/tall (gathered in the hand) before release -
    # deliberately the opposite axis from HOP's flat squash so the two read differently
    # from the very first frame.
    tween.tween_property(dice_display, "scale", Vector2(0.86, 1.14), 0.06) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    tween.tween_property(dice_display, "scale", Vector2(peak, peak), TOSS_RISE_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(dice_display, "position",
        start_position + Vector2(drift, -TOSS_LIFT), TOSS_RISE_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(dice_display, "rotation",
        total_spin * 0.7, TOSS_RISE_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    tween.tween_interval(TOSS_HANG_TIME)

    # Snap back to rest: the collapse IS the impact.
    tween.tween_property(dice_display, "scale", Vector2.ONE, TOSS_FALL_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(dice_display, "position", start_position, TOSS_FALL_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(dice_display, "rotation", total_spin, TOSS_FALL_TIME) \
        .set_trans(Tween.TRANS_LINEAR)
    tween.tween_callback(land)

    _start_face_flips(faces, TOSS_FLIP_DELAYS)


# SPIN: never leaves the plinth. Spins like a roulette reel, decelerating, squeezed narrow
# while fast (the "on edge" read, no new art needed), then wobbles to a stop on the result.
# Most compact of the four - the die stays exactly where the eye already is, so nothing in
# the HUD is ever occluded.
func _build_roll_spin(tween: Tween, faces: Array, is_max: bool, land: Callable) -> void:
    var spin_sign := 1.0 if randf() < 0.5 else -1.0
    var turns := SPIN_TURNS * randf_range(0.85, 1.15)
    if is_max:
        turns += 0.5
    var total_spin := spin_sign * TAU * turns

    # Counter-rotation wind-up: pull back against the spin before the reel releases.
    tween.tween_property(dice_display, "rotation", -spin_sign * 0.22, SPIN_WINDUP_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(dice_display, "rotation", total_spin, SPIN_TIME) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_callback(land)

    # Wobble to a stop, like a spinning top toppling into place. Runs after the landing
    # callback, which has already snapped rotation to 0 - so these tween from upright.
    tween.tween_property(dice_display, "rotation",
        spin_sign * SPIN_WOBBLE_ANGLE, SPIN_WOBBLE_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(dice_display, "rotation",
        -spin_sign * SPIN_WOBBLE_ANGLE * 0.4, SPIN_WOBBLE_TIME * 0.8) \
        .set_trans(Tween.TRANS_SINE)
    tween.tween_property(dice_display, "rotation", 0.0, SPIN_WOBBLE_TIME * 0.6) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    # The squeeze rides its own timeline (a sequential squeeze-then-release can't be
    # expressed as one parallel() step against the spin). Leading interval keeps it in
    # sync with the wind-up, and it lands back at ONE exactly when the spin ends.
    if _roll_aux_tween and _roll_aux_tween.is_valid():
        _roll_aux_tween.kill()
    _roll_aux_tween = create_tween()
    _roll_aux_tween.tween_interval(SPIN_WINDUP_TIME)
    _roll_aux_tween.tween_property(dice_display, "scale",
        Vector2(SPIN_SQUEEZE, 1.08), SPIN_TIME * 0.3) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _roll_aux_tween.tween_property(dice_display, "scale", Vector2.ONE, SPIN_TIME * 0.7) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

    _start_face_flips(faces, SPIN_FLIP_DELAYS)


# DROP: yanked up out of frame and dropped hard, then bounces twice to rest. Heaviest of
# the four, and the only one whose character lives in the SETTLE rather than the impact.
func _build_roll_drop(tween: Tween, faces: Array, start_position: Vector2,
        is_max: bool, land: Callable) -> void:
    var spin_sign := 1.0 if randf() < 0.5 else -1.0
    var total_spin := spin_sign * TAU * DROP_SPIN_TURNS
    var height := DROP_HEIGHT * randf_range(0.9, 1.1)
    if is_max:
        height *= 1.12
    var drift := randf_range(-12.0, 12.0)

    # Yank up fast (snatched off the plinth), then a hard accelerating fall.
    tween.tween_property(dice_display, "position",
        start_position + Vector2(drift, -height), DROP_LIFT_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(dice_display, "rotation",
        total_spin * 0.55, DROP_LIFT_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(dice_display, "position", start_position, DROP_FALL_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(dice_display, "rotation", total_spin, DROP_FALL_TIME) \
        .set_trans(Tween.TRANS_LINEAR)
    tween.tween_callback(land)

    # Decaying bounces. These run AFTER the landing callback, so the roll is already
    # resolved and _roll_in_progress is clear - the settle never blocks the next roll.
    for bounce_frac: float in DROP_BOUNCES:
        var bounce_h := height * bounce_frac
        var bounce_t := DROP_FALL_TIME * (0.55 + bounce_frac)
        tween.tween_property(dice_display, "position",
            start_position + Vector2(drift * bounce_frac * 0.5, -bounce_h), bounce_t) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(dice_display, "position", start_position, bounce_t * 0.85) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

    _start_face_flips(faces, DROP_FLIP_DELAYS)


# Face swaps ride their own tween: they're time-based, not step-based, so welding them
# into the flight's position steps would stall the motion at each swap. Never shows the
# same face twice in a row. The landing face itself is set by _apply_roll_result.
func _start_face_flips(faces: Array, delays: Array) -> void:
    if _roll_flip_tween and _roll_flip_tween.is_valid():
        _roll_flip_tween.kill()
    _roll_flip_tween = create_tween()
    # One-element array, not a bare int: GDScript lambdas capture locals by VALUE, so an int
    # written inside the callback would never persist to the next swap - the dedup would
    # silently never fire. Arrays are captured by reference.
    var last_anim_index := [-1]
    for flip_delay: float in delays:
        _roll_flip_tween.tween_interval(flip_delay)
        _roll_flip_tween.tween_callback(func():
            var anim_index := randi() % faces.size()
            if faces.size() > 1 and anim_index == last_anim_index[0]:
                anim_index = (anim_index + 1) % faces.size()
            last_anim_index[0] = anim_index
            dice_display.texture = faces[anim_index]
        )


# The shared landing beat, identical across every roll style: resolve the result, then
# orbs + dust + squash + aura pulse + emanation flare + hit-stop, and the max-roll
# celebration on top. Whatever the flight looked like, the payoff reads the same.
func _on_roll_landed(roll_index: int, values: Array, faces: Array) -> void:
    # ⚠️ KILL THE FACE-SHUFFLE FIRST. The flips run on their OWN tween (so they don't stall
    # the flight), which means they are NOT ordered against this callback: if the flight
    # finishes first, a still-pending flip fires afterwards and overwrites the settled
    # result with a random face - the die showed a 3 while Power correctly counted a 1
    # (Julien, 2026-08-07, in the tutorial where the rolls are forced and the mismatch is
    # obvious). It became reachable when the ROLL-button coil started skipping the 0.05s
    # wind-up step, pulling the flight's end back under the 0.29s flip schedule on
    # low/mid rolls (which have no apex hang to pad them). Killing here makes the ordering
    # structural instead of a timing coincidence - the settled face can no longer be
    # overwritten no matter how the flight timing drifts in future tuning.
    if _roll_flip_tween and _roll_flip_tween.is_valid():
        _roll_flip_tween.kill()
    # Exact-snap the flight transform before anything else reads the die: the flight
    # tweens target these values anyway, but a killed/interrupted one must not leave a
    # residual rotation or squeeze baked under the punch tweens below.
    dice_display.rotation = 0.0
    dice_display.position = _dice_display_rest_position
    dice_display.scale = Vector2.ONE
    _apply_roll_result(roll_index, values, faces)
    var roll_val = values[roll_index]
    var is_max_roll = roll_val == values.max()

    var val_frac := float(roll_val) / maxf(1.0, float(values.max()))

    _spawn_power_orbs(roll_val, dice_type, is_max_roll)
    # Dust scales with the result: a 1 lands with a plop, a max roll kicks up a cloud -
    # the landing communicates the value the same way the celebration ladder does.
    var dust_mult := 0.7 + 0.8 * val_frac
    if is_max_roll:
        dust_mult *= 1.25
    _spawn_roll_land_dust(dust_mult)

    # Land thud: pitch climbs with chain depth (Global.roll_history already includes this
    # roll - _apply_roll_result appended it above), volume with the roll's value. Priority
    # 0 (not -1): the landing is the beat of the whole animation, orb plinks get stolen
    # before it does.
    var chain_depth := Global.roll_history.size()
    # Overcharge raises the ladder's ceiling (see OVERCHARGE_THUD_PITCH_CAP_STEP). It only
    # binds on chains long enough to have hit the cap already, which is exactly the runaway
    # turn it is meant to describe - a normal chain never reaches the extra steps.
    var pitch_cap := LAND_THUD_CHAIN_PITCH_CAP \
            + _overcharge_tier * OVERCHARGE_THUD_PITCH_CAP_STEP
    var thud_pitch := LAND_THUD_BASE_PITCH \
            + LAND_THUD_CHAIN_PITCH_STEP * clampi(chain_depth - 1, 0, pitch_cap)
    SFXPlayer.play(LAND_THUD_SOUND, false, thud_pitch, lerpf(-8.0, -2.0, val_frac))
    if is_max_roll:
        # The heavier smash rides on top of (not instead of) the thud, so the max landing
        # keeps its place at the top of the same ladder rather than sounding unrelated.
        SFXPlayer.play(Global.high_roll_sound(), false, randf_range(0.92, 1.0), -2.0)

    # Landing rattle, every roll, value^2 so the low end stays quiet (a d6 1-3 computes
    # under LAND_SHAKE_MIN and doesn't shake at all). Skipped when the builder's double
    # bounce owns the settle - two tweens fighting over position reads as jitter, not
    # weight. This replaces the old max-only _shake_dice_display() call.
    # ^1.5, not ^2: the old quadratic falloff kept mid rolls nearly still, which was a
    # big part of "only the 6s feel good". A d6 3 now trembles, a 5 genuinely rattles;
    # 1-2 stay silent (the ladder needs its quiet bottom).
    var shake_strength := LAND_SHAKE_STRENGTH * pow(val_frac, 1.5)
    if is_max_roll:
        shake_strength += 2.0
    if shake_strength >= LAND_SHAKE_MIN and not _suppress_land_shake:
        _shake_dice_display(shake_strength)
    _suppress_land_shake = false

    # Value-fraction curve (not raw roll value): a green d3's 3 is a big roll FOR THAT
    # DIE and squashes like one; raw-value scaling made small dice permanently limp.
    var punch_scale = 1.10 + 0.30 * val_frac
    if is_max_roll:
        punch_scale += 0.16
    punch_scale = clampf(punch_scale, 1.10, 1.56)
    var is_dud: bool = roll_val == values.min() and not is_max_roll
    var impact = create_tween()
    if is_dud:
        # The dud's sad settle: a real deflate instead of an impact squash - the die
        # lands, visibly sags, and slowly breathes back. Paired with a brief DIM (the
        # die's light going out for a beat - brightness reads at a glance where a few
        # px of scale never did), no shake, no flash and the quiet thud, the min face
        # reads as a sigh.
        impact.tween_property(dice_display, "scale", Vector2(1.03, 0.95), 0.06) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        impact.tween_property(dice_display, "scale", Vector2(0.93, 0.90), 0.12) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        impact.tween_property(dice_display, "scale", Vector2(1.0, 1.0), 0.30) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        # Absolute-target dim (0.78 gray -> WHITE), same anti-ratchet rule as the
        # flashes: never restore from a live modulate read. The dud path skips both
        # flash tweens, so nothing else owns modulate during this.
        var dim := create_tween()
        dim.tween_property(dice_display, "modulate", Color(0.78, 0.78, 0.82, 1.0), 0.08) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        dim.tween_property(dice_display, "modulate", Color.WHITE, 0.38) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    else:
        # Landing squash: wider than tall on the impact frame (the die hits the plinth),
        # then an elastic settle back to square. Reads as weight, where a uniform
        # grow-punch reads as inflation. The vertical crush deepens with value too.
        impact.tween_property(dice_display, "scale",
            Vector2(punch_scale + 0.04, 0.86 - 0.08 * val_frac), 0.05) \
            .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        impact.tween_property(dice_display, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

    # Plinth dip on big landings - the whole panel (die, aura, ROLL button) absorbs the
    # hit and springs back: "the table felt it". The drop is INSTANT, not tweened: the
    # hit-stop below freezes time in this same callback, so a tweened descent was frozen
    # at its undipped first frame and the whole effect played invisibly after the freeze
    # (why Julien never saw the 2px version - that, and 2px was under the perception
    # floor anyway). An instant set means the freeze HOLDS the dipped impact frame.
    # Anchored on the captured rest so rapid landings can't walk the panel downward.
    if val_frac >= 0.55 or is_max_roll:
        var panel := dice_display.get_parent() as Control
        var roll_button := $Button as Control
        if _panel_dip_tween and _panel_dip_tween.is_valid():
            _panel_dip_tween.kill()
        var dip := 9.0 if is_max_roll else 6.0
        panel.position = _panel_rest_position + Vector2(0, dip)
        roll_button.position = _roll_button_rest_position + Vector2(0, dip)
        _panel_dip_tween = create_tween()
        _panel_dip_tween.tween_property(panel, "position:y", _panel_rest_position.y, 0.22) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        _panel_dip_tween.parallel().tween_property(
                roll_button, "position:y", _roll_button_rest_position.y, 0.22) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

    # Mini impact flash on every NON-max landing, brightness scaled by value - the "hit"
    # frame ordinary rolls never had. Warm-biased (blue channel dampened) to lean gold
    # like the house style. Max rolls skip it: max_flash below owns their modulate, and
    # both tweens target ABSOLUTE colors ending at WHITE, so neither can ratchet the way
    # live-read restores do (documented power-color trap).
    if not is_max_roll and not is_dud:
        var flash_b := LAND_FLASH_BASE + LAND_FLASH_VALUE_BONUS * val_frac
        var land_flash := create_tween()
        land_flash.tween_property(dice_display, "modulate",
            Color(1.0 + flash_b, 1.0 + flash_b, 1.0 + flash_b * 0.7, 1.0), 0.04) \
            .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        land_flash.tween_property(dice_display, "modulate", Color.WHITE, 0.16) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

    # Subtle transient pulse on the per-dice-type aura behind the die, on every landing
    # (not just max rolls) - reuses the existing aura node/shader instead of new art,
    # scaled by roll value so a bigger roll gives a slightly bigger pulse. Always settles
    # back to AURA_SCALE_REST (not a charge-dependent size) - the "grows with power" story
    # lives entirely in _update_dice_aura_charge()'s shader parameters now, not in scale.
    # Longest wins: a charge drives this SAME aura.scale (the "charge" AnimationPlayer
    # kick, whose only track is Aura:scale), much harder and far more rarely, so starting
    # the landing's small punch on top of one already running would cut the charge beat off
    # mid-flight. These genuinely collide - a Gnome-infused Green die charges a Blue die on
    # a natural 1, i.e. on this very landing. Same "the shorter effect must not win" rule
    # the ref-counted hit-stop exists for.
    # One-directional on purpose: _apply_roll_result() above is what emits dice_charged, so
    # a roll-driven charge always starts its beat BEFORE this point and this guard sees it.
    var charge_beat_running := animation_player.is_playing() \
            and animation_player.current_animation == "charge"
    if not charge_beat_running:
        var aura_punch = AURA_SCALE_REST + 0.04 + 0.18 * val_frac
        var aura_pulse := create_tween()
        aura_pulse.tween_property(aura, "scale", Vector2(aura_punch, aura_punch), 0.07) \
            .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        aura_pulse.tween_property(aura, "scale", Vector2(AURA_SCALE_REST, AURA_SCALE_REST), 0.16) \
            .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

    # Emanation flare on the same landing beat: spike "surge" instantly, decay it out.
    # Tracked so rapid rolls restart the flare instead of stacking tweens on the param.
    if emanation.material is ShaderMaterial:
        if _emanation_surge_tween and _emanation_surge_tween.is_valid():
            _emanation_surge_tween.kill()
        emanation.material.set_shader_parameter("surge", 1.0)
        _emanation_surge_tween = create_tween()
        _emanation_surge_tween.tween_property(
            emanation.material, "shader_parameter/surge", 0.0, EMANATION_SURGE_DECAY_TIME) \
            .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

    # Landing impact: brief hit-stop so every roll lands with weight, bigger on a max-value
    # roll. Roughly doubled (was 0.02-0.07/0.09) now that hit_stop()'s time_scale default
    # is a harder freeze - the old duration was tuned for the old, softer time_scale and
    # was imperceptible either way.
    # Frac-based, not raw value: the old roll_val * 0.013 gave a d3's best roll a 0.04s
    # stop (imperceptible) while a d12's mid rolls outscored a d6's max. Every die now
    # spans the same felt range, and the mid-range stop is finally perceptible.
    var hit_stop_duration = lerpf(LAND_HIT_STOP_MIN, LAND_HIT_STOP_MAX, val_frac)
    if is_max_roll:
        hit_stop_duration = 0.22
    Shaker.hit_stop(hit_stop_duration)

    # Max-roll celebration: gold flash + particle burst + white-hot impact flare at the
    # die's base, on top of the normal landing. The burst is tinted per dice type (accent
    # pulled toward warm gold) so a max roll on magma erupts fiery, on evil violet, etc. -
    # the flash itself stays gold-white, the universal "success" beat. The flare reuses
    # the thrown-die "BAM" glow at the impact point, which is what makes the landing read
    # as a SMASH rather than a light show. (The rattle fired above, value-scaled.)
    if is_max_roll:
        var burst_material := gpu_particles_2d.process_material as ParticleProcessMaterial
        if burst_material:
            burst_material.color = DicePalette.burst(dice_type)
        gpu_particles_2d.emitting = true
        var die_rect := dice_display.get_global_rect()
        _spawn_thrown_die_flare(self,
                Vector2(die_rect.get_center().x, die_rect.end.y - 14.0),
                DicePalette.burst(dice_type), true)
        var max_flash := create_tween()
        max_flash.tween_property(dice_display, "modulate", Color(2.2, 2.0, 1.2, 1.0), 0.06) \
            .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        max_flash.tween_property(dice_display, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.22) \
            .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

# Ghost-afterimage spawner for the max fall, driven 0->1 across the fall by tween_method.
# Spawns at fixed progress thresholds (not per-frame) so the trail is 3 clean ghosts, not
# a smudge; _smear_spawned resets in roll_dice.
func _smear_step(t: float) -> void:
    const THRESHOLDS := [0.15, 0.45, 0.75]
    while _smear_spawned < THRESHOLDS.size() and t >= THRESHOLDS[_smear_spawned]:
        _smear_spawned += 1
        var ghost := TextureRect.new()
        ghost.texture = dice_display.texture
        ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        ghost.size = dice_display.size
        ghost.scale = dice_display.scale
        ghost.pivot_offset = dice_display.pivot_offset
        ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
        ghost.modulate = Color(1.0, 1.0, 1.0, 0.28)
        # Sibling of DiceDisplay with default z 0: renders under the die (z 1), so the
        # trail reads as left-behind light, never as a second die on top.
        dice_display.get_parent().add_child(ghost)
        ghost.position = dice_display.position
        var tw := ghost.create_tween()
        tw.tween_property(ghost, "modulate:a", 0.0, 0.11) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tw.tween_callback(ghost.queue_free)


# Small scale pop on the roll-history rack (the RichTextLabel node, not Global's array),
# fired when a new chain face lands. Tracked so rapid rolls restart it from rest instead
# of compounding mid-pop scales.
func _punch_roll_history() -> void:
    roll_history.pivot_offset = roll_history.size / 2.0
    if _roll_history_punch_tween and _roll_history_punch_tween.is_valid():
        _roll_history_punch_tween.kill()
        roll_history.scale = Vector2.ONE
    _roll_history_punch_tween = create_tween()
    _roll_history_punch_tween.tween_property(roll_history, "scale", Vector2(1.12, 1.12), 0.06) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    _roll_history_punch_tween.tween_property(roll_history, "scale", Vector2.ONE, 0.12) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Real visible shake (not a time_scale freeze), now on every landing with value-scaled
# strength (see _on_roll_landed). Inline rather than reusing Shaker.shake() since that's
# typed for Node2D and dice_display is a Control (TextureRect) - different CanvasItem
# branch, position still works the same way.
func _shake_dice_display(strength := 6.0) -> void:
    # Anchor on the captured rest position, not a live read: this runs right after the hop's
    # landing snap, but if anything ever reorders those, a live read would bake a mid-motion
    # offset into every shake step. Tracked in _dice_shake_tween so the next roll_dice()
    # can kill it and re-snap instead of capturing a shaken position as the new rest.
    var orig_pos := _dice_display_rest_position if _dice_display_rest_captured \
        else dice_display.position
    _dice_shake_tween = create_tween()
    for i in 6:
        var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
        _dice_shake_tween.tween_property(dice_display, "position", orig_pos + offset, 0.025)
        strength *= 0.7
    _dice_shake_tween.tween_property(dice_display, "position", orig_pos, 0.03)


# Soft dust poof at the die's base on every landing - the grounding half of the hop:
# without it the slam reads as the die stopping mid-air. Same soft-radial + additive
# recipe as the thrown-die shock puff, but squashed into a ground-hugging ellipse,
# neutral warm (dust, not magic) and low alpha so it never fights the max-roll burst
# when the two stack (additive-blend stacking lesson).
func _spawn_roll_land_dust(size_mult := 1.0) -> void:
    var puff := TextureRect.new()
    puff.texture = _get_power_orb_texture()
    puff.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    puff.stretch_mode = TextureRect.STRETCH_SCALE
    puff.size = Vector2(46.0, 46.0)
    puff.pivot_offset = puff.size / 2.0
    puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
    puff.material = _get_power_orb_material()
    # Alpha rises with the puff's size so big landings kick up denser (not just wider)
    # dust - capped under the additive-stacking ceiling.
    puff.modulate = Color(0.82, 0.74, 0.58, minf(0.55, 0.25 + 0.2 * size_mult))
    puff.scale = Vector2(0.7, 0.4)
    # Sibling of DiceDisplay (z_index 1) with default z 0: the dust renders BEHIND the die,
    # peeking out around its bottom edge - a ground puff, not a flash on top of the art.
    dice_display.get_parent().add_child(puff)
    var die_rect := dice_display.get_global_rect()
    puff.global_position = Vector2(die_rect.get_center().x, die_rect.end.y - 10.0) \
        - puff.size / 2.0
    var tw := puff.create_tween()
    tw.tween_property(puff, "scale", Vector2(2.2, 0.9) * size_mult, 0.22) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(puff, "modulate:a", 0.0, 0.22) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.tween_callback(puff.queue_free)


# Soft white radial gradient, tinted per-orb via modulate - lets every dice-type color reuse
# one shared texture instead of generating a new gradient per roll.
func _get_power_orb_texture() -> GradientTexture2D:
    if _power_orb_texture:
        return _power_orb_texture
    var gradient := Gradient.new()
    gradient.set_color(0, Color(1, 1, 1, 1))
    gradient.set_color(1, Color(1, 1, 1, 0))
    var tex := GradientTexture2D.new()
    tex.gradient = gradient
    tex.width = 32
    tex.height = 32
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    _power_orb_texture = tex
    return _power_orb_texture


# Additive blend so the orbs read as actual light over the dark dice panel (a normal-blend
# tinted sprite reads as a flat colored dot by comparison). Shared across all orbs, built once
# like the orb texture above.
var _power_orb_material: CanvasItemMaterial

func _get_power_orb_material() -> CanvasItemMaterial:
    if _power_orb_material:
        return _power_orb_material
    var mat := CanvasItemMaterial.new()
    mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    _power_orb_material = mat
    return _power_orb_material


# tween_method's first parameter is always the interpolated value (t here) - bound args are
# appended after it, so this stays a named function rather than a multi-statement inline lambda
# (see reference-video-frame-analysis / the combat-juice-pass lessons on that gotcha).
#
# wobble_freq/amp/phase add a per-orb perpendicular sine drift on top of the pure bezier curve,
# so the PATH itself squiggles instead of being a mechanically clean arc - the sin(t*PI)
# envelope is 0 at t=0 and t=1, so the wobble never moves the guaranteed launch/landing points,
# only the middle of the flight.
func _orb_bezier_step(t: float, orb: TextureRect, p0: Vector2, p1: Vector2, p2: Vector2, wobble_freq: float, wobble_amp: float, wobble_phase: float) -> void:
    var base := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
    var tangent := p1.lerp(p2, t) - p0.lerp(p1, t)
    tangent = tangent.normalized() if tangent.length_squared() > 0.0001 else Vector2.RIGHT
    var perp := Vector2(-tangent.y, tangent.x)
    var wobble := sin(t * wobble_freq * TAU + wobble_phase) * wobble_amp * sin(t * PI)
    orb.global_position = (base + perp * wobble) - orb.size / 2.0


# The "roll -> power" visual link: a few small orbs fly from the die to the Power label on
# every roll, timed to launch in the same instant as the landing hit-stop (called from the same
# tween_callback in roll_dice(), before Shaker.hit_stop() below) so they visibly pop right along
# with the freeze rather than trailing in afterward.
#
# The Power number itself already updated instantly back in _apply_roll_result (no delay on the
# actual value/text). What's chained onto the first orb's flight below is purely an ADDITIVE
# reaction (_play_power_orb_arrival_reaction) - a second, smaller "delivery" beat on top of the
# already-correct number, not a replacement for the immediate update.
func _spawn_power_orbs(roll_val: int, type: String, is_max_roll: bool) -> void:
    if roll_val <= 0:
        return  # evil dice's 0 face (and any other zero-value roll) adds nothing - no orbs, no reaction
    # Orbs erupt from UNDER the die, spread along its bottom edge - squeezed out by the
    # slam rather than radiating from the die's heart. Fires on the landing frame, so
    # the read is impact -> power (Julien, 2026-08). The bezier control point sits above
    # min(start, end) so they still arc up and over into the Power number.
    var die_rect := dice_display.get_global_rect()
    var origin := Vector2(die_rect.get_center().x, die_rect.end.y - 8.0)
    var origin_spread_x := die_rect.size.x * 0.38
    var target := current_power.get_global_rect().get_center()
    # Overbright multiply (same trick as the max-roll flash's Color(2.2, 2.0, 1.2, 1.0)) so the
    # orbs pop against the panel rather than reading as a flat/dim tint - was too shy at 1.0.
    # Max rolls get an extra punch on top, so the biggest hits read as visibly more electric.
    var brightness := POWER_ORB_MAX_ROLL_BRIGHTNESS if is_max_roll else POWER_ORB_BRIGHTNESS
    var color := DicePalette.accent(type) * brightness
    var texture := _get_power_orb_texture()
    var orb_material := _get_power_orb_material()

    var count := clampi(POWER_ORB_MIN_COUNT + roll_val / 2, POWER_ORB_MIN_COUNT, POWER_ORB_MAX_COUNT)
    if is_max_roll:
        count += POWER_ORB_MAX_ROLL_BONUS

    # Big rolls get chunkier orbs on top of the base random size, not just more of them.
    var size_bonus := lerpf(0.0, POWER_ORB_SIZE_BIG_ROLL_BONUS, clampf(float(roll_val) / 12.0, 0.0, 1.0))

    # Precompute each orb's launch delay + flight time up front (rather than inline per
    # iteration) so we can find which orb actually lands FIRST - both are now drawn
    # independently at random, so it's no longer reliably orb #0 the way it was under the
    # old indexed-stagger scheme (see _play_power_orb_arrival_reaction's call site below).
    var launch_window := POWER_ORB_LAUNCH_WINDOW_PER_ORB * count
    var launch_delays: Array[float] = []
    var flight_times: Array[float] = []
    var earliest_index := 0
    var earliest_arrival := INF
    for i in count:
        var launch_delay := randf_range(0.0, launch_window)
        var flight_time := randf_range(POWER_ORB_FLIGHT_MIN, POWER_ORB_FLIGHT_MAX)
        launch_delays.append(launch_delay)
        flight_times.append(flight_time)
        var arrival := launch_delay + flight_time
        if arrival < earliest_arrival:
            earliest_arrival = arrival
            earliest_index = i

    for i in count:
        var orb := TextureRect.new()
        orb.texture = texture
        # Texture is a fixed 32x32 source - without EXPAND_IGNORE_SIZE, TextureRect renders at
        # native resolution regardless of .size below (bit the refuel-return icons the same way).
        orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        orb.material = orb_material
        orb.modulate = color
        orb.modulate.a = 0.0
        orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        orb.z_index = 60  # above Panel/DiceDisplay, still local to this Dice control
        add_child(orb)

        var size := randf_range(POWER_ORB_SIZE_MIN, POWER_ORB_SIZE_MAX) + size_bonus
        orb.size = Vector2(size, size)
        orb.pivot_offset = orb.size / 2.0

        var start := origin + Vector2(randf_range(-origin_spread_x, origin_spread_x), randf_range(-4.0, 8.0))
        var end := target + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
        orb.global_position = start - orb.size / 2.0

        # Rough "rainbow" arc: control point sits well ABOVE the midpoint (and biased toward
        # the target's x) so the path rises, sails over, and comes back down into the Power
        # label from above - rather than the old perpendicular-random bow, which averaged out
        # to a flat, straightforward line since it bowed up or down with equal odds.
        # mid_x's ratio is randomized per orb (was a fixed 0.55) so each one bows through a
        # different point along the path instead of all fanning out from the same silhouette -
        # combined with the wider control-x jitter below, this is what breaks the "train" look.
        var mid_x := lerpf(start.x, end.x, randf_range(POWER_ORB_MID_X_MIN, POWER_ORB_MID_X_MAX))
        var apex_y := minf(start.y, end.y) - randf_range(POWER_ORB_ARC_HEIGHT_MIN, POWER_ORB_ARC_HEIGHT_MAX)
        var control := Vector2(mid_x + randf_range(-25.0, 25.0), apex_y)

        var flight_time := flight_times[i]
        var launch_delay := launch_delays[i]
        var ease_profile: Array = POWER_ORB_EASE_PROFILES[randi() % POWER_ORB_EASE_PROFILES.size()]
        var wobble_freq := randf_range(POWER_ORB_WOBBLE_FREQ_MIN, POWER_ORB_WOBBLE_FREQ_MAX)
        var wobble_amp := randf_range(POWER_ORB_WOBBLE_AMP_MIN, POWER_ORB_WOBBLE_AMP_MAX)
        var wobble_phase := randf_range(0.0, TAU)

        var tw := create_tween()
        tw.tween_interval(launch_delay)
        tw.tween_property(orb, "modulate:a", 1.0, flight_time * 0.3)
        tw.parallel().tween_method(
                _orb_bezier_step.bind(orb, start, control, end, wobble_freq, wobble_amp, wobble_phase),
                0.0, 1.0, flight_time) \
            .set_trans(ease_profile[0]).set_ease(ease_profile[1])
        # Shrinks to nothing exactly as it arrives, so it reads as being absorbed into the
        # number rather than just stopping next to it.
        tw.parallel().tween_property(orb, "scale", Vector2(0.2, 0.2), flight_time) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        # Whichever orb was precomputed to land FIRST (not necessarily i==0 anymore, now that
        # launch delay and flight time are both independently randomized) gets the Power
        # number's "delivery" reaction.
        if i == earliest_index:
            tw.tween_callback(_play_power_orb_arrival_reaction.bind(type))
        tw.tween_callback(_play_power_orb_land_sfx)
        tw.tween_callback(orb.queue_free)


# Written by _on_card_played_track_frame on every card play, read by _on_change_current_power
# to tell a CARD-driven power gain (spawn the support-card orb burst) apart from every other
# source of that same signal - see the CARD_ORB_* constants block for the full reasoning.
var _last_card_played_frame := -1


func _on_card_played_track_frame(_card: Card) -> void:
    _last_card_played_frame = Engine.get_process_frames()


# The ceremonial cousin of _spawn_power_orbs above: fired when a played card itself raised
# Power. Orbs bloom outward from where the card visually resolves, hang, then get drawn into
# the Power number. Parented to the ui_layer (same as the refuel/All In flourishes) so they
# sail OVER the dice panel and hand on the way in, matching the flying card they erupt from.
func _spawn_support_card_orbs(power_delta: int) -> void:
    if power_delta <= 0:
        return
    var parent_layer := get_tree().get_first_node_in_group("ui_layer")
    if not parent_layer:
        return
    var target := current_power.get_global_rect().get_center()

    # Orbs erupt from where the card was RELEASED (last_played_card_position, captured by
    # CardUI.play() the instant of play) - Julien's explicit call after seeing a first version
    # that launched from the card's staging pause above the dice interface instead ("seem to
    # come from way above? I'd like them to shoot from where you release the card"). Only
    # red-socket plays differ: their card visual never leaves the die, so the die IS the
    # release point (and last_played_card_position would be stale there - that play path
    # never goes through CardUI.play()).
    var origin := Global.last_played_card_position
    var extra_delay := 0.05
    if Global.playing_red_card or origin == Vector2.ZERO:
        origin = dice_display.get_global_rect().get_center()

    var color := DicePalette.accent(Global.dice_type) * CARD_ORB_BRIGHTNESS
    var texture := _get_power_orb_texture()
    var orb_material := _get_power_orb_material()

    var count := clampi(CARD_ORB_MIN_COUNT + power_delta, CARD_ORB_MIN_COUNT, CARD_ORB_MAX_COUNT)
    var size_bonus := lerpf(0.0, CARD_ORB_SIZE_DELTA_BONUS, clampf(float(power_delta) / 10.0, 0.0, 1.0))

    # Same earliest-arrival precompute as _spawn_power_orbs: launch delay and flight time are
    # both independent random draws, so "which orb lands first" must be computed, not assumed.
    var launch_delays: Array[float] = []
    var flight_times: Array[float] = []
    var earliest_index := 0
    var earliest_arrival := INF
    for i in count:
        var launch_delay := extra_delay + randf_range(0.0, CARD_ORB_LAUNCH_WINDOW)
        var flight_time := randf_range(CARD_ORB_FLIGHT_MIN, CARD_ORB_FLIGHT_MAX)
        launch_delays.append(launch_delay)
        flight_times.append(flight_time)
        if launch_delay + flight_time < earliest_arrival:
            earliest_arrival = launch_delay + flight_time
            earliest_index = i

    for i in count:
        var orb := TextureRect.new()
        orb.texture = texture
        orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        orb.material = orb_material
        orb.modulate = color
        orb.modulate.a = 0.0
        orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        orb.z_index = 150  # ui_layer flourish convention (refuel return / All In / scout pick)
        parent_layer.add_child(orb)

        var orb_size := randf_range(CARD_ORB_SIZE_MIN, CARD_ORB_SIZE_MAX) + size_bonus
        orb.size = Vector2(orb_size, orb_size)
        orb.pivot_offset = orb.size / 2.0

        var start := origin + Vector2(randf_range(-18.0, 18.0), randf_range(-12.0, 12.0))
        var end := target + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
        orb.global_position = start - orb.size / 2.0

        # Control point flung OUTWARD from the card in a mostly-upward fan (~220 degrees
        # centered on straight up), so with the EASE_IN acceleration profiles below each orb
        # visibly blooms away from the card first, hangs, then sweeps into the Power number -
        # "the card exhales its magic, and your power inhales it".
        var fling_dir := Vector2.from_angle(deg_to_rad(randf_range(-200.0, 20.0)))
        var control := start + fling_dir * randf_range(CARD_ORB_FLING_DIST_MIN, CARD_ORB_FLING_DIST_MAX)

        var flight_time := flight_times[i]
        var ease_profile: Array = POWER_ORB_EASE_PROFILES[randi() % POWER_ORB_EASE_PROFILES.size()]
        var wobble_freq := randf_range(POWER_ORB_WOBBLE_FREQ_MIN, POWER_ORB_WOBBLE_FREQ_MAX)
        var wobble_amp := randf_range(CARD_ORB_WOBBLE_AMP_MIN, CARD_ORB_WOBBLE_AMP_MAX)
        var wobble_phase := randf_range(0.0, TAU)

        var tw := create_tween()
        tw.tween_interval(launch_delays[i])
        tw.tween_property(orb, "modulate:a", 1.0, flight_time * 0.25)
        tw.parallel().tween_method(
                _orb_bezier_step.bind(orb, start, control, end, wobble_freq, wobble_amp, wobble_phase),
                0.0, 1.0, flight_time) \
            .set_trans(ease_profile[0]).set_ease(ease_profile[1])
        tw.parallel().tween_property(orb, "scale", Vector2(0.2, 0.2), flight_time) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        if i == earliest_index:
            tw.tween_callback(_play_power_orb_arrival_reaction.bind(Global.dice_type))
        tw.tween_callback(_play_power_orb_land_sfx)
        tw.tween_callback(orb.queue_free)


# Drives the die's own per-dice-type aura shader (brightness, spread, swirl speed, color)
# so the DIE itself visibly "charges up" as banked power grows this turn, rather than a
# separate glow flashing on the Power number - the old power_glow-on-the-number flare was
# removed so the "you're charged" signal lives on one element, not two (Julien + GPT's
# refinement plan, 2026-07-01). Deliberately doesn't touch aura.scale - see the constants
# comment above for why scaling the node itself caused the glow to visibly detach from the
# die at higher power.
func _update_dice_aura_charge() -> void:
    if not (aura.material is ShaderMaterial):
        return
    # Exponential approach (1 - e^-x/k), not smoothstep: smoothstep(0,12,x) looked right
    # around power 5 but kept accelerating hard through 9-13 (84% -> 100%, felt like "too
    # much" too fast). This curve has no hard cap - growth continuously decelerates instead
    # of an S-curve with a fixed ceiling, so power~5 lands about the same as before while
    # 9/13/20+ all read as calmer, later steps toward a ceiling it never quite reaches.
    var t := 1.0 - exp(-float(Global.roll_value) / AURA_CHARGE_SOFTNESS)
    # Red charges via "pick a card, roll, resolve, reset" rather than accumulating like the
    # other types - it's rarely sitting at a nonzero roll_value long enough to visibly charge
    # at all, so give it a floor equivalent to ~6-7 power on blue instead of starting from 0.
    if dice_type == "red":
        t = maxf(t, AURA_RED_BASELINE_CHARGE)
    var intensity_rest: float = AURA_INTENSITY_REST_OVERRIDE.get(dice_type, AURA_INTENSITY_REST)
    var target_intensity := lerpf(intensity_rest, AURA_INTENSITY_MAX, t)
    var target_reach := lerpf(AURA_REACH_REST, AURA_REACH_MAX, t)

    var base_wave_speed: float = AURA_BASE_WAVE_SPEED.get(dice_type, AURA_BASE_WAVE_SPEED_DEFAULT)
    # Clamped to the uniform's own declared hint_range (0.1-3.0 in dice_glow.gdshader) -
    # magma's higher base (2.55) leaves less headroom before hitting that ceiling than the
    # other 8 types' base (2.022), so it gets a smaller relative boost rather than exceeding it.
    var target_wave_speed := clampf(base_wave_speed * lerpf(1.0, AURA_WAVE_SPEED_MULT_MAX, t), 0.1, 3.0)
    var target_heat := lerpf(0.0, AURA_HEAT_MAX, t)

    var charge_tween := create_tween()
    _tween_aura_shader_param(charge_tween, "power_intensity", target_intensity, 0.25)
    _tween_aura_shader_param(charge_tween, "glow_reach", target_reach, 0.25)
    _tween_aura_shader_param(charge_tween, "wave_speed", target_wave_speed, 0.3)
    _tween_aura_shader_param(charge_tween, "charge_heat", target_heat, 0.3)
    # The emanation tongues ride the exact same charge curve (t) as the ring, so both
    # layers grow/settle in lockstep - reach/density/speed derive from "charge" inside
    # dice_emanation.gdshader.
    _tween_emanation_shader_param(charge_tween, "charge", t, 0.3)
    _tween_emanation_shader_param(charge_tween, "charge_heat", target_heat, 0.3)

    # Overcharge rides here rather than on its own set of hooks: this function is already the
    # one place every power change funnels through, so the tier climbs AND tears itself down
    # on paths (Reservoir keep, ricochet restore, red's delayed wipe) that will never know it
    # exists. See the Overcharge section at the bottom of this file.
    _update_overcharge()


# Defensive wrapper: tween_property() returns null if the material's currently-loaded/
# compiled shader doesn't expose the given parameter (e.g. right after adding a new uniform
# to a .gdshader file, before a running instance has reloaded it - hit this once with
# charge_heat mid-session). Guards against that null crashing the rest of the tween chain.
func _tween_aura_shader_param(t: Tween, param_name: String, value, duration: float) -> void:
    var tweener := t.parallel().tween_property(aura.material, "shader_parameter/" + param_name, value, duration)
    if tweener:
        tweener.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# Same null-guard rationale as _tween_aura_shader_param, for the emanation layer's material.
func _tween_emanation_shader_param(t: Tween, param_name: String, value, duration: float) -> void:
    var tweener := t.parallel().tween_property(emanation.material, "shader_parameter/" + param_name, value, duration)
    if tweener:
        tweener.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------------------
# Debug-build SFX audition (2026-08-18): cycle landing-sound candidates live in any fight.
# F9 = crush (the big-roll smash), F10 = riser (the max-roll hang swell). F9 is now only a
# keyboard shortcut for the debug panel's SFX button, so the two can never hold different
# ideas of which crush candidate is selected; the riser stays local and folder-driven
# (.ogg/.wav/.mp3 in res://debug_sfx_candidates/riser, cycling file 1..N then back to none).
# Debug builds only; the folder rides the debug_* export exclusion so candidates never ship.
var _riser_audition_index := -1


func _unhandled_input(event: InputEvent) -> void:
    if not OS.is_debug_build():
        return
    var key := event as InputEventKey
    if key == null or not key.pressed or key.echo:
        return
    if key.keycode == KEY_F9:
        if Global.debug_overlay != null:
            Global.debug_overlay.cycle_sfx(1)
    elif key.keycode == KEY_F10:
        _cycle_riser_candidate()
    elif key.keycode == KEY_F11:
        _debug_stock_dice()


# Debug builds only: fill EVERY dice type to DEBUG_STOCK_AMOUNT, live, mid-fight. Exists so
# the overcharge tiers can be reached in one turn without playing a run up to them - a long
# same-type chain is the only way to bank that much Power, and 20 blue rolls averages ~70.
#
# A key rather than edited starting data on purpose: the run loadout picker (dice_loadout.gd)
# rewrites all nine types at the start of every run #2+, so seeding reset_run_state() would
# be silently overwritten, and either way it would mean restarting a run per experiment.
#
# Writes max_amount as well as current: dice_interface refills current = max + bonus at the
# start of every turn, so setting only current would evaporate on the next turn.
const DEBUG_STOCK_AMOUNT := 20


func _debug_stock_dice() -> void:
    for type: String in Global.DICE_TYPE_ORDER:
        Global.set(type + "_dice_max_amount", DEBUG_STOCK_AMOUNT)
        Global.set(type + "_dice_current_amount", DEBUG_STOCK_AMOUNT)
        if not Global.dice_inventory.has(type):
            Global.dice_inventory.append(type)
    # The slot row caches which types are visible and how wide the tray is, so it has to be
    # rebuilt rather than left to notice on its own.
    var row := get_tree().get_first_node_in_group("dice_interface")
    if row != null:
        row.initialize_dices()
        row._resize_panel_for_dice_inventory()
        row.update_selected_highlight()
    Events.update_dice_top_bar.emit()
    print("[debug] stocked all 9 dice types to %d" % DEBUG_STOCK_AMOUNT)


func _cycle_riser_candidate() -> void:
    var dir_path := "res://debug_sfx_candidates/riser"
    var files: Array[String] = []
    var dir := DirAccess.open(dir_path)
    if dir:
        for f: String in dir.get_files():
            var lower := f.to_lower()
            if lower.ends_with(".ogg") or lower.ends_with(".wav") or lower.ends_with(".mp3"):
                files.append(f)
        files.sort()
    if files.is_empty():
        print("[sfx-audition] no candidates in %s - drop .ogg/.wav/.mp3 there first" % dir_path)
        return
    var idx := _riser_audition_index + 1
    if idx >= files.size():
        idx = -1  # wrap through the default before cycling the files again
    _riser_audition_index = idx
    if idx == -1:
        land_riser_sound = null
        print("[sfx-audition] riser -> none (default)")
        return
    var stream := load(dir_path + "/" + files[idx]) as AudioStream
    if stream == null:
        print("[sfx-audition] could not load %s (not imported yet? refocus the editor once)" % files[idx])
        return
    land_riser_sound = stream
    print("[sfx-audition] riser -> %s (%d of %d)" % [files[idx], idx + 1, files.size()])
    SFXPlayer.play(stream, false, 1.0, -4.0)


# Silent unless a riser candidate is selected via F10. Fired by the CALM builder as the
# max-roll hang begins, so the swell leads into the landing smash.
func _play_land_riser() -> void:
    if land_riser_sound:
        SFXPlayer.play(land_riser_sound, false, randf_range(0.96, 1.04), -4.0)


# Helper function to apply the roll result (unified logic)
func _apply_roll_result(roll_index: int, values: Array, faces: Array):
    Global.last_roll = values[roll_index]
    # Snake Eyes / Hot Hand / Ice Cold streaks - values/faces already carry the full set
    # this roll was drawn from (including infusion overrides), so min/max here match
    # exactly what the player could have rolled.
    AchievementManager.report_dice_roll(dice_type, Global.last_roll, values.min(), values.max())

    # Update dice display
    if dice_type in ["evil", "even", "odd", "magma", "green", "mech"]:
        dice_display.texture = faces[roll_index]
    else:
        dice_display.texture = load("res://assets/images/" + dice_type + str(Global.last_roll) + ".png")

    # New power on the board - supersedes any pending delayed red reset (see _power_reset_generation).
    _power_reset_generation += 1
    Global.roll_value += Global.last_roll
    Global.power_generated_this_turn += Global.last_roll
    # Lifetime power counter ("Unlimited Power" achievement) - mirrors the increment above.
    AchievementManager.add_stat("power_generated", Global.last_roll)
    # Run-lifetime stats for the end-of-run screens.
    Global.run_stat_dice_rolled += 1
    Global.run_stat_power_generated += Global.last_roll
    current_power.modulate.a = 1.0
    _spawn_roll_popup(Global.last_roll)
    var power_punch = 1.2 + (Global.last_roll / 20.0)  # 1.25 on 1, 1.5 on 6, 1.8 on 12
    # Chain ladder: the deeper into a same-type chain this roll is, the harder the number
    # punches - the 4th consecutive roll HITS harder than the 1st even at the same face
    # value. Depth = history size BEFORE this roll's append (it happens further down).
    power_punch += POWER_CHAIN_PUNCH_STEP \
            * clampi(Global.roll_history.size(), 0, POWER_CHAIN_PUNCH_CAP)
    # Tier crossing: banking POWER_TIER_THRESHOLD+ in one chain fires a one-shot ignition
    # flare on the number + a brief freeze. Deliberately NO persistent tint while above -
    # the power color paths are a documented minefield of restore-to-snapshot bugs, and a
    # one-shot beat can't fight them.
    var tier_was := _power_tier_active
    _power_tier_active = Global.roll_value >= POWER_TIER_THRESHOLD
    if _power_tier_active and not tier_was:
        _spawn_thrown_die_flare(self, current_power.get_global_rect().get_center(),
                DicePalette.burst(dice_type), true)
        Shaker.hit_stop(0.1)
        power_punch += 0.25
    # Resting size grows with the turn's accumulated power (not just this single roll), so a
    # big turn leaves the number visibly bigger between rolls instead of snapping back to
    # the same neutral size every time - the goal Julien described as "feel more powerful"
    # rather than the rejected count-up animation.
    var power_rest_scale = clampf(1.0 + Global.roll_value / 130.0, 1.0, 1.25)
    var power_tween = create_tween()
    power_tween.tween_property(current_power, "scale", Vector2(power_punch, power_punch), 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    power_tween.tween_property(current_power, "scale", Vector2(power_rest_scale, power_rest_scale), 0.14).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

    # Restore to the authoritative per-type colour, NEVER to a live read of modulate:
    # an orb arrival landing mid-flash would capture the already-lightened value as its
    # "resting" colour and settle there, and every subsequent roll would lighten from that
    # washed-out base again - the number ratcheted to white after 2-3 rolls.
    var base_power_color := _power_resting_color()
    if _power_color_flash_tween and _power_color_flash_tween.is_valid():
        _power_color_flash_tween.kill()
    _power_color_flash_tween = create_tween()
    _power_color_flash_tween.tween_property(current_power, "modulate", base_power_color.lightened(0.6), 0.05)
    _power_color_flash_tween.tween_property(current_power, "modulate", base_power_color, 0.18)

    # Magma dice special effect
    if dice_type == "magma":
        var enemies = get_tree().get_nodes_in_group("enemies")
        var base_damage = Global.last_roll
        var damage_effect := DamageEffect.new()
        damage_effect.amount = base_damage
        damage_effect.execute(enemies)
        _spawn_magma_burn(enemies)
        AchievementManager.report_magma_hit(enemies.size())
        # Inferno infusion: the FIRST magma roll each turn burns a second time (double AoE
        # on that roll). _magma_burned_this_turn is reset in _on_player_turn_started.
        # The second burn lands after a short beat (INFERNO_SECOND_BURN_DELAY) so the two
        # hits read as two distinct impacts; targets are re-queried at fire time because
        # the first burn may have killed (freed) some of them in the meantime.
        if Global.is_dice_infused("magma") and not _magma_burned_this_turn:
            get_tree().create_timer(INFERNO_SECOND_BURN_DELAY, false).timeout.connect(func():
                if not is_instance_valid(self):
                    return
                var burn_targets := get_tree().get_nodes_in_group("enemies")
                if burn_targets.is_empty():
                    return
                var second_burn := DamageEffect.new()
                second_burn.amount = base_damage
                second_burn.execute(burn_targets)
                _spawn_magma_burn(burn_targets)
            )
        _magma_burned_this_turn = true

    # NO high-roll sound here any more. A max roll used to fire TWO of them: an orchestral
    # hit from this line, plus the smash in _on_roll_landed() - Julien, 2026-08-26, wanted
    # only the crush kept. The smash survives because it is the one on the landing BEAT
    # (it rides on top of the thud, at the moment of impact), whereas this fired at result
    # time. Both were gated on the identical condition - this die's own best face
    # (values.max(), so 12 on Giant / 3 on Green, never literally 6) - so nothing changed
    # about WHEN the celebration happens, only that it is one sound instead of two.

    # Evil dice's crack face (0): a distinct sting so whiffing reads as a felt outcome
    # rather than a silent non-event (a 0 roll spawns no power orbs, no popup worth noting).
    if dice_type == "evil" and Global.last_roll == 0:
        play_crack_sound()

    # Separate gameplay flag (Pinpoint card checks this) - stays tied to a literal 6,
    # not the per-die max, so don't fold it into the check above.
    if Global.last_roll == 6:
        Global.has_rolled_6_this_turn = true
        # Fight-long tally for Jackpot/Effigy. Keyed on the NATURAL face like the flag above,
        # so a Boosted or Surge 5->6 never counts.
        Global.sixes_rolled_this_fight += 1

        # Talisman, held in hand: every natural 6 grants Block (Julien, 2026-08-20). Sits
        # here rather than in the card so it shares Jackpot's and Effigy's definition of a
        # "6" - three cards, one rule, and the sixes archetype can never disagree with itself.
        var talisman_block := Global.in_hand_six_block()
        if talisman_block > 0:
            Events.add_block.emit(talisman_block)

    # Rainbow archetype: which TYPES were rolled this turn (Spectrum, Prismatic Lens).
    Global.dice_types_rolled_this_turn[dice_type] = true

    # Arcane infusion (Blue act-2 infusion): a NATURAL 6 on the Blue die deals ARCANE_AOE_DAMAGE
    # to all enemies. Checked on last_roll (the rolled face itself), BEFORE next_roll_modifier
    # is applied below - so a Scout/Lucky-guaranteed 6 counts (they force the actual face),
    # while a Boosted 5->6 does not (Julien's call, 2026-07-14). Flat AoE via DamageEffect
    # (same pattern as Magma), so it picks up each target's own DMG_TAKEN modifiers (Exposed)
    # but not the player's Strength - consistent with magma, and berserker_boost_active is
    # false here since this fires on a roll, not during a socketed card play.
    if dice_type == "blue" and Global.last_roll == 6 and Global.is_dice_infused("blue"):
        var arcane_effect := DamageEffect.new()
        arcane_effect.amount = ARCANE_AOE_DAMAGE
        arcane_effect.execute(get_tree().get_nodes_in_group("enemies"))

    # More infusion on-roll triggers, all keyed to the NATURAL rolled face (Global.last_roll),
    # same as Arcane above and BEFORE next_roll_modifier - and all ON TOP of the normal Power
    # this roll already generated (Julien: additive, not a replacement).
    _apply_infusion_roll_effects()

    # Status checks
    Events.check_canalize_status.emit()

    Events.weak_effect_consumed.emit()
    Events.check_chaos_status.emit()
    
    # Apply roll modifiers
    if Global.next_roll_modifier != 0:
        Global.roll_value += Global.next_roll_modifier
        Global.roll_value = max(0, Global.roll_value)
        if Global.next_roll_modifier < 0:
            play_weak_dice_sound()
        else:
            play_strong_dice_sound()
        Global.next_roll_modifier = 0
        animation_player_power.play("power_change")
        next_roll_bonus_panel.hide()

    # Surge: flat Power on EVERY roll. Boost above is consumed by a single roll; this is not,
    # which is the whole point - it's the per-ROLL scaling axis (Strength being the per-HIT one).
    # Deliberately applied HERE, after every natural-face trigger above: Arcane's 6, Gnome's 1,
    # Octet's 8 and Critical Edge's max face all read Global.last_roll, so a Surge roll can
    # never fake a natural face. Same ruling Boost already follows (Julien, 2026-07-14).
    if Global.surge_amount > 0:
        Global.roll_value += Global.surge_amount

    # Cards that buff rolls purely by being HELD (Blood Oath on Red, Dead Weight's Surge 1).
    # Same placement rule as Surge: after every natural-face trigger, so a held card can never
    # fake a natural 6/1/8.
    var held_bonus: int = Global.in_hand_roll_bonus(dice_type)
    if held_bonus > 0:
        Global.roll_value += held_bonus

    _set_power_text(Global.roll_value)
    current_power.modulate.a = 0.4 if Global.roll_value == 0 else 1.0
    _update_power_float()
    _update_dice_aura_charge()
    # Update roll history
    Global.roll_history.append(Global.last_roll)
    Global.last_rolled_type = dice_type
    update_roll_history_ui()
    # The chain rack punches in sync with the landing (this whole function runs on the
    # landing frame) - the new mini-face ARRIVES instead of just appearing, which is what
    # makes the chain legible to someone who doesn't know the mechanic yet.
    _punch_roll_history()

    # Emit appropriate events
    if dice_type != "red":
        Events.dice_rolled.emit(Global.dice_type, Global.roll_value)
    else:
        # Arm the one-shot report token BEFORE the emit: whichever socketed CardUI handles
        # red_dice_rolled first consumes it and re-emits dice_rolled, so a Red roll produces
        # exactly one dice_rolled no matter how many cards are socketed (Dual Cannon).
        Global.red_roll_pending_report = true
        Events.red_dice_rolled.emit()
        _fire_socketless_red()
    _check_sigil_trigger()
    Events.hover_playable_cards.emit()
    mech_adjustments_used = 0
    _update_mech_buttons()
    # ⚠️ The Ricochet allowance refreshes only on a FRESH roll. Mech resets unconditionally
    # here because every Mech roll is a new die; a reroll is the SAME roll landing again, so
    # resetting on its landing would immediately grant another reroll of it - unlimited.
    if not Global.ricochet_reroll_active:
        ricochet_rerolls_used = 0
    Global.ricochet_reroll_active = false
    _update_charged_card_description()
    _roll_in_progress = false
    # ⚠️ MUST come after `_roll_in_progress = false`. _can_ricochet_reroll() reads that flag,
    # so updating the button any earlier evaluates it as "a roll is still in progress", leaves
    # the button disabled, and nothing re-runs this afterwards - the reroll is dead for the
    # whole turn. (Shipped that way briefly; caught in playtest, not by the harness, because
    # the harness asserted on the predicate instead of on the button's actual state.)
    _update_ricochet_button()


const OCTET_MUSCLE_STATUS := preload("res://statuses/muscle.tres")
const BULWARK_BLOCK_SFX := preload("res://art/block.ogg")
const ARCANE_AOE_DAMAGE := 5  # Arcane infusion: damage dealt to all enemies on a natural 6

# On-roll dice-infusion effects that grant something extra (charge / block / strength) on top
# of the roll's normal Power. Keyed to the NATURAL rolled face (Global.last_roll), consistent
# with Arcane. Called from _apply_roll_result before next_roll_modifier is applied.
func _apply_infusion_roll_effects() -> void:
    # Gnome (Green): a natural 1 charges a Blue Dice (same trio of calls as the Sigil trigger).
    if dice_type == "green" and Global.last_roll == 1 and Global.is_dice_infused("green"):
        Global.blue_dice_current_amount += 1
        Events.dice_amount_changed.emit()
        Events.dice_charged.emit("blue", 1)

    # Bulwark (Odd): every roll ALSO grants Block equal to its value (Julien: on top of Power).
    if dice_type == "odd" and Global.last_roll > 0 and Global.is_dice_infused("odd"):
        var block_effect := BlockEffect.new()
        block_effect.amount = Global.last_roll
        block_effect.sound = BULWARK_BLOCK_SFX
        var block_targets: Array[Node] = [Global.player]
        block_effect.execute(block_targets)

    # Octet (Even): a natural 8 grants 8 Strength for THIS turn only - removed at the start of
    # next turn via lose_strength_next_turn (the same one-turn-strength mechanism fury.gd uses;
    # player_handler.start_turn now clears the global after applying it, see the fix there).
    if dice_type == "even" and Global.last_roll == 8 and Global.is_dice_infused("even"):
        var status_effect := StatusEffect.new()
        var muscle := OCTET_MUSCLE_STATUS.duplicate()
        muscle.stacks = 8
        status_effect.status = muscle
        var muscle_targets: Array[Node] = [Global.player]
        status_effect.execute(muscle_targets)
        Global.lose_strength_next_turn += 8


# Light landing tick, fired on EVERY orb (unlike _play_power_orb_arrival_reaction below, which
# only fires once per roll on the first orb). Pitch/volume jittered per hit so a big roll's
# flurry of landings reads as a scatter of individual little hits rather than the same note
# machine-gunned back to back.
func _play_power_orb_land_sfx() -> void:
    var pitch := randf_range(POWER_ORB_LAND_PITCH_MIN, POWER_ORB_LAND_PITCH_MAX)
    var volume := POWER_ORB_LAND_VOLUME_DB + randf_range(-POWER_ORB_LAND_VOLUME_JITTER, POWER_ORB_LAND_VOLUME_JITTER)
    # Low priority (-1, see sound_player.gd): a burst of these (up to ~15 on a big roll) must
    # never starve the pooled voices out from under a real gameplay sound (e.g. Recombobulate's
    # refuel sound going missing when playing fast) - decorative plinks are the first to get
    # stolen, never the ones doing the stealing.
    SFXPlayer.play(POWER_ORB_LAND_SFX, false, pitch, volume, -1)


# A second, smaller reaction on the Power number, purely additive - the number itself already
# updated instantly back in _apply_roll_result (text/punch/flash/crackle all fire immediately,
# same as before the orb feature existed - no lag on the actual value). This plays ON TOP when
# the first power orb actually lands (chained from _spawn_power_orbs), as a distinct "delivery"
# beat: a smaller pop (so it doesn't fight the roll's own bigger landing punch) plus a flash
# tinted in the active dice's color (vs. the roll punch's white lighten) so the two beats read
# as different things - "the roll landed" vs. "the orb just fed the number".
func _play_power_orb_arrival_reaction(type: String) -> void:
    var rest_scale := clampf(1.0 + Global.roll_value / 130.0, 1.0, 1.25)
    var pop_tween := create_tween()
    pop_tween.tween_property(current_power, "scale", Vector2(rest_scale, rest_scale) * 1.12, 0.05) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    pop_tween.tween_property(current_power, "scale", Vector2(rest_scale, rest_scale), 0.12) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

    # Same rule as the roll flash: settle on the true per-type colour, not on whatever
    # mid-flash value modulate happens to hold when this orb lands.
    var base_color := _power_resting_color()
    if _power_color_flash_tween and _power_color_flash_tween.is_valid():
        _power_color_flash_tween.kill()
    _power_color_flash_tween = create_tween()
    _power_color_flash_tween.tween_property(current_power, "modulate", DicePalette.accent(type).lightened(0.35), 0.05)
    _power_color_flash_tween.tween_property(current_power, "modulate", base_color, 0.15)


func _on_active_dice_changed(new_dice_type):
    SFXPlayer.play(Global.sfx_click)
    dice_type = new_dice_type
    Global.dice_type = new_dice_type  # Make sure to update the global variable
    if dice_type == "red" and new_dice_type != "red" and socketed_card_ui != null:
        _on_cancel_red_card_pressed()
    Global.next_guaranteed_roll = -1
    next_roll_panel.hide()
    Events.hover_playable_cards.emit()
    # Kill any in-flight power-color flashes first: they'd otherwise finish by restoring the
    # PREVIOUS dice type's color on top of the new one update_dice_display() is about to set
    # (the "power stays red after switching to blue" bug when playing fast).
    if _power_color_flash_tween and _power_color_flash_tween.is_valid():
        _power_color_flash_tween.kill()
    if _power_clang_flash_tween and _power_clang_flash_tween.is_valid():
        _power_clang_flash_tween.kill()
    update_dice_display()

    # Small landing pop when the new die takes the socket - the swap was previously an
    # instant texture change with zero feedback. Ends at exactly 1.0 so it can't fight the
    # roll/refuel tweens beyond a transient frame.
    var switch_tween := create_tween()
    switch_tween.tween_property(dice_display, "scale", Vector2(1.12, 1.12), 0.07) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    switch_tween.tween_property(dice_display, "scale", Vector2(1.0, 1.0), 0.12) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

    if(dice_type == "red"):
        card_drop_area.show()
        mech_section.hide()
        # Repaint an empty socket now that Red is live: _socket_is_armed() reads dice_type, and
        # Armageddon is usually played from a DIFFERENT die, so the socket was last painted
        # before the blessing existed.
        _refresh_empty_socket_look()
    elif(dice_type == "mech"):
        mech_section.show()  
        card_drop_area.hide()      
    else:
        card_drop_area.hide()
        mech_section.hide()
        Global.playing_red_card = false
        
    # The switch zeroes power itself, so a pending delayed red reset has nothing left to do
    # here - and letting it fire later would blank whatever the player rolls on the new die.
    _power_reset_generation += 1
    # Kaleidoscope: for this turn, hopping between types does NOT break the chain - the one
    # rule change that makes a rainbow turn (Spectrum, Prismatic Lens) affordable.
    if not Global.keep_power_on_type_change:
        Global.roll_value = 0
        Global.roll_history = []
        _set_power_text("0")
    current_power.modulate.a = 0.4
    current_power.scale = Vector2.ONE
    _update_power_float()
    Events.change_current_power.emit()

    # Switching type starts a new chain (roll_value/history were just zeroed above), so the
    # Ricochet allowance and snapshot go with it. _update_ricochet_button() also owns showing
    # and hiding the section, mirroring the mech_section branches earlier in this function -
    # it has to run AFTER roll_history is cleared, since it reads it.
    ricochet_rerolls_used = 0
    _ricochet_snapshot = {}
    Global.ricochet_reroll_active = false
    _update_ricochet_button()

# The Power number's true resting colour: per-type RGB captured in update_dice_display(),
# but carrying whatever alpha is live right now (the dimmed 0.4 at zero power vs 1.0 with
# power banked is owned by the roll/reset paths, not by the palette).
func _power_resting_color() -> Color:
    # Derived from the palette rather than from _power_resting_modulate: that snapshot
    # defaults to Color.WHITE until update_dice_display() first runs, and a flash beating
    # it would then bake white in permanently - the exact failure this is fixing.
    var c := DicePalette.accent(dice_type)
    c.a = current_power.modulate.a
    return c


func update_dice_display():
    # Resting face shown when this type becomes active - "1" for every type that has a 1,
    # evil's best face (it has no 1) and even's lowest (2).
    var rest_face := "1"
    match dice_type:
        "evil": rest_face = "6"
        "even": rest_face = "2"
    dice_display.texture = load("res://assets/images/" + dice_type + rest_face + ".png")

    current_power.modulate = DicePalette.accent(dice_type)
    # The outline must go through label_settings: this Label HAS a LabelSettings resource,
    # which takes priority over theme overrides - the old add_theme_color_override() call
    # here was silently ignored, leaving the outline stuck on its authored brown for every
    # dice type. (Safe to mutate: dice.tscn is instanced exactly once, in battle.tscn, and
    # _set_power_text already mutates this same resource's font_size.)
    if current_power.label_settings:
        current_power.label_settings.outline_color = DicePalette.outline(dice_type)
    _power_resting_modulate = current_power.modulate  # capture per-type color for the clang flash to return to
    set_shader_from_global_type(dice_type)
    _update_emanation_colors()
    _update_power_ember_colors()


# Retint the emanation tongues to the active die's identity. Safe to set directly: the
# material is resource_local_to_scene, so this instance owns its own copy (never the
# shared preloaded per-type auras - that mutation bug lives in _resolve_aura_material's
# comment). DicePalette.accent()/outline() are infusion-aware, so this covers act-2
# infused recolors too.
func _update_emanation_colors() -> void:
    if not (emanation.material is ShaderMaterial):
        return
    var mat: ShaderMaterial = emanation.material
    mat.set_shader_parameter("accent_color", DicePalette.accent(dice_type))
    mat.set_shader_parameter("deep_color", DicePalette.outline(dice_type))
    var speed: float = EMANATION_BASE_SPEED.get(dice_type, EMANATION_BASE_SPEED_DEFAULT)
    mat.set_shader_parameter("base_speed", speed)

# The emanation shader fades its light out beneath the dice-type slot row so the row stays
# readable. Those bounds are read from the row's REAL rect instead of being baked into the
# shader as constants: a hardcoded copy stops matching the moment anyone nudges the row in
# battle.tscn, and NOTHING errors when it drifts - the clearance just quietly stops
# clearing. That is precisely how the status-row clamp broke when End Turn moved. Outside
# battle (harness / standalone boots) there is no row, so the authored defaults stand.
func _sync_emanation_row_clearance() -> void:
    if not (emanation.material is ShaderMaterial):
        return
    var row := get_tree().get_first_node_in_group("dice_interface") as Control
    if row == null:
        return
    var die_panel := get_node_or_null("Panel") as Panel
    if die_panel == null:
        return
    var mat: ShaderMaterial = emanation.material
    var die_center := die_panel.global_position + die_panel.size * 0.5
    var rect := row.get_global_rect()
    # Shader space is die-centered pixels, +y down.
    mat.set_shader_parameter("row_bottom_y", rect.end.y - die_center.y)
    mat.set_shader_parameter("row_half_width",
            maxf(absf(rect.position.x - die_center.x), absf(rect.end.x - die_center.x)))


func _on_dice_rolled(rolled_dice_type, roll_value):
    # Connected to Events.dice_rolled (see _ready). Body intentionally empty -
    # it only ever printed. Kept as a hook so the connect() above stays valid.
    pass

func play_error_sound():
    var sound = AudioStreamPlayer.new()
    sound.stream = load("res://sounds/error.wav")
    add_child(sound)
    sound.play()
    await sound.finished  # Wait for sound to finish
    sound.queue_free()  # Remove it after playing
    
    
func play_dice_roll_sound():
    # Pick a random sound from the list
    var random_sound_path = dice_roll_sounds[randi() % dice_roll_sounds.size()]
    dice_roll_player.stream = load(random_sound_path)
    
    # Increase volume if needed
    dice_roll_player.volume_db = 6  # Increase volume (optional)
    
    # Play the sound
    dice_roll_player.play()
    
func play_crack_sound():
    var sfx_crack = preload("res://glass_sound.mp3")
    SFXPlayer.play(sfx_crack, false, 1.0, 3.0)

func play_weak_dice_sound():
    #dice_roll_player.stream = load("res://sounds/visionsound.wav")
    #dice_roll_player.volume_db = 6  # Increase volume (optional)
    #dice_roll_player.play() 
    var sfx_weak_roll = preload("res://sfx/374749__sgossner__oldtrombone-f2-trombone_fall_f2_2.wav")
    SFXPlayer.play(sfx_weak_roll)

func play_strong_dice_sound():
    dice_roll_player.stream = load("res://chargedicesound.mp3")
    dice_roll_player.volume_db = 6  # Increase volume (optional)
    dice_roll_player.play() 

func _on_player_turn_started() -> void:
    # Ending the turn right after a red card would otherwise let the pending 1s reset land on
    # the new turn and eat the Stockpile carryover restored just below.
    _power_reset_generation += 1
    Global.roll_history = []
    Global.power_generated_this_turn = 0
    _magma_burned_this_turn = false
    if socketed_card_ui != null:
        _on_cancel_red_card_pressed()
    if Global.starting_power_next_turn!=0:
        Global.roll_value = Global.starting_power_next_turn
        Global.starting_power_next_turn = 0
    else:
        Global.roll_value = 0
    _set_power_text(Global.roll_value)
    current_power.modulate.a = 0.4 if Global.roll_value == 0 else 1.0
    current_power.scale = Vector2.ONE
    _update_power_float()
    _update_dice_aura_charge()
    # If you have a variable tracking the roll value, reset it here too
    # Global.roll_value = 0  # This is now handled in the dice_interface.gd
    mech_adjustments_used = 0
    _update_mech_buttons()
    # New turn = new chain: no roll left to reroll, so drop the allowance and the stale
    # snapshot. Clearing the Global flag here too is belt-and-braces against it surviving an
    # interrupted roll and silently making the next roll free.
    ricochet_rerolls_used = 0
    _ricochet_snapshot = {}
    Global.ricochet_reroll_active = false
    _update_ricochet_button()

func _on_dice_roll_reset() -> void:

    if Global.no_reset:
        Global.no_reset = false
        return
    # Reservoir: keep a floor of Power through a card's reset instead of wiping to zero. Only
    # meaningful when there was more than that to begin with - it must never ADD Power.
    var keep: int = Global.power_kept_on_reset
    if keep > 0 and Global.roll_value > keep:
        _power_reset_generation += 1
        Global.roll_value = keep
        Global.roll_history = []
        _set_power_text(str(keep))
        current_power.modulate.a = 1.0
        update_roll_history_ui()
        _update_dice_aura_charge()
        Events.hover_playable_cards.emit()
        return
    _power_reset_generation += 1
    if Global.dice_type == "red":
        var generation := _power_reset_generation
        await get_tree().create_timer(1.0).timeout  # Wait 0.5 seconds
        # Anything that banked new power during the delay (blue roll after hopping off red,
        # a dice switch, a new turn's Stockpile carryover, another card's reset) bumped the
        # counter - this wipe is stale, drop it or it eats power the player just earned.
        if generation != _power_reset_generation:
            return
        _set_power_text("0")
        current_power.modulate.a = 0.4
        current_power.scale = Vector2.ONE
        Global.roll_value = 0
        Global.playing_red_card = false
        Global.roll_history = []
        _update_power_float()
        _update_dice_aura_charge()
        update_roll_history_ui()
    else:
        _set_power_text("0")
        Global.roll_value = 0
        current_power.modulate.a = 0.4
        current_power.scale = Vector2.ONE
        Global.roll_history = []
        _update_power_float()
        _update_dice_aura_charge()
        update_roll_history_ui()
    mech_adjustments_used = 0
    _update_mech_buttons()
    # A card spent the Power: the roll it came from is gone, so there is nothing left to
    # reroll back into. Same reasoning as the turn-start reset above.
    ricochet_rerolls_used = 0
    _ricochet_snapshot = {}
    Global.ricochet_reroll_active = false
    _update_ricochet_button()
    Events.hover_playable_cards.emit()
    _update_charged_card_description()


func _on_card_charged(card_ui):
    if Global.red_dice_current_amount <= 0:
        return

    if not card_ui or not card_ui.card:
        print("Card data not available")
        return

    if card_ui.card.can_play_without_dice:
        return

    if _socketing_in_progress:
        return
    _socketing_in_progress = true

    # Second socket: when it exists and socket 1 is taken, fill socket 2 instead of
    # evicting socket 1. Returns early - the rest of this function styles socket 1.
    if socketed_card_ui != null and Global.red_socket_capacity >= 2 \
            and socketed_card_ui_2 == null and socketed_card_ui != card_ui:
        _fill_socket_2(card_ui)
        _socketing_in_progress = false
        return

    # CRITICAL FIX: If a card is already socketed, auto-cancel it first
    if socketed_card_ui != null:
        print("Socket already occupied - auto-canceling previous card")
        _on_cancel_red_card_pressed()
        # Small delay to ensure state is clean
        await get_tree().create_timer(0.1).timeout

    # Now socket the new card
    _set_socket_filled()
    socketed_card_ui = card_ui
    charged_card_texture.texture = card_ui.card.icon
    _set_charged_description(card_ui.card, card_ui.card.description)
    # Deferred on purpose: card_released_state.gd emits card_charged BEFORE it assigns
    # Global.charged_card_instance_id, and the Berserker preview boost
    # (Card.apply_target_modifier) keys off that id - an immediate refresh here would
    # miss the +50% until the next dice_rolled/power-change refresh.
    _update_charged_card_description.call_deferred()
    title.text = card_ui.card.name
    cancel_red_card_panel.show()

    # Requirement
    if card_ui.card.requirement == Card.Requirement.NONE:
        requirement_panel.show()
        requirement_panel.add_theme_stylebox_override("panel", CardUI.NONE_STYLEBOX)
        requirement_label.text = "Any"
    elif card_ui.card.requirement == Card.Requirement.MAX:
        requirement_panel.show()
        requirement_panel.add_theme_stylebox_override("panel", CardUI.MAX_STYLEBOX)
        requirement_label.text = "Max %d" % card_ui.card.requirement_number
    elif card_ui.card.requirement == Card.Requirement.EVEN:
        requirement_panel.show()
        requirement_panel.add_theme_stylebox_override("panel", CardUI.EVEN_STYLEBOX)
        requirement_label.text = "Even"
    elif card_ui.card.requirement == Card.Requirement.ODD:
        requirement_panel.show()
        requirement_panel.add_theme_stylebox_override("panel", CardUI.ODD_STYLEBOX)
        requirement_label.text = "Odd"
    elif card_ui.card.requirement == Card.Requirement.RED:
        requirement_panel.show()
        requirement_panel.add_theme_stylebox_override("panel", CardUI.RED_STYLEBOX)
        requirement_label.text = "Red"
    elif card_ui.card.requirement == Card.Requirement.EXACT:
        requirement_panel.show()
        requirement_panel.add_theme_stylebox_override("panel", CardUI.EXACT_STYLEBOX)
        requirement_label.text = "Exact %d" % card_ui.card.requirement_number
    elif card_ui.card.requirement == Card.Requirement.MIN:
        requirement_panel.show()
        requirement_panel.add_theme_stylebox_override("panel", CardUI.MIN_STYLEBOX)
        requirement_label.text = "Min %d" % card_ui.card.requirement_number
    elif card_ui.card.requirement == Card.Requirement.MULTIPLE:
        requirement_panel.show()
        requirement_panel.add_theme_stylebox_override("panel", CardUI.MULTIPLE_STYLEBOX)
        requirement_label.text = "Mult %d" % card_ui.card.requirement_number

    # Bonus requirement
    if card_ui.card.bonus_requirement == Card.Requirement.NONE:
        bonus_effect.hide()
    else:
        bonus_effect.show()
        bonus_effect_label.text = str(card_ui.card.bonus_description_text)
        if card_ui.card.bonus_requirement == Card.Requirement.MAX:
            bonus_requirement_panel.add_theme_stylebox_override("panel", CardUI.BONUS_MAX_STYLEBOX)
            bonus_requirement_label.text = "Max %d" % card_ui.card.bonus_requirement_number
        elif card_ui.card.bonus_requirement == Card.Requirement.EVEN:
            bonus_requirement_panel.add_theme_stylebox_override("panel", CardUI.BONUS_EVEN_STYLEBOX)
            bonus_requirement_label.text = "Even"
        elif card_ui.card.bonus_requirement == Card.Requirement.ODD:
            bonus_requirement_panel.add_theme_stylebox_override("panel", CardUI.BONUS_ODD_STYLEBOX)
            bonus_requirement_label.text = "Odd"
        elif card_ui.card.bonus_requirement == Card.Requirement.RED:
            bonus_requirement_panel.add_theme_stylebox_override("panel", CardUI.BONUS_RED_STYLEBOX)
            bonus_requirement_label.text = "Red"
        elif card_ui.card.bonus_requirement == Card.Requirement.EXACT:
            bonus_requirement_panel.add_theme_stylebox_override("panel", CardUI.BONUS_EXACT_STYLEBOX)
            bonus_requirement_label.text = "Exact %d" % card_ui.card.bonus_requirement_number
        elif card_ui.card.bonus_requirement == Card.Requirement.MIN:
            bonus_requirement_panel.add_theme_stylebox_override("panel", CardUI.BONUS_MIN_STYLEBOX)
            bonus_requirement_label.text = "Min %d" % card_ui.card.bonus_requirement_number
        elif card_ui.card.bonus_requirement == Card.Requirement.MULTIPLE:
            bonus_requirement_panel.add_theme_stylebox_override("panel", CardUI.BONUS_MULTIPLE_STYLEBOX)
            bonus_requirement_label.text = "Mult %d" % card_ui.card.bonus_requirement_number

    card_ui.hide()
    card_ui.disabled = true

    # Set the flag ONLY when actually ready to play
    # DON'T set it here - let card_released_state handle it
    # Global.playing_red_card = true  // REMOVE THIS
    _socketing_in_progress = false


func _on_reset_charged_card():
    # This same signal fires from inside virtually every card's apply_effects() (a generic
    # cleanup call unrelated to red-dice sockets) AND explicitly right after a socketed card
    # is actually played (card_released_state.gd's Global.playing_red_card branch) - only the
    # latter should animate the socket away; every other case still clears it instantly.
    if _flying_charged_card_to_discard:
        return
    if Global.playing_red_card and is_instance_valid(socketed_card_ui):
        _flying_charged_card_to_discard = true
        # Drop the reference NOW, not at the end of the fly tween: the fly only animates
        # card_drop_area visuals and never reads socketed_card_ui. Keeping the pointer
        # alive for the ~1s animation let End Turn's clear_socket "cancel" an already-
        # played card back into the hand (-> its Card added to the discard pile a second
        # time by discard_cards() -> duplicated card next reshuffle), and would let the
        # fly's end-callback null out a NEWLY socketed card dropped in mid-animation.
        socketed_card_ui = null
        Global.charged_card_instance_id = 0
        Global.charged_card_instance_ids.clear()
        _clear_socket_2()
        _fly_charged_card_to_discard()
        return

    # Generic-cleanup emits must NOT wipe a socket that's still legitimately occupied -
    # e.g. playing a Celestial (which plays directly, never socketing) while another card
    # sits in the red socket. Emptying the display here would null the texture (making the
    # red die unrollable) while the socketed card stayed hidden in the hand.
    if charged_card_texture.texture != null and socketed_card_ui == null:
        _set_socket_empty()
   

func _on_change_current_power():
    # Capture BEFORE _set_power_text (which overwrites _last_shown_power): did this emit
    # actually change the power value, or is a card just refreshing its display after
    # charging dice / blocking / dealing damage? Only a real change earns the clang.
    var old_power := _last_shown_power
    var power_changed := Global.roll_value != old_power

    # Power the player GAINED without rolling (Reinforce, Blaze, mech +1, a relic that pays
    # out on a roll...) counts toward the turn's total, exactly like a roll does. Before
    # 2026-08-29 only _apply_roll_result credited power_generated_this_turn, so Parasite and
    # Crescendo - both of which are written as "Power generated this turn" - silently saw
    # rolls only, and playing Reinforce moved neither.
    #
    # ⚠️ This cannot double count rolls: _apply_roll_result credits its own value and then
    # calls _set_power_text, which syncs _last_shown_power, and it never emits this signal.
    # So any rise still visible here is by definition non-roll power.
    #
    # Only RISES count. A reset, a dice-type switch or a Ricochet rewind must not subtract
    # (the rewind restores power_generated_this_turn from its snapshot and re-syncs the text
    # before emitting, so it reaches this line as a zero delta anyway).
    if Global.roll_value > old_power:
        Global.power_generated_this_turn += Global.roll_value - old_power

    _set_power_text(Global.roll_value)
    _check_sigil_trigger()
    Events.hover_playable_cards.emit()
    # Central hook for mech +/- adjustment AND dice-type-switch resets, both of which emit
    # this same signal - no separate call needed at either of those sites.
    _update_dice_aura_charge()
    # Heavy "anvil clang" only when power genuinely changed to a nonzero value - so Reinforce,
    # Blaze, Geomancy, mech +/-, etc. clang, while the ~19 cards that emit this signal only to
    # refresh their display (and the dice-type-switch reset to 0) stay quiet.
    if power_changed and Global.roll_value > 0:
        _play_power_clang()
        # Small hit-stop for support/power cards (Reinforce, Blaze...) - these never call
        # DamageEffect so they had no hit-stop at all before. Scaled by how much the power
        # actually changed, not a flat value - Blaze's +5 should land harder than Reinforce's +2.
        var power_delta := absf(Global.roll_value - old_power)
        Shaker.hit_stop(clampf(power_delta * 0.01, 0.03, 0.1))
        # A power GAIN that happened in the same frame as a card play = the card itself raised
        # Power - give it the same "orbs feed the number" treatment rolls get, scaled up (see
        # _spawn_support_card_orbs). Same-frame is the discriminator: rolls and roll-reactive
        # relics change power on a roll frame, never a card_played frame.
        if Global.roll_value > old_power and Engine.get_process_frames() == _last_card_played_frame:
            _spawn_support_card_orbs(Global.roll_value - old_power)
    else:
        animation_player_power.play("power_change")
    _update_charged_card_description()


# Heavy "anvil clang" impact on the Power number for power-manipulation cards (Reinforce etc.).
# Reads as struck from above: a hard vertical squash, an elastic spring-back that overshoots
# and wobbles like the clang reverberating, plus a metallic flash and a small rotational rattle.
# The clang SFX is played by the cards themselves - this is the matching visual. Settles back to
# the same power-based resting scale as _apply_roll_result so it composes with "the number grows
# with banked power" instead of fighting it.
func _play_power_clang() -> void:
    var rest_scale := clampf(1.0 + Global.roll_value / 130.0, 1.0, 1.25)

    if _power_clang_scale_tween and _power_clang_scale_tween.is_valid():
        _power_clang_scale_tween.kill()
    _power_clang_scale_tween = create_tween()
    _power_clang_scale_tween.tween_property(current_power, "scale", Vector2(rest_scale * 1.45, rest_scale * 0.55), 0.045) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    _power_clang_scale_tween.tween_property(current_power, "scale", Vector2(rest_scale, rest_scale), 0.45) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

    if _power_clang_flash_tween and _power_clang_flash_tween.is_valid():
        _power_clang_flash_tween.kill()
    _power_clang_flash_tween = create_tween()
    _power_clang_flash_tween.tween_property(current_power, "modulate", Color(1.7, 1.55, 1.1, _power_resting_modulate.a), 0.04) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    _power_clang_flash_tween.tween_property(current_power, "modulate", _power_resting_modulate, 0.22) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

    if _power_clang_rattle_tween and _power_clang_rattle_tween.is_valid():
        _power_clang_rattle_tween.kill()
    current_power.rotation = 0.0
    _power_clang_rattle_tween = create_tween()
    _power_clang_rattle_tween.tween_property(current_power, "rotation", deg_to_rad(5.0), 0.04) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _power_clang_rattle_tween.tween_property(current_power, "rotation", deg_to_rad(-3.5), 0.06) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _power_clang_rattle_tween.tween_property(current_power, "rotation", 0.0, 0.14) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_next_roll_determined():
    next_roll_panel.show()
    var path := "res://assets/images/%s%d.png" % [Global.dice_type, Global.next_guaranteed_roll]
    next_roll_texture.texture = load(path)
    # Landing pop: battle.gd flies the picked scout die here and emits this signal on
    # touchdown, so the slot visibly RECEIVES it (scale punch + overbright flash - the
    # panel's modulate propagates to the face texture inside) instead of silently appearing.
    # Focus/Focus+ emit the same signal with no flight and get the same beat.
    next_roll_panel.pivot_offset = next_roll_panel.size / 2.0
    if _next_roll_pop_tween and _next_roll_pop_tween.is_valid():
        _next_roll_pop_tween.kill()
    next_roll_panel.scale = Vector2(0.55, 0.55)
    next_roll_panel.modulate = Color(1.75, 1.75, 1.75, 1.0)
    _next_roll_pop_tween = create_tween()
    _next_roll_pop_tween.tween_property(next_roll_panel, "scale", Vector2(1.14, 1.14), 0.1) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _next_roll_pop_tween.parallel().tween_property(next_roll_panel, "modulate", Color.WHITE, 0.24) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _next_roll_pop_tween.tween_property(next_roll_panel, "scale", Vector2.ONE, 0.12) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    
func _on_battle_started():
    Global.fight_dice_rolled = 0
    Global.blue_dice_bonus_amount_fight = 0
    Global.mech_dice_bonus_amount_fight = 0
    _surprise_rolls_this_fight = 0  # the surprise budget is per fight, not per run
    set_shader_from_global_type()

func set_shader_from_global_type(type: String = Global.dice_type) -> void:
    var new_shader_material : ShaderMaterial

    match type:
        "red":
            new_shader_material = preload("res://scenes/dices/red_dice_shader.tres")
        "blue":
            new_shader_material = preload("res://scenes/dices/blue_dice_shader.tres")
        "giant":
            new_shader_material = preload("res://scenes/dices/giant_dice_shader.tres")
        "evil":
            new_shader_material = preload("res://scenes/dices/evil_dice_shader.tres")
        "magma":
            new_shader_material = preload("res://scenes/dices/magma_dice_shader.tres")
        "even":
            new_shader_material = preload("res://scenes/dices/even_dice_shader.tres")
        "odd":
            new_shader_material = preload("res://scenes/dices/odd_dice_shader.tres")
        "green":
            new_shader_material = preload("res://scenes/dices/green_dice_shader.tres")
        "mech":
            new_shader_material = preload("res://scenes/dices/mech_dice_shader.tres")
        _:
            push_warning("Unknown dice type: %s" % Global.dice_type)
            return

    aura.material = _resolve_aura_material(type, new_shader_material)


# Per-battle cache of recolored aura materials for infused dice types (act-2 dice
# infusions). Instance state on purpose: dice.tscn is re-instantiated every battle, so
# a later run in the same app session can never inherit a stale infused material.
var _infused_aura_materials := {}


# Infused dice get a recolored COPY of their type's aura material. NEVER mutate the
# preloaded shared .tres directly - that's the exact bug the old "charge" animation had
# (see _on_charge_delivered): the 9 per-type ShaderMaterials are shared preloaded
# resources, so writing colors into one repaints it for the rest of the app session.
func _resolve_aura_material(type: String, base_material: ShaderMaterial) -> ShaderMaterial:
    if not Global.is_dice_infused(type):
        return base_material
    if not _infused_aura_materials.has(type):
        var info: Dictionary = DiceInfusions.get_info(type)
        var infused: ShaderMaterial = base_material.duplicate()
        if info.has("aura_magic"):
            infused.set_shader_parameter("magic_color", info["aura_magic"])
        if info.has("aura_accent"):
            infused.set_shader_parameter("accent_color", info["aura_accent"])
        _infused_aura_materials[type] = infused
    return _infused_aura_materials[type]


# Fires on Events.dice_charge_delivered, i.e. when the volley's LAST delivered die LANDS
# in its slot - not when the charge was cast (2026-08-28). Everything else in this game
# that reads as impact follows "projectile lands -> receiver reacts" (the power orbs'
# arrival reaction, the thrown-die bash); the charge pulse was the lone impact-sized effect
# firing at LAUNCH, so it was an announcement with no payoff, over before the eye finished
# following the flying dice to the row. Landing-timed, the phrase becomes a crescendo -
# launch flare, flight, rising plinks, then clack + panel kick + hit-stop + THIS on one
# beat - and the pulse now happens INSIDE the volley's hit-stop instead of being long dead
# by it (the same freeze-frame miss the slash rework had to fix). Launch-time
# responsiveness is carried by the delivery's own launch flare and sound (dice_interface).
# The signal is emitted exactly once per volley, so nothing here needs its own de-dup.
func _on_charge_delivered(charged_type: String, count: int) -> void:
    if count <= 0:
        return
    # Two DIFFERENT claims, deliberately split (Julien, 2026-08-14) - conflating them is
    # what made the old argless signal lie:
    #   "energy just erupted"      -> ALWAYS true of a charge. The big die is the screen's
    #                                 centre of gravity, so it has to carry this or the
    #                                 whole event hides inside the little slot row.
    #   "THIS die absorbed dice"   -> only true when the charged type IS the active type.
    # So everything below up to the early-return is universal, tinted by the CHARGED type
    # (never by dice_type) - it says "orange energy just went somewhere", and the delivery
    # flying to the orange slot answers where. charge_heat is a type-neutral warm gold, so
    # surging it claims energy without claiming a type.
    #
    # This universal half is the ORIGINAL charge beat (aura pulse + inward-converging
    # particle ring) promoted to fire on every charge and tinted by the charged type,
    # PLUS one contained wavefront (2026-08-25, _spawn_charge_pulse below - Julien asked
    # for the eruption to be felt). A big screen-crossing shockwave was tried in 2026-08
    # and rejected: "too much intensity & too fast". The wavefront must stay a contained
    # pulse AT the die - do not grow its travel far or stack more fronts.
    #
    # ---- WIND-UP: landing -> CHARGE_PULSE_ANTICIPATION ----
    # The converging particle ring starts NOW and is the anticipation the player actually
    # sees; the eruption is scheduled one beat later (see the round-3 note on the consts).
    # Nothing here may be loud - if the wind-up competes with the bang there is no bang.
    var burst_material := gpu_particles_2d.process_material as ParticleProcessMaterial
    if burst_material:
        burst_material.color = DicePalette.burst(charged_type, 0.35)
    # Time-scaled so the ring lands ON the detonation instead of still falling inward
    # after it. speed_scale, not a lifetime edit: lifetime lives in the authored .tscn
    # sub-resource and the emitter is re-used every volley.
    gpu_particles_2d.speed_scale = CHARGE_PARTICLE_CONVERGE \
            / maxf(CHARGE_PULSE_ANTICIPATION, 0.05)
    # restart(), not `emitting = true`: on a one_shot emitter that assignment is a no-op
    # while the previous burst is still alive (0.45s lifetime), so rapid multi-die
    # volleys were rendering ONE converging ring for the whole volley.
    gpu_particles_2d.restart()

    # ---- DETONATION, scheduled ----
    # Its own tween so a second volley landing during the wind-up simply queues its own
    # bang; the gust cooldown is what protects the additive layer from stacked fronts.
    # Tweens created on this node die with it, so nothing fires into a freed die.
    var boom := create_tween()
    boom.tween_interval(CHARGE_PULSE_ANTICIPATION)
    boom.tween_callback(_detonate_charge.bind(charged_type, count))

    # Charge flash on the aura itself. charge_heat ALONE is invisible: the shader blends
    # it into rgb at 22% weight only (dice_glow.gdshader), never into alpha or reach, so
    # the "pulse" was a slight hue shift ("we don't even see the pulse anymore", Julien
    # 2026-08-18). The old animation tracks were visible because they swung accent_color's
    # luminance AND alpha - but they were removed for a real reason (they wrote the BLUE
    # shader's authored accent into whatever shared per-type ShaderMaterial was active,
    # corrupting it until restart). So the flare is carried by power_intensity + glow_reach
    # instead: real brightness and spread, zero color writes, and both params are already
    # re-derived from banked power by _update_dice_aura_charge() on every event, so a
    # transient overshoot is structurally self-healing where accent_color was not.
    var aura_material := aura.material as ShaderMaterial
    if aura_material:
        if _charge_flash_tween and _charge_flash_tween.is_valid():
            _charge_flash_tween.kill()
        _charge_flash_tween = create_tween()
        # INHALE first (2026-08-29). A silent gap between the landing and the bang reads
        # as lag; a gap in which the light visibly draws IN reads as a wind-up. Dimming
        # also buys the flash its contrast back - it now rises from below the resting
        # level instead of from wherever banked power had already parked it.
        var intensity_now := _shader_f(aura_material, "power_intensity", AURA_INTENSITY_REST)
        var reach_now := _shader_f(aura_material, "glow_reach", AURA_REACH_REST)
        var dip := _charge_flash_tween.tween_property(
            aura_material, "shader_parameter/power_intensity",
            intensity_now * CHARGE_AURA_INHALE, CHARGE_PULSE_ANTICIPATION)
        if dip:
            dip.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        var reach_dip := _charge_flash_tween.parallel().tween_property(
            aura_material, "shader_parameter/glow_reach",
            reach_now * 0.92, CHARGE_PULSE_ANTICIPATION)
        if reach_dip:
            reach_dip.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        var heat_rise := _charge_flash_tween.tween_property(
            aura_material, "shader_parameter/charge_heat", 1.0, 0.12)
        if heat_rise:
            heat_rise.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        var intensity_rise := _charge_flash_tween.parallel().tween_property(
            aura_material, "shader_parameter/power_intensity", AURA_INTENSITY_MAX, 0.12)
        if intensity_rise:
            intensity_rise.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        # Only a SMALL reach bump. Slamming this to AURA_REACH_MAX inflated the aura into
        # the exact band the travelling front crosses, at the exact moment it crosses it -
        # measured on round 1, the two merged into one fat halo and the wave was lost
        # inside it. The flash stays a brightness event at the SOURCE; spread belongs to
        # the front. (power_intensity above still goes to max - that part reads fine.)
        var reach_rise := _charge_flash_tween.parallel().tween_property(
            aura_material, "shader_parameter/glow_reach",
            minf(reach_now + AURA_CHARGE_FLASH_REACH_BUMP, AURA_REACH_MAX), 0.12)
        if reach_rise:
            reach_rise.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        _charge_flash_tween.tween_interval(0.3)
        # Settles heat/intensity/reach back to the banked-power level in one place.
        _charge_flash_tween.tween_callback(_update_dice_aura_charge)
    # The emanation tongues share the same absorb beat: heat + a surge flare that decays
    # after the hold. charge_heat is settled back by the _update_dice_aura_charge callback
    # above; surge lives on the SAME tracked tween the roll-landing flare uses, so the two
    # triggers restart each other instead of fighting over the parameter.
    var emanation_material := emanation.material as ShaderMaterial
    if emanation_material:
        if _emanation_surge_tween and _emanation_surge_tween.is_valid():
            _emanation_surge_tween.kill()
        _emanation_surge_tween = create_tween()
        # Same wind-up gap as the aura - the licks flare WITH the front, not before it.
        _emanation_surge_tween.tween_interval(CHARGE_PULSE_ANTICIPATION)
        var em_rise := _emanation_surge_tween.tween_property(
            emanation_material, "shader_parameter/surge", 1.0, 0.12)
        if em_rise:
            em_rise.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        _emanation_surge_tween.parallel().tween_property(
            emanation_material, "shader_parameter/charge_heat", 1.0, 0.12)
        _emanation_surge_tween.tween_interval(0.3)
        _emanation_surge_tween.tween_property(
            emanation_material, "shader_parameter/surge", 0.0, EMANATION_SURGE_DECAY_TIME) \
            .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

    # ---- Everything past here is the OWNERSHIP claim: this die really did gain dice. ----
    # Evaluated at LANDING time, so switching the active die mid-flight decides which claim
    # fires. That is deliberate and more honest than snapshotting the type at cast time:
    # the absorb ceremony says "the die you are looking at just took these in", and if you
    # walked away from that die before they arrived, it did not. Do not snapshot.
    if charged_type != dice_type:
        return

    # Beats are timed so the die "absorbs" the energy exactly when the inward-converging
    # particles reach its center: anticipation squash + hold while the ring collapses,
    # then a punch + flash + power pulse on impact, then settle. Tighter overall than the
    # old scattered fountain so the charge no longer upstages the hit that triggered it.
    #
    # This IS the detonation instant now (2026-08-29). It always was a squash-then-punch,
    # but its punch used to land 0.3s AFTER the wavefront had already come and gone, so
    # the charge read as two unrelated events. Sharing one constant with the wavefront is
    # what makes them a single bang - do not fork these two timings again.
    var converge_time := CHARGE_PULSE_ANTICIPATION

    # --- Scale: anticipation squash -> hold while energy converges -> absorb-punch -> settle ---
    # The absorb punch scales with HOW MANY dice landed in the active pool (Charge 1 vs
    # Charge 3+ should not be pixel-identical - same ladder rule as the roll feel pass).
    var punch := 1.16 + 0.04 * float(clampi(count, 1, 4))
    var scale_tween := create_tween()
    scale_tween.tween_property(dice_display, "scale", Vector2(0.9, 0.9), 0.08) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    scale_tween.tween_interval(converge_time - 0.08)
    scale_tween.tween_property(dice_display, "scale", Vector2(punch, punch), 0.07) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    scale_tween.tween_property(dice_display, "scale", Vector2(1.0, 1.0), 0.22) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

    # --- Brightness flash on impact ---
    var flash_tween := create_tween()
    flash_tween.tween_interval(converge_time)
    flash_tween.tween_property(dice_display, "modulate", Color(2.4, 2.4, 2.4, 1.0), 0.06) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    flash_tween.tween_property(dice_display, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.22) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

    # --- Power label sympathetic pulse on impact ---
    var power_tween := create_tween()
    power_tween.tween_interval(converge_time)
    power_tween.tween_property(current_power, "scale", Vector2(1.3, 1.3), 0.07) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    power_tween.tween_property(current_power, "scale", Vector2(1.0, 1.0), 0.15) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    
# Reading an unassigned uniform returns null, which throws when it lands in a typed float
# (the documented "shader params must be seeded" trap) - so every read of a value we intend
# to tween FROM goes through here.
func _shader_f(mat: ShaderMaterial, param: String, fallback: float) -> float:
    var v = mat.get_shader_parameter(param)
    return fallback if v == null else float(v)


# The bang itself, one CHARGE_PULSE_ANTICIPATION after the dice landed in the row. The aura
# flash and the emanation surge are already scheduled tweens by the time this runs; what is
# left here is everything that cannot be expressed as a delayed tweener.
func _detonate_charge(charged_type: String, count: int) -> void:
    animation_player.play("charge")  # aura scale kick (peak ~0.1s, settle ~0.55s)
    _spawn_charge_pulse(charged_type, count)
    # The volley freeze lives here rather than on the arrival (moved out of
    # dice_interface, 2026-08-29): the freeze has to punctuate the loudest frame, and the
    # loudest frame is this one. Landing keeps its clack, panel kick and slot flash.
    var now := Time.get_ticks_msec()
    if now - _last_charge_hit_stop_ms >= CHARGE_HIT_STOP_COOLDOWN_MS:
        _last_charge_hit_stop_ms = now
        Shaker.hit_stop(clampf(0.06 + 0.014 * float(count), 0.06, 0.13),
                CHARGE_HIT_STOP_SCALE)


# The wavefront half of the universal charge beat: the die's own light field getting blown
# outward. Drives gust_radius (constant-width front, in px beyond the die silhouette) and
# gust amplitude through dice_emanation.gdshader, so the licks lean/flare as it passes and
# a bright front rides out along the silhouette. Tinted by the CHARGED type, pulled well
# toward hot white - a blue front inside a blue field is invisible at any brightness.
func _spawn_charge_pulse(charged_type: String, count: int) -> void:
    if charge_pulse_mode == 3:
        return
    var now := Time.get_ticks_msec()
    if now - _last_charge_pulse_ms < CHARGE_PULSE_COOLDOWN_MS:
        return
    _last_charge_pulse_ms = now
    # "punchy" (the live mode) used to mean FASTER; since 2026-08-29 it means HEAVIER -
    # wider reach and a stronger front over the same, longer travel. Mode 0 keeps a lighter,
    # quicker version so the bake-off plate still shows two distinct weights.
    var punchy := charge_pulse_mode == 2
    var travel_time := CHARGE_GUST_TIME * (1.0 if punchy else 0.85)
    var reach := CHARGE_GUST_REACH * (1.12 if punchy else 1.0)
    # Cap above 1.0 so the count ladder still has somewhere to go - see the gust uniform's
    # range note in dice_emanation.gdshader.
    var peak := minf(CHARGE_GUST_PEAK * (1.12 if punchy else 1.0)
            + CHARGE_GUST_COUNT_STEP * float(clampi(count, 1, 4) - 1), CHARGE_GUST_PEAK_CAP)
    _fire_gust(DicePalette.burst(charged_type, 0.55), peak, reach, travel_time,
            CHARGE_GUST_HOLD)

    if charge_pulse_mode == 1:
        _spawn_charge_ring_sprite(charged_type, count)


# The wavefront itself, shared by the charge beat and by the overcharge leaks so the two can
# never drift apart in shape - only in colour, amplitude, reach and speed. Killing whatever is
# already in flight is part of the contract: two live fronts on an additive layer overexpose.
func _fire_gust(color: Color, peak: float, reach: float, travel_time: float,
        hold: float = 0.0) -> void:
    var mat := emanation.material as ShaderMaterial
    if mat == null:
        return
    mat.set_shader_parameter("gust_color", color)

    for t: Tween in _charge_gust_tweens:
        if t and t.is_valid():
            t.kill()
    _charge_gust_tweens.clear()

    # Radius and amplitude ride SEPARATE tweens on purpose: the front must keep advancing
    # while it dims. Chaining them onto one tween would gate the decay behind the travel
    # (Tween steps wait for the longest tweener in the step), which is what produces a
    # "hold at full brightness then vanish" pop instead of a wave melting as it goes.
    var radius_tween := create_tween()
    # QUAD, not EXPO: EXPO puts ~90% of the distance in the first fifth of the time, so the
    # front teleports and then loiters. QUAD is fast-then-settling but stays watchable.
    radius_tween.tween_property(mat, "shader_parameter/gust_radius", reach, travel_time) \
            .from(CHARGE_GUST_START).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    var amp_tween := create_tween()
    amp_tween.tween_property(mat, "shader_parameter/gust", peak, CHARGE_GUST_RISE) \
            .from(0.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    # Optional HOLD at full amplitude before the decay starts. The radius keeps advancing
    # underneath it (separate tween), so the front stays bright across the fast opening
    # stretch of its travel - that is the difference between a shockwave and a flicker.
    # Overcharge leaks pass hold = 0 and keep their old melting shape.
    if hold > 0.0:
        amp_tween.tween_interval(hold)
    amp_tween.tween_property(mat, "shader_parameter/gust", 0.0,
            maxf(travel_time - CHARGE_GUST_RISE - hold, 0.05)) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    _charge_gust_tweens = [radius_tween, amp_tween]


# Optional companion sprite band (mode 1 only): a thin bright rim riding just ahead of the
# shader gust, for a harder-edged "crack" on top of the soft light wave.
func _spawn_charge_ring_sprite(charged_type: String, count: int) -> void:
    var die_panel := get_node_or_null("Panel") as Panel
    if die_panel == null:
        return
    var center := die_panel.position + die_panel.size * 0.5
    var band_px := DicePalette.die_ring_texture().get_width() * 0.5 \
            * DicePalette.DIE_RING_BAND_FRACTION
    # Spawn scale is DERIVED from the panel's real rect, never hardcoded - a resized die
    # can't silently re-bury the band's brightest moment under the opaque plate.
    var start_scale := (maxf(die_panel.size.x, die_panel.size.y) * 0.5 + 4.0) / band_px
    var alpha := minf(CHARGE_RING_ALPHA
            * (1.0 + 0.08 * float(clampi(count, 1, 4) - 1)), 0.5)
    _spawn_charge_pulse_ring(center, DicePalette.burst(charged_type, 0.5), start_scale,
            start_scale * CHARGE_RING_TRAVEL_MULT, alpha, CHARGE_RING_TIME, 0.0)


func _spawn_charge_pulse_ring(center: Vector2, tint: Color, start_scale: float,
        end_scale: float, peak_alpha: float, travel_time: float, delay: float) -> void:
    var ring := Sprite2D.new()
    ring.texture = DicePalette.die_ring_texture()
    ring.material = DicePalette.additive_material()
    ring.position = center
    ring.scale = Vector2(start_scale, start_scale)
    ring.modulate = Color(tint.r, tint.g, tint.b, 0.0)  # invisible until its delay elapses
    ring.add_to_group("charge_pulse_ring")
    add_child(ring)
    # Under the whole die cluster via TREE ORDER (right after Emanation, before Panel) -
    # never a negative z_index, which would drop it below the opaque battle Background.
    move_child(ring, 1)
    var travel := create_tween()
    if delay > 0.0:
        travel.tween_interval(delay)
    # QUAD, not EXPO: the front has to be SEEN traveling, not teleport then linger.
    travel.tween_property(ring, "scale", Vector2(end_scale, end_scale), travel_time) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) \
            .from(Vector2(start_scale, start_scale))
    travel.tween_callback(ring.queue_free)
    var fade := create_tween()
    if delay > 0.0:
        fade.tween_interval(delay)
    # Alpha on its OWN tween: snap to peak in a blink, then start melting immediately
    # (EASE_IN keeps the band readable through mid-travel, gone right as it stops). A
    # peak held through the whole expansion is the additive wash trap.
    fade.tween_property(ring, "modulate:a", peak_alpha, 0.05) \
            .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).from(0.0)
    fade.tween_property(ring, "modulate:a", 0.0, travel_time - 0.05) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _on_put_ink_on_dice():
    if not ink_is_on:
        ink_animation.play("ink_spray")
    dice_roll_player.stream = load("res://splatsound.mp3")
    dice_roll_player.play()
    ink_is_on = true
    Global.ink_active = true
    Events.hover_playable_cards.emit()

func _on_remove_ink_from_dice():
    if ink_is_on:
        ink_animation.play("ink_fade")
    ink_is_on = false
    Global.ink_active = false
    Events.hover_playable_cards.emit()
    # Overcharge freezes rather than climbing while inked, so it needs an explicit nudge to
    # catch up with whatever was banked under the ink - no roll may follow for a while.
    _update_overcharge()
    
func _on_display_next_roll_modifier():
    if Global.next_roll_modifier > 0:
        next_roll_bonus_panel.show()
        next_roll_bonus_label.text = "+" + str(Global.next_roll_modifier)

    

func _on_cancel_red_card_pressed() -> void:
    # Check if there's actually a card socketed
    if socketed_card_ui == null:
        print("No card to cancel")
        return
    
    # Clear the socket display
    _set_socket_empty()
    
    # Re-enable the card in the hand
    if is_instance_valid(socketed_card_ui):
        socketed_card_ui.show()
        socketed_card_ui.disabled = false
        print("Card returned to hand: ", socketed_card_ui.card.name)
        Events.fan_hand_requested.emit()
    
    # CRITICAL: Reset the global flags so new cards can be socketed
    Global.playing_red_card = false
    Global.charged_card_instance_id = 0
    Global.charged_card_instance_ids.clear()
    _clear_socket_2()
    
    # Clear our reference
    socketed_card_ui = null
    
    # Play feedback sound
    SFXPlayer.play(Global.sfx_click)

func _on_clear_socket():
    _on_cancel_red_card_pressed()

func update_roll_history_ui():
    if Global.roll_history.is_empty() or ink_is_on:
        roll_history.text = ""
        roll_history.visible = false  # don't leave an empty backing pill floating there
        return

    # The chain rendered as MINI DIE FACES instead of plain "4, 5" text - the stacking
    # story made visible (2026-07-24, Julien's pick from the combat quick-wins list).
    # History entries are NATURAL faces of the ACTIVE type (roll_history is cleared on
    # every reset AND type switch, and infusion overrides are subsets of real faces), so
    # a face texture exists for every entry - verified for all 9 types. The text branch
    # is a safety net for any future entry without art, not an expected path.
    # Lives CENTERED UNDER the ROLL button (moved 2026-07-24: its old spot right of the
    # die was the same rectangle as NextRollPanel, so a scouted face stacked on top of
    # the history faces) - the trail sits below the die, the guaranteed NEXT roll keeps
    # the marquee spot beside it.
    roll_history.visible = true
    roll_history.clear()
    roll_history.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
    var first := true
    for value in Global.roll_history:
        if not first:
            roll_history.add_text(" ")
        first = false
        var tex_path := "res://assets/images/%s%d.png" % [Global.dice_type, value]
        if ResourceLoader.exists(tex_path):
            roll_history.add_image(load(tex_path), HISTORY_FACE_SIZE, HISTORY_FACE_SIZE)
        else:
            roll_history.push_color(DicePalette.accent(Global.dice_type).lerp(Color.WHITE, 0.35))
            roll_history.add_text(str(value))
            roll_history.pop()
    roll_history.pop()  # close the centered paragraph

func _check_sigil_trigger() -> void:
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if enemy.status_handler._has_status("sigil"):
            var sigil = enemy.status_handler._get_status("sigil")
            if Global.roll_value == sigil.stacks:
                Global.blue_dice_current_amount += 1
                Events.dice_amount_changed.emit()
                Events.dice_charged.emit("blue", 1)


func _on_mech_increase_pressed() -> void:
    if mech_adjustments_used >= _mech_adjustments_allowed() or Global.roll_value == 0:
        return
    mech_adjustments_used += 1
    Global.roll_value += 1
    SFXPlayer.play(load("res://sounds/blacksmithsound.wav"))
    Events.change_current_power.emit()
    _mech_increase_tween = _play_mech_arrow_punch(mech_increase, _mech_increase_tween)
    _update_mech_buttons()

func _on_mech_decrease_pressed() -> void:
    if mech_adjustments_used >= _mech_adjustments_allowed() or Global.roll_value == 0:
        return
    mech_adjustments_used += 1
    Global.roll_value -= 1
    SFXPlayer.play(load("res://sounds/blacksmithsound.wav"))
    Events.change_current_power.emit()
    _mech_decrease_tween = _play_mech_arrow_punch(mech_decrease, _mech_decrease_tween)
    _update_mech_buttons()

# Clockwork infusion (Mech) lets you adjust twice per roll instead of once.
func _mech_adjustments_allowed() -> int:
    return 2 if Global.is_dice_infused("mech") else 1


# --- Ricochet reroll --------------------------------------------------------------------
func _on_ricochet_reroll_pressed() -> void:
    if not _can_ricochet_reroll():
        return
    ricochet_rerolls_used += 1
    _ricochet_restore_snapshot()
    _ricochet_reroll_tween = _play_mech_arrow_punch(ricochet_button, _ricochet_reroll_tween)
    _update_ricochet_button()

    # Hand the reroll to the NORMAL roll path - same builder, same _on_roll_landed (which kills
    # _roll_flip_tween on its first line). A bespoke mini-animation here is exactly what caused
    # the 0.2.7 face/value mismatch: two paths writing the shown face with no ordering between
    # them. The flag is what makes roll_dice() treat this as a reroll rather than a new roll;
    # _apply_roll_result clears it once the result has landed.
    Global.ricochet_reroll_active = true
    roll_dice()


# "odd" (Ricochet) rerolls natively; a graft card (the Blue reroll blessing) adds its type
# to Global.reroll_types.
func _type_can_reroll(type: String) -> bool:
    return type == "odd" or Global.reroll_types.has(type)


func _can_ricochet_reroll() -> bool:
    return _type_can_reroll(dice_type) \
            and not _roll_in_progress \
            and ricochet_rerolls_used < _ricochet_rerolls_allowed() \
            and not _ricochet_snapshot.is_empty() \
            and not Global.roll_history.is_empty()


# Puts back exactly what the discarded roll changed. Scope is deliberate and matches the design
# call: Power (banked + this turn's total), the history entry and the shown face are rewound;
# relic triggers, per-roll counters and the Bulwark infusion are NOT, because by the time this
# button can be clicked they have already dealt damage and granted Block that no rewind could
# take back honestly.
func _ricochet_restore_snapshot() -> void:
    if _ricochet_snapshot.is_empty():
        return
    Global.roll_value = _ricochet_snapshot["roll_value"]
    Global.power_generated_this_turn = _ricochet_snapshot["power_generated_this_turn"]
    # ⚠️ Typed local, NOT `Global.roll_history = _ricochet_snapshot[...].duplicate()`.
    # A Dictionary subscript is Variant, and assigning a Variant into Global.roll_history
    # (which every other writer assigns a plain `[]` to) degrades the type the analyzer
    # infers for that autoload member from Array to Variant PROJECT-WIDE. That silently
    # breaks every `:=` that reads it elsewhere - dice.gd's own chain_depth/rolled_values
    # and both Dice Slap cards - with "Cannot infer the type ..." parse errors pointing at
    # innocent pre-existing lines. Naming the type here keeps the member's inference intact.
    var restored_history: Array = _ricochet_snapshot["roll_history"]
    Global.roll_history = restored_history.duplicate()
    _power_tier_active = _ricochet_snapshot["power_tier_active"]

    # A Boost consumed by the discarded roll comes back with it - "fully undone" has to mean
    # undone, not burned. Note the asymmetry with a Scout/Focus/Lucky guarantee, which stays
    # spent (Julien's call): a refunded guarantee would force the SAME face again and make the
    # reroll a no-op, whereas a refunded flat modifier applies to whichever result you keep.
    Global.next_roll_modifier = _ricochet_snapshot["next_roll_modifier"]
    if Global.next_roll_modifier > 0:
        _on_display_next_roll_modifier()
    else:
        next_roll_bonus_panel.hide()

    _set_power_text(Global.roll_value)
    current_power.modulate.a = 0.4 if Global.roll_value == 0 else 1.0
    _update_power_float()
    _update_dice_aura_charge()
    update_roll_history_ui()
    Events.change_current_power.emit()
    Events.hover_playable_cards.emit()


func _update_ricochet_button() -> void:
    if not is_instance_valid(ricochet_section):
        return
    ricochet_section.visible = _type_can_reroll(dice_type)
    var usable := _can_ricochet_reroll()
    ricochet_section.modulate.a = 1.0 if usable else 0.3
    ricochet_button.disabled = not usable


func _on_ricochet_button_mouse_entered() -> void:
    if ricochet_button.disabled:
        return
    if _ricochet_reroll_tween and _ricochet_reroll_tween.is_valid():
        _ricochet_reroll_tween.kill()
    _ricochet_reroll_tween = create_tween()
    _ricochet_reroll_tween.tween_property(ricochet_button, "scale", MECH_ARROW_HOVER_SCALE,
            MECH_ARROW_HOVER_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_ricochet_button_mouse_exited() -> void:
    if _ricochet_reroll_tween and _ricochet_reroll_tween.is_valid():
        _ricochet_reroll_tween.kill()
    _ricochet_reroll_tween = create_tween()
    _ricochet_reroll_tween.tween_property(ricochet_button, "scale", Vector2.ONE,
            MECH_ARROW_HOVER_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _update_mech_buttons() -> void:
    var usable = mech_adjustments_used < _mech_adjustments_allowed() and Global.roll_value > 0
    mech_section.modulate.a = 1.0 if usable else 0.3
    mech_increase.disabled = not usable
    mech_decrease.disabled = not usable


# Quick squash-and-recover "punch" on a successful ±1 adjustment - the only feedback before
# this was the click SFX, nothing on the arrow itself.
func _play_mech_arrow_punch(button: TextureButton, existing_tween: Tween) -> Tween:
    if existing_tween and existing_tween.is_valid():
        existing_tween.kill()
    var tween := create_tween()
    tween.tween_property(button, "scale", MECH_ARROW_PUNCH_SCALE, MECH_ARROW_PUNCH_DURATION) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(button, "scale", Vector2.ONE, MECH_ARROW_PUNCH_DURATION) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    return tween


# Hover pop, matching the flat/punchy timing already used for the map room and dice shop
# hover feedback - gated on `disabled` so a spent arrow (dimmed, non-clickable) doesn't still
# pop up on hover, which would misleadingly suggest it's still usable.
func _on_mech_increase_mouse_entered() -> void:
    if mech_increase.disabled:
        return
    if _mech_increase_tween and _mech_increase_tween.is_valid():
        _mech_increase_tween.kill()
    _mech_increase_tween = create_tween()
    _mech_increase_tween.tween_property(mech_increase, "scale", MECH_ARROW_HOVER_SCALE, MECH_ARROW_HOVER_DURATION) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_mech_increase_mouse_exited() -> void:
    if _mech_increase_tween and _mech_increase_tween.is_valid():
        _mech_increase_tween.kill()
    _mech_increase_tween = create_tween()
    _mech_increase_tween.tween_property(mech_increase, "scale", Vector2.ONE, MECH_ARROW_HOVER_DURATION) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_mech_decrease_mouse_entered() -> void:
    if mech_decrease.disabled:
        return
    if _mech_decrease_tween and _mech_decrease_tween.is_valid():
        _mech_decrease_tween.kill()
    _mech_decrease_tween = create_tween()
    _mech_decrease_tween.tween_property(mech_decrease, "scale", MECH_ARROW_HOVER_SCALE, MECH_ARROW_HOVER_DURATION) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_mech_decrease_mouse_exited() -> void:
    if _mech_decrease_tween and _mech_decrease_tween.is_valid():
        _mech_decrease_tween.kill()
    _mech_decrease_tween = create_tween()
    _mech_decrease_tween.tween_property(mech_decrease, "scale", Vector2.ONE, MECH_ARROW_HOVER_DURATION) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _spawn_roll_popup(value: int) -> void:
    if ink_is_on:
        return
    var popup = Label.new()
    popup.text = "+" + str(value)

    # Match the dice type color
    var color := DicePalette.accent(Global.dice_type)

    # Size scales a bit with the roll value, so a big roll's "+X" actually reads as bigger
    var font_size := clampi(28 + value, 28, 44)
    popup.modulate = color
    popup.add_theme_font_override("font", preload("res://fonts/LuckiestGuy-Regular.ttf"))
    popup.add_theme_font_size_override("font_size", font_size)
    popup.add_theme_constant_override("outline_size", 4)
    popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
    # Above the slot row (z 5): the popup rises from the Power number straight through the
    # row's band, and at the default z 0 it slid behind it.
    popup.z_index = 12
    popup.position = current_power.position + Vector2(0, -10)
    popup.pivot_offset = Vector2(20, font_size / 2.0)
    popup.scale = Vector2(0.3, 0.3)
    add_child(popup)

    # Entrance punch before the existing rise-and-fade
    var punch_in := create_tween()
    punch_in.tween_property(popup, "scale", Vector2(1.25, 1.25), 0.08) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    punch_in.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.08) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(popup, "position", popup.position + Vector2(0, -40), 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    tween.tween_property(popup, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
    tween.chain().tween_callback(popup.queue_free)

# Resolves the actual face texture for a historical roll VALUE (not the die's current face) -
# every dice type uses "<type><value>.png", including evil's 0 face ("evil0.png", see
# evil_faces above). Mirrors the same lookup _apply_roll_result() uses, just keyed by value
# instead of by roll_index into a faces array, since roll_history only stores values.
func _get_dice_face_texture(value: int) -> Texture2D:
    return _get_dice_face_texture_for(dice_type, value)


# Same lookup as above but for an explicit type rather than this Dice's own active dice_type -
# needed for flourishes that show icons spanning MULTIPLE dice types at once (e.g. All In's
# consumed-dice display, which can include Blue, Evil, Giant... all in the same burst).
func _get_dice_face_texture_for(type: String, value: int) -> Texture2D:
    if type == "evil" and value == 0:
        return load("res://assets/images/evil0.png")
    return load("res://assets/images/" + type + str(value) + ".png")


# For refuel cards: the dice you actually rolled this turn (each showing ITS OWN rolled face,
# from rolled_values - not all copies of the die's current face) pop out of the played card,
# rise to hover above it, float briefly, then fly back into the die - showing the rolled dice
# being returned to your pool. Card position is where card_ui.play() stashed it. Returns the
# LAST icon's Tween (or null if nothing was spawned) so the caller can await its completion
# for exact sync, rather than a separately-computed duration estimate that could drift out of
# sync if the timing constants above are ever tuned without also updating that estimate.
#
# Spawned on ui_layer (BattleUI, a CanvasLayer), NOT as a child of this Dice control - the
# played card is ALSO reparented onto ui_layer during its fly-to-discard animation and given
# z_index=100 there. CanvasLayers composite as fully separate passes independent of z_index,
# so icons parented under Dice (base layer) could never render above the card regardless of
# z_index; they'd stay hidden behind it for their whole rise/hover phase. Living on the same
# CanvasLayer is what makes the z_index comparison below meaningful at all.
func _spawn_refuel_return(rolled_values: Array) -> Tween:
    if rolled_values.is_empty():
        return null
    var parent_layer := get_tree().get_first_node_in_group("ui_layer")
    if not parent_layer:
        return null
    var n := mini(rolled_values.size(), REFUEL_RETURN_MAX_ICONS)
    var die_center := dice_display.get_global_rect().get_center()
    var origin := Global.last_played_card_position
    if origin == Vector2.ZERO:
        origin = die_center  # fallback: no known card origin, just pop at the die

    var last_flight: Tween = null
    for i in n:
        var icon := TextureRect.new()
        icon.texture = _get_dice_face_texture(rolled_values[i])
        # A TextureRect renders its texture at NATIVE size unless expand_mode lets .size drive
        # it - without this the die face draws at full source resolution (huge). Match the main
        # die's setup (EXPAND_IGNORE_SIZE + KEEP_ASPECT_CENTERED).
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.custom_minimum_size = Vector2(60, 60)
        icon.size = Vector2(60, 60)
        icon.pivot_offset = icon.size / 2.0
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        icon.z_index = 150  # above the flying card's z_index=100, same CanvasLayer
        parent_layer.add_child(icon)

        var spawn_pos := origin + Vector2(randf_range(-16.0, 16.0), randf_range(-10.0, 10.0))
        # Hover spot: above where the card was (clears the card's own body, and its top edge
        # too once the card itself has started rising during its own play-out animation),
        # fanned out horizontally per-icon so multiple dice read as distinct, not stacked.
        var hover_pos := origin + Vector2(lerpf(-50.0, 50.0, float(i) / maxf(1.0, n - 1)), -100.0)
        var target_pos := die_center + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
        icon.global_position = spawn_pos - icon.size / 2.0
        icon.scale = Vector2.ZERO

        var flight := create_tween()
        flight.tween_interval(REFUEL_RETURN_STAGGER * i)

        # 1. Pop out of the card and rise to the hover spot together.
        flight.tween_property(icon, "scale", Vector2.ONE, REFUEL_RETURN_RISE) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        flight.parallel().tween_property(icon, "global_position", hover_pos - icon.size / 2.0, REFUEL_RETURN_RISE) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

        # 2. Float at the hover spot for a beat - a gentle up/down drift (not a frozen pause)
        # so it reads as floating, giving the player a moment to register these are the dice
        # they just rolled.
        flight.tween_property(icon, "global_position:y", hover_pos.y - icon.size.y / 2.0 - REFUEL_RETURN_HOVER_BOB, REFUEL_RETURN_HOVER * 0.5) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        flight.tween_property(icon, "global_position:y", hover_pos.y - icon.size.y / 2.0, REFUEL_RETURN_HOVER * 0.5) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

        # 3. Then fly to the die (EASE_IN so it accelerates in, like being pulled), shrinking
        # + fading as it arrives so it "merges" rather than just stopping.
        flight.tween_property(icon, "global_position", target_pos - icon.size / 2.0, REFUEL_RETURN_FLIGHT) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        flight.parallel().tween_property(icon, "scale", Vector2(0.3, 0.3), REFUEL_RETURN_FLIGHT) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        flight.parallel().tween_property(icon, "modulate:a", 0.0, REFUEL_RETURN_FLIGHT) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        flight.chain().tween_callback(icon.queue_free)
        last_flight = flight

    return last_flight


# Thrown-dice cards (Meteor, Fastball, Cursed Toss, Pixie Volley, Dice Avalanche, All In +
# the support throws Windfall/Rampart/Kickstart): each throw is a mini-story synced to the
# effect the card scheduled via Card._land_thrown_die / its own timer. Both sides use
# Global.DICE_THROW_FLIGHT_TIME as the TOTAL time from emit to landing and
# Global.dice_throw_volley_stagger() as the per-die spacing - every beat below is carved
# OUT of that budget, never added on top, so retiming only ever means touching the
# Global constants (every card stays in sync automatically).
# Enemy-targeted dice are a 4-beat BASH (Julien, 2026-07-24: sequenced "bam bam bam",
# each roll readable before it hits):
#   1. WINDUP - the die pops out of the played card and hangs above it, tumbling faces,
#      coiling (vertical stretch) right before launch. Anticipation.
#   2. ASCENT - whip-whoosh + recoil motes, then a decelerating lob UP to an apex right
#      above the target (clamped below its intent icon): still tumbling, swelling as it
#      rises, spin settling to upright exactly at the crest.
#   3. HANG - the tumble stops and the die SNAPS to its final face with a glint + pop,
#      hanging raised over the enemy for a beat: the "read the roll" moment. The face
#      never changes again - the player tracks "a 6 is coming down" into the hit.
#   4. SLAM - hard accelerating dive straight down into the body: overbright flash, hard
#      squash, radial burst + shock puff (gold-warm + bigger on the die's MAX face),
#      lingers so the number can breathe, then drops off the body like a spent die.
# Air lands (the support throws, target == null) keep the old single arc: windup, lob to
# a point above the card, settle mid-air and dissolve into their effect.
# Purely visual: the roll was already decided at play time. Icons live on the ui_layer
# with the same z convention as the other dice flourishes. Target positions are captured
# at SPAWN time, so a die whose target dies mid-flight still lands where it was aimed
# (the damage side handles retargeting separately - a tiny spatial lie, accepted).
const THROWN_DIE_SIZE := 56.0
const THROWN_DIE_ARC_RISE := 150.0
const THROWN_DIE_TUMBLE_INTERVAL := 0.06
const THROWN_DIE_LINGER := 0.45
const THROWN_DIE_WINDUP_RISE := 54.0
const THROWN_DIE_TRAIL_GAP_MS := 28
# Bash beats (enemy lands), carved out of FLIGHT_TIME: hang + slam are fixed, the ascent
# gets whatever remains after the windup. The die hangs ABOVE-and-LEFT of the target,
# clearly OFF the body (Julien, 2026-07-24 v3: "top left of the enemy, not touching him,
# not 1 inch away... the moment it overlaps is because it just smacked him"). Clearance is
# VERTICAL - the hang sits STRIKE_GAP px above the enemy's top edge AND above its intent
# icon (so the telegraph stays readable), biased LATERAL px left of the torso. Deriving it
# from the sprite's real bounding box (not a fixed offset - a wide Marauder kept the die
# on its shoulder, and clearing a wide body sideways drifted the die to the screen edge).
# The slam is then a diagonal haymaker down-right that only reaches the body at the very
# end. REAR_BACK is the pull-away along the strike axis during the hang (punch
# anticipation); DRIVE_IN pushes the visual stop point past the surface (driven INTO him).
const THROWN_DIE_HANG_TIME := 0.18
const THROWN_DIE_SLAM_TIME := 0.13
const THROWN_DIE_STRIKE_GAP := 30.0
const THROWN_DIE_LATERAL_MIN := 66.0
const THROWN_DIE_LATERAL_FRAC := 0.52
const THROWN_DIE_TOP_MARGIN := 26.0
const THROWN_DIE_RAISE_MIN := 62.0
const THROWN_DIE_REAR_BACK := 14.0
const THROWN_DIE_DRIVE_IN := 10.0
const THROWN_DIE_SLAM_TILT := 0.45
const THROWN_DIE_ASCENT_BOW := 34.0
const THROWN_DIE_SLAM_TRAIL_GAP_MS := 16
# whipsound was freed up when the evil-0 crack moved to glass_sound - it reads as a clean
# throw "whip" here. The air-land clack is the tightest of the three roll sounds pitched
# up into a short clatter (placeholder until Julien finds a dedicated single-die clack).
const THROWN_DIE_WHOOSH := preload("res://whipsound.mp3")
const THROWN_DIE_AIR_LAND_SFX := preload("res://sounds/dicerollsound3.mp3")
# The throw origin is where the CARD WAS RELEASED, which the player controls - release one
# high on the screen and the windup (which pops the die WINDUP_RISE px ABOVE the origin,
# and an air-land another 160 on top) used to fling the die clean off the top edge, so you
# never saw the roll (Julien, 2026-07-25). The origin is pulled back into a safe band
# before anything is derived from it; the card itself is untouched, only the die's start
# point moves. Same identity-canvas-transform assumption the apex clamp already makes.
const THROWN_DIE_SPAWN_MIN_Y := 150.0
const THROWN_DIE_SPAWN_MARGIN_X := 90.0
const THROWN_DIE_AIR_LAND_MIN_Y := 70.0


func _spawn_thrown_dice(throws: Array, origin: Vector2) -> void:
    if throws.is_empty():
        return
    var parent_layer := get_tree().get_first_node_in_group("ui_layer")
    if not parent_layer:
        return
    var spawn_origin := origin
    if spawn_origin == Vector2.ZERO:
        spawn_origin = dice_display.get_global_rect().get_center()
    spawn_origin = _clamp_throw_origin(spawn_origin)
    # Same helper the card scripts use to schedule the damage - the bash and the hit can
    # never drift apart, including the big-volley compression.
    var stagger := Global.dice_throw_volley_stagger(throws.size())
    for i in throws.size():
        var entry: Dictionary = throws[i]
        var throw_type: String = entry.get("type", "blue")
        var value: int = entry.get("value", 1)
        var target = entry.get("target")
        var has_target := false
        var land_pos := spawn_origin + Vector2(0.0, -160.0)
        # Air lands hover 160px above the origin - keep that hover on screen too.
        land_pos.y = maxf(land_pos.y, THROWN_DIE_AIR_LAND_MIN_Y)
        var apex_pos := land_pos
        if target != null and is_instance_valid(target) and target is Node2D:
            has_target = true
            land_pos = _thrown_die_impact_pos(target)
            if throws.size() > 1:
                # Volleys pelt the body on ALTERNATING sides so consecutive impacts (and
                # their damage numbers) never stack on the same pixel - half the old
                # readability problem was every die of a volley smashing one spot.
                var side := -1.0 if i % 2 == 0 else 1.0
                land_pos += Vector2(side * randf_range(8.0, 26.0), randf_range(-14.0, 10.0))
            apex_pos = _thrown_die_apex_pos(target, land_pos)
        _animate_thrown_die(parent_layer, throw_type, value, spawn_origin, land_pos,
                apex_pos, stagger * i, has_target, bool(entry.get("thud", false)), target)


# Pulls a card-release point into a band where the whole throw stays visible. Only the top
# edge really bites (the windup and the air-land hover both travel UP), but the sides are
# clamped too so a throw released at the very edge of the screen still reads. With
# stretch/mode = canvas_items the viewport rect IS the design canvas, so this tracks the
# 1280x720 the rest of the throw code assumes without hardcoding it.
func _clamp_throw_origin(origin: Vector2) -> Vector2:
    var screen := get_viewport_rect().size
    return Vector2(
            clampf(origin.x, THROWN_DIE_SPAWN_MARGIN_X, screen.x - THROWN_DIE_SPAWN_MARGIN_X),
            clampf(origin.y, THROWN_DIE_SPAWN_MIN_Y, screen.y - THROWN_DIE_SPAWN_MIN_Y * 0.5))


# The enemy ROOT's global_position is not the visual center - enemy.tscn bakes the Sprite2D
# at local x=124 (the same baseline the name-label centering fix documented), so landing on
# the root put every thrown die ~124px LEFT of the body. Aim at the sprite node itself:
# update_enemy() anchors the content bottom to the feet line, which leaves the sprite node
# sitting at the torso center - exactly where a hit should land. Lives on Card so the
# damage side can spawn each die's popup at the same spot (Card.thrown_impact_pos).
func _thrown_die_impact_pos(target: Node2D) -> Vector2:
    return Card.thrown_impact_pos(target)


# Where the die hangs before the strike: ABOVE the target and biased LEFT, clear of the
# whole silhouette AND above the intent icon, so it never sits on the body and never hides
# the telegraph. The slam then comes down-right into the torso, overlapping only on the
# hit. Because the hang is left of the intent, the down-right slam path also stays clear
# of the intent until it's already below it.
func _thrown_die_apex_pos(target: Node2D, land_pos: Vector2) -> Vector2:
    var center := Card.thrown_impact_pos(target)  # unscattered torso center
    var aabb := _enemy_sprite_aabb(target)
    var die_half := THROWN_DIE_SIZE * 0.62  # ~half-size at the hang swell scale (~1.24)
    # Top clearance: above the sprite top AND the intent icon (whichever is higher).
    var top := aabb.position.y
    var intent = target.get("intent_ui")
    if intent is Control and is_instance_valid(intent):
        top = minf(top, (intent as Control).get_global_rect().position.y)
    var lateral := maxf(aabb.size.x * 0.5 * THROWN_DIE_LATERAL_FRAC, THROWN_DIE_LATERAL_MIN)
    var apex := Vector2(
            center.x - lateral + randf_range(-6.0, 6.0),
            top - THROWN_DIE_STRIKE_GAP - die_half + randf_range(-6.0, 4.0))
    # Never below a floor above the impact (tiny enemy safety), never off the screen top.
    apex.y = minf(apex.y, land_pos.y - THROWN_DIE_RAISE_MIN)
    apex.y = maxf(apex.y, THROWN_DIE_TOP_MARGIN)
    return apex


# The target's on-screen sprite bounds (global AABB of the sprite rect). Falls back to a
# reasonable box around the impact point if the sprite can't be read.
func _enemy_sprite_aabb(target: Node2D) -> Rect2:
    var sprite = target.get("sprite_2d")
    if sprite is Sprite2D and is_instance_valid(sprite):
        var s := sprite as Sprite2D
        var r: Rect2 = s.get_rect()
        var xf := s.get_global_transform()
        var mn := Vector2(INF, INF)
        var mx := Vector2(-INF, -INF)
        for corner in [r.position, r.position + Vector2(r.size.x, 0.0),
                r.position + Vector2(0.0, r.size.y), r.end]:
            var g: Vector2 = xf * corner
            mn = Vector2(minf(mn.x, g.x), minf(mn.y, g.y))
            mx = Vector2(maxf(mx.x, g.x), maxf(mx.y, g.y))
        return Rect2(mn, mx - mn)
    var c: Vector2 = Card.thrown_impact_pos(target)
    return Rect2(c - Vector2(70.0, 90.0), Vector2(140.0, 180.0))


func _animate_thrown_die(parent_layer: Node, throw_type: String, value: int, from_pos: Vector2, to_pos: Vector2, apex_pos: Vector2, delay: float, has_target: bool, thud: bool, target: Node = null) -> void:
    var icon := TextureRect.new()
    icon.texture = _get_dice_face_texture_for(throw_type, value)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.custom_minimum_size = Vector2(THROWN_DIE_SIZE, THROWN_DIE_SIZE)
    icon.size = Vector2(THROWN_DIE_SIZE, THROWN_DIE_SIZE)
    icon.pivot_offset = icon.size / 2.0
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.z_index = 150
    icon.visible = false
    icon.scale = Vector2(0.35, 0.35)
    parent_layer.add_child(icon)
    icon.global_position = from_pos - icon.size / 2.0

    # Infusion-aware faces (Julien, 2026-07-23): a Repented Evil must never flash its
    # removed 0 face mid-tumble, a Bulky Giant tumbles through 7-12.
    var faces: Array = Card.thrown_faces_for(throw_type)
    var windup := minf(Global.DICE_THROW_WINDUP_TIME, Global.DICE_THROW_FLIGHT_TIME * 0.45)
    # Enemy lands: hang + slam are fixed beats, the ascent gets the rest of the budget.
    # Air lands: the whole remainder is the old single arc.
    var ascent := maxf(0.12, Global.DICE_THROW_FLIGHT_TIME - windup - THROWN_DIE_HANG_TIME - THROWN_DIE_SLAM_TIME)
    var air_flight := Global.DICE_THROW_FLIGHT_TIME - windup
    var tumble_time := (windup + ascent) if has_target else (windup + air_flight)
    var hang_pos := from_pos + Vector2(randf_range(-10.0, 10.0), -THROWN_DIE_WINDUP_RISE)
    var spin_dir := 1.0 if randf() < 0.5 else -1.0

    var tween := create_tween()
    if delay > 0.0:
        tween.tween_interval(delay)
    tween.tween_callback(icon.show)
    tween.tween_callback(_start_die_tumble.bind(icon, throw_type, faces, tumble_time))
    # WINDUP: pop out of the card and hang above it, then coil (vertical stretch) - the
    # anticipation beat that makes the launch read as a real throw.
    tween.tween_property(icon, "global_position", hang_pos - icon.size / 2.0, windup * 0.55) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(icon, "scale", Vector2(1.15, 1.15), windup * 0.55) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(icon, "scale", Vector2(0.88, 1.24), windup * 0.45) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_callback(_launch_thrown_die_fx.bind(icon, hang_pos, throw_type))
    var strike_dir := Vector2.DOWN
    if has_target:
        strike_dir = (to_pos - apex_pos).normalized()
        # The little pull-away along the strike axis during the hang (punch anticipation)
        # and the visual stop point driven slightly INTO the body.
        var rear_pos := apex_pos - strike_dir * THROWN_DIE_REAR_BACK
        var drive_pos := to_pos + strike_dir * THROWN_DIE_DRIVE_IN
        # The die tilts into its travel direction during the slam (about half the true
        # strike angle - full alignment hurt face readability more than it sold speed).
        var tilt := THROWN_DIE_SLAM_TILT * (strike_dir.angle() - PI * 0.5)
        # ASCENT: decelerating lob up to the hang point beside the target - spin settles
        # into exactly one full turn so the die arrives upright with no visible snap.
        tween.tween_method(_thrown_die_ascent_step.bind(icon, hang_pos, apex_pos, spin_dir, throw_type), 0.0, 1.0, ascent) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        # HANG: the tumble ends, the final face locks in with a glint (the icon's own
        # tween inside the callback) while the die rears back - "wound up to strike".
        tween.tween_callback(_lock_thrown_die_face.bind(icon, throw_type, value))
        tween.tween_property(icon, "global_position", rear_pos - icon.size / 2.0, THROWN_DIE_HANG_TIME) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        # SLAM: hard accelerating diagonal punch into the body.
        tween.tween_method(_thrown_die_slam_step.bind(icon, rear_pos, drive_pos, tilt, throw_type), 0.0, 1.0, THROWN_DIE_SLAM_TIME) \
            .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    else:
        # AIR FLIGHT: the old accelerating arc (position, tumble spin, mid-arc swell and
        # the trail all live in the flight step).
        tween.tween_method(_thrown_die_flight_step.bind(icon, hang_pos, to_pos, spin_dir, throw_type), 0.0, 1.0, air_flight) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    # IMPACT: flash/squash/burst (own tweens inside), then linger long enough for the
    # roll to be read.
    tween.tween_callback(_finish_thrown_die.bind(icon, throw_type, value, has_target, thud, strike_dir, target))
    tween.tween_interval(THROWN_DIE_LINGER)
    # EXIT: a spent die tumbles off the body; an air-land dissolves into its effect.
    if has_target:
        tween.tween_property(icon, "global_position:y", to_pos.y - icon.size.y / 2.0 + 52.0, 0.3) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.parallel().tween_property(icon, "rotation", randf_range(-0.7, 0.7), 0.3)
        tween.parallel().tween_property(icon, "modulate:a", 0.0, 0.24)
    else:
        tween.tween_property(icon, "scale", Vector2.ZERO, 0.22) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
        tween.parallel().tween_property(icon, "modulate:a", 0.0, 0.2)
    tween.tween_callback(icon.queue_free)


func _launch_thrown_die_fx(icon: TextureRect, hang_pos: Vector2, throw_type: String) -> void:
    # Decorative (priority -1): a Dice Avalanche fires 9 of these 0.15s apart - they must
    # never starve a real beat out of the SFX pool. Pitch jitter keeps volleys organic.
    SFXPlayer.play(THROWN_DIE_WHOOSH, false, randf_range(1.0, 1.25), -6.0, -1)
    if not is_instance_valid(icon):
        return
    var accent := DicePalette.accent(throw_type)
    for i in 5:
        var dir := Vector2.from_angle(randf_range(0.0, TAU))
        _spawn_thrown_die_mote(icon.get_parent(), hang_pos, accent,
                randf_range(8.0, 14.0), dir * randf_range(18.0, 42.0), 0.28)


func _thrown_die_flight_step(t: float, icon: TextureRect, from_pos: Vector2, to_pos: Vector2, spin_dir: float, throw_type: String) -> void:
    if not is_instance_valid(icon):
        return
    var pos := from_pos.lerp(to_pos, t)
    pos.y -= THROWN_DIE_ARC_RISE * sin(t * PI)
    icon.global_position = pos - icon.size / 2.0
    icon.rotation = t * TAU * 1.5 * spin_dir
    # Mid-arc the die swells (reads as closer to camera) and settles back by landing.
    var height := sin(t * PI)
    icon.scale = Vector2.ONE * (1.0 + 0.24 * height)
    # Accent mote trail, throttled in real time (same trick as the card comet trail - the
    # step fires every frame, the throttle keeps density framerate-independent).
    var now := Time.get_ticks_msec()
    var last := int(icon.get_meta("trail_last_ms", 0))
    if now - last >= THROWN_DIE_TRAIL_GAP_MS:
        icon.set_meta("trail_last_ms", now)
        _spawn_thrown_die_mote(icon.get_parent(), pos, DicePalette.accent(throw_type),
                randf_range(10.0, 18.0),
                Vector2(randf_range(-14.0, 14.0), randf_range(4.0, 26.0)), 0.32)


# ASCENT step (enemy lands): rising lob from the launch point to the apex. A small
# perpendicular bow keeps it reading as a throw (not an elevator); the tween's EASE_OUT
# does the deceleration. Spin is exactly one full turn riding the same eased t, so the
# die decelerates into an upright face at the crest - the face lock needs no rotation
# snap. Swells the whole way up: by the apex it's at its biggest, i.e. its most readable.
func _thrown_die_ascent_step(t: float, icon: TextureRect, from_pos: Vector2, apex_pos: Vector2, spin_dir: float, throw_type: String) -> void:
    if not is_instance_valid(icon):
        return
    var pos := from_pos.lerp(apex_pos, t)
    pos.y -= THROWN_DIE_ASCENT_BOW * sin(t * PI)
    icon.global_position = pos - icon.size / 2.0
    icon.rotation = t * TAU * spin_dir
    icon.scale = Vector2.ONE * (1.0 + 0.24 * t)
    var now := Time.get_ticks_msec()
    var last := int(icon.get_meta("trail_last_ms", 0))
    if now - last >= THROWN_DIE_TRAIL_GAP_MS:
        icon.set_meta("trail_last_ms", now)
        _spawn_thrown_die_mote(icon.get_parent(), pos, DicePalette.accent(throw_type),
                randf_range(10.0, 18.0),
                Vector2(randf_range(-14.0, 14.0), randf_range(4.0, 26.0)), 0.32)


# The "read the roll" beat: the tumble ends and the die snaps to its FINAL face with a
# glint + pop while hanging raised over the target. From here through the slam the face
# never changes - the player tracks "a 6 is coming down" all the way into the hit.
func _lock_thrown_die_face(icon: TextureRect, throw_type: String, value: int) -> void:
    if not is_instance_valid(icon):
        return
    if icon.has_meta("tumble"):
        var tumble: Tween = icon.get_meta("tumble")
        if tumble != null and tumble.is_valid():
            tumble.kill()
    icon.rotation = 0.0
    icon.texture = _get_dice_face_texture_for(throw_type, value)
    icon.modulate = Color(1.85, 1.8, 1.55, 1.0)
    var pop := icon.create_tween()
    pop.tween_property(icon, "scale", Vector2(1.4, 1.4), 0.07) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    pop.parallel().tween_property(icon, "modulate", Color.WHITE, THROWN_DIE_HANG_TIME) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    pop.tween_property(icon, "scale", Vector2(1.28, 1.28), THROWN_DIE_HANG_TIME - 0.07)
    # Quiet settle tick - the pickup note before the "bam". Decorative, never steals a
    # real beat from the SFX pool. With a volley, ticks and impacts interleave into the
    # tick-BAM-tick-BAM rhythm that carries the whole sequence.
    SFXPlayer.play(THROWN_DIE_AIR_LAND_SFX, false, randf_range(1.55, 1.7), -11.0, -1)
    var accent := DicePalette.accent(throw_type)
    var center := icon.global_position + icon.size / 2.0
    for i in 3:
        var dir := Vector2.from_angle(randf_range(-PI * 0.85, -PI * 0.15))
        _spawn_thrown_die_mote(icon.get_parent(), center, accent,
                randf_range(7.0, 12.0), dir * randf_range(16.0, 34.0), 0.24)


# SLAM step (enemy lands): short, hard, accelerating diagonal punch from the hang point
# into the body. The die tilts into its travel direction and stretches as it accelerates;
# the trail motes kick back opposite the strike - speed lines rather than a drifting
# comet tail.
func _thrown_die_slam_step(t: float, icon: TextureRect, from_pos: Vector2, to_pos: Vector2, tilt: float, throw_type: String) -> void:
    if not is_instance_valid(icon):
        return
    var pos := from_pos.lerp(to_pos, t)
    icon.global_position = pos - icon.size / 2.0
    icon.rotation = tilt * minf(1.0, t * 1.6)
    icon.scale = Vector2(lerpf(1.28, 0.96, t), lerpf(1.28, 1.34, t))
    var back := (from_pos - to_pos).normalized()
    var now := Time.get_ticks_msec()
    var last := int(icon.get_meta("trail_last_ms", 0))
    if now - last >= THROWN_DIE_SLAM_TRAIL_GAP_MS:
        icon.set_meta("trail_last_ms", now)
        _spawn_thrown_die_mote(icon.get_parent(), pos, DicePalette.accent(throw_type),
                randf_range(9.0, 15.0),
                back * randf_range(12.0, 32.0) + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)), 0.22)


# One additive accent mote with its own tween (parented to the ui_layer, so it outlives the
# die that spawned it) - shared by the flight trail, the launch recoil and the impact burst.
func _spawn_thrown_die_mote(parent: Node, pos: Vector2, color: Color, mote_size: float, drift: Vector2, life: float) -> void:
    if parent == null:
        return
    var mote := TextureRect.new()
    mote.texture = _get_power_orb_texture()
    mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mote.stretch_mode = TextureRect.STRETCH_SCALE
    mote.size = Vector2(mote_size, mote_size)
    mote.pivot_offset = mote.size / 2.0
    mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mote.material = _get_power_orb_material()
    mote.modulate = color
    mote.z_index = 149
    parent.add_child(mote)
    mote.global_position = pos - mote.size / 2.0
    var tw := mote.create_tween()
    tw.tween_property(mote, "global_position", pos + drift - mote.size / 2.0, life) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(mote, "scale", Vector2(0.15, 0.15), life) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.parallel().tween_property(mote, "modulate:a", 0.0, life) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.tween_callback(mote.queue_free)


# Soft expanding shock puff at the landing point - kept at modest alpha so it never
# overexposes when it stacks with the burst motes (additive-blend stacking lesson).
# `strong` (enemy bashes) grows it further - the "BAM" ring - without touching alpha.
func _spawn_thrown_die_shock(parent: Node, pos: Vector2, color: Color, big: bool, strong: bool = false) -> void:
    if parent == null:
        return
    var puff := TextureRect.new()
    puff.texture = _get_power_orb_texture()
    puff.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    puff.stretch_mode = TextureRect.STRETCH_SCALE
    puff.size = Vector2(46.0, 46.0)
    puff.pivot_offset = puff.size / 2.0
    puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
    puff.material = _get_power_orb_material()
    puff.modulate = Color(color.r, color.g, color.b, 0.5)
    puff.z_index = 148
    puff.scale = Vector2(0.6, 0.6)
    parent.add_child(puff)
    puff.global_position = pos - puff.size / 2.0
    var target_scale := 3.2 if big else 2.4
    if strong:
        target_scale *= 1.22
    var tw := puff.create_tween()
    tw.tween_property(puff, "scale", Vector2.ONE * target_scale, 0.28) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(puff, "modulate:a", 0.0, 0.28) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.tween_callback(puff.queue_free)


# Bright additive impact flare - white-hot core snapping open and fading fast, the "BAM"
# glow at the moment the die smacks the enemy. Distinct from the soft shock puff: this is
# short, bright and punchy (higher alpha, quicker) so it reads as a flash of force, not a
# lingering cloud. Single flare per impact, so a high peak alpha is fine.
func _spawn_thrown_die_flare(parent: Node, pos: Vector2, color: Color, big: bool) -> void:
    if parent == null:
        return
    var flare := TextureRect.new()
    flare.texture = _get_power_orb_texture()
    flare.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    flare.stretch_mode = TextureRect.STRETCH_SCALE
    flare.size = Vector2(90.0, 90.0)
    flare.pivot_offset = flare.size / 2.0
    flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flare.material = _get_power_orb_material()
    # White-hot core tinted toward the die's accent, so it glows in the die's color.
    flare.modulate = Color(1.0, 1.0, 1.0, 0.0).lerp(Color(color.r + 0.6, color.g + 0.6, color.b + 0.6, 0.95), 0.7)
    flare.z_index = 151
    flare.scale = Vector2(0.35, 0.35)
    parent.add_child(flare)
    flare.global_position = pos - flare.size / 2.0
    var peak := 1.9 if big else 1.45
    var flare_tween := flare.create_tween()
    flare_tween.tween_property(flare, "scale", Vector2.ONE * peak, 0.09) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    flare_tween.parallel().tween_property(flare, "modulate:a", 0.0, 0.18) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    flare_tween.tween_callback(flare.queue_free)


func _start_die_tumble(icon: TextureRect, throw_type: String, faces: Array, duration: float) -> void:
    if not is_instance_valid(icon):
        return
    var steps := maxi(1, int(duration / THROWN_DIE_TUMBLE_INTERVAL))
    var tumble := icon.create_tween()
    for i in steps:
        tumble.tween_callback(_set_random_die_face.bind(icon, throw_type, faces))
        tumble.tween_interval(THROWN_DIE_TUMBLE_INTERVAL)
    icon.set_meta("tumble", tumble)


func _set_random_die_face(icon: TextureRect, throw_type: String, faces: Array) -> void:
    if not is_instance_valid(icon):
        return
    icon.texture = _get_dice_face_texture_for(throw_type, int(faces[randi() % faces.size()]))


func _finish_thrown_die(icon: TextureRect, throw_type: String, value: int, has_target: bool, thud: bool = false, strike_dir: Vector2 = Vector2.DOWN, target: Node = null) -> void:
    if not is_instance_valid(icon):
        return
    # Enemy lands already locked their face at the hang; air lands snap here.
    if icon.has_meta("tumble"):
        var tumble: Tween = icon.get_meta("tumble")
        if tumble != null and tumble.is_valid():
            tumble.kill()
    icon.rotation = 0.0
    icon.texture = _get_dice_face_texture_for(throw_type, value)
    # Infusion-aware set so the "best face" jackpot beat matches what the die can roll.
    var faces: Array = Card.thrown_faces_for(throw_type)
    var is_max_face: bool = value == int(faces.max())
    var accent := DicePalette.accent(throw_type)
    var burst_color := DicePalette.burst(throw_type) if is_max_face else accent
    # Overbright flash + hard squash, springing back to rest while the face lingers.
    # Max faces flash warmer/bigger - the "it rolled its best" jackpot micro-beat.
    icon.modulate = Color(2.6, 2.45, 2.0, 1.0) if is_max_face else Color(2.1, 2.0, 1.8, 1.0)
    icon.scale = Vector2(1.68, 0.5) if has_target else Vector2(1.3, 1.3)
    var impact := icon.create_tween()
    impact.tween_property(icon, "scale", Vector2(1.16, 1.16), 0.14) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    impact.parallel().tween_property(icon, "modulate", Color.WHITE, 0.22) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    impact.tween_property(icon, "scale", Vector2.ONE, 0.1)
    # Burst + shock puff at the landing point. Enemy hits spray most of the debris in a
    # cone CONTINUING the strike (driven-through force), the rest radial; air lands stay
    # a modest radial pop.
    var parent := icon.get_parent()
    var center := icon.global_position + icon.size / 2.0
    var mote_count := 20 if is_max_face else (15 if has_target else 6)
    for i in mote_count:
        var drift: Vector2
        if has_target and i % 3 != 0:
            var cone_dir := strike_dir.rotated(randf_range(-0.55, 0.55))
            drift = cone_dir * randf_range(55.0, 130.0)
        else:
            drift = Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(30.0, 90.0)
        _spawn_thrown_die_mote(parent, center, burst_color,
                randf_range(9.0, 16.0), drift, randf_range(0.25, 0.4))
    _spawn_thrown_die_shock(parent, center, burst_color, is_max_face, has_target)
    # BAM glow: a bright additive flare at the impact - the "hit the enemy with an attack
    # card" pop Julien asked for. Enemy lands get the big one; air lands a modest bloom.
    if has_target:
        _spawn_thrown_die_flare(parent, center, burst_color, is_max_face)
    # A thud die (All In) carries no damage of its own, so it never triggers the enemy's
    # own take_damage() white flash + knockback - do it here so every bash physically
    # lands. (Damage-dealing throws already flash via the synced DamageEffect.)
    if thud and target != null and is_instance_valid(target) and target.has_method("flash_impact"):
        target.flash_impact()
        var camera = get_tree().get_first_node_in_group("camera")
        if camera and camera.has_method("shake"):
            camera.shake(7.0, 0.12)
    # Air lands (support throws) had NO landing sound at all - give the die a settle clack.
    # Enemy lands normally get the card's own hit sound from the damage side, synced; a
    # damage-less bash (All In's consumed dice - their total lands once on the final
    # impact) gets a low clack instead so every hit still lands audibly.
    if not has_target:
        SFXPlayer.play(THROWN_DIE_AIR_LAND_SFX, false, randf_range(1.35, 1.5), -4.0, -1)
    elif thud:
        SFXPlayer.play(THROWN_DIE_AIR_LAND_SFX, false, randf_range(0.85, 0.95), -3.0, -1)
    if throw_type == "evil" and value == 0:
        play_crack_sound()


# Double or Nothing's coin: tossed from the played card, spins (scale.x oscillation reads as
# the flip), then reveals at exactly Global.COIN_FLIP_TIME - the same moment the card's own
# timer resolves the damage (heads) or nothing (tails), so the reveal and the outcome land
# together. Heads flashes overbright gold; tails desaturates and drops away.
const COIN_TEXTURE := preload("res://daiso_coin_icon.png")
# Bigger and tossed UP BY THE ENEMY rather than out of the played card (Julien, 2026-07-25)
# - the flip is the whole point of the card, it shouldn't happen down in the hand where the
# cards cover it. The toss anchors just above the target's silhouette (and its intent icon,
# same clearance rule the thrown-die hang uses), then rises from there; COIN_MIN_ANCHOR_Y
# keeps the apex on screen for tall enemies, since visible beats perfectly placed.
const COIN_SIZE := 108.0
const COIN_TOSS_RISE := 110.0
const COIN_SPIN_HALF := 0.1
const COIN_GAP_ABOVE_TARGET := 44.0
const COIN_MIN_ANCHOR_Y := 220.0


func _spawn_coin_flip(heads: bool, origin: Vector2, target: Node = null) -> void:
    var parent_layer := get_tree().get_first_node_in_group("ui_layer")
    if not parent_layer:
        return
    var spawn_origin := origin
    if spawn_origin == Vector2.ZERO:
        spawn_origin = dice_display.get_global_rect().get_center()
    spawn_origin = _coin_flip_anchor(target, _clamp_throw_origin(spawn_origin))
    var coin := TextureRect.new()
    coin.texture = COIN_TEXTURE
    coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    coin.custom_minimum_size = Vector2(COIN_SIZE, COIN_SIZE)
    coin.size = Vector2(COIN_SIZE, COIN_SIZE)
    coin.pivot_offset = coin.size / 2.0
    coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    coin.z_index = 150
    parent_layer.add_child(coin)
    coin.global_position = spawn_origin - coin.size / 2.0

    var spin := coin.create_tween()
    var spins := maxi(1, int(Global.COIN_FLIP_TIME / (COIN_SPIN_HALF * 2.0)))
    for i in spins:
        spin.tween_property(coin, "scale:x", 0.08, COIN_SPIN_HALF) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        spin.tween_property(coin, "scale:x", 1.0, COIN_SPIN_HALF) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    coin.set_meta("spin", spin)

    var tween := create_tween()
    tween.tween_property(coin, "global_position:y", spawn_origin.y - COIN_TOSS_RISE - coin.size.y / 2.0, Global.COIN_FLIP_TIME * 0.55) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(coin, "global_position:y", spawn_origin.y - COIN_TOSS_RISE * 0.45 - coin.size.y / 2.0, Global.COIN_FLIP_TIME * 0.45) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_callback(_reveal_coin.bind(coin, heads))


# Where the coin is tossed from: centred on the target's torso, just above its silhouette
# and its intent icon. Falls back to the (already clamped) card-release point when the card
# has no living Node2D target.
func _coin_flip_anchor(target: Node, fallback: Vector2) -> Vector2:
    if target == null or not is_instance_valid(target) or not (target is Node2D):
        return fallback
    var node := target as Node2D
    var top := _enemy_sprite_aabb(node).position.y
    var intent = node.get("intent_ui")
    if intent is Control and is_instance_valid(intent):
        top = minf(top, (intent as Control).get_global_rect().position.y)
    # Enemies sit as far right as ~x1150, so the (now much bigger) coin needs a side clamp
    # of its own or it clips off the right edge above a far-right target.
    var half := COIN_SIZE * 0.5 + 16.0
    return Vector2(
            clampf(Card.thrown_impact_pos(node).x, half, get_viewport_rect().size.x - half),
            maxf(top - COIN_GAP_ABOVE_TARGET, COIN_MIN_ANCHOR_Y))


func _reveal_coin(coin: TextureRect, heads: bool) -> void:
    if not is_instance_valid(coin):
        return
    if coin.has_meta("spin"):
        var spin: Tween = coin.get_meta("spin")
        if spin != null and spin.is_valid():
            spin.kill()
    coin.scale = Vector2.ONE
    var tween := coin.create_tween()
    if heads:
        tween.tween_property(coin, "modulate", Color(2.0, 1.8, 1.1, 1.0), 0.1)
        tween.parallel().tween_property(coin, "scale", Vector2(1.35, 1.35), 0.1) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_interval(0.25)
        tween.tween_property(coin, "modulate:a", 0.0, 0.18)
    else:
        tween.tween_property(coin, "modulate", Color(0.45, 0.5, 0.6, 1.0), 0.12)
        tween.tween_property(coin, "global_position:y", coin.global_position.y + 46.0, 0.32) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.parallel().tween_property(coin, "modulate:a", 0.0, 0.32)
    tween.tween_callback(coin.queue_free)


func _on_refuel_happened(amount: int) -> void:
    var start_value := Global.roll_value  # capture before reset happens
    # roll_history is still populated here (dice_roll_reset, which clears it, is emitted by
    # the card AFTER refuel_happened) - duplicate the values before the first await below.
    var rolled_values := Global.roll_history.duplicate()
    var last_flight := _spawn_refuel_return(rolled_values)

    # --- Power drain animation --- (sped up: was 0.03/tick, could outlast a quick reroll)
    var steps := mini(start_value, 6)
    var step_size: float = float(start_value) / float(maxi(steps, 1))
    var step_duration := 0.018  # seconds per tick

    for i in range(steps):
        await get_tree().create_timer(step_duration * i).timeout
        var display_val := int(start_value - step_size * (i + 1))
        _set_power_text(maxi(display_val, 0))

    await get_tree().create_timer(step_duration * steps).timeout

    # Wait for the LAST returning die's own tween to actually finish, rather than a separately
    # -computed duration estimate - so the recharge pulse below is guaranteed to land exactly
    # as the dice arrive, even if the timing constants above get retuned later. is_running()
    # guard first: awaiting an already-finished Tween's `finished` signal would hang forever
    # (it only fires once, on its own completion, not retroactively).
    if last_flight and last_flight.is_running():
        await last_flight.finished

    # Only force the power display back to "0" if no fresh roll happened during the drain.
    # Recombobulate's own reset leaves roll_value at 0 (normal case), but a roll landing
    # mid-drain sets roll_value > 0 and already updated the text - stomping "0" would blank
    # it. The dice recharge flash below plays either way (it's the "dice are back" feedback).
    if Global.roll_value <= 0:
        _set_power_text("0")
        current_power.modulate.a = 0.4
        if current_power.material:
            current_power.material.set_shader_parameter("float_intensity", 0.0)
            current_power.material.set_shader_parameter("crackle_charge", 0.0)

        var drain_punch := create_tween()
        drain_punch.tween_property(current_power, "scale", Vector2(1.15, 1.15), 0.06) \
            .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        drain_punch.tween_property(current_power, "scale", Vector2(1.0, 1.0), 0.12) \
            .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

    # --- Dice recharge pulse (always plays) ---
    var dice_tween := create_tween()
    dice_tween.tween_property(dice_display, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.08) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    dice_tween.tween_property(dice_display, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

    var dice_scale_tween := create_tween()
    dice_scale_tween.tween_property(dice_display, "scale", Vector2(1.12, 1.12), 0.08) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    dice_scale_tween.tween_property(dice_display, "scale", Vector2(1.0, 1.0), 0.18) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
        
        
# Mirrors CardUI._fly_to_discard_and_free()'s single-targeted lift-then-arc, applied to the
# socket's own display (card_drop_area) instead of the real CardUI: that node gets hidden the
# whole time a card is socketed (see _on_card_charged's card_ui.hide()), so animating it would
# be invisible - card_drop_area is what the player has actually been looking at.
func _fly_charged_card_to_discard() -> void:
    var origin_pos := card_drop_area.global_position
    var origin_scale := card_drop_area.scale

    var target_pos := origin_pos
    var ui_layer := get_tree().get_first_node_in_group("ui_layer")
    if ui_layer:
        var discard: Node = ui_layer.get_node_or_null("DiscardPileButton")
        if discard and discard is Control:
            target_pos = (discard as Control).global_position

    var lift_pos := origin_pos + Vector2(0, -80)
    var lift_time := 0.16
    var arc_time := 0.7

    var fly_tween := create_tween()
    fly_tween.tween_property(card_drop_area, "global_position", lift_pos, lift_time) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    fly_tween.tween_property(card_drop_area, "global_position", target_pos, arc_time) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    fly_tween.parallel().tween_property(card_drop_area, "scale", origin_scale * 0.15, arc_time) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    fly_tween.parallel().tween_property(card_drop_area, "rotation", deg_to_rad(randf_range(-35.0, 35.0)), arc_time) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

    var fade_tween := create_tween()
    fade_tween.tween_interval(lift_time + arc_time - 0.2)
    fade_tween.tween_property(card_drop_area, "modulate:a", 0.0, 0.2) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fade_tween.tween_callback(func():
        # socketed_card_ui is deliberately NOT touched here anymore - it was already
        # nulled when the fly started (_on_reset_charged_card), and nulling it again
        # would clobber a NEW card socketed while this animation was still playing.
        # Same reason for the guard below: only reset the display if nothing new
        # took the socket mid-flight.
        if socketed_card_ui == null:
            _set_socket_empty()
        card_drop_area.global_position = origin_pos
        card_drop_area.rotation = 0.0
        card_drop_area.modulate.a = 1.0
        _flying_charged_card_to_discard = false
    )


func _set_socket_empty() -> void:
    card_drop_area.scale = SOCKET_REST_SCALE  # after you apply scale
    card_banner.modulate.a = 0.7
    panel.modulate.a = 0.35
    $CardDropArea/CardBackground/CardFrame/DescriptionPanel.modulate.a = 0.15
    title.text = "?"
    title.modulate.a = 0.7
    title.show()
    charged_card_texture.texture = null
    charged_card_texture.hide()
    requirement_panel.show()
    requirement_panel.add_theme_stylebox_override("panel", CardUI.NONE_STYLEBOX)
    requirement_label.text = "Drop a card"
    requirement_panel.modulate.a = 0.5
    # Restore the defaults: the last socketed card may have stepped the font down and resized the
    # panel, and this placeholder would otherwise inherit both.
    charged_card_description.add_theme_font_size_override(
        "normal_font_size", CHARGED_DESC_FONT_SIZE_CANDIDATES[0])
    description_panel.offset_top = CardUI.DESC_PANEL_TOP
    description_panel.offset_bottom = CardUI.DESC_PANEL_TOP + CardUI.DESC_PANEL_HEIGHT
    charged_card_description.text = "[center]Place a card here[/center]"
    description_panel.modulate.a = 0.6
    bonus_effect.hide()
    bonus_separator.hide()
    cancel_red_card_panel.hide()
    # Everything above is the INERT empty socket. With Armageddon up it is not inert, and every
    # word of it is wrong - so the armed look overwrites it wholesale (see _apply_armed_socket).
    if _socket_is_armed():
        _apply_armed_socket()
    else:
        _socket_showing_armed = false
        _hide_armed_socket_icon()

func _set_socket_filled() -> void:
    _socket_showing_armed = false
    _hide_armed_socket_icon()
    card_banner.modulate.a = 1.0
    panel.modulate.a = 1.0
    title.modulate.a = 1.0
    $CardDropArea/CardBackground/CardFrame/DescriptionPanel.modulate.a = 1.0
    requirement_panel.modulate.a = 1.0
    title.show()
    charged_card_texture.show()
    $CardDropArea/CardBackground/CardFrame/DescriptionPanel.show()
    var tween = create_tween()
    tween.tween_property(card_drop_area, "scale", Vector2(0.857, 0.857), 0.12)\
        .from(Vector2(0.728, 0.728))\
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Same resource as OCTET_MUSCLE_STATUS above; named separately so the socketless path reads
# as what it is rather than borrowing the Octet infusion's name. preload() dedupes.
const MUSCLE_STATUS := preload("res://statuses/muscle.tres")


# Socketless Red blessing: rolling the Red die with an EMPTY socket turns that roll into board
# damage instead of a card play. Nothing here runs unless the blessing is up AND the socket is
# genuinely empty, so a normal socketed red roll is completely unaffected.
func _fire_socketless_red() -> void:
    if not Global.socketless_red:
        return
    if charged_card_texture.texture != null or is_instance_valid(socketed_card_ui):
        return
    var amount: int = Global.roll_value
    if amount <= 0:
        return
    var enemies := get_tree().get_nodes_in_group("enemies")
    if enemies.is_empty():
        return
    # Routed through the PLAYER's DMG_DEALT modifiers rather than dealt flat, because that is
    # exactly how Berserk doubles it: "You deal double damage with Red Dice" is a PERCENT_BASED
    # modifier that switches itself on while Red is the active die (status_berserk.gd), so
    # going through the stack is the only way to honour it without re-implementing it here.
    # Julien confirmed Berserk should apply.
    # NOTE this also lets Strength through, unlike magma's flat per-roll burn - a deliberate
    # consequence of using the modifier stack, and a tuning dial rather than an oversight.
    var player := get_tree().get_first_node_in_group("player")
    if player != null and player.get("modifier_handler") != null:
        amount = player.modifier_handler.get_modified_value(amount, Modifier.Type.DMG_DEALT)
    var damage_effect := DamageEffect.new()
    damage_effect.amount = amount
    damage_effect.execute(enemies)
    # Socketless Red+ (Julien, 2026-08-20): EVERY empty-socket Red roll also grants Strength,
    # so the blessing compounds across the fight instead of paying out once. Granted here
    # rather than in the card because this is the only place that knows a socketless roll
    # actually happened - the card just flips the flag and exhausts.
    if Global.socketless_red_strength > 0 and player != null:
        var muscle: Status = MUSCLE_STATUS.duplicate()
        muscle.stacks = Global.socketless_red_strength
        var status_effect := StatusEffect.new()
        status_effect.status = muscle
        status_effect.execute([player])
    # The Red die is decremented by dice_interface._on_dice_rolled, which listens to
    # dice_rolled - and dice.gd never emits that for Red. The ONLY thing that normally does is
    # card_ui.gd:909, right after a socketed card plays. With an empty socket that never runs,
    # so without this emit the die is rolled for free forever (Julien, 2026-08-16: "doesn't use
    # the red dice"). Emitting it here also feeds the per-roll relics (Crown, Metronome) that a
    # socketless roll should count towards, exactly like the socketed path already does.
    # No CardUI can have consumed the token here (an empty socket means none passed the
    # charged-id gate), but consume it explicitly so the "exactly one per Red roll" rule
    # holds structurally rather than by coincidence.
    if Global.red_roll_pending_report:
        Global.red_roll_pending_report = false
        Events.dice_rolled.emit("red", Global.roll_value)
    # The roll was spent on the board instead of on a card, so it still ends the chain.
    Events.dice_roll_reset.emit()


# --- Second Red socket -----------------------------------------------------------------------
# Built by DUPLICATING the CardDropArea subtree at runtime rather than hand-authoring a second
# copy in dice.tscn: the subtree is ~220 lines of scene and the two must stay visually identical
# forever. Only the handful of nodes whose CONTENT changes are resolved.
#
# Socket 2 deliberately has no Cancel button of its own - cancelling socket 1 clears both, which
# keeps a single, already-tested teardown path instead of two that can disagree.
func _ensure_socket_2() -> Control:
    if is_instance_valid(_socket_2):
        return _socket_2
    _socket_2 = card_drop_area.duplicate() as Control
    _socket_2.name = "CardDropArea2"
    add_child(_socket_2)
    _socket_2.position = card_drop_area.position + SOCKET_2_OFFSET
    var cancel := _socket_2.get_node_or_null("CancelRedCardPanel")
    if cancel:
        cancel.hide()
    _socket_2.hide()
    return _socket_2


func _fill_socket_2(card_ui: CardUI) -> void:
    var socket := _ensure_socket_2()
    socketed_card_ui_2 = card_ui
    if not Global.charged_card_instance_ids.has(card_ui.card.instance_id):
        Global.charged_card_instance_ids.append(card_ui.card.instance_id)
    var texture := socket.get_node_or_null(
            "CardBackground/CardFrame/Panel/ChargedCardTexture") as TextureRect
    if texture:
        texture.texture = card_ui.card.icon
        texture.show()
    var socket_title := socket.get_node_or_null(
            "CardBackground/CardFrame/CardBanner/Title") as Label
    if socket_title:
        socket_title.text = card_ui.card.name
        socket_title.modulate.a = 1.0
    var desc := socket.get_node_or_null(
            "CardBackground/CardFrame/DescriptionPanel/ChargedCardDescriptionCenter/ChargedCardDescription") as RichTextLabel
    if desc:
        desc.text = "[center]%s[/center]" % card_ui.card.get_colorized_description(
                card_ui.card.description)
    var req := socket.get_node_or_null(
            "CardBackground/CardFrame/RequirementPanel/RequirementLabel") as Label
    if req:
        req.text = _requirement_text(card_ui.card)
    socket.show()
    card_ui.hide()


func _clear_socket_2() -> void:
    socketed_card_ui_2 = null
    if is_instance_valid(_socket_2):
        _socket_2.hide()


# Same wording the socket 1 badge uses (card_ui.gd is the source for the real card face).
func _requirement_text(card: Card) -> String:
    match card.requirement:
        Card.Requirement.NONE: return "Any"
        Card.Requirement.MIN: return "Min %d" % card.requirement_number
        Card.Requirement.MAX: return "Max %d" % card.requirement_number
        Card.Requirement.EVEN: return "Even"
        Card.Requirement.ODD: return "Odd"
        Card.Requirement.RED: return "Red"
        Card.Requirement.EXACT: return "Exact %d" % card.requirement_number
        Card.Requirement.MULTIPLE: return "Mult %d" % card.requirement_number
        _: return "Any"


# --- Armageddon: the ARMED empty socket -------------------------------------------------------
# With the Armageddon blessing up, rolling Red on an EMPTY socket is a legal and powerful move.
# The empty socket placeholder ("?" / "Drop a card" / "Place a card here") is then not merely
# uninviting - it is FALSE, and it is the only thing the socket ever says to the player. This
# replaces it with what the empty socket actually does now, and undims the card so it reads as
# armed rather than disabled. (Julien, 2026-08-25: "remind the player he can actually roll a
# dice without putting a card in the socket".)
#
# ⚠️ NEVER put a texture in charged_card_texture here, tempting as an Armageddon card face is:
# roll_dice() uses `charged_card_texture.texture != null` as its "a card is socketed" test, and
# _fire_socketless_red() early-returns on the same check. Filling the art slot would make the
# die think it has a card, set playing_red_card, and silently kill the whole blessing.
const SOCKET_REST_SCALE := Vector2(0.857, 0.857)
const ARMED_SOCKET_TITLE := "Armageddon"
const ARMED_SOCKET_RIBBON := "No card needed"
const ARMED_SOCKET_TEXT := "Roll to deal X damage to ALL enemies"
# Armageddon+ also grants Strength on every socketless roll (_fire_socketless_red), so the
# socket has to say so - the status badge tooltip is the only other place that does.
const ARMED_SOCKET_TEXT_PLUS := "Roll to deal X damage to ALL enemies and gain Strength"
# Armageddon's own card art, shown in the art slot's place. A SEPARATE node, never
# charged_card_texture - see the warning above; that slot has to stay null.
# ⚠️ load() at runtime, NOT preload: a preload of an asset with no .ctex is a PARSE error, and
# a parse error takes the whole of dice.gd down (and with it every scene that touches the die).
# Same reason _reskin_enemy loads act-2 art at runtime. Worth nothing more than a missing
# overlay if it ever fails; the rest of the armed socket still reads correctly.
const ARMED_SOCKET_ICON_PATH := "res://socketless_red.png"

var _socket_showing_armed := false
var _armed_socket_flash_tween: Tween
var _armed_socket_icon: TextureRect


# Built lazily so the scene file stays untouched, and reused thereafter.
func _ensure_armed_socket_icon() -> TextureRect:
    if is_instance_valid(_armed_socket_icon):
        return _armed_socket_icon
    var tex := load(ARMED_SOCKET_ICON_PATH) as Texture2D
    if tex == null:
        return null
    var icon := TextureRect.new()
    icon.name = "ArmedSocketIcon"
    icon.texture = tex
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(icon)
    icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _armed_socket_icon = icon
    return icon


func _hide_armed_socket_icon() -> void:
    if is_instance_valid(_armed_socket_icon):
        _armed_socket_icon.hide()


# Deliberately does NOT test socketed_card_ui: _on_cancel_red_card_pressed() calls
# _set_socket_empty() BEFORE it nulls that reference, so including it here would leave the
# socket looking inert after a cancel. Every caller already means "the display is empty now".
func _socket_is_armed() -> bool:
    return Global.socketless_red and dice_type == "red"


func _apply_armed_socket() -> void:
    title.text = ARMED_SOCKET_TITLE
    title.modulate.a = 1.0
    card_banner.modulate.a = 1.0
    # The art slot itself stays empty (it must), but the space it leaves is the biggest part
    # of the card, so the blessing's own art fills it from a separate overlay node.
    var armed_icon := _ensure_armed_socket_icon()
    if armed_icon != null:
        armed_icon.show()
        panel.modulate.a = 1.0
    else:
        # No art available - keep the slot dim-but-not-dead rather than showing a bright void.
        panel.modulate.a = 0.5
    $CardDropArea/CardBackground/CardFrame/DescriptionPanel.modulate.a = 1.0
    requirement_panel.add_theme_stylebox_override("panel", CardUI.RED_STYLEBOX)
    requirement_label.text = ARMED_SOCKET_RIBBON
    requirement_panel.modulate.a = 1.0
    description_panel.modulate.a = 1.0
    _set_armed_socket_description()
    var was_armed := _socket_showing_armed
    _socket_showing_armed = true
    # One-shot on the TRANSITION only. A permanent pulse would be on screen for most of a fight
    # (you sit on Red with an empty socket a lot) and would go to wallpaper the same way an
    # always-on effect does; this beat exists to catch the eye the moment the state appears.
    if not was_armed:
        _flash_armed_socket()


# Same measure-and-step-down loop as _set_charged_description(): this is the same 140x56 slot
# and the sentence is long enough to need it. Routed through colorize_tooltip() rather than
# set as a raw string so "X" becomes the Power glyph and "Strength" picks up the keyword gold,
# exactly as they would on a real card face.
func _set_armed_socket_description() -> void:
    # Explicitly typed, not inferred: a ternary is one of the spots where GDScript quietly
    # degrades to Variant, and a degraded local poisons every `:=` after it in the file.
    var text: String = ARMED_SOCKET_TEXT_PLUS if Global.socketless_red_strength > 0 \
            else ARMED_SOCKET_TEXT
    description_panel.offset_top = CardUI.DESC_PANEL_TOP
    description_panel.offset_bottom = CardUI.DESC_PANEL_TOP + CardUI.DESC_PANEL_HEIGHT
    var available := description_panel.size.y
    for font_size: int in CHARGED_DESC_FONT_SIZE_CANDIDATES:
        charged_card_description.add_theme_font_size_override("normal_font_size", font_size)
        charged_card_description.text = "[center]%s[/center]" % KeywordColorizer.colorize_tooltip(
                text, font_size + 2)
        if charged_card_description.get_content_height() <= available:
            return


# Warm brightness rather than a scale punch: card_drop_area has no pivot_offset authored, so
# scaling it would grow from the top-left corner, and setting a pivot here would silently
# change _set_socket_filled()'s existing scale tween too.
func _flash_armed_socket() -> void:
    if _armed_socket_flash_tween and _armed_socket_flash_tween.is_valid():
        _armed_socket_flash_tween.kill()
    _armed_socket_flash_tween = create_tween()
    _armed_socket_flash_tween.tween_property(
            card_drop_area, "modulate", Color(1.7, 1.5, 1.2, 1.0), 0.10) \
            .from(Color.WHITE).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    _armed_socket_flash_tween.tween_property(
            card_drop_area, "modulate", Color.WHITE, 0.38) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# Armageddon is Min 6 and NOT red_only, so it is usually played from some other die entirely -
# meaning the socket was last painted (by _set_socket_empty) long before the flag existed, and
# switching to Red is the first time the blessing's own socket is on screen at all. Without
# this the socket keeps asking for a card the player does not need.
func _refresh_empty_socket_look() -> void:
    if _flying_charged_card_to_discard:
        return
    if charged_card_texture.texture != null or is_instance_valid(socketed_card_ui):
        return
    _set_socket_empty()


# --- Surge motes -----------------------------------------------------------------------------
# Sparks leaking off the central die while SURGE is up (Julien, 2026-08-25, after liking the
# motes on the infusion and dice-shop dice).
#
# GATED on Surge rather than running all the time, deliberately. Those two screens use motes to
# say "this die is special" about an otherwise static image; the combat die already has three
# continuous systems saying "alive" (emanation tongues, aura ring, power orbs), so a permanent
# fourth layer would be wallpaper by turn three - and it would spend clutter in the one region
# this scene keeps having to fight for, the slot row sitting ~15px above the die art. Surge, by
# contrast, had NO presence on the die at all: its whole fantasy is "this die is weighted, every
# roll pays extra", and the only tell was a badge over on the player, nowhere near the die.
#
# Density scales with Global.surge_amount, so building the ladder (Sleight -> Ringer -> a held
# Dead Weight) shows on the die itself instead of only in a badge number.
const SURGE_MOTE_INTERVAL_BASE := 0.55   # spawn gap at Surge 1; also the idle poll rate
const SURGE_MOTE_INTERVAL_STEP := 0.09   # shaved off per extra stack
const SURGE_MOTE_INTERVAL_FLOOR := 0.26  # never denser than the dice shop per-die rate
# Bigger and brighter than the shop/infusion motes (11-22px at 0.38-0.62), and not by taste:
# those sit on a static die on a dark screen, while this one is already inside the emanation's
# light pool. Measured at the shop's values here, the motes lit 99 sampled px against an 84px
# noise floor from the emanation's own animation - i.e. they rendered and did not exist. Size
# is the strongest lever because glow_texture() concentrates its brightness in a small core.
const SURGE_MOTE_SIZE_MIN := 14.0
const SURGE_MOTE_SIZE_MAX := 26.0
const SURGE_MOTE_ALPHA_MIN := 0.50
const SURGE_MOTE_ALPHA_MAX := 0.75
const SURGE_MOTE_ALPHA_PER_STACK := 0.03
const SURGE_MOTE_STACK_CAP := 4
# Spawn band measured UP from _mote_spawn_base_y, and how far a mote climbs.
const SURGE_MOTE_SPAWN_BAND := 38.0
const SURGE_MOTE_RISE_MIN := 55.0
const SURGE_MOTE_RISE_MAX := 95.0
const SURGE_MOTE_DRIFT_X := 14.0
# Hard ceiling, as a gap above the die art's top edge. The dice-type slot row sits just above
# the die and draws at z_index 5, so a spark that drifts into it does not overlap the tray - it
# vanishes behind an opaque plate mid-flight. Every rise is clamped against this rather than
# just being tuned to land short of it, so retuning the band above can never quietly reopen it.
const SURGE_MOTE_HEADROOM := 18.0
# Strongly warm-shifted, not merely tinted. A spark in the die's own accent is invisible inside
# that die's light field - the way the charge gust failed on 2026-08-25 - and at a half lerp it
# was still blue-on-blue, rendering as a pale smudge on the Blue die rather than an ember. This
# lands close to burst()'s warm gold, which also happens to be the colour the card text already
# teaches for the Surge keyword, while keeping a trace of the die's hue.
const SURGE_MOTE_WARMTH := 0.78
const SURGE_MOTE_GROUP := "surge_mote"
# ⚠️ Being a LATER SIBLING is not enough to draw in front here: dice.tscn gives DiceDisplay
# z_index 1, and z_index beats tree order. At the default 0 these motes rendered perfectly -
# behind the opaque die face, invisible, while every property probe (visible, alpha, texture,
# rect) looked correct. 2 puts them just in front of the face and still under DiceInk (4), so
# an inked die keeps hiding them, and far under the ROLL button (10) and socket panels (8).
const SURGE_MOTE_Z_INDEX := 8

var _surge_mote_timer: Timer
# The die art's RESTING rect in root-local space. Motes are parented to the ROOT, never to
# dice_display, so the hop cannot drag them along mid-flight - which is precisely why they need
# the resting footprint rather than the live one.
var _die_rest_rect := Rect2()
# Where motes are born. NOT simply the die art's bottom edge: the art runs 25px past the bottom
# of the dice root, and the ROLL button is a sibling anchored there at z_index 10 - so the
# lowest slice of the die is covered, and motes spawned into it were born invisible and rose
# out from behind a button. Derived from the button's real rect so moving it can't reopen that.
var _mote_spawn_base_y := 0.0


func _setup_surge_motes() -> void:
    _surge_mote_timer = Timer.new()
    _surge_mote_timer.wait_time = SURGE_MOTE_INTERVAL_BASE
    _surge_mote_timer.timeout.connect(_on_surge_mote_timer_timeout)
    add_child(_surge_mote_timer)
    _surge_mote_timer.start()


# Deferred from _ready so the anchored layout has resolved. Read once: the plinth dip moves
# panel.position on big landings, so sampling live would drift the spawn band by a few pixels
# for the ~0.3s a dip lasts.
func _cache_die_rest_rect() -> void:
    _die_rest_rect = Rect2(panel.position + dice_display.position, dice_display.size)
    _mote_spawn_base_y = _die_rest_rect.end.y
    var roll_button := get_node_or_null("Button") as Control
    if roll_button != null:
        _mote_spawn_base_y = minf(_mote_spawn_base_y, roll_button.position.y)


func _surge_mote_interval(surge: int) -> float:
    if surge <= 1:
        return SURGE_MOTE_INTERVAL_BASE
    return maxf(SURGE_MOTE_INTERVAL_FLOOR,
            SURGE_MOTE_INTERVAL_BASE - SURGE_MOTE_INTERVAL_STEP * float(surge - 1))


func _on_surge_mote_timer_timeout() -> void:
    var surge: int = Global.surge_amount
    # start() rather than assigning wait_time: Timer re-arms itself with the OLD value before
    # emitting, so a mid-turn Sleight (or its expiry) would otherwise take a full extra cycle
    # to change the density.
    _surge_mote_timer.start(_surge_mote_interval(surge))
    if surge <= 0:
        return
    _spawn_surge_mote(surge)


func _spawn_surge_mote(surge: int) -> void:
    if _die_rest_rect.size == Vector2.ZERO:
        return
    var tint := DicePalette.burst(dice_type, SURGE_MOTE_WARMTH)
    var mote := TextureRect.new()
    mote.texture = DicePalette.glow_texture()
    mote.material = DicePalette.additive_material()
    mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mote.stretch_mode = TextureRect.STRETCH_SCALE
    # IGNORE, not the Control default STOP: these sit over the die and would otherwise eat the
    # hovers belonging to the Power number's tooltip zone and the ROLL button.
    mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mote.z_index = SURGE_MOTE_Z_INDEX
    # Group, not a name prefix: Godot renames duplicate siblings to "@SurgeMote@2", which no
    # begins_with("SurgeMote") test ever matches - debug_surge_motes silently saw one mote at
    # a time that way.
    mote.name = "SurgeMote"
    mote.add_to_group(SURGE_MOTE_GROUP)
    var mote_size := randf_range(SURGE_MOTE_SIZE_MIN, SURGE_MOTE_SIZE_MAX)
    mote.size = Vector2(mote_size, mote_size)
    mote.modulate = Color(tint.r, tint.g, tint.b, 0.0)
    mote.position = Vector2(
            _die_rest_rect.position.x + randf_range(0.0, _die_rest_rect.size.x - mote_size),
            _mote_spawn_base_y - randf_range(0.0, SURGE_MOTE_SPAWN_BAND))
    add_child(mote)

    var extra_stacks := float(mini(surge, SURGE_MOTE_STACK_CAP) - 1)
    var peak_alpha := randf_range(SURGE_MOTE_ALPHA_MIN, SURGE_MOTE_ALPHA_MAX) \
            + extra_stacks * SURGE_MOTE_ALPHA_PER_STACK
    var ceiling_y := _die_rest_rect.position.y - SURGE_MOTE_HEADROOM
    var rise := minf(randf_range(SURGE_MOTE_RISE_MIN, SURGE_MOTE_RISE_MAX),
            maxf(mote.position.y - ceiling_y, 0.0))
    var duration := randf_range(1.0, 1.6)
    var t := create_tween()
    t.set_parallel(true)
    t.tween_property(mote, "position:y", mote.position.y - rise, duration) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    t.tween_property(mote, "position:x",
            mote.position.x + randf_range(-SURGE_MOTE_DRIFT_X, SURGE_MOTE_DRIFT_X), duration)
    t.tween_property(mote, "modulate:a", peak_alpha, duration * 0.3)
    t.tween_property(mote, "modulate:a", 0.0, duration * 0.45).set_delay(duration * 0.55)
    t.chain().tween_callback(mote.queue_free)


# --- Overcharge ------------------------------------------------------------------------------
# "My power is uncontrollable" (Julien, 2026-08-26, asking for a Balatro-style absurd-combo
# escalation without letting it take over the screen). The existing charge glow already grows
# with banked power, but it PLATEAUS - the emanation's own energy gain tops out around 12-16
# power, so a 45-power turn and an 18-power turn look nearly identical. Everything below lives
# in that unclaimed headroom above the plateau.
#
# Three ideas drive the feel, in descending order of how much work they do:
#   1. AUTONOMY - past T2 the die fires gusts on its own timer, with no roll happening. Nothing
#      reads "this is no longer under my control" like effects going off unprompted.
#   2. INSTABILITY - the Power number stops being a label and starts burning (power_float's
#      `heat`), because in Balatro the SCORE is the star of the spectacle, not the background.
#   3. CONTRAST - the world dims slightly instead of the die getting brighter. The additive
#      stack around this die is already near its ceiling (documented overexposure trap), so
#      more light is the one lever that cannot work; taking light away from everything else
#      makes the die read hotter for free.
#
# SINGLE DRIVER: _update_overcharge() is called from the tail of _update_dice_aura_charge(),
# which every single power-changing path already calls (roll, card reset, turn start, type
# switch, Reservoir keep, ricochet restore, _ready). So the tier follows banked power for free
# and, crucially, TEARS ITSELF DOWN on every reset path without any of them knowing it exists.
const OVERCHARGE_T2_THRESHOLD := 30
const OVERCHARGE_T3_THRESHOLD := 46
# Where the continuous 0..1 level starts once tier 1 is reached. Without a floor, crossing
# POWER_TIER_THRESHOLD would leave literally no trace (t is 0 at exactly 18) and the existing
# ignition flare would fire into nothing.
const OVERCHARGE_LEVEL_FLOOR := 0.25

# ⚠️ INK. Ink exists to hide the Power number from the player; a roaring die and a darkening
# room would announce the same information the enemy just paid a turn to conceal, so the
# escalation freezes while inked (it does not tear down - it stops CLIMBING, and resumes when
# the ink clears). The emanation's own charge glow already leaks a little under ink, which is
# pre-existing and much quieter. Flip this one bool to take the other side of that call
# ("you can hide the number, you cannot hide the energy") - nothing else needs to change.
const OVERCHARGE_DURING_INK := false

# 2 - the number ignites. heat drives colour + flicker + extra tremor in power_float.gdshader.
const OVERCHARGE_HEAT_TWEEN_TIME := 0.35
# Embers dripping off the number. Tier-gated: at T1 the number only crackles hotter.
const OVERCHARGE_EMBER_MIN_TIER := 2
const OVERCHARGE_EMBER_INTERVAL_T2 := 0.34
const OVERCHARGE_EMBER_INTERVAL_T3 := 0.17
const OVERCHARGE_EMBER_SIZE_MIN := 10.0
const OVERCHARGE_EMBER_SIZE_MAX := 20.0
const OVERCHARGE_EMBER_ALPHA_MIN := 0.42
const OVERCHARGE_EMBER_ALPHA_MAX := 0.70
const OVERCHARGE_EMBER_RISE_MIN := 34.0
const OVERCHARGE_EMBER_RISE_MAX := 62.0
const OVERCHARGE_EMBER_DRIFT_X := 11.0
# Same warmth as the Surge sparks and for the same measured reason: an ember in the die's own
# accent vanishes inside the die's own light field.
const OVERCHARGE_EMBER_WARMTH := 0.82
# Matches SURGE_MOTE_Z_INDEX - in front of the die face (z 1), under DiceInk (4), the socket
# panels (8) and the ROLL button (10).
const OVERCHARGE_EMBER_Z_INDEX := 2
const OVERCHARGE_EMBER_GROUP := "overcharge_ember"

# 1 - spontaneous mini-gusts. Reuses the shipped charge wavefront at reduced amplitude.
const OVERCHARGE_GUST_MIN_TIER := 2
const OVERCHARGE_GUST_INTERVAL_T2 := Vector2(1.9, 3.4)
const OVERCHARGE_GUST_INTERVAL_T3 := Vector2(1.1, 2.1)
const OVERCHARGE_GUST_PEAK_T2 := 0.40
const OVERCHARGE_GUST_PEAK_T3 := 0.58
const OVERCHARGE_GUST_REACH := 46.0     # shorter than a real charge's 62 - a leak, not an event
const OVERCHARGE_GUST_TIME := 0.52      # and slower, so it reads as a breath rather than a bang
# A real charge must never be swallowed, so the two directions are NOT symmetric: a charge
# always kills whatever spontaneous gust is in flight (the shared kill loop in _fire_gust), but
# a spontaneous one refuses to fire in the wake of a real one and never touches the charge
# cooldown clock. Otherwise a leak landing 100ms before a Charge 4 would eat its wavefront.
const OVERCHARGE_GUST_QUIET_AFTER_CHARGE_MS := 700

# 3 - the world recedes. Deltas ON TOP of whatever the background material is authored with,
# never absolute values - a hardcoded restore target is the stale-copy failure mode that the
# emanation's row clearance already had to be rescued from.
const OVERCHARGE_VIGNETTE_ADD := 0.16
const OVERCHARGE_BRIGHTNESS_DROP := 0.08
const OVERCHARGE_WORLD_TWEEN_TIME := 0.6

# 4 - audio simmer. PLACEHOLDER asset (project convention): a synthesized 2s seamless drone.
# load() not preload(): a missing/unimported file in a preload is a PARSE ERROR that takes the
# whole of dice.gd down with it, and gdtoolkit does not catch it (documented, cost 3 runs).
const OVERCHARGE_HUM_PATH := "res://sounds/overcharge_hum.wav"
const OVERCHARGE_HUM_MIN_DB := -30.0
# -9, not -13: this is a texture meant to be FELT under the other SFX, and the first pass
# was quiet enough to miss entirely (compounded by the v1 asset being nearly all sub-bass).
# This is the first dial to turn down if it crowds the mix.
const OVERCHARGE_HUM_MAX_DB := -9.0
const OVERCHARGE_HUM_FADE_IN := 0.7
const OVERCHARGE_HUM_FADE_OUT := 0.45
const OVERCHARGE_HUM_PITCH_MAX := 1.16
# The landing thud's chain ladder is capped at 6 steps so it cannot climb into a squeal on a
# normal turn. Overcharge lifts that ceiling: a chain long enough to reach it is exactly the
# situation the player should hear running away from them.
const OVERCHARGE_THUD_PITCH_CAP_STEP := 2

var _overcharge_tier := 0
var _overcharge_level := 0.0
var _overcharge_heat_tween: Tween
var _overcharge_ember_timer: Timer
var _overcharge_gust_countdown := 0.0
var _overcharge_hum: AudioStreamPlayer
var _overcharge_hum_tween: Tween
var _world_dim_material: ShaderMaterial
var _world_dim_base_vignette := 0.0
var _world_dim_base_brightness := 0.0
var _world_dim_resolved := false
var _world_dim_tween: Tween


func _setup_overcharge() -> void:
    # ⚠️ SEED `heat` BEFORE ANYTHING TRIES TO TWEEN OR READ IT. A ShaderMaterial does not
    # expose `shader_parameter/<name>` as a real property until that parameter has been
    # ASSIGNED at least once - declaring the uniform in the .gdshader is not enough, and
    # dice.tscn's material only authors amplitude/speed. Without this line the feature is
    # DEAD but looks alive: tween_property() finds no such property (console error, silent
    # no-op) and get_shader_parameter() returns null, so heat sits at the shader default
    # forever and the number never ignites. Caught by debug_overcharge - the "does the
    # shader expose a heat uniform" probe passed the whole time it was broken.
    if current_power.material is ShaderMaterial:
        (current_power.material as ShaderMaterial).set_shader_parameter("heat", 0.0)

    _overcharge_ember_timer = Timer.new()
    _overcharge_ember_timer.wait_time = OVERCHARGE_EMBER_INTERVAL_T2
    _overcharge_ember_timer.timeout.connect(_on_overcharge_ember_timer_timeout)
    add_child(_overcharge_ember_timer)
    _overcharge_ember_timer.start()

    var stream: AudioStream = load(OVERCHARGE_HUM_PATH)
    if stream != null:
        _overcharge_hum = AudioStreamPlayer.new()
        _overcharge_hum.stream = _looping_copy_of(stream)
        _overcharge_hum.bus = &"SFX"
        _overcharge_hum.volume_db = OVERCHARGE_HUM_MIN_DB
        add_child(_overcharge_hum)


# The two ends of the number's incandescence swing, derived from the ACTIVE die rather than
# fixed. Julien's playtest verdict: the Power number must keep saying which die is active -
# it is the one element the HUD leans on to answer that - so it goes white-hot in its own
# hue instead of turning orange. Called from update_dice_display(), the same chokepoint that
# already retints the number, its outline and the emanation, so switching type recolours the
# ignition for free and infused dice inherit it (DicePalette is infusion-aware).
#
# Set directly rather than tweened, so unlike `heat` these need no seeding - a written
# parameter is what makes the property exist in the first place.
func _update_power_ember_colors() -> void:
    if not (current_power.material is ShaderMaterial):
        return
    var mat: ShaderMaterial = current_power.material
    var accent := DicePalette.accent(dice_type)
    # Trough of the flicker: the accent, pushed a little richer so even the low end of the
    # swing reads as charged rather than identical to rest.
    # ⚠️ The swing must be MONOTONIC away from rest, never straddling it. Making the trough
    # MORE saturated than the accent put the resting colour in the middle of the range, so
    # roughly half of every flicker cycle rendered identical to rest and the whole ignition
    # measured as ~0 changed pixels on blue. Trough is now a touch hotter than rest, peak is
    # much hotter, and every point in between is brighter than the number's resting look.
    var deep := Color.from_hsv(accent.h, accent.s * 0.9, 1.0)
    mat.set_shader_parameter("ember_color", deep)
    # Peak of the flicker. Built in HSV, NOT with lightened(): blue's own blue channel is
    # already 1.0, so lightening it can only raise the other two - i.e. it walks straight to
    # white and the hue this whole change exists to preserve is the first thing lost
    # (measured r=.86 g=.90 b=.93, a white number). Dropping saturation while pinning value
    # keeps the hue intact at full brightness, and works for warm accents too.
    mat.set_shader_parameter("ember_core", Color.from_hsv(accent.h, accent.s * 0.35, 1.0))


# The hum has to loop, and the .import that says so is the one thing here an editor re-scan
# could quietly reset (loop_mode would fall back to Disabled and the drone would play once,
# reading as a bug rather than a missing loop). Re-asserting it on a DUPLICATE costs nothing,
# never mutates the shared imported resource, and makes the import setting a redundancy rather
# than a dependency.
func _looping_copy_of(stream: AudioStream) -> AudioStream:
    var wav := stream as AudioStreamWAV
    if wav == null:
        return stream  # not a WAV (someone swapped in an .ogg) - trust its own import
    if wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
        return wav
    var bytes_per_frame := 0
    if wav.format == AudioStreamWAV.FORMAT_16_BITS:
        bytes_per_frame = 2
    elif wav.format == AudioStreamWAV.FORMAT_8_BITS:
        bytes_per_frame = 1
    if bytes_per_frame == 0:
        return wav  # compressed format - frame count isn't derivable from byte length
    if wav.stereo:
        bytes_per_frame *= 2
    var looped: AudioStreamWAV = wav.duplicate()
    looped.loop_begin = 0
    looped.loop_end = looped.data.size() / bytes_per_frame
    looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
    return looped


func _overcharge_tier_for(power: int) -> int:
    if power >= OVERCHARGE_T3_THRESHOLD:
        return 3
    if power >= OVERCHARGE_T2_THRESHOLD:
        return 2
    if power >= POWER_TIER_THRESHOLD:
        return 1
    return 0


# Called from the tail of _update_dice_aura_charge() - see the section header for why that is
# the only hook this system needs.
func _update_overcharge() -> void:
    # Frozen, not torn down, while inked: the tier holds whatever it reached so the die does
    # not visibly deflate the instant an enemy inks it (which would itself be information).
    if not OVERCHARGE_DURING_INK and Global.ink_active:
        return

    var power := int(Global.roll_value)
    var tier := _overcharge_tier_for(power)
    var span := float(OVERCHARGE_T3_THRESHOLD - POWER_TIER_THRESHOLD)
    var t := clampf((float(power) - float(POWER_TIER_THRESHOLD)) / maxf(span, 1.0), 0.0, 1.0)
    var level := 0.0
    if tier > 0:
        level = OVERCHARGE_LEVEL_FLOOR + (1.0 - OVERCHARGE_LEVEL_FLOOR) * t

    var previous_tier := _overcharge_tier
    _overcharge_tier = tier
    _overcharge_level = level

    _apply_overcharge_heat(level)
    _apply_overcharge_hum(level)
    _apply_world_dim(level)

    if tier < OVERCHARGE_GUST_MIN_TIER:
        _overcharge_gust_countdown = 0.0
    elif previous_tier < OVERCHARGE_GUST_MIN_TIER:
        # Arm on ENTERING the tier rather than firing immediately: the roll that crossed the
        # threshold already has its own celebration, and a leak on the same frame would land
        # inside it and read as part of the roll instead of as the die acting on its own.
        _overcharge_gust_countdown = _overcharge_gust_interval()

    if tier > previous_tier and tier >= 2:
        # Tier 1's ceremony already exists (the ignition flare + freeze in _apply_roll_result),
        # so only the new ceilings get a new one, or 18 would fire two beats on one roll.
        _play_overcharge_escalation(tier)


func _apply_overcharge_heat(level: float) -> void:
    if current_power.material == null:
        return
    if _overcharge_heat_tween and _overcharge_heat_tween.is_valid():
        _overcharge_heat_tween.kill()
    _overcharge_heat_tween = create_tween()
    var tweener := _overcharge_heat_tween.tween_property(
            current_power.material, "shader_parameter/heat", level, OVERCHARGE_HEAT_TWEEN_TIME)
    if tweener:
        tweener.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _apply_overcharge_hum(level: float) -> void:
    if _overcharge_hum == null:
        return
    if _overcharge_hum_tween and _overcharge_hum_tween.is_valid():
        _overcharge_hum_tween.kill()
    _overcharge_hum_tween = create_tween()
    if level <= 0.0:
        if not _overcharge_hum.playing:
            return
        _overcharge_hum_tween.tween_property(
                _overcharge_hum, "volume_db", OVERCHARGE_HUM_MIN_DB, OVERCHARGE_HUM_FADE_OUT)
        _overcharge_hum_tween.tween_callback(_overcharge_hum.stop)
        return
    if not _overcharge_hum.playing:
        _overcharge_hum.volume_db = OVERCHARGE_HUM_MIN_DB
        _overcharge_hum.play()
    _overcharge_hum.pitch_scale = lerpf(1.0, OVERCHARGE_HUM_PITCH_MAX, level)
    _overcharge_hum_tween.tween_property(_overcharge_hum, "volume_db",
            lerpf(OVERCHARGE_HUM_MIN_DB, OVERCHARGE_HUM_MAX_DB, level), OVERCHARGE_HUM_FADE_IN)


# Resolved lazily and ONCE, and by group rather than by path, because this node also lives in
# render harnesses and in dice.tscn on its own, where no battle background exists at all.
#
# The material is DUPLICATED and reassigned rather than written to in place. battle.tscn's
# background material is a SubResource, i.e. potentially shared between instantiations of that
# scene, and a compounding "baseline" captured from an already-dimmed copy would darken the
# game a little more every fight. Owning a private copy makes that impossible rather than
# merely unlikely, and removes any need to restore anything on the way out.
func _ensure_world_dim() -> void:
    if _world_dim_resolved:
        return
    _world_dim_resolved = true
    var bg := get_tree().get_first_node_in_group("battle_background") as CanvasItem
    if bg == null:
        return
    var shared := bg.material as ShaderMaterial
    if shared == null:
        return
    # Same "unassigned parameters read back as null" rule as the heat seed above - here the
    # values are authored on the material so they resolve, but a stripped/retuned background
    # material must degrade to "no world dim" rather than crash the whole power update path.
    var vig = shared.get_shader_parameter("vignette_strength")
    var bright = shared.get_shader_parameter("brightness")
    if vig == null or bright == null:
        return
    var owned: ShaderMaterial = shared.duplicate()
    bg.material = owned
    _world_dim_material = owned
    _world_dim_base_vignette = float(vig)
    _world_dim_base_brightness = float(bright)


func _apply_world_dim(level: float) -> void:
    _ensure_world_dim()
    if _world_dim_material == null:
        return
    if _world_dim_tween and _world_dim_tween.is_valid():
        _world_dim_tween.kill()
    _world_dim_tween = create_tween()
    _world_dim_tween.set_parallel(true)
    _world_dim_tween.tween_property(_world_dim_material, "shader_parameter/vignette_strength",
            _world_dim_base_vignette + OVERCHARGE_VIGNETTE_ADD * level,
            OVERCHARGE_WORLD_TWEEN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _world_dim_tween.tween_property(_world_dim_material, "shader_parameter/brightness",
            _world_dim_base_brightness - OVERCHARGE_BRIGHTNESS_DROP * level,
            OVERCHARGE_WORLD_TWEEN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# One-shot beat on crossing T2/T3. Deliberately built from parts that already ship (the same
# flare as the tier-1 ignition, the same wavefront as a charge, the same thud stream) - a new
# ceiling should sound like MORE of this die, not like a different game.
func _play_overcharge_escalation(tier: int) -> void:
    var big := tier >= 3
    _spawn_thrown_die_flare(self, current_power.get_global_rect().get_center(),
            DicePalette.burst(dice_type, 0.7), big)
    Shaker.hit_stop(0.12 if big else 0.09)
    _fire_gust(DicePalette.burst(dice_type, 0.6),
            0.85 if big else 0.7, CHARGE_GUST_REACH, CHARGE_GUST_TIME)
    # PLACEHOLDER: the landing thud dropped an octave and a half reads as a low detonation.
    SFXPlayer.play(LAND_THUD_SOUND, false, 0.34 if big else 0.45, -1.0)


func _overcharge_gust_interval() -> float:
    # Explicitly typed, not `:=`: a ternary is one of the places GDScript quietly drops the
    # static type, and a degraded Variant here breaks inference further down the file.
    var band: Vector2 = OVERCHARGE_GUST_INTERVAL_T3 if _overcharge_tier >= 3 \
            else OVERCHARGE_GUST_INTERVAL_T2
    return randf_range(band.x, band.y)


# Driven from _process, not a Timer, so the countdown genuinely stops while the tier is below
# threshold instead of a timer firing into a guard forever.
func _tick_overcharge_gust(delta: float) -> void:
    if _overcharge_tier < OVERCHARGE_GUST_MIN_TIER:
        return
    if not OVERCHARGE_DURING_INK and Global.ink_active:
        return
    _overcharge_gust_countdown -= delta
    if _overcharge_gust_countdown > 0.0:
        return
    _overcharge_gust_countdown = _overcharge_gust_interval()
    if charge_pulse_mode == 3:
        return
    # Never in a real charge's wake, and never on top of a front still travelling - two
    # overlapping wavefronts on an additive layer is the documented overexposure trap.
    if Time.get_ticks_msec() - _last_charge_pulse_ms < OVERCHARGE_GUST_QUIET_AFTER_CHARGE_MS:
        return
    for t: Tween in _charge_gust_tweens:
        if t and t.is_valid() and t.is_running():
            return
    var peak: float = OVERCHARGE_GUST_PEAK_T3 if _overcharge_tier >= 3 \
            else OVERCHARGE_GUST_PEAK_T2
    # The die's OWN accent, warm-shifted: a charge gust is tinted by the type being charged
    # because it announces a delivery elsewhere. Nothing is being delivered here - this is
    # this die failing to hold what it already has.
    _fire_gust(DicePalette.burst(dice_type, 0.5), peak,
            OVERCHARGE_GUST_REACH, OVERCHARGE_GUST_TIME)


func _on_overcharge_ember_timer_timeout() -> void:
    var interval: float = OVERCHARGE_EMBER_INTERVAL_T3 if _overcharge_tier >= 3 \
            else OVERCHARGE_EMBER_INTERVAL_T2
    # start() rather than assigning wait_time - a Timer re-arms with the OLD value before it
    # emits, so a tier change would otherwise take a full extra cycle to show up (same trap
    # the Surge mote timer documents).
    _overcharge_ember_timer.start(interval)
    if _overcharge_tier < OVERCHARGE_EMBER_MIN_TIER:
        return
    if not OVERCHARGE_DURING_INK and Global.ink_active:
        return
    _spawn_overcharge_ember()


func _spawn_overcharge_ember() -> void:
    var rect := Rect2(current_power.position, current_power.size)
    if rect.size == Vector2.ZERO:
        return
    var tint := DicePalette.burst(dice_type, OVERCHARGE_EMBER_WARMTH)
    var ember := TextureRect.new()
    ember.texture = DicePalette.glow_texture()
    ember.material = DicePalette.additive_material()
    ember.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ember.stretch_mode = TextureRect.STRETCH_SCALE
    # IGNORE, not the Control default STOP: these drift straight across the Power number's own
    # hover zone, which owns the tooltip that teaches what the glyph on every card means.
    ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ember.z_index = OVERCHARGE_EMBER_Z_INDEX
    ember.name = "OverchargeEmber"
    ember.add_to_group(OVERCHARGE_EMBER_GROUP)
    var ember_size := randf_range(OVERCHARGE_EMBER_SIZE_MIN, OVERCHARGE_EMBER_SIZE_MAX)
    ember.size = Vector2(ember_size, ember_size)
    ember.modulate = Color(tint.r, tint.g, tint.b, 0.0)
    # Born across the lower half of the glyph box and rising - embers come off the top of a
    # fire, they do not materialize above it.
    ember.position = Vector2(
            rect.position.x + randf_range(0.0, maxf(rect.size.x - ember_size, 1.0)),
            rect.position.y + rect.size.y * randf_range(0.35, 0.75))
    add_child(ember)

    var duration := randf_range(0.8, 1.35)
    var t := create_tween()
    t.set_parallel(true)
    t.tween_property(ember, "position:y",
            ember.position.y - randf_range(OVERCHARGE_EMBER_RISE_MIN, OVERCHARGE_EMBER_RISE_MAX),
            duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    t.tween_property(ember, "position:x",
            ember.position.x + randf_range(-OVERCHARGE_EMBER_DRIFT_X, OVERCHARGE_EMBER_DRIFT_X),
            duration)
    t.tween_property(ember, "modulate:a",
            randf_range(OVERCHARGE_EMBER_ALPHA_MIN, OVERCHARGE_EMBER_ALPHA_MAX), duration * 0.25)
    t.tween_property(ember, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
    t.chain().tween_callback(ember.queue_free)


# The battle-over panel pauses the tree while the scene is still alive, so nothing else would
# ever bring the drone down - it would keep simmering under the Game Over screen.
func _on_battle_over_screen_requested(_text, _type) -> void:
    _shutdown_overcharge()


func _shutdown_overcharge() -> void:
    _overcharge_tier = 0
    _overcharge_level = 0.0
    _overcharge_gust_countdown = 0.0
    if _overcharge_hum_tween and _overcharge_hum_tween.is_valid():
        _overcharge_hum_tween.kill()
    if _overcharge_hum != null and _overcharge_hum.playing:
        _overcharge_hum.stop()
    if _overcharge_heat_tween and _overcharge_heat_tween.is_valid():
        _overcharge_heat_tween.kill()
    if current_power != null and current_power.material != null:
        current_power.material.set_shader_parameter("heat", 0.0)
