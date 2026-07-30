class_name TrueStrengthStatus
extends Status

const MUSCLE_STATUS := preload("res://statuses/muscle.tres")

# const, not a var, so the status tooltip can read the real number off the class instead of
# retyping it (status_tooltip.gd). Nothing ever assigned this from outside.
const STRENGTH_PER_TURN := 2


func apply_status(target: Node) -> void:
    print("applied true strength form")
    
    var status_effect := StatusEffect.new()
    var muscle := MUSCLE_STATUS.duplicate()
    muscle.stacks = STRENGTH_PER_TURN
    status_effect.status = muscle
    status_effect.execute([target])
    
    status_applied.emit(self)
