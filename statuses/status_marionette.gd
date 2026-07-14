class_name MarionetteStatus
extends Status

const SCOUT3_CARD = preload("res://characters/warrior/cards/card_scout3.tres")

func apply_status(target: Node) -> void:
    # SCOUT3_CARD is a shared preloaded singleton, and Marionette is designed to trigger
    # repeatedly - duplicate before handing it out so two triggers never emit the SAME Card
    # object into hand twice (two CardUI nodes sharing one instance_id causes both to resolve
    # as "the" socketed/played card at once).
    Events.add_card_to_hand_requested.emit(SCOUT3_CARD.duplicate())
    status_applied.emit(self)
