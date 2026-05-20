class_name Dice
extends Control

@onready var dice_display: TextureRect = $Panel/DiceDisplay

@onready var current_power: Label = $CurrentPower
@export var dice_type: String = "blue"
@onready var card_drop_area: Control = $CardDropArea
@onready var charged_card_texture: TextureRect = $CardDropArea/CardBackground/CardFrame/Panel/ChargedCardTexture
@onready var charged_card_description: Label = $CardDropArea/CardBackground/CardFrame/DescriptionPanel/ChargedCardDescription
@onready var requirement_panel: Panel = $CardDropArea/CardBackground/CardFrame/RequirementPanel
@onready var requirement_label: RichTextLabel = $CardDropArea/CardBackground/CardFrame/RequirementPanel/RequirementLabel
@onready var bonus_effect: HBoxContainer = $CardDropArea/CardBackground/CardFrame/BonusEffect
@onready var bonus_requirement_panel: Panel = $CardDropArea/CardBackground/CardFrame/BonusEffect/BonusRequirementPanel
@onready var bonus_requirement_label: RichTextLabel = $CardDropArea/CardBackground/CardFrame/BonusEffect/BonusRequirementPanel/BonusRequirementLabel
@onready var bonus_effect_label: Label = $CardDropArea/CardBackground/CardFrame/BonusEffect/BonusEffectLabel
@onready var mech_section: Control = $MechSection


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


    
    # Initialize the dice display with the correct texture based on dice_type
    update_dice_display()
    
    # Make sure Global.dice_type is synchronized
    Global.dice_type = dice_type

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
    var shake_intensity = randf_range(5.0, 25.0)
    var shake_speed = randf_range(0.05, 0.12)
    var face_change_frequency = randi_range(8, 16)
    var anticipation_delay = randf_range(0.05, 0.4)

    # Dice shake animation
    for i in range(4):
        tween.tween_property(dice_display, "position", start_position + Vector2(shake_intensity * (-1 if i % 2 == 0 else 1), 0), shake_speed)
    tween.tween_property(dice_display, "position", start_position, 0.05)

    # Rapid face changes
    for i in range(face_change_frequency):
        tween.tween_callback(func():
            var anim_index = randi() % faces.size()
            dice_display.texture = faces[anim_index]
            Global.last_roll = values[anim_index]
            current_power.text = str(Global.last_roll + Global.roll_value)
        )
        tween.tween_interval(shake_speed)

    # Anticipation delay
    tween.tween_interval(anticipation_delay)

    # Final roll callback
    tween.tween_callback(func():
        _apply_roll_result(roll_index, values, faces)
    )


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
    current_power.text = str(Global.roll_value)
    var power_tween = create_tween()
    power_tween.tween_property(current_power, "scale", Vector2(1.4, 1.4), 0.07)
    power_tween.tween_property(current_power, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    
    # Magma dice special effect
    if dice_type == "magma": 
        print("magma dice on")
        var damage_effect := DamageEffect.new() 
        var base_damage = Global.last_roll 
        damage_effect.amount = base_damage 
        var enemies = get_tree().get_nodes_in_group("enemies") 
        damage_effect.execute(enemies)
    
    # High roll sound
    if Global.last_roll == 6:
        play_high_roll_sound()
        Global.has_rolled_6_this_turn = true

    # Status checks
    Events.check_canalize_status.emit()
    Events.check_blessed_status.emit()

    Events.weak_effect_consumed.emit()
    Events.check_chaos_status.emit()
    
    # Apply roll modifiers
    current_power.text = str(Global.roll_value + Global.next_roll_modifier)
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

    current_power.text = str(Global.roll_value)

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
    current_power.text = "0"
    Events.change_current_power.emit()

func update_dice_display():
    # Update the dice display with the first face of the current dice type
    dice_display.texture = load("res://assets/images/" + dice_type + "1.png")
    
    
    # Update power label color based on dice type
    if dice_type == "blue":
        current_power.modulate = Color(0, 0, 1)  # Blue color
    elif dice_type == "red":
        current_power.modulate = Color(1, 0, 0)  # Red color
    elif dice_type == "evil":
        current_power.modulate = Color(0.8, 0.2, 0.7)  # Vibrant pink-purple
        dice_display.texture = load("res://assets/images/evil6.png")
    elif dice_type == "giant":
        current_power.modulate = Color(0.7, 1.0, 0.3)  # green ")
    elif dice_type == "magma":
        current_power.modulate = Color(1.0, 0.3, 0.0) #magma
    elif dice_type == "even":
        current_power.modulate = Color(1.0, 0.6, 0.3) 
        dice_display.texture = load("res://assets/images/" + dice_type + "2.png")
    elif dice_type == "odd":
        current_power.modulate = Color(0.925, 0.764, 0.043) 
        dice_display.texture = load("res://assets/images/" + dice_type + "1.png")
    elif dice_type == "green":
        current_power.modulate = Color(0.0, 0.933, 0.475)
        dice_display.texture = load("res://assets/images/" + dice_type + "1.png")
    elif dice_type == "mech":
        current_power.modulate = Color(0.0, 0.933, 0.475)
        dice_display.texture = load("res://assets/images/" + dice_type + "1.png")
    set_shader_from_global_type()

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
    current_power.text = str(Global.roll_value)
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
        current_power.text = "0"
        Global.roll_value = 0
        Global.playing_red_card = false
        Global.roll_history = []
    else: 
        current_power.text = "0"
        Global.roll_value = 0
        Global.roll_history = []
    Events.check_ink_status.emit()
    mech_adjustment_used = false
    _update_mech_buttons()


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
    socketed_card_ui = card_ui
    charged_card_texture.texture = card_ui.card.icon
    charged_card_description.text = card_ui.card.description
    title.text = card_ui.card.name
    cancel_red_card_panel.show()
    
    if card_ui.card.requirement == Card.Requirement.NONE:
        requirement_panel.hide()
    else:
        requirement_panel.show()
        if card_ui.card.requirement == Card.Requirement.MAX:
            requirement_panel.add_theme_stylebox_override("panel", CardUI.MAX_STYLEBOX)
            requirement_label.text = "[center]Max %d[/center]" % card_ui.card.requirement_number
        elif card_ui.card.requirement == Card.Requirement.EVEN:
            requirement_panel.add_theme_stylebox_override("panel", CardUI.EVEN_STYLEBOX)
            requirement_label.text = "[center]Even[/center]"
        elif card_ui.card.requirement == Card.Requirement.ODD:
            requirement_panel.add_theme_stylebox_override("panel", CardUI.ODD_STYLEBOX)
            requirement_label.text = "[center]Odd[/center]"
        elif card_ui.card.requirement == Card.Requirement.RED:
            requirement_panel.add_theme_stylebox_override("panel", CardUI.RED_STYLEBOX)
            requirement_label.text = "[center]Red[/center]"
        elif card_ui.card.requirement == Card.Requirement.EXACT:
            requirement_panel.add_theme_stylebox_override("panel", CardUI.EXACT_STYLEBOX)
            requirement_label.text = "[center]Exact %d[/center]" % card_ui.card.requirement_number
        elif card_ui.card.requirement == Card.Requirement.MIN:
            requirement_panel.add_theme_stylebox_override("panel", CardUI.MIN_STYLEBOX)
            requirement_label.text = "[center]Min %d[/center]" % card_ui.card.requirement_number
        elif card_ui.card.requirement == Card.Requirement.MULTIPLE:
            requirement_panel.add_theme_stylebox_override("panel", CardUI.MULTIPLE_STYLEBOX)
            requirement_label.text = "[center]Mult %d[/center]" % card_ui.card.requirement_number
    if card_ui.card.bonus_requirement == Card.Requirement.NONE:
        bonus_effect.hide()
    else:
        bonus_effect.show()
        bonus_effect_label.text = str(card_ui.card.bonus_description_text)
        
        if card_ui.card.bonus_requirement == Card.Requirement.MAX:
            bonus_requirement_panel.add_theme_stylebox_override("panel", CardUI.MAX_STYLEBOX)
            bonus_requirement_label.text = "[center]Max %d[/center]" % card_ui.card.bonus_requirement_number
        elif card_ui.card.bonus_requirement == Card.Requirement.EVEN:
            bonus_requirement_panel.add_theme_stylebox_override("panel", CardUI.EVEN_STYLEBOX)
            bonus_requirement_label.text = "[center]Even[/center]"
        elif card_ui.card.bonus_requirement == Card.Requirement.ODD:
            bonus_requirement_panel.add_theme_stylebox_override("panel", CardUI.ODD_STYLEBOX)
            bonus_requirement_label.text = "[center]Odd[/center]"
        elif card_ui.card.bonus_requirement == Card.Requirement.RED:
            bonus_requirement_panel.add_theme_stylebox_override("panel", CardUI.RED_STYLEBOX)
            bonus_requirement_label.text = "[center]Red[/center]"
        elif card_ui.card.bonus_requirement == Card.Requirement.EXACT:
            bonus_requirement_panel.add_theme_stylebox_override("panel", CardUI.EXACT_STYLEBOX)
            bonus_requirement_label.text = "[center]Exact %d[/center]" % card_ui.card.bonus_requirement_number
        elif card_ui.card.bonus_requirement == Card.Requirement.MIN:
            bonus_requirement_panel.add_theme_stylebox_override("panel", CardUI.MIN_STYLEBOX)
            bonus_requirement_label.text = "[center]Min %d[/center]" % card_ui.card.bonus_requirement_number
        elif card_ui.card.bonus_requirement == Card.Requirement.MULTIPLE:
            bonus_requirement_panel.add_theme_stylebox_override("panel", CardUI.MULTIPLE_STYLEBOX)
            bonus_requirement_label.text = "[center]Mult %d[/center]" % card_ui.card.bonus_requirement_number
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
        print("reset charged card")
        charged_card_texture.texture = null
        charged_card_description.text = "Place a card here"
        title.text = "Card"
        requirement_panel.hide()
        bonus_effect.hide()
   

func _on_change_current_power():
    
    current_power.text = str(Global.roll_value)
    animation_player_power.play("power_change")
    _check_sigil_trigger()


func _on_next_roll_determined():
    next_roll_panel.show()
    var path := "res://assets/images/%s%d.png" % [Global.dice_type, Global.next_guaranteed_roll]
    next_roll_texture.texture = load(path)
    print(path)
    
func _on_battle_started():
    Global.fight_dice_rolled = 0
    Global.blue_dice_bonus_amount_fight = 0
    set_shader_from_global_type()

func set_shader_from_global_type() -> void:
    var new_shader_material : ShaderMaterial

    match Global.dice_type:
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
            new_shader_material = preload("res://scenes/dices/green_dice_shader.tres")
        _:
            push_warning("Unknown dice type: %s" % Global.dice_type)
            return

    aura.material = new_shader_material


func _on_charge_dice_animation():
    animation_player.play("charge")  # Play the 'charge' animation  
    dice_roll_player.stream = load("res://chargedicesound.mp3")
    dice_roll_player.volume_db = 6  # Increase volume (optional)
    dice_roll_player.play()   
    gpu_particles_2d.emitting = true
    
func _on_put_ink_on_dice():
    if not ink_is_on:
        ink_animation.play("ink_spray")
    dice_roll_player.stream = load("res://splatsound.mp3")
    dice_roll_player.play()   
    ink_is_on = true
    
func _on_remove_ink_from_dice():
    if ink_is_on: 
        ink_animation.play("ink_fade")
    ink_is_on = false
    
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
    charged_card_texture.texture = null
    charged_card_description.text = "Place a card here"
    title.text = "Card"
    requirement_panel.hide()
    bonus_effect.hide()
    cancel_red_card_panel.hide()
    
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

    # Apply with RichText formatting
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
