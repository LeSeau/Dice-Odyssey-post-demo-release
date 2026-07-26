extends Card

# Big-chain payoff: at Min 10 it hits for your whole banked Power AND hands back two dice of
# whatever type you were rolling, so the chain that earned it can keep running.
#
# The gate is read from the card resource via meets_requirement() rather than hardcoded, which is
# what lets card_disintegration_plus.tres reuse this exact script with nothing but its Min
# lowered to 8 (same "+ reuses the base script" pattern as Meteor+/Pixie Volley+).

const CHARGE_AMOUNT := 2


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if meets_requirement():
        var active_dice: String = Global.dice_type
        var dice_amount_variable := active_dice + "_dice_current_amount"
        Global.set(dice_amount_variable, Global.get(dice_amount_variable) + CHARGE_AMOUNT)
        Events.charge_dice_animation.emit()
        Events.temporary_dice_added.emit(active_dice)
        var damage_effect := DamageEffect.new()
        damage_effect.amount = modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT)
        damage_effect.sound = sound
        damage_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func get_dynamic_description(modifiers: ModifierHandler, target: Node = null) -> String:
    if is_inked():
        return "Deal ? damage. Charge 2"
    if not has_active_roll() or not meets_requirement():
        return "Deal X damage. Charge 2"
    var total := apply_target_modifier(modifiers.get_modified_value(Global.roll_value, Modifier.Type.DMG_DEALT), target)
    return "Deal %d damage. Charge 2" % total
