extends Card

# "This combat, your active Dice's highest face replaces its lowest." Blue becomes
# 2/3/4/5/6/6 - EV up, and sixes density up, which feeds Jackpot, Effigy and Critical Edge.
# Exact 6 as its gate, so it belongs to the precision ladder that pays for itself.

func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    var type: String = Global.dice_type
    var values: Array = Global.current_face_values(type).duplicate()
    if values.size() > 1:
        values.sort()
        values[0] = values[values.size() - 1]
        values.sort()
        Global.face_overrides[type] = values
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
