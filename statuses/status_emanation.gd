
extends Status

const MODIFIER := 0.5

func apply_status(target: Node) -> void:
        status_applied.emit(self)
