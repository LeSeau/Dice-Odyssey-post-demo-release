extends Control

const TooltipScene = preload("res://scenes/ui/dice_tooltip.tscn")


@onready var buy_dice_1: Button = $MarginContainer/Panel/HBoxContainer/Dice1/BuyDice1
@onready var buy_dice_2: Button = $MarginContainer/Panel/HBoxContainer/Dice2/BuyDice2
@onready var dice_1: VBoxContainer = $MarginContainer/Panel/HBoxContainer/Dice1
@onready var dice_2: VBoxContainer = $MarginContainer/Panel/HBoxContainer/Dice2
@onready var dice_3: VBoxContainer = $MarginContainer/Panel/HBoxContainer/Dice3
@onready var dice_4: VBoxContainer = $MarginContainer/Panel/HBoxContainer/Dice4
@onready var dice_5: VBoxContainer = $MarginContainer/Panel/HBoxContainer/Dice5
@onready var dice_6: VBoxContainer = $MarginContainer/Panel/HBoxContainer/Dice6
@onready var dice_7: VBoxContainer = $MarginContainer/Panel/HBoxContainer/Dice7
@onready var dice_8: VBoxContainer = $MarginContainer/Panel/HBoxContainer/Dice8
@onready var dice_9: VBoxContainer = $MarginContainer/Panel/HBoxContainer/Dice9


@onready var buy_dice_1_label: RichTextLabel = $MarginContainer/Panel/HBoxContainer/Dice1/BuyDice1/BuyDice1Label
@onready var buy_dice_2_label: RichTextLabel = $MarginContainer/Panel/HBoxContainer/Dice2/BuyDice2/BuyDice2Label
@onready var buy_dice_3_label: RichTextLabel = $MarginContainer/Panel/HBoxContainer/Dice3/BuyDice3/BuyDice3Label
@onready var buy_dice_4_label: RichTextLabel = $MarginContainer/Panel/HBoxContainer/Dice4/BuyDice4/BuyDice4Label
@onready var buy_dice_5_label: RichTextLabel = $MarginContainer/Panel/HBoxContainer/Dice5/BuyDice5/BuyDice5Label
@onready var buy_dice_6_label: RichTextLabel = $MarginContainer/Panel/HBoxContainer/Dice6/BuyDice6/BuyDice6Label
@onready var buy_dice_7_label: RichTextLabel = $MarginContainer/Panel/HBoxContainer/Dice7/BuyDice7/BuyDice7Label
@onready var buy_dice_8_label: RichTextLabel = $MarginContainer/Panel/HBoxContainer/Dice8/BuyDice8/BuyDice8Label
@onready var buy_dice_9_label: RichTextLabel = $MarginContainer/Panel/HBoxContainer/Dice9/BuyDice9/BuyDice9Label


@export var run_stats: RunStats

var evil_dice_base_price = 240
var giant_dice_base_price = 240
var magma_dice_base_price = 270
var even_dice_base_price = 210
var odd_dice_base_price = 190
var blue_dice_base_price = 180
var red_dice_base_price = 180
var green_dice_base_price = 150
var mech_dice_base_price = 200

var reroll_price = 20

# Every dice purchase (ANY type) raises ALL dice prices by this factor. Replaces the old
# per-type-only escalation, which almost never fired in practice (players diversify types,
# so each new type came at base price and a 2nd die was affordable too early mid-run).
# Die #1 at base = the happy milestone; die #2 at ~1.4x = late-run stretch; die #3 = trophy.
const GLOBAL_DICE_PRICE_ESCALATION := 1.4

var evil_dice_price = evil_dice_base_price
var giant_dice_price = giant_dice_base_price
var magma_dice_price = magma_dice_base_price
var even_dice_price = even_dice_base_price
var odd_dice_price = odd_dice_base_price
var blue_dice_price = blue_dice_base_price
var red_dice_price = red_dice_base_price
var green_dice_price = green_dice_base_price
var mech_dice_price = mech_dice_base_price


var existing_dices = 9



func _ready():
    Events.dice_price_changed.connect(_on_dice_price_changed)
    var dice_nodes = [dice_1, dice_2, dice_3, dice_4, dice_5, dice_6, dice_7, dice_8, dice_9]
    
    # Hide all dice containers initially
    for dice in dice_nodes:
        dice.hide()
    
    # Only randomize if this is first time opening the shop
    if not Global.shop_initialized:
        # Generate the random selection
        var chosen_indexes := []
        while chosen_indexes.size() < 3:
            var rand_index = randi() % existing_dices
            if not chosen_indexes.has(rand_index):
                chosen_indexes.append(rand_index)
        
        # Store the selection in Global
        Global.shop_dice_selection = chosen_indexes
        Global.shop_initialized = true

    
    # Show the dice that were selected (either just now or previously)
    for index in Global.shop_dice_selection:
        dice_nodes[index].show()
    update_dice_price()

func _on_button_pressed() -> void:
    Events.shop_exited.emit()



func _on_buy_dice_1_pressed() -> void:
    if Global.gold >= evil_dice_price:
        Events.dice_bought.emit("evil")
        SFXPlayer.play(load("res://sounds/buydicesound.wav")) 
        Global.evil_dice_max_amount+=1
        Global.evil_dice_current_amount+=1
        Global.gold-= evil_dice_price
        Events.gold_changed.emit()
        print(Global.gold)
        if Global.evil_dice_current_amount == 1:
            Global.dice_inventory.append("evil")
        Events.update_dice_top_bar.emit()
        Global.purchased_dice_counts["evil"] += 1
        update_dice_price()



func _on_buy_dice_2_pressed() -> void:
    if Global.gold >= giant_dice_price:
        Global.gold-= giant_dice_price
        Events.gold_changed.emit()
        Events.dice_bought.emit("giant")
        SFXPlayer.play(load("res://sounds/buydicesound.wav")) 
        Global.giant_dice_max_amount+=1
        Global.giant_dice_current_amount+=1
        if Global.giant_dice_current_amount == 1:
            Global.dice_inventory.append("giant")
        Events.update_dice_top_bar.emit()
        Global.purchased_dice_counts["giant"] += 1
        update_dice_price()
    
func _on_buy_dice_3_pressed() -> void:
    if Global.gold >= magma_dice_price:
        Global.gold-= magma_dice_price
        Events.gold_changed.emit()
        Events.dice_bought.emit("magma")
        SFXPlayer.play(load("res://sounds/buydicesound.wav")) 
        Global.magma_dice_max_amount+=1
        Global.magma_dice_current_amount+=1
        if Global.magma_dice_current_amount == 1:
            Global.dice_inventory.append("magma")
        Events.update_dice_top_bar.emit()
        Global.purchased_dice_counts["magma"] += 1
        update_dice_price()

func _on_buy_dice_4_pressed() -> void:
    if Global.gold >= even_dice_price:
        Global.gold-= even_dice_price
        Events.gold_changed.emit()
        Events.dice_bought.emit("even")
        SFXPlayer.play(load("res://sounds/buydicesound.wav")) 
        Global.even_dice_max_amount+=1
        Global.even_dice_current_amount+=1
        if Global.even_dice_current_amount == 1:
            Global.dice_inventory.append("even")
        Events.update_dice_top_bar.emit()
        Global.purchased_dice_counts["even"] += 1
        update_dice_price()

func _on_buy_dice_5_pressed() -> void:
    if Global.gold >= odd_dice_price:
        Global.gold-= odd_dice_price
        Events.gold_changed.emit()
        Events.dice_bought.emit("odd")
        SFXPlayer.play(load("res://sounds/buydicesound.wav")) 
        Global.odd_dice_max_amount+=1
        Global.odd_dice_current_amount+=1
        if Global.odd_dice_current_amount == 1:
            Global.dice_inventory.append("odd")
        Events.update_dice_top_bar.emit()
        Global.purchased_dice_counts["odd"] += 1
        update_dice_price()
        
func update_dice_price() -> void:
    var total_dice_purchased := 0
    for count in Global.purchased_dice_counts.values():
        total_dice_purchased += count
    var escalation := pow(GLOBAL_DICE_PRICE_ESCALATION, total_dice_purchased)
    evil_dice_price  = int(evil_dice_base_price  * escalation)
    giant_dice_price = int(giant_dice_base_price * escalation)
    magma_dice_price = int(magma_dice_base_price * escalation)
    even_dice_price  = int(even_dice_base_price  * escalation)
    odd_dice_price   = int(odd_dice_base_price   * escalation)
    blue_dice_price  = int(blue_dice_base_price  * escalation)
    red_dice_price   = int(red_dice_base_price   * escalation)
    green_dice_price = int(green_dice_base_price * escalation)
    mech_dice_price  = int(mech_dice_base_price  * escalation)


    buy_dice_1_label.text = "[center]Buy ([color=#FFD700]" + str(evil_dice_price) + "G[/color])[/center]"
    buy_dice_2_label.text = "[center]Buy ([color=#FFD700]" + str(giant_dice_price) + "G[/color])[/center]"
    buy_dice_3_label.text = "[center]Buy ([color=#FFD700]" + str(magma_dice_price) + "G[/color])[/center]"
    buy_dice_4_label.text = "[center]Buy ([color=#FFD700]" + str(even_dice_price) + "G[/color])[/center]"
    buy_dice_5_label.text = "[center]Buy ([color=#FFD700]" + str(odd_dice_price) + "G[/color])[/center]"
    buy_dice_6_label.text = "[center]Buy ([color=#FFD700]" + str(blue_dice_price) + "G[/color])[/center]"
    buy_dice_7_label.text = "[center]Buy ([color=#FFD700]" + str(red_dice_price) + "G[/color])[/center]"
    buy_dice_8_label.text = "[center]Buy ([color=#FFD700]" + str(green_dice_price) + "G[/color])[/center]"
    buy_dice_9_label.text = "[center]Buy ([color=#FFD700]" + str(mech_dice_price) + "G[/color])[/center]"

    get_cheapest_available_dice_price()

func _on_dice_price_changed():
    update_dice_price()


func _on_buy_dice_6_pressed() -> void:
    if Global.gold >= blue_dice_price:
        Global.gold-= blue_dice_price
        Events.gold_changed.emit()
        Events.dice_bought.emit("blue")
        SFXPlayer.play(load("res://sounds/buydicesound.wav")) 
        Global.blue_dice_max_amount+=1
        Global.blue_dice_current_amount+=1
        if Global.blue_dice_current_amount == 1:
            Global.dice_inventory.append("blue")
        Events.update_dice_top_bar.emit()
        Global.purchased_dice_counts["blue"] += 1
        update_dice_price()


func _on_buy_dice_7_pressed() -> void:
    if Global.gold >= red_dice_price:
        Global.gold-= red_dice_price
        Events.gold_changed.emit()
        Events.dice_bought.emit("red")
        SFXPlayer.play(load("res://sounds/buydicesound.wav")) 
        Global.red_dice_max_amount+=1
        Global.red_dice_current_amount+=1
        if Global.red_dice_current_amount == 1:
            Global.dice_inventory.append("red")
        Events.update_dice_top_bar.emit()
        Global.purchased_dice_counts["red"] += 1
        update_dice_price()
        
func _on_buy_dice_8_pressed() -> void:
    if Global.gold >= green_dice_price:
        Global.gold-= green_dice_price
        Events.gold_changed.emit()
        Events.dice_bought.emit("green")
        SFXPlayer.play(load("res://sounds/buydicesound.wav")) 
        Global.green_dice_max_amount+=1
        Global.green_dice_current_amount+=1
        if Global.green_dice_current_amount == 1:
            Global.dice_inventory.append("green")
        Events.update_dice_top_bar.emit()
        Global.purchased_dice_counts["green"] += 1
        update_dice_price()
        
func _on_buy_dice_9_pressed() -> void:
    if Global.gold >= mech_dice_price:
        Global.gold-= mech_dice_price
        Events.gold_changed.emit()
        Events.dice_bought.emit("mech")
        SFXPlayer.play(load("res://sounds/buydicesound.wav")) 
        Global.mech_dice_max_amount+=1
        Global.mech_dice_current_amount+=1
        if Global.mech_dice_current_amount == 1:
            Global.dice_inventory.append("mech")
        Events.update_dice_top_bar.emit()
        Global.purchased_dice_counts["mech"] += 1
        update_dice_price()


        
func is_mouse_over_dice() -> bool:
    return get_global_rect().has_point(get_global_mouse_position())

var tooltip_instance_requirement: CanvasLayer
var tooltip_instance_bonus: CanvasLayer

# Dice Shop can now be open while the Map is fully live behind it (it's a
# TopBar/CanvasLayer child, floating over the map instead of blocking it - see
# run.gd::dice_shop_instance). Any room click that lands on the shop panel and
# reaches a Map room anyway (or the player just travels to a room while still
# hovering a dice) makes run.gd free this whole DiceShop instance
# (_show_map()'s dice_shop_instance.queue_free()) while a tooltip is still
# showing - mouse_exited never gets a chance to fire on a node being destroyed,
# so without this the tooltip (parented under get_tree().root, independent of
# this node) is orphaned and sits on screen forever, surviving into whatever
# screen comes next. Same bug class already fixed once in relic_ui.gd.
func _exit_tree() -> void:
    _cleanup_dice_tooltips()

func _cleanup_dice_tooltips() -> void:
    if tooltip_instance_requirement and is_instance_valid(tooltip_instance_requirement):
        tooltip_instance_requirement.queue_free()
        tooltip_instance_requirement = null
    if tooltip_instance_bonus and is_instance_valid(tooltip_instance_bonus):
        tooltip_instance_bonus.queue_free()
        tooltip_instance_bonus = null

func _on_dice_1_mouse_entered() -> void:
    await get_tree().create_timer(0.01).timeout

    if not is_mouse_over_dice():
        return

    var dice_pos = dice_1.global_position + Vector2(0, dice_1.size.y - 510)

    tooltip_instance_requirement = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip_instance_requirement)
    var tooltip_panel = tooltip_instance_requirement.get_node("DiceTooltip")
    tooltip_panel.get_tooltip_content("evil")
    tooltip_panel.show_tooltip(dice_pos)

    # 🔴 Show bonus requirement tooltip (offset below)
    var need_additional_tooltip = false
    if need_additional_tooltip:
        tooltip_instance_bonus = TooltipScene.instantiate()
        get_tree().root.add_child(tooltip_instance_bonus)
        var tooltip_bonus_panel = tooltip_instance_bonus.get_node("DiceTooltip")
        tooltip_bonus_panel.get_tooltip_content("evil")
        tooltip_bonus_panel.show_tooltip(dice_pos + Vector2(0, 75))  # slight offset


func _on_dice_1_mouse_exited() -> void:
    if tooltip_instance_requirement and is_instance_valid(tooltip_instance_requirement):
        tooltip_instance_requirement.queue_free()
        tooltip_instance_requirement = null

    if tooltip_instance_bonus and is_instance_valid(tooltip_instance_bonus):
        tooltip_instance_bonus.queue_free()
        tooltip_instance_bonus = null



func _on_dice_2_mouse_entered() -> void:
    await get_tree().create_timer(0.01).timeout

    if not is_mouse_over_dice():
        return

    var dice_pos = dice_2.global_position + Vector2(0, dice_2.size.y - 510)

    tooltip_instance_requirement = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip_instance_requirement)
    var tooltip_panel = tooltip_instance_requirement.get_node("DiceTooltip")
    tooltip_panel.get_tooltip_content("giant")
    tooltip_panel.show_tooltip(dice_pos)

func _on_dice_2_mouse_exited() -> void:
    if tooltip_instance_requirement and is_instance_valid(tooltip_instance_requirement):
        tooltip_instance_requirement.queue_free()
        tooltip_instance_requirement = null

    if tooltip_instance_bonus and is_instance_valid(tooltip_instance_bonus):
        tooltip_instance_bonus.queue_free()
        tooltip_instance_bonus = null




func _on_dice_3_mouse_entered() -> void:
    await get_tree().create_timer(0.01).timeout

    if not is_mouse_over_dice():
        return

    var dice_pos = dice_3.global_position + Vector2(0, dice_3.size.y - 510)

    tooltip_instance_requirement = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip_instance_requirement)
    var tooltip_panel = tooltip_instance_requirement.get_node("DiceTooltip")
    tooltip_panel.get_tooltip_content("magma")
    tooltip_panel.show_tooltip(dice_pos)
    


func _on_dice_3_mouse_exited() -> void:
    if tooltip_instance_requirement and is_instance_valid(tooltip_instance_requirement):
        tooltip_instance_requirement.queue_free()
        tooltip_instance_requirement = null

    if tooltip_instance_bonus and is_instance_valid(tooltip_instance_bonus):
        tooltip_instance_bonus.queue_free()
        tooltip_instance_bonus = null


func _on_dice_4_mouse_entered() -> void:
    await get_tree().create_timer(0.01).timeout

    if not is_mouse_over_dice():
        return

    var dice_pos = dice_4.global_position + Vector2(0, dice_4.size.y - 510)

    tooltip_instance_requirement = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip_instance_requirement)
    var tooltip_panel = tooltip_instance_requirement.get_node("DiceTooltip")
    tooltip_panel.get_tooltip_content("even")
    tooltip_panel.show_tooltip(dice_pos)


func _on_dice_4_mouse_exited() -> void:
    if tooltip_instance_requirement and is_instance_valid(tooltip_instance_requirement):
        tooltip_instance_requirement.queue_free()
        tooltip_instance_requirement = null

    if tooltip_instance_bonus and is_instance_valid(tooltip_instance_bonus):
        tooltip_instance_bonus.queue_free()
        tooltip_instance_bonus = null



func _on_dice_5_mouse_entered() -> void:
    await get_tree().create_timer(0.01).timeout

    if not is_mouse_over_dice():
        return

    var dice_pos = dice_5.global_position + Vector2(0, dice_5.size.y - 510)

    tooltip_instance_requirement = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip_instance_requirement)
    var tooltip_panel = tooltip_instance_requirement.get_node("DiceTooltip")
    tooltip_panel.get_tooltip_content("odd")
    tooltip_panel.show_tooltip(dice_pos)


func _on_dice_5_mouse_exited() -> void:
    if tooltip_instance_requirement and is_instance_valid(tooltip_instance_requirement):
        tooltip_instance_requirement.queue_free()
        tooltip_instance_requirement = null

    if tooltip_instance_bonus and is_instance_valid(tooltip_instance_bonus):
        tooltip_instance_bonus.queue_free()
        tooltip_instance_bonus = null




func _on_dice_6_mouse_entered() -> void:
    await get_tree().create_timer(0.01).timeout

    if not is_mouse_over_dice():
        return

    var dice_pos = dice_6.global_position + Vector2(0, dice_6.size.y - 510)

    tooltip_instance_requirement = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip_instance_requirement)
    var tooltip_panel = tooltip_instance_requirement.get_node("DiceTooltip")
    tooltip_panel.get_tooltip_content("blue")
    tooltip_panel.show_tooltip(dice_pos)


func _on_dice_6_mouse_exited() -> void:
    if tooltip_instance_requirement and is_instance_valid(tooltip_instance_requirement):
        tooltip_instance_requirement.queue_free()
        tooltip_instance_requirement = null

    if tooltip_instance_bonus and is_instance_valid(tooltip_instance_bonus):
        tooltip_instance_bonus.queue_free()
        tooltip_instance_bonus = null





func _on_dice_7_mouse_entered() -> void:
    await get_tree().create_timer(0.01).timeout

    if not is_mouse_over_dice():
        return

    var dice_pos = dice_7.global_position + Vector2(0, dice_7.size.y - 510)

    tooltip_instance_requirement = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip_instance_requirement)
    var tooltip_panel = tooltip_instance_requirement.get_node("DiceTooltip")
    tooltip_panel.get_tooltip_content("red")
    tooltip_panel.show_tooltip(dice_pos)


func _on_dice_7_mouse_exited() -> void:
    if tooltip_instance_requirement and is_instance_valid(tooltip_instance_requirement):
        tooltip_instance_requirement.queue_free()
        tooltip_instance_requirement = null

    if tooltip_instance_bonus and is_instance_valid(tooltip_instance_bonus):
        tooltip_instance_bonus.queue_free()
        tooltip_instance_bonus = null


func _on_dice_8_mouse_entered() -> void:
    await get_tree().create_timer(0.01).timeout

    if not is_mouse_over_dice():
        return

    var dice_pos = dice_8.global_position + Vector2(0, dice_8.size.y - 510)

    tooltip_instance_requirement = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip_instance_requirement)
    var tooltip_panel = tooltip_instance_requirement.get_node("DiceTooltip")
    tooltip_panel.get_tooltip_content("green")
    tooltip_panel.show_tooltip(dice_pos)

func _on_dice_8_mouse_exited() -> void:
    if tooltip_instance_requirement and is_instance_valid(tooltip_instance_requirement):
        tooltip_instance_requirement.queue_free()
        tooltip_instance_requirement = null

    if tooltip_instance_bonus and is_instance_valid(tooltip_instance_bonus):
        tooltip_instance_bonus.queue_free()
        tooltip_instance_bonus = null
        
func _on_dice_9_mouse_entered() -> void:
    await get_tree().create_timer(0.01).timeout

    if not is_mouse_over_dice():
        return

    var dice_pos = dice_9.global_position + Vector2(0, dice_9.size.y - 510)

    tooltip_instance_requirement = TooltipScene.instantiate()
    get_tree().root.add_child(tooltip_instance_requirement)
    var tooltip_panel = tooltip_instance_requirement.get_node("DiceTooltip")
    tooltip_panel.get_tooltip_content("mech")
    tooltip_panel.show_tooltip(dice_pos)


func _on_dice_9_mouse_exited() -> void:
    if tooltip_instance_requirement and is_instance_valid(tooltip_instance_requirement):
        tooltip_instance_requirement.queue_free()
        tooltip_instance_requirement = null

    if tooltip_instance_bonus and is_instance_valid(tooltip_instance_bonus):
        tooltip_instance_bonus.queue_free()
        tooltip_instance_bonus = null





func _on_exit_shop_button_pressed() -> void:
    print("exiting shop")
    Events.check_if_can_purchase_dice.emit()
    Events.show_map_requested.emit()


func reroll_shop_dice() -> void:
    var dice_nodes = [dice_1, dice_2, dice_3, dice_4, dice_5, dice_6, dice_7, dice_8, dice_9]

    # Hide all dice first
    for dice in dice_nodes:
        dice.hide()

    # Generate a new random selection of 3 unique dice
    var chosen_indexes := []
    while chosen_indexes.size() < 3:
        var rand_index = randi() % existing_dices
        if not chosen_indexes.has(rand_index):
            chosen_indexes.append(rand_index)

    # Save the selection in Global
    Global.shop_dice_selection = chosen_indexes

    # Show the new dice
    for index in chosen_indexes:
        dice_nodes[index].show()


func _on_reroll_button_pressed() -> void:
    if Global.gold >= reroll_price:
        reroll_shop_dice()
        Global.gold -= reroll_price
        Events.gold_changed.emit()

func get_cheapest_available_dice_price() -> int:
    var dice_price_map = {
        0: evil_dice_price,
        1: giant_dice_price,
        2: magma_dice_price,
        3: even_dice_price,
        4: odd_dice_price,
        5: blue_dice_price,
        6: red_dice_price,
        7: green_dice_price,
        8: mech_dice_price
    }
    
    var prices = []
    for index in Global.shop_dice_selection:
        prices.append(dice_price_map[index])
    Global.cheapest_dice_price = prices.min()
    print(Global.cheapest_dice_price)
    return prices.min()
