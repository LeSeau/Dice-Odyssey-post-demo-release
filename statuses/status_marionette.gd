class_name MarionetteStatus
extends Status

const SCOUT3_CARD = preload("res://characters/warrior/cards/card_scout3.tres")

func apply_status(target: Node) -> void:
    # SCOUT3_CARD is a shared preloaded singleton, and Marionette is designed to trigger
    # repeatedly - duplicate before handing it out so two triggers never emit the SAME Card
    # object into hand twice (two CardUI nodes sharing one instance_id causes both to resolve
    # as "the" socketed/played card at once).
    # One Scout card per Marionette played (stacks = copies, see absorb_copy).
    for _i in maxi(stacks, 1):
        Events.add_card_to_hand_requested.emit(SCOUT3_CARD.duplicate())
    status_applied.emit(self)


func absorb_copy(other: Status) -> bool:
    stacks += other.stacks
    return true


func get_tooltip() -> String:
    var count := maxi(stacks, 1)
    if count == 1:
        return tooltip
    return "At the start of each turn, gain %d Scout 3 cards" % count
