class_name SteadyHandStatus
extends Status

func apply_status(_target: Node) -> void:
    Global.next_roll_modifier += 3
    Events.display_next_roll_modifier.emit()
    status_applied.emit(self)
