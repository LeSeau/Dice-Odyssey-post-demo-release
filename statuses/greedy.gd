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
        # 2 per threshold (was 1) - paired with lowering Gargantua's base hits 11->8:
        # softer opening turns, but he outscales his old flat damage within a few turns
        # if the fight drags (Julien, 2026-07-16).
        var muscle := MUSCLE_STATUS.duplicate()
        muscle.stacks = 2
        var status_effect := StatusEffect.new()
        status_effect.status = muscle
        status_effect.execute([target])
        Events.enemy_strength_changed.emit()

    # Update stacks to show progress toward next threshold: e.g. 4/6 shows as 4
    stacks = total % 6
    status_changed.emit()
