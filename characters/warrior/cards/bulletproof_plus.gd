extends Card


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var block_effect := BlockEffect.new()
    block_effect.amount = Global.roll_value * 3
    block_effect.sound = sound
    block_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Block ?"
    if not has_active_roll() or not meets_requirement():
        return "Gain X3 Block"
    return "Gain X3 Block (%d)" % (int(Global.roll_value) * 3)
