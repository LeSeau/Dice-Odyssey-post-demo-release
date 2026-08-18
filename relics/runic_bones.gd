class_name RunicBones
extends Relic

func initialize_relic(owner: RelicUI) -> void:
    Events.dice_charged.connect(_on_charge_dice.bind(owner))

func _on_charge_dice(_dice_type: String, _count: int, owner: RelicUI) -> void:
    if Global.charged_dice_this_turn:
        return
    Global.charged_dice_this_turn = true
    owner.flash()
    # Draws instead of granting Block (Julien, 2026-08-16). Card draw is the thinnest
    # ladder in the pool - four cards in eighty - and Block is the fattest, so the relic
    # pays into the scarce resource now. Deliberately replaces the 4 Block, not additive.
    Events.draw_card.emit(2)

func deactivate_relic(owner: RelicUI) -> void:
    if Events.dice_charged.is_connected(_on_charge_dice):
        Events.dice_charged.disconnect(_on_charge_dice)
