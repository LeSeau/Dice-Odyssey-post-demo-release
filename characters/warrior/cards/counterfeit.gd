extends Card

# "This combat, your active Dice's highest face replaces its lowest." Blue becomes
# 2/3/4/5/6/6 - EV up, and sixes density up, which feeds Jackpot, Effigy and Critical Edge.
# Exact 6 as its gate, so it belongs to the precision ladder that pays for itself.

const COUNTERFEIT_STATUS = preload("res://statuses/status_counterfeit.tres")


func apply_effects(targets: Array[Node], _modifiers: ModifierHandler) -> void:
    if not meets_requirement():
        return
    var type: String = Global.dice_type
    var values: Array = Global.current_face_values(type).duplicate()
    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    if values.size() > 1:
        values.sort()
        values[0] = values[values.size() - 1]
        values.sort()
        Global.face_overrides[type] = values
        # Badge for a rule that would otherwise be invisible for the whole combat (Julien,
        # 2026-08-19). Inside the guard so a die that couldn't be counterfeited never shows
        # one. No sound on the StatusEffect - the SupportEffect above already played it
        # (same shape as socketless_red/reservoir).
        var status_effect := StatusEffect.new()
        status_effect.status = COUNTERFEIT_STATUS.duplicate()
        status_effect.execute(targets)
    Events.dice_roll_reset.emit()
    Events.reset_charged_card.emit()
