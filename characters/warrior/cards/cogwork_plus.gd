extends Card

const COGWORK_STATUS = preload("res://statuses/status_cogwork.tres")

func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    if meets_requirement():
        Global.mech_dice_bonus_amount_fight += 1
        if not Global.dice_inventory.has("mech"):
            Global.dice_inventory.append("mech")
        Events.temporary_dice_added.emit("mech")
        var status_effect := StatusEffect.new()
        var cogwork := COGWORK_STATUS.duplicate()
        status_effect.status = cogwork
        status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

# Exempt from the 0-Power refusal (Julien, 2026-09-10): this grants a Mech Dice every turn, never reading the bank,
# so an empty bank costs it nothing. See Card.plays_at_zero_power().
# Base Cogwork is EXACT 6, so it cannot reach 0 Power in the first place.
func plays_at_zero_power() -> bool:
    return true
