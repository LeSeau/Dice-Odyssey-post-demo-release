extends Relic

const MUSCLE_STATUS = preload("res://statuses/muscle.tres")

# Once per TURN (2026-07-28 retune): the old version re-armed whenever power dropped below 5,
# i.e. every bank cycle - at mid-game that was +2 permanent Strength per turn, sometimes twice
# a turn, silently the strongest relic in the pool. Now mirrors Spyglass' triggered_this_turn.
var triggered_this_turn := false


func initialize_relic(owner: RelicUI) -> void:
    triggered_this_turn = false
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))
    Events.change_current_power.connect(_on_change_current_power.bind(owner))
    Events.player_turn_started.connect(_on_player_turn_started)


func _on_dice_rolled(_dice_type: String, _roll_value: int, owner: RelicUI) -> void:
    _try_trigger(owner)


func _on_change_current_power(owner: RelicUI) -> void:
    _try_trigger(owner)


func _try_trigger(owner: RelicUI) -> void:
    if triggered_this_turn or Global.roll_value <= 10:
        return
    triggered_this_turn = true
    owner.flash()
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = 2
    status_effect.status = muscle
    var player := owner.get_tree().get_first_node_in_group("player") as Player
    if player:
        status_effect.execute([player])


func _on_player_turn_started() -> void:
    triggered_this_turn = false


func deactivate_relic(_owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
    if Events.change_current_power.is_connected(_on_change_current_power):
        Events.change_current_power.disconnect(_on_change_current_power)
    if Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.disconnect(_on_player_turn_started)
