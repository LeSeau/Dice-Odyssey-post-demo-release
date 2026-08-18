extends Control

@export var relic_handler: RelicHandler
@export var char_stats: CharacterStats

var character_stats: CharacterStats
var run_stats: RunStats

const CALM_GOLD_COST := 30
const IGNORE_HP_COST := 6
# Anything but Blue or Red - the idol wants something new to "feel", not more
# of what it already knows.
const REWARD_TYPES := ["evil", "giant", "magma", "even", "odd", "green", "mech"]

@onready var feed_button: Button = $TextureRect/MarginContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer/FeedButton

# The idol is FED a Red Dice, and since the run-start loadout picker a run can own zero Red
# (The Elf, and any Red traded away here already). The pool gate
# (EventStats.required_dice_type = "red") keeps this event out of the draw in that case;
# hiding the button here is the second layer, for when it is reached some other way.
func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats
    feed_button.visible = Global.red_dice_max_amount >= 1


# Dice GAINED FROM EVENTS deliberately do NOT touch purchased_dice_counts, so they
# don't escalate the dice-shop price (only gold purchases at the two shops do - see
# global.gd::current_dice_price). This is a swap (red -> random), net-zero pool size,
# so taxing the whole dice market off it made no sense. Everything else matches the
# shop's bookkeeping (max+current+inventory+dice_bought for the top bar).
func _on_feed_pressed() -> void:
    if Global.red_dice_max_amount < 1:
        return
    Global.red_dice_max_amount -= 1
    Global.red_dice_current_amount = maxi(0, Global.red_dice_current_amount - 1)
    # Giving up your LAST Red drops it out of the owned-types list too, so the inventory
    # keeps matching the dice you actually have (it is saved with the run, and the card
    # shop's deal die reads it).
    if Global.red_dice_max_amount == 0:
        Global.dice_inventory.erase("red")

    var target: String = REWARD_TYPES.pick_random()
    var new_max: int = Global.get(target + "_dice_max_amount") + 1
    Global.set(target + "_dice_max_amount", new_max)
    Global.set(target + "_dice_current_amount", Global.get(target + "_dice_current_amount") + 1)
    if not Global.dice_inventory.has(target):
        Global.dice_inventory.append(target)
    Events.dice_bought.emit(target)
    Events.update_dice_top_bar.emit()
    Events.dice_price_changed.emit()
    Events.event_exited.emit()


func _on_calm_pressed() -> void:
    if Global.gold < CALM_GOLD_COST:
        return
    Global.gold -= CALM_GOLD_COST
    Events.gold_changed.emit()
    Events.event_exited.emit()


func _on_ignore_pressed() -> void:
    character_stats.health -= IGNORE_HP_COST
    Events.hp_changed.emit()
    Events.event_exited.emit()
