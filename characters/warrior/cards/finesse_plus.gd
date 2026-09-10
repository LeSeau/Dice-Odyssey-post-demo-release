extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if meets_requirement():
        Global.next_roll_modifier+=8
        Events.display_next_roll_modifier.emit()
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_roll_reset.emit()

func _on_dice_rolled():
    print("adding dice to damage")

# Exempt from the 0-Power refusal (Julien, 2026-09-10): this grants a flat Boost,
# so an empty bank costs it nothing. See Card.plays_at_zero_power().
func plays_at_zero_power() -> bool:
    return true
