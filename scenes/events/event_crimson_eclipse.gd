extends Control

var character_stats: CharacterStats
var run_stats: RunStats

const WAGER_COST := 50

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


func _on_accept_pressed() -> void:
    if Global.gold < WAGER_COST:
        return
    Global.gold -= WAGER_COST
    Events.gold_changed.emit()
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
    Events.event_exited.emit()
