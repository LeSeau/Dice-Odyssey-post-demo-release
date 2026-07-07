extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    # By the time a red card resolves, the die that carried it is already spent -
    # "remaining" is genuinely every other Red die in the pool.
    var red_dice_spent: int = Global.red_dice_current_amount
    var bonus := 0
    for i in red_dice_spent:
        bonus += randi_range(1, 6)
    Global.red_dice_current_amount = 0
    var damage_effect := DamageEffect.new()
    var base_damage: int = Global.roll_value + bonus
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)
    Events.dice_amount_changed.emit()
    Events.dice_roll_reset.emit()

func get_dynamic_description(_modifiers: ModifierHandler) -> String:
    return "Deal X damage. Spend all your remaining Red Dice: each adds its own roll\n(%d Red Dice remaining)" % Global.red_dice_current_amount
