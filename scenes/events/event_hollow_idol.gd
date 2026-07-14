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

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats
    feed_button.visible = Global.red_dice_max_amount >= 1


# Same bookkeeping as event_dice_forge.gd/event_crimson_eclipse.gd's dice grants
# (max+current+inventory+purchased_dice_counts) so a later shop rebuy of this
# type still escalates in price correctly.
func _on_feed_pressed() -> void:
    if Global.red_dice_max_amount < 1:
        return
    Global.red_dice_max_amount -= 1
    Global.red_dice_current_amount = maxi(0, Global.red_dice_current_amount - 1)

    var target: String = REWARD_TYPES.pick_random()
    var new_max: int = Global.get(target + "_dice_max_amount") + 1
    Global.set(target + "_dice_max_amount", new_max)
    Global.set(target + "_dice_current_amount", Global.get(target + "_dice_current_amount") + 1)
    if new_max == 1:
        Global.dice_inventory.append(target)
    Global.purchased_dice_counts[target] += 1
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
