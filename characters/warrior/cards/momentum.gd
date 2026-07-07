extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    # cards_played_this_turn is bumped by Card.play() BEFORE apply_effects runs,
    # so it already includes this card - "each OTHER card" is count - 1.
    var base_damage := 4 + 4 * maxi(0, Global.cards_played_this_turn - 1)
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func get_dynamic_description(modifiers: ModifierHandler) -> String:
    # Preview from hand: the card hasn't been played yet, so the current counter
    # IS the number of other cards already played this turn.
    var total := modifiers.get_modified_value(4 + 4 * Global.cards_played_this_turn, Modifier.Type.DMG_DEALT)
    return "Deal %d damage (4, plus 4 for each other card played this turn)" % total
