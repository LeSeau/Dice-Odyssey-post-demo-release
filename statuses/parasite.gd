class_name ParasiteStatus
extends Status

const MUSCLE_STATUS := preload("res://statuses/muscle.tres")

# This threshold is the tuning dial for how greedy the player is allowed to be. It went
# 15 -> 18 when Oculus became a long-lived scaler (44 HP), on the theory that bigger turns
# would be needed to kill it and 18 would keep "slow and safe vs fast and punished" a real
# choice - but in play 18 sat above what a normal turn reaches, so the punish almost never
# fired and the decision evaporated the other way. Back to 15 (Julien, 2026-07-28).
# The status tooltip reads this constant directly (status_tooltip.gd), so it follows.
const PARASITE_THRESHOLD := 15
const PARASITE_STRENGTH := 2

var target: Node
var triggered_this_turn := false

func initialize_status(_target: Node) -> void:
    target = _target
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled)
    if not Events.player_turn_started.is_connected(_on_player_turn_started):
        Events.player_turn_started.connect(_on_player_turn_started)

func apply_status(_target: Node) -> void:
    status_applied.emit(self)

func _on_dice_rolled(_dice_type: String, _roll_value: int) -> void:
    if not is_instance_valid(target):
        return
    if triggered_this_turn:
        return
    if Global.power_generated_this_turn > PARASITE_THRESHOLD:
        triggered_this_turn = true
        var muscle := MUSCLE_STATUS.duplicate()
        muscle.stacks = PARASITE_STRENGTH
        var status_effect := StatusEffect.new()
        status_effect.status = muscle
        status_effect.execute([target])
        Events.enemy_strength_changed.emit()
        status_changed.emit()
    stacks = Global.power_generated_this_turn
    status_changed.emit()

func _on_player_turn_started() -> void:
    triggered_this_turn = false
    stacks = Global.power_generated_this_turn
    status_changed.emit()
