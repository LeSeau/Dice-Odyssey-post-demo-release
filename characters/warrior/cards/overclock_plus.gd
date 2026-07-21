extends Card

# Overclock+ : Draw 3, Charge 3 (base overclock.gd draws 2 / charges 2). Still Celestial,
# no-reset, Exhaust.


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.draw_card.emit(3)
    var prop := "%s_dice_current_amount" % Global.dice_type
    Global.set(prop, int(Global.get(prop)) + 3)
    Events.charge_dice_animation.emit()
    Events.dice_amount_changed.emit()
    Events.temporary_dice_added.emit(Global.dice_type)
    Events.reset_charged_card.emit()
