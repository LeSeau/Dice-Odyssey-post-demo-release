extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    # power_generated_this_turn accumulates every roll of the whole turn (dice.gd
    # bumps it on each roll, resets it at turn start) - unlike roll_value it
    # survives spends and type switches, so this rewards total throughput, not
    # the current bank.
    var base_damage: int = Global.power_generated_this_turn
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()

func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage (all Power generated this turn). Exhaust"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.power_generated_this_turn, Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage (all Power generated this turn). Exhaust" % total
