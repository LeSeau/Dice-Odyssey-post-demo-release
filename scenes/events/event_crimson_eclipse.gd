extends Control

var character_stats: CharacterStats
var run_stats: RunStats

# The eclipse's tribute is paid in permanent Max HP now (was 2 random relics). Relics
# cost near-nothing early-run when you own few/none, which made accepting a no-brainer
# every time; Max HP always bites, so the wager is a real decision at any point in the run.
const WAGER_MAX_HP_COST := 16
const DECLINE_HP_COST := 6

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


# Pay WAGER_MAX_HP_COST permanent Max HP for a guaranteed Evil Dice. Dice gained from
# events deliberately do NOT touch purchased_dice_counts, so this never escalates the
# dice-shop price (only gold purchases at the two shops do - see
# global.gd::current_dice_price). The Max HP write mirrors event_patient_monk.gd's
# pattern in reverse: Global.player_max_hp is kept in lockstep (the top bar reads it,
# not max_health directly).
func _on_accept_pressed() -> void:
    character_stats.max_health -= WAGER_MAX_HP_COST
    Global.player_max_hp -= WAGER_MAX_HP_COST
    # Re-clamp current health through its setter (clamps to the new, lower max and syncs
    # Global.player_hp). Max HP loss never kills on its own - current HP is separate.
    character_stats.health = mini(character_stats.health, character_stats.max_health)
    Events.hp_changed.emit()

    Global.evil_dice_max_amount += 1
    Global.evil_dice_current_amount += 1
    if Global.evil_dice_max_amount == 1:
        Global.dice_inventory.append("evil")
    Events.dice_bought.emit("evil")
    Events.update_dice_top_bar.emit()
    Events.dice_price_changed.emit()
    Events.event_exited.emit()


func _on_decline_pressed() -> void:
    character_stats.health -= DECLINE_HP_COST
    Events.hp_changed.emit()
    Events.event_exited.emit()
