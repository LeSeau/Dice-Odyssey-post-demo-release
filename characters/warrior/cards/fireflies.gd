extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value
    block_effect.sound = sound
    block_effect.execute(targets)
    Global.next_roll_modifier+=5
    Events.display_next_roll_modifier.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.dice_roll_reset.emit()

func _on_dice_rolled():
    print("adding dice to damage")

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Block ?. Boost 5"
    if not has_active_roll():
        return "Block X. Boost 5"
    return "Block %d. Boost 5" % Global.roll_value
