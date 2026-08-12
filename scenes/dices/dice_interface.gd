class_name DiceInterface
extends Control

signal active_dice_changed(active_dice)

const TooltipScene = preload("res://scenes/ui/dice_tooltip.tscn")
const DICE_TYPE_TO_NODE = {
    "blue": "dice_1", "red": "dice_2", "evil": "dice_3",
    "giant": "dice_4", "magma": "dice_5", "even": "dice_6",
    "odd": "dice_7", "green": "dice_8", "mech": "dice_9"
}
const DICE_TYPE_TO_AMOUNT = {
    "blue": "blue_dice_current_amount", "red": "red_dice_current_amount", "evil": "evil_dice_current_amount",
    "giant": "giant_dice_current_amount", "magma": "magma_dice_current_amount", "even": "even_dice_current_amount",
    "odd": "odd_dice_current_amount", "green": "green_dice_current_amount", "mech": "mech_dice_current_amount"
}
# Selected-slot highlight color comes from DicePalette (same source as the rolled die /
# Power number color elsewhere in the HUD).

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


var tooltip_instance: CanvasLayer
# Looping pulse tweens on slots that still have dice while the active type is spent AND no
# Power is banked. _nudge_nodes tracks which slots are currently pulsing so a refresh whose
# nudge-set is unchanged leaves the running tweens alone (no restart-mid-breath).
var _nudge_tweens: Array[Tween] = []
var _nudge_nodes: Array = []



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
    Events.player_turn_ended.connect(_on_player_turn_ended)
    Events.dice_bought.connect(_on_dice_bought)
    Events.resize_dice_interface.connect(_on_resize_dice_interface)
    Events.charge_dice_animation.connect(_on_charge_dice_animation)
    initialize_dices()
    _resize_panel_for_dice_inventory()
    Events.temporary_dice_added.connect(_on_temporary_dice_added)
    Events.active_dice_changed.connect(update_selected_highlight)
    # Fires after every roll AND after a card spends your Power to 0 (end of the reset
    # handler, past the red path's await) - the moment the "you're out, switch" nudge
    # should start or stop. Idempotent, so re-firing without a state change is a no-op.
    Events.hover_playable_cards.connect(_on_hover_playable_cards)
    await get_tree().process_frame
    update_selected_highlight(Global.dice_type)




# Called when a dice is rolled
func _on_dice_rolled(dice_type: String, roll_value: int):
    # A Ricochet reroll re-rolls the die already spent on the first result, so it must not
    # consume a second one. Skipping the per-type branch skips its label refresh too, which is
    # correct (the count didn't move) - but the highlight refresh at the tail of this function
    # still has to run, since the reroll DID change Global.roll_value and that drives the
    # "you still have dice on another slot" nudge.
    if Global.ricochet_reroll_active:
        update_selected_highlight()
        return
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
    update_selected_highlight()

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

        
        
        
        
func _on_player_turn_ended() -> void:
    # Bank whatever Golem Dice the player didn't spend, for the next turn's refill to add on.
    # Read at turn END rather than at the next turn's start so a shop purchase (which does
    # `current += 1` between fights) can never be mistaken for a leftover - see the comment
    # on Global.golem_dice_carryover.
    # Explicit int: Global's dice counters are untyped, so `:=`/maxi() can't infer from them.
    var leftover: int = Global.even_dice_current_amount
    Global.golem_dice_carryover = maxi(0, leftover)


func _on_player_turn_started() -> void:
    Global.blue_dice_current_amount = Global.blue_dice_max_amount + Global.blue_dice_bonus_amount + Global.blue_dice_bonus_amount_fight
    Global.red_dice_current_amount = Global.red_dice_max_amount + Global.red_dice_bonus_amount
    Global.evil_dice_current_amount = Global.evil_dice_max_amount + Global.evil_dice_bonus_amount
    Global.green_dice_current_amount = Global.green_dice_max_amount + Global.green_dice_bonus_amount
    Global.giant_dice_current_amount = Global.giant_dice_max_amount + Global.giant_dice_bonus_amount
    Global.magma_dice_current_amount = Global.magma_dice_max_amount + Global.magma_dice_bonus_amount
    # Golem Dice: the one type that does NOT simply reset to max+bonus. Whatever went
    # unspent last turn (captured in _on_player_turn_ended) is added on top. No cap - the
    # cost of hoarding is the tempo you gave up to do it.
    # A NEGATIVE bonus (Depleted from Electrify, the Dicelord's Dice Theft) eats into the
    # carried dice like it eats into any other type's refill, hence the single clamp over
    # the whole sum rather than protecting the carry: "you have 1 less Dice next turn"
    # stays honest, and banking dice can't be used to dodge the debuff.
    Global.even_dice_current_amount = maxi(0,
            Global.even_dice_max_amount + Global.even_dice_bonus_amount
            + Global.golem_dice_carryover)
    Global.golem_dice_carryover = 0
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
    update_selected_highlight()
    _play_panel_refill_burst()

func _on_hover_playable_cards() -> void:
    update_selected_highlight()

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
    update_selected_highlight()

func initialize_dices():
    # Blue is assumed permanent (nothing in the game reduces it to 0 in
    # practice) so it stays always-visible - but Red can now be traded away
    # entirely (event_hollow_idol.gd), so it needs the same show/hide check
    # already applied to every other non-blue dice type below.
    if Global.red_dice_max_amount > 0 or Global.red_dice_current_amount > 0 or Global.red_dice_bonus_amount > 0:
        dice_2.show()
    else:
        dice_2.hide()

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
    _resize_panel_for_dice_inventory()

func _resize_panel_for_dice_inventory() -> void:
    # Count slots that are actually visible right now (mirrors
    # initialize_dices()'s own per-type conditions) rather than relying on
    # Global.dice_inventory, which most temporary-dice-granting cards never
    # update (only cogwork.gd does) and is therefore frequently stale.
    var visible_dice_count := 1  # blue is always shown
    if Global.red_dice_max_amount > 0 or Global.red_dice_current_amount > 0 or Global.red_dice_bonus_amount > 0:
        visible_dice_count += 1
    if Global.evil_dice_max_amount > 0 or Global.evil_dice_current_amount > 0 or Global.evil_dice_bonus_amount > 0:
        visible_dice_count += 1
    if Global.giant_dice_max_amount > 0 or Global.giant_dice_current_amount > 0 or Global.giant_dice_bonus_amount > 0:
        visible_dice_count += 1
    if Global.magma_dice_max_amount > 0 or Global.magma_dice_current_amount > 0 or Global.magma_dice_bonus_amount > 0:
        visible_dice_count += 1
    if Global.even_dice_max_amount > 0 or Global.even_dice_current_amount > 0 or Global.even_dice_bonus_amount > 0:
        visible_dice_count += 1
    if Global.odd_dice_max_amount > 0 or Global.odd_dice_current_amount > 0 or Global.odd_dice_bonus_amount > 0:
        visible_dice_count += 1
    if Global.green_dice_max_amount > 0 or Global.green_dice_current_amount > 0 or Global.green_dice_bonus_amount > 0:
        visible_dice_count += 1
    if Global.mech_dice_max_amount > 0 or Global.mech_dice_current_amount > 0 or Global.mech_dice_bonus_amount > 0 or Global.mech_dice_bonus_amount_fight > 0:
        visible_dice_count += 1
    dice_panel.custom_minimum_size.x = (visible_dice_count * 65) + 20

func _on_charge_dice_animation():
    animation_player.play("charge")  # Play the 'charge' animation
    initialize_dices()
    # initialize_dices() only refreshes the optional dice types' labels - blue (dice_1)
    # and red (dice_2) are always-visible and skipped there, so charging a blue/red die
    # (e.g. Disintegrate on the active blue die, Electrify, Spark, Blood Drop) wouldn't
    # update its count. Refresh them here so the displayed amount stays correct.
    dice_1_label.text = str(Global.blue_dice_current_amount, "/", Global.blue_dice_max_amount)
    dice_2_label.text = str(Global.red_dice_current_amount, "/", Global.red_dice_max_amount)
    update_selected_highlight()

func _on_temporary_dice_added(dice_type: String):
    print("adding dice")
    initialize_dices()  # Refresh the interface
    _resize_panel_for_dice_inventory()

func _show_tooltip(dice_node: VBoxContainer, dice_type: String) -> void:
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null
    tooltip_instance = TooltipScene.instantiate()
    Global.add_tooltip(tooltip_instance, self)
    var tooltip_panel = tooltip_instance.get_node("DiceTooltip")
    tooltip_panel.get_tooltip_content(dice_type)
    tooltip_panel.show_tooltip(Vector2(498, 123))  # adjust to taste

func _hide_tooltip() -> void:
    if tooltip_instance and is_instance_valid(tooltip_instance):
        tooltip_instance.queue_free()
        tooltip_instance = null


# Combat can end (or the view can be swapped) while a dice slot is hovered - mouse_exited
# never fires on a node being destroyed, and the tooltip lives on the tree root, so without
# this it outlives the battle. Same bug class as shop.gd's dice tooltips.
func _exit_tree() -> void:
    _hide_tooltip()
        
        

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


func update_selected_highlight(selected_type: String = Global.dice_type) -> void:
    var active_empty: bool = Global.get(DICE_TYPE_TO_AMOUNT.get(selected_type, "blue_dice_current_amount")) <= 0
    # Nudge toward another die only once the current die is spent AND no Power is banked -
    # otherwise it nags "switch to me!" while you still have Power to spend on a card first
    # (you rolled blue, blue's now empty, but you're about to Strike with that Power). Once
    # a card consumes the Power (roll_value -> 0), hover_playable_cards fires and the nudge
    # kicks in. Suppressed during the tutorial - it gates/spotlights slots itself.
    var want_nudge := active_empty and Global.roll_value <= 0 and not Global.tutorial_on

    # Which slots should be pulsing this pass (deterministic dict order, so the array can be
    # compared by value below).
    var new_nudge: Array = []
    if want_nudge:
        for dice_type in DICE_TYPE_TO_NODE:
            if dice_type == selected_type:
                continue
            var n = get(DICE_TYPE_TO_NODE[dice_type])
            if Global.get(DICE_TYPE_TO_AMOUNT[dice_type]) > 0 and n.visible:
                new_nudge.append(n)

    # Only tear down / rebuild the looping pulses when the SET actually changes, so the
    # frequent refresh signals this listens to (rolls, power changes, switches) can't
    # restart the breathing animation every time. A pulsing slot's modulate/scale are owned
    # by its tween, so those nodes are skipped in the styling loop while their set holds.
    var nudge_changed: bool = new_nudge != _nudge_nodes
    if nudge_changed:
        for t in _nudge_tweens:
            if t and t.is_valid():
                t.kill()
        _nudge_tweens.clear()
        _nudge_nodes = new_nudge

    for dice_type in DICE_TYPE_TO_NODE:
        var node = get(DICE_TYPE_TO_NODE[dice_type])
        if node in _nudge_nodes:
            if nudge_changed:
                _start_nudge_pulse(node)
            continue
        var amount: int = Global.get(DICE_TYPE_TO_AMOUNT[dice_type])
        var depleted := amount <= 0
        if dice_type == selected_type and not depleted:
            var base_color: Color = DicePalette.accent(dice_type)
            var highlight := base_color.lerp(Color.WHITE, 0.55)
            node.modulate = Color(highlight.r * 1.3, highlight.g * 1.3, highlight.b * 1.3, 1.0)
            node.scale = Vector2(1.15, 1.15)
        elif depleted:
            node.modulate = Color(0.32, 0.32, 0.32, 0.55)
            node.scale = Vector2(1.0, 1.0)
        else:
            node.modulate = Color(0.72, 0.72, 0.72, 1.0)
            node.scale = Vector2(1.0, 1.0)


# Soft looping "I'm still ready" pulse on an available slot while the active die is out
# of rolls. Deliberately subtle: a warm brightening from the idle gray plus a whisper of
# scale - the gold-ish tint matches the game's established "actionable" language (End
# Turn pulse, tutorial glow) without competing with the selected slot's accent pop.
func _start_nudge_pulse(node: Control) -> void:
    node.pivot_offset = node.size / 2.0
    var tween := create_tween().set_loops()
    tween.tween_property(node, "modulate", Color(1.12, 1.05, 0.85, 1.0), 0.55) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.parallel().tween_property(node, "scale", Vector2(1.06, 1.06), 0.55) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(node, "modulate", Color(0.72, 0.72, 0.72, 1.0), 0.55) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.parallel().tween_property(node, "scale", Vector2(1.0, 1.0), 0.55) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _nudge_tweens.append(tween)


# Small "back up!" punch played on a dice slot that just got refilled from
# empty at the start of a turn. Plays after update_selected_highlight() has
# "Dice are back!" punch played on the whole dice panel at the start of every
# turn, regardless of what was depleted last turn — simpler and more readable
# than animating individual slots, and reads as "your resources just refreshed."
func _play_panel_refill_burst() -> void:
    dice_panel.pivot_offset = dice_panel.size / 2.0
    var resting_modulate: Color = dice_panel.modulate
    var tween := create_tween()
    tween.tween_property(dice_panel, "scale", Vector2(1.12, 1.12), 0.12) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(dice_panel, "modulate", Color(1.6, 1.6, 1.6, resting_modulate.a), 0.1)
    tween.tween_property(dice_panel, "scale", Vector2(1.0, 1.0), 0.22) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(dice_panel, "modulate", resting_modulate, 0.28)
