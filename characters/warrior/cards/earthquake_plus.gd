extends Card

# Earthquake+ : banks X3 instead of X2 into the pending quake (base earthquake.gd).

const EARTHQUAKE_STATUS = preload("res://statuses/status_earthquake.tres")


func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    if not has_active_roll():
        Events.reset_charged_card.emit()
        return
    var banked := modifiers.get_modified_value(int(Global.roll_value) * 3, Modifier.Type.DMG_DEALT)
    if banked > 0:
        var status_effect := StatusEffect.new()
        var quake: Status = EARTHQUAKE_STATUS.duplicate()
        quake.stacks = banked
        status_effect.status = quake
        status_effect.sound = sound
        status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()


func get_dynamic_description(modifiers: ModifierHandler, _target: Node = null) -> String:
    if is_inked():
        return "At the start of your next turn, deal ? damage to ALL enemies"
    if not has_active_roll():
        return "At the start of your next turn, deal X3 damage to ALL enemies"
    var total := modifiers.get_modified_value(int(Global.roll_value) * 3, Modifier.Type.DMG_DEALT)
    return "At the start of your next turn, deal X3 damage to ALL enemies (%d)" % total
