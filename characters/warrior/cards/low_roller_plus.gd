extends Card

# Cataclysm+ : 15 - X instead of 12 - X (base low_roller.gd). Inverted scaling, bigger ceiling.


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if targets.is_empty() or not has_active_roll():
        Events.reset_charged_card.emit()
        return
    var base := maxi(0, 15 - int(Global.roll_value))
    var damage_effect := DamageEffect.new()
    damage_effect.amount = modifiers.get_modified_value(base, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage"
    if not has_active_roll():
        return "Deal 15 - X damage"
    var base := maxi(0, 15 - int(Global.roll_value))
    var total := apply_target_modifier(modifiers.get_modified_value(base, Modifier.Type.DMG_DEALT), target)
    return "Deal 15 - X damage (%d)" % total


# The one confirmed exception to the 0-Power refusal (Julien, 2026-09-10). Inverted scaling
# means an empty bank is this card's BEST case, not a dead one - refusing it there would
# delete the payoff it exists for. Card.plays_at_zero_power() is only consulted once a roll
# has happened, so this still cannot be played cold off a fresh reset for a free 15.
func plays_at_zero_power() -> bool:
    return true
