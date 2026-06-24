extends Card



func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:

    if Global.roll_value >= 4:
        var active_dice = Global.dice_type
        var dice_amount_variable = active_dice + "_dice_current_amount"
        Global.set(dice_amount_variable, Global.get(dice_amount_variable) + 1)
        Events.charge_dice_animation.emit()
        Events.temporary_dice_added.emit(active_dice)
        var damage_effect := DamageEffect.new()
        var base_damage = Global.roll_value
        Events.reset_charged_card.emit()
        damage_effect.amount = modifiers.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
        Events.dice_rolled.connect(_on_dice_rolled)
        damage_effect.sound = sound
        damage_effect.execute(targets)

    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()     
func _on_dice_rolled():
    

    print("adding dice to damage")
