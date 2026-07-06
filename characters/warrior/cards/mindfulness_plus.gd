extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value
    block_effect.sound = sound
    block_effect.execute(targets)
    var scout_card = load("res://characters/warrior/cards/card_scout5.tres")
    Events.add_card_to_hand_requested.emit(scout_card)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

func get_dynamic_description(_modifiers: ModifierHandler) -> String:
    if is_inked():
        return "Block ?. Gain a Scout 5 card"
    if not has_active_roll():
        return "Block X. Gain a Scout 5 card"
    return "Block %d. Gain a Scout 5 card" % Global.roll_value
