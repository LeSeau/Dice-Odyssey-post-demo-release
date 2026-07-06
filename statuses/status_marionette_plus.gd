class_name MarionettePlusStatus
extends Status

const SCOUT5_CARD = preload("res://characters/warrior/cards/card_scout5.tres")

func apply_status(target: Node) -> void:
    Events.add_card_to_hand_requested.emit(SCOUT5_CARD)
    status_applied.emit(self)
