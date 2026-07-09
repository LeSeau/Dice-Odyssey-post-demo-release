extends Control

var character_stats: CharacterStats
var run_stats: RunStats

const FORGE_COST := 35
const EXOTIC_TYPES := ["evil", "giant", "magma", "even", "odd", "green", "mech"]

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


# Prefers a type not yet owned (a real "found something new" moment) - falls back
# to an extra copy of a random exotic type already owned once every type is unlocked,
# so the event never whiffs into nothing late-run. Mirrors shop.gd's exact purchase
# bookkeeping (max+current+inventory+purchased_dice_counts) so a later shop rebuy
# of this same type still escalates in price correctly.
func _on_forge_pressed() -> void:
    if Global.gold < FORGE_COST:
        return
    Global.gold -= FORGE_COST
    Events.gold_changed.emit()

    var unowned: Array = EXOTIC_TYPES.filter(func(t): return Global.get(t + "_dice_max_amount") == 0)
    var target: String = unowned.pick_random() if not unowned.is_empty() else EXOTIC_TYPES.pick_random()

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


func _on_leave_pressed() -> void:
    Events.event_exited.emit()
