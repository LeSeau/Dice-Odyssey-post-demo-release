extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value
    block_effect.sound = sound
    block_effect.execute(targets)
    # load() is still ResourceLoader-cached by path - duplicate so a repeat trigger never
    # hands out the SAME Card object twice (see calculations.gd for the full rationale).
    var scout_card = load("res://characters/warrior/cards/card_scout5.tres").duplicate()
    Events.add_card_to_hand_requested.emit(scout_card)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Block ?. Gain a Scout 5 card"
    if not has_active_roll():
        return "Gain X Block. Gain a Scout 5 card"
    return "Gain X Block (%d). Gain a Scout 5 card" % Global.roll_value
