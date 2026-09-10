extends Card

func apply_effects(targets: Array[Node], modifiers: ModifierHandler) -> void:
    var remainder := Global.roll_value % 7
    if remainder == 0:
        Global.roll_value += 7
    elif remainder == 1:
        Global.roll_value += 6
    elif remainder == 2:
        Global.roll_value += 5
    elif remainder == 3:
        Global.roll_value += 4
    elif remainder == 4:
        Global.roll_value += 3
    elif remainder == 5:
        Global.roll_value += 2
    elif remainder == 6:
        Global.roll_value += 1

    Events.change_current_power.emit()

    var support_effect := SupportEffect.new()
    support_effect.sound = sound
    support_effect.execute(targets)
    Events.draw_card.emit(1)
    Events.reset_charged_card.emit()

# Exempt from the 0-Power refusal (Julien, 2026-09-10): this lifts the bank to the next multiple, so an empty bank still pays out,
# so an empty bank costs it nothing. See Card.plays_at_zero_power().
func plays_at_zero_power() -> bool:
    return true
