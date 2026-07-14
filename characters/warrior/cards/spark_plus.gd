extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Global.blue_dice_current_amount+=1

    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)

    # load() is still ResourceLoader-cached by path - duplicate so a repeat trigger never
    # hands out the SAME Card object twice (see calculations.gd for the full rationale).
    var scout_card = load("res://characters/warrior/cards/card_scout5.tres").duplicate()
    Events.add_card_to_hand_requested.emit(scout_card)

    Events.dice_amount_changed.emit()
    Events.charge_dice_animation.emit()
    Events.temporary_dice_added.emit("blue")
    Events.reset_charged_card.emit()
