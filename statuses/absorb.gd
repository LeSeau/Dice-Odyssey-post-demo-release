class_name AbsorbStatus
extends Status

const MUSCLE_STATUS := preload("res://statuses/muscle.tres")

var stacks_per_turn := 2


func apply_status(target: Node) -> void:
    if Global.fight_turn != 1:
        var status_effect := StatusEffect.new()
        var muscle := MUSCLE_STATUS.duplicate()
        muscle.stacks = Global.last_roll
        status_effect.status = muscle
        status_effect.execute([target])

    
    status_applied.emit(self)
