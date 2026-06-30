class_name Dice
extends Control

@onready var dice_display: TextureRect = $Panel/DiceDisplay

@onready var current_power: Label = $CurrentPower
@onready var power_glow: TextureRect = $PowerGlow
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
    _init_power_glow()
    _update_power_float()

# The glow used to idle-pulse continuously, but that ambient motion turned out to be too
# subtle to register (same lesson as the dice hit-stop). It's now event-driven instead:
# resting state here, flared on every roll in _apply_roll_result().
func _init_power_glow() -> void:
    power_glow.pivot_offset = power_glow.size / 2.0
    power_glow.scale = Vector2.ONE
    power_glow.modulate.a = 0.0

# Single chokepoint for the Power number's text, so the font size can shrink as the number
# grows. An 80px glyph looks great at 1 digit but too big at 2+ (and the magnitude
# rest-scale compounds it). Keeps single digits punchy while taming "14"-style values.
func _set_power_text(value) -> void:
    var s := str(value)
    current_power.text = s
    var fs := 80
    if s.length() >= 3:
        fs = 48
    elif s.length() == 2:
        fs = 60
    if current_power.label_settings:
        current_power.label_settings.font_size = fs

# The power label's idle float (power_float.gdshader) should only play while there's
# actually power banked - at 0 it should sit dead still, not "emanate" nothing.
func _update_power_float() -> void:
    if current_power.material:
        current_power.material.set_shader_parameter("float_intensity", 0.0 if Global.roll_value == 0 else 1.0)

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

        var punch_scale = 1.08 + (roll_val / 60.0)  # 1.09 on 1, 1.28 on 12
        if is_max_roll:
            punch_scale += 0.10
        punch_scale = clampf(punch_scale, 1.08, 1.5)
        var impact = create_tween()
        impact.tween_property(dice_display, "scale", Vector2(punch_scale, punch_scale), 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        impact.tween_property(dice_display, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

        # Subtle pulse on the per-dice-type aura behind the die, on every landing (not just
        # max rolls) - reuses the existing aura node/shader instead of new art, scaled by
        # roll value so a bigger roll gives a slightly bigger pulse.
        var aura_punch = 1.05 + (roll_val / 100.0)
        var aura_pulse := create_tween()
        aura_pulse.tween_property(aura, "scale", Vector2(aura_punch, aura_punch), 0.07) \
            .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        aura_pulse.tween_property(aura, "scale", Vector2(1.0, 1.0), 0.16) \
            .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

        # Landing impact: brief hit-stop so every roll lands with weight, bigger on a max-value roll
        var hit_stop_duration = clampf(roll_val * 0.006, 0.02, 0.07)
        if is_max_roll:
            hit_stop_duration = 0.09
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

    # Power glow flare: punch the glow brighter/bigger on every roll, fade back out to nothing
    # (no resting glow - Julien found a constant glow too much, only the on-roll punch reads well)
    var glow_punch = 1.25 + (Global.last_roll / 20.0)  # mirrors power_punch scaling
    var glow_flare := create_tween()
    glow_flare.tween_property(power_glow, "scale", Vector2(glow_punch, glow_punch), 0.07) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    glow_flare.parallel().tween_property(power_glow, "modulate:a", 1.0, 0.07) \
        .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    glow_flare.tween_property(power_glow, "scale", Vector2(1.0, 1.0), 0.35) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    glow_flare.parallel().tween_property(power_glow, "modulate:a", 0.0, 0.35) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
    Events.check_blessed_status.emit()

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
    power_glow.modulate = Color(current_power.modulate.r, current_power.modulate.g, current_power.modulate.b, 0.0)
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
        update_roll_history_ui()
    else:
        _set_power_text("0")
        Global.roll_value = 0
        current_power.modulate.a = 0.4
        current_power.scale = Vector2.ONE
        Global.roll_history = []
        _update_power_float()
        update_roll_history_ui()
    mech_adjustment_used = false
    _update_mech_buttons()
    Events.hover_playable_cards.emit()


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

    if charged_card_texture.texture != null:
        _set_socket_empty()
   

func _on_change_current_power():

    _set_power_text(Global.roll_value)
    animation_player_power.play("power_change")
    _check_sigil_trigger()
    Events.hover_playable_cards.emit()


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
    _update_mech_buttons()

func _on_mech_decrease_pressed() -> void:
    if mech_adjustment_used or Global.roll_value == 0:
        return
    mech_adjustment_used = true
    Global.roll_value -= 1
    SFXPlayer.play(load("res://sounds/blacksmithsound.wav"))
    Events.change_current_power.emit()
    _update_mech_buttons()

func _update_mech_buttons() -> void:
    var usable = not mech_adjustment_used and Global.roll_value > 0
    mech_section.modulate.a = 1.0 if usable else 0.3

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

func _on_refuel_happened(amount: int) -> void:
    var start_value := Global.roll_value  # capture before reset happens

    # --- Power drain animation --- (sped up: was 0.03/tick, could outlast a quick reroll)
    var steps := mini(start_value, 6)
    var step_size: float = float(start_value) / float(maxi(steps, 1))
    var step_duration := 0.018  # seconds per tick

    for i in range(steps):
        await get_tree().create_timer(step_duration * i).timeout
        var display_val := int(start_value - step_size * (i + 1))
        _set_power_text(maxi(display_val, 0))

    await get_tree().create_timer(step_duration * steps).timeout

    # Only force the power display back to "0" if no fresh roll happened during the drain.
    # Recombobulate's own reset leaves roll_value at 0 (normal case), but a roll landing
    # mid-drain sets roll_value > 0 and already updated the text - stomping "0" would blank
    # it. The dice recharge flash below plays either way (it's the "dice are back" feedback).
    if Global.roll_value <= 0:
        _set_power_text("0")
        current_power.modulate.a = 0.4
        if current_power.material:
            current_power.material.set_shader_parameter("float_intensity", 0.0)

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
