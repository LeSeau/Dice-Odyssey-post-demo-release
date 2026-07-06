class_name SteadyHandPlusStatus
extends Status

func apply_status(_target: Node) -> void:
    Global.next_roll_modifier += 5
    Events.display_next_roll_modifier.emit()
    status_applied.emit(self)
