extends Card


func apply_effects(targets: Array [Node], modifiers: ModifierHandler) -> void:
    Events.reset_charged_card.emit()
    if Global.roll_value <= 3:
        Global.next_roll_modifier+=8
        Events.display_next_roll_modifier.emit()
        var support_effect := SupportEffect.new()
        support_effect.sound = sound
        support_effect.execute(targets)
        Events.dice_roll_reset.emit()

func _on_dice_rolled():
    print("adding dice to damage")
