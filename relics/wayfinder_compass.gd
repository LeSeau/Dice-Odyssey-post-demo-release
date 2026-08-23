extends Relic

# Switching dice type costs you the bank you had built. This pays part of it back - but only
# when you actually SACRIFICED something (Julien, 2026-08-23): gating on "with Power left"
# is what stops it being farmed by tapping between types at 0 Power on a dead turn.
#
# Global.power_at_last_switch is captured by dice_interface immediately BEFORE it emits
# active_dice_changed. Reading Global.roll_value from in here instead would be a race - the
# handler that zeroes the bank listens to the same signal, and signal order is connection
# order, which relics have no control over.

const ROLL_BONUS := 2

var triggered_this_turn := false


func initialize_relic(owner: RelicUI) -> void:
    triggered_this_turn = false
    Events.active_dice_changed.connect(_on_active_dice_changed.bind(owner))
    Events.player_turn_started.connect(_on_player_turn_started)


func _on_active_dice_changed(_active_dice, owner: RelicUI) -> void:
    if triggered_this_turn or Global.power_at_last_switch <= 0:
        return
    triggered_this_turn = true
    owner.flash()
    Global.next_roll_modifier += ROLL_BONUS
    # Same pair every Boost card uses (dynamite.gd et al): bump the Global, then tell the
    # dice panel to show the pending bonus.
    Events.display_next_roll_modifier.emit()


func _on_player_turn_started() -> void:
    triggered_this_turn = false


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.active_dice_changed.is_connected(_on_active_dice_changed):
        Events.active_dice_changed.disconnect(_on_active_dice_changed)
    if Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.disconnect(_on_player_turn_started)
