extends Relic

# Wayfinder Compass' defensive twin, on the same trigger: paid for abandoning a bank. Where
# the Compass pushes you back toward offence on the new type, this one banks the loss as
# armour - the pick between them is whether your deck wants tempo or survival.

const BLOCK_AMOUNT := 3

var triggered_this_turn := false


func initialize_relic(owner: RelicUI) -> void:
    triggered_this_turn = false
    Events.active_dice_changed.connect(_on_active_dice_changed.bind(owner))
    Events.player_turn_started.connect(_on_player_turn_started)


func _on_active_dice_changed(_active_dice, owner: RelicUI) -> void:
    # See wayfinder_compass.gd for why this reads power_at_last_switch and not roll_value.
    if triggered_this_turn or Global.power_at_last_switch <= 0:
        return
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    if player == null:
        return
    triggered_this_turn = true
    owner.flash()
    var block_effect := BlockEffect.new()
    block_effect.amount = BLOCK_AMOUNT
    block_effect.execute([player])


func _on_player_turn_started() -> void:
    triggered_this_turn = false


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.active_dice_changed.is_connected(_on_active_dice_changed):
        Events.active_dice_changed.disconnect(_on_active_dice_changed)
    if Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.disconnect(_on_player_turn_started)
