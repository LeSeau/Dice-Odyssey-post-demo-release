class_name ParasiteStatus
extends Status

const MUSCLE_STATUS := preload("res://statuses/muscle.tres")

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
    if Global.power_generated_this_turn > 15:
        triggered_this_turn = true
        var muscle := MUSCLE_STATUS.duplicate()
        muscle.stacks = 3
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
