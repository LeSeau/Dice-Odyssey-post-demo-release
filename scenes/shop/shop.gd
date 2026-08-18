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
# The "all three are different" half of this is the whole reason to spend the 20 gold, so it
# is stated outright: before 2026-08-13 a reroll drew from all 9 types and could legitimately
# hand back dice that were already on display, which read as the button not working.
const REROLL_TOOLTIP_TEXT := "Offers three new Dice. All three are guaranteed to be different types from the ones shown now."
var _reroll_tooltip: Node = null

# Soft accent-tinted halo + rising motes behind each die (2026-08-13, Julien: "a small glow
# like on dice infusion") - the infused-style presentation the card shop's deal die already
# has, via the now-shared DicePalette.glow_texture()/additive_material() recipe. Halo sits
# BEHIND the die art (show_behind_parent), so it only ever reads as rim light.
# The die art is opaque and covers the halo's center, so only the ring past the die edge is
# ever visible - the halo must be a good deal larger than the 200px die for that ring to
# clear the ~10%-luminosity visibility floor. Shaped die_halo_texture (rounded square, not
# the radial circle - Julien's call) is much brighter at the die edge than the old radial
# tail was, hence the lower alphas.
const GLOW_SIZE := 320.0
const GLOW_ALPHA_LOW := 0.32
const GLOW_ALPHA_HIGH := 0.5
# One shared timer cycles the 3 visible dice, so this is the SHOP-WIDE rate: divide by 3
# for the per-die rate (~0.78s), unlike the infusion/deal-die timers which are per-die.
# Bumped from 0.42 on Julien's "slightly increase mote intensity/frequency" pass.
const MOTE_INTERVAL := 0.26
var _dice_columns: Array = []
var _mote_cursor := 0
# {node, phase, period} per halo, driven by _process. Phases are golden-ratio-spaced by
# column index; the random offset just rotates the whole pattern per shop visit.
var _glow_pulses: Array = []
var _glow_time := 0.0
var _glow_phase_offset := randf()



func _ready():
    Events.dice_price_changed.connect(_on_dice_price_changed)
    var dice_nodes = [dice_1, dice_2, dice_3, dice_4, dice_5, dice_6, dice_7, dice_8, dice_9]
    _dice_columns = dice_nodes

    # Accent halo behind every die + one shared mote timer. All 9 are set up (hidden columns
    # hide their glow with them), so a reroll swaps which glows show for free.
    for i in dice_nodes.size():
        _setup_dice_glow(i)
    var mote_timer := Timer.new()
    mote_timer.wait_time = MOTE_INTERVAL
    mote_timer.autostart = true
    mote_timer.timeout.connect(_spawn_shop_mote)
    add_child(mote_timer)
    
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
    # Wired here rather than in the .tscn simply because the button is already resolved
    # above; the label/coin row inside it are mouse-transparent, so these still fire.
    reroll_btn.mouse_entered.connect(_on_reroll_button_mouse_entered)
    reroll_btn.mouse_exited.connect(_on_reroll_button_mouse_exited)

    update_dice_price()

func _on_button_pressed() -> void:
    Events.dice_shop_closed.emit()


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
        if not Global.dice_inventory.has("evil"):
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
        if not Global.dice_inventory.has("giant"):
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
        if not Global.dice_inventory.has("magma"):
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
        if not Global.dice_inventory.has("even"):
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
        if not Global.dice_inventory.has("odd"):
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
        if not Global.dice_inventory.has("blue"):
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
        if not Global.dice_inventory.has("red"):
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
        if not Global.dice_inventory.has("green"):
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
        if not Global.dice_inventory.has("mech"):
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
    _hide_reroll_tooltip()

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
    Events.dice_shop_closed.emit()


func reroll_shop_dice() -> void:
    var dice_nodes = [dice_1, dice_2, dice_3, dice_4, dice_5, dice_6, dice_7, dice_8, dice_9]

    # Hide all dice first
    for dice in dice_nodes:
        dice.hide()

    # A reroll replaces the offer WHOLESALE: draw only from the types that aren't on display
    # (6 of the 9 remain, so 3 can always be drawn). The old version drew from all 9 and could
    # return dice that were already there - paying for an offer that partly didn't change reads
    # as a broken button, and it made the reroll price impossible to judge. Buying a die leaves
    # it on display, so shop_dice_selection is always the 3 currently-shown types.
    var previously_shown: Array = Global.shop_dice_selection
    var candidates := []
    for index in existing_dices:
        if not previously_shown.has(index):
            candidates.append(index)
    candidates.shuffle()
    # Only reachable if the stored selection is ever bigger than it should be - falling back to
    # the shown types beats handing the rest of the function fewer than 3 dice.
    while candidates.size() < 3:
        candidates.append(randi() % existing_dices)
    var chosen_indexes := candidates.slice(0, 3)

    # Save the selection in Global. The card shop's deal die must stay outside the 3
    # types shown here, so a reroll re-picks it too.
    Global.shop_dice_selection = chosen_indexes
    Global.shop_dice_deal_index = Global.pick_dice_deal_index()

    # Show the new dice
    for index in chosen_indexes:
        dice_nodes[index].show()

    # Refreshes the affordable/unaffordable price colours (gold just went down by the reroll
    # cost) and re-derives Global.cheapest_dice_price, which is keyed off the SELECTION and so
    # was left describing the previous offer - that value drives the map's "you can afford a
    # Dice" badge.
    update_dice_price()


func _setup_dice_glow(column_index: int) -> void:
    var die_texture: TextureRect = _dice_columns[column_index].get_node(
            "Dice%dTexture" % (column_index + 1))
    var accent: Color = DicePalette.accent(Global.DICE_TYPE_ORDER[column_index])
    var glow := TextureRect.new()
    glow.texture = DicePalette.die_halo_texture()
    glow.material = DicePalette.additive_material()
    glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    glow.stretch_mode = TextureRect.STRETCH_SCALE
    glow.show_behind_parent = true
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glow.size = Vector2(GLOW_SIZE, GLOW_SIZE)
    glow.position = (die_texture.custom_minimum_size - glow.size) / 2.0
    glow.pivot_offset = glow.size / 2.0
    glow.modulate = Color(accent.r, accent.g, accent.b, GLOW_ALPHA_LOW)
    die_texture.add_child(glow)

    # Deterministic phase spread (Julien: the three glows read as breathing in lockstep).
    # A random 0-1.4s lead-in tween was tried first and failed structurally: uniform draws
    # can cluster, and during the lead-in every halo idles at the same LOW value, so the
    # first cycle - most of a shop visit - still looked synchronized. Golden-ratio spacing
    # by column index puts ANY 3 visible columns at well-separated points of the cycle from
    # the very first frame, and the per-die period keeps them drifting apart after that.
    var phase := fmod(column_index * 0.618 + _glow_phase_offset, 1.0) * TAU
    _glow_pulses.append({"node": glow, "phase": phase, "period": randf_range(2.7, 3.4)})


# Sine-driven breathing for all 9 halos (hidden columns cost nothing visible). _process
# instead of looping tweens so each halo can START mid-cycle at its assigned phase - a
# Tween loop always begins at a leg boundary, which is exactly the synchronization problem.
func _process(delta: float) -> void:
    _glow_time += delta
    for entry in _glow_pulses:
        var glow: TextureRect = entry["node"]
        var wave: float = 0.5 + 0.5 * sin(TAU * _glow_time / entry["period"] + entry["phase"])
        glow.modulate.a = lerpf(GLOW_ALPHA_LOW, GLOW_ALPHA_HIGH, wave)
        var glow_scale: float = lerpf(0.96, 1.06, wave)
        glow.scale = Vector2(glow_scale, glow_scale)


# Accent mote drifting up across the die face, dice-infusion recipe. Reads the CURRENT
# selection every tick, so a reroll redirects the motes to the new dice automatically.
func _spawn_shop_mote() -> void:
    var shown: Array = Global.shop_dice_selection
    if shown.is_empty():
        return
    _mote_cursor = (_mote_cursor + 1) % shown.size()
    var column_index: int = shown[_mote_cursor]
    var die_texture: TextureRect = _dice_columns[column_index].get_node(
            "Dice%dTexture" % (column_index + 1))
    var accent: Color = DicePalette.accent(Global.DICE_TYPE_ORDER[column_index])
    var box: Vector2 = die_texture.custom_minimum_size

    var mote := TextureRect.new()
    mote.texture = DicePalette.glow_texture()
    mote.material = DicePalette.additive_material()
    mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mote.stretch_mode = TextureRect.STRETCH_SCALE
    var mote_size := randf_range(11.0, 22.0)
    mote.size = Vector2(mote_size, mote_size)
    mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mote.modulate = Color(accent.r, accent.g, accent.b, 0.0)
    mote.position = Vector2(
        randf_range(12.0, box.x - 12.0 - mote_size),
        box.y - randf_range(5.0, 40.0)
    )
    die_texture.add_child(mote)

    var rise := randf_range(70.0, 115.0)
    var duration := randf_range(1.1, 1.6)
    var peak_alpha := randf_range(0.38, 0.62)
    var t := create_tween()
    t.set_parallel(true)
    t.tween_property(mote, "position:y", mote.position.y - rise, duration) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    t.tween_property(mote, "position:x", mote.position.x + randf_range(-16.0, 16.0), duration)
    t.tween_property(mote, "modulate:a", peak_alpha, duration * 0.3)
    t.tween_property(mote, "modulate:a", 0.0, duration * 0.45).set_delay(duration * 0.55)
    t.chain().tween_callback(mote.queue_free)


func _on_reroll_button_mouse_entered() -> void:
    _hide_reroll_tooltip()
    _reroll_tooltip = IconTooltip.spawn_body_below($RerollButton, REROLL_TOOLTIP_TEXT)


func _on_reroll_button_mouse_exited() -> void:
    _hide_reroll_tooltip()


func _hide_reroll_tooltip() -> void:
    if is_instance_valid(_reroll_tooltip):
        _reroll_tooltip.queue_free()
    _reroll_tooltip = null


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
