extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    # cards_played_this_turn is bumped by Card.play() BEFORE apply_effects runs,
    # so it already includes this card - "each OTHER card" is count - 1.
    var base_damage := 3 + 3 * maxi(0, Global.cards_played_this_turn - 1)
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    # Preview from hand: the card hasn't been played yet, so the current counter
    # IS the number of other cards already played this turn.
    var total := apply_target_modifier(modifiers.get_modified_value(3 + 3 * Global.cards_played_this_turn, Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage (3, plus 3 for each other card played this turn)" % total
