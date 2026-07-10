extends Control

@export var relic_handler: RelicHandler

var character_stats: CharacterStats
var run_stats: RunStats

const WAGER_RELIC_COST := 2
const DECLINE_HP_COST := 6

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


# Costs 2 random relics instead of gold - loses however many you actually own if
# you have fewer than 2 (including zero, a rare free roll early-run).
func _on_accept_pressed() -> void:
    var relic_uis := relic_handler._get_all_relic_ui_nodes()
    relic_uis.shuffle()
    for i in mini(WAGER_RELIC_COST, relic_uis.size()):
        relic_uis[i].queue_free()
    Global.evil_dice_max_amount += 1
    Global.evil_dice_current_amount += 1
    if Global.evil_dice_max_amount == 1:
        Global.dice_inventory.append("evil")
    Global.purchased_dice_counts["evil"] += 1
    Events.dice_bought.emit("evil")
    Events.update_dice_top_bar.emit()
    Events.dice_price_changed.emit()
    Events.event_exited.emit()


func _on_decline_pressed() -> void:
    character_stats.health -= DECLINE_HP_COST
    Events.hp_changed.emit()
    Events.event_exited.emit()
