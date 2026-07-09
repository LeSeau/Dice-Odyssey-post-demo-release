extends Control

@export var treasure_relic_pool: RelicPool
@export var relic_handler: RelicHandler
@export var char_stats: CharacterStats

var character_stats: CharacterStats
var run_stats: RunStats

const RELIC_COST := 55
const ALL_DICE_TYPES := ["blue", "red", "evil", "giant", "magma", "even", "odd", "green", "mech"]

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


# Left vault: free, reinforces a die type you already own (never grants a brand new
# type - that's what the Dice Forge/Crimson Eclipse events are for). Right vault:
# costs gold for a random relic. Two different REWARD categories to pick between,
# rather than a safe/risky version of the same reward.
func _on_left_vault_pressed() -> void:
    var owned: Array = ALL_DICE_TYPES.filter(func(t): return Global.get(t + "_dice_max_amount") > 0)
    if owned.is_empty():
        Events.event_exited.emit()
        return
    var target: String = owned.pick_random()
    Global.set(target + "_dice_max_amount", Global.get(target + "_dice_max_amount") + 1)
    Global.set(target + "_dice_current_amount", Global.get(target + "_dice_current_amount") + 1)
    Events.update_dice_top_bar.emit()
    Events.dice_price_changed.emit()
    Events.event_exited.emit()


func _on_right_vault_pressed() -> void:
    if Global.gold < RELIC_COST:
        return
    var relic := treasure_relic_pool.get_random_relic(char_stats, relic_handler)
    if not relic:
        return
    Global.gold -= RELIC_COST
    Events.gold_changed.emit()
    Events.show_reward_with_relic.emit(relic)
