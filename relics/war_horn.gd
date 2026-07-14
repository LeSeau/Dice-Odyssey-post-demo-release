extends Relic

const SCOUT3_CARD = preload("res://characters/warrior/cards/card_scout3.tres")

func activate_relic(owner: RelicUI) -> void:
    owner.flash()
    # SCOUT3_CARD is a shared preloaded singleton (the same cached object other
    # scripts preload from the same path, e.g. status_marionette.gd) - duplicate before
    # handing it out so it never ends up as the SAME Card object as one already in hand.
    Events.add_card_to_hand_requested.emit(SCOUT3_CARD.duplicate())

