extends Card

# Net-positive Celestial rare (STS Adrenaline energy): pure free tempo - 2 cards + 2
# dice of your active type, playable at zero resources. SUPPORT flag: never resets your
# Power. Exhausts.


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.draw_card.emit(2)
    var prop := "%s_dice_current_amount" % Global.dice_type
    Global.set(prop, int(Global.get(prop)) + 2)
    Events.dice_charged.emit(Global.dice_type, 2)
    Events.dice_amount_changed.emit()
    Events.temporary_dice_added.emit(Global.dice_type)
    Events.reset_charged_card.emit()
