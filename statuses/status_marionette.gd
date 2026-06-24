class_name MarionetteStatus
extends Status

const SCOUT3_CARD = preload("res://characters/warrior/cards/card_scout3.tres")

func apply_status(target: Node) -> void:
    Events.add_card_to_hand_requested.emit(SCOUT3_CARD)
    status_applied.emit(self)
