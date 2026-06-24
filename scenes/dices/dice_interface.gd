class_name DiceInterface
extends Control

signal active_dice_changed(active_dice)

const TooltipScene = preload("res://scenes/ui/dice_tooltip.tscn")
const DICE_TYPE_TO_NODE = {
    "blue": "dice_1", "red": "dice_2", "evil": "dice_3",
    "giant": "dice_4", "magma": "dice_5", "even": "dice_6",
    "odd": "dice_7", "green": "dice_8", "mech": "dice_9"
}

@onready var control: DiceInterface = $"."
@onready var dice_1: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice1
@onready var dice_2: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice2
@onready var dice_1_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice1/Dice1Label
@onready var dice_2_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice2/Dice2Label
@onready var dice_3: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice3
@onready var dice_3_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice3/Dice3Texture
@onready var dice_3_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice3/Dice3Label
@onready var h_box_container: HBoxContainer = $DicePanel/MarginContainer/HBoxContainer
@onready var dice_1_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice1/Dice1Texture
@onready var dice_2_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice2/Dice2Texture
@onready var dice_4_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice4/Dice4Texture
@onready var dice_5_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice5/Dice5Texture
@onready var dice_4: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice4
@onready var dice_5: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice5
@onready var dice_4_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice4/Dice4Label
@onready var dice_panel: Panel = $DicePanel
@onready var dice_5_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice5/Dice5Label
@onready var dice_6: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice6
@onready var dice_6_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice6/Dice6Texture
@onready var dice_6_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice6/Dice6Label
@onready var dice_7: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice7
@onready var dice_7_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice7/Dice7Texture
@onready var dice_7_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice7/Dice7Label
@onready var animation_player: AnimationPlayer = $DicePanel/AnimationPlayer
@onready var dice_8: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice8
@onready var dice_8_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice8/Dice8Texture
@onready var dice_8_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice8/Dice8Label
@onready var dice_9: VBoxContainer = $DicePanel/MarginContainer/HBoxContainer/Dice9
@onready var dice_9_texture: TextureRect = $DicePanel/MarginContainer/HBoxContainer/Dice9/Dice9Texture
@onready var dice_9_label: Label = $DicePanel/MarginContainer/HBoxContainer/Dice9/Dice9Label


var tooltip_instance: Panel



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    dice_1_label.text = str(Global.blue_dice_current_amount, "/", Global.blue_dice_max_amount)
    dice_2_label.text = str(Global.red_dice_current_amount, "/", Global.red_dice_max_amount)
    dice_3_label.text = str(Global.evil_dice_current_amount, "/", Global.evil_dice_max_amount)
    dice_4_label.text = str(Global.giant_dice_current_amount, "/", Global.giant_dice_max_amount)
    dice_5_label.text = str(Global.magma_dice_current_amount, "/", Global.magma_dice_max_amount)
    dice_6_label.text = str(Global.even_dice_current_amount, "/", Global.even_dice_max_amount)
    dice_7_label.text = str(Global.odd_dice_current_amount, "/", Global.odd_dice_max_amount)
    dice_8_label.text = str(Global.green_dice_current_amount, "/", Global.green_dice_max_amount)
    dice_9_label.text = str(Global.mech_dice_current_amount, "/", Global.mech_dice_max_amount)
    # Connect event listener for dice rolls
    Events.dice_rolled.connect(_on_dice_rolled)
    Events.dice_amount_changed.connect(_on_dice_amount_changed)
    Events.player_turn_started.connect(_on_player_turn_started)
    Events.dice_bought.connect(_on_dice_bought)
    Events.resize_dice_interface.connect(_on_resize_dice_interface)
    Events.charge_dice_animation.connect(_on_charge_dice_animation)
    initialize_dices()
    var different_dices_amount = Global.dice_inventory.size()
    dice_panel.custom_minimum_size.x = (different_dices_amount * 65) + 20
    Events.temporary_dice_added.connect(_on_temporary_dice_added)
    Events.active_dice_changed.connect(update_selected_highlight)
    await get_tree().process_frame
    update_selected_highlight(Global.dice_type)




# Called when a dice is rolled
func _on_dice_rolled(dice_type: String, roll_value: int):
    if Global.dice_type == "blue":  # Reduce only if it's the blue die
        if Global.blue_dice_current_amount > 0:  
            Global.blue_dice_current_amount -= 1
            dice_1_label.text = str(Global.blue_dice_current_amount, "/", Global.blue_dice_max_amount)
    elif Global.dice_type == "red":  # Reduce only if it's the blue die
        if Global.red_dice_current_amount > 0:  
            Global.red_dice_current_amount -= 1
            dice_2_label.text = str(Global.red_dice_current_amount, "/", Global.red_dice_max_amount)
    elif Global.dice_type == "evil":  # Reduce only if it's the blue die
        if Global.evil_dice_current_amount > 0:  
            Global.evil_dice_current_amount -= 1
            dice_3_label.text = str(Global.evil_dice_current_amount, "/", Global.evil_dice_max_amount)
    elif Global.dice_type == "giant":  # Reduce only if it's the blue die
        if Global.giant_dice_current_amount > 0:  
            Global.giant_dice_current_amount -= 1
            dice_4_label.text = str(Global.giant_dice_current_amount, "/", Global.giant_dice_max_amount)
    elif Global.dice_type == "magma":  # Reduce only if it's the blue die
        if Global.magma_dice_current_amount > 0:  
            Global.magma_dice_current_amount -= 1
            dice_5_label.text = str(Global.magma_dice_current_amount, "/", Global.magma_dice_max_amount)
    elif Global.dice_type == "even":  # Reduce only if it's the blue die
        if Global.even_dice_current_amount > 0:  
            Global.even_dice_current_amount -= 1
            dice_6_label.text = str(Global.even_dice_current_amount, "/", Global.even_dice_max_amount)
    elif Global.dice_type == "odd":  # Reduce only if it's the blue die
        if Global.odd_dice_current_amount > 0:  
            Global.odd_dice_current_amount -= 1
            dice_7_label.text = str(Global.odd_dice_current_amount, "/", Global.odd_dice_max_amount)
    elif Global.dice_type == "green":  # Reduce only if it's the blue die
        if Global.green_dice_current_amount > 0:  
            Global.green_dice_current_amount -= 1
            dice_8_label.text = str(Global.green_dice_current_amount, "/", Global.green_dice_max_amount)
    elif Global.dice_type == "mech":  # Reduce only if it's the blue die
        if Global.mech_dice_current_amount > 0:  
            Global.mech_dice_current_amount -= 1
            dice_9_label.text = str(Global.mech_dice_current_amount, "/", Global.mech_dice_max_amount)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


func _on_dice_1_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0 && Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Events.active_dice_changed.emit("blue")
        if Global.tutorial_blue_dice: 
            Events.tutorial_step_requested.emit(13)
            Global.tutorial_blue_dice = false
        Events.update_roll_history_ui.emit()
        


func _on_dice_2_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Events.active_dice_changed.emit("red")
        Global.dice_type = "red"
        Events.reset_charged_card.emit()
        if Global.tutorial_red_dice: 
            Events.tutorial_step_requested.emit(9)
            Global.tutorial_red_dice = false
        Events.update_roll_history_ui.emit()
        
func _on_dice_3_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Events.active_dice_changed.emit("evil")
        Global.dice_type = "evil"
        Events.update_roll_history_ui.emit()
        
func _on_dice_4_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Events.active_dice_changed.emit("giant")
        Global.dice_type = "giant"
        Events.update_roll_history_ui.emit()
        
func _on_dice_5_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Events.active_dice_changed.emit("magma")
        Global.dice_type = "magma"
        Events.update_roll_history_ui.emit()      
        
func _on_dice_6_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Events.active_dice_changed.emit("even")
        Global.dice_type = "even"
        Events.update_roll_history_ui.emit()
        
func _on_dice_7_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Events.active_dice_changed.emit("odd")
        Global.dice_type = "odd"
        Events.update_roll_history_ui.emit()  
        
func _on_dice_8_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Events.active_dice_changed.emit("green")
        Global.dice_type = "green"
        Events.update_roll_history_ui.emit()

func _on_dice_9_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if Global.tutorial_reset_power_warning && Global.roll_value>0&& Global.dice_type != "red":
            #show warning message
            Events.show_warning_message.emit()
            Global.tutorial_reset_power_warning = false 
            return
        Events.active_dice_changed.emit("mech")
        Global.dice_type = "mech"
        Events.update_roll_history_ui.emit()

        
        
        
        
func _on_player_turn_started() -> void:
    Global.blue_dice_current_amount = Global.blue_dice_max_amount + Global.blue_dice_bonus_amount + Global.blue_dice_bonus_amount_fight
    Global.red_dice_current_amount = Global.red_dice_max_amount + Global.red_dice_bonus_amount
    Global.evil_dice_current_amount = Global.evil_dice_max_amount + Global.evil_dice_bonus_amount
    Global.green_dice_current_amount = Global.green_dice_max_amount + Global.green_dice_bonus_amount
    Global.giant_dice_current_amount = Global.giant_dice_max_amount + Global.giant_dice_bonus_amount
    Global.magma_dice_current_amount = Global.magma_dice_max_amount + Global.magma_dice_bonus_amount
    Global.even_dice_current_amount = Global.even_dice_max_amount + Global.even_dice_bonus_amount
    Global.odd_dice_current_amount = Global.odd_dice_max_amount + Global.odd_dice_bonus_amount
    Global.mech_dice_current_amount = Global.mech_dice_max_amount + Global.mech_dice_bonus_amount + Global.mech_dice_bonus_amount_fight

    dice_1_label.text = str(Global.blue_dice_current_amount, "/", Global.blue_dice_max_amount)
    dice_2_label.text = str(Global.red_dice_current_amount, "/", Global.red_dice_max_amount)
    dice_3_label.text = str(Global.evil_dice_current_amount, "/", Global.evil_dice_max_amount)
    dice_4_label.text = str(Global.giant_dice_current_amount, "/", Global.giant_dice_max_amount)
    dice_5_label.text = str(Global.magma_dice_current_amount, "/", Global.magma_dice_max_amount)
    dice_6_label.text = str(Global.even_dice_current_amount, "/", Global.even_dice_max_amount)
    dice_7_label.text = str(Global.odd_dice_current_amount, "/", Global.odd_dice_max_amount)
    dice_8_label.text = str(Global.green_dice_current_amount, "/", Global.green_dice_max_amount)
    dice_9_label.text = str(Global.mech_dice_current_amount, "/", Global.mech_dice_max_amount)

    Global.roll_history = []
    Events.update_roll_history_ui.emit()

    Global.blue_dice_bonus_amount = 0
    Global.red_dice_bonus_amount = 0
    Global.evil_dice_bonus_amount = 0
    Global.green_dice_bonus_amount = 0
    Global.giant_dice_bonus_amount = 0
    Global.magma_dice_bonus_amount = 0
    Global.even_dice_bonus_amount = 0
    Global.odd_dice_bonus_amount = 0
    Global.mech_dice_bonus_amount = 0
    Global.charged_dice_this_turn = false
    initialize_dices()
   
func _on_dice_amount_changed():
    dice_1_label.text = str(Global.blue_dice_current_amount, "/", Global.blue_dice_max_amount)
    dice_2_label.text = str(Global.red_dice_current_amount, "/", Global.red_dice_max_amount)
    dice_3_label.text = str(Global.evil_dice_current_amount, "/", Global.evil_dice_max_amount)
    dice_4_label.text = str(Global.giant_dice_current_amount, "/", Global.giant_dice_max_amount)
    dice_5_label.text = str(Global.magma_dice_current_amount, "/", Global.magma_dice_max_amount)
    dice_6_label.text = str(Global.even_dice_current_amount, "/", Global.even_dice_max_amount)
    dice_7_label.text = str(Global.odd_dice_current_amount, "/", Global.odd_dice_max_amount)
    dice_8_label.text = str(Global.green_dice_current_amount, "/", Global.green_dice_max_amount)
    dice_9_label.text = str(Global.mech_dice_current_amount, "/", Global.mech_dice_max_amount)

func initialize_dices():
    if Global.evil_dice_max_amount > 0 or Global.evil_dice_current_amount > 0 or Global.evil_dice_bonus_amount > 0:
        print("evil dice appearing")
        dice_3_texture.texture = load("res://assets/images/evil6.png")
        dice_3_label.text = str(Global.evil_dice_current_amount, "/", Global.evil_dice_max_amount)
        dice_3.show()
    else:
        dice_3.hide()

    if Global.giant_dice_max_amount > 0 or Global.giant_dice_current_amount > 0 or Global.giant_dice_bonus_amount > 0:
        print("giant dice appearing")
        dice_4_texture.texture = load("res://assets/images/giant12.png")
        dice_4_label.text = str(Global.giant_dice_current_amount, "/", Global.giant_dice_max_amount)
        dice_4.show()
    else:
        dice_4.hide()

    if Global.magma_dice_max_amount > 0 or Global.magma_dice_current_amount > 0 or Global.magma_dice_bonus_amount > 0:
        print("magma dice appearing")
        dice_5_texture.texture = load("res://assets/images/magma6.png")
        dice_5_label.text = str(Global.magma_dice_current_amount, "/", Global.magma_dice_max_amount)
        dice_5.show()
    else:
        dice_5.hide()

    if Global.even_dice_max_amount > 0 or Global.even_dice_current_amount > 0 or Global.even_dice_bonus_amount > 0:
        print("even dice appearing")
        dice_6_texture.texture = load("res://assets/images/even8.png")
        dice_6_label.text = str(Global.even_dice_current_amount, "/", Global.even_dice_max_amount)
        dice_6.show()
    else:
        dice_6.hide()

    if Global.odd_dice_max_amount > 0 or Global.odd_dice_current_amount > 0 or Global.odd_dice_bonus_amount > 0:
        print("odd dice appearing")
        dice_7_texture.texture = load("res://assets/images/odd7.png")
        dice_7_label.text = str(Global.odd_dice_current_amount, "/", Global.odd_dice_max_amount)
        dice_7.show()
    else:
        dice_7.hide()

    if Global.green_dice_max_amount > 0 or Global.green_dice_current_amount > 0 or Global.green_dice_bonus_amount > 0:
        print("green dice appearing")
        dice_8_texture.texture = load("res://assets/images/green1.png")
        dice_8_label.text = str(Global.green_dice_current_amount, "/", Global.green_dice_max_amount)
        dice_8.show()
    else:
        dice_8.hide()
    
    if Global.mech_dice_max_amount > 0 or Global.mech_dice_current_amount > 0 or Global.mech_dice_bonus_amount > 0 or Global.mech_dice_bonus_amount_fight > 0:
        print("mech dice appearing")
        dice_9_texture.texture = load("res://assets/images/mech1.png")
        dice_9_label.text = str(Global.mech_dice_current_amount, "/", Global.mech_dice_max_amount)
        dice_9.show()
    else:
        dice_9.hide()
        
func add_dice_slot(dice_type: String) -> int:
    var textures = [dice_1_texture, dice_2_texture, dice_3_texture, dice_4_texture, dice_5_texture, dice_6_texture, dice_7_texture,dice_8_texture]
    
    for i in textures.size():
        if textures[i].texture == null:
            print("Available slot:", i)
            textures[i].texture = load("res://assets/images/evil6.png")
            var dice_node = get_node("DicePanel/MarginContainer/HBoxContainer/Dice" + str(i+1))
            dice_node.show()
            return i  # First available slot
    print("No available dice slots!")
    return -1  # No available slots

func _on_dice_bought(dice_type):
    print("bought ", dice_type)
    SFXPlayer.play(Global.sfx_click)
    add_dice_slot(dice_type)

func _on_resize_dice_interface():
    var different_dices_amount = Global.dice_inventory.size()
    dice_panel.width = 1200

func _on_charge_dice_animation():
    animation_player.play("charge")  # Play the 'charge' animation  
    initialize_dices()

func _on_temporary_dice_added(dice_type: String):
    print("adding dice")
    initialize_dices()  # Refresh the interface

func _show_tooltip(dice_node: VBoxContainer, dice_type: String) -> void:
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null
    tooltip_instance = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip_instance)
    tooltip_instance.get_tooltip_content(dice_type)
    tooltip_instance.show_tooltip(Vector2(498, 148))  # adjust to taste

func _hide_tooltip() -> void:
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null
        
        

func _on_dice_1_mouse_entered() -> void:
    _show_tooltip(dice_1, "blue")
func _on_dice_1_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_2_mouse_entered() -> void:
    _show_tooltip(dice_2, "red")
func _on_dice_2_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_3_mouse_entered() -> void:
    _show_tooltip(dice_3, "evil")
func _on_dice_3_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_4_mouse_entered() -> void:
    _show_tooltip(dice_4, "giant")
func _on_dice_4_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_5_mouse_entered() -> void:
    _show_tooltip(dice_5, "magma")
func _on_dice_5_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_6_mouse_entered() -> void:
    _show_tooltip(dice_6, "even")
func _on_dice_6_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_7_mouse_entered() -> void:
    _show_tooltip(dice_7, "odd")
func _on_dice_7_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_8_mouse_entered() -> void:
    _show_tooltip(dice_8, "green")
func _on_dice_8_mouse_exited() -> void:
    _hide_tooltip()

func _on_dice_9_mouse_entered() -> void:
    _show_tooltip(dice_9, "mech")
func _on_dice_9_mouse_exited() -> void:
    _hide_tooltip()


func update_selected_highlight(selected_type: String) -> void:
    for dice_type in DICE_TYPE_TO_NODE:
        var node = get(DICE_TYPE_TO_NODE[dice_type])
        if dice_type == selected_type:
            node.modulate = Color(1.3, 1.3, 1.3, 1.0)
            node.scale = Vector2(1.1, 1.1)
        else:
            node.modulate = Color(0.6, 0.6, 0.6, 1.0)
            node.scale = Vector2(1.0, 1.0)
