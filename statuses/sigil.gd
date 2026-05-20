class_name SigilStatus
extends Status

func initialize_status(_target: Node) -> void:
    stacks = randi_range(1, 6)

func apply_status(_target: Node) -> void:
    stacks = randi_range(1, 6)
    status_applied.emit(self)
