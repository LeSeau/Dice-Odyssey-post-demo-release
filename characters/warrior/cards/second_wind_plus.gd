extends Card


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    var heal_amount: int = int(Global.roll_value)
    if heal_amount > 0:
        for target in targets:
            if target.get("stats") != null:
                target.stats.heal(heal_amount)
        Events.hp_changed.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Heal ? HP. Exhaust"
    if not has_active_roll() or Global.roll_value <= 0 or not meets_requirement():
        return "Heal X HP. Exhaust"
    return "Heal X HP (%d). Exhaust" % int(Global.roll_value)
