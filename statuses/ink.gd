class_name InkStatus
extends Status

const MODIFIER := 0.5

# In weak.gd
func initialize_status(_target: Node) -> void:
    if not Events.check_ink_status.is_connected(consume_stack):
        Events.check_ink_status.connect(consume_stack)

func consume_stack() -> void:
    duration-=1
    if duration < 1:
        #Global.remove_ink_next_card = true
        Events.remove_ink_from_dice.emit()
        # The status_changed signal will trigger status_ui to update or remove itself
        status_changed.emit()

func apply_status(target: Node) -> void:
        status_applied.emit(self)
