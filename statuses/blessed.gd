class_name BlessedStatus
extends Status

const MODIFIER := 0.5

# In weak.gd
func initialize_status(_target: Node) -> void:
    if not Events.check_blessed_status.is_connected(consume_stack):
        Events.check_blessed_status.connect(consume_stack)

func consume_stack() -> void:
    if duration > 0:
        print("consuming stack")
        Global.next_roll_modifier +=2
        # The status_changed signal will trigger status_ui to update or remove itself
        status_changed.emit()

func apply_status(target: Node) -> void:
        status_applied.emit(self)
