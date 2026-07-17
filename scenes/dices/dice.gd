class_name Dice
extends Control

@onready var dice_display: TextureRect = $Panel/DiceDisplay

@onready var current_power: Label = $CurrentPower
@export var dice_type: String = "blue"
@onready var card_drop_area: Control = $CardDropArea
@onready var charged_card_texture: TextureRect = $CardDropArea/CardBackground/CardFrame/Panel/ChargedCardTexture
@onready var charged_card_description: Label = $CardDropArea/CardBackground/CardFrame/DescriptionPanel/ChargedCardDescription
@onready var requirement_panel: Panel = $CardDropArea/CardBackground/CardFrame/RequirementPanel
@onready var requirement_label: Label = $CardDropArea/CardBackground/CardFrame/RequirementPanel/RequirementLabel
@onready var bonus_effect: HBoxContainer = $CardDropArea/CardBackground/CardFrame/BonusEffect
@onready var bonus_requirement_panel: Panel = $CardDropArea/CardBackground/CardFrame/BonusEffect/BonusRequirementPanel
@onready var bonus_requirement_label: Label = $CardDropArea/CardBackground/CardFrame/BonusEffect/BonusRequirementPanel/BonusRequirementLabel
@onready var bonus_effect_label: Label = $CardDropArea/CardBackground/CardFrame/BonusEffect/BonusEffectLabel
@onready var mech_section: Control = $MechSection
@onready var mech_increase: TextureButton = $MechSection/MechIncrease
@onready var mech_decrease: TextureButton = $MechSection/MechDecrease
@onready var bonus_effect_texture: TextureRect = $CardDropArea/CardBackground/CardFrame/BonusEffect/BonusEffectTexture
@onready var bonus_separator: ColorRect = $CardDropArea/CardBackground/CardFrame/BonusSeparator

@onready var aura: ColorRect = $Panel/Aura
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
# How many ±1 power adjustments have been spent on the CURRENT mech roll. Base mech allows 1;
# the Clockwork infusion (Mech) allows 2 (see _mech_adjustments_allowed).
var mech_adjustments_used := 0
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

const MECH_ARROW_HOVER_SCALE := Vector2(1.2, 1.2)
const MECH_ARROW_HOVER_DURATION := 0.1
const MECH_ARROW_PUNCH_SCALE := Vector2(0.8, 0.8)
const MECH_ARROW_PUNCH_DURATION := 0.08

var _mech_increase_tween: Tween
var _mech_decrease_tween: Tween

# Power "clang" impact (power-manipulation cards - see _play_power_clang). Tracked so rapid
# re-triggers kill the prior tweens instead of compounding. _power_resting_modulate is
# captured in update_dice_display() so the flash always returns to the true dice-type color
# rather than whatever mid-flash brightened value modulate happens to hold.
var _power_clang_scale_tween: Tween
var _power_clang_flash_tween: Tween
var _power_clang_rattle_tween: Tween
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
        charged_card_description.text = card.get_dynamic_description(socketed_card_ui.player_modifiers)



func _ready():
    Events.active_dice_changed.connect(_on_active_dice_changed)
    Events.battle_started.connect(_on_battle_started)
    Events.dice_rolled.connect(_on_dice_rolled)
    Events.player_turn_started.connect(_on_player_turn_started)
    Events.dice_roll_reset.connect(_on_dice_roll_reset)
    Events.card_charged.connect(_on_card_charged)
    Events.reset_charged_card.connect(_on_reset_charged_card)
    Events.change_current_power.connect(_on_change_current_power)
    Events.next_roll_determined.connect(_on_next_roll_determined)
    Events.charge_dice_animation.connect(_on_charge_dice_animation)
    Events.put_ink_on_dice.connect(_on_put_ink_on_dice)
    Events.remove_ink_from_dice.connect(_on_remove_ink_from_dice)
    Events.display_next_roll_modifier.connect(_on_display_next_roll_modifier)
    Events.clear_socket.connect(_on_clear_socket)
    Events.update_roll_history_ui.connect(update_roll_history_ui)
    Events.refuel_happened.connect(_on_refuel_happened)
    Events.all_in_dice_consumed.connect(_spawn_all_in_consumed)
    Events.card_played.connect(_on_card_played_track_frame)

    
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
func _update_power_float() -> void:
    if current_power.material:
        current_power.material.set_shader_parameter("float_intensity", 0.0 if Global.roll_value == 0 else 1.0)
        var crackle_charge := smoothstep(0.0, AURA_CHARGE_FULL_AT_POWER, float(Global.roll_value))
        current_power.material.set_shader_parameter("crackle_charge", crackle_charge)

func roll_dice():
    if _roll_in_progress:
        return
    var can_roll = false
    dice_type = Global.dice_type
    # Flux check
    if not Global.roll_history.is_empty():
        for enemy in get_tree().get_nodes_in_group("enemies"):
            if enemy.status_handler._has_status("flux"):
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

    if not can_roll:
        print("no more " + dice_type + " dice")
        play_error_sound()
        return

    _roll_in_progress = true

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

    # Determine the roll result index
    var roll_index = randi() % values.size()
    Events.check_unlucky_status.emit()
    Events.check_lucky_status.emit()

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

# --- Normal roll with animation ---
    var tween = create_tween()
    var start_position = dice_display.position

    # Anticipation squash: a quick compress right before the toss, so the whole roll
    # has a wind-up beat instead of starting cold straight into the shake.
    tween.tween_property(dice_display, "scale", Vector2(1.1, 0.85), 0.05) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(dice_display, "scale", Vector2(1.0, 1.0), 0.06) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

    # Physical shake with slight vertical component
    tween.tween_property(dice_display, "position", start_position + Vector2(-10, -4), 0.04)
    tween.tween_property(dice_display, "position", start_position + Vector2(10, 4), 0.04)
    tween.tween_property(dice_display, "position", start_position, 0.03)

    # Face flips with deceleration (feels like die losing momentum)
    var flip_intervals = [0.03, 0.05, 0.08]
    for i in range(3):
        tween.tween_callback(func():
            var anim_index = randi() % faces.size()
            dice_display.texture = faces[anim_index]
        )
        tween.tween_interval(flip_intervals[i])

    # Snap to result + impact scale punch (size varies by roll value)
    tween.tween_callback(func():
        _apply_roll_result(roll_index, values, faces)
        var roll_val = values[roll_index]
        var is_max_roll = roll_val == values.max()

        _spawn_power_orbs(roll_val, dice_type, is_max_roll)

        var punch_scale = 1.08 + (roll_val / 60.0)  # 1.09 on 1, 1.28 on 12
        if is_max_roll:
            punch_scale += 0.10
        punch_scale = clampf(punch_scale, 1.08, 1.5)
        var impact = create_tween()
        impact.tween_property(dice_display, "scale", Vector2(punch_scale, punch_scale), 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        impact.tween_property(dice_display, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

        # Subtle transient pulse on the per-dice-type aura behind the die, on every landing
        # (not just max rolls) - reuses the existing aura node/shader instead of new art,
        # scaled by roll value so a bigger roll gives a slightly bigger pulse. Always settles
        # back to AURA_SCALE_REST (not a charge-dependent size) - the "grows with power" story
        # lives entirely in _update_dice_aura_charge()'s shader parameters now, not in scale.
        var aura_punch = AURA_SCALE_REST + 0.05 + (roll_val / 100.0)
        var aura_pulse := create_tween()
        aura_pulse.tween_property(aura, "scale", Vector2(aura_punch, aura_punch), 0.07) \
            .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        aura_pulse.tween_property(aura, "scale", Vector2(AURA_SCALE_REST, AURA_SCALE_REST), 0.16) \
            .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

        # Landing impact: brief hit-stop so every roll lands with weight, bigger on a max-value
        # roll. Roughly doubled (was 0.02-0.07/0.09) now that hit_stop()'s time_scale default
        # is a harder freeze - the old duration was tuned for the old, softer time_scale and
        # was imperceptible either way.
        var hit_stop_duration = clampf(roll_val * 0.013, 0.04, 0.14)
        if is_max_roll:
            hit_stop_duration = 0.2
        Shaker.hit_stop(hit_stop_duration)

        # Max-roll celebration: gold flash + particle burst on top of the normal landing.
        # The burst is tinted per dice type (accent pulled toward warm gold) so a max roll
        # on magma erupts fiery, on evil violet, etc. - the flash itself stays gold-white,
        # the universal "success" beat.
        if is_max_roll:
            var burst_material := gpu_particles_2d.process_material as ParticleProcessMaterial
            if burst_material:
                burst_material.color = DicePalette.burst(dice_type)
            gpu_particles_2d.emitting = true
            var max_flash := create_tween()
            max_flash.tween_property(dice_display, "modulate", Color(2.2, 2.0, 1.2, 1.0), 0.06) \
                .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
            max_flash.tween_property(dice_display, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.22) \
                .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
            _shake_dice_display()
    )

# Real visible shake (not a time_scale freeze) for the max-roll moment specifically.
# Inline rather than reusing Shaker.shake() since that's typed for Node2D and dice_display
# is a Control (TextureRect) - different CanvasItem branch, position still works the same way.
func _shake_dice_display() -> void:
    var orig_pos := dice_display.position
    var shake_tween := create_tween()
    var strength := 6.0
    for i in 6:
        var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
        shake_tween.tween_property(dice_display, "position", orig_pos + offset, 0.025)
        strength *= 0.7
    shake_tween.tween_property(dice_display, "position", orig_pos, 0.03)


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
    var origin := dice_display.get_global_rect().get_center()
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

        var start := origin + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
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


# Defensive wrapper: tween_property() returns null if the material's currently-loaded/
# compiled shader doesn't expose the given parameter (e.g. right after adding a new uniform
# to a .gdshader file, before a running instance has reloaded it - hit this once with
# charge_heat mid-session). Guards against that null crashing the rest of the tween chain.
func _tween_aura_shader_param(t: Tween, param_name: String, value, duration: float) -> void:
    var tweener := t.parallel().tween_property(aura.material, "shader_parameter/" + param_name, value, duration)
    if tweener:
        tweener.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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

    Global.roll_value += Global.last_roll
    Global.power_generated_this_turn += Global.last_roll
    # Lifetime power counter ("Unlimited Power" achievement) - mirrors the increment above.
    AchievementManager.add_stat("power_generated", Global.last_roll)
    current_power.modulate.a = 1.0
    _spawn_roll_popup(Global.last_roll)
    var power_punch = 1.2 + (Global.last_roll / 20.0)  # 1.25 on 1, 1.5 on 6, 1.8 on 12
    # Resting size grows with the turn's accumulated power (not just this single roll), so a
    # big turn leaves the number visibly bigger between rolls instead of snapping back to
    # the same neutral size every time - the goal Julien described as "feel more powerful"
    # rather than the rejected count-up animation.
    var power_rest_scale = clampf(1.0 + Global.roll_value / 130.0, 1.0, 1.25)
    var power_tween = create_tween()
    power_tween.tween_property(current_power, "scale", Vector2(power_punch, power_punch), 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    power_tween.tween_property(current_power, "scale", Vector2(power_rest_scale, power_rest_scale), 0.14).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

    var base_power_color = current_power.modulate
    var flash_tween = create_tween()
    flash_tween.tween_property(current_power, "modulate", base_power_color.lightened(0.6), 0.05)
    flash_tween.tween_property(current_power, "modulate", base_power_color, 0.18)

    # Magma dice special effect
    if dice_type == "magma":
        print("magma dice on")
        var enemies = get_tree().get_nodes_in_group("enemies")
        var base_damage = Global.last_roll
        var damage_effect := DamageEffect.new()
        damage_effect.amount = base_damage
        damage_effect.execute(enemies)
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
            )
        _magma_burned_this_turn = true

    # High roll sound: celebrate this die's own best possible face (max of its values,
    # not literally 6 - e.g. 12 on Giant, 8 on Even, 3 on Green), same definition of
    # "max roll" used for the landing flourish in roll_dice().
    if Global.last_roll == values.max():
        play_high_roll_sound()

    # Evil dice's crack face (0): a distinct sting so whiffing reads as a felt outcome
    # rather than a silent non-event (a 0 roll spawns no power orbs, no popup worth noting).
    if dice_type == "evil" and Global.last_roll == 0:
        play_crack_sound()

    # Separate gameplay flag (Pinpoint card checks this) - stays tied to a literal 6,
    # not the per-die max, so don't fold it into the check above.
    if Global.last_roll == 6:
        Global.has_rolled_6_this_turn = true

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
    Events.check_infused_status.emit()

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

    _set_power_text(Global.roll_value)
    current_power.modulate.a = 0.4 if Global.roll_value == 0 else 1.0
    _update_power_float()
    _update_dice_aura_charge()
    # Update roll history
    Global.roll_history.append(Global.last_roll)
    print(Global.roll_history)
    update_roll_history_ui()

    # Emit appropriate events
    if dice_type != "red":
        Events.dice_rolled.emit(Global.dice_type, Global.roll_value)
    else:
        Events.red_dice_rolled.emit()
    _check_sigil_trigger()
    Events.hover_playable_cards.emit()
    mech_adjustments_used = 0
    _update_mech_buttons()
    _update_charged_card_description()
    _roll_in_progress = false


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
        Events.charge_dice_animation.emit()

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

    var base_color := current_power.modulate
    var flash_tween := create_tween()
    flash_tween.tween_property(current_power, "modulate", DicePalette.accent(type).lightened(0.35), 0.05)
    flash_tween.tween_property(current_power, "modulate", base_color, 0.15)


func _on_active_dice_changed(new_dice_type):
    SFXPlayer.play(Global.sfx_click)
    dice_type = new_dice_type
    Global.dice_type = new_dice_type  # Make sure to update the global variable
    print("Active dice changed to: " + dice_type)
    if dice_type == "red" and new_dice_type != "red" and socketed_card_ui != null:
        _on_cancel_red_card_pressed()
    Global.next_guaranteed_roll = -1
    next_roll_panel.hide()
    Events.hover_playable_cards.emit()
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
    elif(dice_type == "mech"):
        mech_section.show()  
        card_drop_area.hide()      
    else:
        card_drop_area.hide()
        mech_section.hide()
        Global.playing_red_card = false
        
    Global.roll_value = 0
    Global.roll_history = []
    _set_power_text("0")
    current_power.modulate.a = 0.4
    current_power.scale = Vector2.ONE
    _update_power_float()
    Events.change_current_power.emit()

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

func _on_dice_rolled(rolled_dice_type, roll_value):
    print("Dice rolled: ", roll_value)
    print("Dice type: ", rolled_dice_type)

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
    
func play_high_roll_sound():
    # Pick a random sound from the list
    #dice_roll_player.stream = load("res://sound_high_roll.wav")
    #
    ## Increase volume if needed
    #dice_roll_player.volume_db = 6  # Increase volume (optional)
    #
    ## Play the sound
    #dice_roll_player.play()  
    
    var sfx_high_roll = preload("res://sfx/817811__thesoundlibrary__orchestral-hit.wav")
    SFXPlayer.play(sfx_high_roll)

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
    Global.roll_history = []
    Global.power_generated_this_turn = 0
    _magma_burned_this_turn = false
    if socketed_card_ui != null:
        _on_cancel_red_card_pressed()
    if Global.starting_power_next_turn!=0:
        print("almost there")
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

func _on_dice_roll_reset() -> void:

    if Global.no_reset:
        Global.no_reset = false
        return
    if Global.dice_type == "red":
        await get_tree().create_timer(1.0).timeout  # Wait 0.5 seconds
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
    charged_card_description.text = card_ui.card.description
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
    print(path)
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
# (see _on_charge_dice_animation): the 9 per-type ShaderMaterials are shared preloaded
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


func _on_charge_dice_animation():
    animation_player.play("charge")  # aura scale pulse (color is driven in code below)
    dice_roll_player.stream = load("res://chargedicesound.mp3")
    dice_roll_player.volume_db = 6
    dice_roll_player.play()
    # Ring of energy spawns and rushes inward (~0.3s to converge), tinted toward the active
    # dice's color so "charging a die" visibly feeds it ITS energy.
    var burst_material := gpu_particles_2d.process_material as ParticleProcessMaterial
    if burst_material:
        burst_material.color = DicePalette.burst(Global.dice_type, 0.35)
    gpu_particles_2d.emitting = true

    # Charge flash on the aura itself: pulse charge_heat to full, then settle back to the
    # banked-power level via _update_dice_aura_charge(). This replaces the old "charge"
    # animation tracks that wrote the BLUE shader's authored accent_color into whatever
    # material happened to be active - the per-type ShaderMaterials are shared preloaded
    # resources, so charging while e.g. magma was active permanently (until restart)
    # repainted magma's aura accent blue-purple.
    var aura_material := aura.material as ShaderMaterial
    if aura_material:
        var heat_tween := create_tween()
        var heat_rise := heat_tween.tween_property(aura_material, "shader_parameter/charge_heat", 1.0, 0.12)
        if heat_rise:
            heat_rise.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        heat_tween.tween_interval(0.3)
        heat_tween.tween_callback(_update_dice_aura_charge)

    # Beats are timed so the die "absorbs" the energy exactly when the inward-converging
    # particles reach its center: anticipation squash + hold while the ring collapses,
    # then a punch + flash + power pulse on impact, then settle. Tighter overall than the
    # old scattered fountain so the charge no longer upstages the hit that triggered it.
    var converge_time := 0.30

    # --- Scale: anticipation squash -> hold while energy converges -> absorb-punch -> settle ---
    var scale_tween := create_tween()
    scale_tween.tween_property(dice_display, "scale", Vector2(0.9, 0.9), 0.08) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    scale_tween.tween_interval(converge_time - 0.08)
    scale_tween.tween_property(dice_display, "scale", Vector2(1.22, 1.22), 0.07) \
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

    # Build text: "2, 5, 3"
    var text := ""
    for i in range(Global.roll_history.size()):
        if i == 0:
            text += str(Global.roll_history[i])
        else:
            text += ", " + str(Global.roll_history[i])

    # Dice-type accent, lightened toward white so it stays legible on the dark backing pill
    # regardless of type.
    var color := DicePalette.accent(Global.dice_type).lerp(Color.WHITE, 0.35)

    # Apply with RichText formatting
    roll_history.visible = true
    roll_history.clear()
    roll_history.push_color(color)
    roll_history.add_text(text)
    roll_history.pop()

func _check_sigil_trigger() -> void:
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if enemy.status_handler._has_status("sigil"):
            var sigil = enemy.status_handler._get_status("sigil")
            if Global.roll_value == sigil.stacks:
                Global.blue_dice_current_amount += 1
                Events.dice_amount_changed.emit()
                Events.charge_dice_animation.emit()


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
    popup.add_theme_font_size_override("font_size", font_size)
    popup.add_theme_constant_override("outline_size", 4)
    popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
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


# All In's "which dice got spent" flourish: pops icons for the consumed dice (each showing its
# own type+face, from all_in.gd's `consumed` array) out of the played card, same rise-and-hover
# beats as _spawn_refuel_return above - but the final leg differs. Refuel's dice fly back INTO
# the die (they're returned to your pool); All In's dice are destroyed, and came from many
# different pools at once, so there's no single die to fly into. Instead they hover noticeably
# longer (Julien: "make them visible a bit longer so the player knows what happened" - the
# previous behavior was no visual at all, just the damage number with no visible cause) and
# then burn away in place: a bright flash, a small final rise, then collapse to nothing.
const ALL_IN_CONSUMED_MAX_ICONS := 10
const ALL_IN_CONSUMED_RISE := 0.14
const ALL_IN_CONSUMED_HOVER := 0.9
const ALL_IN_CONSUMED_HOVER_BOB := 7.0
const ALL_IN_CONSUMED_BURN := 0.4
const ALL_IN_CONSUMED_STAGGER := 0.05

func _spawn_all_in_consumed(consumed: Array, target_position: Vector2 = Vector2.ZERO) -> void:
    if consumed.is_empty():
        return
    var parent_layer := get_tree().get_first_node_in_group("ui_layer")
    if not parent_layer:
        return
    var n := mini(consumed.size(), ALL_IN_CONSUMED_MAX_ICONS)
    # Icons pop from the played card (matches the other dice-flourish origins), but hover/burn
    # up near the enemy that got hit rather than over the card itself - see all_in.gd, which
    # resolves target_position from the targeted Enemy's IntentUI position.
    var spawn_origin := Global.last_played_card_position
    if spawn_origin == Vector2.ZERO:
        spawn_origin = dice_display.get_global_rect().get_center()
    var hover_origin := target_position if target_position != Vector2.ZERO else spawn_origin

    for i in n:
        var entry: Dictionary = consumed[i]
        var icon := TextureRect.new()
        icon.texture = _get_dice_face_texture_for(entry.get("type", "blue"), entry.get("value", 1))
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.custom_minimum_size = Vector2(58, 58)
        icon.size = Vector2(58, 58)
        icon.pivot_offset = icon.size / 2.0
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        icon.z_index = 150  # same layer/z convention as the refuel icons above
        parent_layer.add_child(icon)

        var spawn_pos := spawn_origin + Vector2(randf_range(-16.0, 16.0), randf_range(-10.0, 10.0))
        var hover_pos := hover_origin + Vector2(lerpf(-100.0, 100.0, float(i) / maxf(1.0, n - 1)), -30.0)
        icon.global_position = spawn_pos - icon.size / 2.0
        icon.scale = Vector2.ZERO

        var flight := create_tween()
        flight.tween_interval(ALL_IN_CONSUMED_STAGGER * i)

        # 1. Pop out of the card and rise to the hover spot.
        flight.tween_property(icon, "scale", Vector2.ONE, ALL_IN_CONSUMED_RISE) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        flight.parallel().tween_property(icon, "global_position", hover_pos - icon.size / 2.0, ALL_IN_CONSUMED_RISE) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

        # 2. Hover with a gentle bob, noticeably longer than the refuel version so the player
        # has time to actually read "oh, that's my dice" before they vanish.
        flight.tween_property(icon, "global_position:y", hover_pos.y - icon.size.y / 2.0 - ALL_IN_CONSUMED_HOVER_BOB, ALL_IN_CONSUMED_HOVER * 0.5) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        flight.tween_property(icon, "global_position:y", hover_pos.y - icon.size.y / 2.0, ALL_IN_CONSUMED_HOVER * 0.5) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

        # 3. Burn away in place: overbright flash, a small final rise + scale pop, then
        # collapse to nothing - reads as "spent," not "returned."
        var burn_pos := hover_pos + Vector2(0.0, -26.0)
        flight.tween_property(icon, "global_position", burn_pos - icon.size / 2.0, ALL_IN_CONSUMED_BURN) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        flight.parallel().tween_property(icon, "modulate", Color(2.2, 2.0, 1.4, 1.0), ALL_IN_CONSUMED_BURN * 0.35) \
            .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        flight.parallel().tween_property(icon, "scale", Vector2(1.25, 1.25), ALL_IN_CONSUMED_BURN * 0.35) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        flight.tween_property(icon, "scale", Vector2.ZERO, ALL_IN_CONSUMED_BURN * 0.5) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
        flight.parallel().tween_property(icon, "modulate:a", 0.0, ALL_IN_CONSUMED_BURN * 0.5) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        flight.chain().tween_callback(icon.queue_free)


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
    card_drop_area.scale = Vector2(0.857, 0.857)  # after you apply scale
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
    charged_card_description.text = "Place a card here"
    description_panel.modulate.a = 0.6
    bonus_effect.hide()
    bonus_separator.hide()
    cancel_red_card_panel.hide()
    
func _set_socket_filled() -> void:
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
