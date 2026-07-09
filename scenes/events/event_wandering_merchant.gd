extends Control

var character_stats: CharacterStats
var run_stats: RunStats

const BROWSE_COST := 25
const TIP_GOLD := 15

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


# Paying just buys the LOOK (2 cards to choose from via the normal reward screen),
# not a guaranteed great pull - same "pay for the opportunity" principle as the
# Whetstone Shrine. Events.show_reward replaces the current view on its own, so no
# separate event_exited is needed on this path.
func _on_browse_pressed() -> void:
    if Global.gold < BROWSE_COST:
        return
    Global.gold -= BROWSE_COST
    Events.gold_changed.emit()
    Global.pending_card_rewards = 2
    Events.show_reward.emit()


func _on_decline_pressed() -> void:
    Global.gold += TIP_GOLD
    Events.gold_changed.emit()
    Events.event_exited.emit()
