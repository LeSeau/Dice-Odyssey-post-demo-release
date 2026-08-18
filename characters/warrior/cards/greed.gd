extends Card

# "Exact 7: deal 7 damage, gain 7 Block, gain 7 Gold. Exhaust."
# The casino soul of the game in one card, and it gives Exact 7 a family alongside Corrode.
# Refinement (round Power up to the next multiple of 7) is its stealth tutor.
# Mid-fight gold has precedent: Blackjack+ already pays out.

const AMOUNT := 7


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    Events.reset_charged_card.emit()
    if not targets.is_empty():
        var damage_effect := DamageEffect.new()
        damage_effect.amount = modifiers.get_modified_value(AMOUNT, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)
    Events.add_block.emit(AMOUNT)
    Global.gold += AMOUNT
    Events.gold_changed.emit()
    Events.dice_roll_reset.emit()
