class_name LuckySevensStatus
extends Status

const LUCKY_STATUS := preload("res://statuses/lucky.tres")
var target: Node

func initialize_status(_target: Node) -> void:
    target = _target
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled)

func apply_status(_target: Node) -> void:
    status_applied.emit(self)

func _on_dice_rolled(_dice_type, _roll_value) -> void:
    if not is_instance_valid(target):
        return
    var total = Global.fight_dice_rolled
    var lucky_to_add = total / 7
    var already_given = (total - 1) / 7
    if lucky_to_add > already_given:
        var lucky := LUCKY_STATUS.duplicate()
        lucky.duration = 1
        var status_effect := StatusEffect.new()
        status_effect.status = lucky
        status_effect.execute([target])
    stacks = total % 7
    status_changed.emit()
