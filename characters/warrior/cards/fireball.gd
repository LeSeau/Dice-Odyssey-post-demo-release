extends Card


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var damage_effect := DamageEffect.new()
    var base_damage = Global.roll_value
    if Global.roll_value >= 4:
        Global.magma_dice_current_amount+=1
        Events.charge_dice_animation.emit()
        Events.temporary_dice_added.emit("magma")
    damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
    damage_effect.sound = sound
    damage_effect.execute(targets)

    Events.dice_roll_reset.emit()
