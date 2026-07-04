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
var mech_adjustment_used := false

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
const POWER_ORB_STAGGER := 0.035         # launch delay between orbs, so they read as a little stream
const POWER_ORB_FLIGHT_MIN := 0.22
const POWER_ORB_FLIGHT_MAX := 0.34
# The die sits left of the Power label at roughly the same height - a straight line between
# them reads as flat/boring. Orbs instead arc UP and over (a rough "rainbow" shape per Julien's
# note - deliberately loose, not a precise math curve), landing on the Power label FROM ABOVE
# rather than approaching it level, which reads as much more impactful.
const POWER_ORB_ARC_HEIGHT_MIN := 60.0
const POWER_ORB_ARC_HEIGHT_MAX := 110.0

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
                load("res://assets/images/blue0.png"),
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

    play_dice_roll_sound()
    Global.fight_dice_rolled+=1
    Global.dice_amount_rolled_this_turn+=1
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

    # Determine the roll result index
    var roll_index = randi() % values.size()
    Events.check_unlucky_status.emit()
    Events.check_lucky_status.emit()

    # Handle guaranteed rolls
    if Global.next_guaranteed_roll != 0:
        var target_value = Global.next_guaranteed_roll
        roll_index = values.find(target_value)

        if roll_index == -1:
            push_error("Guaranteed roll value %s is not in dice values: %s" %
                    [str(target_value), str(values)])
            roll_index = randi() % values.size()

        Global.next_guaranteed_roll = 0
        next_roll_panel.hide()
    
    # Handle tutorial forced rolls
    if Global.tutorial_forced_roll != 0:
        var target_value = Global.tutorial_forced_roll
        roll_index = values.find(target_value)

        if roll_index == -1:
            push_error("Tutorial forced roll value %s is not in dice values: %s" %
                    [str(target_value), str(values)])
            roll_index = randi() % values.size()

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

        # Max-roll celebration: gold flash + particle burst on top of the normal landing
        if is_max_roll:
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


# Matches card_particles.gd's palette (kept in sync by eye - both are small per-dice-type color
# tables, not worth a shared resource for two call sites) but brighter, since these orbs are
# small UI elements that need to pop against the dice panel background rather than a full-scale
# particle burst.
func _get_power_orb_color(type: String) -> Color:
    match type:
        "magma": return Color("ff5522")
        "blue":  return Color("5a8bffff")
        "red":   return Color("ff3322")
        "green": return Color("33ff99")
        "odd":   return Color("ffd60b")
        "even":  return Color("ffaa55")
        "evil":  return Color("dd55dd")
        "giant": return Color("99ff55")
        "mech":  return Color("bbbbbb")
        _:       return Color(1, 1, 1)


# tween_method's first parameter is always the interpolated value (t here) - bound args are
# appended after it, so this stays a named function rather than a multi-statement inline lambda
# (see reference-video-frame-analysis / the combat-juice-pass lessons on that gotcha).
func _orb_bezier_step(t: float, orb: TextureRect, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
    var pos := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
    orb.global_position = pos - orb.size / 2.0


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
    var color := _get_power_orb_color(type) * brightness
    var texture := _get_power_orb_texture()

    var count := clampi(POWER_ORB_MIN_COUNT + roll_val / 2, POWER_ORB_MIN_COUNT, POWER_ORB_MAX_COUNT)
    if is_max_roll:
        count += POWER_ORB_MAX_ROLL_BONUS

    # Big rolls get chunkier orbs on top of the base random size, not just more of them.
    var size_bonus := lerpf(0.0, POWER_ORB_SIZE_BIG_ROLL_BONUS, clampf(float(roll_val) / 12.0, 0.0, 1.0))

    for i in count:
        var orb := TextureRect.new()
        orb.texture = texture
        # Texture is a fixed 32x32 source - without EXPAND_IGNORE_SIZE, TextureRect renders at
        # native resolution regardless of .size below (bit the refuel-return icons the same way).
        orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        orb.modulate = color
        orb.modulate.a = 0.0
        orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        orb.z_index = 60  # above Panel/DiceDisplay, still local to this Dice control
        add_child(orb)

        var size := randf_range(POWER_ORB_SIZE_MIN, POWER_ORB_SIZE_MAX) + size_bonus
        orb.size = Vector2(size, size)
        orb.pivot_offset = orb.size / 2.0

        var start := origin + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
        var end := target + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
        orb.global_position = start - orb.size / 2.0

        # Rough "rainbow" arc: control point sits well ABOVE the midpoint (and biased toward
        # the target's x) so the path rises, sails over, and comes back down into the Power
        # label from above - rather than the old perpendicular-random bow, which averaged out
        # to a flat, straightforward line since it bowed up or down with equal odds.
        var mid_x := lerpf(start.x, end.x, 0.55)
        var apex_y := minf(start.y, end.y) - randf_range(POWER_ORB_ARC_HEIGHT_MIN, POWER_ORB_ARC_HEIGHT_MAX)
        var control := Vector2(mid_x + randf_range(-15.0, 15.0), apex_y)

        var flight_time := randf_range(POWER_ORB_FLIGHT_MIN, POWER_ORB_FLIGHT_MAX)
        var tw := create_tween()
        tw.tween_interval(POWER_ORB_STAGGER * i)
        tw.tween_property(orb, "modulate:a", 1.0, flight_time * 0.3)
        tw.parallel().tween_method(_orb_bezier_step.bind(orb, start, control, end), 0.0, 1.0, flight_time) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        # Shrinks to nothing exactly as it arrives, so it reads as being absorbed into the
        # number rather than just stopping next to it.
        tw.parallel().tween_property(orb, "scale", Vector2(0.2, 0.2), flight_time) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        # The first (unstaggered, i==0) orb is the earliest to land - that's the moment the
        # Power number gets its "delivery" reaction, rather than waiting for the whole
        # staggered swarm on big rolls (so the timing doesn't grow with orb count).
        if i == 0:
            tw.tween_callback(_play_power_orb_arrival_reaction.bind(type))
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

    # Update dice display
    if dice_type in ["evil", "even", "odd", "magma", "green", "mech"]:
        dice_display.texture = faces[roll_index]
    else:
        dice_display.texture = load("res://assets/images/" + dice_type + str(Global.last_roll) + ".png")

    Global.roll_value += Global.last_roll
    Global.power_generated_this_turn += Global.last_roll
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
        var damage_effect := DamageEffect.new() 
        var base_damage = Global.last_roll 
        damage_effect.amount = base_damage 
        var enemies = get_tree().get_nodes_in_group("enemies") 
        damage_effect.execute(enemies)
    
    # High roll sound: celebrate this die's own best possible face (max of its values,
    # not literally 6 - e.g. 12 on Giant, 8 on Even, 3 on Green), same definition of
    # "max roll" used for the landing flourish in roll_dice().
    if Global.last_roll == values.max():
        play_high_roll_sound()

    # Separate gameplay flag (Pinpoint card checks this) - stays tied to a literal 6,
    # not the per-die max, so don't fold it into the check above.
    if Global.last_roll == 6:
        Global.has_rolled_6_this_turn = true

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

    # Tutorial step progression (after roll is complete)
    if Global.tutorial_forced_roll == 6:
        Events.tutorial_step_requested.emit(3)
        Global.tutorial_forced_roll = 0
    elif Global.tutorial_forced_roll == 3:
        Events.tutorial_step_requested.emit(6)
        Global.tutorial_forced_roll = 0
    elif Global.tutorial_forced_roll == 1:
        Events.tutorial_step_requested.emit(14)
        Global.tutorial_forced_roll = 0
    elif Global.tutorial_forced_roll == 2:
        Global.tutorial_forced_roll = 1

    # Emit appropriate events
    if dice_type != "red":
        Events.dice_rolled.emit(Global.dice_type, Global.roll_value)
    else:
        Events.red_dice_rolled.emit()
    _check_sigil_trigger()
    Events.hover_playable_cards.emit()
    mech_adjustment_used = false
    _update_mech_buttons()
    _update_charged_card_description()


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
    flash_tween.tween_property(current_power, "modulate", _get_power_orb_color(type), 0.05)
    flash_tween.tween_property(current_power, "modulate", base_color, 0.15)


func _on_active_dice_changed(new_dice_type):
    SFXPlayer.play(Global.sfx_click)
    dice_type = new_dice_type
    Global.dice_type = new_dice_type  # Make sure to update the global variable
    print("Active dice changed to: " + dice_type)
    if dice_type == "red" and new_dice_type != "red" and socketed_card_ui != null:
        _on_cancel_red_card_pressed()
    Global.next_guaranteed_roll = 0
    next_roll_panel.hide()
    Events.hover_playable_cards.emit()
    update_dice_display()
    
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
    dice_display.texture = load("res://assets/images/" + dice_type + "1.png")
    
    var outline_color: Color
    if dice_type == "blue":
        current_power.modulate = Color(0.35, 0.65, 1.0)  # softer sky blue
        outline_color = Color(0.0, 0.15, 0.45)
    elif dice_type == "red":
        current_power.modulate = Color(1, 0, 0)
        outline_color = Color(0.4, 0.0, 0.0)
    elif dice_type == "evil":
        current_power.modulate = Color(0.8, 0.2, 0.7)
        outline_color = Color(0.3, 0.0, 0.3)
        dice_display.texture = load("res://assets/images/evil6.png")
    elif dice_type == "giant":
        current_power.modulate = Color(0.7, 1.0, 0.3)
        outline_color = Color(0.2, 0.4, 0.0)
    elif dice_type == "magma":
        current_power.modulate = Color(1.0, 0.3, 0.0)
        outline_color = Color(0.4, 0.1, 0.0)
    elif dice_type == "even":
        current_power.modulate = Color(1.0, 0.6, 0.3)
        outline_color = Color(0.4, 0.2, 0.0)
        dice_display.texture = load("res://assets/images/" + dice_type + "2.png")
    elif dice_type == "odd":
        current_power.modulate = Color(0.925, 0.764, 0.043)
        outline_color = Color(0.4, 0.3, 0.0)
        dice_display.texture = load("res://assets/images/" + dice_type + "1.png")
    elif dice_type == "green":
        current_power.modulate = Color(0.0, 0.933, 0.475)
        outline_color = Color(0.0, 0.3, 0.15)
        dice_display.texture = load("res://assets/images/" + dice_type + "1.png")
    elif dice_type == "mech":
        current_power.modulate = Color(0.35, 0.35, 0.35)
        outline_color = Color(0.1, 0.1, 0.1)
        dice_display.texture = load("res://assets/images/" + dice_type + "1.png")
    
    current_power.get_theme_font("font")
    current_power.add_theme_color_override("font_outline_color", outline_color)
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
    mech_adjustment_used = false
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
    mech_adjustment_used = false
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
    _update_charged_card_description()
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

    if Global.tutorial_charging_card:
        Events.tutorial_step_requested.emit(10)
        Global.tutorial_charging_card = false


func _on_reset_charged_card():
    # This same signal fires from inside virtually every card's apply_effects() (a generic
    # cleanup call unrelated to red-dice sockets) AND explicitly right after a socketed card
    # is actually played (card_released_state.gd's Global.playing_red_card branch) - only the
    # latter should animate the socket away; every other case still clears it instantly.
    if _flying_charged_card_to_discard:
        return
    if Global.playing_red_card and is_instance_valid(socketed_card_ui):
        _flying_charged_card_to_discard = true
        _fly_charged_card_to_discard()
        return

    if charged_card_texture.texture != null:
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
        # actually changed, not a flat value - Blaze's +5 should land harder than Reinforce's +1.
        var power_delta := absf(Global.roll_value - old_power)
        Shaker.hit_stop(clampf(power_delta * 0.01, 0.03, 0.1))
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

    aura.material = new_shader_material


func _on_charge_dice_animation():
    animation_player.play("charge")  # existing aura animation
    dice_roll_player.stream = load("res://chargedicesound.mp3")
    dice_roll_player.volume_db = 6
    dice_roll_player.play()
    gpu_particles_2d.emitting = true  # ring of energy spawns and rushes inward (~0.3s to converge)

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

    # Color by dice type
    var color := Color.WHITE
    match Global.dice_type:
        "blue":
            color = Color(0.3, 0.5, 1.0)
        "red":
            color = Color(1.0, 0.3, 0.3)
        "evil":
            color = Color(0.8, 0.2, 0.7)
        "giant":
            color = Color(0.7, 1.0, 0.3)
        "magma":
            color = Color(1.0, 0.3, 0.0)
        "even":
            color = Color(1.0, 0.6, 0.3)
        "odd":
            color = Color(0.925, 0.764, 0.043)
        "green":
            color = Color(0.0, 0.933, 0.475)
        "mech":
            color = Color(0.35, 0.35, 0.35)

    # Lighten toward white so it stays legible on the dark backing pill regardless of
    # dice type (mech's dark grey was nearly invisible against the glow otherwise).
    color = color.lerp(Color.WHITE, 0.35)

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
    if mech_adjustment_used or Global.roll_value == 0:
        return
    mech_adjustment_used = true
    Global.roll_value += 1
    SFXPlayer.play(load("res://sounds/blacksmithsound.wav"))
    Events.change_current_power.emit()
    _mech_increase_tween = _play_mech_arrow_punch(mech_increase, _mech_increase_tween)
    _update_mech_buttons()

func _on_mech_decrease_pressed() -> void:
    if mech_adjustment_used or Global.roll_value == 0:
        return
    mech_adjustment_used = true
    Global.roll_value -= 1
    SFXPlayer.play(load("res://sounds/blacksmithsound.wav"))
    Events.change_current_power.emit()
    _mech_decrease_tween = _play_mech_arrow_punch(mech_decrease, _mech_decrease_tween)
    _update_mech_buttons()

func _update_mech_buttons() -> void:
    var usable = not mech_adjustment_used and Global.roll_value > 0
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
    var color := Color.WHITE
    match Global.dice_type:
        "blue":   color = Color(0.3, 0.5, 1.0)
        "red":    color = Color(1.0, 0.3, 0.3)
        "evil":   color = Color(0.8, 0.2, 0.7)
        "giant":  color = Color(0.7, 1.0, 0.3)
        "magma":  color = Color(1.0, 0.3, 0.0)
        "even":   color = Color(1.0, 0.6, 0.3)
        "odd":    color = Color(0.925, 0.764, 0.043)
        "green":  color = Color(0.0, 0.933, 0.475)
        "mech":   color = Color(0.35, 0.35, 0.35)
    
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
# every dice type uses "<type><value>.png" EXCEPT evil's 0 face, which is "blue0.png" (see
# evil_faces above). Mirrors the same lookup _apply_roll_result() uses, just keyed by value
# instead of by roll_index into a faces array, since roll_history only stores values.
func _get_dice_face_texture(value: int) -> Texture2D:
    if dice_type == "evil" and value == 0:
        return load("res://assets/images/blue0.png")
    return load("res://assets/images/" + dice_type + str(value) + ".png")


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
        _set_socket_empty()
        socketed_card_ui = null
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
