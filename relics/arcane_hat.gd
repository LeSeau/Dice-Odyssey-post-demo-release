extends Relic

const ALL_DICE_TYPES := ["blue", "red", "green", "giant", "magma", "even", "odd", "mech", "evil"]

func initialize_relic(owner: RelicUI) -> void:
    Events.card_played.connect(_on_card_played.bind(owner))

func _on_card_played(card: Card, owner: RelicUI) -> void:
    if card.requirement != Card.Requirement.EXACT or not card.meets_requirement():
        return
    owner.flash()
    var chosen = ALL_DICE_TYPES[randi() % ALL_DICE_TYPES.size()]
    var dice_amount_variable = chosen + "_dice_current_amount"
    Global.set(dice_amount_variable, Global.get(dice_amount_variable) + 1)
    Events.dice_amount_changed.emit()
    Events.charge_dice_animation.emit()
    Events.temporary_dice_added.emit(chosen)

func deactivate_relic(owner: RelicUI) -> void:
    if Events.card_played.is_connected(_on_card_played):
        Events.card_played.disconnect(_on_card_played)
