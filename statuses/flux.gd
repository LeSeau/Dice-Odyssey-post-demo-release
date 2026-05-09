class_name FluxStatus
extends Status

func initialize_status(_target: Node) -> void:
    pass

func apply_status(_target: Node) -> void:
    status_applied.emit(self)
