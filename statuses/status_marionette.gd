class_name MarionetteStatus
extends Status

const SCOUT2_CARD = preload("res://characters/warrior/cards/card_scout2.tres")

func apply_status(target: Node) -> void:
    Events.add_card_to_hand_requested.emit(SCOUT2_CARD)
    status_applied.emit(self)
