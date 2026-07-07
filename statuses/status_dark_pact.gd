class_name DarkPactStatus
extends Status

const MUSCLE_STATUS := preload("res://statuses/muscle.tres")
var target: Node

func initialize_status(_target: Node) -> void:
    target = _target
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled)

func apply_status(_target: Node) -> void:
    status_applied.emit(self)

func _on_dice_rolled(_dice_type, roll_value) -> void:
    if not is_instance_valid(target):
        return
    if int(roll_value) != 0:
        return
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = 2
    var status_effect := StatusEffect.new()
    status_effect.status = muscle
    status_effect.execute([target])
