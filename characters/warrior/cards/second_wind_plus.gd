extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if Global.roll_value > 16:
        return
    var heal_amount: int = int(Global.roll_value / 2.0)
    if heal_amount > 0:
        for target in targets:
            if target.get("stats") != null:
                target.stats.heal(heal_amount)
        Events.hp_changed.emit()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    # NORMAL rarity on purpose: the bank is SPENT on the heal, same price as any
    # other converter card.
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()

func get_dynamic_description(_modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "Heal ? HP (half your Power). Exhaust"
    if not has_active_roll() or Global.roll_value <= 0 or not meets_requirement():
        return "Heal HP equal to half your Power. Exhaust"
    return "Heal %d HP (half your Power). Exhaust" % int(Global.roll_value / 2.0)
