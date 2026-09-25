class_name MarionettePlusStatus
extends Status

const SCOUT5_CARD = preload("res://characters/warrior/cards/card_scout5.tres")

func apply_status(target: Node) -> void:
    # SCOUT5_CARD is a shared preloaded singleton, and Marionette+ is designed to trigger
    # repeatedly - duplicate before handing it out so two triggers never emit the SAME Card
    # object into hand twice (see status_marionette.gd for the full rationale).
    # One Scout card per Marionette+ played (stacks = copies, see absorb_copy).
    for _i in maxi(stacks, 1):
        Events.add_card_to_hand_requested.emit(SCOUT5_CARD.duplicate())
    status_applied.emit(self)


func absorb_copy(other: Status) -> bool:
    stacks += other.stacks
    return true


func get_tooltip() -> String:
    var count := maxi(stacks, 1)
    if count == 1:
        return tooltip
    return "At the start of each turn, gain %d Scout 5 cards" % count
