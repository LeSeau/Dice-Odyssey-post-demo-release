class_name GreedyStatus
extends Status

const MUSCLE_STATUS := preload("res://statuses/muscle.tres")

var target: Node

func initialize_status(_target: Node) -> void:
    target = _target
    if not Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.connect(_on_dice_rolled)

func apply_status(_target: Node) -> void:
    status_applied.emit(self)

func _on_dice_rolled(_dice_type: String, _roll_value: int) -> void:
    if not is_instance_valid(target):
        return

    var total = Global.fight_dice_rolled
    var strength_to_add = total / 6
    var already_given = (total - 1) / 6

    if strength_to_add > already_given:
        var muscle := MUSCLE_STATUS.duplicate()
        muscle.stacks = 1
        var status_effect := StatusEffect.new()
        status_effect.status = muscle
        status_effect.execute([target])
        Events.enemy_strength_changed.emit()
        print("Greedy: gained 1 Strength at fight roll #", total)

    # Update stacks to show progress toward next threshold: e.g. 4/6 shows as 4
    stacks = total % 6
    status_changed.emit()
