extends Card

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if meets_requirement():
        var block_effect := BlockEffect.new()
        block_effect.amount = 18
        block_effect.sound = sound
        block_effect.execute(targets)
        Events.dice_roll_reset.emit()

        Events.card_type_played.emit("exact")
    Events.reset_charged_card.emit()


# Written as X12 rather than a flat 12 (Julien, 2026-08-20): the Power glyph is what
# teaches that Block comes from the bank. The Exact 1 gate pins X to 1, so the printed
# number never varies - which is exactly why there is nothing left to resolve here.
