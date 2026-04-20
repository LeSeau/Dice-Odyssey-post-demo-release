class_name CanalizeStatus
extends Status

const MUSCLE_STATUS := preload("res://statuses/muscle.tres")

var stacks_per_turn := 2
var target: Node

func initialize_status(_target: Node) -> void:
    if not Events.check_canalize_status.is_connected(consume_stack):
        Events.check_canalize_status.connect(consume_stack)
    target = _target


func apply_status(target: Node) -> void:
    if Global.roll_value >= 10:
        var status_effect := StatusEffect.new()
        var muscle := MUSCLE_STATUS.duplicate()
        muscle.stacks = 3
        status_effect.status = muscle
        status_effect.execute([target])
        print("consuming stack of canalize!")

    
    status_applied.emit(self)

func consume_stack() -> void:
    if target:  # Safety check
        if Global.roll_value > 8:
            var status_effect := StatusEffect.new()
            var muscle := MUSCLE_STATUS.duplicate()
            muscle.stacks = 3
            status_effect.status = muscle
            status_effect.execute([target])  # ← Now it knows who to affect!
            print("consuming stack of canalize!")
            status_applied.emit(self)
            status_changed.emit()
            Events.enemy_strength_changed.emit()
    
