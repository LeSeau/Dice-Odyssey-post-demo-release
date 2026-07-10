extends Control

var character_stats: CharacterStats
var run_stats: RunStats

const BROWSE_COST := 25
const SELL_GOLD := 50

func setup(character: CharacterStats, stats: RunStats) -> void:
    character_stats = character
    run_stats = stats


# Paying buys the LOOK (1 round of 3 cards to choose from via the normal reward
# screen), pre-upgraded via Global.force_upgraded_card_rewards (consumed one-shot by
# battle_reward.gd::_show_card_rewards) - not a guaranteed great pull, same "pay for
# the opportunity" principle as the Whetstone Shrine. Events.show_reward replaces the
# current view on its own, so no separate event_exited is needed on this path.
func _on_browse_pressed() -> void:
    if Global.gold < BROWSE_COST:
        return
    Global.gold -= BROWSE_COST
    Events.gold_changed.emit()
    Global.force_upgraded_card_rewards = true
    Global.pending_card_rewards = 1
    Events.show_reward.emit()


func _on_decline_pressed() -> void:
    Global.gold += SELL_GOLD
    Events.gold_changed.emit()
    Events.event_exited.emit()
