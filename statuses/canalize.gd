class_name CanalizeStatus
extends Status
const MUSCLE_STATUS := preload("res://statuses/muscle.tres")
var stacks_per_turn := 2
var target: Node
var threshold_triggered := false

func initialize_status(_target: Node) -> void:
    if not Events.check_canalize_status.is_connected(consume_stack):
        Events.check_canalize_status.connect(consume_stack)
    if not Events.change_current_power.is_connected(consume_stack):
        Events.change_current_power.connect(consume_stack)
    target = _target

func apply_status(target: Node) -> void:
    status_applied.emit(self)

func consume_stack() -> void:
    if target:
        if Global.roll_value > 9 and not threshold_triggered:
            threshold_triggered = true
            var status_effect := StatusEffect.new()
            var muscle := MUSCLE_STATUS.duplicate()
            muscle.stacks = 2
            status_effect.status = muscle
            status_effect.execute([target])
            print("consuming stack of canalize!")
            status_applied.emit(self)
            status_changed.emit()
            Events.enemy_strength_changed.emit()
        elif Global.roll_value <= 9:
            threshold_triggered = false
