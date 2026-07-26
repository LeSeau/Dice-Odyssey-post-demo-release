class_name ParasiteStatus
extends Status

const MUSCLE_STATUS := preload("res://statuses/muscle.tres")

# Oculus is now a long-lived scaler (44 HP), so it needs BIGGER turns to kill - which means
# a 15 threshold would fire almost every turn even for careful play and delete the choice.
# 18 keeps "go slow and safe vs fast and punished" an actual decision. This threshold is the
# tuning dial for how greedy the player is allowed to be.
const PARASITE_THRESHOLD := 18
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
