class_name WeakStatus
extends Status

const MODIFIER := 0.5

# In weak.gd
func initialize_status(_target: Node) -> void:
    if not Events.weak_effect_consumed.is_connected(consume_stack):
        Events.weak_effect_consumed.connect(consume_stack)

func consume_stack() -> void:
    if stacks > 0:
        Global.next_roll_modifier -= stacks
        stacks = 0

    # The status_changed signal will trigger status_ui to update or remove itself
    status_changed.emit()

func apply_status(target: Node) -> void:
        status_applied.emit(self)
