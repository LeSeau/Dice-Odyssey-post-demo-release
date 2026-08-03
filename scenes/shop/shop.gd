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

var reroll_price = 20

# Base prices + the global x1.4 escalation now live in Global (DICE_BASE_PRICES /
# DICE_PRICE_ESCALATION / current_dice_price(), moved 2026-07-23) so the card shop's
# discounted "deal die" always reads the same numbers as this shop. The deal die itself
# is SOLD in the card shop, not here - this shop only re-picks which type it is on
# reroll (it must stay outside the 3 types shown here).
var evil_dice_price = 0
var giant_dice_price = 0
var magma_dice_price = 0
var even_dice_price = 0
var odd_dice_price = 0
var blue_dice_price = 0
var red_dice_price = 0
var green_dice_price = 0
var mech_dice_price = 0


var existing_dices = 9

const COIN_TEXTURE := preload("res://gold_icon_v2.png")
# All coin-adjacent numbers use LuckiestGuy (the game's established "numbers" font -
# top bar, run stats) via a shared FontVariation whose baseline_offset is CALIBRATED so
# digits sit at the true optical center of their line box. CinzelDecorative was tried
# and rejected: its digits aren't uniform lining figures, so "37" and "180" center
# differently and no single offset can fix all price strings.
const PRICE_FONT := preload("res://fonts/luckiest_guy_numbers.tres")
# Number labels built in code inside each Buy button (index-aligned with dice_nodes /
# DICE_TYPE_ORDER). A real coin sprite + Label reads far better than a bbcode inline
# image, which renders small and sits low on the text baseline.
var _dice_price_labels: Array[Label] = []
var _reroll_price_label: Label = null



func _ready():
    Events.dice_price_changed.connect(_on_dice_price_changed)
    var dice_nodes = [dice_1, dice_2, dice_3, dice_4, dice_5, dice_6, dice_7, dice_8, dice_9]
    
    # Hide all dice containers initially
    for dice in dice_nodes:
        dice.hide()
    
    # Only randomize if this is first time opening the shop (shared with the card shop,
    # which needs the same state for its deal die - whichever room opens first wins)
    Global.ensure_dice_shop_state()

    # Show the dice that were selected (either just now or previously)
    for index in Global.shop_dice_selection:
        dice_nodes[index].show()

    # Each die is bought with its own Buy BUTTON (the .tscn wires pressed -> buy). Replace
    # the button's plain bbcode price label with a centered coin-sprite + number row so the
    # coin is a properly sized, vertically-centered image.
    _dice_price_labels.clear()
    for i in dice_nodes.size():
        var col: VBoxContainer = dice_nodes[i]
        var buy_btn: Button = col.get_node("BuyDice%d" % (i + 1))
        buy_btn.get_node("BuyDice%dLabel" % (i + 1)).hide()
        var row := _build_coin_row(30, 22)
        buy_btn.add_child(row["hbox"])
        _dice_price_labels.append(row["label"])

    # Reroll button: same coin-sprite row, with a "Reroll" word + spacer before the coin
    # (replaces the bbcode label so the coin isn't small/baseline-low with a wide gap).
    var reroll_btn: Button = $RerollButton
    reroll_btn.get_node("RichTextLabel").hide()
    var rrow := _build_coin_row(30, 22)
    var word := Label.new()
    word.text = "Reroll"
    word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    word.add_theme_font_size_override("font_size", 26)
    word.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.01))
    word.add_theme_constant_override("outline_size", 5)
    word.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(12, 0)
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rrow["hbox"].add_child(word)
    rrow["hbox"].add_child(spacer)
    rrow["hbox"].move_child(word, 0)
    rrow["hbox"].move_child(spacer, 1)
    rrow["label"].text = str(reroll_price)
    _reroll_price_label = rrow["label"]
    reroll_btn.add_child(rrow["hbox"])

    update_dice_price()

func _on_button_pressed() -> void:
    Events.shop_exited.emit()


# A centered [coin sprite][number] row that fills its parent, mouse-transparent so it
# never blocks the button/click underneath. Returns {hbox, label} for later updates.
func _build_coin_row(coin_px: int, font_px: int) -> Dictionary:
    var hbox := HBoxContainer.new()
    hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    # 0 (not the default 4): the coin art carries ~15% transparent padding, so 0 already
    # leaves a snug ~4px visible gap; positive values read as "too far apart".
    hbox.add_theme_constant_override("separation", 0)
    hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var coin := TextureRect.new()
    coin.texture = COIN_TEXTURE
    coin.custom_minimum_size = Vector2(coin_px, coin_px)
    coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.add_child(coin)

    var label := Label.new()
    label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_override("font", PRICE_FONT)
    label.add_theme_font_size_override("font_size", font_px)
    label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.01))
    label.add_theme_constant_override("outline_size", 5)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.add_child(label)

    return {"hbox": hbox, "label": label}



func _on_buy_dice_1_pressed() -> void:
    if Global.gold >= evil_dice_price:
        Events.dice_bought.emit("evil")
        SFXPlayer.play(load("res://sounds/buydicesound.wav"))
        AchievementManager.unlock("customer")
        AchievementManager.add_stat("dice_bought_from_shop", 1)
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
        AchievementManager.unlock("customer")
        AchievementManager.add_stat("dice_bought_from_shop", 1)
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
        AchievementManager.unlock("customer")
        AchievementManager.add_stat("dice_bought_from_shop", 1)
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
        AchievementManager.unlock("customer")
        AchievementManager.add_stat("dice_bought_from_shop", 1)
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
        AchievementManager.unlock("customer")
        AchievementManager.add_stat("dice_bought_from_shop", 1)
        Global.odd_dice_max_amount+=1
        Global.odd_dice_current_amount+=1
        if Global.odd_dice_current_amount == 1:
            Global.dice_inventory.append("odd")
        Events.update_dice_top_bar.emit()
        Global.purchased_dice_counts["odd"] += 1
        update_dice_price()
        
func update_dice_price() -> void:
    evil_dice_price  = Global.current_dice_price("evil")
    giant_dice_price = Global.current_dice_price("giant")
    magma_dice_price = Global.current_dice_price("magma")
    even_dice_price  = Global.current_dice_price("even")
    odd_dice_price   = Global.current_dice_price("odd")
    blue_dice_price  = Global.current_dice_price("blue")
    red_dice_price   = Global.current_dice_price("red")
    green_dice_price = Global.current_dice_price("green")
    mech_dice_price  = Global.current_dice_price("mech")


    # Index-aligned with dice_nodes / DICE_TYPE_ORDER (Dice1=evil ... Dice9=mech).
    var prices := [evil_dice_price, giant_dice_price, magma_dice_price, even_dice_price,
            odd_dice_price, blue_dice_price, red_dice_price, green_dice_price, mech_dice_price]
    for i in _dice_price_labels.size():
        var lbl := _dice_price_labels[i]
        lbl.text = str(prices[i])
        var affordable: bool = Global.gold >= prices[i]
        lbl.add_theme_color_override("font_color", Color("FFD700") if affordable else Color("FF4444"))

    if _reroll_price_label:
        var can_reroll: bool = Global.gold >= reroll_price
        _reroll_price_label.add_theme_color_override("font_color",
                Color("FFD700") if can_reroll else Color("FF4444"))

    get_cheapest_available_dice_price()

func _on_dice_price_changed():
    update_dice_price()


func _on_buy_dice_6_pressed() -> void:
    if Global.gold >= blue_dice_price:
        Global.gold-= blue_dice_price
        Events.gold_changed.emit()
        Events.dice_bought.emit("blue")
        SFXPlayer.play(load("res://sounds/buydicesound.wav"))
        AchievementManager.unlock("customer")
        AchievementManager.add_stat("dice_bought_from_shop", 1)
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
        AchievementManager.unlock("customer")
        AchievementManager.add_stat("dice_bought_from_shop", 1)
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
        AchievementManager.unlock("customer")
        AchievementManager.add_stat("dice_bought_from_shop", 1)
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
        AchievementManager.unlock("customer")
        AchievementManager.add_stat("dice_bought_from_shop", 1)
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

# Also called right before every spawn, which is the fix for the OTHER leak here (reported
# 2026-08-03: "hovering an even dice then leaving the shop leaves a permanent obstruction").
# All nine dice share this one `tooltip_instance_requirement` slot, and each
# _on_dice_N_mouse_entered() used to assign straight over it. Sliding the mouse along the
# dice row is enough: every handler waits 0.01s before spawning, and is_mouse_over_dice()
# tests the WHOLE shop rect rather than the individual die, so several pending handlers can
# all pass their check and spawn. Each new tooltip overwrote the reference to the previous
# one, which was then unreachable - mouse_exited and _exit_tree could only ever free the last
# one, so the earlier tooltips outlived the shop and floated over the map/fight underneath.
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

    _cleanup_dice_tooltips()
    tooltip_instance_requirement = TooltipScene.instantiate()
    Global.add_tooltip(tooltip_instance_requirement, self)
    var tooltip_panel = tooltip_instance_requirement.get_node("DiceTooltip")
    tooltip_panel.get_tooltip_content("evil")
    tooltip_panel.show_tooltip(dice_pos)

    # 🔴 Show bonus requirement tooltip (offset below)
    var need_additional_tooltip = false
    if need_additional_tooltip:
        tooltip_instance_bonus = TooltipScene.instantiate()
        Global.add_tooltip(tooltip_instance_bonus, self)
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

    _cleanup_dice_tooltips()
    tooltip_instance_requirement = TooltipScene.instantiate()
    Global.add_tooltip(tooltip_instance_requirement, self)
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

    _cleanup_dice_tooltips()
    tooltip_instance_requirement = TooltipScene.instantiate()
    Global.add_tooltip(tooltip_instance_requirement, self)
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

    _cleanup_dice_tooltips()
    tooltip_instance_requirement = TooltipScene.instantiate()
    Global.add_tooltip(tooltip_instance_requirement, self)
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

    _cleanup_dice_tooltips()
    tooltip_instance_requirement = TooltipScene.instantiate()
    Global.add_tooltip(tooltip_instance_requirement, self)
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

    _cleanup_dice_tooltips()
    tooltip_instance_requirement = TooltipScene.instantiate()
    Global.add_tooltip(tooltip_instance_requirement, self)
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

    _cleanup_dice_tooltips()
    tooltip_instance_requirement = TooltipScene.instantiate()
    Global.add_tooltip(tooltip_instance_requirement, self)
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

    _cleanup_dice_tooltips()
    tooltip_instance_requirement = TooltipScene.instantiate()
    Global.add_tooltip(tooltip_instance_requirement, self)
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

    _cleanup_dice_tooltips()
    tooltip_instance_requirement = TooltipScene.instantiate()
    Global.add_tooltip(tooltip_instance_requirement, self)
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

    # Save the selection in Global. The card shop's deal die must stay outside the 3
    # types shown here, so a reroll re-picks it too.
    Global.shop_dice_selection = chosen_indexes
    Global.shop_dice_deal_index = Global.pick_dice_deal_index()

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
