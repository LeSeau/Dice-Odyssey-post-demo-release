extends Relic

const SCOUT2_CARD = preload("res://characters/warrior/cards/card_scout2.tres")

func initialize_relic(owner: RelicUI) -> void:
    Events.refuel_happened.connect(_on_refuel_happened.bind(owner))

func _on_refuel_happened(_amount, owner: RelicUI) -> void:
    owner.flash()
    # SCOUT2_CARD is a shared preloaded singleton - duplicate before handing it out so two
    # refuels in the same fight (this relic can trigger repeatedly) never emit the SAME Card
    # object into hand twice (two CardUI nodes sharing one instance_id causes both to resolve
    # as "the" socketed/played card at once).
    Events.add_card_to_hand_requested.emit(SCOUT2_CARD.duplicate())

func deactivate_relic(owner: RelicUI) -> void:
    if Events.refuel_happened.is_connected(_on_refuel_happened):
        Events.refuel_happened.disconnect(_on_refuel_happened)
